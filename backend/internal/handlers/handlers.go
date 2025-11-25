package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jcom-dev/zmanim-lab/internal/db"
	"github.com/jcom-dev/zmanim-lab/internal/models"
	"github.com/jcom-dev/zmanim-lab/internal/services"
)

// Handlers holds all HTTP handlers
type Handlers struct {
	db               *db.DB
	publisherService *services.PublisherService
	zmanimService    *services.ZmanimService
}

// New creates a new handlers instance
func New(database *db.DB) *Handlers {
	publisherService := services.NewPublisherService(database)
	zmanimService := services.NewZmanimService(database, publisherService)

	return &Handlers{
		db:               database,
		publisherService: publisherService,
		zmanimService:    zmanimService,
	}
}

// HealthCheck returns the health status of the API
func (h *Handlers) HealthCheck(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Check database health
	dbStatus := "ok"
	if err := h.db.Health(ctx); err != nil {
		dbStatus = "error: " + err.Error()
		w.WriteHeader(http.StatusServiceUnavailable)
	}

	response := models.HealthResponse{
		Status:   "ok",
		Database: dbStatus,
		Version:  "1.0.0",
	}

	respondJSON(w, http.StatusOK, response)
}

// GetPublishers returns a list of publishers
func (h *Handlers) GetPublishers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Parse query parameters
	page := 1
	pageSize := 20
	regionID := r.URL.Query().Get("region_id")

	if p := r.URL.Query().Get("page"); p != "" {
		if parsed, err := parseIntParam(p); err == nil && parsed > 0 {
			page = parsed
		}
	}

	if ps := r.URL.Query().Get("page_size"); ps != "" {
		if parsed, err := parseIntParam(ps); err == nil && parsed > 0 && parsed <= 100 {
			pageSize = parsed
		}
	}

	var regionPtr *string
	if regionID != "" {
		regionPtr = &regionID
	}

	publishers, err := h.publisherService.GetPublishers(ctx, page, pageSize, regionPtr)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get publishers", err)
		return
	}

	respondJSON(w, http.StatusOK, publishers)
}

// GetPublisher returns a single publisher by ID
func (h *Handlers) GetPublisher(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := chi.URLParam(r, "id")

	if id == "" {
		respondError(w, http.StatusBadRequest, "Publisher ID is required", nil)
		return
	}

	publisher, err := h.publisherService.GetPublisherByID(ctx, id)
	if err != nil {
		respondError(w, http.StatusNotFound, "Publisher not found", err)
		return
	}

	respondJSON(w, http.StatusOK, publisher)
}

// CalculateZmanim calculates zmanim for a given location and date
func (h *Handlers) CalculateZmanim(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req models.ZmanimRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	// Validate request
	if req.Date == "" {
		respondError(w, http.StatusBadRequest, "Date is required", nil)
		return
	}
	if req.Latitude < -90 || req.Latitude > 90 {
		respondError(w, http.StatusBadRequest, "Invalid latitude", nil)
		return
	}
	if req.Longitude < -180 || req.Longitude > 180 {
		respondError(w, http.StatusBadRequest, "Invalid longitude", nil)
		return
	}
	if req.Timezone == "" {
		req.Timezone = "UTC"
	}

	response, err := h.zmanimService.CalculateZmanim(ctx, &req)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to calculate zmanim", err)
		return
	}

	respondJSON(w, http.StatusOK, response)
}

// GetLocations returns a list of predefined locations
func (h *Handlers) GetLocations(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Query geographic regions as locations
	query := `
		SELECT id, name,
		       ST_Y(ST_Centroid(bounds::geometry)) as latitude,
		       ST_X(ST_Centroid(bounds::geometry)) as longitude
		FROM geographic_regions
		WHERE type = 'city'
		ORDER BY name
		LIMIT 100
	`

	rows, err := h.db.Pool.Query(ctx, query)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get locations", err)
		return
	}
	defer rows.Close()

	var locations []map[string]interface{}
	for rows.Next() {
		var id, name string
		var latitude, longitude float64
		if err := rows.Scan(&id, &name, &latitude, &longitude); err != nil {
			continue
		}
		locations = append(locations, map[string]interface{}{
			"id":        id,
			"name":      name,
			"latitude":  latitude,
			"longitude": longitude,
			"timezone":  "UTC", // In production, derive from location
		})
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"locations": locations,
		"total":     len(locations),
	})
}

// Helper functions

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
	}
}

func respondError(w http.ResponseWriter, status int, message string, err error) {
	errorMsg := message
	if err != nil {
		errorMsg = message + ": " + err.Error()
	}

	response := models.ErrorResponse{
		Error:   http.StatusText(status),
		Message: errorMsg,
		Code:    status,
	}

	respondJSON(w, status, response)
}

func parseIntParam(s string) (int, error) {
	var i int
	err := json.Unmarshal([]byte(s), &i)
	return i, err
}
