package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jcom-dev/zmanim-lab/internal/db"
	"github.com/jcom-dev/zmanim-lab/internal/middleware"
	"github.com/jcom-dev/zmanim-lab/internal/models"
	"github.com/jcom-dev/zmanim-lab/internal/services"
)

// Handlers holds all HTTP handlers
type Handlers struct {
	db               *db.DB
	publisherService *services.PublisherService
	zmanimService    *services.ZmanimService
	clerkService     *services.ClerkService
	emailService     *services.EmailService
}

// New creates a new handlers instance
func New(database *db.DB) *Handlers {
	publisherService := services.NewPublisherService(database)
	zmanimService := services.NewZmanimService(database, publisherService)
	clerkService, err := services.NewClerkService()
	if err != nil {
		// Log error but continue - Clerk features will be disabled
		fmt.Printf("Warning: Clerk service initialization failed: %v\n", err)
	}
	emailService := services.NewEmailService()

	return &Handlers{
		db:               database,
		publisherService: publisherService,
		zmanimService:    zmanimService,
		clerkService:     clerkService,
		emailService:     emailService,
	}
}

// HealthCheck returns the health status of the API
func (h *Handlers) HealthCheck(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Check database health
	dbStatus := "ok"
	if err := h.db.Health(ctx); err != nil {
		dbStatus = "error: " + err.Error()
		RespondServiceUnavailable(w, r, "Database health check failed")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"status":   "ok",
		"database": dbStatus,
		"version":  "1.0.0",
	})
}

// GetPublishers returns a list of publishers
func (h *Handlers) GetPublishers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Parse query parameters
	page := 1
	pageSize := 20
	regionID := r.URL.Query().Get("region_id")

	if p := r.URL.Query().Get("page"); p != "" {
		if parsed, err := parseIntParam(p); err == nil && parsed > 0 {
			page = parsed
		}
	}

	if ps := r.URL.Query().Get("page_size"); ps != "" {
		if parsed, err := parseIntParam(ps); err == nil && parsed > 0 && parsed <= 100 {
			pageSize = parsed
		}
	}

	var regionPtr *string
	if regionID != "" {
		regionPtr = &regionID
	}

	publishers, err := h.publisherService.GetPublishers(ctx, page, pageSize, regionPtr)
	if err != nil {
		RespondInternalError(w, r, "Failed to get publishers")
		return
	}

	RespondJSON(w, r, http.StatusOK, publishers)
}

// GetPublisher returns a single publisher by ID
func (h *Handlers) GetPublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := chi.URLParam(r, "id")

	if id == "" {
		RespondValidationError(w, r, "Publisher ID is required", nil)
		return
	}

	publisher, err := h.publisherService.GetPublisherByID(ctx, id)
	if err != nil {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	RespondJSON(w, r, http.StatusOK, publisher)
}

// CalculateZmanim calculates zmanim for a given location and date
func (h *Handlers) CalculateZmanim(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req models.ZmanimRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate request
	validationErrors := make(map[string]string)
	if req.Date == "" {
		validationErrors["date"] = "Date is required"
	}
	if req.Latitude < -90 || req.Latitude > 90 {
		validationErrors["latitude"] = "Latitude must be between -90 and 90"
	}
	if req.Longitude < -180 || req.Longitude > 180 {
		validationErrors["longitude"] = "Longitude must be between -180 and 180"
	}
	if len(validationErrors) > 0 {
		RespondValidationError(w, r, "Invalid request parameters", validationErrors)
		return
	}

	if req.Timezone == "" {
		req.Timezone = "UTC"
	}

	response, err := h.zmanimService.CalculateZmanim(ctx, &req)
	if err != nil {
		RespondInternalError(w, r, "Failed to calculate zmanim")
		return
	}

	RespondJSON(w, r, http.StatusOK, response)
}

// GetLocations returns a list of predefined locations
func (h *Handlers) GetLocations(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Query geographic regions as locations
	query := `
		SELECT id, name,
		       ST_Y(ST_Centroid(bounds::geometry)) as latitude,
		       ST_X(ST_Centroid(bounds::geometry)) as longitude
		FROM geographic_regions
		WHERE type = 'city'
		ORDER BY name
		LIMIT 100
	`

	rows, err := h.db.Pool.Query(ctx, query)
	if err != nil {
		RespondInternalError(w, r, "Failed to get locations")
		return
	}
	defer rows.Close()

	var locations []map[string]interface{}
	for rows.Next() {
		var id, name string
		var latitude, longitude float64
		if err := rows.Scan(&id, &name, &latitude, &longitude); err != nil {
			continue
		}
		locations = append(locations, map[string]interface{}{
			"id":        id,
			"name":      name,
			"latitude":  latitude,
			"longitude": longitude,
			"timezone":  "UTC", // In production, derive from location
		})
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"locations": locations,
		"total":     len(locations),
	})
}

