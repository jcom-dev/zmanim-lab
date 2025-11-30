package handlers

import (
	"net/http"
	"time"

	"github.com/jcom-dev/zmanim-lab/internal/calendar"
)

// ============================================
// TYPES FOR EVENT MODEL
// ============================================

// JewishEventResponse represents a Jewish event for API responses
type JewishEventResponse struct {
	ID                   string  `json:"id"`
	Code                 string  `json:"code"`
	NameHebrew           string  `json:"name_hebrew"`
	NameEnglish          string  `json:"name_english"`
	EventType            string  `json:"event_type"`
	DurationDaysIsrael   int     `json:"duration_days_israel"`
	DurationDaysDiaspora int     `json:"duration_days_diaspora"`
	FastStartType        *string `json:"fast_start_type,omitempty"`
	ParentEventCode      *string `json:"parent_event_code,omitempty"`
	SortOrder            int     `json:"sort_order"`
}

// ZmanDisplayContext represents a context-specific display name for a zman
type ZmanDisplayContext struct {
	ID                 string `json:"id"`
	ContextCode        string `json:"context_code"`
	DisplayNameHebrew  string `json:"display_name_hebrew"`
	DisplayNameEnglish string `json:"display_name_english"`
	SortOrder          int    `json:"sort_order"`
}

// WeekCalendarResponse represents the weekly calendar API response
type WeekCalendarResponse struct {
	StartDate string             `json:"start_date"`
	EndDate   string             `json:"end_date"`
	Days      []calendar.DayInfo `json:"days"`
}

// GetWeekCalendar returns Hebrew calendar data for a week
// GET /api/calendar/week?date=YYYY-MM-DD
func (h *Handlers) GetWeekCalendar(w http.ResponseWriter, r *http.Request) {
	// Parse date parameter
	dateStr := r.URL.Query().Get("date")
	var startDate time.Time
	var err error

	if dateStr != "" {
		startDate, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			RespondBadRequest(w, r, "Invalid date format. Use YYYY-MM-DD")
			return
		}
	} else {
		startDate = time.Now()
	}

	// Get week info
	calendarSvc := calendar.NewCalendarService()
	weekInfo := calendarSvc.GetWeekInfo(startDate)

	RespondJSON(w, r, http.StatusOK, WeekCalendarResponse{
		StartDate: weekInfo.StartDate,
		EndDate:   weekInfo.EndDate,
		Days:      weekInfo.Days,
	})
}

// GetHebrewDate returns the Hebrew date for a given Gregorian date
// GET /api/calendar/hebrew-date?date=YYYY-MM-DD
func (h *Handlers) GetHebrewDate(w http.ResponseWriter, r *http.Request) {
	dateStr := r.URL.Query().Get("date")
	var date time.Time
	var err error

	if dateStr != "" {
		date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			RespondBadRequest(w, r, "Invalid date format. Use YYYY-MM-DD")
			return
		}
	} else {
		date = time.Now()
	}

	calendarSvc := calendar.NewCalendarService()
	hebrewDate := calendarSvc.GetHebrewDate(date)

	RespondJSON(w, r, http.StatusOK, hebrewDate)
}

// GetShabbatTimes returns Shabbat times for a given location and date
// GET /api/calendar/shabbat?date=YYYY-MM-DD&lat=31.7683&lon=35.2137&tz=Asia/Jerusalem
func (h *Handlers) GetShabbatTimes(w http.ResponseWriter, r *http.Request) {
	dateStr := r.URL.Query().Get("date")
	latStr := r.URL.Query().Get("lat")
	lonStr := r.URL.Query().Get("lon")
	tzName := r.URL.Query().Get("tz")

	if tzName == "" {
		tzName = "UTC"
	}

	var date time.Time
	var err error

	if dateStr != "" {
		date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			RespondBadRequest(w, r, "Invalid date format. Use YYYY-MM-DD")
			return
		}
	} else {
		date = time.Now()
	}

	// Parse coordinates
	var lat, lon float64
	if latStr != "" {
		_, err = parseFloat(latStr, &lat)
		if err != nil {
			RespondBadRequest(w, r, "Invalid latitude")
			return
		}
	} else {
		lat = 31.7683 // Jerusalem default
	}

	if lonStr != "" {
		_, err = parseFloat(lonStr, &lon)
		if err != nil {
			RespondBadRequest(w, r, "Invalid longitude")
			return
		}
	} else {
		lon = 35.2137 // Jerusalem default
	}

	calendarSvc := calendar.NewCalendarService()
	shabbatTimes := calendarSvc.GetShabbatTimes(date, lat, lon, tzName)

	RespondJSON(w, r, http.StatusOK, shabbatTimes)
}

