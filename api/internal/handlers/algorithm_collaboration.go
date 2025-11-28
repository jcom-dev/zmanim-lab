package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jcom-dev/zmanim-lab/internal/middleware"
)

// PublicAlgorithm represents a public algorithm for browsing
type PublicAlgorithm struct {
	ID            string        `json:"id"`
	Name          string        `json:"name"`
	Description   string        `json:"description"`
	PublisherID   string        `json:"publisher_id"`
	PublisherName string        `json:"publisher_name"`
	PublisherLogo string        `json:"publisher_logo,omitempty"`
	Template      string        `json:"template,omitempty"`
	ZmanimPreview []ZmanPreview `json:"zmanim_preview"`
	ForkCount     int           `json:"fork_count"`
	CreatedAt     string        `json:"created_at"`
}

// ZmanPreview represents a preview of a zman in a public algorithm
type ZmanPreview struct {
	Key        string `json:"key"`
	Name       string `json:"name"`
	NameHebrew string `json:"name_hebrew,omitempty"`
	SampleTime string `json:"sample_time"`
}

// BrowsePublicAlgorithms returns a list of public algorithms
// GET /api/algorithms/public
func (h *Handlers) BrowsePublicAlgorithms(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Parse query params
	search := r.URL.Query().Get("search")
	template := r.URL.Query().Get("template")
	page := 1
	pageSize := 20

	if p := r.URL.Query().Get("page"); p != "" {
		if parsed, err := parseIntParam(p); err == nil && parsed > 0 {
			page = parsed
		}
	}
	if ps := r.URL.Query().Get("page_size"); ps != "" {
		if parsed, err := parseIntParam(ps); err == nil && parsed > 0 && parsed <= 50 {
			pageSize = parsed
		}
	}

	offset := (page - 1) * pageSize

	// Build query - use algorithms table
	query := `
		SELECT
			a.id, a.name, COALESCE(a.description, '') as description,
			a.publisher_id, p.name as publisher_name,
			COALESCE(p.logo_url, '') as publisher_logo,
			COALESCE(a.fork_count, 0) as fork_count,
			a.created_at
		FROM algorithms a
		JOIN publishers p ON p.id = a.publisher_id
		WHERE a.is_public = true AND a.is_active = true
	`
	args := []interface{}{}
	argCount := 1

	if search != "" {
		query += ` AND (a.name ILIKE $` + string('0'+byte(argCount)) + ` OR p.name ILIKE $` + string('0'+byte(argCount)) + `)`
		args = append(args, "%"+search+"%")
		argCount++
	}

	query += ` ORDER BY a.fork_count DESC, a.created_at DESC`
	query += ` LIMIT $` + string('0'+byte(argCount)) + ` OFFSET $` + string('0'+byte(argCount+1))
	args = append(args, pageSize, offset)

	rows, err := h.db.Pool.Query(ctx, query, args...)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch algorithms")
		return
	}
	defer rows.Close()

	var algorithms []PublicAlgorithm
	for rows.Next() {
		var alg PublicAlgorithm
		var createdAt time.Time

		err := rows.Scan(
			&alg.ID, &alg.Name, &alg.Description,
			&alg.PublisherID, &alg.PublisherName, &alg.PublisherLogo,
			&alg.ForkCount, &createdAt,
		)
		if err != nil {
			continue
		}
		alg.CreatedAt = createdAt.Format(time.RFC3339)
		alg.Template = template
		alg.ZmanimPreview = []ZmanPreview{} // Would populate from configuration
		algorithms = append(algorithms, alg)
	}

	if algorithms == nil {
		algorithms = []PublicAlgorithm{}
	}

	// Get total count
	var total int
	h.db.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM algorithms
		WHERE is_public = true AND is_active = true
	`).Scan(&total)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"algorithms": algorithms,
		"total":      total,
		"page":       page,
		"page_size":  pageSize,
	})
}

// GetPublicAlgorithm returns details of a public algorithm
// GET /api/algorithms/{id}/public
func (h *Handlers) GetPublicAlgorithm(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	algorithmID := chi.URLParam(r, "id")

	var alg PublicAlgorithm
	var createdAt time.Time
	var configData []byte

	err := h.db.Pool.QueryRow(ctx, `
		SELECT
			a.id, a.name, COALESCE(a.description, '') as description,
			a.publisher_id, p.name as publisher_name,
			COALESCE(p.logo_url, '') as publisher_logo,
			COALESCE(a.fork_count, 0) as fork_count,
			a.created_at, COALESCE(a.configuration::text, '{}')::bytea
		FROM algorithms a
		JOIN publishers p ON p.id = a.publisher_id
		WHERE a.id = $1 AND a.is_public = true AND a.is_active = true
	`, algorithmID).Scan(
		&alg.ID, &alg.Name, &alg.Description,
		&alg.PublisherID, &alg.PublisherName, &alg.PublisherLogo,
		&alg.ForkCount, &createdAt, &configData,
	)

	if err != nil {
		RespondNotFound(w, r, "Algorithm not found or not public")
		return
	}

	alg.CreatedAt = createdAt.Format(time.RFC3339)

	// Parse configuration for zmanim preview
	if configData != nil {
		var data map[string]interface{}
		if err := json.Unmarshal(configData, &data); err == nil {
			if zmanim, ok := data["zmanim"].([]interface{}); ok {
				for _, z := range zmanim {
					if zm, ok := z.(map[string]interface{}); ok {
						preview := ZmanPreview{
							Key:  getString(zm, "key"),
							Name: getString(zm, "nameEnglish"),
						}
						alg.ZmanimPreview = append(alg.ZmanimPreview, preview)
					}
				}
			}
		}
	}

	RespondJSON(w, r, http.StatusOK, alg)
}

// CopyAlgorithm copies a public algorithm to the user's account
// POST /api/algorithms/{id}/copy
func (h *Handlers) CopyAlgorithm(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	sourceAlgorithmID := chi.URLParam(r, "id")

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

	// Get the source algorithm (must be public)
	var name, description string
	var configData []byte
	err := h.db.Pool.QueryRow(ctx, `
		SELECT name, COALESCE(description, ''), COALESCE(configuration::text, '{}')::bytea
		FROM algorithms
		WHERE id = $1 AND is_public = true AND is_active = true
	`, sourceAlgorithmID).Scan(&name, &description, &configData)

	if err != nil {
		RespondNotFound(w, r, "Algorithm not found or not public")
		return
	}

	// Create the copy
	var newAlgorithmID string
	err = h.db.Pool.QueryRow(ctx, `
		INSERT INTO algorithms (
			publisher_id, name, description, configuration, version,
			formula_definition, calculation_type,
			is_active, is_public, created_at, updated_at
		) VALUES (
			$1, $2 || ' (Copy)', $3, $4, '1.0',
			'{}', 'custom',
			false, false, NOW(), NOW()
		)
		RETURNING id
	`, publisherID, name, description, configData).Scan(&newAlgorithmID)

	if err != nil {
		RespondInternalError(w, r, "Failed to copy algorithm")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"new_algorithm_id": newAlgorithmID,
		"message":          "Algorithm copied successfully",
	})
}

// ForkAlgorithm forks a public algorithm with attribution
// POST /api/algorithms/{id}/fork
func (h *Handlers) ForkAlgorithm(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	sourceAlgorithmID := chi.URLParam(r, "id")

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

	// Get the source algorithm and publisher name
	var name, description, sourcePublisherName string
	var configData []byte
	err := h.db.Pool.QueryRow(ctx, `
		SELECT a.name, COALESCE(a.description, ''), COALESCE(a.configuration::text, '{}')::bytea, p.name
		FROM algorithms a
		JOIN publishers p ON p.id = a.publisher_id
		WHERE a.id = $1 AND a.is_public = true AND a.is_active = true
	`, sourceAlgorithmID).Scan(&name, &description, &configData, &sourcePublisherName)

	if err != nil {
		RespondNotFound(w, r, "Algorithm not found or not public")
		return
	}

	// Create attribution text
	attribution := "Based on " + sourcePublisherName + "'s algorithm"

	// Create the fork
	var newAlgorithmID string
	err = h.db.Pool.QueryRow(ctx, `
		INSERT INTO algorithms (
			publisher_id, name, description, configuration, version,
			formula_definition, calculation_type,
			is_active, is_public, forked_from, attribution_text,
			created_at, updated_at
		) VALUES (
			$1, $2 || ' (Fork)', $3, $4, '1.0',
			'{}', 'custom',
			false, false, $5, $6, NOW(), NOW()
		)
		RETURNING id
	`, publisherID, name, description, configData, sourceAlgorithmID, attribution).Scan(&newAlgorithmID)

	if err != nil {
		RespondInternalError(w, r, "Failed to fork algorithm")
		return
	}

	// Increment fork count on source
	_, _ = h.db.Pool.Exec(ctx, `
		UPDATE algorithms
		SET fork_count = COALESCE(fork_count, 0) + 1
		WHERE id = $1
	`, sourceAlgorithmID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"new_algorithm_id": newAlgorithmID,
		"attribution":      attribution,
		"message":          "Algorithm forked successfully",
	})
}

// SetAlgorithmVisibility toggles algorithm public/private
// PUT /api/publisher/algorithm/visibility
func (h *Handlers) SetAlgorithmVisibility(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	var req struct {
		IsPublic bool `json:"is_public"`
	}
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

	// Update visibility
	_, err := h.db.Pool.Exec(ctx, `
		UPDATE algorithms
		SET is_public = $1, updated_at = NOW()
		WHERE publisher_id = $2
	`, req.IsPublic, publisherID)

	if err != nil {
		RespondInternalError(w, r, "Failed to update visibility")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"is_public": req.IsPublic,
	})
}

// GetMyForks returns the user's forked algorithms
// GET /api/publisher/algorithm/forks
func (h *Handlers) GetMyForks(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

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

	rows, err := h.db.Pool.Query(ctx, `
		SELECT
			a.id, a.name, a.attribution_text,
			source.id as source_id, source.name as source_name,
			p.name as source_publisher
		FROM algorithms a
		JOIN algorithms source ON source.id = a.forked_from
		JOIN publishers p ON p.id = source.publisher_id
		WHERE a.publisher_id = $1 AND a.forked_from IS NOT NULL
		ORDER BY a.created_at DESC
	`, publisherID)

	if err != nil {
		RespondInternalError(w, r, "Failed to fetch forks")
		return
	}
	defer rows.Close()

	type Fork struct {
		ID              string `json:"id"`
		Name            string `json:"name"`
		Attribution     string `json:"attribution"`
		SourceID        string `json:"source_id"`
		SourceName      string `json:"source_name"`
		SourcePublisher string `json:"source_publisher"`
	}

	var forks []Fork
	for rows.Next() {
		var fork Fork
		err := rows.Scan(
			&fork.ID, &fork.Name, &fork.Attribution,
			&fork.SourceID, &fork.SourceName, &fork.SourcePublisher,
		)
		if err != nil {
			continue
		}
		forks = append(forks, fork)
	}

	if forks == nil {
		forks = []Fork{}
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"forks": forks,
	})
}

// helper to get string from map
func getString(m map[string]interface{}, key string) string {
	if v, ok := m[key].(string); ok {
		return v
	}
	return ""
}
