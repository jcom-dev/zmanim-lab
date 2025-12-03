package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
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
	Transliteration  *string   `json:"transliteration,omitempty" db:"transliteration"`
	Description      *string   `json:"description,omitempty" db:"description"`
	FormulaDSL       string    `json:"formula_dsl" db:"formula_dsl"`
	AIExplanation    *string   `json:"ai_explanation" db:"ai_explanation"`
	PublisherComment *string   `json:"publisher_comment" db:"publisher_comment"`
	IsEnabled        bool      `json:"is_enabled" db:"is_enabled"`
	IsVisible        bool      `json:"is_visible" db:"is_visible"`
	IsPublished      bool      `json:"is_published" db:"is_published"`
	IsBeta           bool      `json:"is_beta" db:"is_beta"`
	IsCustom         bool      `json:"is_custom" db:"is_custom"`
	IsEventZman      bool      `json:"is_event_zman" db:"is_event_zman"`
	Category         string    `json:"category" db:"category"`
	Dependencies     []string  `json:"dependencies" db:"dependencies"`
	SortOrder        int       `json:"sort_order" db:"sort_order"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time `json:"updated_at" db:"updated_at"`
	Tags             []ZmanTag `json:"tags,omitempty" db:"tags"` // Tags from master zman
	// Linked zmanim support
	MasterZmanID              *string `json:"master_zman_id,omitempty" db:"master_zman_id"`
	LinkedPublisherZmanID     *string `json:"linked_publisher_zman_id,omitempty" db:"linked_publisher_zman_id"`
	SourceType                *string `json:"source_type,omitempty" db:"source_type"`
	IsLinked                  bool    `json:"is_linked" db:"is_linked"`
	LinkedSourcePublisherName *string `json:"linked_source_publisher_name,omitempty" db:"linked_source_publisher_name"`
	LinkedSourceIsDeleted     bool    `json:"linked_source_is_deleted" db:"linked_source_is_deleted"`
	// Source/original values from registry or linked publisher (for diff/revert functionality)
	SourceHebrewName      *string `json:"source_hebrew_name,omitempty" db:"source_hebrew_name"`
	SourceEnglishName     *string `json:"source_english_name,omitempty" db:"source_english_name"`
	SourceTransliteration *string `json:"source_transliteration,omitempty" db:"source_transliteration"`
	SourceDescription     *string `json:"source_description,omitempty" db:"source_description"`
	SourceFormulaDSL      *string `json:"source_formula_dsl,omitempty" db:"source_formula_dsl"`
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
	Transliteration  *string `json:"transliteration"`
	Description      *string `json:"description"`
	FormulaDSL       *string `json:"formula_dsl"`
	AIExplanation    *string `json:"ai_explanation"`
	PublisherComment *string `json:"publisher_comment"`
	IsEnabled        *bool   `json:"is_enabled"`
	IsVisible        *bool   `json:"is_visible"`
	IsPublished      *bool   `json:"is_published"`
	IsBeta           *bool   `json:"is_beta"`
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
	slog.Info("fetching zmanim", "publisher_id", publisherID)

	// Query with linked zmanim resolution
	query := `
		SELECT
			pz.id, pz.publisher_id, pz.zman_key, pz.hebrew_name, pz.english_name,
			pz.transliteration, pz.description,
			COALESCE(linked_pz.formula_dsl, pz.formula_dsl) AS formula_dsl,
			pz.ai_explanation, pz.publisher_comment,
			pz.is_enabled, pz.is_visible, pz.is_published, pz.is_beta, pz.is_custom, pz.category,
			pz.dependencies, pz.sort_order, pz.created_at, pz.updated_at,
			pz.master_zman_id, pz.linked_publisher_zman_id, pz.source_type,
			-- Source/original values from registry or linked publisher (for diff/revert UI)
			COALESCE(mr.canonical_hebrew_name, linked_pz.hebrew_name) AS source_hebrew_name,
			COALESCE(mr.canonical_english_name, linked_pz.english_name) AS source_english_name,
			COALESCE(mr.transliteration, linked_pz.transliteration) AS source_transliteration,
			COALESCE(mr.description, linked_pz.description) AS source_description,
			COALESCE(mr.default_formula_dsl, linked_pz.formula_dsl) AS source_formula_dsl,
			EXISTS (
				SELECT 1 FROM master_zman_events mze
				WHERE mze.master_zman_id = pz.master_zman_id
			) AS is_event_zman,
			COALESCE(
				(SELECT json_agg(json_build_object(
					'id', t.id,
					'tag_key', t.tag_key,
					'name', t.name,
					'display_name_hebrew', t.display_name_hebrew,
					'display_name_english', t.display_name_english,
					'tag_type', t.tag_type
				) ORDER BY t.sort_order)
				FROM master_zman_tags mzt
				JOIN zman_tags t ON mzt.tag_id = t.id
				WHERE mzt.master_zman_id = pz.master_zman_id),
				'[]'::json
			) AS tags,
			CASE WHEN pz.linked_publisher_zman_id IS NOT NULL THEN true ELSE false END AS is_linked,
			linked_pub.name AS linked_source_publisher_name,
			CASE WHEN pz.linked_publisher_zman_id IS NOT NULL AND linked_pz.deleted_at IS NOT NULL
				 THEN true ELSE false END AS linked_source_is_deleted
		FROM publisher_zmanim pz
		LEFT JOIN publisher_zmanim linked_pz ON pz.linked_publisher_zman_id = linked_pz.id
		LEFT JOIN publishers linked_pub ON linked_pz.publisher_id = linked_pub.id
		LEFT JOIN master_zmanim_registry mr ON pz.master_zman_id = mr.id
		WHERE pz.publisher_id = $1
		  AND pz.deleted_at IS NULL
		ORDER BY pz.sort_order, pz.hebrew_name
	`

	rows, err := h.db.Pool.Query(ctx, query, publisherID)
	if err != nil {
		slog.Error("failed to fetch zmanim", "error", err, "publisher_id", publisherID)
		RespondInternalError(w, r, "Failed to fetch zmanim")
		return
	}
	defer rows.Close()

	var zmanim []PublisherZman
	for rows.Next() {
		var z PublisherZman
		var tagsJSON []byte
		err := rows.Scan(
			&z.ID, &z.PublisherID, &z.ZmanKey, &z.HebrewName, &z.EnglishName,
			&z.Transliteration, &z.Description,
			&z.FormulaDSL, &z.AIExplanation, &z.PublisherComment,
			&z.IsEnabled, &z.IsVisible, &z.IsPublished, &z.IsBeta, &z.IsCustom, &z.Category,
			&z.Dependencies, &z.SortOrder, &z.CreatedAt, &z.UpdatedAt,
			&z.MasterZmanID, &z.LinkedPublisherZmanID, &z.SourceType,
			&z.SourceHebrewName, &z.SourceEnglishName, &z.SourceTransliteration, &z.SourceDescription, &z.SourceFormulaDSL,
			&z.IsEventZman, &tagsJSON, &z.IsLinked, &z.LinkedSourcePublisherName, &z.LinkedSourceIsDeleted,
		)
		if err != nil {
			slog.Error("failed to scan zman", "error", err, "publisher_id", publisherID)
			RespondInternalError(w, r, "Failed to fetch zmanim")
			return
		}

		// Parse tags JSON
		if len(tagsJSON) > 0 {
			_ = json.Unmarshal(tagsJSON, &z.Tags)
		}
		if z.Tags == nil {
			z.Tags = []ZmanTag{}
		}

		zmanim = append(zmanim, z)
	}

	// Log the result count
	slog.Info("fetched zmanim", "count", len(zmanim), "publisher_id", publisherID)

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
	var masterZmanID, linkedPublisherZmanID, linkedSourcePublisherName *string
	if z.MasterZmanID.Valid {
		id := z.MasterZmanID.Bytes[:]
		idStr := fmt.Sprintf("%x-%x-%x-%x-%x", id[0:4], id[4:6], id[6:8], id[8:10], id[10:16])
		masterZmanID = &idStr
	}
	if z.LinkedPublisherZmanID.Valid {
		id := z.LinkedPublisherZmanID.Bytes[:]
		idStr := fmt.Sprintf("%x-%x-%x-%x-%x", id[0:4], id[4:6], id[6:8], id[8:10], id[10:16])
		linkedPublisherZmanID = &idStr
	}
	if z.LinkedSourcePublisherName != nil {
		linkedSourcePublisherName = z.LinkedSourcePublisherName
	}

	// Convert source values - COALESCE makes these non-nullable strings
	var sourceHebrewName, sourceEnglishName, sourceTransliteration, sourceDescription, sourceFormulaDSL *string
	if z.SourceHebrewName != "" {
		sourceHebrewName = &z.SourceHebrewName
	}
	if z.SourceEnglishName != "" {
		sourceEnglishName = &z.SourceEnglishName
	}
	if z.SourceTransliteration != nil && *z.SourceTransliteration != "" {
		sourceTransliteration = z.SourceTransliteration
	}
	if z.SourceDescription != nil && *z.SourceDescription != "" {
		sourceDescription = z.SourceDescription
	}
	if z.SourceFormulaDsl != "" {
		sourceFormulaDSL = &z.SourceFormulaDsl
	}

	// Parse tags from JSON
	var tags []ZmanTag
	if z.Tags != nil {
		if tagsBytes, err := json.Marshal(z.Tags); err == nil {
			_ = json.Unmarshal(tagsBytes, &tags)
		}
	}

	return PublisherZman{
		ID:                        z.ID,
		PublisherID:               z.PublisherID,
		ZmanKey:                   z.ZmanKey,
		HebrewName:                z.HebrewName,
		EnglishName:               z.EnglishName,
		Transliteration:           z.Transliteration,
		Description:               z.Description,
		FormulaDSL:                z.FormulaDsl,
		AIExplanation:             z.AiExplanation,
		PublisherComment:          z.PublisherComment,
		IsEnabled:                 z.IsEnabled,
		IsVisible:                 z.IsVisible,
		IsPublished:               z.IsPublished,
		IsBeta:                    z.IsBeta,
		IsCustom:                  z.IsCustom,
		IsEventZman:               z.IsEventZman,
		Category:                  z.Category,
		Dependencies:              z.Dependencies,
		SortOrder:                 int(z.SortOrder),
		CreatedAt:                 z.CreatedAt,
		UpdatedAt:                 z.UpdatedAt,
		Tags:                      tags,
		MasterZmanID:              masterZmanID,
		LinkedPublisherZmanID:     linkedPublisherZmanID,
		SourceType:                z.SourceType,
		IsLinked:                  z.IsLinked,
		LinkedSourcePublisherName: linkedSourcePublisherName,
		LinkedSourceIsDeleted:     z.LinkedSourceIsDeleted,
		SourceHebrewName:          sourceHebrewName,
		SourceEnglishName:         sourceEnglishName,
		SourceTransliteration:     sourceTransliteration,
		SourceDescription:         sourceDescription,
		SourceFormulaDSL:          sourceFormulaDSL,
	}
}

// Convert GetPublisherZmanByKeyRow to PublisherZman
func getPublisherZmanByKeyRowToPublisherZman(z sqlcgen.GetPublisherZmanByKeyRow) PublisherZman {
	var masterZmanID, linkedPublisherZmanID, linkedSourcePublisherName *string
	if z.MasterZmanID.Valid {
		id := z.MasterZmanID.Bytes[:]
		idStr := fmt.Sprintf("%x-%x-%x-%x-%x", id[0:4], id[4:6], id[6:8], id[8:10], id[10:16])
		masterZmanID = &idStr
	}
	if z.LinkedPublisherZmanID.Valid {
		id := z.LinkedPublisherZmanID.Bytes[:]
		idStr := fmt.Sprintf("%x-%x-%x-%x-%x", id[0:4], id[4:6], id[6:8], id[8:10], id[10:16])
		linkedPublisherZmanID = &idStr
	}
	if z.LinkedSourcePublisherName != nil {
		linkedSourcePublisherName = z.LinkedSourcePublisherName
	}

	// Convert source values - COALESCE makes these non-nullable strings
	var sourceHebrewName, sourceEnglishName, sourceTransliteration, sourceDescription, sourceFormulaDSL *string
	if z.SourceHebrewName != "" {
		sourceHebrewName = &z.SourceHebrewName
	}
	if z.SourceEnglishName != "" {
		sourceEnglishName = &z.SourceEnglishName
	}
	if z.SourceTransliteration != nil && *z.SourceTransliteration != "" {
		sourceTransliteration = z.SourceTransliteration
	}
	if z.SourceDescription != nil && *z.SourceDescription != "" {
		sourceDescription = z.SourceDescription
	}
	if z.SourceFormulaDsl != "" {
		sourceFormulaDSL = &z.SourceFormulaDsl
	}

	return PublisherZman{
		ID:                        z.ID,
		PublisherID:               z.PublisherID,
		ZmanKey:                   z.ZmanKey,
		HebrewName:                z.HebrewName,
		EnglishName:               z.EnglishName,
		Transliteration:           z.Transliteration,
		Description:               z.Description,
		FormulaDSL:                z.FormulaDsl,
		AIExplanation:             z.AiExplanation,
		PublisherComment:          z.PublisherComment,
		IsEnabled:                 z.IsEnabled,
		IsVisible:                 z.IsVisible,
		IsPublished:               z.IsPublished,
		IsBeta:                    z.IsBeta,
		IsCustom:                  z.IsCustom,
		Category:                  z.Category,
		Dependencies:              z.Dependencies,
		SortOrder:                 int(z.SortOrder),
		CreatedAt:                 z.CreatedAt,
		UpdatedAt:                 z.UpdatedAt,
		MasterZmanID:              masterZmanID,
		LinkedPublisherZmanID:     linkedPublisherZmanID,
		SourceType:                z.SourceType,
		IsLinked:                  z.IsLinked,
		LinkedSourcePublisherName: linkedSourcePublisherName,
		SourceHebrewName:          sourceHebrewName,
		SourceEnglishName:         sourceEnglishName,
		SourceTransliteration:     sourceTransliteration,
		SourceDescription:         sourceDescription,
		SourceFormulaDSL:          sourceFormulaDSL,
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
		IsBeta:           z.IsBeta,
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
		Transliteration:  z.Transliteration,
		Description:      z.Description,
		FormulaDSL:       z.FormulaDsl,
		AIExplanation:    z.AiExplanation,
		PublisherComment: z.PublisherComment,
		IsEnabled:        z.IsEnabled,
		IsVisible:        z.IsVisible,
		IsPublished:      z.IsPublished,
		IsBeta:           z.IsBeta,
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
		slog.Error("UpdatePublisherZman: failed to read body", "error", readErr)
		RespondBadRequest(w, r, "Failed to read request body")
		return
	}
	slog.Debug("UpdatePublisherZman: raw body", "zman_key", zmanKey, "body", string(bodyBytes))

	var req UpdateZmanRequest
	if err := json.Unmarshal(bodyBytes, &req); err != nil {
		slog.Error("UpdatePublisherZman: failed to decode body", "error", err)
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	slog.Info("UpdatePublisherZman: request",
		"zman_key", zmanKey, "category", req.Category, "is_enabled", req.IsEnabled, "is_published", req.IsPublished, "is_beta", req.IsBeta)

	// At least one field must be provided
	if req.HebrewName == nil && req.EnglishName == nil && req.Transliteration == nil &&
		req.Description == nil && req.FormulaDSL == nil &&
		req.AIExplanation == nil && req.PublisherComment == nil &&
		req.IsEnabled == nil && req.IsVisible == nil && req.IsPublished == nil &&
		req.IsBeta == nil && req.Category == nil && req.SortOrder == nil {
		slog.Error("UpdatePublisherZman: no fields to update")
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
		Transliteration:  req.Transliteration,
		Description:      req.Description,
		FormulaDsl:       req.FormulaDSL,
		AiExplanation:    req.AIExplanation,
		PublisherComment: req.PublisherComment,
		IsEnabled:        req.IsEnabled,
		IsVisible:        req.IsVisible,
		IsPublished:      req.IsPublished,
		IsBeta:           req.IsBeta,
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

// VerifiedPublisher represents a verified publisher for linking
type VerifiedPublisher struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	LogoURL     *string `json:"logo_url,omitempty"`
	ZmanimCount int     `json:"zmanim_count"`
}

// PublisherZmanForLinking represents a zman available for linking/copying
type PublisherZmanForLinking struct {
	ID            string  `json:"id"`
	PublisherID   string  `json:"publisher_id"`
	PublisherName string  `json:"publisher_name"`
	ZmanKey       string  `json:"zman_key"`
	HebrewName    string  `json:"hebrew_name"`
	EnglishName   string  `json:"english_name"`
	FormulaDSL    string  `json:"formula_dsl"`
	Category      string  `json:"category"`
	SourceType    *string `json:"source_type,omitempty"`
}

// CreateFromPublisherRequest represents the request for copying/linking from another publisher
type CreateFromPublisherRequest struct {
	SourcePublisherZmanID string `json:"source_publisher_zman_id" validate:"required"`
	Mode                  string `json:"mode" validate:"required"` // "copy" or "link"
}

// GetVerifiedPublishers returns verified publishers that can be linked to
// GET /api/v1/publishers/verified
func (h *Handlers) GetVerifiedPublishers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context (to exclude self)
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	query := `
		SELECT
			p.id, p.name, p.logo_url,
			COUNT(pz.id) AS zmanim_count
		FROM publishers p
		JOIN publisher_zmanim pz ON pz.publisher_id = p.id
			AND pz.is_published = true
			AND pz.is_enabled = true
			AND pz.deleted_at IS NULL
		WHERE p.is_verified = true
		  AND p.status = 'active'
		  AND p.id != $1
		GROUP BY p.id, p.name, p.logo_url
		HAVING COUNT(pz.id) > 0
		ORDER BY p.name
	`

	rows, err := h.db.Pool.Query(ctx, query, publisherID)
	if err != nil {
		slog.Error("failed to fetch verified publishers", "error", err)
		RespondInternalError(w, r, "Failed to fetch publishers")
		return
	}
	defer rows.Close()

	var publishers []VerifiedPublisher
	for rows.Next() {
		var p VerifiedPublisher
		err := rows.Scan(&p.ID, &p.Name, &p.LogoURL, &p.ZmanimCount)
		if err != nil {
			slog.Error("failed to scan publisher", "error", err)
			RespondInternalError(w, r, "Failed to fetch publishers")
			return
		}
		publishers = append(publishers, p)
	}

	RespondJSON(w, r, http.StatusOK, publishers)
}

// GetPublisherZmanimForLinking returns zmanim from a publisher available for linking
// GET /api/v1/publishers/{publisherId}/zmanim
func (h *Handlers) GetPublisherZmanimForLinking(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get current publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	currentPublisherID := pc.PublisherID

	// Get target publisher ID from URL
	sourcePublisherID := chi.URLParam(r, "publisherId")
	if sourcePublisherID == "" {
		RespondBadRequest(w, r, "Publisher ID is required")
		return
	}

	// Verify source publisher is verified
	var isVerified bool
	err := h.db.Pool.QueryRow(ctx,
		"SELECT is_verified FROM publishers WHERE id = $1 AND status = 'active'",
		sourcePublisherID,
	).Scan(&isVerified)
	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Publisher not found")
		return
	}
	if err != nil {
		RespondInternalError(w, r, "Failed to verify publisher")
		return
	}
	if !isVerified {
		RespondForbidden(w, r, "Publisher is not verified for linking")
		return
	}

	query := `
		SELECT
			pz.id, pz.publisher_id, pz.zman_key, pz.hebrew_name, pz.english_name,
			pz.formula_dsl, pz.category, pz.source_type,
			p.name AS publisher_name
		FROM publisher_zmanim pz
		JOIN publishers p ON p.id = pz.publisher_id
		WHERE pz.publisher_id = $1
		  AND pz.is_published = true
		  AND pz.is_enabled = true
		  AND pz.deleted_at IS NULL
		  AND pz.zman_key NOT IN (
			  SELECT zman_key FROM publisher_zmanim WHERE publisher_id = $2 AND deleted_at IS NULL
		  )
		ORDER BY pz.sort_order, pz.hebrew_name
	`

	rows, err := h.db.Pool.Query(ctx, query, sourcePublisherID, currentPublisherID)
	if err != nil {
		slog.Error("failed to fetch zmanim for linking", "error", err)
		RespondInternalError(w, r, "Failed to fetch zmanim")
		return
	}
	defer rows.Close()

	var zmanim []PublisherZmanForLinking
	for rows.Next() {
		var z PublisherZmanForLinking
		err := rows.Scan(&z.ID, &z.PublisherID, &z.ZmanKey, &z.HebrewName, &z.EnglishName,
			&z.FormulaDSL, &z.Category, &z.SourceType, &z.PublisherName)
		if err != nil {
			slog.Error("failed to scan zman", "error", err)
			RespondInternalError(w, r, "Failed to fetch zmanim")
			return
		}
		zmanim = append(zmanim, z)
	}

	RespondJSON(w, r, http.StatusOK, zmanim)
}

// CreateZmanFromPublisher creates a zman by copying or linking from another publisher
// POST /api/v1/publisher/zmanim/from-publisher
func (h *Handlers) CreateZmanFromPublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	var req CreateFromPublisherRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate mode
	if req.Mode != "copy" && req.Mode != "link" {
		RespondBadRequest(w, r, "Mode must be 'copy' or 'link'")
		return
	}

	// Fetch source zman
	var sourceZman struct {
		ID            string
		PublisherID   string
		ZmanKey       string
		HebrewName    string
		EnglishName   string
		FormulaDSL    string
		Category      string
		Dependencies  []string
		SortOrder     int32
		MasterZmanID  *string
		IsVerified    bool
	}

	err := h.db.Pool.QueryRow(ctx, `
		SELECT
			pz.id, pz.publisher_id, pz.zman_key, pz.hebrew_name, pz.english_name,
			pz.formula_dsl, pz.category, pz.dependencies, pz.sort_order, pz.master_zman_id,
			p.is_verified
		FROM publisher_zmanim pz
		JOIN publishers p ON p.id = pz.publisher_id
		WHERE pz.id = $1
		  AND pz.is_published = true
		  AND pz.is_enabled = true
		  AND pz.deleted_at IS NULL
	`, req.SourcePublisherZmanID).Scan(
		&sourceZman.ID, &sourceZman.PublisherID, &sourceZman.ZmanKey, &sourceZman.HebrewName,
		&sourceZman.EnglishName, &sourceZman.FormulaDSL, &sourceZman.Category,
		&sourceZman.Dependencies, &sourceZman.SortOrder, &sourceZman.MasterZmanID, &sourceZman.IsVerified,
	)

	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Source zman not found or not available")
		return
	}
	if err != nil {
		slog.Error("failed to fetch source zman", "error", err)
		RespondInternalError(w, r, "Failed to fetch source zman")
		return
	}

	// For linking, verify source publisher is verified
	if req.Mode == "link" && !sourceZman.IsVerified {
		RespondForbidden(w, r, "Can only link to zmanim from verified publishers")
		return
	}

	// Check if zman_key already exists for this publisher
	var exists bool
	err = h.db.Pool.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM publisher_zmanim WHERE publisher_id = $1 AND zman_key = $2 AND deleted_at IS NULL)",
		publisherID, sourceZman.ZmanKey,
	).Scan(&exists)
	if err != nil {
		RespondInternalError(w, r, "Failed to check existing zman")
		return
	}
	if exists {
		RespondBadRequest(w, r, fmt.Sprintf("Zman with key '%s' already exists", sourceZman.ZmanKey))
		return
	}

	newID := uuid.New().String()
	var sourceType string
	var linkedID *string
	var formulaDSL string

	if req.Mode == "copy" {
		sourceType = "copied"
		linkedID = nil
		formulaDSL = sourceZman.FormulaDSL
	} else {
		sourceType = "linked"
		linkedID = &sourceZman.ID
		formulaDSL = "" // For linked zmanim, formula is resolved at query time
	}

	// Insert the new zman
	query := `
		INSERT INTO publisher_zmanim (
			id, publisher_id, zman_key, hebrew_name, english_name,
			formula_dsl, is_enabled, is_visible, is_published, is_custom, category,
			dependencies, sort_order, master_zman_id, linked_publisher_zman_id, source_type
		) VALUES (
			$1, $2, $3, $4, $5, $6, true, true, false, false, $7, $8, $9, $10, $11, $12
		)
		RETURNING id, created_at, updated_at
	`

	var createdAt, updatedAt time.Time
	err = h.db.Pool.QueryRow(ctx, query,
		newID, publisherID, sourceZman.ZmanKey, sourceZman.HebrewName, sourceZman.EnglishName,
		formulaDSL, sourceZman.Category, sourceZman.Dependencies, sourceZman.SortOrder,
		sourceZman.MasterZmanID, linkedID, sourceType,
	).Scan(&newID, &createdAt, &updatedAt)

	if err != nil {
		if strings.Contains(err.Error(), "duplicate key") {
			RespondBadRequest(w, r, fmt.Sprintf("Zman with key '%s' already exists", sourceZman.ZmanKey))
			return
		}
		slog.Error("failed to create zman from publisher", "error", err)
		RespondInternalError(w, r, "Failed to create zman")
		return
	}

	// Return the created zman
	result := PublisherZman{
		ID:                    newID,
		PublisherID:           publisherID,
		ZmanKey:               sourceZman.ZmanKey,
		HebrewName:            sourceZman.HebrewName,
		EnglishName:           sourceZman.EnglishName,
		FormulaDSL:            sourceZman.FormulaDSL, // Return the resolved formula
		IsEnabled:             true,
		IsVisible:             true,
		IsPublished:           false,
		IsCustom:              false,
		Category:              sourceZman.Category,
		Dependencies:          sourceZman.Dependencies,
		SortOrder:             int(sourceZman.SortOrder),
		CreatedAt:             createdAt,
		UpdatedAt:             updatedAt,
		MasterZmanID:          sourceZman.MasterZmanID,
		LinkedPublisherZmanID: linkedID,
		SourceType:            &sourceType,
		IsLinked:              req.Mode == "link",
	}

	RespondJSON(w, r, http.StatusCreated, result)
}
