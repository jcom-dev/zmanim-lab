package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// ============================================
// TYPES
// ============================================

// MasterZman represents a canonical zman from the master registry
type MasterZman struct {
	ID                   string    `json:"id"`
	ZmanKey              string    `json:"zman_key"`
	CanonicalHebrewName  string    `json:"canonical_hebrew_name"`
	CanonicalEnglishName string    `json:"canonical_english_name"`
	Transliteration      *string   `json:"transliteration,omitempty"`
	Description          *string   `json:"description,omitempty"`
	HalachicNotes        *string   `json:"halachic_notes,omitempty"`
	HalachicSource       *string   `json:"halachic_source,omitempty"`
	TimeCategory         string    `json:"time_category"`
	DefaultFormulaDSL    string    `json:"default_formula_dsl"`
	IsFundamental        bool      `json:"is_fundamental"`
	SortOrder            int       `json:"sort_order"`
	CreatedAt            time.Time `json:"created_at"`
	UpdatedAt            time.Time `json:"updated_at"`
	Tags                 []ZmanTag `json:"tags,omitempty"`
	DayTypes             []string  `json:"day_types,omitempty"` // Day types this zman applies to
}

// ZmanTag represents a tag for categorizing zmanim
type ZmanTag struct {
	ID                 string    `json:"id"`
	Name               string    `json:"name"`
	DisplayNameHebrew  string    `json:"display_name_hebrew"`
	DisplayNameEnglish string    `json:"display_name_english"`
	TagType            string    `json:"tag_type"`
	Description        *string   `json:"description,omitempty"`
	Color              *string   `json:"color,omitempty"`
	SortOrder          int       `json:"sort_order"`
	CreatedAt          time.Time `json:"created_at"`
}

// DayType represents a type of day (Shabbos, Yom Tov, Taanis, etc.)
type DayType struct {
	ID                 string  `json:"id"`
	Name               string  `json:"name"`
	DisplayNameHebrew  string  `json:"display_name_hebrew"`
	DisplayNameEnglish string  `json:"display_name_english"`
	Description        *string `json:"description,omitempty"`
	ParentType         *string `json:"parent_type,omitempty"`
	SortOrder          int     `json:"sort_order"`
}

// MasterZmanimGrouped represents zmanim grouped by time category
type MasterZmanimGrouped struct {
	TimeCategory string       `json:"time_category"`
	DisplayName  string       `json:"display_name"`
	Zmanim       []MasterZman `json:"zmanim"`
}

