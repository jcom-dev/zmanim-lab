package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/jcom-dev/zmanim-lab/internal/algorithm"
)

// AlgorithmResponse represents the algorithm configuration response
type AlgorithmResponse struct {
	ID            string                     `json:"id"`
	Name          string                     `json:"name"`
	Description   string                     `json:"description"`
	Configuration *algorithm.AlgorithmConfig `json:"configuration"`
	Status        string                     `json:"status"`
	IsActive      bool                       `json:"is_active"`
	CreatedAt     time.Time                  `json:"created_at"`
	UpdatedAt     time.Time                  `json:"updated_at"`
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
	Date      string                 `json:"date"`
	Location  ZmanimLocationInfo     `json:"location"`
	Zmanim    []ZmanWithFormula      `json:"zmanim"`
}

// GetPublisherAlgorithmHandler returns the current publisher's algorithm configuration
func (h *Handlers) GetPublisherAlgorithmHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get user ID from context
	userID, ok := ctx.Value("user_id").(string)
	if !ok || userID == "" {
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
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	// Get algorithm for this publisher
	var algID, algName, description, status string
	var configJSON []byte
	var isActive bool
	var createdAt, updatedAt time.Time

	query := `
		SELECT id, name, COALESCE(description, ''),
		       COALESCE(configuration::text, '{}')::jsonb,
		       COALESCE(validation_status, 'draft'), is_active,
		       created_at, updated_at
		FROM algorithms
		WHERE publisher_id = $1
		ORDER BY created_at DESC
		LIMIT 1
	`
	err = h.db.Pool.QueryRow(ctx, query, publisherID).Scan(
		&algID, &algName, &description, &configJSON, &status, &isActive, &createdAt, &updatedAt,
	)

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
		Status:        status,
		IsActive:      isActive,
		CreatedAt:     createdAt,
		UpdatedAt:     updatedAt,
	})
}

