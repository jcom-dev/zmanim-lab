package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

// AdminGetPublisherUsers returns all users linked to a publisher
// GET /api/admin/publishers/{id}/users
func (h *Handlers) AdminGetPublisherUsers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	publisherID := chi.URLParam(r, "id")

	if publisherID == "" {
		RespondValidationError(w, r, "Publisher ID is required", nil)
		return
	}

	// Verify publisher exists
	var exists bool
	err := h.db.Pool.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM publishers WHERE id = $1)", publisherID).Scan(&exists)
	if err != nil {
		slog.Error("failed to check publisher existence", "error", err, "publisher_id", publisherID)
		RespondInternalError(w, r, "Failed to verify publisher")
		return
	}
	if !exists {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	if h.clerkService == nil {
		RespondInternalError(w, r, "Clerk service not available")
		return
	}

	// Get users with access to this publisher from Clerk
	users, err := h.clerkService.GetUsersWithPublisherAccess(ctx, publisherID)
	if err != nil {
		slog.Error("failed to get publisher users", "error", err, "publisher_id", publisherID)
		RespondInternalError(w, r, "Failed to retrieve users")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"users": users,
		"total": len(users),
	})
}

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

// AdminCreatePublisher creates a new publisher entity (no Clerk user)
// POST /api/admin/publishers
// Note: Use AdminInviteUserToPublisher to invite users to manage this publisher
func (h *Handlers) AdminCreatePublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req struct {
		Name         string  `json:"name"`
		Organization string  `json:"organization"`
		Email        *string `json:"email"`   // Optional contact email for the publisher
		Website      *string `json:"website"`
		Bio          *string `json:"bio"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate required fields
	validationErrors := make(map[string]string)
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

	// Insert new publisher as verified (admin-created publishers are auto-verified)
	query := `
		INSERT INTO publishers (name, organization, slug, email, website, description, status)
		VALUES ($1, $2, $3, $4, $5, $6, 'verified')
		RETURNING id, name, organization, slug, email, website, description, status, created_at, updated_at
	`

	var id, name, organization, resSlug, status string
	var email, website, description *string
	var createdAt, updatedAt time.Time

	err := h.db.Pool.QueryRow(ctx, query, req.Name, req.Organization, slug, req.Email,
		req.Website, req.Bio).Scan(&id, &name, &organization, &resSlug, &email, &website,
		&description, &status, &createdAt, &updatedAt)

	if err != nil {
		slog.Error("failed to create publisher", "error", err)

		// Check for unique constraint violation
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique constraint") {
			RespondConflict(w, r, "Publisher with this organization already exists")
			return
		}
		RespondInternalError(w, r, "Failed to create publisher")
		return
	}

	publisher := map[string]interface{}{
		"id":           id,
		"name":         name,
		"organization": organization,
		"slug":         resSlug,
		"status":       status,
		"created_at":   createdAt,
		"updated_at":   updatedAt,
	}

	if email != nil {
		publisher["email"] = *email
	}
	if website != nil {
		publisher["website"] = *website
	}
	if description != nil {
		publisher["bio"] = *description
	}

	slog.Info("publisher created", "id", id, "organization", organization, "status", status)

	// Get publisher email for invite
	publisherEmail := ""
	if email != nil {
		publisherEmail = *email
	}

	// Send approval email and invite (non-blocking)
	if publisherEmail != "" {
		webURL := os.Getenv("WEB_URL")
		if webURL == "" {
			webURL = "http://localhost:3001"
		}
		dashboardURL := fmt.Sprintf("%s/publisher/dashboard", webURL)

		// Send approval/welcome email
		if h.emailService != nil {
			go func() {
				err := h.emailService.SendPublisherApproved(publisherEmail, name, dashboardURL)
				if err != nil {
					slog.Error("failed to send publisher welcome email",
						"error", err,
						"publisher_id", id,
						"email", publisherEmail)
				} else {
					slog.Info("publisher welcome email sent",
						"publisher_id", id,
						"email", publisherEmail)
				}
			}()
		}

		// Create Clerk user or add publisher to existing user
		if h.clerkService != nil {
			go func() {
				// Check if user already exists in Clerk
				existingUser, err := h.clerkService.GetUserByEmail(context.Background(), publisherEmail)
				if err != nil {
					slog.Error("failed to check for existing user",
						"error", err,
						"email", publisherEmail)
					return
				}

				if existingUser != nil {
					// User exists - add publisher to their access list
					if err := h.clerkService.AddPublisherToUser(context.Background(), existingUser.ID, id); err != nil {
						slog.Error("failed to add publisher to existing user",
							"error", err,
							"user_id", existingUser.ID,
							"publisher_id", id)
					} else {
						slog.Info("publisher access granted to existing user",
							"email", publisherEmail,
							"user_id", existingUser.ID,
							"publisher_id", id)
					}
				} else {
					// User doesn't exist - create them directly (works with Restricted mode)
					newUser, err := h.clerkService.CreatePublisherUserDirectly(context.Background(), publisherEmail, name, id)
					if err != nil {
						slog.Error("failed to create publisher user",
							"error", err,
							"email", publisherEmail,
							"publisher_id", id)
					} else {
						slog.Info("publisher user created",
							"email", publisherEmail,
							"user_id", newUser.ID,
							"publisher_id", id)
					}
				}
			}()
		}
	}

	RespondJSON(w, r, http.StatusCreated, publisher)
}

// AdminInviteUserToPublisher invites a user to manage a publisher
// POST /api/admin/publishers/{id}/users/invite
// If user exists in Clerk, adds publisher to their access list
// If user doesn't exist, sends invitation with publisher metadata
func (h *Handlers) AdminInviteUserToPublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	publisherID := chi.URLParam(r, "id")

	if publisherID == "" {
		RespondValidationError(w, r, "Publisher ID is required", nil)
		return
	}

	var req struct {
		Email string `json:"email"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	if req.Email == "" {
		RespondValidationError(w, r, "Email is required", map[string]string{"email": "Email is required"})
		return
	}

	// Verify publisher exists
	var exists bool
	err := h.db.Pool.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM publishers WHERE id = $1)", publisherID).Scan(&exists)
	if err != nil {
		slog.Error("failed to check publisher existence", "error", err, "publisher_id", publisherID)
		RespondInternalError(w, r, "Failed to verify publisher")
		return
	}
	if !exists {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	if h.clerkService == nil {
		RespondInternalError(w, r, "Clerk service not available")
		return
	}

	// Check if user already exists in Clerk
	existingUser, err := h.clerkService.GetUserByEmail(ctx, req.Email)
	if err != nil {
		slog.Error("failed to search for existing user", "error", err, "email", req.Email)
		RespondInternalError(w, r, "Failed to check for existing user")
		return
	}

	if existingUser != nil {
		// User exists - add publisher to their access list
		if err := h.clerkService.AddPublisherToUser(ctx, existingUser.ID, publisherID); err != nil {
			slog.Error("failed to add publisher to user", "error", err, "user_id", existingUser.ID, "publisher_id", publisherID)
			RespondInternalError(w, r, "Failed to add publisher access")
			return
		}

		slog.Info("publisher access added to existing user",
			"email", req.Email,
			"user_id", existingUser.ID,
			"publisher_id", publisherID)

		RespondJSON(w, r, http.StatusOK, map[string]interface{}{
			"status":       "access_granted",
			"message":      "Publisher access added to existing user",
			"email":        req.Email,
			"publisher_id": publisherID,
			"user_id":      existingUser.ID,
		})
		return
	}

	// User doesn't exist - send invitation with publisher metadata
	if err := h.clerkService.SendPublisherInvitation(ctx, req.Email, publisherID); err != nil {
		slog.Error("failed to send publisher invitation", "error", err, "email", req.Email, "publisher_id", publisherID)
		RespondInternalError(w, r, "Failed to send invitation")
		return
	}

	slog.Info("publisher invitation sent",
		"email", req.Email,
		"publisher_id", publisherID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"status":       "invitation_sent",
		"message":      "Invitation email sent to user",
		"email":        req.Email,
		"publisher_id": publisherID,
	})
}

