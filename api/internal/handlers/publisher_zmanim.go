package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jcom-dev/zmanim-lab/internal/middleware"
	"github.com/jackc/pgx/v5"
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
	IsCustom         bool      `json:"is_custom" db:"is_custom"`
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
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found")
		return
	}

	// Get and validate publisher ID from header (validated against JWT claims)
	// Admins can impersonate any publisher via X-Publisher-Id header
	requestedID := r.Header.Get("X-Publisher-Id")
	publisherID := middleware.GetValidatedPublisherID(ctx, requestedID)
	if publisherID == "" {
		RespondForbidden(w, r, "No access to the requested publisher")
		return
	}

	query := `
		SELECT
			id, publisher_id, zman_key, hebrew_name, english_name,
			formula_dsl, ai_explanation, publisher_comment,
			is_enabled, is_visible, is_custom, category,
			dependencies, sort_order, created_at, updated_at
		FROM publisher_zmanim
		WHERE publisher_id = $1
		ORDER BY category, sort_order, hebrew_name
	`

	rows, err := h.db.Pool.Query(ctx, query, publisherID)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch zmanim")
		return
	}
	defer rows.Close()

	zmanim := []PublisherZman{}
	for rows.Next() {
		var z PublisherZman
		err := rows.Scan(
			&z.ID, &z.PublisherID, &z.ZmanKey, &z.HebrewName, &z.EnglishName,
			&z.FormulaDSL, &z.AIExplanation, &z.PublisherComment,
			&z.IsEnabled, &z.IsVisible, &z.IsCustom, &z.Category,
			&z.Dependencies, &z.SortOrder, &z.CreatedAt, &z.UpdatedAt,
		)
		if err != nil {
			RespondInternalError(w, r, "Failed to scan zman")
			return
		}
		zmanim = append(zmanim, z)
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"data": zmanim,
	})
}

// GetPublisherZman returns a single zman by key
// GET /api/v1/publisher/zmanim/{zmanKey}
func (h *Handlers) GetPublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found")
		return
	}

	zmanKey := chi.URLParam(r, "zmanKey")

	// Get publisher ID
	var publisherID string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT id FROM publishers WHERE clerk_user_id = $1",
		userID,
	).Scan(&publisherID)
	if err != nil {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	query := `
		SELECT
			id, publisher_id, zman_key, hebrew_name, english_name,
			formula_dsl, ai_explanation, publisher_comment,
			is_enabled, is_visible, is_custom, category,
			dependencies, sort_order, created_at, updated_at
		FROM publisher_zmanim
		WHERE publisher_id = $1 AND zman_key = $2
	`

	var z PublisherZman
	err = h.db.Pool.QueryRow(ctx, query, publisherID, zmanKey).Scan(
		&z.ID, &z.PublisherID, &z.ZmanKey, &z.HebrewName, &z.EnglishName,
		&z.FormulaDSL, &z.AIExplanation, &z.PublisherComment,
		&z.IsEnabled, &z.IsVisible, &z.IsCustom, &z.Category,
		&z.Dependencies, &z.SortOrder, &z.CreatedAt, &z.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Zman not found")
		return
	}
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch zman")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"data": z,
	})
}

