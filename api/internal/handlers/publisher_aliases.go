package handlers

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jcom-dev/zmanim-lab/internal/db/sqlcgen"
)

// CreateAliasRequest is the request body for creating/updating an alias
type CreateAliasRequest struct {
	CustomHebrewName      string  `json:"custom_hebrew_name"`
	CustomEnglishName     string  `json:"custom_english_name"`
	CustomTransliteration *string `json:"custom_transliteration,omitempty"`
}

// AliasResponse is the response for a single alias
type AliasResponse struct {
	ID                    string  `json:"id"`
	ZmanKey               string  `json:"zman_key"`
	CustomHebrewName      string  `json:"custom_hebrew_name"`
	CustomEnglishName     string  `json:"custom_english_name"`
	CustomTransliteration *string `json:"custom_transliteration,omitempty"`
	CanonicalHebrewName   string  `json:"canonical_hebrew_name"`
	CanonicalEnglishName  string  `json:"canonical_english_name"`
	CreatedAt             string  `json:"created_at"`
	UpdatedAt             string  `json:"updated_at"`
}

// AliasListResponse is the response for listing aliases
type AliasListResponse struct {
	Aliases []AliasResponse `json:"aliases"`
}

// CreateOrUpdateAlias handles PUT /api/v1/publisher/zmanim/{zmanKey}/alias
func (h *Handlers) CreateOrUpdateAlias(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Step 1: Resolve publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}

	// Step 2: Extract URL params
	zmanKey := chi.URLParam(r, "zmanKey")
	if zmanKey == "" {
		RespondBadRequest(w, r, "zman_key is required")
		return
	}

	// Step 3: Parse request body
	var req CreateAliasRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Step 4: Validate inputs
	if req.CustomHebrewName == "" || req.CustomEnglishName == "" {
		RespondValidationError(w, r, "Hebrew and English names are required", nil)
		return
	}

	// Step 5: Execute business logic - upsert the alias
	alias, err := h.db.Queries.UpsertPublisherZmanAlias(ctx, sqlcgen.UpsertPublisherZmanAliasParams{
		PublisherID:           pc.PublisherID,
		ZmanKey:               zmanKey,
		CustomHebrewName:      req.CustomHebrewName,
		CustomEnglishName:     req.CustomEnglishName,
		CustomTransliteration: req.CustomTransliteration,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			RespondNotFound(w, r, "Zman not found in your published zmanim")
			return
		}
		slog.Error("failed to upsert alias", "error", err, "publisher_id", pc.PublisherID, "zman_key", zmanKey)
		RespondInternalError(w, r, "Failed to save alias")
		return
	}

	// Get the full alias with canonical names
	fullAlias, err := h.db.Queries.GetPublisherZmanAlias(ctx, sqlcgen.GetPublisherZmanAliasParams{
		PublisherID: pc.PublisherID,
		ZmanKey:     zmanKey,
	})
	if err != nil {
		slog.Error("failed to get alias after upsert", "error", err, "publisher_id", pc.PublisherID)
		RespondInternalError(w, r, "Failed to retrieve alias")
		return
	}

	// Step 6: Respond
	response := AliasResponse{
		ID:                    alias.ID,
		ZmanKey:               fullAlias.ZmanKey,
		CustomHebrewName:      fullAlias.CustomHebrewName,
		CustomEnglishName:     fullAlias.CustomEnglishName,
		CustomTransliteration: fullAlias.CustomTransliteration,
		CanonicalHebrewName:   fullAlias.CanonicalHebrewName,
		CanonicalEnglishName:  fullAlias.CanonicalEnglishName,
		CreatedAt:             alias.CreatedAt.Format("2006-01-02T15:04:05Z"),
		UpdatedAt:             alias.UpdatedAt.Format("2006-01-02T15:04:05Z"),
	}

	RespondJSON(w, r, http.StatusOK, response)
}

