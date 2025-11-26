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

// ZmanDisplayNames maps zman keys to display names
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
