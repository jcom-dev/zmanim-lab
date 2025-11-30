package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jcom-dev/zmanim-lab/internal/db/sqlcgen"
)

// PublisherZman represents a single zman formula for a publisher
type PublisherZman struct {
	ID               string    `json:"id" db:"id"`
	PublisherID      string    `json:"publisher_id" db:"publisher_id"`
	ZmanKey          string    `json:"zman_key" db:"zman_key"`
	HebrewName       string    `json:"hebrew_name" db:"hebrew_name"`
	EnglishName      string    `json:"english_name" db:"english_name"`
	FormulaDSL       string    `json:"formula_dsl" db:"formula_dsl"`
	AIExplanation    *string   `json:"ai_explanation" db:"ai_explanation"`
	PublisherComment *string   `json:"publisher_comment" db:"publisher_comment"`
	IsEnabled        bool      `json:"is_enabled" db:"is_enabled"`
	IsVisible        bool      `json:"is_visible" db:"is_visible"`
	IsPublished      bool      `json:"is_published" db:"is_published"`
	IsCustom         bool      `json:"is_custom" db:"is_custom"`
	IsEventZman      bool      `json:"is_event_zman" db:"is_event_zman"`
	Category         string    `json:"category" db:"category"`
	Dependencies     []string  `json:"dependencies" db:"dependencies"`
	SortOrder        int       `json:"sort_order" db:"sort_order"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time `json:"updated_at" db:"updated_at"`
}

// ZmanimTemplate represents a system-wide default zman template
type ZmanimTemplate struct {
	ID          string    `json:"id" db:"id"`
	ZmanKey     string    `json:"zman_key" db:"zman_key"`
	HebrewName  string    `json:"hebrew_name" db:"hebrew_name"`
	EnglishName string    `json:"english_name" db:"english_name"`
	FormulaDSL  string    `json:"formula_dsl" db:"formula_dsl"`
	Category    string    `json:"category" db:"category"`
	Description *string   `json:"description" db:"description"`
	IsRequired  bool      `json:"is_required" db:"is_required"`
	SortOrder   int       `json:"sort_order" db:"sort_order"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// CreateZmanRequest represents the request body for creating a zman
type CreateZmanRequest struct {
	ZmanKey          string  `json:"zman_key" validate:"required"`
	HebrewName       string  `json:"hebrew_name" validate:"required"`
	EnglishName      string  `json:"english_name" validate:"required"`
	FormulaDSL       string  `json:"formula_dsl" validate:"required"`
	AIExplanation    *string `json:"ai_explanation"`
	PublisherComment *string `json:"publisher_comment"`
	IsEnabled        *bool   `json:"is_enabled"`
	IsVisible        *bool   `json:"is_visible"`
	SortOrder        *int    `json:"sort_order"`
}

// UpdateZmanRequest represents the request body for updating a zman
type UpdateZmanRequest struct {
	HebrewName       *string `json:"hebrew_name"`
	EnglishName      *string `json:"english_name"`
	FormulaDSL       *string `json:"formula_dsl"`
	AIExplanation    *string `json:"ai_explanation"`
	PublisherComment *string `json:"publisher_comment"`
	IsEnabled        *bool   `json:"is_enabled"`
	IsVisible        *bool   `json:"is_visible"`
	IsPublished      *bool   `json:"is_published"`
	Category         *string `json:"category"`
	SortOrder        *int    `json:"sort_order"`
}

// extractDependencies extracts @references from a DSL formula
func extractDependencies(formula string) []string {
	// Match @word_pattern (alphanumeric + underscores)
	re := regexp.MustCompile(`@([a-z_][a-z0-9_]*)`)
	matches := re.FindAllStringSubmatch(formula, -1)

	deps := make(map[string]bool) // Use map to avoid duplicates
	for _, match := range matches {
		if len(match) > 1 {
			deps[match[1]] = true
		}
	}

	// Convert map to slice
	result := make([]string, 0, len(deps))
	for dep := range deps {
		result = append(result, dep)
	}

	return result
}

// GetPublisherZmanim returns all zmanim for a publisher
// GET /api/v1/publisher/zmanim
func (h *Handlers) GetPublisherZmanim(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Log the publisher ID being queried
	log.Printf("INFO fetching zmanim publisher_id=%s", publisherID)

	// Use SQLc generated query
	sqlcZmanim, err := h.db.Queries.GetPublisherZmanim(ctx, publisherID)
	if err != nil {
		log.Printf("ERROR failed to fetch zmanim error=%v publisher_id=%s", err, publisherID)
		RespondInternalError(w, r, "Failed to fetch zmanim")
		return
	}

	// Log the result count
	log.Printf("INFO fetched zmanim count=%d publisher_id=%s", len(sqlcZmanim), publisherID)

	// Convert SQLc types to handler types for consistent API response
	zmanim := make([]PublisherZman, len(sqlcZmanim))
	for i, z := range sqlcZmanim {
		zmanim[i] = getPublisherZmanimRowToPublisherZman(z)
	}

	RespondJSON(w, r, http.StatusOK, zmanim)
}

// sqlcZmanRow is an interface for SQLc generated row types
type sqlcZmanRow interface {
	GetID() string
	GetPublisherID() string
	GetZmanKey() string
	GetHebrewName() string
	GetEnglishName() string
	GetFormulaDsl() string
	GetAiExplanation() *string
	GetPublisherComment() *string
	GetIsEnabled() bool
	GetIsVisible() bool
	GetIsPublished() bool
	GetIsCustom() bool
	GetCategory() string
	GetDependencies() []string
	GetSortOrder() int32
	GetCreatedAt() time.Time
	GetUpdatedAt() time.Time
}

// Convert GetPublisherZmanimRow to PublisherZman
func getPublisherZmanimRowToPublisherZman(z sqlcgen.GetPublisherZmanimRow) PublisherZman {
	return PublisherZman{
		ID:               z.ID,
		PublisherID:      z.PublisherID,
		ZmanKey:          z.ZmanKey,
		HebrewName:       z.HebrewName,
		EnglishName:      z.EnglishName,
		FormulaDSL:       z.FormulaDsl,
		AIExplanation:    z.AiExplanation,
		PublisherComment: z.PublisherComment,
		IsEnabled:        z.IsEnabled,
		IsVisible:        z.IsVisible,
		IsPublished:      z.IsPublished,
		IsCustom:         z.IsCustom,
		IsEventZman:      z.IsEventZman,
		Category:         z.Category,
		Dependencies:     z.Dependencies,
		SortOrder:        int(z.SortOrder),
		CreatedAt:        z.CreatedAt,
		UpdatedAt:        z.UpdatedAt,
	}
}

// Convert GetPublisherZmanByKeyRow to PublisherZman
func getPublisherZmanByKeyRowToPublisherZman(z sqlcgen.GetPublisherZmanByKeyRow) PublisherZman {
	return PublisherZman{
		ID:               z.ID,
		PublisherID:      z.PublisherID,
		ZmanKey:          z.ZmanKey,
		HebrewName:       z.HebrewName,
		EnglishName:      z.EnglishName,
		FormulaDSL:       z.FormulaDsl,
		AIExplanation:    z.AiExplanation,
		PublisherComment: z.PublisherComment,
		IsEnabled:        z.IsEnabled,
		IsVisible:        z.IsVisible,
		IsPublished:      z.IsPublished,
		IsCustom:         z.IsCustom,
		Category:         z.Category,
		Dependencies:     z.Dependencies,
		SortOrder:        int(z.SortOrder),
		CreatedAt:        z.CreatedAt,
		UpdatedAt:        z.UpdatedAt,
	}
}

// Convert CreatePublisherZmanRow to PublisherZman
func createPublisherZmanRowToPublisherZman(z sqlcgen.CreatePublisherZmanRow) PublisherZman {
	return PublisherZman{
		ID:               z.ID,
		PublisherID:      z.PublisherID,
		ZmanKey:          z.ZmanKey,
		HebrewName:       z.HebrewName,
		EnglishName:      z.EnglishName,
		FormulaDSL:       z.FormulaDsl,
		AIExplanation:    z.AiExplanation,
		PublisherComment: z.PublisherComment,
		IsEnabled:        z.IsEnabled,
		IsVisible:        z.IsVisible,
		IsPublished:      z.IsPublished,
		IsCustom:         z.IsCustom,
		Category:         z.Category,
		Dependencies:     z.Dependencies,
		SortOrder:        int(z.SortOrder),
		CreatedAt:        z.CreatedAt,
		UpdatedAt:        z.UpdatedAt,
	}
}

// Convert UpdatePublisherZmanRow to PublisherZman
func updatePublisherZmanRowToPublisherZman(z sqlcgen.UpdatePublisherZmanRow) PublisherZman {
	return PublisherZman{
		ID:               z.ID,
		PublisherID:      z.PublisherID,
		ZmanKey:          z.ZmanKey,
		HebrewName:       z.HebrewName,
		EnglishName:      z.EnglishName,
		FormulaDSL:       z.FormulaDsl,
		AIExplanation:    z.AiExplanation,
		PublisherComment: z.PublisherComment,
		IsEnabled:        z.IsEnabled,
		IsVisible:        z.IsVisible,
		IsPublished:      z.IsPublished,
		IsCustom:         z.IsCustom,
		Category:         z.Category,
		Dependencies:     z.Dependencies,
		SortOrder:        int(z.SortOrder),
		CreatedAt:        z.CreatedAt,
		UpdatedAt:        z.UpdatedAt,
	}
}

// Convert ImportZmanimFromTemplatesRow to PublisherZman
func importZmanimFromTemplatesRowToPublisherZman(z sqlcgen.ImportZmanimFromTemplatesRow) PublisherZman {
	return PublisherZman{
		ID:               z.ID,
		PublisherID:      z.PublisherID,
		ZmanKey:          z.ZmanKey,
		HebrewName:       z.HebrewName,
		EnglishName:      z.EnglishName,
		FormulaDSL:       z.FormulaDsl,
		AIExplanation:    z.AiExplanation,
		PublisherComment: z.PublisherComment,
		IsEnabled:        z.IsEnabled,
		IsVisible:        z.IsVisible,
		IsPublished:      z.IsPublished,
		IsCustom:         z.IsCustom,
		Category:         z.Category,
		Dependencies:     z.Dependencies,
		SortOrder:        int(z.SortOrder),
		CreatedAt:        z.CreatedAt,
		UpdatedAt:        z.UpdatedAt,
	}
}

// Convert ImportZmanimFromTemplatesByKeysRow to PublisherZman
func importZmanimFromTemplatesByKeysRowToPublisherZman(z sqlcgen.ImportZmanimFromTemplatesByKeysRow) PublisherZman {
	return PublisherZman{
		ID:               z.ID,
		PublisherID:      z.PublisherID,
		ZmanKey:          z.ZmanKey,
		HebrewName:       z.HebrewName,
		EnglishName:      z.EnglishName,
		FormulaDSL:       z.FormulaDsl,
		AIExplanation:    z.AiExplanation,
		PublisherComment: z.PublisherComment,
		IsEnabled:        z.IsEnabled,
		IsVisible:        z.IsVisible,
		IsPublished:      z.IsPublished,
		IsCustom:         z.IsCustom,
		Category:         z.Category,
		Dependencies:     z.Dependencies,
		SortOrder:        int(z.SortOrder),
		CreatedAt:        z.CreatedAt,
		UpdatedAt:        z.UpdatedAt,
	}
}

// GetPublisherZman returns a single zman by key
// GET /api/v1/publisher/zmanim/{zmanKey}
func (h *Handlers) GetPublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	zmanKey := chi.URLParam(r, "zmanKey")

	// Use SQLc generated query
	sqlcZman, err := h.db.Queries.GetPublisherZmanByKey(ctx, sqlcgen.GetPublisherZmanByKeyParams{
		PublisherID: publisherID,
		ZmanKey:     zmanKey,
	})

	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Zman not found")
		return
	}
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch zman")
		return
	}

	z := getPublisherZmanByKeyRowToPublisherZman(sqlcZman)

	RespondJSON(w, r, http.StatusOK, z)
}