// GetAlias handles GET /api/v1/publisher/zmanim/{zmanKey}/alias
func (h *Handlers) GetAlias(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Step 1: Resolve publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}

	// Step 2: Extract URL params
	zmanKey := chi.URLParam(r, "zmanKey")
	if zmanKey == "" {
		RespondBadRequest(w, r, "zman_key is required")
		return
	}

	// Step 3-4: No request body to parse or validate

	// Step 5: Execute business logic
	alias, err := h.db.Queries.GetPublisherZmanAlias(ctx, sqlcgen.GetPublisherZmanAliasParams{
		PublisherID: pc.PublisherID,
		ZmanKey:     zmanKey,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Return null data (no alias exists) - not 404
			RespondJSON(w, r, http.StatusOK, nil)
			return
		}
		slog.Error("failed to get alias", "error", err, "publisher_id", pc.PublisherID, "zman_key", zmanKey)
		RespondInternalError(w, r, "Failed to retrieve alias")
		return
	}

	// Step 6: Respond
	response := AliasResponse{
		ID:                    alias.ID,
		ZmanKey:               alias.ZmanKey,
		CustomHebrewName:      alias.CustomHebrewName,
		CustomEnglishName:     alias.CustomEnglishName,
		CustomTransliteration: alias.CustomTransliteration,
		CanonicalHebrewName:   alias.CanonicalHebrewName,
		CanonicalEnglishName:  alias.CanonicalEnglishName,
		CreatedAt:             alias.CreatedAt.Format("2006-01-02T15:04:05Z"),
		UpdatedAt:             alias.UpdatedAt.Format("2006-01-02T15:04:05Z"),
	}

	RespondJSON(w, r, http.StatusOK, response)
}

// DeleteAlias handles DELETE /api/v1/publisher/zmanim/{zmanKey}/alias
func (h *Handlers) DeleteAlias(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Step 1: Resolve publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}

	// Step 2: Extract URL params
	zmanKey := chi.URLParam(r, "zmanKey")
	if zmanKey == "" {
		RespondBadRequest(w, r, "zman_key is required")
		return
	}

	// Step 3-4: No request body to parse or validate

	// Step 5: Execute business logic
	err := h.db.Queries.DeletePublisherZmanAlias(ctx, sqlcgen.DeletePublisherZmanAliasParams{
		PublisherID: pc.PublisherID,
		ZmanKey:     zmanKey,
	})
	if err != nil {
		slog.Error("failed to delete alias", "error", err, "publisher_id", pc.PublisherID, "zman_key", zmanKey)
		RespondInternalError(w, r, "Failed to delete alias")
		return
	}

	// Step 6: Respond with 204 No Content
	w.WriteHeader(http.StatusNoContent)
}

// ListAliases handles GET /api/v1/publisher/zmanim/aliases
func (h *Handlers) ListAliases(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Step 1: Resolve publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}

	// Step 2-4: No URL params or request body

	// Step 5: Execute business logic
	aliases, err := h.db.Queries.GetAllPublisherZmanAliases(ctx, pc.PublisherID)
	if err != nil {
		slog.Error("failed to list aliases", "error", err, "publisher_id", pc.PublisherID)
		RespondInternalError(w, r, "Failed to retrieve aliases")
		return
	}

	// Step 6: Respond
	response := AliasListResponse{
		Aliases: make([]AliasResponse, 0, len(aliases)),
	}

	for _, alias := range aliases {
		response.Aliases = append(response.Aliases, AliasResponse{
			ID:                    alias.ID,
			ZmanKey:               alias.ZmanKey,
			CustomHebrewName:      alias.CustomHebrewName,
			CustomEnglishName:     alias.CustomEnglishName,
			CustomTransliteration: alias.CustomTransliteration,
			CanonicalHebrewName:   alias.CanonicalHebrewName,
			CanonicalEnglishName:  alias.CanonicalEnglishName,
			CreatedAt:             alias.CreatedAt.Format("2006-01-02T15:04:05Z"),
			UpdatedAt:             alias.UpdatedAt.Format("2006-01-02T15:04:05Z"),
		})
	}

	RespondJSON(w, r, http.StatusOK, response)
}