// Helper functions

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
	}
}

func respondError(w http.ResponseWriter, status int, message string, err error) {
	errorMsg := message
	if err != nil {
		errorMsg = message + ": " + err.Error()
	}

	response := models.ErrorResponse{
		Error:   http.StatusText(status),
		Message: errorMsg,
		Code:    status,
	}

	respondJSON(w, status, response)
}

func parseIntParam(s string) (int, error) {
	var i int
	err := json.Unmarshal([]byte(s), &i)
	return i, err
}

// GetPublisherProfile returns the current publisher's profile
func (h *Handlers) GetPublisherProfile(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get user ID from context (set by auth middleware)
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Query publisher by clerk_user_id
	query := `
		SELECT id, clerk_user_id, name, organization, email, description, bio,
		       website, logo_url, status, created_at, updated_at
		FROM publishers
		WHERE clerk_user_id = $1
	`

	var publisher models.Publisher
	err := h.db.Pool.QueryRow(ctx, query, userID).Scan(
		&publisher.ID,
		&publisher.ClerkUserID,
		&publisher.Name,
		&publisher.Organization,
		&publisher.Email,
		&publisher.Description,
		&publisher.Bio,
		&publisher.Website,
		&publisher.LogoURL,
		&publisher.Status,
		&publisher.CreatedAt,
		&publisher.UpdatedAt,
	)

	if err != nil {
		if err.Error() == "no rows in result set" {
			RespondNotFound(w, r, "Publisher profile not found")
			return
		}
		RespondInternalError(w, r, "Failed to fetch publisher profile")
		return
	}

	// Set derived fields
	publisher.IsVerified = publisher.Status == "verified"
	publisher.ContactEmail = publisher.Email

	RespondJSON(w, r, http.StatusOK, publisher)
}

// GetAccessiblePublishers returns publishers the current user has access to
// GET /api/publisher/accessible
func (h *Handlers) GetAccessiblePublishers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get user ID from context (set by auth middleware)
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// If no Clerk service, fall back to getting publisher by clerk_user_id
	if h.clerkService == nil {
		// Query publisher by clerk_user_id (legacy single-publisher mode)
		query := `
			SELECT id, name, organization, status
			FROM publishers
			WHERE clerk_user_id = $1
		`
		var id, name, organization, status string
		err := h.db.Pool.QueryRow(ctx, query, userID).Scan(&id, &name, &organization, &status)
		if err != nil {
			RespondJSON(w, r, http.StatusOK, map[string]interface{}{
				"publishers": []interface{}{},
			})
			return
		}

		RespondJSON(w, r, http.StatusOK, map[string]interface{}{
			"publishers": []map[string]string{{
				"id":           id,
				"name":         name,
				"organization": organization,
				"status":       status,
			}},
		})
		return
	}

	// Get user's publisher_access_list from Clerk
	metadata, err := h.clerkService.GetUserPublicMetadata(ctx, userID)
	if err != nil {
		// Fall back to database lookup
		query := `
			SELECT id, name, organization, status
			FROM publishers
			WHERE clerk_user_id = $1
		`
		var id, name, organization, status string
		err := h.db.Pool.QueryRow(ctx, query, userID).Scan(&id, &name, &organization, &status)
		if err != nil {
			RespondJSON(w, r, http.StatusOK, map[string]interface{}{
				"publishers": []interface{}{},
			})
			return
		}

		RespondJSON(w, r, http.StatusOK, map[string]interface{}{
			"publishers": []map[string]string{{
				"id":           id,
				"name":         name,
				"organization": organization,
				"status":       status,
			}},
		})
		return
	}

	// Extract publisher_access_list from metadata
	var publisherIDs []string
	if accessList, ok := metadata["publisher_access_list"].([]interface{}); ok {
		for _, v := range accessList {
			if s, ok := v.(string); ok {
				publisherIDs = append(publisherIDs, s)
			}
		}
	}

	// If no publisher access list, return empty array
	if len(publisherIDs) == 0 {
		RespondJSON(w, r, http.StatusOK, map[string]interface{}{
			"publishers": []interface{}{},
		})
		return
	}

	// Fetch publisher details from database
	query := `
		SELECT id, name, organization, status
		FROM publishers
		WHERE id = ANY($1)
		ORDER BY name
	`

	rows, err := h.db.Pool.Query(ctx, query, publisherIDs)
	if err != nil {
		RespondInternalError(w, r, "Failed to get publishers")
		return
	}
	defer rows.Close()

	publishers := make([]map[string]string, 0)
	for rows.Next() {
		var id, name, organization, status string
		if err := rows.Scan(&id, &name, &organization, &status); err != nil {
			continue
		}
		publishers = append(publishers, map[string]string{
			"id":           id,
			"name":         name,
			"organization": organization,
			"status":       status,
		})
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"publishers": publishers,
	})
}

