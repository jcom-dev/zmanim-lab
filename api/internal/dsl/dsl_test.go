package dsl

import (
	"testing"
	"time"
)

// TestLexer tests the DSL lexer
func TestLexer(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected []TokenType
	}{
		{
			name:     "primitive",
			input:    "sunrise",
			expected: []TokenType{TOKEN_PRIMITIVE, TOKEN_EOF},
		},
		{
			name:     "function call",
			input:    "solar(16.1, before_sunrise)",
			expected: []TokenType{TOKEN_FUNCTION, TOKEN_LPAREN, TOKEN_NUMBER, TOKEN_COMMA, TOKEN_DIRECTION, TOKEN_RPAREN, TOKEN_EOF},
		},
		{
			name:     "duration",
			input:    "72min",
			expected: []TokenType{TOKEN_DURATION, TOKEN_EOF},
		},
		{
			name:     "compound duration",
			input:    "1h 30min",
			expected: []TokenType{TOKEN_DURATION, TOKEN_EOF},
		},
		{
			name:     "binary operation",
			input:    "sunrise + 72min",
			expected: []TokenType{TOKEN_PRIMITIVE, TOKEN_PLUS, TOKEN_DURATION, TOKEN_EOF},
		},
		{
			name:     "reference",
			input:    "@alos_hashachar",
			expected: []TokenType{TOKEN_AT, TOKEN_EOF},
		},
		{
			name:     "conditional",
			input:    "if (latitude > 60) { sunrise } else { sunset }",
			expected: []TokenType{TOKEN_IF, TOKEN_LPAREN, TOKEN_LATITUDE, TOKEN_GT, TOKEN_NUMBER, TOKEN_RPAREN, TOKEN_LBRACE, TOKEN_PRIMITIVE, TOKEN_RBRACE, TOKEN_ELSE, TOKEN_LBRACE, TOKEN_PRIMITIVE, TOKEN_RBRACE, TOKEN_EOF},
		},
		{
			name:     "proportional_hours function",
			input:    "proportional_hours(3, gra)",
			expected: []TokenType{TOKEN_FUNCTION, TOKEN_LPAREN, TOKEN_NUMBER, TOKEN_COMMA, TOKEN_BASE, TOKEN_RPAREN, TOKEN_EOF},
		},
		{
			name:     "comment ignored",
			input:    "sunrise // this is a comment",
			expected: []TokenType{TOKEN_PRIMITIVE, TOKEN_EOF},
		},
		{
			name:     "multiline comment",
			input:    "sunrise /* comment */ + 72min",
			expected: []TokenType{TOKEN_PRIMITIVE, TOKEN_PLUS, TOKEN_DURATION, TOKEN_EOF},
		},
		{
			name:     "logical and",
			input:    "latitude > 50 && month >= 5",
			expected: []TokenType{TOKEN_LATITUDE, TOKEN_GT, TOKEN_NUMBER, TOKEN_AND, TOKEN_MONTH, TOKEN_GTE, TOKEN_NUMBER, TOKEN_EOF},
		},
		{
			name:     "logical or",
			input:    "month == 5 || month == 6",
			expected: []TokenType{TOKEN_MONTH, TOKEN_EQ, TOKEN_NUMBER, TOKEN_OR, TOKEN_MONTH, TOKEN_EQ, TOKEN_NUMBER, TOKEN_EOF},
		},
		{
			name:     "logical not",
			input:    "!latitude > 50",
			expected: []TokenType{TOKEN_NOT, TOKEN_LATITUDE, TOKEN_GT, TOKEN_NUMBER, TOKEN_EOF},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tokens, err := Tokenize(tt.input)
			if err != nil {
				t.Fatalf("Tokenize(%q) error = %v", tt.input, err)
			}

			if len(tokens) != len(tt.expected) {
				t.Errorf("Tokenize(%q) got %d tokens, want %d", tt.input, len(tokens), len(tt.expected))
				for i, tok := range tokens {
					t.Logf("  token[%d] = %s %q", i, tok.Type, tok.Literal)
				}
				return
			}

			for i, want := range tt.expected {
				if tokens[i].Type != want {
					t.Errorf("Tokenize(%q) token[%d] = %s, want %s", tt.input, i, tokens[i].Type, want)
				}
			}
		})
	}
}

// TestParseDuration tests duration parsing
func TestParseDuration(t *testing.T) {
	tests := []struct {
		input   string
		want    float64
		wantErr bool
	}{
		{"72min", 72, false},
		{"1hr", 60, false},
		{"2h", 120, false},
		{"1h 30min", 90, false},
		{"90min", 90, false},
		{"invalid", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got, err := ParseDuration(tt.input)
			if (err != nil) != tt.wantErr {
				t.Errorf("ParseDuration(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
				return
			}
			if got != tt.want {
				t.Errorf("ParseDuration(%q) = %v, want %v", tt.input, got, tt.want)
			}
		})
	}
}

