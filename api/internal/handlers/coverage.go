package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jcom-dev/zmanim-lab/internal/models"
)

// GetPublisherCoverage returns the current publisher's coverage areas
func (h *Handlers) GetPublisherCoverage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Query coverage areas with display names
	// For country-level coverage, look up the country name from cities table
	query := `
		SELECT
			pc.id, pc.publisher_id, pc.coverage_level,
			pc.country_code, pc.region, pc.city_id,
			pc.priority, pc.is_active, pc.created_at, pc.updated_at,
			CASE
				WHEN pc.coverage_level = 'city' THEN c.name || ', ' || COALESCE(c.region, '') || ', ' || c.country
				WHEN pc.coverage_level = 'region' THEN pc.region || ', ' || COALESCE(country_lookup.country, pc.country_code)
				WHEN pc.coverage_level = 'country' THEN COALESCE(country_lookup.country, pc.country_code)
			END as display_name,
			COALESCE(c.name, '') as city_name,
			COALESCE(c.country, country_lookup.country, pc.country_code, '') as country
		FROM publisher_coverage pc
		LEFT JOIN cities c ON pc.city_id = c.id
		LEFT JOIN LATERAL (
			SELECT DISTINCT country FROM cities WHERE country_code = pc.country_code LIMIT 1
		) country_lookup ON true
		WHERE pc.publisher_id = $1
		ORDER BY pc.priority DESC, pc.created_at DESC
	`

	rows, err := h.db.Pool.Query(ctx, query, publisherID)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch coverage areas")
		return
	}
	defer rows.Close()

	var coverage []models.PublisherCoverage
	for rows.Next() {
		var c models.PublisherCoverage
		err := rows.Scan(
			&c.ID, &c.PublisherID, &c.CoverageLevel,
			&c.CountryCode, &c.Region, &c.CityID,
			&c.Priority, &c.IsActive, &c.CreatedAt, &c.UpdatedAt,
			&c.DisplayName, &c.CityName, &c.Country,
		)
		if err != nil {
			continue
		}
		coverage = append(coverage, c)
	}

	if coverage == nil {
		coverage = []models.PublisherCoverage{}
	}

	RespondJSON(w, r, http.StatusOK, models.PublisherCoverageListResponse{
		Coverage: coverage,
		Total:    len(coverage),
	})
}

// CreatePublisherCoverage adds a new coverage area for the publisher
func (h *Handlers) CreatePublisherCoverage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Parse request body
	var req models.PublisherCoverageCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate coverage level
	if req.CoverageLevel != "country" && req.CoverageLevel != "region" && req.CoverageLevel != "city" {
		RespondBadRequest(w, r, "Invalid coverage_level: must be 'country', 'region', or 'city'")
		return
	}

	// Validate based on coverage level
	switch req.CoverageLevel {
	case "country":
		if req.CountryCode == nil || *req.CountryCode == "" {
			RespondBadRequest(w, r, "country_code is required for country-level coverage")
			return
		}
	case "region":
		if req.CountryCode == nil || *req.CountryCode == "" {
			RespondBadRequest(w, r, "country_code is required for region-level coverage")
			return
		}
		if req.Region == nil || *req.Region == "" {
			RespondBadRequest(w, r, "region is required for region-level coverage")
			return
		}
	case "city":
		if req.CityID == nil || *req.CityID == "" {
			RespondBadRequest(w, r, "city_id is required for city-level coverage")
			return
		}
		// Verify city exists
		var exists bool
		err := h.db.Pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM cities WHERE id = $1)", *req.CityID).Scan(&exists)
		if err != nil || !exists {
			RespondBadRequest(w, r, "Invalid city_id: city not found")
			return
		}
	}

	// Default priority
	priority := 5
	if req.Priority != nil && *req.Priority >= 1 && *req.Priority <= 10 {
		priority = *req.Priority
	}

	// Insert coverage
	var coverage models.PublisherCoverage
	query := `
		INSERT INTO publisher_coverage (publisher_id, coverage_level, country_code, region, city_id, priority)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, publisher_id, coverage_level, country_code, region, city_id, priority, is_active, created_at, updated_at
	`

	insertErr := h.db.Pool.QueryRow(ctx, query,
		publisherID, req.CoverageLevel, req.CountryCode, req.Region, req.CityID, priority,
	).Scan(
		&coverage.ID, &coverage.PublisherID, &coverage.CoverageLevel,
		&coverage.CountryCode, &coverage.Region, &coverage.CityID,
		&coverage.Priority, &coverage.IsActive, &coverage.CreatedAt, &coverage.UpdatedAt,
	)

	if insertErr != nil {
		// Check for unique constraint violation
		if insertErr.Error() != "" {
			RespondBadRequest(w, r, "Coverage already exists for this area")
			return
		}
		RespondInternalError(w, r, "Failed to create coverage")
		return
	}

	// Get display name
	if req.CoverageLevel == "city" && req.CityID != nil {
		h.db.Pool.QueryRow(ctx,
			"SELECT name || ', ' || COALESCE(region, '') || ', ' || country FROM cities WHERE id = $1",
			*req.CityID,
		).Scan(&coverage.DisplayName)
	} else if req.CoverageLevel == "region" {
		// Look up country name for region display
		var countryName string
		err := h.db.Pool.QueryRow(ctx,
			"SELECT DISTINCT country FROM cities WHERE country_code = $1 LIMIT 1",
			*req.CountryCode,
		).Scan(&countryName)
		if err != nil || countryName == "" {
			countryName = *req.CountryCode
		}
		coverage.DisplayName = *req.Region + ", " + countryName
	} else {
		// Look up country name for country-level coverage
		var countryName string
		err := h.db.Pool.QueryRow(ctx,
			"SELECT DISTINCT country FROM cities WHERE country_code = $1 LIMIT 1",
			*req.CountryCode,
		).Scan(&countryName)
		if err != nil || countryName == "" {
			countryName = *req.CountryCode
		}
		coverage.DisplayName = countryName
	}

	RespondJSON(w, r, http.StatusCreated, coverage)
}

