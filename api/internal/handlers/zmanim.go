package handlers

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/jcom-dev/zmanim-lab/internal/algorithm"
	"github.com/jcom-dev/zmanim-lab/internal/astro"
	"github.com/jcom-dev/zmanim-lab/internal/calendar"
	"github.com/jcom-dev/zmanim-lab/internal/middleware"
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
	Date      string               `json:"date"`
	Location  ZmanimLocationInfo   `json:"location"`
	Publisher *ZmanimPublisherInfo `json:"publisher,omitempty"`
	Zmanim    []ZmanWithFormula    `json:"zmanim"`
	Cached    bool                 `json:"cached"`
	CachedAt  *time.Time           `json:"cached_at,omitempty"`
}

// ZmanimPublisherInfo contains publisher details for the response
type ZmanimPublisherInfo struct {
	ID      string  `json:"id"`
	Name    string  `json:"name"`
	LogoURL *string `json:"logo_url,omitempty"`
}

// ZmanimLocationInfo contains location details for the response
type ZmanimLocationInfo struct {
	CityID    string  `json:"city_id,omitempty"`
	CityName  string  `json:"city_name,omitempty"`
	Country   string  `json:"country,omitempty"`
	Region    *string `json:"region"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Timezone  string  `json:"timezone"`
}

// ZmanWithFormula represents a single zman with formula details
type ZmanWithFormula struct {
	Name    string         `json:"name"`
	Key     string         `json:"key"`
	Time    string         `json:"time"`
	IsBeta  bool           `json:"is_beta"`
	Formula FormulaDetails `json:"formula"`
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

	// Default publisher ID for cache key
	cachePublisherID := publisherID
	if cachePublisherID == "" {
		cachePublisherID = "default"
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

	// Check cache first (if available)
	if h.cache != nil {
		cached, err := h.cache.GetZmanim(ctx, cachePublisherID, cityID, dateStr)
		if err != nil {
			slog.Error("cache read error", "error", err)
		} else if cached != nil {
			// Return cached response
			var response ZmanimWithFormulaResponse
			if err := json.Unmarshal(cached.Data, &response); err == nil {
				response.Cached = true
				response.CachedAt = &cached.CachedAt
				RespondJSON(w, r, http.StatusOK, response)
				return
			}
		}
	}

	// Get city details
	var cityName, country, timezone string
	var region *string
	var latitude, longitude float64

	cityQuery := `
		SELECT c.name, co.name as country, r.name as region, c.timezone, c.latitude, c.longitude
		FROM cities c
		JOIN geo_countries co ON c.country_id = co.id
		LEFT JOIN geo_regions r ON c.region_id = r.id
		WHERE c.id = $1
	`
	err = h.db.Pool.QueryRow(ctx, cityQuery, cityID).Scan(
		&cityName, &country, &region, &timezone, &latitude, &longitude,
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

	// Get algorithm configuration and publisher info
	var algorithmConfig *algorithm.AlgorithmConfig
	var publisherInfo *ZmanimPublisherInfo
	if publisherID != "" {
		// First, get publisher info
		pubQuery := `SELECT name, logo_url FROM publishers WHERE id = $1`
		var pubName string
		var pubLogo *string
		err = h.db.Pool.QueryRow(ctx, pubQuery, publisherID).Scan(&pubName, &pubLogo)
		if err == nil {
			publisherInfo = &ZmanimPublisherInfo{
				ID:      publisherID,
				Name:    pubName,
				LogoURL: pubLogo,
			}
		}

		// Try to get publisher's algorithm
		algQuery := `
			SELECT configuration
			FROM algorithms
			WHERE publisher_id = $1 AND status = 'published'
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

	// Fetch beta status for zmanim if a publisher is specified
	betaStatusMap := make(map[string]bool)
	if publisherID != "" {
		betaQuery := `
			SELECT zman_key, is_beta
			FROM publisher_zmanim
			WHERE publisher_id = $1 AND deleted_at IS NULL AND is_beta = true
		`
		betaRows, betaErr := h.db.Pool.Query(ctx, betaQuery, publisherID)
		if betaErr == nil {
			defer betaRows.Close()
			for betaRows.Next() {
				var zmanKey string
				var isBeta bool
				if err := betaRows.Scan(&zmanKey, &isBeta); err == nil {
					betaStatusMap[zmanKey] = isBeta
				}
			}
		}
	}

	// Build response
	response := ZmanimWithFormulaResponse{
		Date: dateStr,
		Location: ZmanimLocationInfo{
			CityID:    cityID,
			CityName:  cityName,
			Country:   country,
			Region:    region,
			Latitude:  latitude,
			Longitude: longitude,
			Timezone:  timezone,
		},
		Publisher: publisherInfo,
		Zmanim:    make([]ZmanWithFormula, 0, len(results.Zmanim)),
		Cached:    false,
	}

	for _, zman := range results.Zmanim {
		response.Zmanim = append(response.Zmanim, ZmanWithFormula{
			Name:   zman.Name,
			Key:    zman.Key,
			Time:   zman.TimeString,
			IsBeta: betaStatusMap[zman.Key],
			Formula: FormulaDetails{
				Method:      zman.Formula.Method,
				DisplayName: zman.Formula.DisplayName,
				Parameters:  zman.Formula.Parameters,
				Explanation: zman.Formula.Explanation,
			},
		})
	}

	// Add event-based zmanim (candle lighting, havdalah)
	calService := calendar.NewCalendarService()
	isIsrael := calendar.IsLocationInIsrael(latitude, longitude)
	zmanimContext := calService.GetZmanimContext(date.In(loc), calendar.Location{
		Latitude:  latitude,
		Longitude: longitude,
		Timezone:  timezone,
		IsIsrael:  isIsrael,
	})

	// Get sunset time from executor
	sunTimes := executor.GetSunTimes()

	// Add candle lighting if needed (Friday or erev Yom Tov)
	if zmanimContext.ShowCandleLighting {
		// Default: 18 minutes before sunset
		candleLightingTime := astro.SubtractMinutes(sunTimes.Sunset, 18)
		response.Zmanim = append(response.Zmanim, ZmanWithFormula{
			Name:   "Candle Lighting",
			Key:    "candle_lighting",
			Time:   astro.FormatTime(candleLightingTime),
			IsBeta: false, // System-generated, never beta
			Formula: FormulaDetails{
				Method:      "fixed_minutes",
				DisplayName: "18 minutes before sunset",
				Parameters: map[string]interface{}{
					"minutes": -18,
					"from":    "sunset",
				},
				Explanation: "Traditional candle lighting time, 18 minutes before sunset",
			},
		})
	}

	// Add havdalah if needed (Motzei Shabbat or Motzei Yom Tov)
	if zmanimContext.ShowShabbosYomTovEnds {
		// Default: 42 minutes after sunset (8.5° below horizon approximation)
		havdalahTime := astro.AddMinutes(sunTimes.Sunset, 42)
		response.Zmanim = append(response.Zmanim, ZmanWithFormula{
			Name:   "Havdalah",
			Key:    "havdalah",
			Time:   astro.FormatTime(havdalahTime),
			IsBeta: false, // System-generated, never beta
			Formula: FormulaDetails{
				Method:      "fixed_minutes",
				DisplayName: "42 minutes after sunset",
				Parameters: map[string]interface{}{
					"minutes": 42,
					"from":    "sunset",
				},
				Explanation: "Traditional havdalah time, approximately 42 minutes after sunset",
			},
		})
	}

	// Cache the result (if cache available)
	if h.cache != nil {
		if err := h.cache.SetZmanim(ctx, cachePublisherID, cityID, dateStr, response); err != nil {
			slog.Error("cache write error", "error", err)
		}
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
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Get publisher ID from header or database lookup
	publisherID := r.Header.Get("X-Publisher-Id")
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

	var redisDeleted int64
	var dbDeleted int64

	// Invalidate Redis cache (if available)
	if h.cache != nil {
		if err := h.cache.InvalidateZmanim(ctx, publisherID); err != nil {
			slog.Error("redis cache invalidation error", "error", err)
		} else {
			slog.Info("redis cache invalidated", "publisher_id", publisherID)
			redisDeleted = 1 // Indicates success (actual count is logged by cache)
		}
		// Also invalidate algorithm cache
		if err := h.cache.InvalidateAlgorithm(ctx, publisherID); err != nil {
			slog.Error("redis algorithm cache invalidation error", "error", err)
		}
	}

	// Also clear database cache (legacy)
	query := `
		DELETE FROM calculation_cache
		WHERE algorithm_id IN (
			SELECT id FROM algorithms WHERE publisher_id = $1
		)
	`
	result, err := h.db.Pool.Exec(ctx, query, publisherID)
	if err != nil {
		slog.Error("database cache invalidation error", "error", err)
	} else {
		dbDeleted = result.RowsAffected()
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"message":            "Cache invalidated",
		"redis_invalidated":  redisDeleted > 0,
		"db_entries_deleted": dbDeleted,
	})
}