// TestParser tests the DSL parser
func TestParser(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantErr bool
	}{
		{"primitive", "sunrise", false},
		{"primitive with offset", "sunrise + 72min", false},
		{"negative offset", "sunset - 18min", false},
		{"solar function", "solar(16.1, before_sunrise)", false},
		{"proportional_hours function", "proportional_hours(3, gra)", false},
		{"midpoint function", "midpoint(sunrise, sunset)", false},
		{"reference", "@alos_hashachar", false},
		{"conditional simple", "if (latitude > 60) { sunrise }", false},
		{"conditional with else", "if (latitude > 60) { sunrise } else { sunset }", false},
		{"nested expression", "sunrise + (sunset - sunrise) / 2", false},
		{"custom base", "proportional_hours(3, custom(sunrise, sunset))", false},
		{"multiplication", "proportional_hours(3, gra) + 72min * 2", false},
		{"invalid syntax", "sunrise +", true},
		{"unclosed paren", "solar(16.1, before_sunrise", true},
		{"logical and in condition", "if (latitude > 50 && month >= 5) { sunrise }", false},
		{"logical or in condition", "if (month == 5 || month == 6) { sunrise }", false},
		{"logical not in condition", "if (!(latitude > 50)) { sunrise }", false},
		{"complex logical expression", "if ((latitude > 50 && month >= 5) || month == 12) { sunrise } else { sunset }", false},
		{"chained and", "if (month >= 5 && month <= 7 && latitude > 50) { sunrise }", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := Parse(tt.input)
			if (err != nil) != tt.wantErr {
				t.Errorf("Parse(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
			}
		})
	}
}

// TestValidator tests semantic validation
func TestValidator(t *testing.T) {
	tests := []struct {
		name           string
		input          string
		availableZmans []string
		wantValid      bool
	}{
		{"valid primitive", "sunrise", nil, true},
		{"valid solar", "solar(16.1, before_sunrise)", nil, true},
		{"invalid solar degrees", "solar(100, before_sunrise)", nil, false},
		{"valid proportional_hours", "proportional_hours(3, gra)", nil, true},
		{"invalid proportional_hours hours", "proportional_hours(15, gra)", nil, false},
		{"valid reference", "@alos", []string{"alos"}, true},
		{"undefined reference", "@undefined", []string{"alos"}, false},
		{"time addition error", "sunrise + sunset", nil, false},
		{"valid time arithmetic", "sunrise + 72min", nil, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, validationErrors, _ := ValidateFormula(tt.input, tt.availableZmans)
			valid := len(validationErrors) == 0
			if valid != tt.wantValid {
				t.Errorf("ValidateFormula(%q) valid = %v, want %v", tt.input, valid, tt.wantValid)
				if len(validationErrors) > 0 {
					t.Logf("Errors: %v", validationErrors)
				}
			}
		})
	}
}

// TestExecutor tests formula execution
func TestExecutor(t *testing.T) {
	// Test location: Jerusalem
	// Date: March 21 (equinox - roughly equal day/night)
	loc, _ := time.LoadLocation("Asia/Jerusalem")
	date := time.Date(2024, 3, 21, 0, 0, 0, 0, loc)
	ctx := NewExecutionContext(date, 31.7683, 35.2137, 0, loc)

	tests := []struct {
		name    string
		formula string
		wantErr bool
	}{
		{"sunrise", "sunrise", false},
		{"sunset", "sunset", false},
		{"solar_noon", "solar_noon", false},
		{"sunrise + offset", "sunrise + 72min", false},
		{"sunset - offset", "sunset - 18min", false},
		{"solar function", "solar(16.1, before_sunrise)", false},
		{"proportional_hours gra", "proportional_hours(3, gra)", false},
		{"proportional_hours mga", "proportional_hours(3, mga)", false},
		{"midpoint", "midpoint(sunrise, sunset)", false},
		{"conditional true", "if (latitude > 30) { sunrise } else { sunset }", false},
		{"conditional false", "if (latitude > 40) { sunrise } else { sunset }", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := ExecuteFormula(tt.formula, ctx)
			if (err != nil) != tt.wantErr {
				t.Errorf("ExecuteFormula(%q) error = %v, wantErr %v", tt.formula, err, tt.wantErr)
				return
			}
			if !tt.wantErr && result.IsZero() {
				t.Errorf("ExecuteFormula(%q) returned zero time", tt.formula)
			}
		})
	}
}

