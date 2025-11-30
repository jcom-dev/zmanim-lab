package calendar

import (
	"fmt"
	"math"
	"time"

	"github.com/hebcal/hdate"
	"github.com/hebcal/hebcal-go/event"
	"github.com/hebcal/hebcal-go/hebcal"
)

// HebrewDate represents a date in the Hebrew calendar
type HebrewDate struct {
	Day       int    `json:"day"`
	Month     string `json:"month"`
	MonthNum  int    `json:"month_num"`
	Year      int    `json:"year"`
	Hebrew    string `json:"hebrew"`    // כ"ג כסלו תשפ"ה
	Formatted string `json:"formatted"` // 23 Kislev 5785
}

// Holiday represents a Jewish holiday or event
type Holiday struct {
	Name       string `json:"name"`
	NameHebrew string `json:"name_hebrew"`
	Category   string `json:"category"` // "major", "minor", "shabbat", "roshchodesh", "fast"
	Candles    bool   `json:"candles"`  // Should light candles
	Yomtov     bool   `json:"yomtov"`   // Is yom tov
	Desc       string `json:"desc,omitempty"`
}

// DayInfo contains information about a single day
type DayInfo struct {
	Date          string     `json:"date"` // ISO 8601 format
	HebrewDate    HebrewDate `json:"hebrew_date"`
	DayOfWeek     int        `json:"day_of_week"`
	DayNameHebrew string     `json:"day_name_hebrew"`
	DayNameEng    string     `json:"day_name_eng"`
	Holidays      []Holiday  `json:"holidays"`
	IsShabbat     bool       `json:"is_shabbat"`
	IsYomTov      bool       `json:"is_yomtov"`
}

// ShabbatTimes contains Shabbat-specific times
type ShabbatTimes struct {
	CandleLighting string `json:"candle_lighting,omitempty"`
	Havdalah       string `json:"havdalah,omitempty"`
}

// WeekInfo contains a week's worth of day information
type WeekInfo struct {
	StartDate string    `json:"start_date"`
	EndDate   string    `json:"end_date"`
	Days      []DayInfo `json:"days"`
}

// Hebrew day names
var hebrewDayNames = []string{
	"יום ראשון",  // Sunday
	"יום שני",    // Monday
	"יום שלישי",  // Tuesday
	"יום רביעי",  // Wednesday
	"יום חמישי",  // Thursday
	"יום שישי",   // Friday
	"שבת קודש",   // Shabbat
}

var englishDayNames = []string{
	"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Shabbat",
}

// Hebrew month names
var hebrewMonthNames = map[hdate.HMonth]string{
	hdate.Nisan:    "ניסן",
	hdate.Iyyar:    "אייר",
	hdate.Sivan:    "סיון",
	hdate.Tamuz:    "תמוז",
	hdate.Av:       "אב",
	hdate.Elul:     "אלול",
	hdate.Tishrei:  "תשרי",
	hdate.Cheshvan: "חשון",
	hdate.Kislev:   "כסלו",
	hdate.Tevet:    "טבת",
	hdate.Shvat:    "שבט",
	hdate.Adar1:    "אדר",
	hdate.Adar2:    "אדר ב׳",
}

// CalendarService provides Hebrew calendar functionality
type CalendarService struct{}

// NewCalendarService creates a new calendar service
func NewCalendarService() *CalendarService {
	return &CalendarService{}
}

// HebrewToGregorian converts a Hebrew date to Gregorian date string
func (s *CalendarService) HebrewToGregorian(yearStr, monthStr, dayStr string) (string, error) {
	var year, month, day int
	_, err := fmt.Sscanf(yearStr, "%d", &year)
	if err != nil {
		return "", fmt.Errorf("invalid year: %s", yearStr)
	}
	_, err = fmt.Sscanf(monthStr, "%d", &month)
	if err != nil {
		return "", fmt.Errorf("invalid month: %s", monthStr)
	}
	_, err = fmt.Sscanf(dayStr, "%d", &day)
	if err != nil {
		return "", fmt.Errorf("invalid day: %s", dayStr)
	}

	// Create Hebrew date and convert to Gregorian
	hd := hdate.New(year, hdate.HMonth(month), day)
	gregorian := hd.Gregorian()
	return gregorian.Format("2006-01-02"), nil
}