// CreatePublisherZman creates a new custom zman
// POST /api/v1/publisher/zmanim
func (h *Handlers) CreatePublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found")
		return
	}

	// Get publisher ID
	var publisherID string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT id FROM publishers WHERE clerk_user_id = $1",
		userID,
	).Scan(&publisherID)
	if err != nil {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

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

	sortOrder := 0
	if req.SortOrder != nil {
		sortOrder = *req.SortOrder
	}

	id := uuid.New().String()

	query := `
		INSERT INTO publisher_zmanim (
			id, publisher_id, zman_key, hebrew_name, english_name,
			formula_dsl, ai_explanation, publisher_comment,
			is_enabled, is_visible, is_custom, category,
			dependencies, sort_order
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
		)
		RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
			formula_dsl, ai_explanation, publisher_comment,
			is_enabled, is_visible, is_custom, category,
			dependencies, sort_order, created_at, updated_at
	`

	var z PublisherZman
	err = h.db.Pool.QueryRow(
		ctx,
		query,
		id, publisherID, req.ZmanKey, req.HebrewName, req.EnglishName,
		req.FormulaDSL, req.AIExplanation, req.PublisherComment,
		isEnabled, isVisible, true, "custom", // is_custom=true for user-created
		dependencies, sortOrder,
	).Scan(
		&z.ID, &z.PublisherID, &z.ZmanKey, &z.HebrewName, &z.EnglishName,
		&z.FormulaDSL, &z.AIExplanation, &z.PublisherComment,
		&z.IsEnabled, &z.IsVisible, &z.IsCustom, &z.Category,
		&z.Dependencies, &z.SortOrder, &z.CreatedAt, &z.UpdatedAt,
	)

	if err != nil {
		// Check for unique constraint violation
		if strings.Contains(err.Error(), "duplicate key") {
			RespondBadRequest(w, r, fmt.Sprintf("Zman with key '%s' already exists", req.ZmanKey))
			return
		}
		RespondInternalError(w, r, "Failed to create zman")
		return
	}

	RespondJSON(w, r, http.StatusCreated, map[string]interface{}{
		"data": z,
	})
}

// UpdatePublisherZman updates an existing zman
// PUT /api/v1/publisher/zmanim/{zmanKey}
func (h *Handlers) UpdatePublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found")
		return
	}

	zmanKey := chi.URLParam(r, "zmanKey")

	// Get publisher ID
	var publisherID string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT id FROM publishers WHERE clerk_user_id = $1",
		userID,
	).Scan(&publisherID)
	if err != nil {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	var req UpdateZmanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Build dynamic update query
	updates := []string{}
	args := []interface{}{publisherID, zmanKey}
	argCount := 2

	if req.HebrewName != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("hebrew_name = $%d", argCount))
		args = append(args, *req.HebrewName)
	}

	if req.EnglishName != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("english_name = $%d", argCount))
		args = append(args, *req.EnglishName)
	}

	if req.FormulaDSL != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("formula_dsl = $%d", argCount))
		args = append(args, *req.FormulaDSL)

		// Re-extract dependencies when formula changes
		argCount++
		updates = append(updates, fmt.Sprintf("dependencies = $%d", argCount))
		args = append(args, extractDependencies(*req.FormulaDSL))
	}

	if req.AIExplanation != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("ai_explanation = $%d", argCount))
		args = append(args, *req.AIExplanation)
	}

	if req.PublisherComment != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("publisher_comment = $%d", argCount))
		args = append(args, *req.PublisherComment)
	}

	if req.IsEnabled != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("is_enabled = $%d", argCount))
		args = append(args, *req.IsEnabled)
	}

	if req.IsVisible != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("is_visible = $%d", argCount))
		args = append(args, *req.IsVisible)
	}

	if req.SortOrder != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("sort_order = $%d", argCount))
		args = append(args, *req.SortOrder)
	}

	if len(updates) == 0 {
		RespondBadRequest(w, r, "No fields to update")
		return
	}

	query := fmt.Sprintf(`
		UPDATE publisher_zmanim
		SET %s
		WHERE publisher_id = $1 AND zman_key = $2
		RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
			formula_dsl, ai_explanation, publisher_comment,
			is_enabled, is_visible, is_custom, category,
			dependencies, sort_order, created_at, updated_at
	`, strings.Join(updates, ", "))

	var z PublisherZman
	err = h.db.Pool.QueryRow(ctx, query, args...).Scan(
		&z.ID, &z.PublisherID, &z.ZmanKey, &z.HebrewName, &z.EnglishName,
		&z.FormulaDSL, &z.AIExplanation, &z.PublisherComment,
		&z.IsEnabled, &z.IsVisible, &z.IsCustom, &z.Category,
		&z.Dependencies, &z.SortOrder, &z.CreatedAt, &z.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Zman not found")
		return
	}
	if err != nil {
		RespondInternalError(w, r, "Failed to update zman")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"data": z,
	})
}

