package handlers

import (
	"net/http"
	"time"

	"github.com/jcom-dev/zmanim-lab/internal/calendar"
)

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
