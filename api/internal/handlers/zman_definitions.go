package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jcom-dev/zmanim-lab/internal/algorithm"
	"github.com/jcom-dev/zmanim-lab/internal/validation"
)

// ZmanDefinition represents a zman with bilingual names
type ZmanDefinition struct {
	ID              string `json:"id,omitempty"`
	Key             string `json:"key"`
	NameHebrew      string `json:"name_hebrew"`
	NameEnglish     string `json:"name_english"`
	Transliteration string `json:"transliteration,omitempty"`
	Category        string `json:"category,omitempty"`
	SortOrder       int    `json:"sort_order,omitempty"`
	IsStandard      bool   `json:"is_standard,omitempty"`
}

// CreateZmanDefinitionRequest represents a request to create a zman definition
type CreateZmanDefinitionRequest struct {
	Key             string `json:"key"`
	NameHebrew      string `json:"name_hebrew"`
	NameEnglish     string `json:"name_english"`
	Transliteration string `json:"transliteration,omitempty"`
	Category        string `json:"category,omitempty"`
}

// GetZmanDefinitions returns all zman definitions
// GET /api/v1/zman-definitions
func (h *Handlers) GetZmanDefinitions(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Query parameters for filtering
	category := r.URL.Query().Get("category")
	standardOnly := r.URL.Query().Get("standard_only") == "true"

	// Build query
	query := `
		SELECT id, key, name_hebrew, name_english, transliteration, category, sort_order, is_standard
		FROM zman_definitions
		WHERE 1=1
	`
	args := []interface{}{}
	argIdx := 1

	if category != "" {
		query += " AND category = $" + string(rune('0'+argIdx))
		args = append(args, category)
		argIdx++
	}

	if standardOnly {
		query += " AND is_standard = true"
	}

	query += " ORDER BY sort_order, name_english"

	rows, err := h.db.Pool.Query(ctx, query, args...)
	if err != nil {
		RespondInternalError(w, r, "Failed to get zman definitions")
		return
	}
	defer rows.Close()

	definitions := []ZmanDefinition{}
	for rows.Next() {
		var def ZmanDefinition
		var transliteration, category *string
		err := rows.Scan(
			&def.ID, &def.Key, &def.NameHebrew, &def.NameEnglish,
			&transliteration, &category, &def.SortOrder, &def.IsStandard,
		)
		if err != nil {
			continue
		}
		if transliteration != nil {
			def.Transliteration = *transliteration
		}
		if category != nil {
			def.Category = *category
		}
		definitions = append(definitions, def)
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"definitions": definitions,
		"total":       len(definitions),
	})
}

// GetZmanDefinition returns a single zman definition by key
// GET /api/v1/zman-definitions/{key}
func (h *Handlers) GetZmanDefinition(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	key := chi.URLParam(r, "key")

	if key == "" {
		// Try to get bilingual name from algorithm package
		name := algorithm.GetBilingualName(key)
		RespondJSON(w, r, http.StatusOK, ZmanDefinition{
			Key:             key,
			NameHebrew:      name.Hebrew,
			NameEnglish:     name.English,
			Transliteration: name.Transliteration,
		})
		return
	}

	query := `
		SELECT id, key, name_hebrew, name_english, transliteration, category, sort_order, is_standard
		FROM zman_definitions
		WHERE key = $1
	`

	var def ZmanDefinition
	var transliteration, category *string
	err := h.db.Pool.QueryRow(ctx, query, key).Scan(
		&def.ID, &def.Key, &def.NameHebrew, &def.NameEnglish,
		&transliteration, &category, &def.SortOrder, &def.IsStandard,
	)

	if err != nil {
		// Fallback to algorithm package
		name := algorithm.GetBilingualName(key)
		RespondJSON(w, r, http.StatusOK, ZmanDefinition{
			Key:             key,
			NameHebrew:      name.Hebrew,
			NameEnglish:     name.English,
			Transliteration: name.Transliteration,
		})
		return
	}

	if transliteration != nil {
		def.Transliteration = *transliteration
	}
	if category != nil {
		def.Category = *category
	}

	RespondJSON(w, r, http.StatusOK, def)
}

// CreateZmanDefinition creates a new zman definition
// POST /api/publisher/zman-definitions
func (h *Handlers) CreateZmanDefinition(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req CreateZmanDefinitionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate bilingual names
	validationErrors := validation.ValidateBilingualNames(req.NameHebrew, req.NameEnglish)
	if validationErrors != nil {
		RespondValidationError(w, r, "Validation failed", validationErrors)
		return
	}

	// Validate key
	if req.Key == "" {
		RespondBadRequest(w, r, "Key is required")
		return
	}

	// Insert
	query := `
		INSERT INTO zman_definitions (key, name_hebrew, name_english, transliteration, category, is_standard)
		VALUES ($1, $2, $3, $4, $5, false)
		RETURNING id, key, name_hebrew, name_english, transliteration, category, sort_order, is_standard
	`

	var def ZmanDefinition
	var transliteration, category *string
	err := h.db.Pool.QueryRow(ctx, query,
		req.Key, req.NameHebrew, req.NameEnglish, req.Transliteration, req.Category,
	).Scan(
		&def.ID, &def.Key, &def.NameHebrew, &def.NameEnglish,
		&transliteration, &category, &def.SortOrder, &def.IsStandard,
	)

	if err != nil {
		if err.Error() == "duplicate key value" {
			RespondConflict(w, r, "Zman definition with this key already exists")
			return
		}
		RespondInternalError(w, r, "Failed to create zman definition")
		return
	}

	if transliteration != nil {
		def.Transliteration = *transliteration
	}
	if category != nil {
		def.Category = *category
	}

	RespondJSON(w, r, http.StatusCreated, def)
}

// UpdateZmanDefinition updates an existing zman definition
// PUT /api/publisher/zman-definitions/{key}
func (h *Handlers) UpdateZmanDefinition(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	key := chi.URLParam(r, "key")

	if key == "" {
		RespondBadRequest(w, r, "Key is required")
		return
	}

	var req CreateZmanDefinitionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate bilingual names
	validationErrors := validation.ValidateBilingualNames(req.NameHebrew, req.NameEnglish)
	if validationErrors != nil {
		RespondValidationError(w, r, "Validation failed", validationErrors)
		return
	}

	// Update
	query := `
		UPDATE zman_definitions
		SET name_hebrew = $1, name_english = $2, transliteration = $3, category = $4, updated_at = NOW()
		WHERE key = $5 AND is_standard = false
		RETURNING id, key, name_hebrew, name_english, transliteration, category, sort_order, is_standard
	`

	var def ZmanDefinition
	var transliteration, category *string
	err := h.db.Pool.QueryRow(ctx, query,
		req.NameHebrew, req.NameEnglish, req.Transliteration, req.Category, key,
	).Scan(
		&def.ID, &def.Key, &def.NameHebrew, &def.NameEnglish,
		&transliteration, &category, &def.SortOrder, &def.IsStandard,
	)

	if err != nil {
		RespondNotFound(w, r, "Zman definition not found or is a standard definition")
		return
	}

	if transliteration != nil {
		def.Transliteration = *transliteration
	}
	if category != nil {
		def.Category = *category
	}

	RespondJSON(w, r, http.StatusOK, def)
}
