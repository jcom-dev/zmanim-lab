package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/jcom-dev/zmanim-lab/internal/algorithm"
	"github.com/jcom-dev/zmanim-lab/internal/models"
)

// ZmanimRequest represents a request for zmanim calculations
type ZmanimRequestParams struct {
	CityID      string `json:"city_id"`
	PublisherID string `json:"publisher_id,omitempty"`
	Date        string `json:"date"` // YYYY-MM-DD format
}

// ZmanimWithFormulaResponse represents the enhanced zmanim response
type ZmanimWithFormulaResponse struct {
	Date     string                    `json:"date"`
	Location ZmanimLocationInfo        `json:"location"`
	Zmanim   []ZmanWithFormula         `json:"zmanim"`
	Cached   bool                      `json:"cached"`
	CachedAt *time.Time                `json:"cached_at,omitempty"`
}

// ZmanimLocationInfo contains location details for the response
type ZmanimLocationInfo struct {
	CityID    string  `json:"city_id,omitempty"`
	CityName  string  `json:"city_name,omitempty"`
	Country   string  `json:"country,omitempty"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Timezone  string  `json:"timezone"`
}

// ZmanWithFormula represents a single zman with formula details
type ZmanWithFormula struct {
	Name       string                 `json:"name"`
	Key        string                 `json:"key"`
	Time       string                 `json:"time"`
	Formula    FormulaDetails         `json:"formula"`
}

// FormulaDetails contains information about how a zman was calculated
type FormulaDetails struct {
	Method      string                 `json:"method"`
	DisplayName string                 `json:"display_name"`
	Parameters  map[string]interface{} `json:"parameters"`
	Explanation string                 `json:"explanation"`
}

// GetZmanimForCity calculates zmanim for a city with formula details
// GET /api/v1/zmanim?cityId={cityId}&publisherId={publisherId}&date={date}
func (h *Handlers) GetZmanimForCity(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Parse query parameters
	cityID := r.URL.Query().Get("cityId")
	publisherID := r.URL.Query().Get("publisherId")
	dateStr := r.URL.Query().Get("date")

	// Validate required parameters
	if cityID == "" {
		RespondBadRequest(w, r, "cityId parameter is required")
		return
	}

	// Default to today if no date specified
	if dateStr == "" {
		dateStr = time.Now().Format("2006-01-02")
	}

	// Parse date
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		RespondBadRequest(w, r, "Invalid date format. Use YYYY-MM-DD")
		return
	}

	// Get city details
	var cityName, country, timezone string
	var latitude, longitude float64

	cityQuery := `
		SELECT name, country, timezone, latitude, longitude
		FROM cities
		WHERE id = $1
	`
	err = h.db.Pool.QueryRow(ctx, cityQuery, cityID).Scan(
		&cityName, &country, &timezone, &latitude, &longitude,
	)
	if err != nil {
		RespondNotFound(w, r, "City not found")
		return
	}

	// Load timezone
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		loc = time.UTC
		timezone = "UTC"
	}

	// Get algorithm configuration
	var algorithmConfig *algorithm.AlgorithmConfig
	if publisherID != "" {
		// Try to get publisher's algorithm
		algQuery := `
			SELECT a.configuration
			FROM algorithms a
			JOIN publishers p ON a.publisher_id = p.id
			WHERE p.id = $1 AND a.is_active = true
			LIMIT 1
		`
		var configJSON []byte
		err = h.db.Pool.QueryRow(ctx, algQuery, publisherID).Scan(&configJSON)
		if err == nil && len(configJSON) > 2 {
			algorithmConfig, _ = algorithm.ParseAlgorithm(configJSON)
		}
	}

	// Use default algorithm if none found
	if algorithmConfig == nil {
		algorithmConfig = algorithm.DefaultAlgorithm()
	}

	// Execute algorithm
	executor := algorithm.NewExecutor(date, latitude, longitude, loc)
	results, err := executor.Execute(algorithmConfig)
	if err != nil {
		RespondInternalError(w, r, "Failed to calculate zmanim")
		return
	}

	// Build response
	response := ZmanimWithFormulaResponse{
		Date: dateStr,
		Location: ZmanimLocationInfo{
			CityID:    cityID,
			CityName:  cityName,
			Country:   country,
			Latitude:  latitude,
			Longitude: longitude,
			Timezone:  timezone,
		},
		Zmanim: make([]ZmanWithFormula, 0, len(results.Zmanim)),
		Cached: false,
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

// GetZmanimByCoordinates calculates zmanim for coordinates
// POST /api/v1/zmanim - existing endpoint, kept for backward compatibility
func (h *Handlers) GetZmanimByCoordinates(w http.ResponseWriter, r *http.Request) {
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

// InvalidatePublisherCache invalidates cached calculations for a publisher
// DELETE /api/v1/publisher/cache
func (h *Handlers) InvalidatePublisherCache(w http.ResponseWriter, r *http.Request) {
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

	// Delete cached calculations for this publisher's algorithms
	query := `
		DELETE FROM calculation_cache
		WHERE algorithm_id IN (
			SELECT id FROM algorithms WHERE publisher_id = $1
		)
	`
	result, err := h.db.Pool.Exec(ctx, query, publisherID)
	if err != nil {
		RespondInternalError(w, r, "Failed to invalidate cache")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"message":         "Cache invalidated",
		"entries_deleted": result.RowsAffected(),
	})
}