// UpdatePublisherCoverage updates a coverage area's priority or active status
func (h *Handlers) UpdatePublisherCoverage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	coverageID := chi.URLParam(r, "id")

	if coverageID == "" {
		RespondBadRequest(w, r, "Coverage ID is required")
		return
	}

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}

	// Verify ownership - coverage must belong to this publisher
	var verifiedPublisherID string
	err := h.db.Pool.QueryRow(ctx,
		`SELECT publisher_id FROM publisher_coverage WHERE id = $1 AND publisher_id = $2`,
		coverageID, pc.PublisherID,
	).Scan(&verifiedPublisherID)
	if err != nil {
		RespondNotFound(w, r, "Coverage not found or not owned by publisher")
		return
	}

	// Parse request body
	var req models.PublisherCoverageUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Build update query
	updates := []string{}
	args := []interface{}{}
	argCount := 1

	if req.Priority != nil {
		if *req.Priority < 1 || *req.Priority > 10 {
			RespondBadRequest(w, r, "Priority must be between 1 and 10")
			return
		}
		updates = append(updates, fmt.Sprintf("priority = $%d", argCount))
		args = append(args, *req.Priority)
		argCount++
	}

	if req.IsActive != nil {
		updates = append(updates, fmt.Sprintf("is_active = $%d", argCount))
		args = append(args, *req.IsActive)
		argCount++
	}

	if len(updates) == 0 {
		RespondBadRequest(w, r, "No fields to update")
		return
	}

	// Add coverage ID
	args = append(args, coverageID)

	// Execute update
	query := "UPDATE publisher_coverage SET " + updates[0]
	for i := 1; i < len(updates); i++ {
		query += ", " + updates[i]
	}
	query += fmt.Sprintf(", updated_at = NOW() WHERE id = $%d", argCount)
	query += " RETURNING id, publisher_id, coverage_level, country_code, region, city_id, priority, is_active, created_at, updated_at"

	var coverage models.PublisherCoverage
	updateErr := h.db.Pool.QueryRow(ctx, query, args...).Scan(
		&coverage.ID, &coverage.PublisherID, &coverage.CoverageLevel,
		&coverage.CountryCode, &coverage.Region, &coverage.CityID,
		&coverage.Priority, &coverage.IsActive, &coverage.CreatedAt, &coverage.UpdatedAt,
	)

	if updateErr != nil {
		RespondInternalError(w, r, "Failed to update coverage")
		return
	}

	RespondJSON(w, r, http.StatusOK, coverage)
}

// DeletePublisherCoverage removes a coverage area
func (h *Handlers) DeletePublisherCoverage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	coverageID := chi.URLParam(r, "id")

	if coverageID == "" {
		RespondBadRequest(w, r, "Coverage ID is required")
		return
	}

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}

	// Delete with publisher ownership check
	result, err := h.db.Pool.Exec(ctx,
		`DELETE FROM publisher_coverage WHERE id = $1 AND publisher_id = $2`,
		coverageID, pc.PublisherID,
	)

	if err != nil {
		RespondInternalError(w, r, "Failed to delete coverage")
		return
	}

	if result.RowsAffected() == 0 {
		RespondNotFound(w, r, "Coverage not found or not owned by user")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"message": "Coverage deleted successfully",
	})
}

// GetPublishersForCity returns publishers serving a specific city
func (h *Handlers) GetPublishersForCity(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	cityID := chi.URLParam(r, "cityId")

	if cityID == "" {
		RespondBadRequest(w, r, "City ID is required")
		return
	}

	// Use the database function we created
	query := `SELECT publisher_id, publisher_name, coverage_level, priority, match_type
			  FROM get_publishers_for_city($1)`

	rows, err := h.db.Pool.Query(ctx, query, cityID)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch publishers for city")
		return
	}
	defer rows.Close()

	var publishers []models.PublisherForCity
	for rows.Next() {
		var p models.PublisherForCity
		if err := rows.Scan(&p.PublisherID, &p.PublisherName, &p.CoverageLevel, &p.Priority, &p.MatchType); err != nil {
			continue
		}
		publishers = append(publishers, p)
	}

	if publishers == nil {
		publishers = []models.PublisherForCity{}
	}

	RespondJSON(w, r, http.StatusOK, models.PublishersForCityResponse{
		Publishers: publishers,
		Total:      len(publishers),
		CityID:     cityID,
	})
}