// CreatePublisherZman creates a new custom zman
// POST /api/v1/publisher/zmanim
func (h *Handlers) CreatePublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	var req CreateZmanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate formula (basic check - full validation done by DSL validator)
	if len(strings.TrimSpace(req.FormulaDSL)) == 0 {
		RespondBadRequest(w, r, "Formula cannot be empty")
		return
	}

	// Extract dependencies from formula
	dependencies := extractDependencies(req.FormulaDSL)

	// Set defaults
	isEnabled := true
	if req.IsEnabled != nil {
		isEnabled = *req.IsEnabled
	}

	isVisible := true
	if req.IsVisible != nil {
		isVisible = *req.IsVisible
	}

	sortOrder := int32(0)
	if req.SortOrder != nil {
		sortOrder = int32(*req.SortOrder)
	}

	id := uuid.New().String()

	// Use SQLc generated query
	sqlcZman, insertErr := h.db.Queries.CreatePublisherZman(ctx, sqlcgen.CreatePublisherZmanParams{
		ID:               id,
		PublisherID:      publisherID,
		ZmanKey:          req.ZmanKey,
		HebrewName:       req.HebrewName,
		EnglishName:      req.EnglishName,
		FormulaDsl:       req.FormulaDSL,
		AiExplanation:    req.AIExplanation,
		PublisherComment: req.PublisherComment,
		IsEnabled:        isEnabled,
		IsVisible:        isVisible,
		IsPublished:      false, // New zmanim start unpublished
		IsCustom:         true,  // Custom zmanim are always user-created
		Category:         "custom",
		Dependencies:     dependencies,
		SortOrder:        sortOrder,
	})

	if insertErr != nil {
		// Check for unique constraint violation
		if strings.Contains(insertErr.Error(), "duplicate key") {
			RespondBadRequest(w, r, fmt.Sprintf("Zman with key '%s' already exists", req.ZmanKey))
			return
		}
		RespondInternalError(w, r, "Failed to create zman")
		return
	}

	z := createPublisherZmanRowToPublisherZman(sqlcZman)

	RespondJSON(w, r, http.StatusCreated, z)
}

