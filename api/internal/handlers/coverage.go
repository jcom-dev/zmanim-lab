package handlers

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jcom-dev/zmanim-lab/internal/db/sqlcgen"
	"github.com/jcom-dev/zmanim-lab/internal/models"
)

// GetPublisherCoverage returns the current publisher's coverage areas
// @Summary Get publisher coverage areas
// @Description Returns all geographic coverage areas configured for the authenticated publisher
// @Tags Coverage
// @Produce json
// @Security BearerAuth
// @Param X-Publisher-Id header string true "Publisher ID"
// @Success 200 {object} APIResponse{data=models.PublisherCoverageListResponse} "List of coverage areas"
// @Failure 401 {object} APIResponse{error=APIError} "Unauthorized"
// @Failure 404 {object} APIResponse{error=APIError} "Publisher not found"
// @Failure 500 {object} APIResponse{error=APIError} "Internal server error"
// @Router /publisher/coverage [get]
func (h *Handlers) GetPublisherCoverage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}

	// Query coverage areas using SQLc
	rows, err := h.db.Queries.GetPublisherCoverage(ctx, pc.PublisherID)
	if err != nil {
		slog.Error("failed to fetch coverage", "error", err, "publisher_id", pc.PublisherID)
		RespondInternalError(w, r, "Failed to fetch coverage areas")
		return
	}

	coverage := make([]models.PublisherCoverage, 0, len(rows))
	for _, row := range rows {
		c := coverageRowToModel(row)
		coverage = append(coverage, c)
	}

	RespondJSON(w, r, http.StatusOK, models.PublisherCoverageListResponse{
		Coverage: coverage,
		Total:    len(coverage),
	})
}

