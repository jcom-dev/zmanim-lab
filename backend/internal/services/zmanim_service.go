package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jcom-dev/zmanim-lab/internal/db"
	"github.com/jcom-dev/zmanim-lab/internal/models"
)

// ZmanimService handles zmanim calculation business logic
type ZmanimService struct {
	db               *db.DB
	publisherService *PublisherService
}

// NewZmanimService creates a new zmanim service
func NewZmanimService(database *db.DB, publisherService *PublisherService) *ZmanimService {
	return &ZmanimService{
		db:               database,
		publisherService: publisherService,
	}
}

// CalculateZmanim calculates zmanim for a given request
func (s *ZmanimService) CalculateZmanim(ctx context.Context, req *models.ZmanimRequest) (*models.ZmanimResponse, error) {
	// Parse date
	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		return nil, fmt.Errorf("invalid date format: %w", err)
	}

	// Check cache first
	cached, err := s.getFromCache(ctx, date, req.Latitude, req.Longitude, req.PublisherID)
	if err == nil && cached != nil {
		return cached, nil
	}

	// Get publisher and algorithm
	var publisher *models.Publisher
	var algorithm *models.Algorithm

	if req.PublisherID != nil && *req.PublisherID != "" {
		publisher, err = s.publisherService.GetPublisherByID(ctx, *req.PublisherID)
		if err != nil {
			return nil, fmt.Errorf("failed to get publisher: %w", err)
		}
		// Get algorithm for this publisher
		algorithm, err = s.getAlgorithmForPublisher(ctx, publisher.ID)
		if err != nil {
			return nil, fmt.Errorf("failed to get algorithm: %w", err)
		}
	} else {
		publisher, algorithm, err = s.publisherService.GetPublisherForLocation(ctx, req.Latitude, req.Longitude)
		if err != nil {
			return nil, fmt.Errorf("failed to get publisher for location: %w", err)
		}
	}

	// Calculate zmanim using the algorithm
	zmanim, err := s.calculateWithAlgorithm(ctx, date, req.Latitude, req.Longitude, req.Timezone, algorithm)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate zmanim: %w", err)
	}

	response := &models.ZmanimResponse{
		Date: req.Date,
		Location: models.Location{
			Name:      fmt.Sprintf("%.4f, %.4f", req.Latitude, req.Longitude),
			Latitude:  req.Latitude,
			Longitude: req.Longitude,
			Timezone:  req.Timezone,
			Elevation: req.Elevation,
		},
		Publisher:    publisher,
		Algorithm:    algorithm,
		Zmanim:       zmanim,
		CalculatedAt: time.Now(),
	}

	// Cache the result
	if err := s.cacheResult(ctx, date, req.Latitude, req.Longitude, algorithm.ID, zmanim); err != nil {
		// Log error but don't fail the request
		fmt.Printf("failed to cache result: %v\n", err)
	}

	return response, nil
}

// getFromCache retrieves cached zmanim calculations
func (s *ZmanimService) getFromCache(ctx context.Context, date time.Time, latitude, longitude float64, publisherID *string) (*models.ZmanimResponse, error) {
	query := `
		SELECT cc.results, cc.created_at, cc.algorithm_id,
		       p.id, p.name, p.description, p.website, p.contact_email, p.logo_url,
		       p.is_verified, p.subscriber_count, p.created_at, p.updated_at,
		       a.id, a.name, a.description, a.version, a.configuration, a.is_active
		FROM calculation_cache cc
		INNER JOIN algorithms a ON cc.algorithm_id = a.id
		INNER JOIN publishers p ON a.publisher_id = p.id
		WHERE cc.date = $1
		  AND ABS(cc.latitude - $2) < 0.001
		  AND ABS(cc.longitude - $3) < 0.001
		  AND cc.expires_at > NOW()
	`
	args := []interface{}{date, latitude, longitude}

	if publisherID != nil && *publisherID != "" {
		query += " AND p.id = $4"
		args = append(args, *publisherID)
	}

	query += " ORDER BY cc.created_at DESC LIMIT 1"

	var resultsJSON []byte
	var cachedAt time.Time
	var algorithmID string
	var p models.Publisher
	var a models.Algorithm

	err := s.db.Pool.QueryRow(ctx, query, args...).Scan(
		&resultsJSON, &cachedAt, &algorithmID,
		&p.ID, &p.Name, &p.Description, &p.Website, &p.ContactEmail, &p.LogoURL,
		&p.IsVerified, &p.SubscriberCount, &p.CreatedAt, &p.UpdatedAt,
		&a.ID, &a.Name, &a.Description, &a.Version, &a.Configuration, &a.IsActive,
	)
	if err != nil {
		return nil, err
	}

	var zmanim map[string]string
	if err := json.Unmarshal(resultsJSON, &zmanim); err != nil {
		return nil, err
	}

	a.PublisherID = p.ID

	return &models.ZmanimResponse{
		Date: date.Format("2006-01-02"),
		Location: models.Location{
			Name:      fmt.Sprintf("%.4f, %.4f", latitude, longitude),
			Latitude:  latitude,
			Longitude: longitude,
		},
		Publisher:    &p,
		Algorithm:    &a,
		Zmanim:       zmanim,
		CachedAt:     &cachedAt,
		CalculatedAt: cachedAt,
	}, nil
}