// GetGregorianDate converts a Hebrew date to Gregorian
// GET /api/calendar/gregorian-date?year=5785&month=9&day=1
func (h *Handlers) GetGregorianDate(w http.ResponseWriter, r *http.Request) {
	yearStr := r.URL.Query().Get("year")
	monthStr := r.URL.Query().Get("month")
	dayStr := r.URL.Query().Get("day")

	if yearStr == "" || monthStr == "" || dayStr == "" {
		RespondBadRequest(w, r, "year, month, and day parameters are required")
		return
	}

	calendarSvc := calendar.NewCalendarService()
	gregorianDate, err := calendarSvc.HebrewToGregorian(yearStr, monthStr, dayStr)
	if err != nil {
		RespondBadRequest(w, r, err.Error())
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]string{
		"date": gregorianDate,
	})
}

// parseFloat is a helper to parse float strings
func parseFloat(s string, f *float64) (bool, error) {
	n, err := parseFloatValue(s)
	if err != nil {
		return false, err
	}
	*f = n
	return true, nil
}

func parseFloatValue(s string) (float64, error) {
	// Simple float parsing
	var result float64
	var sign float64 = 1
	var decimal float64 = 0
	var decimalPlaces float64 = 1

	i := 0
	if len(s) > 0 && s[0] == '-' {
		sign = -1
		i++
	}

	for ; i < len(s); i++ {
		c := s[i]
		if c == '.' {
			decimal = 1
			continue
		}
		if c < '0' || c > '9' {
			break
		}
		digit := float64(c - '0')
		if decimal > 0 {
			decimalPlaces *= 10
			result = result + digit/decimalPlaces
		} else {
			result = result*10 + digit
		}
	}

	return sign * result, nil
}

// ============================================
// JEWISH EVENTS HANDLERS (NEW EVENT MODEL)
// ============================================

// GetJewishEvents returns all Jewish events from the database
// GET /api/v1/calendar/events
func (h *Handlers) GetJewishEvents(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	eventType := r.URL.Query().Get("type")

	var events []JewishEventResponse

	if eventType != "" {
		rows, err := h.db.Pool.Query(ctx, `
			SELECT id, code, name_hebrew, name_english, event_type,
				duration_days_israel, duration_days_diaspora,
				fast_start_type, parent_event_code, sort_order
			FROM jewish_events
			WHERE event_type = $1
			ORDER BY sort_order, name_english
		`, eventType)
		if err != nil {
			RespondInternalError(w, r, "Failed to get Jewish events")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var e JewishEventResponse
			if err := rows.Scan(
				&e.ID, &e.Code, &e.NameHebrew, &e.NameEnglish, &e.EventType,
				&e.DurationDaysIsrael, &e.DurationDaysDiaspora,
				&e.FastStartType, &e.ParentEventCode, &e.SortOrder,
			); err != nil {
				continue
			}
			events = append(events, e)
		}
	} else {
		rows, err := h.db.Pool.Query(ctx, `
			SELECT id, code, name_hebrew, name_english, event_type,
				duration_days_israel, duration_days_diaspora,
				fast_start_type, parent_event_code, sort_order
			FROM jewish_events
			ORDER BY sort_order, name_english
		`)
		if err != nil {
			RespondInternalError(w, r, "Failed to get Jewish events")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var e JewishEventResponse
			if err := rows.Scan(
				&e.ID, &e.Code, &e.NameHebrew, &e.NameEnglish, &e.EventType,
				&e.DurationDaysIsrael, &e.DurationDaysDiaspora,
				&e.FastStartType, &e.ParentEventCode, &e.SortOrder,
			); err != nil {
				continue
			}
			events = append(events, e)
		}
	}

	if events == nil {
		events = []JewishEventResponse{}
	}

	RespondJSON(w, r, http.StatusOK, events)
}

