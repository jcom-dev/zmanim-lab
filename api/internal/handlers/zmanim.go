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
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Logo        *string `json:"logo,omitempty"`        // Base64 data URL
	IsCertified bool    `json:"is_certified"`          // Whether this is a certified/authoritative source
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
	Name         string         `json:"name"`
	HebrewName   string         `json:"hebrew_name,omitempty"`
	Key          string         `json:"key"`
	Time         string         `json:"time"`
	IsBeta       bool           `json:"is_beta"`
	IsCore       bool           `json:"is_core"`
	TimeCategory string         `json:"time_category,omitempty"`
	Tags         []ZmanTag      `json:"tags,omitempty"`
	Formula      FormulaDetails `json:"formula"`
}

// FormulaDetails contains information about how a zman was calculated
type FormulaDetails struct {
	Method      string                 `json:"method"`
	DisplayName string                 `json:"display_name"`
	DSL         string                 `json:"dsl,omitempty"`
	Parameters  map[string]interface{} `json:"parameters"`
	Explanation string                 `json:"explanation"`
	HalachicSource string              `json:"halachic_source,omitempty"`
}

// GetZmanimForCity calculates zmanim for a city with formula details
// @Summary Get zmanim for a city
// @Description Calculates Jewish prayer times (zmanim) for a specific city and date, optionally using a publisher's custom algorithm
// @Tags Zmanim
// @Accept json
// @Produce json
// @Param cityId query string true "City ID from the cities database"
// @Param publisherId query string false "Publisher ID for custom algorithm (uses default if not specified)"
// @Param date query string false "Date in YYYY-MM-DD format (defaults to today)"
// @Success 200 {object} APIResponse{data=ZmanimWithFormulaResponse} "Calculated zmanim with formula details"
// @Failure 400 {object} APIResponse{error=APIError} "Invalid parameters"
// @Failure 404 {object} APIResponse{error=APIError} "City not found"
// @Failure 500 {object} APIResponse{error=APIError} "Internal server error"
// @Router /zmanim [get]
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
		JOIN geo_regions r ON c.region_id = r.id
		JOIN geo_countries co ON r.country_id = co.id
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
		// First, get publisher info (logo_data is the base64 embedded logo)
		pubQuery := `SELECT name, logo_data, is_certified FROM publishers WHERE id = $1`
		var pubName string
		var pubLogo *string
		var isCertified bool
		err = h.db.Pool.QueryRow(ctx, pubQuery, publisherID).Scan(&pubName, &pubLogo, &isCertified)
		if err == nil {
			publisherInfo = &ZmanimPublisherInfo{
				ID:          publisherID,
				Name:        pubName,
				Logo:        pubLogo,
				IsCertified: isCertified,
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

	// Fetch metadata for all zmanim from master registry (database is source of truth)
	type zmanMetadata struct {
		TimeCategory string
		HebrewName   string
		EnglishName  string
		DSL          string
		IsCore       bool
		HalachicSource string
	}
	zmanMetadataMap := make(map[string]zmanMetadata)
	metadataQuery := `SELECT zman_key, COALESCE(time_category, ''), COALESCE(canonical_hebrew_name, ''), COALESCE(canonical_english_name, ''), COALESCE(default_formula_dsl, ''), is_core, COALESCE(halachic_source, '') FROM master_zmanim_registry`
	metadataRows, metadataErr := h.db.Pool.Query(ctx, metadataQuery)
	if metadataErr == nil {
		defer metadataRows.Close()
		for metadataRows.Next() {
			var zmanKey, timeCategory, hebrewName, englishName, dsl, halachicSource string
			var isCore bool
			if err := metadataRows.Scan(&zmanKey, &timeCategory, &hebrewName, &englishName, &dsl, &isCore, &halachicSource); err == nil {
				zmanMetadataMap[zmanKey] = zmanMetadata{
					TimeCategory: timeCategory,
					HebrewName:   hebrewName,
					EnglishName:  englishName,
					DSL:          dsl,
					IsCore:       isCore,
					HalachicSource: halachicSource,
				}
			}
		}
	}

	// Fetch tags for all zmanim
	tagsMap := make(map[string][]ZmanTag)
	tagsQuery := `
		SELECT mr.zman_key, t.id, t.tag_key, t.name, t.display_name_english, t.display_name_hebrew, t.tag_type, t.color, t.sort_order, t.created_at
		FROM master_zmanim_registry mr
		JOIN master_zman_tags mzt ON mr.id = mzt.master_zman_id
		JOIN zman_tags t ON mzt.tag_id = t.id
		ORDER BY mr.zman_key, t.tag_type, t.sort_order
	`
	tagsRows, tagsErr := h.db.Pool.Query(ctx, tagsQuery)
	if tagsErr == nil {
		defer tagsRows.Close()
		for tagsRows.Next() {
			var zmanKey string
			var tag ZmanTag
			var description *string
			if err := tagsRows.Scan(&zmanKey, &tag.ID, &tag.TagKey, &tag.Name, &tag.DisplayNameEnglish, &tag.DisplayNameHebrew, &tag.TagType, &tag.Color, &tag.SortOrder, &tag.CreatedAt); err == nil {
				tag.Description = description
				tagsMap[zmanKey] = append(tagsMap[zmanKey], tag)
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
		metadata := zmanMetadataMap[zman.Key]
		// Use database English name if available, otherwise log warning and use key
		englishName := metadata.EnglishName
		if englishName == "" {
			slog.Warn("missing english name in master_zmanim_registry", "zman_key", zman.Key)
			englishName = zman.Key // Fallback to key (no hardcoded names)
		}
		response.Zmanim = append(response.Zmanim, ZmanWithFormula{
			Name:         englishName,
			HebrewName:   metadata.HebrewName,
			Key:          zman.Key,
			Time:         zman.TimeString,
			IsBeta:       betaStatusMap[zman.Key],
			IsCore:       metadata.IsCore,
			TimeCategory: metadata.TimeCategory,
			Tags:         tagsMap[zman.Key],
			Formula: FormulaDetails{
				Method:      zman.Formula.Method,
				DisplayName: zman.Formula.DisplayName,
				DSL:         metadata.DSL,
				Parameters:  zman.Formula.Parameters,
				Explanation: zman.Formula.Explanation,
				HalachicSource: metadata.HalachicSource,
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
		// Get Hebrew name from master registry - NO FALLBACK (database is source of truth)
		candleMetadata := zmanMetadataMap["candle_lighting"]
		candleHebrewName := candleMetadata.HebrewName
		if candleHebrewName == "" {
			slog.Warn("missing hebrew name in master_zmanim_registry", "zman_key", "candle_lighting")
		}
		response.Zmanim = append(response.Zmanim, ZmanWithFormula{
			Name:         "Candle Lighting",
			HebrewName:   candleHebrewName,
			Key:          "candle_lighting",
			Time:         astro.FormatTime(candleLightingTime),
			IsBeta:       false,    // System-generated, never beta
			TimeCategory: "sunset", // Candle lighting is near sunset
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
		// Get Hebrew name from master registry - NO FALLBACK (database is source of truth)
		havdalahMetadata := zmanMetadataMap["havdalah"]
		havdalahHebrewName := havdalahMetadata.HebrewName
		if havdalahHebrewName == "" {
			slog.Warn("missing hebrew name in master_zmanim_registry", "zman_key", "havdalah")
		}
		response.Zmanim = append(response.Zmanim, ZmanWithFormula{
			Name:         "Havdalah",
			HebrewName:   havdalahHebrewName,
			Key:          "havdalah",
			Time:         astro.FormatTime(havdalahTime),
			IsBeta:       false,       // System-generated, never beta
			TimeCategory: "nightfall", // Havdalah is after nightfall
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

	// Sort all zmanim by calculated time for chronological display
	sortZmanimByTime(response.Zmanim)

	// Cache the result (if cache available)
	if h.cache != nil {
		if err := h.cache.SetZmanim(ctx, cachePublisherID, cityID, dateStr, response); err != nil {
			slog.Error("cache write error", "error", err)
		}
	}

	RespondJSON(w, r, http.StatusOK, response)
}

// GetZmanimByCoordinates calculates zmanim for coordinates (legacy)
// @Summary Calculate zmanim by coordinates (legacy)
// @Description Calculates zmanim using raw latitude/longitude coordinates. Prefer the GET /zmanim endpoint with cityId for better accuracy.
// @Tags Zmanim
// @Accept json
// @Produce json
// @Param request body models.ZmanimRequest true "Coordinates and date"
// @Success 200 {object} APIResponse{data=ZmanimWithFormulaResponse} "Calculated zmanim"
// @Failure 400 {object} APIResponse{error=APIError} "Invalid request"
// @Failure 500 {object} APIResponse{error=APIError} "Internal server error"
// @Router /zmanim [post]
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
// @Summary Invalidate publisher cache
// @Description Clears all cached zmanim calculations for the authenticated publisher
// @Tags Publisher
// @Produce json
// @Security BearerAuth
// @Param X-Publisher-Id header string true "Publisher ID"
// @Success 200 {object} APIResponse{data=object} "Cache invalidated"
// @Failure 401 {object} APIResponse{error=APIError} "Unauthorized"
// @Failure 404 {object} APIResponse{error=APIError} "Publisher not found"
// @Router /publisher/cache [delete]
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
		if err := h.cache.InvalidatePublisherCache(ctx, publisherID); err != nil {
			slog.Error("redis cache invalidation error", "error", err)
		} else {
			slog.Info("redis cache invalidated", "publisher_id", publisherID)
			redisDeleted = 1 // Indicates success (actual count is logged by cache)
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
