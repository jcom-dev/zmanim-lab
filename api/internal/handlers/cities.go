package handlers

import (
	"fmt"
	"log/slog"
	"math"
	"net/http"
	"strconv"
	"strings"

	"github.com/jcom-dev/zmanim-lab/internal/models"
)

// SearchCities handles city search with autocomplete and filtering
// GET /api/v1/cities?search={query}&country_code={code}&region={region}&limit={limit}
func (h *Handlers) SearchCities(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get query parameters
	search := strings.TrimSpace(r.URL.Query().Get("search"))
	countryCode := strings.TrimSpace(r.URL.Query().Get("country_code"))
	region := strings.TrimSpace(r.URL.Query().Get("region"))

	// At least one filter must be provided
	if search == "" && countryCode == "" {
		RespondBadRequest(w, r, "Either search or country_code parameter is required")
		return
	}

	// Get limit (default 10 for search, 100 for filters; max 100)
	defaultLimit := 10
	maxLimit := 100
	if search == "" && countryCode != "" {
		defaultLimit = 100
	}

	limit := defaultLimit
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= maxLimit {
			limit = parsed
		}
	}

	// Build dynamic query with normalized schema JOINs
	var queryBuilder strings.Builder
	queryBuilder.WriteString(`
		SELECT c.id, c.name, co.name as country, co.code as country_code, r.name as region,
		       c.latitude, c.longitude, c.timezone, c.population, c.elevation, ct.name as continent
		FROM cities c
		JOIN geo_countries co ON c.country_id = co.id
		JOIN geo_continents ct ON co.continent_id = ct.id
		LEFT JOIN geo_regions r ON c.region_id = r.id
		WHERE 1=1`)

	args := make([]interface{}, 0)
	argNum := 1

	// Add country code filter
	if countryCode != "" {
		queryBuilder.WriteString(fmt.Sprintf(" AND co.code = $%d", argNum))
		args = append(args, countryCode)
		argNum++
	}

	// Add region filter
	if region != "" {
		queryBuilder.WriteString(fmt.Sprintf(" AND r.name = $%d", argNum))
		args = append(args, region)
		argNum++
	}

	// Add search filter (uses pg_trgm for fuzzy matching)
	// Lower threshold (0.2) allows typos like "lverpool" -> "Liverpool"
	if search != "" && len(search) >= 2 {
		queryBuilder.WriteString(fmt.Sprintf(` AND (
			c.name_ascii ILIKE $%d || '%%'
			OR c.name ILIKE $%d || '%%'
			OR c.name_ascii %% $%d
			OR c.name %% $%d
		)`, argNum, argNum, argNum, argNum))
		args = append(args, search)
		argNum++
	}

	// Add ordering - prioritize exact prefix matches, then similarity score, then population
	if search != "" && len(search) >= 2 {
		queryBuilder.WriteString(fmt.Sprintf(`
		ORDER BY
			CASE WHEN c.name_ascii ILIKE $%d || '%%' THEN 0
			     WHEN c.name ILIKE $%d || '%%' THEN 1
			     ELSE 2 END,
			similarity(c.name_ascii, $%d) DESC,
			c.population DESC NULLS LAST,
			c.name ASC`, len(args), len(args), len(args)))
	} else {
		queryBuilder.WriteString(`
		ORDER BY c.population DESC NULLS LAST, c.name ASC`)
	}

	// Add limit
	queryBuilder.WriteString(fmt.Sprintf(" LIMIT $%d", argNum))
	args = append(args, limit)

	// Execute query
	rows, err := h.db.Pool.Query(ctx, queryBuilder.String(), args...)
	if err != nil {
		slog.Error("failed to search cities", "error", err, "search", search, "country", countryCode, "region", region)
		RespondInternalError(w, r, "Failed to search cities")
		return
	}
	defer rows.Close()

	cities := make([]models.City, 0)
	for rows.Next() {
		var city models.City
		err := rows.Scan(
			&city.ID,
			&city.Name,
			&city.Country,
			&city.CountryCode,
			&city.Region,
			&city.Latitude,
			&city.Longitude,
			&city.Timezone,
			&city.Population,
			&city.Elevation,
			&city.Continent,
		)
		if err != nil {
			slog.Error("failed to scan city row", "error", err)
			continue
		}

		// Build display name: "City, Region, Country"
		city.DisplayName = buildDisplayName(city)
		cities = append(cities, city)
	}

	RespondJSON(w, r, http.StatusOK, models.CitySearchResponse{
		Cities: cities,
		Total:  len(cities),
	})
}

