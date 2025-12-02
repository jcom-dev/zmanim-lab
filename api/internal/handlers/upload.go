package handlers

import (
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
)

const (
	maxUploadSize = 5 * 1024 * 1024 // 5MB
)

var allowedMimeTypes = map[string]bool{
	"image/jpeg": true,
	"image/jpg":  true,
	"image/png":  true,
	"image/webp": true,
}

// UploadPublisherLogo handles logo upload for publishers
// Stores logo as base64 data URL directly in the database
func (h *Handlers) UploadPublisherLogo(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Step 1: Resolve publisher context
	pc := h.publisherResolver.MustResolve(w, r)
	if pc == nil {
		return // Response already sent
	}
	publisherID := pc.PublisherID

	// Parse multipart form
	err := r.ParseMultipartForm(maxUploadSize)
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

	// Read file content
	fileBytes, err := io.ReadAll(file)
	if err != nil {
		RespondInternalError(w, r, "Failed to read file")
		return
	}

	// Convert to base64 data URL
	base64Data := base64.StdEncoding.EncodeToString(fileBytes)
	dataURL := fmt.Sprintf("data:%s;base64,%s", contentType, base64Data)

	// Update publisher's logo_data in database
	updateQuery := `
		UPDATE publishers
		SET logo_data = $1, updated_at = NOW()
		WHERE id = $2
		RETURNING logo_data
	`
	var updatedLogoData string
	err = h.db.Pool.QueryRow(ctx, updateQuery, dataURL, publisherID).Scan(&updatedLogoData)
	if err != nil {
		RespondInternalError(w, r, "Failed to update publisher profile")
		return
	}

	RespondJSON(w, r, http.StatusOK, map[string]interface{}{
		"logo_data": updatedLogoData,
		"message":   "Logo uploaded successfully",
	})
}