// TestExecutorResults tests specific calculation results
func TestExecutorResults(t *testing.T) {
	// Test location: Jerusalem on equinox
	loc, _ := time.LoadLocation("Asia/Jerusalem")
	date := time.Date(2024, 3, 21, 0, 0, 0, 0, loc)
	ctx := NewExecutionContext(date, 31.7683, 35.2137, 0, loc)

	// Execute sunrise
	sunrise, _ := ExecuteFormula("sunrise", ctx)
	// Execute sunset
	sunset, _ := ExecuteFormula("sunset", ctx)
	// Execute sunrise + 72min
	alos, _ := ExecuteFormula("sunrise - 72min", ctx)
	// Execute midpoint
	midpoint, _ := ExecuteFormula("midpoint(sunrise, sunset)", ctx)

	// Basic sanity checks
	if !sunrise.Before(sunset) {
		t.Error("sunrise should be before sunset")
	}

	if !alos.Before(sunrise) {
		t.Error("alos (sunrise - 72min) should be before sunrise")
	}

	// Midpoint should be between sunrise and sunset
	if !midpoint.After(sunrise) || !midpoint.Before(sunset) {
		t.Error("midpoint should be between sunrise and sunset")
	}

	// Check alos is approximately 72 minutes before sunrise
	diff := sunrise.Sub(alos).Minutes()
	if diff < 71 || diff > 73 {
		t.Errorf("alos should be ~72 min before sunrise, got %v min", diff)
	}
}

// TestProportionalHours tests proportional hour calculations
func TestProportionalHours(t *testing.T) {
	loc, _ := time.LoadLocation("Asia/Jerusalem")
	date := time.Date(2024, 6, 21, 0, 0, 0, 0, loc) // Summer solstice - long day
	ctx := NewExecutionContext(date, 31.7683, 35.2137, 0, loc)

	// Get sunrise and sunset
	sunrise, _ := ExecuteFormula("sunrise", ctx)
	sunset, _ := ExecuteFormula("sunset", ctx)

	// proportional_hours(3, gra) should be 3 proportional hours after sunrise
	sofZmanShma, _ := ExecuteFormula("proportional_hours(3, gra)", ctx)

	// It should be after sunrise
	if !sofZmanShma.After(sunrise) {
		t.Error("proportional_hours(3, gra) should be after sunrise")
	}

	// It should be before solar noon (which is at ~6 hours)
	solarNoon, _ := ExecuteFormula("solar_noon", ctx)
	if !sofZmanShma.Before(solarNoon) {
		t.Error("proportional_hours(3, gra) should be before solar noon")
	}

	// proportional_hours(4, gra) for tefila should be after shma
	sofZmanTefila, _ := ExecuteFormula("proportional_hours(4, gra)", ctx)
	if !sofZmanTefila.After(sofZmanShma) {
		t.Error("proportional_hours(4, gra) should be after proportional_hours(3, gra)")
	}

	// Verify proportional hours calculation
	dayLength := sunset.Sub(sunrise)
	hourLength := dayLength / 12
	expectedShma := sunrise.Add(3 * hourLength)

	// Should be within 1 minute
	diff := sofZmanShma.Sub(expectedShma).Abs()
	if diff > time.Minute {
		t.Errorf("proportional_hours(3, gra) should match manual calculation, diff = %v", diff)
	}
}

// TestCircularDependency tests circular dependency detection
func TestCircularDependency(t *testing.T) {
	formulas := map[string]string{
		"a": "@b + 10min",
		"b": "@c + 10min",
		"c": "@a + 10min", // circular!
	}

	_, err := DetectCircularDependencies(formulas)
	if err == nil {
		t.Error("DetectCircularDependencies should detect the cycle")
	}
}

// TestNonCircularDependency tests valid dependency ordering
func TestNonCircularDependency(t *testing.T) {
	formulas := map[string]string{
		"sunrise_offset": "sunrise + 10min",
		"alos":           "sunrise - 72min",
		"tzeis":          "sunset + 42min",
	}

	order, err := DetectCircularDependencies(formulas)
	if err != nil {
		t.Errorf("DetectCircularDependencies error = %v", err)
	}
	if len(order) != 3 {
		t.Errorf("Expected 3 items in order, got %d", len(order))
	}
}