// GetEventDayInfo returns event information for a specific date and location
// GET /api/v1/calendar/day-info?date=YYYY-MM-DD&latitude=X&longitude=Y
func (h *Handlers) GetEventDayInfo(w http.ResponseWriter, r *http.Request) {
	// Parse query parameters
	dateStr := r.URL.Query().Get("date")
	latStr := r.URL.Query().Get("latitude")
	lonStr := r.URL.Query().Get("longitude")
	timezone := r.URL.Query().Get("timezone")

	// Validate required parameters
	validationErrors := make(map[string]string)
	if dateStr == "" {
		validationErrors["date"] = "Date is required (YYYY-MM-DD format)"
	}
	if latStr == "" {
		validationErrors["latitude"] = "Latitude is required"
	}
	if lonStr == "" {
		validationErrors["longitude"] = "Longitude is required"
	}

	if len(validationErrors) > 0 {
		RespondValidationError(w, r, "Missing required parameters", validationErrors)
		return
	}

	// Parse date
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		RespondBadRequest(w, r, "Invalid date format. Use YYYY-MM-DD")
		return
	}

	// Parse latitude
	var latitude float64
	if _, err := parseFloat(latStr, &latitude); err != nil {
		RespondBadRequest(w, r, "Invalid latitude value")
		return
	}

	// Parse longitude
	var longitude float64
	if _, err := parseFloat(lonStr, &longitude); err != nil {
		RespondBadRequest(w, r, "Invalid longitude value")
		return
	}

	// Validate coordinate ranges
	if latitude < -90 || latitude > 90 {
		RespondBadRequest(w, r, "Latitude must be between -90 and 90")
		return
	}
	if longitude < -180 || longitude > 180 {
		RespondBadRequest(w, r, "Longitude must be between -180 and 180")
		return
	}

	if timezone == "" {
		timezone = "UTC"
	}

	// Create location
	loc := calendar.Location{
		Latitude:  latitude,
		Longitude: longitude,
		Timezone:  timezone,
		IsIsrael:  calendar.IsLocationInIsrael(latitude, longitude),
	}

	// Get calendar service and day info
	calendarService := calendar.NewCalendarService()
	dayInfo := calendarService.GetEventDayInfo(date, loc)

	RespondJSON(w, r, http.StatusOK, dayInfo)
}

// GetZmanimContext returns the zmanim context for a specific date and location
// GET /api/v1/calendar/zmanim-context?date=YYYY-MM-DD&latitude=X&longitude=Y
func (h *Handlers) GetZmanimContext(w http.ResponseWriter, r *http.Request) {
	// Parse query parameters
	dateStr := r.URL.Query().Get("date")
	latStr := r.URL.Query().Get("latitude")
	lonStr := r.URL.Query().Get("longitude")
	timezone := r.URL.Query().Get("timezone")

	// Validate required parameters
	validationErrors := make(map[string]string)
	if dateStr == "" {
		validationErrors["date"] = "Date is required (YYYY-MM-DD format)"
	}
	if latStr == "" {
		validationErrors["latitude"] = "Latitude is required"
	}
	if lonStr == "" {
		validationErrors["longitude"] = "Longitude is required"
	}

	if len(validationErrors) > 0 {
		RespondValidationError(w, r, "Missing required parameters", validationErrors)
		return
	}

	// Parse date
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		RespondBadRequest(w, r, "Invalid date format. Use YYYY-MM-DD")
		return
	}

	// Parse latitude
	var latitude float64
	if _, err := parseFloat(latStr, &latitude); err != nil {
		RespondBadRequest(w, r, "Invalid latitude value")
		return
	}

	// Parse longitude
	var longitude float64
	if _, err := parseFloat(lonStr, &longitude); err != nil {
		RespondBadRequest(w, r, "Invalid longitude value")
		return
	}

	// Validate coordinate ranges
	if latitude < -90 || latitude > 90 {
		RespondBadRequest(w, r, "Latitude must be between -90 and 90")
		return
	}
	if longitude < -180 || longitude > 180 {
		RespondBadRequest(w, r, "Longitude must be between -180 and 180")
		return
	}

	if timezone == "" {
		timezone = "UTC"
	}

	// Create location
	loc := calendar.Location{
		Latitude:  latitude,
		Longitude: longitude,
		Timezone:  timezone,
		IsIsrael:  calendar.IsLocationInIsrael(latitude, longitude),
	}

	// Get calendar service and zmanim context
	calendarService := calendar.NewCalendarService()
	zmanimContext := calendarService.GetZmanimContext(date, loc)

	RespondJSON(w, r, http.StatusOK, zmanimContext)
}