// AdminRemoveUserFromPublisher removes a user's access to a publisher
// DELETE /api/admin/publishers/{id}/users/{userId}
func (h *Handlers) AdminRemoveUserFromPublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	publisherID := chi.URLParam(r, "id")
	userID := chi.URLParam(r, "userId")

	if publisherID == "" {
		RespondValidationError(w, r, "Publisher ID is required", nil)
		return
	}
	if userID == "" {
		RespondValidationError(w, r, "User ID is required", nil)
		return
	}

	// Verify publisher exists
	var exists bool
	err := h.db.Pool.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM publishers WHERE id = $1)", publisherID).Scan(&exists)
	if err != nil {
		slog.Error("failed to check publisher existence", "error", err, "publisher_id", publisherID)
		RespondInternalError(w, r, "Failed to verify publisher")
		return
	}
	if !exists {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	if h.clerkService == nil {
		RespondInternalError(w, r, "Clerk service not available")
		return
	}

	// Remove publisher from user's access list
	if err := h.clerkService.RemovePublisherFromUser(ctx, userID, publisherID); err != nil {
		slog.Error("failed to remove publisher from user", "error", err, "user_id", userID, "publisher_id", publisherID)
		RespondInternalError(w, r, "Failed to remove publisher access")
		return
	}

	slog.Info("publisher access removed from user",
		"user_id", userID,
		"publisher_id", publisherID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"status":       "access_removed",
		"message":      "Publisher access removed from user",
		"user_id":      userID,
		"publisher_id": publisherID,
	})
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

	// Get publisher details before updating status (for email)
	var publisherEmail, publisherName string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT email, name FROM publishers WHERE id = $1", id).Scan(&publisherEmail, &publisherName)
	if err != nil {
		slog.Error("failed to get publisher for verification", "error", err, "id", id)
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	result := h.updatePublisherStatus(ctx, id, "verified")
	if result.err != nil {
		handlePublisherStatusError(w, r, result)
		return
	}

	slog.Info("publisher verified", "id", id)

	// Send approval email and invite user (non-blocking)
	if publisherEmail != "" {
		webURL := os.Getenv("WEB_URL")
		if webURL == "" {
			webURL = "http://localhost:3001"
		}
		dashboardURL := fmt.Sprintf("%s/publisher/dashboard", webURL)

		// Send approval email
		if h.emailService != nil {
			go func() {
				err := h.emailService.SendPublisherApproved(publisherEmail, publisherName, dashboardURL)
				if err != nil {
					slog.Error("failed to send publisher approval email",
						"error", err,
						"publisher_id", id,
						"email", publisherEmail)
				} else {
					slog.Info("publisher approval email sent",
						"publisher_id", id,
						"email", publisherEmail)
				}
			}()
		}

		// Automatically create user or add publisher to existing user
		if h.clerkService != nil {
			go func() {
				// Check if user already exists in Clerk
				existingUser, err := h.clerkService.GetUserByEmail(context.Background(), publisherEmail)
				if err != nil {
					slog.Error("failed to check for existing user during verification",
						"error", err,
						"email", publisherEmail)
					return
				}

				if existingUser != nil {
					// User exists - add publisher to their access list
					if err := h.clerkService.AddPublisherToUser(context.Background(), existingUser.ID, id); err != nil {
						slog.Error("failed to add publisher to existing user",
							"error", err,
							"user_id", existingUser.ID,
							"publisher_id", id)
					} else {
						slog.Info("publisher access granted to existing user",
							"email", publisherEmail,
							"user_id", existingUser.ID,
							"publisher_id", id)
					}
				} else {
					// User doesn't exist - create them directly (works with Restricted mode)
					newUser, err := h.clerkService.CreatePublisherUserDirectly(context.Background(), publisherEmail, publisherName, id)
					if err != nil {
						slog.Error("failed to create publisher user",
							"error", err,
							"email", publisherEmail,
							"publisher_id", id)
					} else {
						slog.Info("publisher user created",
							"email", publisherEmail,
							"user_id", newUser.ID,
							"publisher_id", id)
					}
				}
			}()
		}
	}

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

// AdminUpdatePublisher updates a publisher's details
// PUT /api/admin/publishers/{id}
func (h *Handlers) AdminUpdatePublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := chi.URLParam(r, "id")

	if id == "" {
		RespondValidationError(w, r, "Publisher ID is required", nil)
		return
	}

	var req struct {
		Name         *string `json:"name"`
		Organization *string `json:"organization"`
		Email        *string `json:"email"`
		Website      *string `json:"website"`
		Bio          *string `json:"bio"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Build dynamic update query
	query := `
		UPDATE publishers
		SET updated_at = NOW()
	`
	args := []interface{}{}
	argIndex := 1

	if req.Name != nil {
		query += fmt.Sprintf(", name = $%d", argIndex)
		args = append(args, *req.Name)
		argIndex++
	}
	if req.Organization != nil {
		query += fmt.Sprintf(", organization = $%d", argIndex)
		args = append(args, *req.Organization)
		argIndex++
		// Also update slug
		query += fmt.Sprintf(", slug = $%d", argIndex)
		args = append(args, generateSlug(*req.Organization))
		argIndex++
	}
	if req.Email != nil {
		query += fmt.Sprintf(", email = $%d", argIndex)
		args = append(args, *req.Email)
		argIndex++
	}
	if req.Website != nil {
		query += fmt.Sprintf(", website = $%d", argIndex)
		args = append(args, *req.Website)
		argIndex++
	}
	if req.Bio != nil {
		query += fmt.Sprintf(", description = $%d", argIndex)
		args = append(args, *req.Bio)
		argIndex++
	}

	query += fmt.Sprintf(`
		WHERE id = $%d
		RETURNING id, name, organization, slug, email, website, description, status, created_at, updated_at
	`, argIndex)
	args = append(args, id)

	var resID, name, organization, slug, status string
	var email, website, description *string
	var createdAt, updatedAt time.Time

	err := h.db.Pool.QueryRow(ctx, query, args...).Scan(
		&resID, &name, &organization, &slug, &email, &website,
		&description, &status, &createdAt, &updatedAt)

	if err != nil {
		if err == pgx.ErrNoRows {
			RespondNotFound(w, r, "Publisher not found")
			return
		}
		slog.Error("failed to update publisher", "error", err, "id", id)
		RespondInternalError(w, r, "Failed to update publisher")
		return
	}

	publisher := map[string]interface{}{
		"id":           resID,
		"name":         name,
		"organization": organization,
		"slug":         slug,
		"status":       status,
		"created_at":   createdAt,
		"updated_at":   updatedAt,
	}

	if email != nil {
		publisher["email"] = *email
	}
	if website != nil {
		publisher["website"] = *website
	}
	if description != nil {
		publisher["bio"] = *description
	}

	slog.Info("publisher updated", "id", id)
	RespondJSON(w, r, http.StatusOK, publisher)
}

// AdminDeletePublisher deletes a publisher and cleans up associated Clerk users
// DELETE /api/admin/publishers/{id}
func (h *Handlers) AdminDeletePublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := chi.URLParam(r, "id")

	if id == "" {
		RespondValidationError(w, r, "Publisher ID is required", nil)
		return
	}

	// First, get all Clerk users with access to this publisher
	var usersToCleanup []struct {
		ClerkUserID     string
		PublisherCount  int
	}

	if h.clerkService != nil {
		users, err := h.clerkService.GetUsersWithPublisherAccess(ctx, id)
		if err != nil {
			slog.Warn("failed to get users with publisher access", "error", err, "publisher_id", id)
		} else {
			// For each user, check if this is their only publisher
			for _, user := range users {
				metadata, err := h.clerkService.GetUserPublicMetadata(ctx, user.ClerkUserID)
				if err != nil {
					slog.Warn("failed to get user metadata", "error", err, "user_id", user.ClerkUserID)
					continue
				}

				accessList, ok := metadata["publisher_access_list"].([]interface{})
				publisherCount := 0
				if ok {
					publisherCount = len(accessList)
				}

				usersToCleanup = append(usersToCleanup, struct {
					ClerkUserID    string
					PublisherCount int
				}{
					ClerkUserID:    user.ClerkUserID,
					PublisherCount: publisherCount,
				})
			}
		}
	}

	// Get publisher name for logging
	var publisherName string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT name FROM publishers WHERE id = $1", id).Scan(&publisherName)
	if err != nil {
		if err == pgx.ErrNoRows {
			RespondNotFound(w, r, "Publisher not found")
			return
		}
		slog.Error("failed to get publisher", "error", err, "id", id)
		RespondInternalError(w, r, "Failed to get publisher")
		return
	}

	// Delete the publisher (cascading will handle related tables)
	result, err := h.db.Pool.Exec(ctx, "DELETE FROM publishers WHERE id = $1", id)
	if err != nil {
		slog.Error("failed to delete publisher", "error", err, "id", id)
		RespondInternalError(w, r, "Failed to delete publisher")
		return
	}

	if result.RowsAffected() == 0 {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	slog.Info("publisher deleted", "id", id, "name", publisherName)

	// Clean up Clerk users in background
	if h.clerkService != nil && len(usersToCleanup) > 0 {
		go func() {
			for _, user := range usersToCleanup {
				if user.PublisherCount <= 1 {
					// This was their only publisher - delete the Clerk user
					if err := h.clerkService.DeleteUser(context.Background(), user.ClerkUserID); err != nil {
						slog.Error("failed to delete Clerk user",
							"error", err,
							"user_id", user.ClerkUserID,
							"publisher_id", id)
					} else {
						slog.Info("deleted Clerk user who only had access to deleted publisher",
							"user_id", user.ClerkUserID,
							"publisher_id", id)
					}
				} else {
					// User has other publishers - just remove this one from their list
					if err := h.clerkService.RemovePublisherFromUser(context.Background(), user.ClerkUserID, id); err != nil {
						slog.Error("failed to remove publisher from user",
							"error", err,
							"user_id", user.ClerkUserID,
							"publisher_id", id)
					} else {
						slog.Info("removed publisher from user access list",
							"user_id", user.ClerkUserID,
							"publisher_id", id)
					}
				}
			}
		}()
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"message":        "Publisher deleted successfully",
		"id":             id,
		"name":           publisherName,
		"users_affected": len(usersToCleanup),
	})
}

// AdminGetStats returns usage statistics
// GET /api/admin/stats
func (h *Handlers) AdminGetStats(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get publisher counts
	var totalPublishers, activePublishers, pendingPublishers, suspendedPublishers int

	publisherQuery := `
		SELECT
			COUNT(*) FILTER (WHERE status IN ('verified', 'pending', 'pending_verification', 'suspended')) as total,
			COUNT(*) FILTER (WHERE status = 'verified') as active,
			COUNT(*) FILTER (WHERE status IN ('pending', 'pending_verification')) as pending,
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