// TestConditionVariables tests condition variable evaluation
func TestConditionVariables(t *testing.T) {
	loc, _ := time.LoadLocation("America/New_York")
	// January - winter in northern hemisphere
	date := time.Date(2024, 1, 15, 0, 0, 0, 0, loc)
	ctx := NewExecutionContext(date, 40.7128, -74.0060, 0, loc) // New York

	// Test latitude condition
	t.Run("latitude condition true", func(t *testing.T) {
		result, err := ExecuteFormula("if (latitude > 30) { sunrise } else { sunset }", ctx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		sunrise, _ := ExecuteFormula("sunrise", ctx)
		// Result should equal sunrise (latitude 40 > 30)
		if result.Sub(sunrise).Abs() > time.Second {
			t.Error("condition should evaluate to true branch (sunrise)")
		}
	})

	t.Run("month condition", func(t *testing.T) {
		result, err := ExecuteFormula("if (month == 1) { sunrise } else { sunset }", ctx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		sunrise, _ := ExecuteFormula("sunrise", ctx)
		// Result should equal sunrise (month is January = 1)
		if result.Sub(sunrise).Abs() > time.Second {
			t.Error("month condition should evaluate to true branch")
		}
	})

	t.Run("season condition", func(t *testing.T) {
		// January in northern hemisphere = winter
		if ctx.Season() != "winter" {
			t.Errorf("Season() = %s, want winter", ctx.Season())
		}
	})
}

// TestLogicalOperators tests logical operators (&&, ||, !)
func TestLogicalOperators(t *testing.T) {
	loc, _ := time.LoadLocation("Europe/London")
	// June - summer in Manchester (lat ~53.5°)
	date := time.Date(2024, 6, 15, 0, 0, 0, 0, loc)
	ctx := NewExecutionContext(date, 53.48, -2.24, 0, loc) // Manchester

	t.Run("logical AND - both true", func(t *testing.T) {
		// latitude > 50 is true (53.48 > 50), month >= 5 is true (6 >= 5)
		result, err := ExecuteFormula("if (latitude > 50 && month >= 5) { sunrise } else { sunset }", ctx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		sunrise, _ := ExecuteFormula("sunrise", ctx)
		if result.Sub(sunrise).Abs() > time.Second {
			t.Error("AND with both true should return true branch")
		}
	})

	t.Run("logical AND - left false", func(t *testing.T) {
		// latitude > 60 is false (53.48 < 60)
		result, err := ExecuteFormula("if (latitude > 60 && month >= 5) { sunrise } else { sunset }", ctx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		sunset, _ := ExecuteFormula("sunset", ctx)
		if result.Sub(sunset).Abs() > time.Second {
			t.Error("AND with left false should return false branch")
		}
	})

	t.Run("logical AND - right false", func(t *testing.T) {
		// month >= 10 is false (6 < 10)
		result, err := ExecuteFormula("if (latitude > 50 && month >= 10) { sunrise } else { sunset }", ctx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		sunset, _ := ExecuteFormula("sunset", ctx)
		if result.Sub(sunset).Abs() > time.Second {
			t.Error("AND with right false should return false branch")
		}
	})

	t.Run("logical OR - both false", func(t *testing.T) {
		// latitude > 60 is false, month >= 10 is false
		result, err := ExecuteFormula("if (latitude > 60 || month >= 10) { sunrise } else { sunset }", ctx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		sunset, _ := ExecuteFormula("sunset", ctx)
		if result.Sub(sunset).Abs() > time.Second {
			t.Error("OR with both false should return false branch")
		}
	})

	t.Run("logical OR - left true", func(t *testing.T) {
		// latitude > 50 is true
		result, err := ExecuteFormula("if (latitude > 50 || month >= 10) { sunrise } else { sunset }", ctx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		sunrise, _ := ExecuteFormula("sunrise", ctx)
		if result.Sub(sunrise).Abs() > time.Second {
			t.Error("OR with left true should return true branch")
		}
	})

	t.Run("logical OR - right true", func(t *testing.T) {
		// latitude > 60 is false, month >= 5 is true
		result, err := ExecuteFormula("if (latitude > 60 || month >= 5) { sunrise } else { sunset }", ctx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		sunrise, _ := ExecuteFormula("sunrise", ctx)
		if result.Sub(sunrise).Abs() > time.Second {
			t.Error("OR with right true should return true branch")
		}
	})

	t.Run("logical NOT", func(t *testing.T) {
		// !(latitude > 60) is true (because latitude > 60 is false)
		result, err := ExecuteFormula("if (!(latitude > 60)) { sunrise } else { sunset }", ctx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		sunrise, _ := ExecuteFormula("sunrise", ctx)
		if result.Sub(sunrise).Abs() > time.Second {
			t.Error("NOT of false should return true branch")
		}
	})

	t.Run("complex expression - Manchester polar summer", func(t *testing.T) {
		// This is the formula we want for Manchester: summer months with high latitude
		// (month >= 5 && month <= 7 && latitude > 50)
		result, err := ExecuteFormula("if (month >= 5 && month <= 7 && latitude > 50) { solar_noon } else { solar(16.1, before_sunrise) }", ctx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		solarNoon, _ := ExecuteFormula("solar_noon", ctx)
		// In June at Manchester, we should get solar_noon (the true branch)
		if result.Sub(solarNoon).Abs() > time.Second {
			t.Error("Manchester summer should use solar_noon branch")
		}
	})

	t.Run("complex expression - winter fallback", func(t *testing.T) {
		// In January, should use the else branch
		winterDate := time.Date(2024, 1, 15, 0, 0, 0, 0, loc)
		winterCtx := NewExecutionContext(winterDate, 53.48, -2.24, 0, loc)

		result, err := ExecuteFormula("if (month >= 5 && month <= 7 && latitude > 50) { solar_noon } else { solar(16.1, before_sunrise) }", winterCtx)
		if err != nil {
			t.Fatalf("error: %v", err)
		}
		dawn, _ := ExecuteFormula("solar(16.1, before_sunrise)", winterCtx)
		if result.Sub(dawn).Abs() > time.Second {
			t.Error("Manchester winter should use solar(16.1) branch")
		}
	})
}

// TestRealWorldFormulas tests formulas used in real halachic calculations
func TestRealWorldFormulas(t *testing.T) {
	loc, _ := time.LoadLocation("Asia/Jerusalem")
	date := time.Date(2024, 3, 21, 0, 0, 0, 0, loc)
	ctx := NewExecutionContext(date, 31.7683, 35.2137, 0, loc)

	realWorldFormulas := []struct {
		name    string
		formula string
	}{
		{"Alos Hashachar (72 min)", "sunrise - 72min"},
		{"Alos Hashachar (16.1°)", "solar(16.1, before_sunrise)"},
		{"Misheyakir (10.2°)", "solar(10.2, before_sunrise)"},
		{"Sof Zman Shma GRA", "proportional_hours(3, gra)"},
		{"Sof Zman Shma MGA", "proportional_hours(3, mga)"},
		{"Sof Zman Tefila GRA", "proportional_hours(4, gra)"},
		{"Chatzos", "midpoint(sunrise, sunset)"},
		{"Mincha Gedola", "proportional_hours(6.5, gra)"},
		{"Mincha Ketana", "proportional_hours(9.5, gra)"},
		{"Plag HaMincha", "proportional_hours(10.75, gra)"},
		{"Tzeis 8.5°", "solar(8.5, after_sunset)"},
		{"Tzeis 72 min", "sunset + 72min"},
	}

	for _, tt := range realWorldFormulas {
		t.Run(tt.name, func(t *testing.T) {
			result, err := ExecuteFormula(tt.formula, ctx)
			if err != nil {
				t.Errorf("Formula %q error: %v", tt.formula, err)
				return
			}
			if result.IsZero() {
				t.Errorf("Formula %q returned zero time", tt.formula)
				return
			}
			t.Logf("%s = %s", tt.name, result.Format("15:04:05"))
		})
	}
}

// TestExecuteFormulaSet tests executing multiple interdependent formulas
func TestExecuteFormulaSet(t *testing.T) {
	loc, _ := time.LoadLocation("Asia/Jerusalem")
	date := time.Date(2024, 3, 21, 0, 0, 0, 0, loc)
	ctx := NewExecutionContext(date, 31.7683, 35.2137, 0, loc)

	formulas := map[string]string{
		"alos_72":  "sunrise - 72min",
		"sunrise":  "sunrise",
		"shma_gra": "proportional_hours(3, gra)",
		"chatzos":  "midpoint(sunrise, sunset)",
		"sunset":   "sunset",
		"tzeis_72": "sunset + 72min",
	}

	results, err := ExecuteFormulaSet(formulas, ctx)
	if err != nil {
		t.Fatalf("ExecuteFormulaSet error: %v", err)
	}

	// Check all formulas produced results
	for key := range formulas {
		if _, ok := results[key]; !ok {
			t.Errorf("Missing result for %q", key)
		}
	}

	// Check ordering makes sense
	if !results["alos_72"].Before(results["sunrise"]) {
		t.Error("alos should be before sunrise")
	}
	if !results["sunrise"].Before(results["chatzos"]) {
		t.Error("sunrise should be before chatzos")
	}
	if !results["chatzos"].Before(results["sunset"]) {
		t.Error("chatzos should be before sunset")
	}
	if !results["sunset"].Before(results["tzeis_72"]) {
		t.Error("sunset should be before tzeis")
	}
}