// DeletePublisherZman deletes a custom zman
// DELETE /api/v1/publisher/zmanim/{zmanKey}
func (h *Handlers) DeletePublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found")
		return
	}

	zmanKey := chi.URLParam(r, "zmanKey")

	// Get publisher ID
	var publisherID string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT id FROM publishers WHERE clerk_user_id = $1",
		userID,
	).Scan(&publisherID)
	if err != nil {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	query := `
		DELETE FROM publisher_zmanim
		WHERE publisher_id = $1 AND zman_key = $2 AND is_custom = true
		RETURNING id
	`

	var deletedID string
	err = h.db.Pool.QueryRow(ctx, query, publisherID, zmanKey).Scan(&deletedID)

	if err == pgx.ErrNoRows {
		RespondBadRequest(w, r, "Can only delete custom zmanim, or zman not found")
		return
	}
	if err != nil {
		RespondInternalError(w, r, "Failed to delete zman")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Zman deleted successfully",
	})
}

// GetZmanimTemplates returns all system templates
// GET /api/v1/zmanim/templates
func (h *Handlers) GetZmanimTemplates(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	query := `
		SELECT
			id, zman_key, hebrew_name, english_name, formula_dsl,
			category, description, is_required, sort_order,
			created_at, updated_at
		FROM zmanim_templates
		ORDER BY category, sort_order, hebrew_name
	`

	rows, err := h.db.Pool.Query(ctx, query)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch templates")
		return
	}
	defer rows.Close()

	templates := []ZmanimTemplate{}
	for rows.Next() {
		var t ZmanimTemplate
		err := rows.Scan(
			&t.ID, &t.ZmanKey, &t.HebrewName, &t.EnglishName, &t.FormulaDSL,
			&t.Category, &t.Description, &t.IsRequired, &t.SortOrder,
			&t.CreatedAt, &t.UpdatedAt,
		)
		if err != nil {
			RespondInternalError(w, r, "Failed to scan template")
			return
		}
		templates = append(templates, t)
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"data": templates,
	})
}

// BrowsePublicZmanim allows browsing public zmanim from other publishers
// GET /api/v1/zmanim/browse?q=search&category=optional
func (h *Handlers) BrowsePublicZmanim(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	searchQuery := r.URL.Query().Get("q")
	category := r.URL.Query().Get("category")

	query := `
		SELECT
			z.id, z.publisher_id, z.zman_key, z.hebrew_name, z.english_name,
			z.formula_dsl, z.category,
			p.name as publisher_name,
			COUNT(*) OVER (PARTITION BY z.zman_key) as usage_count
		FROM publisher_zmanim z
		JOIN publishers p ON p.id = z.publisher_id
		WHERE z.is_visible = true
	`

	args := []interface{}{}
	argCount := 0

	if searchQuery != "" {
		argCount++
		query += fmt.Sprintf(` AND (
			z.hebrew_name ILIKE $%d OR
			z.english_name ILIKE $%d OR
			z.formula_dsl ILIKE $%d
		)`, argCount, argCount, argCount)
		args = append(args, "%"+searchQuery+"%")
	}

	if category != "" {
		argCount++
		query += fmt.Sprintf(" AND z.category = $%d", argCount)
		args = append(args, category)
	}

	query += " ORDER BY usage_count DESC, z.hebrew_name LIMIT 50"

	rows, err := h.db.Pool.Query(ctx, query, args...)
	if err != nil {
		RespondInternalError(w, r, "Failed to browse zmanim")
		return
	}
	defer rows.Close()

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

	results := []BrowseResult{}
	for rows.Next() {
		var br BrowseResult
		err := rows.Scan(
			&br.ID, &br.PublisherID, &br.ZmanKey, &br.HebrewName, &br.EnglishName,
			&br.FormulaDSL, &br.Category, &br.PublisherName, &br.UsageCount,
		)
		if err != nil {
			RespondInternalError(w, r, "Failed to scan result")
			return
		}
		results = append(results, br)
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"data": results,
	})
}