// cacheResult stores calculation results in cache
func (s *ZmanimService) cacheResult(ctx context.Context, date time.Time, latitude, longitude float64, algorithmID string, zmanim map[string]string) error {
	resultsJSON, err := json.Marshal(zmanim)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO calculation_cache (date, latitude, longitude, algorithm_id, results, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (date, latitude, longitude, algorithm_id)
		DO UPDATE SET results = EXCLUDED.results, expires_at = EXCLUDED.expires_at, created_at = NOW()
	`

	expiresAt := time.Now().Add(24 * time.Hour)
	_, err = s.db.Pool.Exec(ctx, query, date, latitude, longitude, algorithmID, resultsJSON, expiresAt)
	return err
}

// calculateWithAlgorithm performs the actual zmanim calculation
func (s *ZmanimService) calculateWithAlgorithm(ctx context.Context, date time.Time, latitude, longitude float64, timezone string, algorithm *models.Algorithm) (map[string]string, error) {
	// This is a placeholder for actual zmanim calculation logic
	// In production, this would use the algorithm configuration to calculate times
	// For now, return sample data

	loc, err := time.LoadLocation(timezone)
	if err != nil {
		loc = time.UTC
	}

	dateInLoc := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, loc)

	// Sample calculation (in production, use actual astronomical calculations)
	return map[string]string{
		"alot_hashachar":      dateInLoc.Add(5*time.Hour + 30*time.Minute).Format("15:04:05"),
		"misheyakir":          dateInLoc.Add(5*time.Hour + 45*time.Minute).Format("15:04:05"),
		"sunrise":             dateInLoc.Add(6*time.Hour + 15*time.Minute).Format("15:04:05"),
		"sof_zman_shma_gra":   dateInLoc.Add(9*time.Hour + 0*time.Minute).Format("15:04:05"),
		"sof_zman_shma_mga":   dateInLoc.Add(8*time.Hour + 45*time.Minute).Format("15:04:05"),
		"sof_zman_tefilla":    dateInLoc.Add(10*time.Hour + 0*time.Minute).Format("15:04:05"),
		"chatzot":             dateInLoc.Add(12*time.Hour + 30*time.Minute).Format("15:04:05"),
		"mincha_gedola":       dateInLoc.Add(13*time.Hour + 0*time.Minute).Format("15:04:05"),
		"mincha_ketana":       dateInLoc.Add(15*time.Hour + 45*time.Minute).Format("15:04:05"),
		"plag_hamincha":       dateInLoc.Add(17*time.Hour + 0*time.Minute).Format("15:04:05"),
		"sunset":              dateInLoc.Add(18*time.Hour + 30*time.Minute).Format("15:04:05"),
		"tzait_hakochavim":    dateInLoc.Add(19*time.Hour + 0*time.Minute).Format("15:04:05"),
		"tzait_72":            dateInLoc.Add(19*time.Hour + 42*time.Minute).Format("15:04:05"),
	}, nil
}

// getAlgorithmForPublisher gets the active algorithm for a publisher
func (s *ZmanimService) getAlgorithmForPublisher(ctx context.Context, publisherID string) (*models.Algorithm, error) {
	query := `
		SELECT id, publisher_id, name, description, version, configuration, is_active, created_at, updated_at
		FROM algorithms
		WHERE publisher_id = $1 AND is_active = true
		ORDER BY created_at DESC
		LIMIT 1
	`

	var a models.Algorithm
	err := s.db.Pool.QueryRow(ctx, query, publisherID).Scan(
		&a.ID, &a.PublisherID, &a.Name, &a.Description, &a.Version,
		&a.Configuration, &a.IsActive, &a.CreatedAt, &a.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get algorithm: %w", err)
	}

	return &a, nil
}