// ZmanVersion represents a version in the per-zman history
type ZmanVersion struct {
	ID              string    `json:"id"`
	PublisherZmanID string    `json:"publisher_zman_id"`
	VersionNumber   int       `json:"version_number"`
	FormulaDSL      string    `json:"formula_dsl"`
	CreatedBy       *string   `json:"created_by,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
}

// DeletedZman represents a soft-deleted zman
type DeletedZman struct {
	ID           string    `json:"id"`
	PublisherID  string    `json:"publisher_id"`
	ZmanKey      string    `json:"zman_key"`
	HebrewName   string    `json:"hebrew_name"`
	EnglishName  string    `json:"english_name"`
	FormulaDSL   string    `json:"formula_dsl"`
	TimeCategory string    `json:"time_category"`
	DeletedAt    time.Time `json:"deleted_at"`
	DeletedBy    *string   `json:"deleted_by,omitempty"`
	MasterZmanID *string   `json:"master_zman_id,omitempty"`
}

// ZmanRegistryRequest represents a request to add a new zman to the registry
type ZmanRegistryRequest struct {
	ID                   string     `json:"id"`
	PublisherID          string     `json:"publisher_id"`
	RequestedKey         string     `json:"requested_key"`
	RequestedHebrewName  string     `json:"requested_hebrew_name"`
	RequestedEnglishName string     `json:"requested_english_name"`
	RequestedFormulaDSL  *string    `json:"requested_formula_dsl,omitempty"`
	TimeCategory         string     `json:"time_category"`
	Justification        string     `json:"justification"`
	Status               string     `json:"status"`
	ReviewedBy           *string    `json:"reviewed_by,omitempty"`
	ReviewedAt           *time.Time `json:"reviewed_at,omitempty"`
	ReviewerNotes        *string    `json:"reviewer_notes,omitempty"`
	CreatedAt            time.Time  `json:"created_at"`
}

// Request bodies
type CreateZmanFromRegistryRequest struct {
	MasterZmanID string  `json:"master_zman_id" validate:"required"`
	FormulaDSL   *string `json:"formula_dsl"` // Optional override
}

type RollbackZmanRequest struct {
	VersionNumber int `json:"version_number" validate:"required"`
}

type CreateZmanRegistryRequestBody struct {
	RequestedKey         string  `json:"requested_key" validate:"required"`
	RequestedHebrewName  string  `json:"requested_hebrew_name" validate:"required"`
	RequestedEnglishName string  `json:"requested_english_name" validate:"required"`
	RequestedFormulaDSL  *string `json:"requested_formula_dsl"`
	TimeCategory         string  `json:"time_category" validate:"required"`
	Justification        string  `json:"justification" validate:"required"`
}

type ReviewZmanRequestBody struct {
	Status        string  `json:"status" validate:"required"` // "approved" or "rejected"
	ReviewerNotes *string `json:"reviewer_notes"`
}

// ============================================
// MASTER REGISTRY HANDLERS (PUBLIC)
// ============================================

// GetMasterZmanim returns all zmanim from the master registry
// @Summary Get all master zmanim
// @Tags Registry
// @Produce json
// @Param category query string false "Filter by time category"
// @Param search query string false "Search by name"
// @Param tag query string false "Filter by tag name"
// @Success 200 {array} MasterZman
// @Router /api/v1/registry/zmanim [get]
func (h *Handlers) GetMasterZmanim(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	category := r.URL.Query().Get("category")
	search := r.URL.Query().Get("search")
	tag := r.URL.Query().Get("tag")

	var zmanim []MasterZman

	// Build query based on filters
	if search != "" {
		// Search by name
		rows, err := h.db.Pool.Query(ctx, `
			SELECT id, zman_key, canonical_hebrew_name, canonical_english_name,
				transliteration, description, halachic_notes, halachic_source,
				time_category, default_formula_dsl, is_fundamental, sort_order,
				created_at, updated_at
			FROM master_zmanim_registry
			WHERE canonical_hebrew_name ILIKE '%' || $1 || '%'
				OR canonical_english_name ILIKE '%' || $1 || '%'
				OR transliteration ILIKE '%' || $1 || '%'
				OR zman_key ILIKE '%' || $1 || '%'
			ORDER BY sort_order LIMIT 50
		`, search)
		if err != nil {
			log.Printf("Error searching master zmanim: %v", err)
			RespondInternalError(w, r, "Failed to search master zmanim")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var z MasterZman
			err := rows.Scan(&z.ID, &z.ZmanKey, &z.CanonicalHebrewName, &z.CanonicalEnglishName,
				&z.Transliteration, &z.Description, &z.HalachicNotes, &z.HalachicSource,
				&z.TimeCategory, &z.DefaultFormulaDSL, &z.IsFundamental, &z.SortOrder,
				&z.CreatedAt, &z.UpdatedAt)
			if err != nil {
				log.Printf("Error scanning master zman: %v", err)
				continue
			}
			zmanim = append(zmanim, z)
		}
	} else if tag != "" {
		// Filter by tag
		rows, err := h.db.Pool.Query(ctx, `
			SELECT mr.id, mr.zman_key, mr.canonical_hebrew_name, mr.canonical_english_name,
				mr.transliteration, mr.description, mr.halachic_notes, mr.halachic_source,
				mr.time_category, mr.default_formula_dsl, mr.is_fundamental, mr.sort_order,
				mr.created_at, mr.updated_at
			FROM master_zmanim_registry mr
			JOIN master_zman_tags mzt ON mr.id = mzt.master_zman_id
			JOIN zman_tags t ON t.id = mzt.tag_id
			WHERE t.name = $1
			ORDER BY mr.time_category, mr.sort_order
		`, tag)
		if err != nil {
			log.Printf("Error getting master zmanim by tag: %v", err)
			RespondInternalError(w, r, "Failed to get master zmanim")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var z MasterZman
			err := rows.Scan(&z.ID, &z.ZmanKey, &z.CanonicalHebrewName, &z.CanonicalEnglishName,
				&z.Transliteration, &z.Description, &z.HalachicNotes, &z.HalachicSource,
				&z.TimeCategory, &z.DefaultFormulaDSL, &z.IsFundamental, &z.SortOrder,
				&z.CreatedAt, &z.UpdatedAt)
			if err != nil {
				log.Printf("Error scanning master zman: %v", err)
				continue
			}
			zmanim = append(zmanim, z)
		}
	} else if category != "" {
		// Filter by category
		rows, err := h.db.Pool.Query(ctx, `
			SELECT id, zman_key, canonical_hebrew_name, canonical_english_name,
				transliteration, description, halachic_notes, halachic_source,
				time_category, default_formula_dsl, is_fundamental, sort_order,
				created_at, updated_at
			FROM master_zmanim_registry
			WHERE time_category = $1
			ORDER BY sort_order, canonical_hebrew_name
		`, category)
		if err != nil {
			log.Printf("Error getting master zmanim by category: %v", err)
			RespondInternalError(w, r, "Failed to get master zmanim")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var z MasterZman
			err := rows.Scan(&z.ID, &z.ZmanKey, &z.CanonicalHebrewName, &z.CanonicalEnglishName,
				&z.Transliteration, &z.Description, &z.HalachicNotes, &z.HalachicSource,
				&z.TimeCategory, &z.DefaultFormulaDSL, &z.IsFundamental, &z.SortOrder,
				&z.CreatedAt, &z.UpdatedAt)
			if err != nil {
				log.Printf("Error scanning master zman: %v", err)
				continue
			}
			zmanim = append(zmanim, z)
		}
	} else {
		// Get all
		rows, err := h.db.Pool.Query(ctx, `
			SELECT id, zman_key, canonical_hebrew_name, canonical_english_name,
				transliteration, description, halachic_notes, halachic_source,
				time_category, default_formula_dsl, is_fundamental, sort_order,
				created_at, updated_at
			FROM master_zmanim_registry
			ORDER BY time_category, sort_order, canonical_hebrew_name
		`)
		if err != nil {
			log.Printf("Error getting all master zmanim: %v", err)
			RespondInternalError(w, r, "Failed to get master zmanim")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var z MasterZman
			err := rows.Scan(&z.ID, &z.ZmanKey, &z.CanonicalHebrewName, &z.CanonicalEnglishName,
				&z.Transliteration, &z.Description, &z.HalachicNotes, &z.HalachicSource,
				&z.TimeCategory, &z.DefaultFormulaDSL, &z.IsFundamental, &z.SortOrder,
				&z.CreatedAt, &z.UpdatedAt)
			if err != nil {
				log.Printf("Error scanning master zman: %v", err)
				continue
			}
			zmanim = append(zmanim, z)
		}
	}

	if zmanim == nil {
		zmanim = []MasterZman{}
	}

	RespondJSON(w, r, http.StatusOK, zmanim)
}

// GetMasterZmanimGrouped returns zmanim grouped by time category
// @Summary Get master zmanim grouped by time category
// @Tags Registry
// @Produce json
// @Param day_types query string false "Filter by day types (comma-separated, e.g., erev_shabbos,motzei_shabbos)"
// @Success 200 {array} MasterZmanimGrouped
// @Router /api/v1/registry/zmanim/grouped [get]
func (h *Handlers) GetMasterZmanimGrouped(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	dayTypesParam := r.URL.Query().Get("day_types")

	categoryOrder := []string{"dawn", "sunrise", "morning", "midday", "afternoon", "sunset", "nightfall", "midnight"}

	// Get zmanim - optionally filtered by day types
	var rows pgx.Rows
	var err error

	if dayTypesParam != "" {
		// Parse comma-separated day types
		dayTypes := strings.Split(dayTypesParam, ",")
		for i := range dayTypes {
			dayTypes[i] = strings.TrimSpace(dayTypes[i])
		}

		// Filter by multiple day types - get zmanim linked to any of these day types
		rows, err = h.db.Pool.Query(ctx, `
			SELECT DISTINCT mr.id, mr.zman_key, mr.canonical_hebrew_name, mr.canonical_english_name,
				mr.transliteration, mr.description, mr.halachic_notes, mr.halachic_source,
				mr.time_category, mr.default_formula_dsl, mr.is_fundamental, mr.sort_order,
				mr.created_at, mr.updated_at
			FROM master_zmanim_registry mr
			JOIN master_zman_day_types mzdt ON mr.id = mzdt.master_zman_id
			JOIN day_types dt ON dt.id = mzdt.day_type_id
			WHERE dt.name = ANY($1) AND mzdt.is_default = true
			ORDER BY mr.time_category, mr.sort_order, mr.canonical_hebrew_name
		`, dayTypes)
	} else {
		// Get all zmanim
		rows, err = h.db.Pool.Query(ctx, `
			SELECT id, zman_key, canonical_hebrew_name, canonical_english_name,
				transliteration, description, halachic_notes, halachic_source,
				time_category, default_formula_dsl, is_fundamental, sort_order,
				created_at, updated_at
			FROM master_zmanim_registry
			ORDER BY time_category, sort_order, canonical_hebrew_name
		`)
	}

	if err != nil {
		log.Printf("Error getting master zmanim: %v", err)
		RespondInternalError(w, r, "Failed to get master zmanim")
		return
	}
	defer rows.Close()

	// Group by category
	grouped := make(map[string][]MasterZman)
	for rows.Next() {
		var z MasterZman
		err := rows.Scan(&z.ID, &z.ZmanKey, &z.CanonicalHebrewName, &z.CanonicalEnglishName,
			&z.Transliteration, &z.Description, &z.HalachicNotes, &z.HalachicSource,
			&z.TimeCategory, &z.DefaultFormulaDSL, &z.IsFundamental, &z.SortOrder,
			&z.CreatedAt, &z.UpdatedAt)
		if err != nil {
			log.Printf("Error scanning master zman: %v", err)
			continue
		}
		grouped[z.TimeCategory] = append(grouped[z.TimeCategory], z)
	}

	// Build result as map keyed by category (for frontend consumption)
	result := make(map[string][]MasterZman)
	for _, cat := range categoryOrder {
		if zmanim, ok := grouped[cat]; ok {
			result[cat] = zmanim
		}
	}

	RespondJSON(w, r, http.StatusOK, result)
}

// GetEventZmanimGrouped returns event zmanim grouped by event_category
// @Summary Get event zmanim grouped by category (candles, havdalah, etc.)
// @Tags Registry
// @Produce json
// @Success 200 {object} map[string][]MasterZman
// @Router /api/v1/registry/zmanim/events [get]
func (h *Handlers) GetEventZmanimGrouped(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Event category order for display
	categoryOrder := []string{"candles", "havdalah", "yom_kippur", "fast_day", "tisha_bav", "pesach"}

	// Get all event zmanim (where event_category IS NOT NULL)
	rows, err := h.db.Pool.Query(ctx, `
		SELECT id, zman_key, canonical_hebrew_name, canonical_english_name,
			transliteration, description, halachic_notes, halachic_source,
			time_category, default_formula_dsl, is_fundamental, sort_order,
			event_category, created_at, updated_at
		FROM master_zmanim_registry
		WHERE event_category IS NOT NULL
		ORDER BY event_category, sort_order, canonical_hebrew_name
	`)
	if err != nil {
		log.Printf("Error getting event zmanim: %v", err)
		RespondInternalError(w, r, "Failed to get event zmanim")
		return
	}
	defer rows.Close()

	// Group by event_category
	grouped := make(map[string][]MasterZman)
	for rows.Next() {
		var z MasterZman
		var eventCategory *string
		err := rows.Scan(&z.ID, &z.ZmanKey, &z.CanonicalHebrewName, &z.CanonicalEnglishName,
			&z.Transliteration, &z.Description, &z.HalachicNotes, &z.HalachicSource,
			&z.TimeCategory, &z.DefaultFormulaDSL, &z.IsFundamental, &z.SortOrder,
			&eventCategory, &z.CreatedAt, &z.UpdatedAt)
		if err != nil {
			log.Printf("Error scanning event zman: %v", err)
			continue
		}
		if eventCategory != nil {
			grouped[*eventCategory] = append(grouped[*eventCategory], z)
		}
	}

	// Build result in category order
	result := make(map[string][]MasterZman)
	for _, cat := range categoryOrder {
		if zmanim, ok := grouped[cat]; ok {
			result[cat] = zmanim
		}
	}

	RespondJSON(w, r, http.StatusOK, result)
}

// GetMasterZman returns a single zman from the master registry
// @Summary Get master zman by key
// @Tags Registry
// @Produce json
// @Param zmanKey path string true "Zman key"
// @Success 200 {object} MasterZman
// @Router /api/v1/registry/zmanim/{zmanKey} [get]
func (h *Handlers) GetMasterZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	zmanKey := chi.URLParam(r, "zmanKey")

	var z MasterZman
	err := h.db.Pool.QueryRow(ctx, `
		SELECT id, zman_key, canonical_hebrew_name, canonical_english_name,
			transliteration, description, halachic_notes, halachic_source,
			time_category, default_formula_dsl, is_fundamental, sort_order,
			created_at, updated_at
		FROM master_zmanim_registry
		WHERE zman_key = $1
	`, zmanKey).Scan(&z.ID, &z.ZmanKey, &z.CanonicalHebrewName, &z.CanonicalEnglishName,
		&z.Transliteration, &z.Description, &z.HalachicNotes, &z.HalachicSource,
		&z.TimeCategory, &z.DefaultFormulaDSL, &z.IsFundamental, &z.SortOrder,
		&z.CreatedAt, &z.UpdatedAt)

	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Master zman not found")
		return
	}
	if err != nil {
		log.Printf("Error getting master zman: %v", err)
		RespondInternalError(w, r, "Failed to get master zman")
		return
	}

	// Get tags for this zman
	tagRows, err := h.db.Pool.Query(ctx, `
		SELECT t.id, t.name, t.display_name_hebrew, t.display_name_english,
			t.tag_type, t.description, t.color, t.sort_order, t.created_at
		FROM zman_tags t
		JOIN master_zman_tags mzt ON t.id = mzt.tag_id
		WHERE mzt.master_zman_id = $1
		ORDER BY t.tag_type, t.sort_order
	`, z.ID)
	if err == nil {
		defer tagRows.Close()
		for tagRows.Next() {
			var tag ZmanTag
			err := tagRows.Scan(&tag.ID, &tag.Name, &tag.DisplayNameHebrew, &tag.DisplayNameEnglish,
				&tag.TagType, &tag.Description, &tag.Color, &tag.SortOrder, &tag.CreatedAt)
			if err == nil {
				z.Tags = append(z.Tags, tag)
			}
		}
	}

	RespondJSON(w, r, http.StatusOK, z)
}

// GetAllTags returns all zman tags
// @Summary Get all zman tags
// @Tags Registry
// @Produce json
// @Param type query string false "Filter by tag type"
// @Success 200 {array} ZmanTag
// @Router /api/v1/registry/tags [get]
func (h *Handlers) GetAllTags(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	tagType := r.URL.Query().Get("type")

	var tags []ZmanTag
	var rows pgx.Rows
	var err error

	if tagType != "" {
		rows, err = h.db.Pool.Query(ctx, `
			SELECT id, name, display_name_hebrew, display_name_english,
				tag_type, description, color, sort_order, created_at
			FROM zman_tags
			WHERE tag_type = $1
			ORDER BY sort_order, name
		`, tagType)
	} else {
		rows, err = h.db.Pool.Query(ctx, `
			SELECT id, name, display_name_hebrew, display_name_english,
				tag_type, description, color, sort_order, created_at
			FROM zman_tags
			ORDER BY tag_type, sort_order, name
		`)
	}

	if err != nil {
		log.Printf("Error getting tags: %v", err)
		RespondInternalError(w, r, "Failed to get tags")
		return
	}
	defer rows.Close()

	for rows.Next() {
		var tag ZmanTag
		err := rows.Scan(&tag.ID, &tag.Name, &tag.DisplayNameHebrew, &tag.DisplayNameEnglish,
			&tag.TagType, &tag.Description, &tag.Color, &tag.SortOrder, &tag.CreatedAt)
		if err != nil {
			log.Printf("Error scanning tag: %v", err)
			continue
		}
		tags = append(tags, tag)
	}

	if tags == nil {
		tags = []ZmanTag{}
	}

	RespondJSON(w, r, http.StatusOK, tags)
}

// GetAllDayTypes returns all day types
// @Summary Get all day types
// @Tags Registry
// @Produce json
// @Param parent query string false "Filter by parent type"
// @Success 200 {array} DayType
// @Router /api/v1/registry/day-types [get]
func (h *Handlers) GetAllDayTypes(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	parentType := r.URL.Query().Get("parent")

	var dayTypes []DayType
	var rows pgx.Rows
	var err error

	if parentType != "" {
		rows, err = h.db.Pool.Query(ctx, `
			SELECT id, name, display_name_hebrew, display_name_english,
				description, parent_type, sort_order
			FROM day_types
			WHERE parent_type = $1
			ORDER BY sort_order, name
		`, parentType)
	} else {
		rows, err = h.db.Pool.Query(ctx, `
			SELECT id, name, display_name_hebrew, display_name_english,
				description, parent_type, sort_order
			FROM day_types
			ORDER BY sort_order, name
		`)
	}

	if err != nil {
		log.Printf("Error getting day types: %v", err)
		RespondInternalError(w, r, "Failed to get day types")
		return
	}
	defer rows.Close()

	for rows.Next() {
		var dt DayType
		err := rows.Scan(&dt.ID, &dt.Name, &dt.DisplayNameHebrew, &dt.DisplayNameEnglish,
			&dt.Description, &dt.ParentType, &dt.SortOrder)
		if err != nil {
			log.Printf("Error scanning day type: %v", err)
			continue
		}
		dayTypes = append(dayTypes, dt)
	}

	if dayTypes == nil {
		dayTypes = []DayType{}
	}

	RespondJSON(w, r, http.StatusOK, dayTypes)
}

// GetZmanApplicableDayTypes returns applicable day types for a specific zman
// @Summary Get applicable day types for a zman
// @Tags Registry
// @Produce json
// @Param zmanKey path string true "Zman key"
// @Success 200 {array} DayType
// @Router /api/v1/registry/zmanim/{zmanKey}/day-types [get]
func (h *Handlers) GetZmanApplicableDayTypes(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	zmanKey := chi.URLParam(r, "zmanKey")

	rows, err := h.db.Pool.Query(ctx, `
		SELECT dt.id, dt.name, dt.display_name_hebrew, dt.display_name_english,
			dt.description, dt.parent_type, dt.sort_order
		FROM day_types dt
		JOIN master_zman_day_types mzdt ON dt.id = mzdt.day_type_id
		JOIN master_zmanim_registry mr ON mr.id = mzdt.master_zman_id
		WHERE mr.zman_key = $1 AND mzdt.is_default = true
		ORDER BY dt.sort_order
	`, zmanKey)
	if err != nil {
		log.Printf("Error getting zman day types: %v", err)
		RespondInternalError(w, r, "Failed to get day types")
		return
	}
	defer rows.Close()

	var dayTypes []DayType
	for rows.Next() {
		var dt DayType
		err := rows.Scan(&dt.ID, &dt.Name, &dt.DisplayNameHebrew, &dt.DisplayNameEnglish,
			&dt.Description, &dt.ParentType, &dt.SortOrder)
		if err != nil {
			log.Printf("Error scanning day type: %v", err)
			continue
		}
		dayTypes = append(dayTypes, dt)
	}

	if dayTypes == nil {
		dayTypes = []DayType{}
	}

	RespondJSON(w, r, http.StatusOK, dayTypes)
}

// ============================================
// VERSION HISTORY HANDLERS (PUBLISHER)
// ============================================

// GetZmanVersionHistory returns the version history for a specific zman
// @Summary Get version history for a zman
// @Tags Publisher Zmanim
// @Produce json
// @Param zmanKey path string true "Zman key"
// @Success 200 {array} ZmanVersion
// @Router /api/v1/publisher/zmanim/{zmanKey}/history [get]
func (h *Handlers) GetZmanVersionHistory(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	zmanKey := chi.URLParam(r, "zmanKey")

	// Resolve publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}
	publisherID := pc.PublisherID

	rows, err := h.db.Pool.Query(ctx, `
		SELECT pzv.id, pzv.publisher_zman_id, pzv.version_number,
			pzv.formula_dsl, pzv.created_by, pzv.created_at
		FROM publisher_zman_versions pzv
		JOIN publisher_zmanim pz ON pz.id = pzv.publisher_zman_id
		WHERE pz.publisher_id = $1 AND pz.zman_key = $2
		ORDER BY pzv.version_number DESC
		LIMIT 7
	`, publisherID, zmanKey)
	if err != nil {
		log.Printf("Error getting zman version history: %v", err)
		RespondInternalError(w, r, "Failed to get version history")
		return
	}
	defer rows.Close()

	var versions []ZmanVersion
	for rows.Next() {
		var v ZmanVersion
		err := rows.Scan(&v.ID, &v.PublisherZmanID, &v.VersionNumber,
			&v.FormulaDSL, &v.CreatedBy, &v.CreatedAt)
		if err != nil {
			log.Printf("Error scanning version: %v", err)
			continue
		}
		versions = append(versions, v)
	}

	if versions == nil {
		versions = []ZmanVersion{}
	}

	RespondJSON(w, r, http.StatusOK, versions)
}

// GetZmanVersion returns a specific version of a zman
// @Summary Get specific version of a zman
// @Tags Publisher Zmanim
// @Produce json
// @Param zmanKey path string true "Zman key"
// @Param version path int true "Version number"
// @Success 200 {object} ZmanVersion
// @Router /api/v1/publisher/zmanim/{zmanKey}/history/{version} [get]
func (h *Handlers) GetZmanVersionDetail(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	zmanKey := chi.URLParam(r, "zmanKey")
	versionStr := chi.URLParam(r, "version")

	version, err := parseIntParam(versionStr)
	if err != nil {
		RespondBadRequest(w, r, "Invalid version number")
		return
	}

	// Resolve publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}
	publisherID := pc.PublisherID

	var v ZmanVersion
	err = h.db.Pool.QueryRow(ctx, `
		SELECT pzv.id, pzv.publisher_zman_id, pzv.version_number,
			pzv.formula_dsl, pzv.created_by, pzv.created_at
		FROM publisher_zman_versions pzv
		JOIN publisher_zmanim pz ON pz.id = pzv.publisher_zman_id
		WHERE pz.publisher_id = $1 AND pz.zman_key = $2 AND pzv.version_number = $3
	`, publisherID, zmanKey, version).Scan(&v.ID, &v.PublisherZmanID, &v.VersionNumber,
		&v.FormulaDSL, &v.CreatedBy, &v.CreatedAt)

	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Version not found")
		return
	}
	if err != nil {
		log.Printf("Error getting zman version: %v", err)
		RespondInternalError(w, r, "Failed to get version")
		return
	}

	RespondJSON(w, r, http.StatusOK, v)
}

// RollbackZmanVersion rolls back a zman to a previous version
// @Summary Rollback zman to previous version
// @Tags Publisher Zmanim
// @Accept json
// @Produce json
// @Param zmanKey path string true "Zman key"
// @Param body body RollbackZmanRequest true "Rollback request"
// @Success 200 {object} PublisherZman
// @Router /api/v1/publisher/zmanim/{zmanKey}/rollback [post]
func (h *Handlers) RollbackZmanVersion(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	zmanKey := chi.URLParam(r, "zmanKey")

	// Resolve publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}
	publisherID := pc.PublisherID

	var req RollbackZmanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Get the target version's formula
	var targetFormula string
	err := h.db.Pool.QueryRow(ctx, `
		SELECT pzv.formula_dsl
		FROM publisher_zman_versions pzv
		JOIN publisher_zmanim pz ON pz.id = pzv.publisher_zman_id
		WHERE pz.publisher_id = $1 AND pz.zman_key = $2 AND pzv.version_number = $3
	`, publisherID, zmanKey, req.VersionNumber).Scan(&targetFormula)

	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Version not found")
		return
	}
	if err != nil {
		log.Printf("Error getting target version: %v", err)
		RespondInternalError(w, r, "Failed to get target version")
		return
	}

	// Get user ID from context
	var userID *string
	if claims, ok := r.Context().Value("claims").(map[string]interface{}); ok {
		if sub, ok := claims["sub"].(string); ok {
			userID = &sub
		}
	}

	// Update the zman with the target formula (this will trigger version creation)
	var result PublisherZman
	err = h.db.Pool.QueryRow(ctx, `
		UPDATE publisher_zmanim
		SET formula_dsl = $3, updated_at = NOW()
		WHERE publisher_id = $1 AND zman_key = $2 AND deleted_at IS NULL
		RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
			formula_dsl, ai_explanation, publisher_comment,
			is_enabled, is_visible, is_published, is_custom, category,
			dependencies, sort_order, created_at, updated_at
	`, publisherID, zmanKey, targetFormula).Scan(
		&result.ID, &result.PublisherID, &result.ZmanKey, &result.HebrewName, &result.EnglishName,
		&result.FormulaDSL, &result.AIExplanation, &result.PublisherComment,
		&result.IsEnabled, &result.IsVisible, &result.IsPublished, &result.IsCustom, &result.Category,
		&result.Dependencies, &result.SortOrder, &result.CreatedAt, &result.UpdatedAt)

	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Zman not found")
		return
	}
	if err != nil {
		log.Printf("Error rolling back zman: %v", err)
		RespondInternalError(w, r, "Failed to rollback zman")
		return
	}

	// Create a new version for the rollback
	_, err = h.db.Pool.Exec(ctx, `
		INSERT INTO publisher_zman_versions (publisher_zman_id, version_number, formula_dsl, created_by)
		SELECT
			pz.id,
			COALESCE((SELECT MAX(version_number) FROM publisher_zman_versions WHERE publisher_zman_id = pz.id), 0) + 1,
			$3,
			$4
		FROM publisher_zmanim pz
		WHERE pz.publisher_id = $1 AND pz.zman_key = $2
	`, publisherID, zmanKey, targetFormula, userID)
	if err != nil {
		log.Printf("Error creating version for rollback: %v", err)
		// Don't fail the request, the rollback itself succeeded
	}

	RespondJSON(w, r, http.StatusOK, result)
}

// ============================================
// SOFT DELETE HANDLERS (PUBLISHER)
// ============================================

// SoftDeletePublisherZman soft deletes a publisher zman
// @Summary Soft delete a zman
// @Tags Publisher Zmanim
// @Param zmanKey path string true "Zman key"
// @Success 200 {object} map[string]string
// @Router /api/v1/publisher/zmanim/{zmanKey} [delete]
func (h *Handlers) SoftDeletePublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	zmanKey := chi.URLParam(r, "zmanKey")

	// Resolve publisher ID
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}
	publisherID := pc.PublisherID

	// Get user ID from context
	var userID *string
	if claims, ok := r.Context().Value("claims").(map[string]interface{}); ok {
		if sub, ok := claims["sub"].(string); ok {
			userID = &sub
		}
	}

	result, err := h.db.Pool.Exec(ctx, `
		UPDATE publisher_zmanim
		SET deleted_at = NOW(), deleted_by = $3, updated_at = NOW()
		WHERE publisher_id = $1 AND zman_key = $2 AND deleted_at IS NULL
	`, publisherID, zmanKey, userID)

	if err != nil {
		log.Printf("Error soft deleting zman: %v", err)
		RespondInternalError(w, r, "Failed to delete zman")
		return
	}

	if result.RowsAffected() == 0 {
		RespondNotFound(w, r, "Zman not found or already deleted")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]string{
		"message": "Zman deleted successfully",
		"zman_key": zmanKey,
	})
}

// GetDeletedZmanim returns soft-deleted zmanim for a publisher
// @Summary Get deleted zmanim
// @Tags Publisher Zmanim
// @Produce json
// @Success 200 {array} DeletedZman
// @Router /api/v1/publisher/zmanim/deleted [get]
func (h *Handlers) GetDeletedZmanim(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Resolve publisher ID
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}
	publisherID := pc.PublisherID

	rows, err := h.db.Pool.Query(ctx, `
		SELECT
			pz.id,
			pz.publisher_id,
			pz.zman_key,
			COALESCE(mr.canonical_hebrew_name, pz.hebrew_name) AS hebrew_name,
			COALESCE(mr.canonical_english_name, pz.english_name) AS english_name,
			pz.formula_dsl,
			COALESCE(mr.time_category, pz.category) AS time_category,
			pz.deleted_at,
			pz.deleted_by,
			pz.master_zman_id
		FROM publisher_zmanim pz
		LEFT JOIN master_zmanim_registry mr ON pz.master_zman_id = mr.id
		WHERE pz.publisher_id = $1 AND pz.deleted_at IS NOT NULL
		ORDER BY pz.deleted_at DESC
	`, publisherID)
	if err != nil {
		log.Printf("Error getting deleted zmanim: %v", err)
		RespondInternalError(w, r, "Failed to get deleted zmanim")
		return
	}
	defer rows.Close()

	var deleted []DeletedZman
	for rows.Next() {
		var d DeletedZman
		err := rows.Scan(&d.ID, &d.PublisherID, &d.ZmanKey, &d.HebrewName, &d.EnglishName,
			&d.FormulaDSL, &d.TimeCategory, &d.DeletedAt, &d.DeletedBy, &d.MasterZmanID)
		if err != nil {
			log.Printf("Error scanning deleted zman: %v", err)
			continue
		}
		deleted = append(deleted, d)
	}

	if deleted == nil {
		deleted = []DeletedZman{}
	}

	RespondJSON(w, r, http.StatusOK, deleted)
}

// RestorePublisherZman restores a soft-deleted zman
// @Summary Restore a deleted zman
// @Tags Publisher Zmanim
// @Param zmanKey path string true "Zman key"
// @Success 200 {object} PublisherZman
// @Router /api/v1/publisher/zmanim/{zmanKey}/restore [post]
func (h *Handlers) RestorePublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	zmanKey := chi.URLParam(r, "zmanKey")

	// Resolve publisher ID
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}
	publisherID := pc.PublisherID

	var result PublisherZman
	err := h.db.Pool.QueryRow(ctx, `
		UPDATE publisher_zmanim
		SET deleted_at = NULL, deleted_by = NULL, updated_at = NOW()
		WHERE publisher_id = $1 AND zman_key = $2 AND deleted_at IS NOT NULL
		RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
			formula_dsl, ai_explanation, publisher_comment,
			is_enabled, is_visible, is_published, is_custom, category,
			dependencies, sort_order, created_at, updated_at
	`, publisherID, zmanKey).Scan(
		&result.ID, &result.PublisherID, &result.ZmanKey, &result.HebrewName, &result.EnglishName,
		&result.FormulaDSL, &result.AIExplanation, &result.PublisherComment,
		&result.IsEnabled, &result.IsVisible, &result.IsPublished, &result.IsCustom, &result.Category,
		&result.Dependencies, &result.SortOrder, &result.CreatedAt, &result.UpdatedAt)

	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Deleted zman not found")
		return
	}
	if err != nil {
		log.Printf("Error restoring zman: %v", err)
		RespondInternalError(w, r, "Failed to restore zman")
		return
	}

	RespondJSON(w, r, http.StatusOK, result)
}

// PermanentDeletePublisherZman permanently deletes a soft-deleted zman
// @Summary Permanently delete a zman
// @Tags Publisher Zmanim
// @Param zmanKey path string true "Zman key"
// @Success 200 {object} map[string]string
// @Router /api/v1/publisher/zmanim/{zmanKey}/permanent [delete]
func (h *Handlers) PermanentDeletePublisherZman(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	zmanKey := chi.URLParam(r, "zmanKey")

	// Resolve publisher ID
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}
	publisherID := pc.PublisherID

	result, err := h.db.Pool.Exec(ctx, `
		DELETE FROM publisher_zmanim
		WHERE publisher_id = $1 AND zman_key = $2 AND deleted_at IS NOT NULL
	`, publisherID, zmanKey)

	if err != nil {
		log.Printf("Error permanently deleting zman: %v", err)
		RespondInternalError(w, r, "Failed to permanently delete zman")
		return
	}

	if result.RowsAffected() == 0 {
		RespondNotFound(w, r, "Deleted zman not found")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]string{
		"message": "Zman permanently deleted",
		"zman_key": zmanKey,
	})
}

// ============================================
// CREATE FROM REGISTRY HANDLER
// ============================================

// CreatePublisherZmanFromRegistry creates a new zman from the master registry
// @Summary Add zman from master registry
// @Tags Publisher Zmanim
// @Accept json
// @Produce json
// @Param body body CreateZmanFromRegistryRequest true "Create request"
// @Success 201 {object} PublisherZman
// @Router /api/v1/publisher/zmanim [post]
func (h *Handlers) CreatePublisherZmanFromRegistry(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Resolve publisher ID
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}
	publisherID := pc.PublisherID

	var req CreateZmanFromRegistryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Parse master_zman_id
	masterZmanID, err := uuid.Parse(req.MasterZmanID)
	if err != nil {
		RespondBadRequest(w, r, "Invalid master_zman_id")
		return
	}

	// Create the zman from the registry
	var result PublisherZman
	var formulaToUse string

	// Get the default formula or use override
	if req.FormulaDSL != nil && *req.FormulaDSL != "" {
		formulaToUse = *req.FormulaDSL
	} else {
		err = h.db.Pool.QueryRow(ctx, `
			SELECT default_formula_dsl FROM master_zmanim_registry WHERE id = $1
		`, masterZmanID).Scan(&formulaToUse)
		if err == pgx.ErrNoRows {
			RespondNotFound(w, r, "Master zman not found")
			return
		}
		if err != nil {
			log.Printf("Error getting master zman: %v", err)
			RespondInternalError(w, r, "Failed to get master zman")
			return
		}
	}

	// Insert the new publisher zman
	err = h.db.Pool.QueryRow(ctx, `
		INSERT INTO publisher_zmanim (
			id, publisher_id, zman_key, hebrew_name, english_name,
			formula_dsl, ai_explanation, publisher_comment,
			is_enabled, is_visible, is_published, is_custom, category,
			dependencies, sort_order, master_zman_id, current_version
		)
		SELECT
			gen_random_uuid(),
			$1,
			mr.zman_key,
			mr.canonical_hebrew_name,
			mr.canonical_english_name,
			$3,
			NULL,
			NULL,
			true,
			true,
			false,
			false,
			mr.time_category,
			'{}',
			mr.sort_order,
			mr.id,
			1
		FROM master_zmanim_registry mr
		WHERE mr.id = $2
		RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
			formula_dsl, ai_explanation, publisher_comment,
			is_enabled, is_visible, is_published, is_custom, category,
			dependencies, sort_order, created_at, updated_at
	`, publisherID, masterZmanID, formulaToUse).Scan(
		&result.ID, &result.PublisherID, &result.ZmanKey, &result.HebrewName, &result.EnglishName,
		&result.FormulaDSL, &result.AIExplanation, &result.PublisherComment,
		&result.IsEnabled, &result.IsVisible, &result.IsPublished, &result.IsCustom, &result.Category,
		&result.Dependencies, &result.SortOrder, &result.CreatedAt, &result.UpdatedAt)

	if err != nil {
		// Check for unique constraint violation
		if isDuplicateKeyError(err) {
			RespondConflict(w, r, "Zman already exists for this publisher")
			return
		}
		log.Printf("Error creating publisher zman: %v", err)
		RespondInternalError(w, r, "Failed to create zman")
		return
	}

	// Create initial version
	_, err = h.db.Pool.Exec(ctx, `
		INSERT INTO publisher_zman_versions (publisher_zman_id, version_number, formula_dsl)
		VALUES ($1, 1, $2)
	`, result.ID, result.FormulaDSL)
	if err != nil {
		log.Printf("Error creating initial version: %v", err)
		// Don't fail - the zman was created successfully
	}

	RespondJSON(w, r, http.StatusCreated, result)
}

// ============================================
// ZMAN REGISTRY REQUEST HANDLERS (EDGE CASE)
// ============================================

// CreateZmanRegistryRequest creates a request to add a new zman to the registry
// @Summary Request new zman for master registry
// @Tags Publisher Zmanim
// @Accept json
// @Produce json
// @Param body body CreateZmanRegistryRequestBody true "Request body"
// @Success 201 {object} ZmanRegistryRequest
// @Router /api/v1/registry/zmanim/request [post]
func (h *Handlers) CreateZmanRegistryRequest(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Resolve publisher ID
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return
	}
	publisherID := pc.PublisherID

	var req CreateZmanRegistryRequestBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate required fields
	if req.RequestedKey == "" || req.RequestedHebrewName == "" || req.RequestedEnglishName == "" ||
		req.TimeCategory == "" || req.Justification == "" {
		RespondBadRequest(w, r, "Missing required fields")
		return
	}

	var result ZmanRegistryRequest
	err := h.db.Pool.QueryRow(ctx, `
		INSERT INTO zman_registry_requests (
			publisher_id, requested_key, requested_hebrew_name, requested_english_name,
			requested_formula_dsl, time_category, justification
		) VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, publisher_id, requested_key, requested_hebrew_name, requested_english_name,
			requested_formula_dsl, time_category, justification, status, created_at
	`, publisherID, req.RequestedKey, req.RequestedHebrewName, req.RequestedEnglishName,
		req.RequestedFormulaDSL, req.TimeCategory, req.Justification).Scan(
		&result.ID, &result.PublisherID, &result.RequestedKey, &result.RequestedHebrewName,
		&result.RequestedEnglishName, &result.RequestedFormulaDSL, &result.TimeCategory,
		&result.Justification, &result.Status, &result.CreatedAt)

	if err != nil {
		log.Printf("Error creating zman registry request: %v", err)
		RespondInternalError(w, r, "Failed to create request")
		return
	}

	RespondJSON(w, r, http.StatusCreated, result)
}

// AdminGetZmanRegistryRequests returns all zman registry requests (admin only)
// @Summary Get all zman registry requests
// @Tags Admin
// @Produce json
// @Param status query string false "Filter by status"
// @Success 200 {array} ZmanRegistryRequest
// @Router /api/v1/admin/registry/requests [get]
func (h *Handlers) AdminGetZmanRegistryRequests(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	status := r.URL.Query().Get("status")

	var rows pgx.Rows
	var err error

	if status != "" {
		rows, err = h.db.Pool.Query(ctx, `
			SELECT id, publisher_id, requested_key, requested_hebrew_name, requested_english_name,
				requested_formula_dsl, time_category, justification, status,
				reviewed_by, reviewed_at, reviewer_notes, created_at
			FROM zman_registry_requests
			WHERE status = $1
			ORDER BY created_at DESC
		`, status)
	} else {
		rows, err = h.db.Pool.Query(ctx, `
			SELECT id, publisher_id, requested_key, requested_hebrew_name, requested_english_name,
				requested_formula_dsl, time_category, justification, status,
				reviewed_by, reviewed_at, reviewer_notes, created_at
			FROM zman_registry_requests
			ORDER BY created_at DESC
		`)
	}

	if err != nil {
		log.Printf("Error getting zman registry requests: %v", err)
		RespondInternalError(w, r, "Failed to get requests")
		return
	}
	defer rows.Close()

	var requests []ZmanRegistryRequest
	for rows.Next() {
		var req ZmanRegistryRequest
		err := rows.Scan(&req.ID, &req.PublisherID, &req.RequestedKey, &req.RequestedHebrewName,
			&req.RequestedEnglishName, &req.RequestedFormulaDSL, &req.TimeCategory, &req.Justification,
			&req.Status, &req.ReviewedBy, &req.ReviewedAt, &req.ReviewerNotes, &req.CreatedAt)
		if err != nil {
			log.Printf("Error scanning request: %v", err)
			continue
		}
		requests = append(requests, req)
	}

	if requests == nil {
		requests = []ZmanRegistryRequest{}
	}

	RespondJSON(w, r, http.StatusOK, requests)
}

// AdminReviewZmanRegistryRequest approves or rejects a zman registry request
// @Summary Review zman registry request
// @Tags Admin
// @Accept json
// @Produce json
// @Param id path string true "Request ID"
// @Param body body ReviewZmanRequestBody true "Review body"
// @Success 200 {object} ZmanRegistryRequest
// @Router /api/v1/admin/registry/requests/{id} [put]
func (h *Handlers) AdminReviewZmanRegistryRequest(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	requestID := chi.URLParam(r, "id")

	// Get reviewer ID from context
	var reviewerID *string
	if claims, ok := r.Context().Value("claims").(map[string]interface{}); ok {
		if sub, ok := claims["sub"].(string); ok {
			reviewerID = &sub
		}
	}

	var req ReviewZmanRequestBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	if req.Status != "approved" && req.Status != "rejected" {
		RespondBadRequest(w, r, "Status must be 'approved' or 'rejected'")
		return
	}

	// Start transaction
	tx, err := h.db.Pool.Begin(ctx)
	if err != nil {
		log.Printf("Error starting transaction: %v", err)
		RespondInternalError(w, r, "Failed to process request")
		return
	}
	defer tx.Rollback(ctx)

	// Update request status
	var result ZmanRegistryRequest
	err = tx.QueryRow(ctx, `
		UPDATE zman_registry_requests
		SET status = $2, reviewed_by = $3, reviewed_at = NOW(), reviewer_notes = $4
		WHERE id = $1
		RETURNING id, publisher_id, requested_key, requested_hebrew_name, requested_english_name,
			requested_formula_dsl, time_category, justification, status,
			reviewed_by, reviewed_at, reviewer_notes, created_at
	`, requestID, req.Status, reviewerID, req.ReviewerNotes).Scan(
		&result.ID, &result.PublisherID, &result.RequestedKey, &result.RequestedHebrewName,
		&result.RequestedEnglishName, &result.RequestedFormulaDSL, &result.TimeCategory,
		&result.Justification, &result.Status, &result.ReviewedBy, &result.ReviewedAt,
		&result.ReviewerNotes, &result.CreatedAt)

	if err == pgx.ErrNoRows {
		RespondNotFound(w, r, "Request not found")
		return
	}
	if err != nil {
		log.Printf("Error updating request: %v", err)
		RespondInternalError(w, r, "Failed to update request")
		return
	}

	// If approved, add to master registry
	if req.Status == "approved" {
		_, err = tx.Exec(ctx, `
			INSERT INTO master_zmanim_registry (
				zman_key, canonical_hebrew_name, canonical_english_name,
				time_category, default_formula_dsl, is_fundamental, sort_order, description
			) VALUES ($1, $2, $3, $4, COALESCE($5, 'sunrise'), false, 999, 'Added from publisher request')
		`, result.RequestedKey, result.RequestedHebrewName, result.RequestedEnglishName,
			result.TimeCategory, result.RequestedFormulaDSL)

		if err != nil {
			log.Printf("Error adding to master registry: %v", err)
			RespondInternalError(w, r, "Failed to add to registry")
			return
		}
	}

	if err := tx.Commit(ctx); err != nil {
		log.Printf("Error committing transaction: %v", err)
		RespondInternalError(w, r, "Failed to process request")
		return
	}

	RespondJSON(w, r, http.StatusOK, result)
}

// Helper function to check for duplicate key errors
func isDuplicateKeyError(err error) bool {
	return err != nil && (
		// pgx error codes for unique violation
		err.Error() == "duplicate key value violates unique constraint" ||
		// Check for common PostgreSQL error patterns
		len(err.Error()) > 0 && (
			err.Error()[0:23] == "ERROR: duplicate key" ||
			err.Error() == "23505" ||
			// Match partial error messages
			containsString(err.Error(), "duplicate key") ||
			containsString(err.Error(), "unique constraint")))
}

func containsString(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > len(substr) && (s[:len(substr)] == substr || s[len(s)-len(substr):] == substr || findSubstring(s, substr)))
}

func findSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