// UpdatePublisherProfile updates the current publisher's profile
func (h *Handlers) UpdatePublisherProfile(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get user ID from context
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Parse request body
	var req models.PublisherProfileUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate required fields
	if req.Name != nil && *req.Name == "" {
		RespondBadRequest(w, r, "Name cannot be empty")
		return
	}
	if req.Email != nil && *req.Email == "" {
		RespondBadRequest(w, r, "Email cannot be empty")
		return
	}

	// Build update query dynamically
	updates := []string{}
	args := []interface{}{}
	argCount := 1

	if req.Name != nil {
		updates = append(updates, "name = $"+fmt.Sprint(argCount))
		args = append(args, *req.Name)
		argCount++
	}
	if req.Organization != nil {
		updates = append(updates, "organization = $"+fmt.Sprint(argCount))
		args = append(args, *req.Organization)
		argCount++
	}
	if req.Email != nil {
		updates = append(updates, "email = $"+fmt.Sprint(argCount))
		args = append(args, *req.Email)
		argCount++
	}
	if req.Website != nil {
		updates = append(updates, "website = $"+fmt.Sprint(argCount))
		args = append(args, *req.Website)
		argCount++
	}
	if req.Bio != nil {
		updates = append(updates, "bio = $"+fmt.Sprint(argCount))
		args = append(args, *req.Bio)
		argCount++
	}

	if len(updates) == 0 {
		RespondBadRequest(w, r, "No fields to update")
		return
	}

	// Add updated_at
	updates = append(updates, "updated_at = NOW()")

	// Add user_id for WHERE clause
	args = append(args, userID)

	// Execute update
	query := "UPDATE publishers SET " + strings.Join(updates, ", ") + " WHERE clerk_user_id = $" + fmt.Sprint(argCount) + " RETURNING id, clerk_user_id, name, organization, email, description, bio, website, logo_url, status, created_at, updated_at"

	var publisher models.Publisher
	err := h.db.Pool.QueryRow(ctx, query, args...).Scan(
		&publisher.ID,
		&publisher.ClerkUserID,
		&publisher.Name,
		&publisher.Organization,
		&publisher.Email,
		&publisher.Description,
		&publisher.Bio,
		&publisher.Website,
		&publisher.LogoURL,
		&publisher.Status,
		&publisher.CreatedAt,
		&publisher.UpdatedAt,
	)

	if err != nil {
		if err.Error() == "no rows in result set" {
			RespondNotFound(w, r, "Publisher profile not found")
			return
		}
		RespondInternalError(w, r, "Failed to update publisher profile")
		return
	}

	publisher.IsVerified = publisher.Status == "verified"
	publisher.ContactEmail = publisher.Email

	RespondJSON(w, r, http.StatusOK, publisher)
}

// GetPublisherActivity returns the activity log for the publisher
// GET /api/publisher/activity
func (h *Handlers) GetPublisherActivity(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get user ID from context
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Get publisher ID from header or query
	publisherID := r.Header.Get("X-Publisher-Id")
	if publisherID == "" {
		publisherID = r.URL.Query().Get("publisher_id")
	}

	// If no publisher ID provided, get from database using clerk_user_id
	if publisherID == "" {
		err := h.db.Pool.QueryRow(ctx,
			"SELECT id FROM publishers WHERE clerk_user_id = $1",
			userID,
		).Scan(&publisherID)
		if err != nil {
			RespondNotFound(w, r, "Publisher not found")
			return
		}
	}

	// For now, return empty activities (will be populated when activity_logs table is created)
	// Parse limit/offset
	limit := 50
	offset := 0
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := parseIntParam(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}
	if o := r.URL.Query().Get("offset"); o != "" {
		if parsed, err := parseIntParam(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	// Placeholder response - will query activity_logs table when created
	activities := []map[string]interface{}{}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"activities":  activities,
		"total":       0,
		"limit":       limit,
		"offset":      offset,
		"next_offset": nil,
	})
}