// GetContinents returns list of continents with city counts
func (h *Handlers) GetContinents(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	query := `
		SELECT DISTINCT continent, COUNT(*) as city_count
		FROM cities
		WHERE continent IS NOT NULL AND continent != ''
		GROUP BY continent
		ORDER BY continent
	`

	rows, err := h.db.Pool.Query(ctx, query)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch continents")
		return
	}
	defer rows.Close()

	type Continent struct {
		Code      string `json:"code"`
		Name      string `json:"name"`
		CityCount int    `json:"city_count"`
	}

	var continents []Continent
	for rows.Next() {
		var name string
		var cityCount int
		if err := rows.Scan(&name, &cityCount); err != nil {
			continue
		}
		// Database stores full continent names, use as both code and name
		continents = append(continents, Continent{
			Code:      name, // Use full name as code for filtering
			Name:      name,
			CityCount: cityCount,
		})
	}

	if continents == nil {
		continents = []Continent{}
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"continents": continents,
		"total":      len(continents),
	})
}

// GetCountries returns list of unique countries from cities table
func (h *Handlers) GetCountries(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Check for continent filter
	continent := strings.TrimSpace(r.URL.Query().Get("continent"))

	var query string
	var rows pgx.Rows
	var err error

	if continent != "" {
		query = `
			SELECT country_code, country, COUNT(*) as city_count
			FROM cities
			WHERE continent = $1
			GROUP BY country_code, country
			ORDER BY country
		`
		rows, err = h.db.Pool.Query(ctx, query, continent)
	} else {
		query = `
			SELECT country_code, country, COUNT(*) as city_count
			FROM cities
			GROUP BY country_code, country
			ORDER BY country
		`
		rows, err = h.db.Pool.Query(ctx, query)
	}

	if err != nil {
		RespondInternalError(w, r, "Failed to fetch countries")
		return
	}
	defer rows.Close()

	type Country struct {
		Code      string `json:"code"`
		Name      string `json:"name"`
		CityCount int    `json:"city_count"`
	}

	var countries []Country
	for rows.Next() {
		var c Country
		if err := rows.Scan(&c.Code, &c.Name, &c.CityCount); err != nil {
			continue
		}
		countries = append(countries, c)
	}

	if countries == nil {
		countries = []Country{}
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"countries": countries,
		"total":     len(countries),
	})
}

// GetRegions returns regions, optionally filtered by country_code or search
func (h *Handlers) GetRegions(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	countryCode := strings.TrimSpace(r.URL.Query().Get("country_code"))
	search := strings.TrimSpace(r.URL.Query().Get("search"))

	// Either country_code or search must be provided
	if countryCode == "" && search == "" {
		RespondBadRequest(w, r, "Either country_code or search query parameter is required")
		return
	}

	// Get limit (default 20, max 100)
	limit := 20
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	type Region struct {
		Name        string `json:"name"`
		CountryCode string `json:"country_code"`
		CountryName string `json:"country_name"`
		CityCount   int    `json:"city_count"`
	}

	var rows pgx.Rows
	var err error

	if search != "" && len(search) >= 2 {
		// Search across all regions
		query := `
			SELECT region, country_code, country, COUNT(*) as city_count
			FROM cities
			WHERE region IS NOT NULL
			  AND (region ILIKE $1 || '%' OR region ILIKE '%' || $1 || '%')
			GROUP BY region, country_code, country
			ORDER BY
				CASE WHEN region ILIKE $1 || '%' THEN 0 ELSE 1 END,
				city_count DESC,
				region
			LIMIT $2
		`
		rows, err = h.db.Pool.Query(ctx, query, search, limit)
	} else {
		// Filter by country code
		query := `
			SELECT region, country_code, country, COUNT(*) as city_count
			FROM cities
			WHERE country_code = $1 AND region IS NOT NULL
			GROUP BY region, country_code, country
			ORDER BY region
			LIMIT $2
		`
		rows, err = h.db.Pool.Query(ctx, query, countryCode, limit)
	}

	if err != nil {
		RespondInternalError(w, r, "Failed to fetch regions")
		return
	}
	defer rows.Close()

	var regions []Region
	for rows.Next() {
		var reg Region
		if err := rows.Scan(&reg.Name, &reg.CountryCode, &reg.CountryName, &reg.CityCount); err != nil {
			continue
		}
		regions = append(regions, reg)
	}

	if regions == nil {
		regions = []Region{}
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"regions": regions,
		"total":   len(regions),
	})
}
