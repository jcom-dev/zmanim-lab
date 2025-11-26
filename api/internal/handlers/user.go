package handlers

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"
)

// RequestPasswordReset sends a password reset email
// POST /api/user/request-password-reset
func (h *Handlers) RequestPasswordReset(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req struct {
		Email string `json:"email"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondBadRequest(w, r, "Invalid request body")
		return
	}

	if req.Email == "" || !isValidEmail(req.Email) {
		RespondValidationError(w, r, "Valid email is required", nil)
		return
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))

	// Generate a reset token
	token, err := generateSecureToken()
	if err != nil {
		slog.Error("failed to generate password reset token", "error", err)
		RespondInternalError(w, r, "Failed to process request")
		return
	}

	// Store the token (expires in 1 hour)
	expiresAt := time.Now().Add(1 * time.Hour)
	_, err = h.db.Pool.Exec(ctx, `
		INSERT INTO password_reset_tokens (email, token, expires_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (email) DO UPDATE
		SET token = $2, expires_at = $3, created_at = NOW()
	`, email, token, expiresAt)

	if err != nil {
		slog.Error("failed to store password reset token", "error", err)
		// Don't expose database errors - continue with success response
	}

	// Send the email (non-blocking)
	if h.emailService != nil {
		webURL := os.Getenv("WEB_URL")
		if webURL == "" {
			webURL = "http://localhost:3001"
		}
		resetURL := webURL + "/reset-password?token=" + token
		go h.emailService.SendPasswordReset(email, resetURL, "1 hour")
	}

	slog.Info("password reset requested", "email", email)

	// Always return success to prevent email enumeration
	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "If an account exists with this email, a password reset link has been sent",
	})
}

// GetPublisherNames returns publisher names for a list of IDs
// GET /api/publishers/names?ids=id1,id2,id3
func (h *Handlers) GetPublisherNames(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	idsParam := r.URL.Query().Get("ids")
	if idsParam == "" {
		RespondJSON(w, r, http.StatusOK, map[string]interface{}{
			"publishers": []interface{}{},
		})
		return
	}

	ids := strings.Split(idsParam, ",")
	if len(ids) == 0 {
		RespondJSON(w, r, http.StatusOK, map[string]interface{}{
			"publishers": []interface{}{},
		})
		return
	}

	// Query publishers
	rows, err := h.db.Pool.Query(ctx, `
		SELECT id, name FROM publishers WHERE id = ANY($1)
	`, ids)

	if err != nil {
		slog.Error("failed to get publisher names", "error", err)
		RespondInternalError(w, r, "Failed to retrieve publishers")
		return
	}
	defer rows.Close()

	publishers := make([]map[string]string, 0)
	for rows.Next() {
		var id, name string
		if err := rows.Scan(&id, &name); err != nil {
			continue
		}
		publishers = append(publishers, map[string]string{
			"id":   id,
			"name": name,
		})
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"publishers": publishers,
	})
}