// CreatePublisherCoverage adds a new coverage area for the publisher
// @Summary Create coverage area
// @Description Adds a new geographic coverage area (continent, country, region, district, or city level)
// @Tags Coverage
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param X-Publisher-Id header string true "Publisher ID"
// @Param request body models.PublisherCoverageCreateRequest true "Coverage area configuration"
// @Success 201 {object} APIResponse{data=models.PublisherCoverage} "Created coverage area"
// @Failure 400 {object} APIResponse{error=APIError} "Invalid request or duplicate coverage"
// @Failure 401 {object} APIResponse{error=APIError} "Unauthorized"
// @Failure 500 {object} APIResponse{error=APIError} "Internal server error"
// @Router /publisher/coverage [post]
func (h *Handlers) CreatePublisherCoverage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}

	// Parse request body
	var req models.PublisherCoverageCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate coverage level
	validLevels := map[string]bool{"continent": true, "country": true, "region": true, "district": true, "city": true}
	if !validLevels[req.CoverageLevel] {
		RespondBadRequest(w, r, "Invalid coverage_level: must be 'continent', 'country', 'region', 'district', or 'city'")
		return
	}

	// Default priority
	priority := int32(5)
	if req.Priority != nil && *req.Priority >= 1 && *req.Priority <= 10 {
		priority = int32(*req.Priority)
	}

	var coverage models.PublisherCoverage

	// Create coverage based on level using appropriate SQLc query
	switch req.CoverageLevel {
	case "continent":
		if req.ContinentCode == nil || *req.ContinentCode == "" {
			RespondBadRequest(w, r, "continent_code is required for continent-level coverage")
			return
		}
		// Check for duplicate
		exists, _ := h.db.Queries.CheckDuplicateCoverageContinent(ctx, sqlcgen.CheckDuplicateCoverageContinentParams{
			PublisherID:   pc.PublisherID,
			ContinentCode: req.ContinentCode,
		})
		if exists {
			RespondBadRequest(w, r, "Coverage already exists for this continent")
			return
		}
		row, err := h.db.Queries.CreateCoverageContinent(ctx, sqlcgen.CreateCoverageContinentParams{
			PublisherID:   pc.PublisherID,
			ContinentCode: req.ContinentCode,
			Priority:      &priority,
			IsActive:      true,
		})
		if err != nil {
			slog.Error("failed to create continent coverage", "error", err)
			RespondInternalError(w, r, "Failed to create coverage")
			return
		}
		coverage = createCoverageContinentRowToModel(row)

	case "country":
		if req.CountryID == nil {
			RespondBadRequest(w, r, "country_id is required for country-level coverage")
			return
		}
		// Check for duplicate
		exists, _ := h.db.Queries.CheckDuplicateCoverageCountry(ctx, sqlcgen.CheckDuplicateCoverageCountryParams{
			PublisherID: pc.PublisherID,
			CountryID:   req.CountryID,
		})
		if exists {
			RespondBadRequest(w, r, "Coverage already exists for this country")
			return
		}
		row, err := h.db.Queries.CreateCoverageCountry(ctx, sqlcgen.CreateCoverageCountryParams{
			PublisherID: pc.PublisherID,
			CountryID:   req.CountryID,
			Priority:    &priority,
			IsActive:    true,
		})
		if err != nil {
			slog.Error("failed to create country coverage", "error", err)
			RespondInternalError(w, r, "Failed to create coverage")
			return
		}
		coverage = createCoverageCountryRowToModel(row)

	case "region":
		if req.RegionID == nil {
			RespondBadRequest(w, r, "region_id is required for region-level coverage")
			return
		}
		// Check for duplicate
		exists, _ := h.db.Queries.CheckDuplicateCoverageRegion(ctx, sqlcgen.CheckDuplicateCoverageRegionParams{
			PublisherID: pc.PublisherID,
			RegionID:    req.RegionID,
		})
		if exists {
			RespondBadRequest(w, r, "Coverage already exists for this region")
			return
		}
		row, err := h.db.Queries.CreateCoverageRegion(ctx, sqlcgen.CreateCoverageRegionParams{
			PublisherID: pc.PublisherID,
			RegionID:    req.RegionID,
			Priority:    &priority,
			IsActive:    true,
		})
		if err != nil {
			slog.Error("failed to create region coverage", "error", err)
			RespondInternalError(w, r, "Failed to create coverage")
			return
		}
		coverage = createCoverageRegionRowToModel(row)

	case "district":
		if req.DistrictID == nil {
			RespondBadRequest(w, r, "district_id is required for district-level coverage")
			return
		}
		// Check for duplicate
		exists, _ := h.db.Queries.CheckDuplicateCoverageDistrict(ctx, sqlcgen.CheckDuplicateCoverageDistrictParams{
			PublisherID: pc.PublisherID,
			DistrictID:  req.DistrictID,
		})
		if exists {
			RespondBadRequest(w, r, "Coverage already exists for this district")
			return
		}
		row, err := h.db.Queries.CreateCoverageDistrict(ctx, sqlcgen.CreateCoverageDistrictParams{
			PublisherID: pc.PublisherID,
			DistrictID:  req.DistrictID,
			Priority:    &priority,
			IsActive:    true,
		})
		if err != nil {
			slog.Error("failed to create district coverage", "error", err)
			RespondInternalError(w, r, "Failed to create coverage")
			return
		}
		coverage = createCoverageDistrictRowToModel(row)

	case "city":
		if req.CityID == nil || *req.CityID == "" {
			RespondBadRequest(w, r, "city_id is required for city-level coverage")
			return
		}
		// Parse city UUID
		cityUUID, err := uuid.Parse(*req.CityID)
		if err != nil {
			RespondBadRequest(w, r, "Invalid city_id format: must be a valid UUID")
			return
		}
		cityPgUUID := pgtype.UUID{Bytes: cityUUID, Valid: true}

		// Check for duplicate
		exists, _ := h.db.Queries.CheckDuplicateCoverageCity(ctx, sqlcgen.CheckDuplicateCoverageCityParams{
			PublisherID: pc.PublisherID,
			CityID:      cityPgUUID,
		})
		if exists {
			RespondBadRequest(w, r, "Coverage already exists for this city")
			return
		}
		row, err := h.db.Queries.CreateCoverageCity(ctx, sqlcgen.CreateCoverageCityParams{
			PublisherID: pc.PublisherID,
			CityID:      cityPgUUID,
			Priority:    &priority,
			IsActive:    true,
		})
		if err != nil {
			slog.Error("failed to create city coverage", "error", err)
			RespondInternalError(w, r, "Failed to create coverage")
			return
		}
		coverage = createCoverageCityRowToModel(row)
	}

	RespondJSON(w, r, http.StatusCreated, coverage)
}

