// Package algorithm provides parsing and execution of zmanim calculation algorithms
package algorithm

import "time"

// Method represents a calculation method type
type Method string

const (
	MethodSunrise       Method = "sunrise"
	MethodSunset        Method = "sunset"
	MethodSolarAngle    Method = "solar_angle"
	MethodFixedMinutes  Method = "fixed_minutes"
	MethodProportional  Method = "proportional"
	MethodMidpoint      Method = "midpoint"
)

// ProportionalBase represents the base for proportional calculations
type ProportionalBase string

const (
	BaseGRA ProportionalBase = "gra"
	BaseMGA ProportionalBase = "mga"
)

// TimeBase represents the base time for fixed minutes calculations
type TimeBase string

const (
	FromSunrise TimeBase = "sunrise"
	FromSunset  TimeBase = "sunset"
	FromAlos    TimeBase = "alos"
	FromTzeis   TimeBase = "tzeis"
)

// ZmanConfig represents the configuration for a single zman calculation
type ZmanConfig struct {
	Method string                 `json:"method"`
	Params map[string]interface{} `json:"params"`
}

// AlgorithmConfig represents a full algorithm configuration
type AlgorithmConfig struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description,omitempty"`
	Version     string                 `json:"version,omitempty"`
	Zmanim      map[string]ZmanConfig  `json:"zmanim"`
}

// ZmanResult represents the result of a single zman calculation
type ZmanResult struct {
	Name        string      `json:"name"`
	Key         string      `json:"key"`
	Time        time.Time   `json:"-"`
	TimeString  string      `json:"time"`
	Formula     FormulaInfo `json:"formula"`
}

// FormulaInfo contains details about how a zman was calculated
type FormulaInfo struct {
	Method       string                 `json:"method"`
	DisplayName  string                 `json:"display_name"`
	Parameters   map[string]interface{} `json:"parameters"`
	Explanation  string                 `json:"explanation"`
}

// ZmanimResults contains all calculated zmanim
type ZmanimResults struct {
	Date     string       `json:"date"`
	Location LocationInfo `json:"location"`
	Zmanim   []ZmanResult `json:"zmanim"`
}

// LocationInfo contains location details
type LocationInfo struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Timezone  string  `json:"timezone"`
	CityName  string  `json:"city_name,omitempty"`
}

// StandardZmanim returns the standard zmanim names in order
var StandardZmanim = []string{
	"alos_hashachar",
	"misheyakir",
	"sunrise",
	"sof_zman_shma_gra",
	"sof_zman_shma_mga",
	"sof_zman_tefilla_gra",
	"sof_zman_tefilla_mga",
	"chatzos",
	"mincha_gedola",
	"mincha_ketana",
	"plag_hamincha",
	"sunset",
	"tzeis_hakochavim",
	"tzeis_72",
}

// ZmanDisplayNames maps zman keys to display names (English)
var ZmanDisplayNames = map[string]string{
	"alos_hashachar":       "Alos HaShachar",
	"misheyakir":           "Misheyakir",
	"sunrise":              "Sunrise (Netz HaChama)",
	"sof_zman_shma_gra":    "Sof Zman Shma (GRA)",
	"sof_zman_shma_mga":    "Sof Zman Shma (MGA)",
	"sof_zman_tefilla_gra": "Sof Zman Tefilla (GRA)",
	"sof_zman_tefilla_mga": "Sof Zman Tefilla (MGA)",
	"chatzos":              "Chatzos (Midday)",
	"mincha_gedola":        "Mincha Gedola",
	"mincha_ketana":        "Mincha Ketana",
	"plag_hamincha":        "Plag HaMincha",
	"sunset":               "Sunset (Shkiah)",
	"tzeis_hakochavim":     "Tzeis HaKochavim",
	"tzeis_72":             "Tzeis (72 minutes)",
}

// BilingualName represents a zman name in Hebrew and English
type BilingualName struct {
	Hebrew         string `json:"hebrew"`
	English        string `json:"english"`
	Transliteration string `json:"transliteration,omitempty"`
}

