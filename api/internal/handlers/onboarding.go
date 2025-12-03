package handlers

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"
)

// OnboardingState represents the publisher's onboarding progress
type OnboardingState struct {
	ID             string                 `json:"id,omitempty"`
	PublisherID    string                 `json:"publisher_id"`
	CurrentStep    int                    `json:"current_step"`
	CompletedSteps []int                  `json:"completed_steps"`
	Data           map[string]interface{} `json:"data"`
	StartedAt      string                 `json:"started_at"`
	LastUpdatedAt  string                 `json:"last_updated_at"`
	CompletedAt    *string                `json:"completed_at,omitempty"`
	Skipped        bool                   `json:"skipped"`
}

// GetOnboardingState returns the publisher's onboarding state
// GET /api/publisher/onboarding
func (h *Handlers) GetOnboardingState(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Query onboarding state
	var state OnboardingState
	var startedAt, lastUpdatedAt time.Time
	var completedAt *time.Time
	var wizardData []byte

	err := h.db.Pool.QueryRow(ctx, `
		SELECT id, current_step, completed_steps, wizard_data,
		       started_at, last_updated_at, completed_at, skipped
		FROM publisher_onboarding
		WHERE publisher_id = $1
	`, publisherID).Scan(
		&state.ID, &state.CurrentStep, &state.CompletedSteps, &wizardData,
		&startedAt, &lastUpdatedAt, &completedAt, &state.Skipped,
	)

	if err != nil {
		// No onboarding state - return null (new publisher)
		RespondJSON(w, r, http.StatusOK, nil)
		return
	}

	state.PublisherID = publisherID
	state.StartedAt = startedAt.Format(time.RFC3339)
	state.LastUpdatedAt = lastUpdatedAt.Format(time.RFC3339)
	if completedAt != nil {
		ts := completedAt.Format(time.RFC3339)
		state.CompletedAt = &ts
	}

	if wizardData != nil {
		_ = json.Unmarshal(wizardData, &state.Data)
	}

	if state.CompletedSteps == nil {
		state.CompletedSteps = []int{}
	}
	if state.Data == nil {
		state.Data = make(map[string]interface{})
	}

	RespondJSON(w, r, http.StatusOK, state)
}

// SaveOnboardingState saves the publisher's onboarding state
// PUT /api/publisher/onboarding
func (h *Handlers) SaveOnboardingState(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.Info("SaveOnboardingState starting")

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		slog.Error("SaveOnboardingState failed to resolve publisher")
		return // Response already sent
	}
	publisherID := pc.PublisherID
	slog.Info("SaveOnboardingState resolved publisher", "publisher_id", publisherID)

	var req OnboardingState
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		slog.Error("SaveOnboardingState invalid request body", "error", err)
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Convert data to JSON
	wizardData, err := json.Marshal(req.Data)
	if err != nil {
		slog.Error("SaveOnboardingState failed to marshal data", "error", err)
		RespondBadRequest(w, r, "Invalid data format")
		return
	}
	slog.Debug("SaveOnboardingState wizard_data", "wizard_data", string(wizardData))

	// Upsert onboarding state
	_, err = h.db.Pool.Exec(ctx, `
		INSERT INTO publisher_onboarding (
			publisher_id, current_step, completed_steps, wizard_data, last_updated_at
		) VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (publisher_id)
		DO UPDATE SET
			current_step = EXCLUDED.current_step,
			completed_steps = EXCLUDED.completed_steps,
			wizard_data = EXCLUDED.wizard_data,
			last_updated_at = NOW()
	`, publisherID, req.CurrentStep, req.CompletedSteps, wizardData)

	if err != nil {
		slog.Error("SaveOnboardingState failed to save", "error", err)
		RespondInternalError(w, r, "Failed to save onboarding state")
		return
	}

	slog.Info("SaveOnboardingState completed successfully")
	RespondJSON(w, r, http.StatusOK, map[string]string{
		"status": "saved",
	})
}

// WizardZman represents a zman from the onboarding wizard customizations
// Supports both legacy format (key, nameHebrew, nameEnglish) and new registry format (zman_key, hebrew_name, english_name)
type WizardZman struct {
	// Legacy format fields
	Key         string `json:"key"`
	NameHebrew  string `json:"nameHebrew"`
	NameEnglish string `json:"nameEnglish"`

	// New registry format fields
	MasterZmanID string `json:"master_zman_id"`
	ZmanKey      string `json:"zman_key"`
	HebrewName   string `json:"hebrew_name"`
	EnglishName  string `json:"english_name"`
	TimeCategory string `json:"time_category"`

	// Common fields
	Formula  string `json:"formula"`
	Category string `json:"category"`
	Enabled  bool   `json:"enabled"`
	Modified bool   `json:"modified"`
}

