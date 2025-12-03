package handlers

import (
	"sort"
	"time"
)

// sortZmanimByTime sorts a slice of ZmanWithFormula by parsed time value (chronological order)
// Zmanim with empty or unparseable times are placed at the end
func sortZmanimByTime(zmanim []ZmanWithFormula) {
	sort.SliceStable(zmanim, func(i, j int) bool {
		ti, errI := parseTimeString(zmanim[i].Time)
		tj, errJ := parseTimeString(zmanim[j].Time)

		// Handle parsing errors - push invalid times to end
		if errI != nil && errJ != nil {
			return false // maintain relative order for both invalid
		}
		if errI != nil {
			return false // i is invalid, j goes first
		}
		if errJ != nil {
			return true // j is invalid, i goes first
		}

		return ti.Before(tj)
	})
}

// parseTimeString parses HH:MM:SS or HH:MM format to time.Time
// Uses a fixed date for comparison purposes only
func parseTimeString(timeStr string) (time.Time, error) {
	// Try HH:MM:SS format first
	t, err := time.Parse("15:04:05", timeStr)
	if err == nil {
		return t, nil
	}

	// Try HH:MM format
	t, err = time.Parse("15:04", timeStr)
	if err == nil {
		return t, nil
	}

	return time.Time{}, err
}

// sortPublisherZmanimByTime sorts PublisherZmanWithTime by calculated time (chronological order)
// Zmanim with nil times or calculation errors are placed at the end
func sortPublisherZmanimByTime(zmanim []PublisherZmanWithTime) {
	sort.SliceStable(zmanim, func(i, j int) bool {
		// Handle nil times - push to end
		if zmanim[i].Time == nil && zmanim[j].Time == nil {
			return false // maintain relative order for both nil
		}
		if zmanim[i].Time == nil {
			return false // i is nil, j goes first
		}
		if zmanim[j].Time == nil {
			return true // j is nil, i goes first
		}

		ti, errI := parseTimeString(*zmanim[i].Time)
		tj, errJ := parseTimeString(*zmanim[j].Time)

		// Handle parsing errors - push invalid times to end
		if errI != nil && errJ != nil {
			return false
		}
		if errI != nil {
			return false
		}
		if errJ != nil {
			return true
		}

		return ti.Before(tj)
	})
}