// UpdatePublisherCoverage updates a coverage area's priority or active status
// @Summary Update coverage area
// @Description Updates an existing coverage area's priority or active status
// @Tags Coverage
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param X-Publisher-Id header string true "Publisher ID"
// @Param id path string true "Coverage area ID"
// @Param request body models.PublisherCoverageUpdateRequest true "Fields to update"
// @Success 200 {object} APIResponse{data=models.PublisherCoverage} "Updated coverage area"
// @Failure 400 {object} APIResponse{error=APIError} "Invalid request"
// @Failure 401 {object} APIResponse{error=APIError} "Unauthorized"
// @Failure 404 {object} APIResponse{error=APIError} "Coverage area not found"
// @Failure 500 {object} APIResponse{error=APIError} "Internal server error"
// @Router /publisher/coverage/{id} [put]
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

	// Verify ownership by fetching the coverage
	existingCoverage, err := h.db.Queries.GetPublisherCoverageByID(ctx, coverageID)
	if err != nil {
		RespondNotFound(w, r, "Coverage not found")
		return
	}
	if existingCoverage.PublisherID != pc.PublisherID {
		RespondNotFound(w, r, "Coverage not found or not owned by publisher")
		return
	}

	// Parse request body
	var req models.PublisherCoverageUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	if req.Priority == nil && req.IsActive == nil {
		RespondBadRequest(w, r, "No fields to update")
		return
	}

	var coverage models.PublisherCoverage

	// Update priority if provided
	if req.Priority != nil {
		if *req.Priority < 1 || *req.Priority > 10 {
			RespondBadRequest(w, r, "Priority must be between 1 and 10")
			return
		}
		priority := int32(*req.Priority)
		row, err := h.db.Queries.UpdateCoveragePriority(ctx, sqlcgen.UpdateCoveragePriorityParams{
			ID:       coverageID,
			Priority: &priority,
		})
		if err != nil {
			slog.Error("failed to update coverage priority", "error", err)
			RespondInternalError(w, r, "Failed to update coverage")
			return
		}
		coverage = updateCoverageRowToModel(row)
	}

	// Update active status if provided
	if req.IsActive != nil {
		row, err := h.db.Queries.UpdateCoverageActive(ctx, sqlcgen.UpdateCoverageActiveParams{
			ID:       coverageID,
			IsActive: *req.IsActive,
		})
		if err != nil {
			slog.Error("failed to update coverage active status", "error", err)
			RespondInternalError(w, r, "Failed to update coverage")
			return
		}
		coverage = updateCoverageActiveRowToModel(row)
	}

	RespondJSON(w, r, http.StatusOK, coverage)
}

// DeletePublisherCoverage removes a coverage area
// @Summary Delete coverage area
// @Description Removes a geographic coverage area from the publisher
// @Tags Coverage
// @Produce json
// @Security BearerAuth
// @Param X-Publisher-Id header string true "Publisher ID"
// @Param id path string true "Coverage area ID"
// @Success 200 {object} APIResponse{data=object} "Deletion confirmation"
// @Failure 400 {object} APIResponse{error=APIError} "Invalid request"
// @Failure 401 {object} APIResponse{error=APIError} "Unauthorized"
// @Failure 404 {object} APIResponse{error=APIError} "Coverage area not found"
// @Failure 500 {object} APIResponse{error=APIError} "Internal server error"
// @Router /publisher/coverage/{id} [delete]
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

	// Verify ownership by fetching the coverage
	existingCoverage, err := h.db.Queries.GetPublisherCoverageByID(ctx, coverageID)
	if err != nil {
		RespondNotFound(w, r, "Coverage not found")
		return
	}
	if existingCoverage.PublisherID != pc.PublisherID {
		RespondNotFound(w, r, "Coverage not found or not owned by publisher")
		return
	}

	// Delete coverage
	if err := h.db.Queries.DeleteCoverage(ctx, coverageID); err != nil {
		slog.Error("failed to delete coverage", "error", err)
		RespondInternalError(w, r, "Failed to delete coverage")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"message": "Coverage deleted successfully",
	})
}