// GetKey returns the zman key from either format
func (z WizardZman) GetKey() string {
	if z.ZmanKey != "" {
		return z.ZmanKey
	}
	return z.Key
}

// GetHebrewName returns the hebrew name from either format
func (z WizardZman) GetHebrewName() string {
	if z.HebrewName != "" {
		return z.HebrewName
	}
	return z.NameHebrew
}

// GetEnglishName returns the english name from either format
func (z WizardZman) GetEnglishName() string {
	if z.EnglishName != "" {
		return z.EnglishName
	}
	return z.NameEnglish
}

// GetCategory returns the category, defaulting to "essential" for everyday zmanim
func (z WizardZman) GetCategory() string {
	if z.Category == "event" {
		return "optional"
	}
	if z.Category == "everyday" {
		return "essential"
	}
	if z.Category != "" {
		return z.Category
	}
	return "essential"
}

// WizardCoverage represents a coverage selection from the onboarding wizard
type WizardCoverage struct {
	Type string `json:"type"` // "city", "region", "country", or "continent"
	ID   string `json:"id"`
	Name string `json:"name"`
}

// CompleteOnboarding marks onboarding as complete and imports zmanim from wizard customizations
// POST /api/publisher/onboarding/complete
func (h *Handlers) CompleteOnboarding(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.Info("CompleteOnboarding starting")

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		slog.Error("CompleteOnboarding failed to resolve publisher")
		return // Response already sent
	}
	publisherID := pc.PublisherID
	slog.Info("CompleteOnboarding resolved publisher", "publisher_id", publisherID)

	// Get the wizard data with user's customizations
	var wizardData []byte
	err := h.db.Pool.QueryRow(ctx, `
		SELECT wizard_data FROM publisher_onboarding WHERE publisher_id = $1
	`, publisherID).Scan(&wizardData)
	if err != nil {
		slog.Error("CompleteOnboarding no onboarding data found", "error", err)
		RespondBadRequest(w, r, "No onboarding data found")
		return
	}
	slog.Debug("CompleteOnboarding wizard_data", "wizard_data", string(wizardData))

	var data struct {
		Customizations []WizardZman     `json:"customizations"`
		Coverage       []WizardCoverage `json:"coverage"`
	}
	if err := json.Unmarshal(wizardData, &data); err != nil {
		slog.Error("CompleteOnboarding invalid wizard data", "error", err)
		RespondBadRequest(w, r, "Invalid wizard data")
		return
	}
	slog.Info("CompleteOnboarding parsed data", "customizations", len(data.Customizations), "coverage_items", len(data.Coverage))

	// Import zmanim from wizard customizations (only enabled ones)
	if len(data.Customizations) > 0 {
		// Filter to only include enabled zmanim
		enabledZmanim := make([]WizardZman, 0)
		for _, zman := range data.Customizations {
			if zman.Enabled {
				enabledZmanim = append(enabledZmanim, zman)
			}
		}
		slog.Info("CompleteOnboarding importing zmanim", "enabled", len(enabledZmanim), "total", len(data.Customizations))

		for i, zman := range enabledZmanim {
			zmanKey := zman.GetKey()
			hebrewName := zman.GetHebrewName()
			englishName := zman.GetEnglishName()
			category := zman.GetCategory()

			slog.Debug("CompleteOnboarding inserting zman", "index", i+1, "key", zmanKey, "hebrew", hebrewName, "english", englishName)

			// Check if this is a registry-based zman (has master_zman_id)
			if zman.MasterZmanID != "" {
				// Use the registry-based insert that links to master_zman_id
				_, err = h.db.Pool.Exec(ctx, `
					INSERT INTO publisher_zmanim (
						publisher_id, zman_key, hebrew_name, english_name, formula_dsl,
						is_enabled, is_visible, is_published, is_custom, category, sort_order,
						master_zman_id
					) VALUES ($1, $2, $3, $4, $5, true, true, false, false, $6, $7, $8)
					ON CONFLICT (publisher_id, zman_key) DO UPDATE SET
						hebrew_name = EXCLUDED.hebrew_name,
						english_name = EXCLUDED.english_name,
						formula_dsl = EXCLUDED.formula_dsl,
						is_enabled = EXCLUDED.is_enabled,
						category = EXCLUDED.category,
						sort_order = EXCLUDED.sort_order,
						master_zman_id = EXCLUDED.master_zman_id
				`, publisherID, zmanKey, hebrewName, englishName,
					zman.Formula, category, i+1, zman.MasterZmanID)
			} else {
				// Legacy insert without master_zman_id
				_, err = h.db.Pool.Exec(ctx, `
					INSERT INTO publisher_zmanim (
						publisher_id, zman_key, hebrew_name, english_name, formula_dsl,
						is_enabled, is_visible, is_published, is_custom, category, sort_order
					) VALUES ($1, $2, $3, $4, $5, true, true, false, false, $6, $7)
					ON CONFLICT (publisher_id, zman_key) DO UPDATE SET
						hebrew_name = EXCLUDED.hebrew_name,
						english_name = EXCLUDED.english_name,
						formula_dsl = EXCLUDED.formula_dsl,
						is_enabled = EXCLUDED.is_enabled,
						category = EXCLUDED.category,
						sort_order = EXCLUDED.sort_order
				`, publisherID, zmanKey, hebrewName, englishName,
					zman.Formula, category, i+1)
			}
			if err != nil {
				slog.Error("CompleteOnboarding failed to insert zman", "zman_key", zmanKey, "error", err)
				RespondInternalError(w, r, "Failed to import zmanim: "+err.Error())
				return
			}
		}
		slog.Info("CompleteOnboarding successfully imported zmanim", "count", len(enabledZmanim))
	} else {
		// Fallback: import essential zmanim from templates if no customizations
		_, err = h.db.Pool.Exec(ctx, `
			INSERT INTO publisher_zmanim (
				publisher_id, zman_key, hebrew_name, english_name, formula_dsl,
				is_enabled, is_visible, is_published, is_custom, category, sort_order
			)
			SELECT
				$1, zman_key, hebrew_name, english_name, formula_dsl,
				true, true, false, false, category, sort_order
			FROM zmanim_templates
			WHERE category = 'essential' OR is_required = true
			ON CONFLICT (publisher_id, zman_key) DO NOTHING
		`, publisherID)
		if err != nil {
			RespondInternalError(w, r, "Failed to import zmanim")
			return
		}
	}

	// Import coverage from wizard selections
	if len(data.Coverage) > 0 {
		slog.Info("CompleteOnboarding importing coverage", "count", len(data.Coverage))
		for i, cov := range data.Coverage {
			slog.Debug("CompleteOnboarding processing coverage", "index", i+1, "type", cov.Type, "id", cov.ID, "name", cov.Name)

			switch cov.Type {
			case "continent":
				// For continent coverage, the ID is the continent code (e.g., "EU", "NA")
				_, err = h.db.Pool.Exec(ctx, `
					INSERT INTO publisher_coverage (publisher_id, coverage_level, continent_code)
					VALUES ($1, 'continent', $2)
					ON CONFLICT DO NOTHING
				`, publisherID, cov.ID)
				if err != nil {
					slog.Error("CompleteOnboarding failed to insert continent coverage", "id", cov.ID, "error", err)
				}

			case "country":
				// For country coverage, the ID is the country code
				_, err = h.db.Pool.Exec(ctx, `
					INSERT INTO publisher_coverage (publisher_id, coverage_level, country_code)
					VALUES ($1, 'country', $2)
					ON CONFLICT DO NOTHING
				`, publisherID, cov.ID)
				if err != nil {
					slog.Error("CompleteOnboarding failed to insert country coverage", "id", cov.ID, "error", err)
				}

			case "region":
				// For region coverage, the ID is "country_code-region_name" (e.g., "US-California")
				parts := splitFirst(cov.ID, "-")
				if len(parts) == 2 {
					_, err = h.db.Pool.Exec(ctx, `
						INSERT INTO publisher_coverage (publisher_id, coverage_level, country_code, region)
						VALUES ($1, 'region', $2, $3)
						ON CONFLICT DO NOTHING
					`, publisherID, parts[0], parts[1])
					if err != nil {
						slog.Error("CompleteOnboarding failed to insert region coverage", "id", cov.ID, "error", err)
					}
				} else {
					slog.Warn("CompleteOnboarding invalid region ID format", "id", cov.ID)
				}

			case "city":
				// For city coverage, the ID could be a UUID or a quick-select ID
				// Quick select IDs are like "quick-jerusalem-IL" - we need to look up the actual city
				if isQuickSelectID(cov.ID) {
					// Look up city by name from quick select
					cityName := extractCityNameFromQuickID(cov.ID)
					var cityID string
					err = h.db.Pool.QueryRow(ctx, `
						SELECT id FROM cities WHERE LOWER(name) = LOWER($1) LIMIT 1
					`, cityName).Scan(&cityID)
					if err != nil {
						slog.Warn("CompleteOnboarding could not find city for quick select", "id", cov.ID, "error", err)
						continue
					}
					_, err = h.db.Pool.Exec(ctx, `
						INSERT INTO publisher_coverage (publisher_id, coverage_level, city_id)
						VALUES ($1, 'city', $2)
						ON CONFLICT DO NOTHING
					`, publisherID, cityID)
					if err != nil {
						slog.Error("CompleteOnboarding failed to insert city coverage", "city_id", cityID, "error", err)
					}
				} else {
					// Regular city ID (UUID)
					_, err = h.db.Pool.Exec(ctx, `
						INSERT INTO publisher_coverage (publisher_id, coverage_level, city_id)
						VALUES ($1, 'city', $2)
						ON CONFLICT DO NOTHING
					`, publisherID, cov.ID)
					if err != nil {
						slog.Error("CompleteOnboarding failed to insert city coverage", "id", cov.ID, "error", err)
					}
				}
			}
		}
		slog.Info("CompleteOnboarding finished importing coverage")
	}

	// Mark onboarding as complete
	_, _ = h.db.Pool.Exec(ctx, `
		UPDATE publisher_onboarding
		SET completed_at = NOW(), current_step = 5
		WHERE publisher_id = $1
	`, publisherID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"status":  "completed",
		"message": "Onboarding completed successfully",
	})
}