// GetWeekEventInfo returns event information for a week starting from a date
// GET /api/v1/calendar/week-events?start_date=YYYY-MM-DD&latitude=X&longitude=Y
func (h *Handlers) GetWeekEventInfo(w http.ResponseWriter, r *http.Request) {
	// Parse query parameters
	startDateStr := r.URL.Query().Get("start_date")
	latStr := r.URL.Query().Get("latitude")
	lonStr := r.URL.Query().Get("longitude")
	timezone := r.URL.Query().Get("timezone")

	// Validate required parameters
	validationErrors := make(map[string]string)
	if startDateStr == "" {
		validationErrors["start_date"] = "Start date is required (YYYY-MM-DD format)"
	}
	if latStr == "" {
		validationErrors["latitude"] = "Latitude is required"
	}
	if lonStr == "" {
		validationErrors["longitude"] = "Longitude is required"
	}

	if len(validationErrors) > 0 {
		RespondValidationError(w, r, "Missing required parameters", validationErrors)
		return
	}

	// Parse date
	startDate, err := time.Parse("2006-01-02", startDateStr)
	if err != nil {
		RespondBadRequest(w, r, "Invalid date format. Use YYYY-MM-DD")
		return
	}

	// Parse latitude
	var latitude float64
	if _, err := parseFloat(latStr, &latitude); err != nil {
		RespondBadRequest(w, r, "Invalid latitude value")
		return
	}

	// Parse longitude
	var longitude float64
	if _, err := parseFloat(lonStr, &longitude); err != nil {
		RespondBadRequest(w, r, "Invalid longitude value")
		return
	}

	// Validate coordinate ranges
	if latitude < -90 || latitude > 90 {
		RespondBadRequest(w, r, "Latitude must be between -90 and 90")
		return
	}
	if longitude < -180 || longitude > 180 {
		RespondBadRequest(w, r, "Longitude must be between -180 and 180")
		return
	}

	if timezone == "" {
		timezone = "UTC"
	}

	// Create location
	loc := calendar.Location{
		Latitude:  latitude,
		Longitude: longitude,
		Timezone:  timezone,
		IsIsrael:  calendar.IsLocationInIsrael(latitude, longitude),
	}

	// Get calendar service
	calendarService := calendar.NewCalendarService()

	// Get info for each day of the week
	weekInfo := make(map[string]calendar.EventDayInfo)
	for i := 0; i < 7; i++ {
		date := startDate.AddDate(0, 0, i)
		dateKey := date.Format("2006-01-02")
		weekInfo[dateKey] = calendarService.GetEventDayInfo(date, loc)
	}

	RespondJSON(w, r, http.StatusOK, weekInfo)
}

// ============================================
// REGISTRY HANDLERS WITH EVENT FILTERING
// ============================================

// GetMasterZmanimByEvent returns zmanim filtered by Jewish event
// GET /api/v1/registry/zmanim/by-event?event_code=shabbos
func (h *Handlers) GetMasterZmanimByEvent(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	eventCode := r.URL.Query().Get("event_code")
	if eventCode == "" {
		RespondBadRequest(w, r, "event_code parameter is required")
		return
	}

	dayNumberStr := r.URL.Query().Get("day_number")
	var dayNumber *int
	if dayNumberStr != "" {
		dn, err := parseIntParam(dayNumberStr)
		if err != nil {
			RespondBadRequest(w, r, "Invalid day_number value")
			return
		}
		dayNumber = &dn
	}

	var zmanim []MasterZman

	if dayNumber != nil {
		// Filter by specific day number
		rows, err := h.db.Pool.Query(ctx, `
			SELECT DISTINCT mr.id, mr.zman_key, mr.canonical_hebrew_name, mr.canonical_english_name,
				mr.transliteration, mr.description, mr.halachic_notes, mr.halachic_source,
				mr.time_category, mr.default_formula_dsl, mr.is_core, mr.sort_order,
				mr.created_at, mr.updated_at
			FROM master_zmanim_registry mr
			JOIN master_zman_events mze ON mr.id = mze.master_zman_id
			JOIN jewish_events je ON je.id = mze.jewish_event_id
			WHERE je.code = $1
				AND mze.is_default = true
				AND (mze.applies_to_day IS NULL OR mze.applies_to_day = $2)
			ORDER BY mr.time_category, mr.sort_order
		`, eventCode, *dayNumber)
		if err != nil {
			RespondInternalError(w, r, "Failed to get zmanim")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var z MasterZman
			if err := rows.Scan(
				&z.ID, &z.ZmanKey, &z.CanonicalHebrewName, &z.CanonicalEnglishName,
				&z.Transliteration, &z.Description, &z.HalachicNotes, &z.HalachicSource,
				&z.TimeCategory, &z.DefaultFormulaDSL, &z.IsCore, &z.SortOrder,
				&z.CreatedAt, &z.UpdatedAt,
			); err != nil {
				continue
			}
			zmanim = append(zmanim, z)
		}
	} else {
		// Get all zmanim for event
		rows, err := h.db.Pool.Query(ctx, `
			SELECT DISTINCT mr.id, mr.zman_key, mr.canonical_hebrew_name, mr.canonical_english_name,
				mr.transliteration, mr.description, mr.halachic_notes, mr.halachic_source,
				mr.time_category, mr.default_formula_dsl, mr.is_core, mr.sort_order,
				mr.created_at, mr.updated_at
			FROM master_zmanim_registry mr
			JOIN master_zman_events mze ON mr.id = mze.master_zman_id
			JOIN jewish_events je ON je.id = mze.jewish_event_id
			WHERE je.code = $1 AND mze.is_default = true
			ORDER BY mr.time_category, mr.sort_order
		`, eventCode)
		if err != nil {
			RespondInternalError(w, r, "Failed to get zmanim")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var z MasterZman
			if err := rows.Scan(
				&z.ID, &z.ZmanKey, &z.CanonicalHebrewName, &z.CanonicalEnglishName,
				&z.Transliteration, &z.Description, &z.HalachicNotes, &z.HalachicSource,
				&z.TimeCategory, &z.DefaultFormulaDSL, &z.IsCore, &z.SortOrder,
				&z.CreatedAt, &z.UpdatedAt,
			); err != nil {
				continue
			}
			zmanim = append(zmanim, z)
		}
	}

	if zmanim == nil {
		zmanim = []MasterZman{}
	}

	RespondJSON(w, r, http.StatusOK, zmanim)
}