// GetPublishersForCity returns publishers serving a specific city
// @Summary Get publishers for city
// @Description Returns all publishers that have coverage for the specified city (via city, district, region, country, or continent level)
// @Tags Cities
// @Produce json
// @Param cityId path string true "City ID (UUID)"
// @Success 200 {object} APIResponse{data=models.PublishersForCityResponse} "Publishers serving this city"
// @Failure 400 {object} APIResponse{error=APIError} "Invalid request"
// @Failure 500 {object} APIResponse{error=APIError} "Internal server error"
// @Router /cities/{cityId}/publishers [get]
func (h *Handlers) GetPublishersForCity(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	cityID := chi.URLParam(r, "cityId")

	if cityID == "" {
		RespondBadRequest(w, r, "City ID is required")
		return
	}

	// Use raw SQL since SQLc can't type the result of a SQL function
	query := `SELECT publisher_id, publisher_name, coverage_level, priority, match_type
			  FROM get_publishers_for_city($1)`

	rows, err := h.db.Pool.Query(ctx, query, cityID)
	if err != nil {
		slog.Error("failed to get publishers for city", "error", err, "city_id", cityID)
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

// GetRegions returns regions using normalized schema, optionally filtered by country_code or search
// @Summary List regions
// @Description Returns regions/states with their city counts, filtered by country code or search query
// @Tags Geography
// @Produce json
// @Param country_code query string false "Filter by ISO country code (required if search not provided)"
// @Param search query string false "Search query for region name (min 2 chars)"
// @Param limit query int false "Max results (default 20, max 100)"
// @Success 200 {object} APIResponse{data=object} "List of regions"
// @Failure 400 {object} APIResponse{error=APIError} "Either country_code or search required"
// @Failure 500 {object} APIResponse{error=APIError} "Internal server error"
// @Router /regions [get]
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
	limit := int32(20)
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = int32(parsed)
		}
	}

	type Region struct {
		ID          int32  `json:"id"`
		Code        string `json:"code"`
		Name        string `json:"name"`
		CountryID   int32  `json:"country_id,omitempty"`
		CountryCode string `json:"country_code,omitempty"`
		CountryName string `json:"country_name,omitempty"`
		CityCount   int64  `json:"city_count,omitempty"`
	}

	var regions []Region

	if search != "" && len(search) >= 2 {
		// Search across all regions using SQLc
		rows, err := h.db.Queries.SearchRegions(ctx, sqlcgen.SearchRegionsParams{
			Column1: &search,
			Limit:   limit,
		})
		if err != nil {
			slog.Error("failed to search regions", "error", err)
			RespondInternalError(w, r, "Failed to fetch regions")
			return
		}
		for _, row := range rows {
			regions = append(regions, Region{
				ID:          row.ID,
				Code:        row.Code,
				Name:        row.Name,
				CountryID:   int32(row.CountryID),
				CountryCode: row.CountryCode,
				CountryName: row.Country,
				CityCount:   row.CityCount,
			})
		}
	} else {
		// Filter by country code using SQLc
		rows, err := h.db.Queries.GetRegionsByCountry(ctx, countryCode)
		if err != nil {
			slog.Error("failed to get regions by country", "error", err)
			RespondInternalError(w, r, "Failed to fetch regions")
			return
		}
		for _, row := range rows {
			regions = append(regions, Region{
				ID:   row.ID,
				Code: row.Code,
				Name: row.Name,
			})
		}
	}

	if regions == nil {
		regions = []Region{}
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"regions": regions,
		"total":   len(regions),
	})
}

