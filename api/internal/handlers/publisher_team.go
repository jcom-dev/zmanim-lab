package handlers

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jcom-dev/zmanim-lab/internal/middleware"
)

// PublisherInvitation represents a team invitation
type PublisherInvitation struct {
	ID          string     `json:"id"`
	PublisherID string     `json:"publisher_id"`
	Email       string     `json:"email"`
	Token       string     `json:"-"` // Never expose token in responses
	Status      string     `json:"status"`
	InvitedBy   string     `json:"invited_by"`
	ExpiresAt   time.Time  `json:"expires_at"`
	AcceptedAt  *time.Time `json:"accepted_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
}

// TeamMember represents a user with publisher access
type TeamMember struct {
	UserID    string    `json:"user_id"`
	Email     string    `json:"email"`
	Name      string    `json:"name"`
	ImageURL  string    `json:"image_url,omitempty"`
	AddedAt   time.Time `json:"added_at"`
	IsOwner   bool      `json:"is_owner"`
}

// GetPublisherTeam returns team members and pending invitations
// GET /api/publisher/team
func (h *Handlers) GetPublisherTeam(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Get publisher ID from header or query
	publisherID := r.Header.Get("X-Publisher-Id")
	if publisherID == "" {
		publisherID = r.URL.Query().Get("publisher_id")
	}

	// If no publisher ID provided, get from database
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

	// Get the publisher's owner (clerk_user_id)
	var ownerID *string
	h.db.Pool.QueryRow(ctx,
		"SELECT clerk_user_id FROM publishers WHERE id = $1",
		publisherID,
	).Scan(&ownerID)

	// Get team members from Clerk
	members := make([]TeamMember, 0)
	if h.clerkService != nil {
		users, err := h.clerkService.GetUsersWithPublisherAccess(ctx, publisherID)
		if err != nil {
			slog.Error("failed to get publisher users from Clerk", "error", err)
		} else {
			for _, u := range users {
				member := TeamMember{
					UserID:   u.ClerkUserID,
					Email:    u.Email,
					Name:     u.Name,
					ImageURL: u.ImageURL,
					AddedAt:  time.Unix(u.CreatedAt/1000, 0), // Clerk uses milliseconds
					IsOwner:  ownerID != nil && u.ClerkUserID == *ownerID,
				}
				members = append(members, member)
			}
		}
	}

	// Get pending invitations
	invitations := make([]map[string]interface{}, 0)
	rows, err := h.db.Pool.Query(ctx, `
		SELECT id, email, status, expires_at, created_at
		FROM publisher_invitations
		WHERE publisher_id = $1 AND status IN ('pending', 'expired')
		ORDER BY created_at DESC
	`, publisherID)

	if err != nil {
		slog.Error("failed to get publisher invitations", "error", err)
	} else {
		defer rows.Close()
		now := time.Now()
		for rows.Next() {
			var id, email, status string
			var expiresAt, createdAt time.Time

			if err := rows.Scan(&id, &email, &status, &expiresAt, &createdAt); err != nil {
				continue
			}

			// Check if expired
			if status == "pending" && now.After(expiresAt) {
				status = "expired"
			}

			invitations = append(invitations, map[string]interface{}{
				"id":         id,
				"email":      email,
				"status":     status,
				"expires_at": expiresAt,
				"created_at": createdAt,
			})
		}
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"members":             members,
		"pending_invitations": invitations,
	})
}

// InvitePublisherTeamMember invites a new team member
// POST /api/publisher/team/invite
func (h *Handlers) InvitePublisherTeamMember(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	var req struct {
		Email string `json:"email"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	if req.Email == "" || !isValidEmail(req.Email) {
		RespondValidationError(w, r, "Valid email is required", map[string]string{"email": "Valid email is required"})
		return
	}

	// Get publisher ID from header or query
	publisherID := r.Header.Get("X-Publisher-Id")
	if publisherID == "" {
		publisherID = r.URL.Query().Get("publisher_id")
	}

	// If no publisher ID provided, get from database
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

	// Get publisher name for the email
	var publisherName string
	err := h.db.Pool.QueryRow(ctx,
		"SELECT name FROM publishers WHERE id = $1",
		publisherID,
	).Scan(&publisherName)
	if err != nil {
		RespondNotFound(w, r, "Publisher not found")
		return
	}

	// Check if user already has access
	if h.clerkService != nil {
		existingUser, err := h.clerkService.GetUserByEmail(ctx, req.Email)
		if err == nil && existingUser != nil {
			metadata, _ := h.clerkService.GetUserPublicMetadata(ctx, existingUser.ID)
			if accessList, ok := metadata["publisher_access_list"].([]interface{}); ok {
				for _, id := range accessList {
					if idStr, ok := id.(string); ok && idStr == publisherID {
						RespondConflict(w, r, "User already has access to this publisher")
						return
					}
				}
			}
		}
	}

	// Check for existing pending invitation
	var existingCount int
	h.db.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM publisher_invitations
		WHERE publisher_id = $1 AND LOWER(email) = LOWER($2) AND status = 'pending'
	`, publisherID, req.Email).Scan(&existingCount)

	if existingCount > 0 {
		RespondConflict(w, r, "An invitation for this email is already pending")
		return
	}

	// Generate token
	token, err := generateSecureToken()
	if err != nil {
		slog.Error("failed to generate invitation token", "error", err)
		RespondInternalError(w, r, "Failed to create invitation")
		return
	}

	// Create invitation (expires in 7 days)
	expiresAt := time.Now().Add(7 * 24 * time.Hour)
	var invitationID string

	err = h.db.Pool.QueryRow(ctx, `
		INSERT INTO publisher_invitations (publisher_id, email, token, status, invited_by, expires_at)
		VALUES ($1, $2, $3, 'pending', $4, $5)
		RETURNING id
	`, publisherID, req.Email, token, userID, expiresAt).Scan(&invitationID)

	if err != nil {
		slog.Error("failed to create publisher invitation", "error", err)
		RespondInternalError(w, r, "Failed to create invitation")
		return
	}

	// Get inviter name for the email
	inviterName := "A team member"
	if h.clerkService != nil {
		inviter, err := h.clerkService.GetUser(ctx, userID)
		if err == nil && inviter != nil {
			if inviter.FirstName != nil {
				inviterName = *inviter.FirstName
				if inviter.LastName != nil {
					inviterName += " " + *inviter.LastName
				}
			}
		}
	}

	// Send invitation email
	if h.emailService != nil {
		webURL := os.Getenv("WEB_URL")
		if webURL == "" {
			webURL = "http://localhost:3001"
		}
		acceptURL := fmt.Sprintf("%s/accept-invitation?token=%s", webURL, token)
		go h.emailService.SendInvitation(req.Email, inviterName, publisherName, acceptURL)
	}

	slog.Info("publisher team invitation sent",
		"invitation_id", invitationID,
		"publisher_id", publisherID,
		"email", req.Email,
		"invited_by", userID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Invitation sent",
	})
}

// RemovePublisherTeamMember removes a team member
// DELETE /api/publisher/team/{userId}
func (h *Handlers) RemovePublisherTeamMember(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	currentUserID := middleware.GetUserID(ctx)
	if currentUserID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	memberUserID := chi.URLParam(r, "userId")
	if memberUserID == "" {
		RespondValidationError(w, r, "User ID is required", nil)
		return
	}

	// Get publisher ID from header or query
	publisherID := r.Header.Get("X-Publisher-Id")
	if publisherID == "" {
		publisherID = r.URL.Query().Get("publisher_id")
	}

	// If no publisher ID provided, get from database
	if publisherID == "" {
		err := h.db.Pool.QueryRow(ctx,
			"SELECT id FROM publishers WHERE clerk_user_id = $1",
			currentUserID,
		).Scan(&publisherID)
		if err != nil {
			RespondNotFound(w, r, "Publisher not found")
			return
		}
	}

	// Prevent removing yourself
	if memberUserID == currentUserID {
		RespondBadRequest(w, r, "You cannot remove yourself from the team")
		return
	}

	// Remove publisher access via Clerk
	if h.clerkService == nil {
		RespondInternalError(w, r, "Clerk service not available")
		return
	}

	if err := h.clerkService.RemovePublisherFromUser(ctx, memberUserID, publisherID); err != nil {
		slog.Error("failed to remove publisher from user", "error", err)
		RespondInternalError(w, r, "Failed to remove team member")
		return
	}

	slog.Info("team member removed",
		"publisher_id", publisherID,
		"removed_user", memberUserID,
		"removed_by", currentUserID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Member removed",
	})
}

// ResendPublisherInvitation resends an invitation email
// POST /api/publisher/team/invitations/{id}/resend
func (h *Handlers) ResendPublisherInvitation(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	invitationID := chi.URLParam(r, "id")
	if invitationID == "" {
		RespondValidationError(w, r, "Invitation ID is required", nil)
		return
	}

	// Get the invitation and verify ownership
	var publisherID, email, token string
	err := h.db.Pool.QueryRow(ctx, `
		SELECT pi.publisher_id, pi.email, pi.token
		FROM publisher_invitations pi
		JOIN publishers p ON pi.publisher_id = p.id
		WHERE pi.id = $1 AND pi.status = 'pending'
	`, invitationID).Scan(&publisherID, &email, &token)

	if err != nil {
		if err == pgx.ErrNoRows {
			RespondNotFound(w, r, "Invitation not found")
			return
		}
		slog.Error("failed to get invitation", "error", err)
		RespondInternalError(w, r, "Failed to retrieve invitation")
		return
	}

	// Generate new token and reset expiration
	newToken, err := generateSecureToken()
	if err != nil {
		slog.Error("failed to generate new token", "error", err)
		RespondInternalError(w, r, "Failed to resend invitation")
		return
	}

	newExpiry := time.Now().Add(7 * 24 * time.Hour)
	_, err = h.db.Pool.Exec(ctx, `
		UPDATE publisher_invitations
		SET token = $1, expires_at = $2
		WHERE id = $3
	`, newToken, newExpiry, invitationID)

	if err != nil {
		slog.Error("failed to update invitation", "error", err)
		RespondInternalError(w, r, "Failed to resend invitation")
		return
	}

	// Get publisher name for the email
	var publisherName string
	h.db.Pool.QueryRow(ctx, "SELECT name FROM publishers WHERE id = $1", publisherID).Scan(&publisherName)

	// Get inviter name
	inviterName := "A team member"
	if h.clerkService != nil {
		inviter, err := h.clerkService.GetUser(ctx, userID)
		if err == nil && inviter != nil && inviter.FirstName != nil {
			inviterName = *inviter.FirstName
			if inviter.LastName != nil {
				inviterName += " " + *inviter.LastName
			}
		}
	}

	// Resend email
	if h.emailService != nil {
		webURL := os.Getenv("WEB_URL")
		if webURL == "" {
			webURL = "http://localhost:3001"
		}
		acceptURL := fmt.Sprintf("%s/accept-invitation?token=%s", webURL, newToken)
		go h.emailService.SendInvitation(email, inviterName, publisherName, acceptURL)
	}

	slog.Info("publisher invitation resent",
		"invitation_id", invitationID,
		"email", email)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Invitation resent",
	})
}

// CancelPublisherInvitation cancels a pending invitation
// DELETE /api/publisher/team/invitations/{id}
func (h *Handlers) CancelPublisherInvitation(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	invitationID := chi.URLParam(r, "id")
	if invitationID == "" {
		RespondValidationError(w, r, "Invitation ID is required", nil)
		return
	}

	// Delete the invitation (only if pending)
	result, err := h.db.Pool.Exec(ctx, `
		DELETE FROM publisher_invitations
		WHERE id = $1 AND status = 'pending'
	`, invitationID)

	if err != nil {
		slog.Error("failed to cancel invitation", "error", err)
		RespondInternalError(w, r, "Failed to cancel invitation")
		return
	}

	if result.RowsAffected() == 0 {
		RespondNotFound(w, r, "Invitation not found or already processed")
		return
	}

	slog.Info("publisher invitation cancelled",
		"invitation_id", invitationID,
		"cancelled_by", userID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Invitation cancelled",
	})
}

// AcceptPublisherInvitation accepts an invitation via token
// POST /api/publisher/team/accept
func (h *Handlers) AcceptPublisherInvitation(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	userID := middleware.GetUserID(ctx)
	if userID == "" {
		RespondUnauthorized(w, r, "Please sign in to accept this invitation")
		return
	}

	var req struct {
		Token string `json:"token"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	if req.Token == "" {
		RespondValidationError(w, r, "Token is required", nil)
		return
	}

	// Find the invitation
	var invitation PublisherInvitation
	var publisherName string
	err := h.db.Pool.QueryRow(ctx, `
		SELECT pi.id, pi.publisher_id, pi.email, pi.status, pi.expires_at, p.name
		FROM publisher_invitations pi
		JOIN publishers p ON pi.publisher_id = p.id
		WHERE pi.token = $1
	`, req.Token).Scan(&invitation.ID, &invitation.PublisherID, &invitation.Email,
		&invitation.Status, &invitation.ExpiresAt, &publisherName)

	if err != nil {
		if err == pgx.ErrNoRows {
			RespondBadRequest(w, r, "This invitation is invalid or has expired. Please request a new invitation.")
			return
		}
		slog.Error("failed to get invitation", "error", err)
		RespondInternalError(w, r, "Failed to process invitation")
		return
	}

	// Check status and expiration
	if invitation.Status != "pending" {
		RespondBadRequest(w, r, "This invitation has already been used or cancelled")
		return
	}

	if time.Now().After(invitation.ExpiresAt) {
		// Mark as expired
		h.db.Pool.Exec(ctx, "UPDATE publisher_invitations SET status = 'expired' WHERE id = $1", invitation.ID)
		RespondBadRequest(w, r, "This invitation has expired. Please request a new invitation.")
		return
	}

	// Add publisher access to user via Clerk
	if h.clerkService == nil {
		RespondInternalError(w, r, "Clerk service not available")
		return
	}

	if err := h.clerkService.AddPublisherToUser(ctx, userID, invitation.PublisherID); err != nil {
		slog.Error("failed to add publisher to user", "error", err)
		RespondInternalError(w, r, "Failed to grant publisher access")
		return
	}

	// Update invitation status
	_, err = h.db.Pool.Exec(ctx, `
		UPDATE publisher_invitations
		SET status = 'accepted', accepted_at = NOW()
		WHERE id = $1
	`, invitation.ID)

	if err != nil {
		slog.Error("failed to update invitation status", "error", err)
		// Don't fail - the user already has access
	}

	slog.Info("publisher invitation accepted",
		"invitation_id", invitation.ID,
		"publisher_id", invitation.PublisherID,
		"user_id", userID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success":        true,
		"publisher_id":   invitation.PublisherID,
		"publisher_name": publisherName,
		"message":        fmt.Sprintf("You've been added to %s!", publisherName),
	})
}
