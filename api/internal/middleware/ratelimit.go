package middleware

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// RateLimiterConfig holds rate limiter configuration
type RateLimiterConfig struct {
	AnonymousRequestsPerHour    int
	AuthenticatedRequestsPerHour int
	CleanupInterval             time.Duration
}

// DefaultRateLimiterConfig returns default rate limiter configuration
func DefaultRateLimiterConfig() RateLimiterConfig {
	return RateLimiterConfig{
		AnonymousRequestsPerHour:    100,  // AC: 100 requests/hour for anonymous
		AuthenticatedRequestsPerHour: 1000, // Higher limit for authenticated
		CleanupInterval:             5 * time.Minute,
	}
}

// clientInfo tracks rate limit state for a client
type clientInfo struct {
	count     int
	windowStart time.Time
}

// RateLimiter provides rate limiting functionality
type RateLimiter struct {
	config     RateLimiterConfig
	clients    map[string]*clientInfo
	mutex      sync.RWMutex
	stopCleanup chan struct{}
}

// NewRateLimiter creates a new rate limiter with the given config
func NewRateLimiter(config RateLimiterConfig) *RateLimiter {
	rl := &RateLimiter{
		config:     config,
		clients:    make(map[string]*clientInfo),
		stopCleanup: make(chan struct{}),
	}

	// Start background cleanup goroutine
	go rl.cleanup()

	return rl
}

// cleanup periodically removes expired client entries
func (rl *RateLimiter) cleanup() {
	ticker := time.NewTicker(rl.config.CleanupInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			rl.mutex.Lock()
			now := time.Now()
			for key, info := range rl.clients {
				if now.Sub(info.windowStart) > time.Hour {
					delete(rl.clients, key)
				}
			}
			rl.mutex.Unlock()
		case <-rl.stopCleanup:
			return
		}
	}
}

// Stop stops the cleanup goroutine
func (rl *RateLimiter) Stop() {
	close(rl.stopCleanup)
}

// getClientKey returns a unique key for the client
func (rl *RateLimiter) getClientKey(r *http.Request) string {
	// Check if user is authenticated
	if userID := GetUserID(r.Context()); userID != "" {
		return "user:" + userID
	}

	// Use IP address for anonymous users
	ip := r.Header.Get("X-Forwarded-For")
	if ip == "" {
		ip = r.Header.Get("X-Real-IP")
	}
	if ip == "" {
		ip = r.RemoteAddr
	}
	return "ip:" + ip
}

// getLimit returns the rate limit for the client
func (rl *RateLimiter) getLimit(r *http.Request) int {
	if userID := GetUserID(r.Context()); userID != "" {
		return rl.config.AuthenticatedRequestsPerHour
	}
	return rl.config.AnonymousRequestsPerHour
}

// isAllowed checks if the request is within rate limits
func (rl *RateLimiter) isAllowed(r *http.Request) (allowed bool, remaining int, resetSeconds int) {
	key := rl.getClientKey(r)
	limit := rl.getLimit(r)
	now := time.Now()

	rl.mutex.Lock()
	defer rl.mutex.Unlock()

	info, exists := rl.clients[key]
	if !exists || now.Sub(info.windowStart) > time.Hour {
		// New window
		rl.clients[key] = &clientInfo{
			count:     1,
			windowStart: now,
		}
		return true, limit - 1, 3600
	}

	// Calculate time until reset
	elapsed := now.Sub(info.windowStart)
	resetSeconds = int((time.Hour - elapsed).Seconds())
	if resetSeconds < 0 {
		resetSeconds = 0
	}

	if info.count >= limit {
		return false, 0, resetSeconds
	}

	info.count++
	return true, limit - info.count, resetSeconds
}

// Middleware returns the rate limiting middleware handler
func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		allowed, remaining, resetSeconds := rl.isAllowed(r)

		// Add rate limit headers
		limit := rl.getLimit(r)
		w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%d", limit))
		w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
		w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetSeconds))

		if !allowed {
			w.Header().Set("Retry-After", fmt.Sprintf("%d", resetSeconds))
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"error": map[string]interface{}{
					"code":    "RATE_LIMITED",
					"message": "Rate limit exceeded. Please try again later.",
					"details": map[string]interface{}{
						"limit":               limit,
						"retry_after_seconds": resetSeconds,
					},
				},
			})
			return
		}

		next.ServeHTTP(w, r)
	})
}

// NewDefaultRateLimiter creates a rate limiter with default configuration
func NewDefaultRateLimiter() *RateLimiter {
	return NewRateLimiter(DefaultRateLimiterConfig())
}
