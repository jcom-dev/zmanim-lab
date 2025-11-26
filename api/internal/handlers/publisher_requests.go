package handlers

import (
	"crypto/rand"
	"encoding/base64"
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

// PublisherRequest represents a publisher registration request
type PublisherRequest struct {
	ID              string     `json:"id"`
	Name            string     `json:"name"`
	Organization    string     `json:"organization"`
	Email           string     `json:"email"`
	Website         *string    `json:"website,omitempty"`
	Description     string     `json:"description"`
	Status          string     `json:"status"`
	RejectionReason *string    `json:"rejection_reason,omitempty"`
	ReviewedBy      *string    `json:"reviewed_by,omitempty"`
	ReviewedAt      *time.Time `json:"reviewed_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

// SubmitPublisherRequest handles public publisher registration requests
// POST /api/publisher-requests
func (h *Handlers) SubmitPublisherRequest(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req struct {
		Name         string  `json:"name"`
		Organization string  `json:"organization"`
		Email        string  `json:"email"`
		Website      *string `json:"website"`
		Description  string  `json:"description"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	// Validate required fields
	validationErrors := make(map[string]string)
	if strings.TrimSpace(req.Name) == "" {
		validationErrors["name"] = "Name is required"
	}
	if strings.TrimSpace(req.Organization) == "" {
		validationErrors["organization"] = "Organization is required"
	}
	if strings.TrimSpace(req.Email) == "" {
		validationErrors["email"] = "Email is required"
	} else if !isValidEmail(req.Email) {
		validationErrors["email"] = "Invalid email format"
	}
	if strings.TrimSpace(req.Description) == "" {
		validationErrors["description"] = "Description is required"
	}

	if len(validationErrors) > 0 {
		RespondValidationError(w, r, "Invalid request parameters", validationErrors)
		return
	}

	// Check for duplicate pending/approved requests
	var existingCount int
	err := h.db.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM publisher_requests
		WHERE LOWER(email) = LOWER($1) AND status IN ('pending', 'approved')
	`, req.Email).Scan(&existingCount)

	if err != nil {
		slog.Error("failed to check for existing requests", "error", err)
		RespondInternalError(w, r, "Failed to process request")
		return
	}

	if existingCount > 0 {
		RespondConflict(w, r, "A request for this email is already pending or has been processed")
		return
	}

	// Insert the request
	query := `
		INSERT INTO publisher_requests (name, organization, email, website, description, status)
		VALUES ($1, $2, $3, $4, $5, 'pending')
		RETURNING id, created_at
	`

	var id string
	var createdAt time.Time
	err = h.db.Pool.QueryRow(ctx, query,
		strings.TrimSpace(req.Name),
		strings.TrimSpace(req.Organization),
		strings.ToLower(strings.TrimSpace(req.Email)),
		req.Website,
		strings.TrimSpace(req.Description),
	).Scan(&id, &createdAt)

	if err != nil {
		slog.Error("failed to create publisher request", "error", err)
		RespondInternalError(w, r, "Failed to submit request")
		return
	}

	slog.Info("publisher request submitted",
		"id", id,
		"email", req.Email,
		"organization", req.Organization)

	// Send confirmation email to applicant (non-blocking)
	if h.emailService != nil {
		go h.emailService.SendPublisherRequestReceived(
			req.Email,
			strings.TrimSpace(req.Name),
			strings.TrimSpace(req.Organization),
		)

		// Send notification to admin (if ADMIN_EMAIL is configured)
		adminEmail := os.Getenv("ADMIN_EMAIL")
		if adminEmail != "" {
			webURL := os.Getenv("WEB_URL")
			if webURL == "" {
				webURL = "http://localhost:3001"
			}
			adminURL := fmt.Sprintf("%s/admin/publishers", webURL)
			go h.emailService.SendAdminNewPublisherRequest(
				adminEmail,
				strings.TrimSpace(req.Name),
				strings.TrimSpace(req.Organization),
				req.Email,
				strings.TrimSpace(req.Description),
				adminURL,
			)
		}
	}

	RespondJSON(w, r, http.StatusCreated, map[string]interface{}{
		"success": true,
		"message": "Thank you! Your request has been submitted. We'll review it and get back to you soon.",
		"id":      id,
	})
}

// AdminGetPublisherRequests returns pending publisher requests
// GET /api/admin/publisher-requests
func (h *Handlers) AdminGetPublisherRequests(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	status := r.URL.Query().Get("status")
	if status == "" {
		status = "pending"
	}

	query := `
		SELECT id, name, organization, email, website, description, status,
		       rejection_reason, reviewed_by, reviewed_at, created_at
		FROM publisher_requests
		WHERE status = $1
		ORDER BY created_at DESC
	`

	rows, err := h.db.Pool.Query(ctx, query, status)
	if err != nil {
		slog.Error("failed to query publisher requests", "error", err)
		RespondInternalError(w, r, "Failed to retrieve requests")
		return
	}
	defer rows.Close()

	requests := make([]PublisherRequest, 0)
	for rows.Next() {
		var req PublisherRequest
		err := rows.Scan(
			&req.ID, &req.Name, &req.Organization, &req.Email, &req.Website,
			&req.Description, &req.Status, &req.RejectionReason, &req.ReviewedBy,
			&req.ReviewedAt, &req.CreatedAt,
		)
		if err != nil {
			slog.Error("failed to scan publisher request row", "error", err)
			continue
		}
		requests = append(requests, req)
	}

	// Get counts for all statuses
	var pendingCount, approvedCount, rejectedCount int
	h.db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM publisher_requests WHERE status = 'pending'").Scan(&pendingCount)
	h.db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM publisher_requests WHERE status = 'approved'").Scan(&approvedCount)
	h.db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM publisher_requests WHERE status = 'rejected'").Scan(&rejectedCount)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"data": requests,
		"meta": map[string]int{
			"total":    len(requests),
			"pending":  pendingCount,
			"approved": approvedCount,
			"rejected": rejectedCount,
		},
	})
}

// AdminApprovePublisherRequest approves a publisher request
// POST /api/admin/publisher-requests/{id}/approve
func (h *Handlers) AdminApprovePublisherRequest(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	requestID := chi.URLParam(r, "id")

	if requestID == "" {
		RespondValidationError(w, r, "Request ID is required", nil)
		return
	}

	// Get admin user ID from context
	adminUserID, _ := ctx.Value("user_id").(string)

	// Get the request details
	var req PublisherRequest
	err := h.db.Pool.QueryRow(ctx, `
		SELECT id, name, organization, email, website, description, status
		FROM publisher_requests WHERE id = $1
	`, requestID).Scan(&req.ID, &req.Name, &req.Organization, &req.Email,
		&req.Website, &req.Description, &req.Status)

	if err != nil {
		if err == pgx.ErrNoRows {
			RespondNotFound(w, r, "Request not found")
			return
		}
		slog.Error("failed to get publisher request", "error", err)
		RespondInternalError(w, r, "Failed to retrieve request")
		return
	}

	if req.Status != "pending" {
		RespondBadRequest(w, r, fmt.Sprintf("Request is already %s", req.Status))
		return
	}

	// Start transaction
	tx, err := h.db.Pool.Begin(ctx)
	if err != nil {
		slog.Error("failed to start transaction", "error", err)
		RespondInternalError(w, r, "Failed to process request")
		return
	}
	defer tx.Rollback(ctx)

	// Create the publisher
	slug := generateSlug(req.Organization)
	var publisherID string
	err = tx.QueryRow(ctx, `
		INSERT INTO publishers (name, organization, slug, email, description, status)
		VALUES ($1, $2, $3, $4, $5, 'pending_verification')
		RETURNING id
	`, req.Name, req.Organization, slug, req.Email, req.Description).Scan(&publisherID)

	if err != nil {
		slog.Error("failed to create publisher", "error", err)
		RespondInternalError(w, r, "Failed to create publisher")
		return
	}

	// Update request status
	_, err = tx.Exec(ctx, `
		UPDATE publisher_requests
		SET status = 'approved', reviewed_by = $1, reviewed_at = NOW()
		WHERE id = $2
	`, adminUserID, requestID)

	if err != nil {
		slog.Error("failed to update request status", "error", err)
		RespondInternalError(w, r, "Failed to update request")
		return
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		slog.Error("failed to commit transaction", "error", err)
		RespondInternalError(w, r, "Failed to process request")
		return
	}

	// Send approval email (non-blocking)
	if h.emailService != nil {
		webURL := os.Getenv("WEB_URL")
		if webURL == "" {
			webURL = "http://localhost:3001"
		}
		dashboardURL := fmt.Sprintf("%s/publisher", webURL)
		go h.emailService.SendPublisherApproved(req.Email, req.Name, dashboardURL)
	}

	slog.Info("publisher request approved",
		"request_id", requestID,
		"publisher_id", publisherID,
		"admin", adminUserID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success":      true,
		"publisher_id": publisherID,
		"message":      "Publisher account created and welcome email sent",
	})
}

// AdminRejectPublisherRequest rejects a publisher request
// POST /api/admin/publisher-requests/{id}/reject
func (h *Handlers) AdminRejectPublisherRequest(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	requestID := chi.URLParam(r, "id")

	if requestID == "" {
		RespondValidationError(w, r, "Request ID is required", nil)
		return
	}

	var reqBody struct {
		Reason string `json:"reason"`
	}
	json.NewDecoder(r.Body).Decode(&reqBody)

	// Get admin user ID from context
	adminUserID, _ := ctx.Value("user_id").(string)

	// Get the request details first
	var req PublisherRequest
	err := h.db.Pool.QueryRow(ctx, `
		SELECT id, name, organization, email, status
		FROM publisher_requests WHERE id = $1
	`, requestID).Scan(&req.ID, &req.Name, &req.Organization, &req.Email, &req.Status)

	if err != nil {
		if err == pgx.ErrNoRows {
			RespondNotFound(w, r, "Request not found")
			return
		}
		slog.Error("failed to get publisher request", "error", err)
		RespondInternalError(w, r, "Failed to retrieve request")
		return
	}

	if req.Status != "pending" {
		RespondBadRequest(w, r, fmt.Sprintf("Request is already %s", req.Status))
		return
	}

	// Update request status
	var rejectionReason *string
	if reqBody.Reason != "" {
		rejectionReason = &reqBody.Reason
	}

	_, err = h.db.Pool.Exec(ctx, `
		UPDATE publisher_requests
		SET status = 'rejected', rejection_reason = $1, reviewed_by = $2, reviewed_at = NOW()
		WHERE id = $3
	`, rejectionReason, adminUserID, requestID)

	if err != nil {
		slog.Error("failed to reject publisher request", "error", err)
		RespondInternalError(w, r, "Failed to reject request")
		return
	}

	// Send rejection email (non-blocking)
	if h.emailService != nil {
		reason := "Your application did not meet our current requirements."
		if reqBody.Reason != "" {
			reason = reqBody.Reason
		}
		go h.emailService.SendPublisherRejected(req.Email, req.Name, reason)
	}

	slog.Info("publisher request rejected",
		"request_id", requestID,
		"reason", reqBody.Reason,
		"admin", adminUserID)

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Request rejected",
	})
}

// Helper function to validate email format
func isValidEmail(email string) bool {
	// Basic validation - contains @ and at least one dot after @
	atIndex := strings.Index(email, "@")
	if atIndex < 1 {
		return false
	}
	dotIndex := strings.LastIndex(email[atIndex:], ".")
	return dotIndex > 1 && dotIndex < len(email[atIndex:])-1
}

// generateSecureToken generates a cryptographically secure random token
func generateSecureToken() (string, error) {
	b := make([]byte, 32)
	_, err := rand.Read(b)
	if err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(b), nil
}
