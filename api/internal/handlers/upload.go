package handlers

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/google/uuid"
)

const (
	maxUploadSize = 5 * 1024 * 1024 // 5MB
	storageBucket = "publisher-logos"
)

var allowedMimeTypes = map[string]bool{
	"image/jpeg": true,
	"image/jpg":  true,
	"image/png":  true,
	"image/webp": true,
}

// UploadPublisherLogo handles logo upload for publishers
func (h *Handlers) UploadPublisherLogo(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Get user ID from context
	userID, ok := ctx.Value("user_id").(string)
	if !ok || userID == "" {
		RespondUnauthorized(w, r, "User ID not found in context")
		return
	}

	// Get publisher ID from database
	query := `SELECT id FROM publishers WHERE clerk_user_id = $1`
	var publisherID string
	err := h.db.Pool.QueryRow(ctx, query, userID).Scan(&publisherID)
	if err != nil {
		RespondNotFound(w, r, "Publisher profile not found")
		return
	}

	// Parse multipart form
	err = r.ParseMultipartForm(maxUploadSize)
	if err != nil {
		RespondBadRequest(w, r, "File too large or invalid form data")
		return
	}

	// Get file from form
	file, header, err := r.FormFile("logo")
	if err != nil {
		RespondBadRequest(w, r, "No file provided")
		return
	}
	defer file.Close()

	// Validate file size
	if header.Size > maxUploadSize {
		RespondBadRequest(w, r, "File size exceeds 5MB limit")
		return
	}

	// Validate file type
	contentType := header.Header.Get("Content-Type")
	if !allowedMimeTypes[contentType] {
		RespondBadRequest(w, r, "Invalid file type. Only JPEG, PNG, and WebP are allowed")
		return
	}

	// Generate unique filename
	ext := filepath.Ext(header.Filename)
	if ext == "" {
		// Determine extension from content type
		switch contentType {
		case "image/jpeg", "image/jpg":
			ext = ".jpg"
		case "image/png":
			ext = ".png"
		case "image/webp":
			ext = ".webp"
		}
	}
	filename := fmt.Sprintf("%s-%s%s", publisherID, uuid.New().String(), ext)

	// Read file content
	fileBytes, err := io.ReadAll(file)
	if err != nil {
		RespondInternalError(w, r, "Failed to read file")
		return
	}

	// Upload to Supabase Storage
	logoURL, err := h.uploadToSupabaseStorage(ctx, filename, contentType, fileBytes)
	if err != nil {
		RespondInternalError(w, r, fmt.Sprintf("Failed to upload file: %v", err))
		return
	}

	// Update publisher's logo_url in database
	updateQuery := `
		UPDATE publishers
		SET logo_url = $1, updated_at = NOW()
		WHERE clerk_user_id = $2
		RETURNING logo_url
	`
	var updatedLogoURL string
	err = h.db.Pool.QueryRow(ctx, updateQuery, logoURL, userID).Scan(&updatedLogoURL)
	if err != nil {
		RespondInternalError(w, r, "Failed to update publisher profile")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"logo_url": updatedLogoURL,
		"message":  "Logo uploaded successfully",
	})
}

// uploadToSupabaseStorage uploads a file to Supabase Storage
func (h *Handlers) uploadToSupabaseStorage(ctx context.Context, filename, contentType string, fileBytes []byte) (string, error) {
	// For now, use environment variables directly
	// TODO: Pass config through handlers struct for better testability
	supabaseURL := os.Getenv("SUPABASE_URL")
	serviceKey := os.Getenv("SUPABASE_SERVICE_KEY")

	if supabaseURL == "" || serviceKey == "" {
		return "", fmt.Errorf("Supabase configuration missing")
	}

	// Supabase Storage API endpoint
	url := fmt.Sprintf("%s/storage/v1/object/%s/%s", supabaseURL, storageBucket, filename)

	// Create request
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(fileBytes))
	if err != nil {
		return "", err
	}

	// Set headers
	req.Header.Set("Authorization", "Bearer "+serviceKey)
	req.Header.Set("Content-Type", contentType)

	// Send request
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// Check response
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("Supabase Storage error: %s (status: %d)", string(body), resp.StatusCode)
	}

	// Construct public URL
	publicURL := fmt.Sprintf("%s/storage/v1/object/public/%s/%s", supabaseURL, storageBucket, filename)

	return publicURL, nil
}