// UpdatePublisherZman updates an existing zman
// PUT /api/v1/publisher/zmanim/{zmanKey}
func (h *Handlers) UpdatePublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	zmanKey := chi.URLParam(r, "zmanKey")

	// Read and log the raw body for debugging
	bodyBytes, readErr := io.ReadAll(r.Body)
	if readErr != nil {
		log.Printf("ERROR [UpdatePublisherZman] Failed to read body: %v", readErr)
		RespondBadRequest(w, r, "Failed to read request body")
		return
	}
	log.Printf("DEBUG [UpdatePublisherZman] Raw body for zman %s: %s", zmanKey, string(bodyBytes))

	var req UpdateZmanRequest
	if err := json.Unmarshal(bodyBytes, &req); err != nil {
		log.Printf("ERROR [UpdatePublisherZman] Failed to decode body: %v", err)
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	log.Printf("INFO [UpdatePublisherZman] Request for zman %s: Category=%v, IsEnabled=%v, IsPublished=%v",
		zmanKey, req.Category, req.IsEnabled, req.IsPublished)

	// At least one field must be provided
	if req.HebrewName == nil && req.EnglishName == nil && req.FormulaDSL == nil &&
		req.AIExplanation == nil && req.PublisherComment == nil &&
		req.IsEnabled == nil && req.IsVisible == nil && req.IsPublished == nil &&
		req.Category == nil && req.SortOrder == nil {
		log.Printf("ERROR [UpdatePublisherZman] No fields to update")
		RespondBadRequest(w, r, "No fields to update")
		return
	}

	// Extract dependencies if formula is updated
	var dependencies []string
	if req.FormulaDSL != nil {
		dependencies = extractDependencies(*req.FormulaDSL)
	}

	// Convert sort order to int32 pointer
	var sortOrder *int32
	if req.SortOrder != nil {
		so := int32(*req.SortOrder)
		sortOrder = &so
	}

	// Use SQLc generated query
	sqlcZman, updateErr := h.db.Queries.UpdatePublisherZman(ctx, sqlcgen.UpdatePublisherZmanParams{
		PublisherID:      publisherID,
		ZmanKey:          zmanKey,
		HebrewName:       req.HebrewName,
		EnglishName:      req.EnglishName,
		FormulaDsl:       req.FormulaDSL,
		AiExplanation:    req.AIExplanation,
		PublisherComment: req.PublisherComment,
		IsEnabled:        req.IsEnabled,
		IsVisible:        req.IsVisible,
		IsPublished:      req.IsPublished,
		Category:         req.Category,
		SortOrder:        sortOrder,
		Dependencies:     dependencies,
	})

	if updateErr == pgx.ErrNoRows {
		RespondNotFound(w, r, "Zman not found")
		return
	}
	if updateErr != nil {
		RespondInternalError(w, r, "Failed to update zman")
		return
	}

	z := updatePublisherZmanRowToPublisherZman(sqlcZman)

	RespondJSON(w, r, http.StatusOK, z)
}

