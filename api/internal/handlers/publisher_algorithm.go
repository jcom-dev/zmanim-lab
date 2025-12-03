package handlers

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jcom-dev/zmanim-lab/internal/algorithm"
)

// AlgorithmResponse represents the algorithm configuration response
type AlgorithmResponse struct {
	ID            string                     `json:"id"`
	Name          string                     `json:"name"`
	Description   string                     `json:"description"`
	Configuration *algorithm.AlgorithmConfig `json:"configuration"`
	Version       int                        `json:"version"`
	Status        string                     `json:"status"`
	IsActive      bool                       `json:"is_active"`
	PublishedAt   *time.Time                 `json:"published_at,omitempty"`
	CreatedAt     time.Time                  `json:"created_at"`
	UpdatedAt     time.Time                  `json:"updated_at"`
}

// AlgorithmVersionResponse represents a version in the history
type AlgorithmVersionResponse struct {
	ID           string     `json:"id"`
	Name         string     `json:"name"`
	Version      int        `json:"version"`
	Status       string     `json:"status"`
	IsActive     bool       `json:"is_active"`
	PublishedAt  *time.Time `json:"published_at,omitempty"`
	DeprecatedAt *time.Time `json:"deprecated_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
}

// AlgorithmUpdateRequest represents the request to update an algorithm
type AlgorithmUpdateRequest struct {
	Name          string                    `json:"name,omitempty"`
	Description   string                    `json:"description,omitempty"`
	Configuration algorithm.AlgorithmConfig `json:"configuration"`
}

// AlgorithmPreviewRequest represents the request for algorithm preview
type AlgorithmPreviewRequest struct {
	Configuration algorithm.AlgorithmConfig `json:"configuration"`
	Date          string                    `json:"date,omitempty"`
	Latitude      float64                   `json:"latitude"`
	Longitude     float64                   `json:"longitude"`
	Timezone      string                    `json:"timezone"`
}

// AlgorithmPreviewResponse represents the preview calculation result
type AlgorithmPreviewResponse struct {
	Date     string             `json:"date"`
	Location ZmanimLocationInfo `json:"location"`
	Zmanim   []ZmanWithFormula  `json:"zmanim"`
}

// GetPublisherAlgorithmHandler returns the current publisher's algorithm configuration
func (h *Handlers) GetPublisherAlgorithmHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Get algorithm for this publisher (prefer draft, then published)
	var err error
	var algID, algName, description, status string
	var configJSON []byte
	var isActive bool
	var version int
	var publishedAt *time.Time
	var createdAt, updatedAt time.Time

	// First try to get draft
	query := `
		SELECT id, name, COALESCE(description, ''),
		       COALESCE(configuration::text, '{}')::jsonb,
		       COALESCE(validation_status, 'draft'), is_active,
		       COALESCE(CAST(SPLIT_PART(version, '.', 1) AS INTEGER), 1),
		       published_at, created_at, updated_at
		FROM algorithms
		WHERE publisher_id = $1 AND validation_status = 'draft'
		ORDER BY created_at DESC
		LIMIT 1
	`
	err = h.db.Pool.QueryRow(ctx, query, publisherID).Scan(
		&algID, &algName, &description, &configJSON, &status, &isActive,
		&version, &publishedAt, &createdAt, &updatedAt,
	)
	if err != nil {
		// No draft, try to get active/published algorithm
		query = `
			SELECT id, name, COALESCE(description, ''),
			       COALESCE(configuration::text, '{}')::jsonb,
			       COALESCE(validation_status, 'draft'), is_active,
			       COALESCE(CAST(SPLIT_PART(version, '.', 1) AS INTEGER), 1),
			       published_at, created_at, updated_at
			FROM algorithms
			WHERE publisher_id = $1 AND (is_active = true OR validation_status = 'published')
			ORDER BY created_at DESC
			LIMIT 1
		`
		err = h.db.Pool.QueryRow(ctx, query, publisherID).Scan(
			&algID, &algName, &description, &configJSON, &status, &isActive,
			&version, &publishedAt, &createdAt, &updatedAt,
		)
	}

	if err != nil {
		// No algorithm exists, return default configuration
		defaultAlg := algorithm.DefaultAlgorithm()
		RespondJSON(w, r, http.StatusOK, AlgorithmResponse{
			ID:            "",
			Name:          "Default Algorithm",
			Description:   "Standard zmanim calculation algorithm",
			Configuration: defaultAlg,
			Status:        "draft",
			IsActive:      false,
			CreatedAt:     time.Now(),
			UpdatedAt:     time.Now(),
		})
		return
	}

	// Parse configuration
	var config algorithm.AlgorithmConfig
	if len(configJSON) > 2 {
		if err := json.Unmarshal(configJSON, &config); err != nil {
			// Return default if parse fails
			config = *algorithm.DefaultAlgorithm()
		}
	} else {
		config = *algorithm.DefaultAlgorithm()
	}

	RespondJSON(w, r, http.StatusOK, AlgorithmResponse{
		ID:            algID,
		Name:          algName,
		Description:   description,
		Configuration: &config,
		Version:       version,
		Status:        status,
		IsActive:      isActive,
		PublishedAt:   publishedAt,
		CreatedAt:     createdAt,
		UpdatedAt:     updatedAt,
	})
}

// UpdatePublisherAlgorithmHandler updates the publisher's algorithm configuration
func (h *Handlers) UpdatePublisherAlgorithmHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Parse request body
	var req AlgorithmUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate configuration
	if err := algorithm.ValidateAlgorithm(&req.Configuration); err != nil {
		RespondValidationError(w, r, err.Error(), nil)
		return
	}

	// Convert configuration to JSON
	configJSON, err := json.Marshal(req.Configuration)
	if err != nil {
		RespondInternalError(w, r, "Failed to encode configuration")
		return
	}

	// Check for existing algorithms
	// Priority: 1. Update existing draft, 2. Create new draft if published exists, 3. Create first draft
	var draftID, publishedID string
	var draftStatus, publishedStatus string

	// Check for existing draft
	err = h.db.Pool.QueryRow(ctx,
		`SELECT id, validation_status FROM algorithms
		 WHERE publisher_id = $1 AND validation_status = 'draft'
		 ORDER BY created_at DESC LIMIT 1`,
		publisherID,
	).Scan(&draftID, &draftStatus)
	hasDraft := err == nil

	// Check for published algorithm (if no draft)
	if !hasDraft {
		err = h.db.Pool.QueryRow(ctx,
			`SELECT id, validation_status FROM algorithms
			 WHERE publisher_id = $1 AND is_active = true
			 ORDER BY created_at DESC LIMIT 1`,
			publisherID,
		).Scan(&publishedID, &publishedStatus)
	}
	hasPublished := publishedID != ""

	var algID string
	var createdAt, updatedAt time.Time

	algName := req.Name
	if algName == "" {
		algName = "Custom Algorithm"
	}
	description := req.Description
	if description == "" {
		description = "Custom zmanim calculation algorithm"
	}

	if hasDraft {
		// Update existing draft
		updateQuery := `
			UPDATE algorithms
			SET configuration = $1,
			    name = COALESCE(NULLIF($2, ''), name),
			    description = COALESCE(NULLIF($3, ''), description),
			    updated_at = NOW()
			WHERE id = $4
			RETURNING id, created_at, updated_at
		`
		err = h.db.Pool.QueryRow(ctx, updateQuery,
			configJSON, req.Name, req.Description, draftID,
		).Scan(&algID, &createdAt, &updatedAt)
		if err != nil {
			RespondInternalError(w, r, "Failed to update draft")
			return
		}
	} else if hasPublished {
		// Create new draft (published exists, changes saved as new draft)
		insertQuery := `
			INSERT INTO algorithms (
				publisher_id, name, description, configuration,
				version, calculation_type, validation_status, is_active
			)
			VALUES ($1, $2, $3, $4, '1.0.0', 'custom', 'draft', false)
			RETURNING id, created_at, updated_at
		`
		err = h.db.Pool.QueryRow(ctx, insertQuery,
			publisherID, algName, description, configJSON,
		).Scan(&algID, &createdAt, &updatedAt)
		if err != nil {
			RespondInternalError(w, r, "Failed to create draft")
			return
		}
	} else {
		// No algorithm exists - create first draft
		insertQuery := `
			INSERT INTO algorithms (
				publisher_id, name, description, configuration,
				version, calculation_type, validation_status, is_active
			)
			VALUES ($1, $2, $3, $4, '1.0.0', 'custom', 'draft', false)
			RETURNING id, created_at, updated_at
		`
		err = h.db.Pool.QueryRow(ctx, insertQuery,
			publisherID, algName, description, configJSON,
		).Scan(&algID, &createdAt, &updatedAt)
		if err != nil {
			RespondInternalError(w, r, "Failed to create algorithm")
			return
		}
	}

	RespondJSON(w, r, http.StatusOK, AlgorithmResponse{
		ID:            algID,
		Name:          req.Name,
		Description:   req.Description,
		Configuration: &req.Configuration,
		Status:        "draft",
		IsActive:      false,
		CreatedAt:     createdAt,
		UpdatedAt:     updatedAt,
	})
}

// PreviewAlgorithm calculates zmanim using the provided algorithm configuration
// POST /api/v1/publisher/algorithm/preview
func (h *Handlers) PreviewAlgorithm(w http.ResponseWriter, r *http.Request) {
	// Get user ID from context (optional - preview can be used without auth for demo)
	// Allow unauthenticated preview for demo purposes

	// Parse request body
	var req AlgorithmPreviewRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate configuration
	if err := algorithm.ValidateAlgorithm(&req.Configuration); err != nil {
		RespondValidationError(w, r, err.Error(), nil)
		return
	}

	// Default to today if no date specified
	dateStr := req.Date
	if dateStr == "" {
		dateStr = time.Now().Format("2006-01-02")
	}

	// Parse date
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		RespondBadRequest(w, r, "Invalid date format. Use YYYY-MM-DD")
		return
	}

	// Validate location
	if req.Latitude < -90 || req.Latitude > 90 {
		RespondBadRequest(w, r, "Latitude must be between -90 and 90")
		return
	}
	if req.Longitude < -180 || req.Longitude > 180 {
		RespondBadRequest(w, r, "Longitude must be between -180 and 180")
		return
	}

	// Default timezone
	timezone := req.Timezone
	if timezone == "" {
		timezone = "America/New_York"
	}

	// Load timezone
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		loc = time.UTC
		timezone = "UTC"
	}

	// Execute algorithm
	executor := algorithm.NewExecutor(date, req.Latitude, req.Longitude, loc)
	results, err := executor.Execute(&req.Configuration)
	if err != nil {
		RespondInternalError(w, r, "Failed to calculate zmanim: "+err.Error())
		return
	}

	// Build response
	response := AlgorithmPreviewResponse{
		Date: dateStr,
		Location: ZmanimLocationInfo{
			Latitude:  req.Latitude,
			Longitude: req.Longitude,
			Timezone:  timezone,
		},
		Zmanim: make([]ZmanWithFormula, 0, len(results.Zmanim)),
	}

	for _, zman := range results.Zmanim {
		response.Zmanim = append(response.Zmanim, ZmanWithFormula{
			Name: zman.Name,
			Key:  zman.Key,
			Time: zman.TimeString,
			Formula: FormulaDetails{
				Method:      zman.Formula.Method,
				DisplayName: zman.Formula.DisplayName,
				Parameters:  zman.Formula.Parameters,
				Explanation: zman.Formula.Explanation,
			},
		})
	}

	// Sort all zmanim by calculated time for chronological display
	sortZmanimByTime(response.Zmanim)

	RespondJSON(w, r, http.StatusOK, response)
}

// GetAlgorithmTemplates returns the available algorithm templates from the database
// GET /api/v1/publisher/algorithm/templates
func (h *Handlers) GetAlgorithmTemplates(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Fetch templates from database
	dbTemplates, err := h.db.Queries.GetAlgorithmTemplates(ctx)
	if err != nil {
		slog.Error("failed to fetch algorithm templates", "error", err)
		RespondInternalError(w, r, "Failed to fetch algorithm templates")
		return
	}

	// Transform database rows to API response format
	templates := make([]map[string]interface{}, 0, len(dbTemplates))
	for _, t := range dbTemplates {
		// Parse configuration JSON
		var config map[string]interface{}
		if err := json.Unmarshal(t.Configuration, &config); err != nil {
			slog.Error("failed to parse template configuration", "template_key", t.TemplateKey, "error", err)
			continue
		}

		description := ""
		if t.Description != nil {
			description = *t.Description
		}

		templates = append(templates, map[string]interface{}{
			"id":            t.TemplateKey,
			"name":          t.Name,
			"description":   description,
			"configuration": config,
		})
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"templates": templates,
	})
}

// GetZmanMethods returns available calculation methods for zmanim
// GET /api/v1/publisher/algorithm/methods
func (h *Handlers) GetZmanMethods(w http.ResponseWriter, r *http.Request) {
	methods := []map[string]interface{}{
		{
			"id":          "sunrise",
			"name":        "Sunrise",
			"description": "Standard sunrise time when the sun's upper edge crosses the horizon",
			"parameters":  []interface{}{},
		},
		{
			"id":          "sunset",
			"name":        "Sunset",
			"description": "Standard sunset time when the sun's upper edge crosses the horizon",
			"parameters":  []interface{}{},
		},
		{
			"id":          "solar_angle",
			"name":        "Solar Angle",
			"description": "Time when the sun is at a specific angle below the horizon",
			"parameters": []map[string]interface{}{
				{
					"name":        "degrees",
					"type":        "number",
					"description": "Degrees below horizon (e.g., 16.1 for alos, 8.5 for tzeis)",
					"required":    true,
					"min":         0,
					"max":         90,
				},
			},
		},
		{
			"id":          "fixed_minutes",
			"name":        "Fixed Minutes",
			"description": "A fixed number of minutes before or after a base time",
			"parameters": []map[string]interface{}{
				{
					"name":        "minutes",
					"type":        "number",
					"description": "Number of minutes (positive = after, negative = before)",
					"required":    true,
				},
				{
					"name":        "from",
					"type":        "select",
					"description": "Base time to calculate from",
					"required":    true,
					"options":     []string{"sunrise", "sunset", "alos", "tzeis"},
				},
			},
		},
		{
			"id":          "proportional",
			"name":        "Proportional Hours",
			"description": "Calculated based on proportional hours of the day",
			"parameters": []map[string]interface{}{
				{
					"name":        "hours",
					"type":        "number",
					"description": "Number of proportional hours from start of day",
					"required":    true,
					"min":         0,
					"max":         12,
				},
				{
					"name":        "base",
					"type":        "select",
					"description": "Base calculation method",
					"required":    true,
					"options":     []string{"gra", "mga"},
				},
			},
		},
		{
			"id":          "midpoint",
			"name":        "Midpoint",
			"description": "The midpoint between two times",
			"parameters": []map[string]interface{}{
				{
					"name":        "start",
					"type":        "select",
					"description": "Start time",
					"required":    true,
					"options":     []string{"sunrise", "sunset", "alos", "tzeis"},
				},
				{
					"name":        "end",
					"type":        "select",
					"description": "End time",
					"required":    true,
					"options":     []string{"sunrise", "sunset", "alos", "tzeis"},
				},
			},
		},
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"methods": methods,
	})
}

// PublishAlgorithm publishes the current draft algorithm
// POST /api/v1/publisher/algorithm/publish
func (h *Handlers) PublishAlgorithm(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Get the draft algorithm
	var algID, algName, description string
	var configJSON []byte
	var currentVersion int
	var err error

	query := `
		SELECT id, name, COALESCE(description, ''),
		       COALESCE(configuration::text, '{}')::jsonb,
		       COALESCE(CAST(SPLIT_PART(version, '.', 1) AS INTEGER), 1)
		FROM algorithms
		WHERE publisher_id = $1
		  AND (validation_status = 'draft' OR validation_status IS NULL)
		ORDER BY created_at DESC
		LIMIT 1
	`
	err = h.db.Pool.QueryRow(ctx, query, publisherID).Scan(
		&algID, &algName, &description, &configJSON, &currentVersion,
	)
	if err != nil {
		RespondNotFound(w, r, "No draft algorithm found to publish")
		return
	}

	// Validate configuration before publishing
	var config algorithm.AlgorithmConfig
	if err := json.Unmarshal(configJSON, &config); err != nil {
		RespondBadRequest(w, r, "Invalid algorithm configuration")
		return
	}

	if err := algorithm.ValidateAlgorithm(&config); err != nil {
		RespondValidationError(w, r, "Algorithm validation failed: "+err.Error(), nil)
		return
	}

	// Start transaction
	tx, err := h.db.Pool.Begin(ctx)
	if err != nil {
		RespondInternalError(w, r, "Failed to start transaction")
		return
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Archive any currently active algorithm
	_, err = tx.Exec(ctx, `
		UPDATE algorithms
		SET validation_status = 'archived', is_active = false, updated_at = NOW()
		WHERE publisher_id = $1 AND is_active = true
	`, publisherID)
	if err != nil {
		RespondInternalError(w, r, "Failed to archive current algorithm")
		return
	}

	// Publish the draft
	newVersion := currentVersion + 1
	var publishedAt time.Time
	var updatedAt time.Time

	err = tx.QueryRow(ctx, `
		UPDATE algorithms
		SET validation_status = 'published',
		    is_active = true,
		    version = $1,
		    published_at = NOW(),
		    updated_at = NOW()
		WHERE id = $2
		RETURNING published_at, updated_at
	`, newVersion, algID).Scan(&publishedAt, &updatedAt)
	if err != nil {
		RespondInternalError(w, r, "Failed to publish algorithm")
		return
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		RespondInternalError(w, r, "Failed to commit publish")
		return
	}

	// Invalidate cache for this publisher (zmanim calculations are now stale)
	if h.cache != nil {
		if err := h.cache.InvalidateZmanim(ctx, publisherID); err != nil {
			slog.Error("cache invalidation error after publish", "error", err)
		} else {
			slog.Info("cache invalidated after algorithm publish", "publisher_id", publisherID)
		}
		// Also invalidate algorithm cache
		if err := h.cache.InvalidateAlgorithm(ctx, publisherID); err != nil {
			slog.Error("algorithm cache invalidation error", "error", err)
		}
	}

	RespondJSON(w, r, http.StatusOK, AlgorithmResponse{
		ID:            algID,
		Name:          algName,
		Description:   description,
		Configuration: &config,
		Version:       newVersion,
		Status:        "published",
		IsActive:      true,
		PublishedAt:   &publishedAt,
		UpdatedAt:     updatedAt,
	})
}

// GetAlgorithmVersions returns the version history for the publisher's algorithm
// GET /api/v1/publisher/algorithm/versions
func (h *Handlers) GetAlgorithmVersions(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Get all versions
	query := `
		SELECT id, name,
		       COALESCE(CAST(SPLIT_PART(version, '.', 1) AS INTEGER), 1) as ver,
		       COALESCE(validation_status, 'draft'),
		       is_active,
		       published_at,
		       deprecated_at,
		       created_at
		FROM algorithms
		WHERE publisher_id = $1
		ORDER BY created_at DESC
	`

	rows, err := h.db.Pool.Query(ctx, query, publisherID)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch versions")
		return
	}
	defer rows.Close()

	versions := []AlgorithmVersionResponse{}
	for rows.Next() {
		var v AlgorithmVersionResponse
		var publishedAt, deprecatedAt *time.Time

		err := rows.Scan(
			&v.ID, &v.Name, &v.Version, &v.Status, &v.IsActive,
			&publishedAt, &deprecatedAt, &v.CreatedAt,
		)
		if err != nil {
			continue
		}

		v.PublishedAt = publishedAt
		v.DeprecatedAt = deprecatedAt
		versions = append(versions, v)
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"versions": versions,
		"total":    len(versions),
	})
}

// DeprecateAlgorithmVersion marks an algorithm version as deprecated
// PUT /api/v1/publisher/algorithm/versions/{id}/deprecate
func (h *Handlers) DeprecateAlgorithmVersion(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Get version ID from URL using chi
	versionID := chi.URLParam(r, "id")
	if versionID == "" {
		RespondBadRequest(w, r, "Version ID is required")
		return
	}

	// Verify version belongs to publisher and update
	result, err := h.db.Pool.Exec(ctx, `
		UPDATE algorithms
		SET validation_status = 'deprecated',
		    deprecated_at = NOW(),
		    updated_at = NOW()
		WHERE id = $1 AND publisher_id = $2
	`, versionID, publisherID)
	if err != nil {
		RespondInternalError(w, r, "Failed to deprecate version")
		return
	}

	if result.RowsAffected() == 0 {
		RespondNotFound(w, r, "Version not found")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"message":    "Version deprecated successfully",
		"version_id": versionID,
	})
}

// GetAlgorithmVersion returns a specific algorithm version
// GET /api/v1/publisher/algorithm/versions/{id}
func (h *Handlers) GetAlgorithmVersion(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Get version ID from URL using chi
	versionID := chi.URLParam(r, "id")
	if versionID == "" {
		RespondBadRequest(w, r, "Version ID is required")
		return
	}

	// Get version
	var algID, algName, description, status string
	var configJSON []byte
	var version int
	var isActive bool
	var publishedAt, deprecatedAt *time.Time
	var createdAt, updatedAt time.Time
	var err error

	query := `
		SELECT id, name, COALESCE(description, ''),
		       COALESCE(configuration::text, '{}')::jsonb,
		       COALESCE(CAST(SPLIT_PART(version, '.', 1) AS INTEGER), 1),
		       COALESCE(validation_status, 'draft'),
		       is_active,
		       published_at, deprecated_at,
		       created_at, updated_at
		FROM algorithms
		WHERE id = $1 AND publisher_id = $2
	`
	err = h.db.Pool.QueryRow(ctx, query, versionID, publisherID).Scan(
		&algID, &algName, &description, &configJSON, &version,
		&status, &isActive, &publishedAt, &deprecatedAt,
		&createdAt, &updatedAt,
	)
	if err != nil {
		RespondNotFound(w, r, "Version not found")
		return
	}

	var config algorithm.AlgorithmConfig
	_ = json.Unmarshal(configJSON, &config)

	RespondJSON(w, r, http.StatusOK, AlgorithmResponse{
		ID:            algID,
		Name:          algName,
		Description:   description,
		Configuration: &config,
		Version:       version,
		Status:        status,
		IsActive:      isActive,
		PublishedAt:   publishedAt,
		CreatedAt:     createdAt,
		UpdatedAt:     updatedAt,
	})
}