// GetNearbyCity finds the nearest city to given coordinates
// GET /api/v1/cities/nearby?lat={lat}&lng={lng}
func (h *Handlers) GetNearbyCity(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Parse latitude
	latStr := r.URL.Query().Get("lat")
	if latStr == "" {
		RespondBadRequest(w, r, "Latitude is required")
		return
	}
	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil || lat < -90 || lat > 90 {
		RespondBadRequest(w, r, "Invalid latitude")
		return
	}

	// Parse longitude
	lngStr := r.URL.Query().Get("lng")
	if lngStr == "" {
		RespondBadRequest(w, r, "Longitude is required")
		return
	}
	lng, err := strconv.ParseFloat(lngStr, 64)
	if err != nil || lng < -180 || lng > 180 {
		RespondBadRequest(w, r, "Invalid longitude")
		return
	}

	// Find nearest city using PostGIS ST_Distance with normalized JOINs
	query := `
		SELECT c.id, c.name, co.name as country, co.code as country_code, r.name as region,
		       c.latitude, c.longitude, c.timezone, c.population, c.elevation, ct.name as continent,
		       ST_Distance(c.location, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) as distance_meters
		FROM cities c
		JOIN geo_countries co ON c.country_id = co.id
		JOIN geo_continents ct ON co.continent_id = ct.id
		LEFT JOIN geo_regions r ON c.region_id = r.id
		ORDER BY c.location <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
		LIMIT 1
	`

	var city models.City
	var distanceMeters float64
	err = h.db.Pool.QueryRow(ctx, query, lat, lng).Scan(
		&city.ID,
		&city.Name,
		&city.Country,
		&city.CountryCode,
		&city.Region,
		&city.Latitude,
		&city.Longitude,
		&city.Timezone,
		&city.Population,
		&city.Elevation,
		&city.Continent,
		&distanceMeters,
	)

	if err != nil {
		slog.Error("failed to find nearby city", "error", err, "lat", lat, "lng", lng)
		RespondInternalError(w, r, "Failed to find nearby city")
		return
	}

	city.DisplayName = buildDisplayName(city)

	// Return city with distance info
	response := map[string]interface{}{
		"city":             city,
		"distance_km":      math.Round(distanceMeters/1000*10) / 10,
		"distance_miles":   math.Round(distanceMeters/1609.34*10) / 10,
		"searched_lat":     lat,
		"searched_lng":     lng,
	}

	RespondJSON(w, r, http.StatusOK, response)
}

// GetCityByID returns a single city by ID
// GET /api/v1/cities/{id}
func (h *Handlers) GetCityByID(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get city ID from URL
	id := r.URL.Query().Get("id")
	if id == "" {
		// Try to get from path parameter (chi)
		// For now, use query param
		RespondBadRequest(w, r, "City ID is required")
		return
	}

	query := `
		SELECT c.id, c.name, co.name as country, co.code as country_code, r.name as region,
		       c.latitude, c.longitude, c.timezone, c.population, c.elevation, ct.name as continent
		FROM cities c
		JOIN geo_countries co ON c.country_id = co.id
		JOIN geo_continents ct ON co.continent_id = ct.id
		LEFT JOIN geo_regions r ON c.region_id = r.id
		WHERE c.id = $1
	`

	var city models.City
	err := h.db.Pool.QueryRow(ctx, query, id).Scan(
		&city.ID,
		&city.Name,
		&city.Country,
		&city.CountryCode,
		&city.Region,
		&city.Latitude,
		&city.Longitude,
		&city.Timezone,
		&city.Population,
		&city.Elevation,
		&city.Continent,
	)

	if err != nil {
		RespondNotFound(w, r, "City not found")
		return
	}

	city.DisplayName = buildDisplayName(city)
	RespondJSON(w, r, http.StatusOK, city)
}

// buildDisplayName creates a formatted display name for a city
func buildDisplayName(city models.City) string {
	parts := []string{city.Name}

	if city.Region != nil && *city.Region != "" {
		parts = append(parts, *city.Region)
	}

	parts = append(parts, city.Country)

	return fmt.Sprintf("%s", strings.Join(parts, ", "))
}