// DeletePublisherZman deletes a custom zman
// DELETE /api/v1/publisher/zmanim/{zmanKey}
func (h *Handlers) DeletePublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	zmanKey := chi.URLParam(r, "zmanKey")

	// Use SQLc generated query
	_, deleteErr := h.db.Queries.DeletePublisherZman(ctx, sqlcgen.DeletePublisherZmanParams{
		PublisherID: publisherID,
		ZmanKey:     zmanKey,
	})

	if deleteErr == pgx.ErrNoRows {
		RespondBadRequest(w, r, "Can only delete custom zmanim, or zman not found")
		return
	}
	if deleteErr != nil {
		RespondInternalError(w, r, "Failed to delete zman")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Zman deleted successfully",
	})
}

// ImportZmanimRequest represents the request body for importing zmanim
type ImportZmanimRequest struct {
	Source      string   `json:"source"`       // "defaults" or "publisher"
	PublisherID *string  `json:"publisher_id"` // Required if source is "publisher"
	ZmanKeys    []string `json:"zman_keys"`    // Optional: specific keys to import (empty = all)
}

// ImportZmanim bulk imports zmanim from defaults or another publisher
// POST /api/v1/publisher/zmanim/import
func (h *Handlers) ImportZmanim(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	var req ImportZmanimRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate source
	if req.Source != "defaults" && req.Source != "publisher" {
		RespondBadRequest(w, r, "Source must be 'defaults' or 'publisher'")
		return
	}

	if req.Source == "publisher" && (req.PublisherID == nil || *req.PublisherID == "") {
		RespondBadRequest(w, r, "publisher_id is required when source is 'publisher'")
		return
	}

	var imported []PublisherZman

	if req.Source == "defaults" {
		// Import from zmanim_templates table using SQLc
		var err error

		if len(req.ZmanKeys) > 0 {
			// Import specific templates
			sqlcImported, importErr := h.db.Queries.ImportZmanimFromTemplatesByKeys(ctx, sqlcgen.ImportZmanimFromTemplatesByKeysParams{
				PublisherID: publisherID,
				Column2:     req.ZmanKeys,
			})
			err = importErr
			if err == nil {
				for _, z := range sqlcImported {
					imported = append(imported, importZmanimFromTemplatesByKeysRowToPublisherZman(z))
				}
			}
		} else {
			// Import all templates
			sqlcImported, importErr := h.db.Queries.ImportZmanimFromTemplates(ctx, publisherID)
			err = importErr
			if err == nil {
				for _, z := range sqlcImported {
					imported = append(imported, importZmanimFromTemplatesRowToPublisherZman(z))
				}
			}
		}

		if err != nil {
			RespondInternalError(w, r, "Failed to import templates: "+err.Error())
			return
		}

	} else {
		// Import from another publisher
		sourcePublisherID := *req.PublisherID

		// Verify source publisher exists and has public algorithm
		var isPublic bool
		err := h.db.Pool.QueryRow(ctx,
			"SELECT COALESCE(algorithm_public, false) FROM publishers WHERE id = $1",
			sourcePublisherID,
		).Scan(&isPublic)
		if err == pgx.ErrNoRows {
			RespondNotFound(w, r, "Source publisher not found")
			return
		}
		if err != nil {
			RespondInternalError(w, r, "Failed to check source publisher")
			return
		}
		if !isPublic {
			RespondForbidden(w, r, "Source publisher's algorithm is not public")
			return
		}

		// Note: Import from publisher still uses raw SQL as it's not in SQLc queries
		// This is intentional - less common operation, more complex query
		var query string
		var args []interface{}

		if len(req.ZmanKeys) > 0 {
			query = `
				INSERT INTO publisher_zmanim (
					id, publisher_id, zman_key, hebrew_name, english_name,
					formula_dsl, ai_explanation, publisher_comment,
					is_enabled, is_visible, is_custom, category,
					dependencies, sort_order
				)
				SELECT
					gen_random_uuid(), $1, zman_key, hebrew_name, english_name,
					formula_dsl, ai_explanation, NULL,
					true, true, false, category,
					dependencies, sort_order
				FROM publisher_zmanim
				WHERE publisher_id = $2 AND zman_key = ANY($3)
				ON CONFLICT (publisher_id, zman_key) DO NOTHING
				RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
					formula_dsl, ai_explanation, publisher_comment,
					is_enabled, is_visible, is_custom, category,
					dependencies, sort_order, created_at, updated_at
			`
			args = []interface{}{publisherID, sourcePublisherID, req.ZmanKeys}
		} else {
			query = `
				INSERT INTO publisher_zmanim (
					id, publisher_id, zman_key, hebrew_name, english_name,
					formula_dsl, ai_explanation, publisher_comment,
					is_enabled, is_visible, is_custom, category,
					dependencies, sort_order
				)
				SELECT
					gen_random_uuid(), $1, zman_key, hebrew_name, english_name,
					formula_dsl, ai_explanation, NULL,
					true, true, false, category,
					dependencies, sort_order
				FROM publisher_zmanim
				WHERE publisher_id = $2
				ON CONFLICT (publisher_id, zman_key) DO NOTHING
				RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
					formula_dsl, ai_explanation, publisher_comment,
					is_enabled, is_visible, is_custom, category,
					dependencies, sort_order, created_at, updated_at
			`
			args = []interface{}{publisherID, sourcePublisherID}
		}

		rows, err := h.db.Pool.Query(ctx, query, args...)
		if err != nil {
			RespondInternalError(w, r, "Failed to import from publisher: "+err.Error())
			return
		}
		defer rows.Close()

		for rows.Next() {
			var z PublisherZman
			err := rows.Scan(
				&z.ID, &z.PublisherID, &z.ZmanKey, &z.HebrewName, &z.EnglishName,
				&z.FormulaDSL, &z.AIExplanation, &z.PublisherComment,
				&z.IsEnabled, &z.IsVisible, &z.IsCustom, &z.Category,
				&z.Dependencies, &z.SortOrder, &z.CreatedAt, &z.UpdatedAt,
			)
			if err != nil {
				RespondInternalError(w, r, "Failed to scan imported zman")
				return
			}
			imported = append(imported, z)
		}
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"imported": imported,
		"count":    len(imported),
		"message":  fmt.Sprintf("Successfully imported %d zmanim", len(imported)),
	})
}

