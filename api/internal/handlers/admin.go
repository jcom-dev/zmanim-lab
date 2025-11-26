package handlers

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

// AdminListPublishers returns a list of all publishers with status
// GET /api/admin/publishers
func (h *Handlers) AdminListPublishers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	query := `
		SELECT id, clerk_user_id, name, organization, email, website,
		       logo_url, bio, status, created_at, updated_at
		FROM publishers
		ORDER BY created_at DESC
	`

	rows, err := h.db.Pool.Query(ctx, query)
	if err != nil {
		slog.Error("failed to query publishers", "error", err)
		RespondInternalError(w, r, "Failed to retrieve publishers")
		return
	}
	defer rows.Close()

	publishers := make([]map[string]interface{}, 0)
	for rows.Next() {
		var id, name, organization, email, status string
		var clerkUserID, website, logoURL, bio *string
		var createdAt, updatedAt time.Time

		err := rows.Scan(&id, &clerkUserID, &name, &organization, &email,
			&website, &logoURL, &bio, &status, &createdAt, &updatedAt)
		if err != nil {
			slog.Error("failed to scan publisher row", "error", err)
			continue
		}

		publisher := map[string]interface{}{
			"id":           id,
			"name":         name,
			"organization": organization,
			"email":        email,
			"status":       status,
			"created_at":   createdAt,
			"updated_at":   updatedAt,
		}

		if clerkUserID != nil {
			publisher["clerk_user_id"] = *clerkUserID
		}
		if website != nil {
			publisher["website"] = *website
		}
		if logoURL != nil {
			publisher["logo_url"] = *logoURL
		}
		if bio != nil {
			publisher["bio"] = *bio
		}

		publishers = append(publishers, publisher)
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"publishers": publishers,
		"total":      len(publishers),
	})
}