// splitFirst splits a string on the first occurrence of sep
func splitFirst(s, sep string) []string {
	idx := -1
	for i := 0; i < len(s); i++ {
		if s[i:i+len(sep)] == sep {
			idx = i
			break
		}
	}
	if idx == -1 {
		return []string{s}
	}
	return []string{s[:idx], s[idx+len(sep):]}
}

// isQuickSelectID checks if the ID is a quick-select format (quick-cityname-countrycode)
func isQuickSelectID(id string) bool {
	return len(id) > 6 && id[:6] == "quick-"
}

// extractCityNameFromQuickID extracts the city name from a quick-select ID
// e.g., "quick-jerusalem-IL" -> "jerusalem", "quick-new-york-US" -> "new york"
func extractCityNameFromQuickID(id string) string {
	if len(id) <= 6 {
		return ""
	}
	// Remove "quick-" prefix
	rest := id[6:]
	// Remove the last part (country code) by finding the last dash
	lastDash := -1
	for i := len(rest) - 1; i >= 0; i-- {
		if rest[i] == '-' {
			lastDash = i
			break
		}
	}
	if lastDash == -1 {
		return rest
	}
	// Replace remaining dashes with spaces for city names like "new-york"
	cityName := rest[:lastDash]
	result := ""
	for _, c := range cityName {
		if c == '-' {
			result += " "
		} else {
			result += string(c)
		}
	}
	return result
}