// UpdatePublisherAlgorithmHandler updates the publisher's algorithm configuration
func (h *Handlers) UpdatePublisherAlgorithmHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get user ID from context
	userID, ok := ctx.Value("user_id").(string)
	if !ok || userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

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

	// Get publisher ID
	var publisherID string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT id FROM publishers WHERE clerk_user_id = $1",
		userID,
	).Scan(&publisherID)
	if err != nil {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	// Convert configuration to JSON
	configJSON, err := json.Marshal(req.Configuration)
	if err != nil {
		RespondInternalError(w, r, "Failed to encode configuration")
		return
	}

	// Check if algorithm exists
	var existingID string
	err = h.db.Pool.QueryRow(ctx,
		"SELECT id FROM algorithms WHERE publisher_id = $1 LIMIT 1",
		publisherID,
	).Scan(&existingID)

	var algID string
	var createdAt, updatedAt time.Time

	if err != nil {
		// Insert new algorithm
		algName := req.Name
		if algName == "" {
			algName = "Custom Algorithm"
		}
		description := req.Description
		if description == "" {
			description = "Custom zmanim calculation algorithm"
		}

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
	} else {
		// Update existing algorithm
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
			configJSON, req.Name, req.Description, existingID,
		).Scan(&algID, &createdAt, &updatedAt)
		if err != nil {
			RespondInternalError(w, r, "Failed to update algorithm")
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
	ctx := r.Context()

	// Get user ID from context (optional - preview can be used without auth for demo)
	_, ok := ctx.Value("user_id").(string)
	if !ok {
		// Allow unauthenticated preview for demo purposes
	}

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

	RespondJSON(w, r, http.StatusOK, response)
}

// GetAlgorithmTemplates returns the available algorithm templates
// GET /api/v1/publisher/algorithm/templates
func (h *Handlers) GetAlgorithmTemplates(w http.ResponseWriter, r *http.Request) {
	templates := []map[string]interface{}{
		{
			"id":          "gra",
			"name":        "GRA (Vilna Gaon)",
			"description": "Standard calculation based on the Vilna Gaon. Uses sunrise to sunset for proportional hours.",
			"configuration": map[string]interface{}{
				"name":        "GRA",
				"description": "Vilna Gaon standard calculation",
				"zmanim": map[string]interface{}{
					"alos_hashachar":       map[string]interface{}{"method": "solar_angle", "params": map[string]interface{}{"degrees": 16.1}},
					"misheyakir":           map[string]interface{}{"method": "solar_angle", "params": map[string]interface{}{"degrees": 11.5}},
					"sunrise":              map[string]interface{}{"method": "sunrise", "params": map[string]interface{}{}},
					"sof_zman_shma_gra":    map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 3.0, "base": "gra"}},
					"sof_zman_tefilla_gra": map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 4.0, "base": "gra"}},
					"chatzos":              map[string]interface{}{"method": "midpoint", "params": map[string]interface{}{"start": "sunrise", "end": "sunset"}},
					"mincha_gedola":        map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 6.5, "base": "gra"}},
					"mincha_ketana":        map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 9.5, "base": "gra"}},
					"plag_hamincha":        map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 10.75, "base": "gra"}},
					"sunset":               map[string]interface{}{"method": "sunset", "params": map[string]interface{}{}},
					"tzeis_hakochavim":     map[string]interface{}{"method": "solar_angle", "params": map[string]interface{}{"degrees": 8.5}},
				},
			},
		},
		{
			"id":          "mga",
			"name":        "MGA (Magen Avraham)",
			"description": "Magen Avraham calculation. Uses 72 minutes before sunrise to 72 minutes after sunset for proportional hours.",
			"configuration": map[string]interface{}{
				"name":        "MGA",
				"description": "Magen Avraham calculation",
				"zmanim": map[string]interface{}{
					"alos_hashachar":       map[string]interface{}{"method": "fixed_minutes", "params": map[string]interface{}{"minutes": -72.0, "from": "sunrise"}},
					"misheyakir":           map[string]interface{}{"method": "solar_angle", "params": map[string]interface{}{"degrees": 11.5}},
					"sunrise":              map[string]interface{}{"method": "sunrise", "params": map[string]interface{}{}},
					"sof_zman_shma_mga":    map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 3.0, "base": "mga"}},
					"sof_zman_tefilla_mga": map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 4.0, "base": "mga"}},
					"chatzos":              map[string]interface{}{"method": "midpoint", "params": map[string]interface{}{"start": "sunrise", "end": "sunset"}},
					"mincha_gedola":        map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 6.5, "base": "mga"}},
					"mincha_ketana":        map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 9.5, "base": "mga"}},
					"plag_hamincha":        map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 10.75, "base": "mga"}},
					"sunset":               map[string]interface{}{"method": "sunset", "params": map[string]interface{}{}},
					"tzeis_72":             map[string]interface{}{"method": "fixed_minutes", "params": map[string]interface{}{"minutes": 72.0, "from": "sunset"}},
				},
			},
		},
		{
			"id":          "rabbeinu_tam",
			"name":        "Rabbeinu Tam",
			"description": "Uses 72 minutes after sunset for tzeis based on Rabbeinu Tam's opinion.",
			"configuration": map[string]interface{}{
				"name":        "Rabbeinu Tam",
				"description": "Rabbeinu Tam calculation for tzeis",
				"zmanim": map[string]interface{}{
					"alos_hashachar":       map[string]interface{}{"method": "solar_angle", "params": map[string]interface{}{"degrees": 16.1}},
					"misheyakir":           map[string]interface{}{"method": "solar_angle", "params": map[string]interface{}{"degrees": 11.5}},
					"sunrise":              map[string]interface{}{"method": "sunrise", "params": map[string]interface{}{}},
					"sof_zman_shma_gra":    map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 3.0, "base": "gra"}},
					"sof_zman_tefilla_gra": map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 4.0, "base": "gra"}},
					"chatzos":              map[string]interface{}{"method": "midpoint", "params": map[string]interface{}{"start": "sunrise", "end": "sunset"}},
					"mincha_gedola":        map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 6.5, "base": "gra"}},
					"mincha_ketana":        map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 9.5, "base": "gra"}},
					"plag_hamincha":        map[string]interface{}{"method": "proportional", "params": map[string]interface{}{"hours": 10.75, "base": "gra"}},
					"sunset":               map[string]interface{}{"method": "sunset", "params": map[string]interface{}{}},
					"tzeis_hakochavim":     map[string]interface{}{"method": "solar_angle", "params": map[string]interface{}{"degrees": 8.5}},
					"tzeis_72":             map[string]interface{}{"method": "fixed_minutes", "params": map[string]interface{}{"minutes": 72.0, "from": "sunset"}},
				},
			},
		},
		{
			"id":          "custom",
			"name":        "Custom",
			"description": "Start with basic times and customize each zman according to your minhag.",
			"configuration": map[string]interface{}{
				"name":        "Custom",
				"description": "Custom algorithm",
				"zmanim": map[string]interface{}{
					"sunrise": map[string]interface{}{"method": "sunrise", "params": map[string]interface{}{}},
					"chatzos": map[string]interface{}{"method": "midpoint", "params": map[string]interface{}{"start": "sunrise", "end": "sunset"}},
					"sunset":  map[string]interface{}{"method": "sunset", "params": map[string]interface{}{}},
				},
			},
		},
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
			"description": "Calculated based on shaos zmaniyos (proportional hours of the day)",
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