// GetHebrewDate converts a Gregorian date to Hebrew date
func (s *CalendarService) GetHebrewDate(date time.Time) HebrewDate {
	hd := hdate.FromTime(date)

	// Format Hebrew string manually
	hebrewMonth := hebrewMonthNames[hd.Month()]
	hebrewStr := fmt.Sprintf("%s %s %d", formatHebrewDay(hd.Day()), hebrewMonth, hd.Year())
	engStr := fmt.Sprintf("%d %s %d", hd.Day(), hd.MonthName("en"), hd.Year())

	return HebrewDate{
		Day:       hd.Day(),
		Month:     hd.MonthName("en"),
		MonthNum:  int(hd.Month()),
		Year:      hd.Year(),
		Hebrew:    hebrewStr,
		Formatted: engStr,
	}
}

// formatHebrewDay formats a day number in Hebrew letters
func formatHebrewDay(day int) string {
	// Simple numeric representation for now
	// In production, use gematriya for full Hebrew numerals
	return fmt.Sprintf("%d", day)
}

// GetDayInfo returns complete information for a given date
func (s *CalendarService) GetDayInfo(date time.Time) DayInfo {
	dow := int(date.Weekday())
	hd := s.GetHebrewDate(date)
	holidays := s.GetHolidays(date)

	// Check if any holiday is yom tov
	isYomTov := false
	for _, h := range holidays {
		if h.Yomtov {
			isYomTov = true
			break
		}
	}

	return DayInfo{
		Date:          date.Format("2006-01-02"),
		HebrewDate:    hd,
		DayOfWeek:     dow,
		DayNameHebrew: hebrewDayNames[dow],
		DayNameEng:    englishDayNames[dow],
		Holidays:      holidays,
		IsShabbat:     dow == 6,
		IsYomTov:      isYomTov,
	}
}

// GetHolidays returns holidays for a given date
func (s *CalendarService) GetHolidays(date time.Time) []Holiday {
	hd := hdate.FromTime(date)
	year := hd.Year()

	// Get calendar events for the Hebrew year
	// NoModern: true excludes modern Israeli holidays (Yom HaAtzmaut, Yom HaZikaron, etc.)
	opts := hebcal.CalOptions{
		Year:             year,
		IsHebrewYear:     true,
		NoHolidays:       false,
		NoMinorFast:      false,
		NoModern:         true,
		NoRoshChodesh:    false,
		NoSpecialShabbat: false,
		ShabbatMevarchim: true,
	}

	events, _ := hebcal.HebrewCalendar(&opts)

	var holidays []Holiday
	dateStr := date.Format("2006-01-02")

	for _, ev := range events {
		evDate := ev.GetDate().Gregorian()
		if evDate.Format("2006-01-02") == dateStr {
			holidays = append(holidays, eventToHoliday(ev))
		}
	}

	return holidays
}

// GetWeekInfo returns information for a week starting from the given date
func (s *CalendarService) GetWeekInfo(startDate time.Time) WeekInfo {
	// Adjust to Sunday if not already
	dow := int(startDate.Weekday())
	if dow != 0 {
		startDate = startDate.AddDate(0, 0, -dow)
	}

	days := make([]DayInfo, 7)
	for i := 0; i < 7; i++ {
		date := startDate.AddDate(0, 0, i)
		days[i] = s.GetDayInfo(date)
	}

	endDate := startDate.AddDate(0, 0, 6)

	return WeekInfo{
		StartDate: startDate.Format("2006-01-02"),
		EndDate:   endDate.Format("2006-01-02"),
		Days:      days,
	}
}