// GetZmanimTemplates returns all system templates
// GET /api/v1/zmanim/templates
func (h *Handlers) GetZmanimTemplates(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use SQLc generated query
	sqlcTemplates, err := h.db.Queries.GetZmanimTemplates(ctx)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch templates")
		return
	}

	// Convert to handler types
	templates := make([]ZmanimTemplate, len(sqlcTemplates))
	for i, t := range sqlcTemplates {
		templates[i] = sqlcTemplateToZmanimTemplate(t)
	}

	RespondJSON(w, r, http.StatusOK, templates)
}

// sqlcTemplateToZmanimTemplate converts SQLc generated type to handler type
func sqlcTemplateToZmanimTemplate(t sqlcgen.ZmanimTemplate) ZmanimTemplate {
	return ZmanimTemplate{
		ID:          t.ID,
		ZmanKey:     t.ZmanKey,
		HebrewName:  t.HebrewName,
		EnglishName: t.EnglishName,
		FormulaDSL:  t.FormulaDsl,
		Category:    t.Category,
		Description: t.Description,
		IsRequired:  t.IsRequired,
		SortOrder:   int(t.SortOrder),
		CreatedAt:   t.CreatedAt,
		UpdatedAt:   t.UpdatedAt,
	}
}

// BrowsePublicZmanim allows browsing public zmanim from other publishers
// GET /api/v1/zmanim/browse?q=search&category=optional
func (h *Handlers) BrowsePublicZmanim(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	searchQuery := r.URL.Query().Get("q")
	category := r.URL.Query().Get("category")

	// Use SQLc generated query
	sqlcResults, err := h.db.Queries.BrowsePublicZmanim(ctx, sqlcgen.BrowsePublicZmanimParams{
		Column1: searchQuery, // Search term (can be empty)
		Column2: category,    // Category filter (can be empty)
	})
	if err != nil {
		RespondInternalError(w, r, "Failed to browse zmanim")
		return
	}

	type BrowseResult struct {
		ID            string `json:"id"`
		PublisherID   string `json:"publisher_id"`
		PublisherName string `json:"publisher_name"`
		ZmanKey       string `json:"zman_key"`
		HebrewName    string `json:"hebrew_name"`
		EnglishName   string `json:"english_name"`
		FormulaDSL    string `json:"formula_dsl"`
		Category      string `json:"category"`
		UsageCount    int    `json:"usage_count"`
	}

	results := make([]BrowseResult, len(sqlcResults))
	for i, r := range sqlcResults {
		results[i] = BrowseResult{
			ID:            r.ID,
			PublisherID:   r.PublisherID,
			PublisherName: r.PublisherName,
			ZmanKey:       r.ZmanKey,
			HebrewName:    r.HebrewName,
			EnglishName:   r.EnglishName,
			FormulaDSL:    r.FormulaDsl,
			Category:      r.Category,
			UsageCount:    int(r.UsageCount),
		}
	}

	RespondJSON(w, r, http.StatusOK, results)
}