// GetPublisherAnalytics returns analytics for the publisher
// GET /api/publisher/analytics
func (h *Handlers) GetPublisherAnalytics(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get user ID from context
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Get publisher ID from header or query
	publisherID := r.Header.Get("X-Publisher-Id")
	if publisherID == "" {
		publisherID = r.URL.Query().Get("publisher_id")
	}

	// If no publisher ID provided, get from database using clerk_user_id
	if publisherID == "" {
		err := h.db.Pool.QueryRow(ctx,
			"SELECT id FROM publishers WHERE clerk_user_id = $1",
			userID,
		).Scan(&publisherID)
		if err != nil {
			RespondNotFound(w, r, "Publisher not found")
			return
		}
	}

	// Get coverage counts
	var coverageAreas int
	h.db.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM publisher_coverage
		WHERE publisher_id = $1 AND is_active = true
	`, publisherID).Scan(&coverageAreas)

	// Estimate cities count
	var citiesCovered int
	h.db.Pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(
			CASE coverage_level
				WHEN 'city' THEN 1
				WHEN 'region' THEN (SELECT COUNT(*) FROM cities c WHERE c.region = pc.region AND c.country_code = pc.country_code)
				WHEN 'country' THEN (SELECT COUNT(*) FROM cities c WHERE c.country_code = pc.country_code)
				ELSE 0
			END
		), 0)
		FROM publisher_coverage pc
		WHERE publisher_id = $1 AND is_active = true
	`, publisherID).Scan(&citiesCovered)

	// For now, calculations are placeholders (will be implemented with calculation_logs table)
	calculationsTotal := 0
	calculationsThisMonth := 0

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"calculations_total":      calculationsTotal,
		"calculations_this_month": calculationsThisMonth,
		"coverage_areas":          coverageAreas,
		"cities_covered":          citiesCovered,
	})
}

// GetPublisherDashboardSummary returns a summary of the publisher's dashboard data
// GET /api/publisher/dashboard
func (h *Handlers) GetPublisherDashboardSummary(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get user ID from context
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Get publisher ID from header or query
	publisherID := r.Header.Get("X-Publisher-Id")
	if publisherID == "" {
		publisherID = r.URL.Query().Get("publisher_id")
	}

	// If no publisher ID provided, get from database using clerk_user_id
	if publisherID == "" {
		err := h.db.Pool.QueryRow(ctx,
			"SELECT id FROM publishers WHERE clerk_user_id = $1",
			userID,
		).Scan(&publisherID)
		if err != nil {
			RespondNotFound(w, r, "Publisher not found")
			return
		}
	}

	// Get profile summary
	var profileSummary struct {
		Name         string `json:"name"`
		Organization string `json:"organization"`
		IsVerified   bool   `json:"is_verified"`
		Status       string `json:"status"`
	}
	err := h.db.Pool.QueryRow(ctx, `
		SELECT name, organization, status = 'verified', status
		FROM publishers WHERE id = $1
	`, publisherID).Scan(&profileSummary.Name, &profileSummary.Organization, &profileSummary.IsVerified, &profileSummary.Status)
	if err != nil {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	// Get algorithm summary
	var algorithmSummary struct {
		Status    string  `json:"status"`
		Name      *string `json:"name"`
		UpdatedAt *string `json:"updated_at"`
	}
	algorithmSummary.Status = "none" // default if no algorithm
	h.db.Pool.QueryRow(ctx, `
		SELECT
			CASE WHEN is_published THEN 'published' ELSE 'draft' END,
			name,
			TO_CHAR(updated_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		FROM publisher_algorithms
		WHERE publisher_id = $1
		ORDER BY updated_at DESC
		LIMIT 1
	`, publisherID).Scan(&algorithmSummary.Status, &algorithmSummary.Name, &algorithmSummary.UpdatedAt)

	// Get coverage summary
	var coverageSummary struct {
		TotalAreas  int `json:"total_areas"`
		TotalCities int `json:"total_cities"`
	}
	h.db.Pool.QueryRow(ctx, `
		SELECT COUNT(*), 0
		FROM publisher_coverage
		WHERE publisher_id = $1 AND is_active = true
	`, publisherID).Scan(&coverageSummary.TotalAreas, &coverageSummary.TotalCities)

	// Estimate cities count based on coverage type
	h.db.Pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(
			CASE coverage_level
				WHEN 'city' THEN 1
				WHEN 'region' THEN (SELECT COUNT(*) FROM cities c WHERE c.region = pc.region AND c.country_code = pc.country_code)
				WHEN 'country' THEN (SELECT COUNT(*) FROM cities c WHERE c.country_code = pc.country_code)
				ELSE 0
			END
		), 0)
		FROM publisher_coverage pc
		WHERE publisher_id = $1 AND is_active = true
	`, publisherID).Scan(&coverageSummary.TotalCities)

	// Analytics placeholder (will be enhanced in Story 2-7)
	var analyticsSummary struct {
		CalculationsThisMonth int `json:"calculations_this_month"`
		CalculationsTotal     int `json:"calculations_total"`
	}
	// For now, return 0 - will be implemented with analytics tables
	analyticsSummary.CalculationsThisMonth = 0
	analyticsSummary.CalculationsTotal = 0

	// Recent activity placeholder (will be enhanced in Story 2-8)
	recentActivity := []map[string]interface{}{}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"profile":         profileSummary,
		"algorithm":       algorithmSummary,
		"coverage":        coverageSummary,
		"analytics":       analyticsSummary,
		"recent_activity": recentActivity,
	})
}
