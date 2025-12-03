package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jcom-dev/zmanim-lab/internal/diff"
	"github.com/jcom-dev/zmanim-lab/internal/middleware"
)

// VersionHistoryEntry represents a version in the history list
type VersionHistoryEntry struct {
	ID            string     `json:"id"`
	VersionNumber int        `json:"version_number"`
	Status        string     `json:"status"`
	Description   string     `json:"description,omitempty"`
	CreatedBy     string     `json:"created_by,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	IsCurrent     bool       `json:"is_current"`
	PublishedAt   *time.Time `json:"published_at,omitempty"`
}

// VersionDetail represents full version details including config snapshot
type VersionDetail struct {
	ID            string          `json:"id"`
	VersionNumber int             `json:"version_number"`
	Status        string          `json:"status"`
	Description   string          `json:"description,omitempty"`
	Config        json.RawMessage `json:"config"`
	CreatedBy     string          `json:"created_by,omitempty"`
	CreatedAt     time.Time       `json:"created_at"`
}

// DiffResponse represents the response for version diff
type DiffResponse struct {
	V1   int                 `json:"v1"`
	V2   int                 `json:"v2"`
	Diff *diff.AlgorithmDiff `json:"diff"`
}

// RollbackRequest represents a request to rollback to a previous version
type RollbackRequest struct {
	TargetVersion int    `json:"target_version"`
	Status        string `json:"status"` // draft or published
	Description   string `json:"description,omitempty"`
}

// GetVersionHistory returns the version history for an algorithm
// GET /api/v1/publisher/algorithm/history
func (h *Handlers) GetVersionHistory(w http.ResponseWriter, r *http.Request) {
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

	// Get algorithm ID
	var algorithmID string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT id FROM algorithms WHERE publisher_id = $1 ORDER BY updated_at DESC LIMIT 1",
		publisherID,
	).Scan(&algorithmID)
	if err != nil {
		RespondNotFound(w, r, "Algorithm not found")
		return
	}

	// Get current version number
	var currentVersion int
	_ = h.db.Pool.QueryRow(ctx,
		"SELECT COALESCE(MAX(version_number), 0) FROM algorithm_version_history WHERE algorithm_id = $1",
		algorithmID,
	).Scan(&currentVersion)

	// Fetch version history
	rows, err := h.db.Pool.Query(ctx, `
		SELECT id, version_number, status, COALESCE(description, ''),
		       COALESCE(created_by, ''), created_at
		FROM algorithm_version_history
		WHERE algorithm_id = $1
		ORDER BY version_number DESC
	`, algorithmID)
	if err != nil {
		RespondInternalError(w, r, "Failed to fetch version history")
		return
	}
	defer rows.Close()

	versions := []VersionHistoryEntry{}
	for rows.Next() {
		var v VersionHistoryEntry
		err := rows.Scan(&v.ID, &v.VersionNumber, &v.Status, &v.Description, &v.CreatedBy, &v.CreatedAt)
		if err != nil {
			continue
		}
		v.IsCurrent = v.VersionNumber == currentVersion
		versions = append(versions, v)
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"versions":        versions,
		"current_version": currentVersion,
		"total":           len(versions),
	})
}

// GetVersionDetail returns the full details of a specific version
// GET /api/v1/publisher/algorithm/history/{version}
func (h *Handlers) GetVersionDetail(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	versionNum := chi.URLParam(r, "version")
	version, err := strconv.Atoi(versionNum)
	if err != nil {
		RespondBadRequest(w, r, "Invalid version number")
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

	// Get algorithm ID
	var algorithmID string
	err = h.db.Pool.QueryRow(ctx,
		"SELECT id FROM algorithms WHERE publisher_id = $1 ORDER BY updated_at DESC LIMIT 1",
		publisherID,
	).Scan(&algorithmID)
	if err != nil {
		RespondNotFound(w, r, "Algorithm not found")
		return
	}

	// Fetch version detail
	var detail VersionDetail
	var configSnapshot []byte
	err = h.db.Pool.QueryRow(ctx, `
		SELECT id, version_number, status, COALESCE(description, ''),
		       config_snapshot, COALESCE(created_by, ''), created_at
		FROM algorithm_version_history
		WHERE algorithm_id = $1 AND version_number = $2
	`, algorithmID, version).Scan(
		&detail.ID, &detail.VersionNumber, &detail.Status,
		&detail.Description, &configSnapshot, &detail.CreatedBy, &detail.CreatedAt,
	)
	if err != nil {
		RespondNotFound(w, r, "Version not found")
		return
	}

	detail.Config = configSnapshot
	RespondJSON(w, r, http.StatusOK, detail)
}

// GetVersionDiff compares two versions and returns the diff
// GET /api/v1/publisher/algorithm/diff?v1=X&v2=Y
func (h *Handlers) GetVersionDiff(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	v1Str := r.URL.Query().Get("v1")
	v2Str := r.URL.Query().Get("v2")

	v1, err := strconv.Atoi(v1Str)
	if err != nil {
		RespondBadRequest(w, r, "Invalid v1 parameter")
		return
	}
	v2, err := strconv.Atoi(v2Str)
	if err != nil {
		RespondBadRequest(w, r, "Invalid v2 parameter")
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

	// Get algorithm ID
	var algorithmID string
	err = h.db.Pool.QueryRow(ctx,
		"SELECT id FROM algorithms WHERE publisher_id = $1 ORDER BY updated_at DESC LIMIT 1",
		publisherID,
	).Scan(&algorithmID)
	if err != nil {
		RespondNotFound(w, r, "Algorithm not found")
		return
	}

	// Get both version configs
	var v1Config, v2Config []byte
	err = h.db.Pool.QueryRow(ctx,
		"SELECT config_snapshot FROM algorithm_version_history WHERE algorithm_id = $1 AND version_number = $2",
		algorithmID, v1,
	).Scan(&v1Config)
	if err != nil {
		RespondNotFound(w, r, "Version v1 not found")
		return
	}

	err = h.db.Pool.QueryRow(ctx,
		"SELECT config_snapshot FROM algorithm_version_history WHERE algorithm_id = $1 AND version_number = $2",
		algorithmID, v2,
	).Scan(&v2Config)
	if err != nil {
		RespondNotFound(w, r, "Version v2 not found")
		return
	}

	// Compute diff
	algorithmDiff, err := diff.CompareAlgorithms(v1Config, v2Config)
	if err != nil {
		RespondInternalError(w, r, "Failed to compute diff")
		return
	}

	RespondJSON(w, r, http.StatusOK, DiffResponse{
		V1:   v1,
		V2:   v2,
		Diff: algorithmDiff,
	})
}

// RollbackVersion rolls back to a previous version
// POST /api/v1/publisher/algorithm/rollback
func (h *Handlers) RollbackVersion(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	var req RollbackRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	if req.TargetVersion <= 0 {
		RespondBadRequest(w, r, "Target version must be positive")
		return
	}

	if req.Status == "" {
		req.Status = "draft"
	}
	if req.Status != "draft" && req.Status != "published" {
		RespondBadRequest(w, r, "Status must be 'draft' or 'published'")
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

	// Get algorithm ID
	var algorithmID string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT id FROM algorithms WHERE publisher_id = $1 ORDER BY updated_at DESC LIMIT 1",
		publisherID,
	).Scan(&algorithmID)
	if err != nil {
		RespondNotFound(w, r, "Algorithm not found")
		return
	}

	// Get current version number
	var currentVersion int
	err = h.db.Pool.QueryRow(ctx,
		"SELECT COALESCE(MAX(version_number), 0) FROM algorithm_version_history WHERE algorithm_id = $1",
		algorithmID,
	).Scan(&currentVersion)
	if err != nil {
		RespondInternalError(w, r, "Failed to get current version")
		return
	}

	// Get target version config
	var configSnapshot []byte
	err = h.db.Pool.QueryRow(ctx,
		"SELECT config_snapshot FROM algorithm_version_history WHERE algorithm_id = $1 AND version_number = $2",
		algorithmID, req.TargetVersion,
	).Scan(&configSnapshot)
	if err != nil {
		RespondNotFound(w, r, "Target version not found")
		return
	}

	// Create new version with rolled-back config
	newVersion := currentVersion + 1
	description := req.Description
	if description == "" {
		description = "Rolled back from v" + strconv.Itoa(req.TargetVersion)
	}

	var newVersionID string
	err = h.db.Pool.QueryRow(ctx, `
		INSERT INTO algorithm_version_history (
			algorithm_id, version_number, status, config_snapshot, description, created_by
		) VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`, algorithmID, newVersion, req.Status, configSnapshot, description, userID).Scan(&newVersionID)
	if err != nil {
		RespondInternalError(w, r, "Failed to create new version")
		return
	}

	// Update main algorithm with rolled-back config
	_, err = h.db.Pool.Exec(ctx, `
		UPDATE algorithms
		SET configuration = $1, updated_at = NOW()
		WHERE id = $2
	`, configSnapshot, algorithmID)
	if err != nil {
		RespondInternalError(w, r, "Failed to update algorithm")
		return
	}

	// Log the rollback
	_, _ = h.db.Pool.Exec(ctx, `
		INSERT INTO algorithm_rollback_audit (
			algorithm_id, source_version, target_version, new_version, reason, rolled_back_by
		) VALUES ($1, $2, $3, $4, $5, $6)
	`, algorithmID, currentVersion, req.TargetVersion, newVersion, description, userID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"new_version":    newVersion,
		"new_version_id": newVersionID,
		"message":        "Successfully rolled back to version " + strconv.Itoa(req.TargetVersion),
	})
}

// CreateVersionSnapshot creates a version snapshot (called on save)
// POST /api/v1/publisher/algorithm/snapshot
func (h *Handlers) CreateVersionSnapshot(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User not authenticated")
		return
	}

	var req struct {
		Config      json.RawMessage `json:"config"`
		Status      string          `json:"status"`
		Description string          `json:"description,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	if req.Status == "" {
		req.Status = "draft"
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

	// Get algorithm ID
	var algorithmID string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT id FROM algorithms WHERE publisher_id = $1 ORDER BY updated_at DESC LIMIT 1",
		publisherID,
	).Scan(&algorithmID)
	if err != nil {
		RespondNotFound(w, r, "Algorithm not found")
		return
	}

	// Get next version number
	var nextVersion int
	err = h.db.Pool.QueryRow(ctx,
		"SELECT get_next_algorithm_version($1)",
		algorithmID,
	).Scan(&nextVersion)
	if err != nil {
		RespondInternalError(w, r, "Failed to get next version number")
		return
	}

	// Create version snapshot
	var versionID string
	err = h.db.Pool.QueryRow(ctx, `
		INSERT INTO algorithm_version_history (
			algorithm_id, version_number, status, config_snapshot, description, created_by
		) VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`, algorithmID, nextVersion, req.Status, req.Config, req.Description, userID).Scan(&versionID)
	if err != nil {
		RespondInternalError(w, r, "Failed to create version snapshot")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"version_id":     versionID,
		"version_number": nextVersion,
		"status":         req.Status,
	})
}