// Helper functions to convert SQLc rows to models

func coverageRowToModel(row sqlcgen.GetPublisherCoverageRow) models.PublisherCoverage {
	c := models.PublisherCoverage{
		ID:            row.ID,
		PublisherID:   row.PublisherID,
		CoverageLevel: row.CoverageLevel,
		ContinentCode: row.ContinentCode,
		CountryID:     row.CountryID,
		RegionID:      row.RegionID,
		DistrictID:    row.DistrictID,
		IsActive:      row.IsActive,
		CreatedAt:     row.CreatedAt.Time,
		UpdatedAt:     row.UpdatedAt.Time,
		ContinentName: row.ContinentName,
		CountryCode:   row.CountryCode,
		CountryName:   row.CountryName,
		RegionCode:    row.RegionCode,
		RegionName:    row.RegionName,
		DistrictCode:  row.DistrictCode,
		DistrictName:  row.DistrictName,
		CityName:      row.CityName,
	}
	if row.Priority != nil {
		c.Priority = int(*row.Priority)
	}
	if row.CityID.Valid {
		cityStr := row.CityID.Bytes[:]
		cityUUID, _ := uuid.FromBytes(cityStr)
		s := cityUUID.String()
		c.CityID = &s
	}
	return c
}

func createCoverageContinentRowToModel(row sqlcgen.CreateCoverageContinentRow) models.PublisherCoverage {
	c := models.PublisherCoverage{
		ID:            row.ID,
		PublisherID:   row.PublisherID,
		CoverageLevel: row.CoverageLevel,
		ContinentCode: row.ContinentCode,
		CountryID:     row.CountryID,
		RegionID:      row.RegionID,
		DistrictID:    row.DistrictID,
		IsActive:      row.IsActive,
		CreatedAt:     row.CreatedAt.Time,
		UpdatedAt:     row.UpdatedAt.Time,
	}
	if row.Priority != nil {
		c.Priority = int(*row.Priority)
	}
	if row.CityID.Valid {
		cityStr := row.CityID.Bytes[:]
		cityUUID, _ := uuid.FromBytes(cityStr)
		s := cityUUID.String()
		c.CityID = &s
	}
	return c
}

func createCoverageCountryRowToModel(row sqlcgen.CreateCoverageCountryRow) models.PublisherCoverage {
	c := models.PublisherCoverage{
		ID:            row.ID,
		PublisherID:   row.PublisherID,
		CoverageLevel: row.CoverageLevel,
		ContinentCode: row.ContinentCode,
		CountryID:     row.CountryID,
		RegionID:      row.RegionID,
		DistrictID:    row.DistrictID,
		IsActive:      row.IsActive,
		CreatedAt:     row.CreatedAt.Time,
		UpdatedAt:     row.UpdatedAt.Time,
	}
	if row.Priority != nil {
		c.Priority = int(*row.Priority)
	}
	if row.CityID.Valid {
		cityStr := row.CityID.Bytes[:]
		cityUUID, _ := uuid.FromBytes(cityStr)
		s := cityUUID.String()
		c.CityID = &s
	}
	return c
}

func createCoverageRegionRowToModel(row sqlcgen.CreateCoverageRegionRow) models.PublisherCoverage {
	c := models.PublisherCoverage{
		ID:            row.ID,
		PublisherID:   row.PublisherID,
		CoverageLevel: row.CoverageLevel,
		ContinentCode: row.ContinentCode,
		CountryID:     row.CountryID,
		RegionID:      row.RegionID,
		DistrictID:    row.DistrictID,
		IsActive:      row.IsActive,
		CreatedAt:     row.CreatedAt.Time,
		UpdatedAt:     row.UpdatedAt.Time,
	}
	if row.Priority != nil {
		c.Priority = int(*row.Priority)
	}
	if row.CityID.Valid {
		cityStr := row.CityID.Bytes[:]
		cityUUID, _ := uuid.FromBytes(cityStr)
		s := cityUUID.String()
		c.CityID = &s
	}
	return c
}