// SkipOnboarding allows a publisher to skip the wizard
// POST /api/publisher/onboarding/skip
func (h *Handlers) SkipOnboarding(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Mark as skipped
	_, err := h.db.Pool.Exec(ctx, `
		INSERT INTO publisher_onboarding (publisher_id, skipped)
		VALUES ($1, true)
		ON CONFLICT (publisher_id)
		DO UPDATE SET skipped = true, last_updated_at = NOW()
	`, publisherID)

	if err != nil {
		RespondInternalError(w, r, "Failed to skip onboarding")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]string{
		"status": "skipped",
	})
}

// ResetOnboarding deletes the onboarding state to allow restarting the wizard
// DELETE /api/publisher/onboarding
func (h *Handlers) ResetOnboarding(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Delete ALL zmanim for this publisher (wizard will re-import)
	_, err := h.db.Pool.Exec(ctx, `
		DELETE FROM publisher_zmanim WHERE publisher_id = $1
	`, publisherID)
	if err != nil {
		slog.Error("ResetOnboarding failed to delete zmanim", "error", err)
		RespondInternalError(w, r, "Failed to reset onboarding")
		return
	}

	// Delete coverage for this publisher (wizard will re-import)
	_, err = h.db.Pool.Exec(ctx, `
		DELETE FROM publisher_coverage WHERE publisher_id = $1
	`, publisherID)
	if err != nil {
		slog.Error("ResetOnboarding failed to delete coverage", "error", err)
		// Continue anyway, coverage deletion is not critical
	}

	// Delete onboarding state
	_, err = h.db.Pool.Exec(ctx, `
		DELETE FROM publisher_onboarding WHERE publisher_id = $1
	`, publisherID)

	if err != nil {
		RespondInternalError(w, r, "Failed to reset onboarding")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]string{
		"status": "reset",
	})
}
