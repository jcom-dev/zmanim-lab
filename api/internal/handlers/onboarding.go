package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/jcom-dev/zmanim-lab/internal/middleware"
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
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	// Get publisher ID
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
		json.Unmarshal(wizardData, &state.Data)
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
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	var req OnboardingState
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Get publisher ID
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

	// Convert data to JSON
	wizardData, _ := json.Marshal(req.Data)

	// Upsert onboarding state
	_, err := h.db.Pool.Exec(ctx, `
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
		RespondInternalError(w, r, "Failed to save onboarding state")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]string{
		"status": "saved",
	})
}

// CompleteOnboarding marks onboarding as complete and creates the algorithm
// POST /api/publisher/onboarding/complete
func (h *Handlers) CompleteOnboarding(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	// Get publisher ID
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

	// Get the wizard data
	var wizardData []byte
	err := h.db.Pool.QueryRow(ctx, `
		SELECT wizard_data FROM publisher_onboarding WHERE publisher_id = $1
	`, publisherID).Scan(&wizardData)
	if err != nil {
		RespondBadRequest(w, r, "No onboarding data found")
		return
	}

	var data map[string]interface{}
	json.Unmarshal(wizardData, &data)

	// Create the algorithm from wizard data
	algorithmJSON, _ := json.Marshal(data)

	_, err = h.db.Pool.Exec(ctx, `
		INSERT INTO publisher_algorithms (
			publisher_id, name, description, algorithm_data, is_published, created_at, updated_at
		) VALUES (
			$1, 'My Algorithm', 'Created via onboarding wizard', $2, true, NOW(), NOW()
		)
		ON CONFLICT (publisher_id)
		DO UPDATE SET
			algorithm_data = EXCLUDED.algorithm_data,
			is_published = true,
			updated_at = NOW()
	`, publisherID, algorithmJSON)

	if err != nil {
		RespondInternalError(w, r, "Failed to create algorithm")
		return
	}

	// Mark onboarding as complete
	_, _ = h.db.Pool.Exec(ctx, `
		UPDATE publisher_onboarding
		SET completed_at = NOW(), current_step = 5
		WHERE publisher_id = $1
	`, publisherID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"status":  "completed",
		"message": "Algorithm created successfully",
	})
}

// SkipOnboarding allows a publisher to skip the wizard
// POST /api/publisher/onboarding/skip
func (h *Handlers) SkipOnboarding(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	// Get publisher ID
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