func createCoverageDistrictRowToModel(row sqlcgen.CreateCoverageDistrictRow) models.PublisherCoverage {
	c := models.PublisherCoverage{
		ID:            row.ID,
		PublisherID:   row.PublisherID,
		CoverageLevel: row.CoverageLevel,
		ContinentCode: row.ContinentCode,
		CountryID:     row.CountryID,
		RegionID:      row.RegionID,
		DistrictID:    row.DistrictID,
		IsActive:      row.IsActive,
		CreatedAt:     row.CreatedAt.Time,
		UpdatedAt:     row.UpdatedAt.Time,
	}
	if row.Priority != nil {
		c.Priority = int(*row.Priority)
	}
	if row.CityID.Valid {
		cityStr := row.CityID.Bytes[:]
		cityUUID, _ := uuid.FromBytes(cityStr)
		s := cityUUID.String()
		c.CityID = &s
	}
	return c
}

func createCoverageCityRowToModel(row sqlcgen.CreateCoverageCityRow) models.PublisherCoverage {
	c := models.PublisherCoverage{
		ID:            row.ID,
		PublisherID:   row.PublisherID,
		CoverageLevel: row.CoverageLevel,
		ContinentCode: row.ContinentCode,
		CountryID:     row.CountryID,
		RegionID:      row.RegionID,
		DistrictID:    row.DistrictID,
		IsActive:      row.IsActive,
		CreatedAt:     row.CreatedAt.Time,
		UpdatedAt:     row.UpdatedAt.Time,
	}
	if row.Priority != nil {
		c.Priority = int(*row.Priority)
	}
	if row.CityID.Valid {
		cityStr := row.CityID.Bytes[:]
		cityUUID, _ := uuid.FromBytes(cityStr)
		s := cityUUID.String()
		c.CityID = &s
	}
	return c
}

func updateCoverageRowToModel(row sqlcgen.UpdateCoveragePriorityRow) models.PublisherCoverage {
	c := models.PublisherCoverage{
		ID:            row.ID,
		PublisherID:   row.PublisherID,
		CoverageLevel: row.CoverageLevel,
		ContinentCode: row.ContinentCode,
		CountryID:     row.CountryID,
		RegionID:      row.RegionID,
		DistrictID:    row.DistrictID,
		IsActive:      row.IsActive,
		CreatedAt:     row.CreatedAt.Time,
		UpdatedAt:     row.UpdatedAt.Time,
	}
	if row.Priority != nil {
		c.Priority = int(*row.Priority)
	}
	if row.CityID.Valid {
		cityStr := row.CityID.Bytes[:]
		cityUUID, _ := uuid.FromBytes(cityStr)
		s := cityUUID.String()
		c.CityID = &s
	}
	return c
}

func updateCoverageActiveRowToModel(row sqlcgen.UpdateCoverageActiveRow) models.PublisherCoverage {
	c := models.PublisherCoverage{
		ID:            row.ID,
		PublisherID:   row.PublisherID,
		CoverageLevel: row.CoverageLevel,
		ContinentCode: row.ContinentCode,
		CountryID:     row.CountryID,
		RegionID:      row.RegionID,
		DistrictID:    row.DistrictID,
		IsActive:      row.IsActive,
		CreatedAt:     row.CreatedAt.Time,
		UpdatedAt:     row.UpdatedAt.Time,
	}
	if row.Priority != nil {
		c.Priority = int(*row.Priority)
	}
	if row.CityID.Valid {
		cityStr := row.CityID.Bytes[:]
		cityUUID, _ := uuid.FromBytes(cityStr)
		s := cityUUID.String()
		c.CityID = &s
	}
	return c
}
