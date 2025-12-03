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

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Get the publisher's owner (clerk_user_id)
	var ownerID *string
	_ = h.db.Pool.QueryRow(ctx,
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

// AddPublisherTeamMember adds a new team member (direct creation, no invitation)
// POST /api/publisher/team/invite
// If user exists: adds publisher to their access list
// If user doesn't exist: creates user directly and sends welcome email
func (h *Handlers) AddPublisherTeamMember(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID
	userID := pc.UserID

	var req struct {
		Email string `json:"email"`
		Name  string `json:"name"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	if req.Email == "" || !isValidEmail(req.Email) {
		RespondValidationError(w, r, "Valid email is required", map[string]string{"email": "Valid email is required"})
		return
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

	if h.clerkService == nil {
		RespondInternalError(w, r, "Clerk service not available")
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

	// Check if user already exists
	existingUser, err := h.clerkService.GetUserByEmail(ctx, req.Email)
	if err != nil {
		slog.Error("failed to check for existing user", "error", err, "email", req.Email)
		RespondInternalError(w, r, "Failed to check for existing user")
		return
	}

	isNewUser := existingUser == nil
	var newUserID string
	userName := req.Name
	if userName == "" {
		userName = req.Email // Fallback to email if no name provided
	}

	if existingUser != nil {
		// User exists - check if they already have access
		newUserID = existingUser.ID
		metadata, _ := h.clerkService.GetUserPublicMetadata(ctx, existingUser.ID)
		if accessList, ok := metadata["publisher_access_list"].([]interface{}); ok {
			for _, id := range accessList {
				if idStr, ok := id.(string); ok && idStr == publisherID {
					RespondConflict(w, r, "User already has access to this publisher")
					return
				}
			}
		}

		// Add publisher to their access list
		if err := h.clerkService.AddPublisherToUser(ctx, existingUser.ID, publisherID); err != nil {
			slog.Error("failed to add publisher to user", "error", err, "user_id", existingUser.ID, "publisher_id", publisherID)
			RespondInternalError(w, r, "Failed to add user to team")
			return
		}

		// Get existing user's name for email
		if existingUser.FirstName != nil {
			userName = *existingUser.FirstName
		}

		slog.Info("publisher access added to existing user",
			"email", req.Email,
			"user_id", existingUser.ID,
			"publisher_id", publisherID,
			"added_by", userID)
	} else {
		// User doesn't exist - create directly (no invitation)
		newUser, err := h.clerkService.CreatePublisherUserDirectly(ctx, req.Email, userName, publisherID)
		if err != nil {
			slog.Error("failed to create user", "error", err, "email", req.Email, "publisher_id", publisherID)
			RespondInternalError(w, r, "Failed to create user")
			return
		}
		newUserID = newUser.ID

		slog.Info("user created and added to publisher team",
			"email", req.Email,
			"user_id", newUser.ID,
			"publisher_id", publisherID,
			"added_by", userID)
	}

	// Send email notification
	if h.emailService != nil {
		go func() {
			if err := h.emailService.SendUserAddedToPublisher(req.Email, userName, publisherName, inviterName, isNewUser); err != nil {
				slog.Error("failed to send team member added email",
					"error", err,
					"email", req.Email,
					"publisher_id", publisherID)
			}
		}()
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success":     true,
		"message":     "Team member added",
		"user_id":     newUserID,
		"is_new_user": isNewUser,
	})
}

// InvitePublisherTeamMember is an alias for AddPublisherTeamMember for backward compatibility
// POST /api/publisher/team/invite
// Deprecated: Use AddPublisherTeamMember instead
func (h *Handlers) InvitePublisherTeamMember(w http.ResponseWriter, r *http.Request) {
	h.AddPublisherTeamMember(w, r)
}

// RemovePublisherTeamMember removes a team member
// DELETE /api/publisher/team/{userId}
// If this is the user's last role (no admin, no other publishers), the user is deleted
func (h *Handlers) RemovePublisherTeamMember(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID
	currentUserID := pc.UserID

	memberUserID := chi.URLParam(r, "userId")
	if memberUserID == "" {
		RespondValidationError(w, r, "User ID is required", nil)
		return
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

	// Get user email before potential deletion (for logging)
	var email string
	if user, err := h.clerkService.GetUser(ctx, memberUserID); err == nil && len(user.EmailAddresses) > 0 {
		email = user.EmailAddresses[0].EmailAddress
	}

	// Remove publisher and check if user should be deleted
	userDeleted, err := h.clerkService.RemovePublisherFromUserAndCleanup(ctx, memberUserID, publisherID)
	if err != nil {
		slog.Error("failed to remove publisher from user", "error", err)
		RespondInternalError(w, r, "Failed to remove team member")
		return
	}

	if userDeleted {
		slog.Info("team member removed and user deleted (no remaining roles)",
			"publisher_id", publisherID,
			"removed_user", memberUserID,
			"removed_by", currentUserID,
			"email", email)

		RespondJSON(w, r, http.StatusOK, map[string]interface{}{
			"success":      true,
			"message":      "Member removed and user deleted (no remaining roles)",
			"user_deleted": true,
		})
	} else {
		slog.Info("team member removed",
			"publisher_id", publisherID,
			"removed_user", memberUserID,
			"removed_by", currentUserID,
			"email", email)

		RespondJSON(w, r, http.StatusOK, map[string]interface{}{
			"success":      true,
			"message":      "Member removed",
			"user_deleted": false,
		})
	}
}

// ResendPublisherInvitation resends an invitation email
// POST /api/publisher/team/invitations/{id}/resend
func (h *Handlers) ResendPublisherInvitation(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	userID := pc.UserID

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
	_ = h.db.Pool.QueryRow(ctx, "SELECT name FROM publishers WHERE id = $1", publisherID).Scan(&publisherName)

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
		go func() { _ = h.emailService.SendInvitation(email, inviterName, publisherName, acceptURL) }()
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

	// Use PublisherResolver to get publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	userID := pc.UserID

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

	// Use PublisherResolver to get user context (optional publisher)
	pc := h.publisherResolver.ResolveOptional(ctx, r)
	if pc == nil || pc.UserID == "" {
		RespondUnauthorized(w, r, "Please sign in to accept this invitation")
		return
	}
	userID := pc.UserID

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
		_, _ = h.db.Pool.Exec(ctx, "UPDATE publisher_invitations SET status = 'expired' WHERE id = $1", invitation.ID)
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
