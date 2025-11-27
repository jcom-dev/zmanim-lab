package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jcom-dev/zmanim-lab/internal/middleware"
	"github.com/jcom-dev/zmanim-lab/internal/models"
)

// GetPublisherCoverage returns the current publisher's coverage areas
func (h *Handlers) GetPublisherCoverage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get user ID from context (set by auth middleware)
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// First get the publisher ID for this user
	var publisherID string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT id FROM publishers WHERE clerk_user_id = $1",
		userID,
	).Scan(&publisherID)

	if err != nil {
		if err.Error() == "no rows in result set" {
			RespondNotFound(w, r, "Publisher not found")
			return
		}
		RespondInternalError(w, r, "Failed to fetch publisher")
		return
	}

	// Query coverage areas with display names
	query := `
		SELECT
			pc.id, pc.publisher_id, pc.coverage_level,
			pc.country_code, pc.region, pc.city_id,
			pc.priority, pc.is_active, pc.created_at, pc.updated_at,
			CASE
				WHEN pc.coverage_level = 'city' THEN c.name || ', ' || COALESCE(c.region, '') || ', ' || c.country
				WHEN pc.coverage_level = 'region' THEN pc.region || ', ' || pc.country_code
				WHEN pc.coverage_level = 'country' THEN pc.country_code
			END as display_name,
			COALESCE(c.name, '') as city_name,
			COALESCE(c.country, pc.country_code, '') as country
		FROM publisher_coverage pc
		LEFT JOIN cities c ON pc.city_id = c.id
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

	// Get user ID from context
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Get publisher ID
	var publisherID string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT id FROM publishers WHERE clerk_user_id = $1",
		userID,
	).Scan(&publisherID)

	if err != nil {
		if err.Error() == "no rows in result set" {
			RespondNotFound(w, r, "Publisher not found")
			return
		}
		RespondInternalError(w, r, "Failed to fetch publisher")
		return
	}

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

	err = h.db.Pool.QueryRow(ctx, query,
		publisherID, req.CoverageLevel, req.CountryCode, req.Region, req.CityID, priority,
	).Scan(
		&coverage.ID, &coverage.PublisherID, &coverage.CoverageLevel,
		&coverage.CountryCode, &coverage.Region, &coverage.CityID,
		&coverage.Priority, &coverage.IsActive, &coverage.CreatedAt, &coverage.UpdatedAt,
	)

	if err != nil {
		// Check for unique constraint violation
		if err.Error() != "" {
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
		coverage.DisplayName = *req.Region + ", " + *req.CountryCode
	} else {
		coverage.DisplayName = *req.CountryCode
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

	// Get user ID from context
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Verify ownership
	var publisherID string
	err := h.db.Pool.QueryRow(ctx,
		`SELECT pc.publisher_id
		 FROM publisher_coverage pc
		 JOIN publishers p ON pc.publisher_id = p.id
		 WHERE pc.id = $1 AND p.clerk_user_id = $2`,
		coverageID, userID,
	).Scan(&publisherID)

	if err != nil {
		RespondNotFound(w, r, "Coverage not found or not owned by user")
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
	err = h.db.Pool.QueryRow(ctx, query, args...).Scan(
		&coverage.ID, &coverage.PublisherID, &coverage.CoverageLevel,
		&coverage.CountryCode, &coverage.Region, &coverage.CityID,
		&coverage.Priority, &coverage.IsActive, &coverage.CreatedAt, &coverage.UpdatedAt,
	)

	if err != nil {
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

	// Get user ID from context
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Delete with ownership check
	result, err := h.db.Pool.Exec(ctx,
		`DELETE FROM publisher_coverage pc
		 USING publishers p
		 WHERE pc.id = $1 AND pc.publisher_id = p.id AND p.clerk_user_id = $2`,
		coverageID, userID,
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

// GetCountries returns list of unique countries from cities table
func (h *Handlers) GetCountries(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	query := `
		SELECT DISTINCT country_code, country
		FROM cities
		ORDER BY country
	`

	rows, err := h.db.Pool.Query(ctx, query)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch countries")
		return
	}
	defer rows.Close()

	type Country struct {
		Code string `json:"code"`
		Name string `json:"name"`
	}

	var countries []Country
	for rows.Next() {
		var c Country
		if err := rows.Scan(&c.Code, &c.Name); err != nil {
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

// GetRegions returns regions for a country
func (h *Handlers) GetRegions(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	countryCode := r.URL.Query().Get("country_code")

	if countryCode == "" {
		RespondBadRequest(w, r, "country_code query parameter is required")
		return
	}

	query := `
		SELECT DISTINCT region, region_type
		FROM cities
		WHERE country_code = $1 AND region IS NOT NULL
		ORDER BY region
	`

	rows, err := h.db.Pool.Query(ctx, query, countryCode)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch regions")
		return
	}
	defer rows.Close()

	type Region struct {
		Name string  `json:"name"`
		Type *string `json:"type,omitempty"`
	}

	var regions []Region
	for rows.Next() {
		var r Region
		if err := rows.Scan(&r.Name, &r.Type); err != nil {
			continue
		}
		regions = append(regions, r)
	}

	if regions == nil {
		regions = []Region{}
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"regions":      regions,
		"total":        len(regions),
		"country_code": countryCode,
	})
}