// ZmanBilingualNames maps zman keys to bilingual names
var ZmanBilingualNames = map[string]BilingualName{
	"alos_hashachar":       {Hebrew: "עלות השחר", English: "Dawn", Transliteration: "Alos HaShachar"},
	"alos_16_1":            {Hebrew: "עלות השחר 16.1°", English: "Dawn (16.1°)", Transliteration: "Alos 16.1"},
	"alos_72":              {Hebrew: "עלות השחר 72 דקות", English: "Dawn (72 minutes)", Transliteration: "Alos 72"},
	"misheyakir":           {Hebrew: "משיכיר", English: "Misheyakir", Transliteration: "Misheyakir"},
	"misheyakir_10_2":      {Hebrew: "משיכיר 10.2°", English: "Misheyakir (10.2°)", Transliteration: "Misheyakir 10.2"},
	"sunrise":              {Hebrew: "נץ החמה", English: "Sunrise", Transliteration: "Netz HaChama"},
	"visible_sunrise":      {Hebrew: "נץ החמה הנראה", English: "Visible Sunrise", Transliteration: "Netz HaChama HaNireh"},
	"sof_zman_shma_gra":    {Hebrew: "סוף זמן שמע גר״א", English: "Latest Shema (GRA)", Transliteration: "Sof Zman Shma GRA"},
	"sof_zman_shma_mga":    {Hebrew: "סוף זמן שמע מג״א", English: "Latest Shema (MGA)", Transliteration: "Sof Zman Shma MGA"},
	"sof_zman_tefilla_gra": {Hebrew: "סוף זמן תפילה גר״א", English: "Latest Shacharit (GRA)", Transliteration: "Sof Zman Tefilla GRA"},
	"sof_zman_tefilla_mga": {Hebrew: "סוף זמן תפילה מג״א", English: "Latest Shacharit (MGA)", Transliteration: "Sof Zman Tefilla MGA"},
	"chatzos":              {Hebrew: "חצות היום", English: "Midday", Transliteration: "Chatzos HaYom"},
	"mincha_gedola":        {Hebrew: "מנחה גדולה", English: "Earliest Mincha", Transliteration: "Mincha Gedolah"},
	"mincha_ketana":        {Hebrew: "מנחה קטנה", English: "Mincha Ketana", Transliteration: "Mincha Ketanah"},
	"plag_hamincha":        {Hebrew: "פלג המנחה", English: "Plag HaMincha", Transliteration: "Plag HaMincha"},
	"sunset":               {Hebrew: "שקיעת החמה", English: "Sunset", Transliteration: "Shkias HaChama"},
	"bein_hashmashos":      {Hebrew: "בין השמשות", English: "Twilight", Transliteration: "Bein HaShmashos"},
	"tzeis_hakochavim":     {Hebrew: "צאת הכוכבים", English: "Nightfall", Transliteration: "Tzeis HaKochavim"},
	"tzeis_8_5":            {Hebrew: "צאת הכוכבים 8.5°", English: "Nightfall (8.5°)", Transliteration: "Tzeis 8.5"},
	"tzeis_72":             {Hebrew: "צאת הכוכבים 72 דקות", English: "Nightfall (72 minutes)", Transliteration: "Tzeis 72"},
	"tzeis_rabbeinu_tam":   {Hebrew: "צאת הכוכבים רבינו תם", English: "Nightfall (Rabbeinu Tam)", Transliteration: "Tzeis Rabbeinu Tam"},
	"chatzos_laila":        {Hebrew: "חצות הלילה", English: "Midnight", Transliteration: "Chatzos HaLailah"},
	"candle_lighting":      {Hebrew: "הדלקת נרות", English: "Candle Lighting", Transliteration: "Hadlakas Neiros"},
	"motzei_shabbat":       {Hebrew: "מוצאי שבת", English: "End of Shabbat", Transliteration: "Motzei Shabbat"},
}

// GetBilingualName returns the bilingual name for a zman key
func GetBilingualName(key string) BilingualName {
	if name, ok := ZmanBilingualNames[key]; ok {
		return name
	}
	// Fallback: use key as both names
	return BilingualName{Hebrew: key, English: key}
}

// GetDisplayName returns the display name in the specified locale
func GetDisplayName(key string, locale string) string {
	name := GetBilingualName(key)
	if locale == "he" {
		return name.Hebrew
	}
	return name.English
}

// DefaultAlgorithm returns a standard algorithm configuration
func DefaultAlgorithm() *AlgorithmConfig {
	return &AlgorithmConfig{
		Name:        "Standard",
		Description: "Standard zmanim calculation using common methods",
		Version:     "1.0.0",
		Zmanim: map[string]ZmanConfig{
			"alos_hashachar": {
				Method: "solar_angle",
				Params: map[string]interface{}{"degrees": 16.1},
			},
			"misheyakir": {
				Method: "solar_angle",
				Params: map[string]interface{}{"degrees": 11.5},
			},
			"sunrise": {
				Method: "sunrise",
				Params: map[string]interface{}{},
			},
			"sof_zman_shma_gra": {
				Method: "proportional",
				Params: map[string]interface{}{"hours": 3.0, "base": "gra"},
			},
			"sof_zman_shma_mga": {
				Method: "proportional",
				Params: map[string]interface{}{"hours": 3.0, "base": "mga"},
			},
			"sof_zman_tefilla_gra": {
				Method: "proportional",
				Params: map[string]interface{}{"hours": 4.0, "base": "gra"},
			},
			"sof_zman_tefilla_mga": {
				Method: "proportional",
				Params: map[string]interface{}{"hours": 4.0, "base": "mga"},
			},
			"chatzos": {
				Method: "midpoint",
				Params: map[string]interface{}{"start": "sunrise", "end": "sunset"},
			},
			"mincha_gedola": {
				Method: "proportional",
				Params: map[string]interface{}{"hours": 6.5, "base": "gra"},
			},
			"mincha_ketana": {
				Method: "proportional",
				Params: map[string]interface{}{"hours": 9.5, "base": "gra"},
			},
			"plag_hamincha": {
				Method: "proportional",
				Params: map[string]interface{}{"hours": 10.75, "base": "gra"},
			},
			"sunset": {
				Method: "sunset",
				Params: map[string]interface{}{},
			},
			"tzeis_hakochavim": {
				Method: "solar_angle",
				Params: map[string]interface{}{"degrees": 8.5},
			},
			"tzeis_72": {
				Method: "fixed_minutes",
				Params: map[string]interface{}{"minutes": 72.0, "from": "sunset"},
			},
		},
	}
}