// AdminCreatePublisher creates a new publisher and sends Clerk invitation
// POST /api/admin/publishers
func (h *Handlers) AdminCreatePublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req struct {
		Email        string  `json:"email"`
		Name         string  `json:"name"`
		Organization string  `json:"organization"`
		Website      *string `json:"website"`
		Bio          *string `json:"bio"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate required fields
	validationErrors := make(map[string]string)
	if req.Email == "" {
		validationErrors["email"] = "Email is required"
	}
	if req.Name == "" {
		validationErrors["name"] = "Name is required"
	}
	if req.Organization == "" {
		validationErrors["organization"] = "Organization is required"
	}
	if len(validationErrors) > 0 {
		RespondValidationError(w, r, "Invalid request parameters", validationErrors)
		return
	}

	// Generate slug from organization name
	slug := generateSlug(req.Organization)

	// Create Clerk user with publisher role
	var clerkUserID *string
	if h.clerkService != nil {
		userID, err := h.clerkService.CreatePublisherUser(ctx, req.Email, req.Name, req.Organization)
		if err != nil {
			slog.Error("failed to create Clerk user", "error", err, "email", req.Email)
			// Continue without Clerk user ID - allows manual setup later
		} else {
			clerkUserID = &userID
			slog.Info("clerk user created", "email", req.Email, "clerk_user_id", userID)

			// Send invitation email
			if inviteErr := h.clerkService.SendInvitation(ctx, req.Email); inviteErr != nil {
				slog.Error("failed to send invitation", "error", inviteErr, "email", req.Email)
			} else {
				slog.Info("invitation email sent", "email", req.Email)
			}
		}
	}

	// Insert new publisher
	query := `
		INSERT INTO publishers (name, organization, slug, email, website, description, clerk_user_id, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending_verification')
		RETURNING id, name, organization, email, website, description, clerk_user_id, status, created_at, updated_at
	`

	var id, name, organization, email, status string
	var website, description, dbClerkUserID *string
	var createdAt, updatedAt time.Time

	err := h.db.Pool.QueryRow(ctx, query, req.Name, req.Organization, slug, req.Email,
		req.Website, req.Bio, clerkUserID).Scan(&id, &name, &organization, &email, &website,
		&description, &dbClerkUserID, &status, &createdAt, &updatedAt)

	if err != nil {
		slog.Error("failed to create publisher", "error", err)

		// If publisher creation failed but Clerk user was created, clean up
		if clerkUserID != nil && h.clerkService != nil {
			if cleanupErr := h.clerkService.DeleteUser(ctx, *clerkUserID); cleanupErr != nil {
				slog.Error("failed to cleanup Clerk user", "error", cleanupErr, "clerk_user_id", *clerkUserID)
			}
		}

		// Check for unique constraint violation
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique constraint") {
			RespondConflict(w, r, "Publisher with this email already exists")
			return
		}
		RespondInternalError(w, r, "Failed to create publisher")
		return
	}

	publisher := map[string]interface{}{
		"id":           id,
		"name":         name,
		"organization": organization,
		"email":        email,
		"status":       status,
		"created_at":   createdAt,
		"updated_at":   updatedAt,
	}

	if website != nil {
		publisher["website"] = *website
	}
	if description != nil {
		publisher["bio"] = *description
	}
	if dbClerkUserID != nil {
		publisher["clerk_user_id"] = *dbClerkUserID
	}

	logFields := []interface{}{"id", id, "email", email, "status", status}
	if dbClerkUserID != nil {
		logFields = append(logFields, "clerk_user_id", *dbClerkUserID, "invitation_sent", true)
	} else {
		logFields = append(logFields, "invitation_sent", false)
	}
	slog.Info("publisher created", logFields...)

	RespondJSON(w, r, http.StatusCreated, publisher)
}

// AdminVerifyPublisher verifies a pending publisher
// PUT /api/admin/publishers/{id}/verify
func (h *Handlers) AdminVerifyPublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := chi.URLParam(r, "id")

	if id == "" {
		RespondValidationError(w, r, "Publisher ID is required", nil)
		return
	}

	result := h.updatePublisherStatus(ctx, id, "verified")
	if result.err != nil {
		handlePublisherStatusError(w, r, result)
		return
	}

	slog.Info("publisher verified", "id", id)
	RespondJSON(w, r, http.StatusOK, result.publisher)
}

// AdminSuspendPublisher suspends a verified publisher
// PUT /api/admin/publishers/{id}/suspend
func (h *Handlers) AdminSuspendPublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := chi.URLParam(r, "id")

	if id == "" {
		RespondValidationError(w, r, "Publisher ID is required", nil)
		return
	}

	result := h.updatePublisherStatus(ctx, id, "suspended")
	if result.err != nil {
		handlePublisherStatusError(w, r, result)
		return
	}

	slog.Info("publisher suspended", "id", id)
	RespondJSON(w, r, http.StatusOK, result.publisher)
}

// AdminReactivatePublisher reactivates a suspended publisher
// PUT /api/admin/publishers/{id}/reactivate
func (h *Handlers) AdminReactivatePublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := chi.URLParam(r, "id")

	if id == "" {
		RespondValidationError(w, r, "Publisher ID is required", nil)
		return
	}

	result := h.updatePublisherStatus(ctx, id, "verified")
	if result.err != nil {
		handlePublisherStatusError(w, r, result)
		return
	}

	slog.Info("publisher reactivated", "id", id)
	RespondJSON(w, r, http.StatusOK, result.publisher)
}

// AdminGetStats returns usage statistics
// GET /api/admin/stats
func (h *Handlers) AdminGetStats(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get publisher counts
	var totalPublishers, activePublishers, pendingPublishers, suspendedPublishers int

	publisherQuery := `
		SELECT
			COUNT(*) FILTER (WHERE status IN ('verified', 'pending', 'suspended')) as total,
			COUNT(*) FILTER (WHERE status = 'verified') as active,
			COUNT(*) FILTER (WHERE status = 'pending') as pending,
			COUNT(*) FILTER (WHERE status = 'suspended') as suspended
		FROM publishers
	`

	err := h.db.Pool.QueryRow(ctx, publisherQuery).Scan(
		&totalPublishers, &activePublishers, &pendingPublishers, &suspendedPublishers)
	if err != nil {
		slog.Error("failed to get publisher stats", "error", err)
		RespondInternalError(w, r, "Failed to retrieve statistics")
		return
	}

	// Get calculation count (from cache or logs - for now returning placeholder)
	totalCalculations := 0
	// TODO: Implement calculation tracking in Task 5

	// Get cache hit ratio (placeholder - will be implemented with Redis integration)
	cacheHitRatio := 0.0
	// TODO: Implement cache stats retrieval in Task 5

	stats := map[string]interface{}{
		"publishers": map[string]int{
			"total":     totalPublishers,
			"active":    activePublishers,
			"pending":   pendingPublishers,
			"suspended": suspendedPublishers,
		},
		"calculations": map[string]interface{}{
			"total":           totalCalculations,
			"cache_hit_ratio": cacheHitRatio,
		},
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	}

	RespondJSON(w, r, http.StatusOK, stats)
}

// AdminGetConfig returns system configuration
// GET /api/admin/config
func (h *Handlers) AdminGetConfig(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	query := `
		SELECT key, value, description, updated_at
		FROM system_config
		ORDER BY key
	`

	rows, err := h.db.Pool.Query(ctx, query)
	if err != nil {
		slog.Error("failed to query system config", "error", err)
		RespondInternalError(w, r, "Failed to retrieve configuration")
		return
	}
	defer rows.Close()

	config := make(map[string]interface{})
	for rows.Next() {
		var key, description string
		var value map[string]interface{}
		var updatedAt time.Time

		err := rows.Scan(&key, &value, &description, &updatedAt)
		if err != nil {
			slog.Error("failed to scan config row", "error", err)
			continue
		}

		config[key] = map[string]interface{}{
			"value":       value,
			"description": description,
			"updated_at":  updatedAt,
		}
	}

	RespondJSON(w, r, http.StatusOK, config)
}

// AdminUpdateConfig updates system configuration
// PUT /api/admin/config
func (h *Handlers) AdminUpdateConfig(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req struct {
		Key   string                 `json:"key"`
		Value map[string]interface{} `json:"value"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate required fields
	if req.Key == "" {
		RespondValidationError(w, r, "Configuration key is required", nil)
		return
	}

	query := `
		UPDATE system_config
		SET value = $1, updated_at = NOW()
		WHERE key = $2
		RETURNING key, value, description, updated_at
	`

	var key, description string
	var value map[string]interface{}
	var updatedAt time.Time

	err := h.db.Pool.QueryRow(ctx, query, req.Value, req.Key).Scan(
		&key, &value, &description, &updatedAt)

	if err != nil {
		if err == pgx.ErrNoRows {
			RespondNotFound(w, r, "Configuration key not found")
			return
		}
		slog.Error("failed to update system config", "error", err, "key", req.Key)
		RespondInternalError(w, r, "Failed to update configuration")
		return
	}

	slog.Info("system config updated", "key", key)

	result := map[string]interface{}{
		"key":         key,
		"value":       value,
		"description": description,
		"updated_at":  updatedAt,
	}

	RespondJSON(w, r, http.StatusOK, result)
}

// Helper types and functions

type statusUpdateResult struct {
	publisher map[string]interface{}
	err       error
	notFound  bool
}

func (h *Handlers) updatePublisherStatus(ctx context.Context, id, status string) statusUpdateResult {
	query := `
		UPDATE publishers
		SET status = $1, updated_at = NOW()
		WHERE id = $2
		RETURNING id, name, organization, email, status, created_at, updated_at
	`

	var resID, name, organization, email, resStatus string
	var createdAt, updatedAt time.Time

	err := h.db.Pool.QueryRow(ctx, query, status, id).Scan(
		&resID, &name, &organization, &email, &resStatus, &createdAt, &updatedAt)

	if err != nil {
		if err == pgx.ErrNoRows {
			return statusUpdateResult{err: err, notFound: true}
		}
		slog.Error("failed to update publisher status", "error", err, "id", id)
		return statusUpdateResult{err: err}
	}

	publisher := map[string]interface{}{
		"id":           resID,
		"name":         name,
		"organization": organization,
		"email":        email,
		"status":       resStatus,
		"created_at":   createdAt,
		"updated_at":   updatedAt,
	}

	return statusUpdateResult{publisher: publisher}
}

func handlePublisherStatusError(w http.ResponseWriter, r *http.Request, result statusUpdateResult) {
	if result.notFound {
		RespondNotFound(w, r, "Publisher not found")
		return
	}
	RespondInternalError(w, r, "Failed to update publisher status")
}

// generateSlug creates a URL-friendly slug from text
func generateSlug(text string) string {
	// Convert to lowercase
	slug := strings.ToLower(text)

	// Replace spaces and special characters with hyphens
	slug = strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			return r
		}
		return '-'
	}, slug)

	// Remove consecutive hyphens
	for strings.Contains(slug, "--") {
		slug = strings.ReplaceAll(slug, "--", "-")
	}

	// Trim hyphens from start and end
	slug = strings.Trim(slug, "-")

	// Limit length to 100 characters
	if len(slug) > 100 {
		slug = slug[:100]
		slug = strings.TrimRight(slug, "-")
	}

	return slug
}
