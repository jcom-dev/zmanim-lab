package models

import (
	"time"

	"github.com/jackc/pgx/v5/pgtype"
)

// Publisher represents a zmanim calculation publisher
type Publisher struct {
	ID              string             `json:"id"`
	ClerkUserID     *string            `json:"clerk_user_id,omitempty"`
	Name            string             `json:"name"`
	Organization    *string            `json:"organization,omitempty"`
	Email           string             `json:"email"`
	Description     string             `json:"description"`
	Bio             *string            `json:"bio,omitempty"`
	Website         *string            `json:"website,omitempty"`
	ContactEmail    string             `json:"contact_email"`
	LogoURL         *string            `json:"logo_url,omitempty"`
	Status          string             `json:"status"`
	IsVerified      bool               `json:"is_verified"`
	SubscriberCount int                `json:"subscriber_count"`
	CreatedAt       time.Time          `json:"created_at"`
	UpdatedAt       time.Time          `json:"updated_at"`
}

// Algorithm represents a calculation algorithm
type Algorithm struct {
	ID            string    `json:"id"`
	PublisherID   string    `json:"publisher_id"`
	Name          string    `json:"name"`
	Description   string    `json:"description"`
	Version       string    `json:"version"`
	Configuration pgtype.Map `json:"configuration"`
	IsActive      bool      `json:"is_active"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// GeographicRegion represents a geographic region
type GeographicRegion struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Type        string    `json:"type"` // country, state, city, custom
	CountryCode *string   `json:"country_code,omitempty"`
	StateCode   *string   `json:"state_code,omitempty"`
	Bounds      *string   `json:"bounds,omitempty"` // GeoJSON polygon
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// City represents a city in the global cities database
type City struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Country     string   `json:"country"`
	CountryCode string   `json:"country_code"`
	Region      *string  `json:"region,omitempty"`
	RegionType  *string  `json:"region_type,omitempty"`
	Latitude    float64  `json:"latitude"`
	Longitude   float64  `json:"longitude"`
	Timezone    string   `json:"timezone"`
	Population  *int     `json:"population,omitempty"`
	// Computed display field
	DisplayName string `json:"display_name"`
}

// CitySearchResponse represents the response for city search
type CitySearchResponse struct {
	Cities []City `json:"cities"`
	Total  int    `json:"total"`
}

// CoverageArea represents a publisher's coverage area
type CoverageArea struct {
	ID          string    `json:"id"`
	PublisherID string    `json:"publisher_id"`
	RegionID    string    `json:"region_id"`
	AlgorithmID string    `json:"algorithm_id"`
	Priority    int       `json:"priority"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// UserProfile represents a user profile
type UserProfile struct {
	ID               string     `json:"id"`
	Email            string     `json:"email"`
	FullName         *string    `json:"full_name,omitempty"`
	PreferredRegion  *string    `json:"preferred_region,omitempty"`
	DefaultPublisher *string    `json:"default_publisher,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

// UserSubscription represents a user's subscription to a publisher
type UserSubscription struct {
	ID          string    `json:"id"`
	UserID      string    `json:"user_id"`
	PublisherID string    `json:"publisher_id"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// CalculationCache represents cached zmanim calculations
type CalculationCache struct {
	ID            string         `json:"id"`
	Date          time.Time      `json:"date"`
	Latitude      float64        `json:"latitude"`
	Longitude     float64        `json:"longitude"`
	AlgorithmID   string         `json:"algorithm_id"`
	Results       pgtype.Map     `json:"results"`
	ExpiresAt     time.Time      `json:"expires_at"`
	CreatedAt     time.Time      `json:"created_at"`
}

// AuditLog represents an audit log entry
type AuditLog struct {
	ID          string         `json:"id"`
	UserID      *string        `json:"user_id,omitempty"`
	Action      string         `json:"action"`
	EntityType  string         `json:"entity_type"`
	EntityID    string         `json:"entity_id"`
	OldValues   *pgtype.Map    `json:"old_values,omitempty"`
	NewValues   *pgtype.Map    `json:"new_values,omitempty"`
	IPAddress   *string        `json:"ip_address,omitempty"`
	UserAgent   *string        `json:"user_agent,omitempty"`
	CreatedAt   time.Time      `json:"created_at"`
}

// Location represents a geographic location for zmanim calculations
type Location struct {
	Name      string  `json:"name"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Timezone  string  `json:"timezone"`
	Elevation *int    `json:"elevation,omitempty"`
}

// ZmanimRequest represents a request for zmanim calculations
type ZmanimRequest struct {
	Date        string   `json:"date"` // YYYY-MM-DD format
	Latitude    float64  `json:"latitude"`
	Longitude   float64  `json:"longitude"`
	Timezone    string   `json:"timezone"`
	PublisherID *string  `json:"publisher_id,omitempty"`
	Elevation   *int     `json:"elevation,omitempty"`
}

// ZmanimResponse represents the response containing calculated zmanim
type ZmanimResponse struct {
	Date         string            `json:"date"`
	Location     Location          `json:"location"`
	Publisher    *Publisher        `json:"publisher,omitempty"`
	Algorithm    *Algorithm        `json:"algorithm,omitempty"`
	Zmanim       map[string]string `json:"zmanim"`
	CachedAt     *time.Time        `json:"cached_at,omitempty"`
	CalculatedAt time.Time         `json:"calculated_at"`
}

// PublisherListResponse represents a list of publishers with pagination
type PublisherListResponse struct {
	Publishers []Publisher `json:"publishers"`
	Total      int         `json:"total"`
	Page       int         `json:"page"`
	PageSize   int         `json:"page_size"`
}

// PublisherProfileUpdateRequest represents a request to update publisher profile
type PublisherProfileUpdateRequest struct {
	Name         *string `json:"name,omitempty"`
	Organization *string `json:"organization,omitempty"`
	Email        *string `json:"email,omitempty"`
	Website      *string `json:"website,omitempty"`
	Bio          *string `json:"bio,omitempty"`
}

// ErrorResponse represents an API error response
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
	Code    int    `json:"code"`
}

// HealthResponse represents a health check response
type HealthResponse struct {
	Status   string `json:"status"`
	Database string `json:"database"`
	Version  string `json:"version"`
}