// GetZmanDisplayContexts returns display contexts for a zman
// GET /api/v1/registry/zmanim/{zmanKey}/display-contexts
func (h *Handlers) GetZmanDisplayContexts(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	zmanKey := r.URL.Query().Get("zman_key")

	if zmanKey == "" {
		RespondBadRequest(w, r, "zman_key is required")
		return
	}

	rows, err := h.db.Pool.Query(ctx, `
		SELECT zdc.id, zdc.context_code, zdc.display_name_hebrew, zdc.display_name_english, zdc.sort_order
		FROM zman_display_contexts zdc
		JOIN master_zmanim_registry mr ON mr.id = zdc.master_zman_id
		WHERE mr.zman_key = $1
		ORDER BY zdc.sort_order
	`, zmanKey)
	if err != nil {
		RespondInternalError(w, r, "Failed to get display contexts")
		return
	}
	defer rows.Close()

	var contexts []ZmanDisplayContext
	for rows.Next() {
		var c ZmanDisplayContext
		if err := rows.Scan(&c.ID, &c.ContextCode, &c.DisplayNameHebrew, &c.DisplayNameEnglish, &c.SortOrder); err != nil {
			continue
		}
		contexts = append(contexts, c)
	}

	if contexts == nil {
		contexts = []ZmanDisplayContext{}
	}

	RespondJSON(w, r, http.StatusOK, contexts)
}

// GetZmanApplicableEvents returns which Jewish events a zman applies to
// GET /api/v1/registry/zmanim/{zmanKey}/events
func (h *Handlers) GetZmanApplicableEvents(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	zmanKey := r.URL.Query().Get("zman_key")

	if zmanKey == "" {
		RespondBadRequest(w, r, "zman_key is required")
		return
	}

	rows, err := h.db.Pool.Query(ctx, `
		SELECT je.id, je.code, je.name_hebrew, je.name_english, je.event_type,
			je.duration_days_israel, je.duration_days_diaspora,
			je.fast_start_type, je.parent_event_code, je.sort_order,
			mze.applies_to_day, mze.is_default, mze.notes
		FROM jewish_events je
		JOIN master_zman_events mze ON je.id = mze.jewish_event_id
		JOIN master_zmanim_registry mr ON mr.id = mze.master_zman_id
		WHERE mr.zman_key = $1
		ORDER BY je.sort_order
	`, zmanKey)
	if err != nil {
		RespondInternalError(w, r, "Failed to get applicable events")
		return
	}
	defer rows.Close()

	var events []map[string]interface{}
	for rows.Next() {
		var e JewishEventResponse
		var appliesToDay *int
		var isDefault bool
		var notes *string

		if err := rows.Scan(
			&e.ID, &e.Code, &e.NameHebrew, &e.NameEnglish, &e.EventType,
			&e.DurationDaysIsrael, &e.DurationDaysDiaspora,
			&e.FastStartType, &e.ParentEventCode, &e.SortOrder,
			&appliesToDay, &isDefault, &notes,
		); err != nil {
			continue
		}

		eventMap := map[string]interface{}{
			"event":          e,
			"applies_to_day": appliesToDay,
			"is_default":     isDefault,
			"notes":          notes,
		}
		events = append(events, eventMap)
	}

	if events == nil {
		events = []map[string]interface{}{}
	}

	RespondJSON(w, r, http.StatusOK, events)
}
