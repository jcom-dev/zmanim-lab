package handlers

import (
	"testing"
)

func TestSortZmanimByTime(t *testing.T) {
	tests := []struct {
		name     string
		input    []ZmanWithFormula
		expected []string // expected order of keys
	}{
		{
			name: "chronological order",
			input: []ZmanWithFormula{
				{Key: "sunset", Time: "17:30:00"},
				{Key: "sunrise", Time: "06:30:00"},
				{Key: "chatzos", Time: "12:00:00"},
			},
			expected: []string{"sunrise", "chatzos", "sunset"},
		},
		{
			name: "with candle lighting before sunset",
			input: []ZmanWithFormula{
				{Key: "tzeis", Time: "18:12:00"},
				{Key: "sunset", Time: "17:30:00"},
				{Key: "candle_lighting", Time: "17:12:00"},
			},
			expected: []string{"candle_lighting", "sunset", "tzeis"},
		},
		{
			name: "empty time goes to end",
			input: []ZmanWithFormula{
				{Key: "sunset", Time: "17:30:00"},
				{Key: "unknown", Time: ""},
				{Key: "sunrise", Time: "06:30:00"},
			},
			expected: []string{"sunrise", "sunset", "unknown"},
		},
		{
			name: "HH:MM format supported",
			input: []ZmanWithFormula{
				{Key: "second", Time: "12:00"},
				{Key: "first", Time: "06:30"},
			},
			expected: []string{"first", "second"},
		},
		{
			name: "mixed formats",
			input: []ZmanWithFormula{
				{Key: "second", Time: "12:00:00"},
				{Key: "first", Time: "06:30"},
			},
			expected: []string{"first", "second"},
		},
		{
			name:     "empty slice",
			input:    []ZmanWithFormula{},
			expected: []string{},
		},
		{
			name: "single element",
			input: []ZmanWithFormula{
				{Key: "only", Time: "12:00:00"},
			},
			expected: []string{"only"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sortZmanimByTime(tt.input)

			if len(tt.input) != len(tt.expected) {
				t.Fatalf("length mismatch: got %d, want %d", len(tt.input), len(tt.expected))
			}

			for i, z := range tt.input {
				if z.Key != tt.expected[i] {
					t.Errorf("position %d: got key %s, want %s", i, z.Key, tt.expected[i])
				}
			}
		})
	}
}

func TestSortPublisherZmanimByTime(t *testing.T) {
	strPtr := func(s string) *string { return &s }

	tests := []struct {
		name     string
		input    []PublisherZmanWithTime
		expected []string // expected order of ZmanKey
	}{
		{
			name: "chronological order",
			input: []PublisherZmanWithTime{
				{PublisherZman: PublisherZman{ZmanKey: "sunset"}, Time: strPtr("17:30:00")},
				{PublisherZman: PublisherZman{ZmanKey: "sunrise"}, Time: strPtr("06:30:00")},
				{PublisherZman: PublisherZman{ZmanKey: "chatzos"}, Time: strPtr("12:00:00")},
			},
			expected: []string{"sunrise", "chatzos", "sunset"},
		},
		{
			name: "nil time goes to end",
			input: []PublisherZmanWithTime{
				{PublisherZman: PublisherZman{ZmanKey: "sunset"}, Time: strPtr("17:30:00")},
				{PublisherZman: PublisherZman{ZmanKey: "error_zman"}, Time: nil},
				{PublisherZman: PublisherZman{ZmanKey: "sunrise"}, Time: strPtr("06:30:00")},
			},
			expected: []string{"sunrise", "sunset", "error_zman"},
		},
		{
			name: "multiple nil times maintain relative order",
			input: []PublisherZmanWithTime{
				{PublisherZman: PublisherZman{ZmanKey: "error1"}, Time: nil},
				{PublisherZman: PublisherZman{ZmanKey: "valid"}, Time: strPtr("12:00:00")},
				{PublisherZman: PublisherZman{ZmanKey: "error2"}, Time: nil},
			},
			expected: []string{"valid", "error1", "error2"},
		},
		{
			name:     "empty slice",
			input:    []PublisherZmanWithTime{},
			expected: []string{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sortPublisherZmanimByTime(tt.input)

			if len(tt.input) != len(tt.expected) {
				t.Fatalf("length mismatch: got %d, want %d", len(tt.input), len(tt.expected))
			}

			for i, z := range tt.input {
				if z.ZmanKey != tt.expected[i] {
					t.Errorf("position %d: got key %s, want %s", i, z.ZmanKey, tt.expected[i])
				}
			}
		})
	}
}

func TestParseTimeString(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantErr bool
	}{
		{name: "HH:MM:SS format", input: "12:30:45", wantErr: false},
		{name: "HH:MM format", input: "12:30", wantErr: false},
		{name: "midnight", input: "00:00:00", wantErr: false},
		{name: "empty string", input: "", wantErr: true},
		{name: "invalid format", input: "invalid", wantErr: true},
		{name: "only hour", input: "12", wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := parseTimeString(tt.input)
			if (err != nil) != tt.wantErr {
				t.Errorf("parseTimeString(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
			}
		})
	}
}