// GetShabbatTimes calculates Shabbat candle lighting and havdalah times
func (s *CalendarService) GetShabbatTimes(date time.Time, lat, lon float64, tzName string) ShabbatTimes {
	loc, err := time.LoadLocation(tzName)
	if err != nil {
		loc = time.UTC
	}

	times := ShabbatTimes{}
	dow := date.Weekday()

	// Calculate sunset using simple algorithm
	sunset := calculateSunset(date, lat, lon, loc)

	// Friday - candle lighting (18 minutes before sunset)
	if dow == time.Friday && !sunset.IsZero() {
		candleLighting := sunset.Add(-18 * time.Minute)
		times.CandleLighting = candleLighting.Format("15:04")
	}

	// Saturday - havdalah (42 minutes after sunset)
	if dow == time.Saturday && !sunset.IsZero() {
		havdalah := sunset.Add(42 * time.Minute)
		times.Havdalah = havdalah.Format("15:04")
	}

	return times
}

// calculateSunset is a simple sunset calculation
func calculateSunset(date time.Time, lat, lon float64, loc *time.Location) time.Time {
	// Day of year
	dayOfYear := float64(date.YearDay())

	// Fractional year (gamma)
	gamma := 2 * math.Pi / 365 * (dayOfYear - 1)

	// Equation of time (minutes)
	eqTime := 229.18 * (0.000075 + 0.001868*math.Cos(gamma) - 0.032077*math.Sin(gamma) -
		0.014615*math.Cos(2*gamma) - 0.040849*math.Sin(2*gamma))

	// Solar declination (radians)
	decl := 0.006918 - 0.399912*math.Cos(gamma) + 0.070257*math.Sin(gamma) -
		0.006758*math.Cos(2*gamma) + 0.000907*math.Sin(2*gamma) -
		0.002697*math.Cos(3*gamma) + 0.00148*math.Sin(3*gamma)

	// Hour angle for sunset (degrees)
	latRad := lat * math.Pi / 180
	zenith := 90.833 * math.Pi / 180

	cosHA := (math.Cos(zenith) - math.Sin(latRad)*math.Sin(decl)) / (math.Cos(latRad) * math.Cos(decl))

	if cosHA < -1 || cosHA > 1 {
		return time.Time{} // No sunset (polar regions)
	}

	ha := math.Acos(cosHA) * 180 / math.Pi

	// Sunset time in minutes from midnight UTC
	sunsetMinutes := 720 + 4*(lon+ha) - eqTime

	// Convert to local time
	hours := int(sunsetMinutes / 60)
	mins := int(sunsetMinutes) % 60

	sunset := time.Date(date.Year(), date.Month(), date.Day(), hours, mins, 0, 0, time.UTC)
	return sunset.In(loc)
}

// eventToHoliday converts a hebcal event to our Holiday type
func eventToHoliday(ev event.CalEvent) Holiday {
	desc := ev.Render("en")
	hebrewName := ev.Render("he")

	// Determine category and properties based on event flags
	category := "minor"
	candles := false
	yomtov := false

	flags := ev.GetFlags()

	if flags&event.MAJOR_FAST != 0 || flags&event.MINOR_FAST != 0 {
		category = "fast"
	} else if flags&event.ROSH_CHODESH != 0 {
		category = "roshchodesh"
	} else if flags&event.SPECIAL_SHABBAT != 0 {
		category = "shabbat"
	} else if flags&event.CHAG != 0 {
		category = "major"
		yomtov = true
		candles = true
	} else if flags&event.LIGHT_CANDLES != 0 || flags&event.LIGHT_CANDLES_TZEIS != 0 {
		candles = true
	}

	return Holiday{
		Name:       desc,
		NameHebrew: hebrewName,
		Category:   category,
		Candles:    candles,
		Yomtov:     yomtov,
	}
}
