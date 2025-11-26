package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/jcom-dev/zmanim-lab/internal/config"
	"github.com/jcom-dev/zmanim-lab/internal/db"
	"github.com/jcom-dev/zmanim-lab/internal/handlers"
	custommw "github.com/jcom-dev/zmanim-lab/internal/middleware"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize database connection
	database, err := db.New(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()

	log.Println("Database connection established")

	// Initialize handlers
	h := handlers.New(database)

	// Setup router
	r := chi.NewRouter()

	// Apply middleware
	r.Use(middleware.RequestID)
	r.Use(custommw.RealIP)
	r.Use(custommw.Logger)
	r.Use(custommw.Recoverer)
	r.Use(custommw.Timeout(30 * time.Second))
	r.Use(custommw.SecurityHeaders)

	// CORS configuration
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   cfg.CORS.AllowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Health check endpoint
	r.Get("/health", h.HealthCheck)

	// Initialize auth middleware
	authMiddleware := custommw.NewAuthMiddleware(cfg.JWT.JWKSUrl, cfg.JWT.Issuer)

	// Initialize rate limiter
	rateLimiter := custommw.NewDefaultRateLimiter()
	defer rateLimiter.Stop()

	// API routes
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(custommw.ContentType("application/json"))

		// Public routes (with optional auth for rate limiting)
		r.Group(func(r chi.Router) {
			r.Use(authMiddleware.OptionalAuth)
			r.Use(rateLimiter.Middleware)

			// Publishers
			r.Get("/publishers", h.GetPublishers)
			r.Get("/publishers/{id}", h.GetPublisher)

			// Locations (legacy)
			r.Get("/locations", h.GetLocations)

			// Cities - Global location system
			r.Get("/cities", h.SearchCities)
			r.Get("/cities/nearby", h.GetNearbyCity)
			r.Get("/cities/{cityId}/publishers", h.GetPublishersForCity)

			// Countries and regions for coverage selection
			r.Get("/countries", h.GetCountries)
			r.Get("/regions", h.GetRegions)

			// Zmanim calculations
			r.Get("/zmanim", h.GetZmanimForCity)      // New: GET with cityId, date, publisherId
			r.Post("/zmanim", h.CalculateZmanim)       // Legacy: POST with coordinates
		})

		// Publisher protected routes
		r.Route("/publisher", func(r chi.Router) {
			r.Use(authMiddleware.RequireRole("publisher"))
			r.Get("/profile", h.GetPublisherProfile)
			r.Put("/profile", h.UpdatePublisherProfile)
			r.Post("/logo", h.UploadPublisherLogo)
			r.Get("/algorithm", h.GetPublisherAlgorithm)
			r.Put("/algorithm", h.UpdatePublisherAlgorithm)
			// Coverage management
			r.Get("/coverage", h.GetPublisherCoverage)
			r.Post("/coverage", h.CreatePublisherCoverage)
			r.Put("/coverage/{id}", h.UpdatePublisherCoverage)
			r.Delete("/coverage/{id}", h.DeletePublisherCoverage)
			// Cache management
			r.Delete("/cache", h.InvalidatePublisherCache)
		})

		// Admin protected routes
		r.Route("/admin", func(r chi.Router) {
			r.Use(authMiddleware.RequireRole("admin"))

			// Publisher management
			r.Get("/publishers", h.AdminListPublishers)
			r.Post("/publishers", h.AdminCreatePublisher)
			r.Put("/publishers/{id}/verify", h.AdminVerifyPublisher)
			r.Put("/publishers/{id}/suspend", h.AdminSuspendPublisher)
			r.Put("/publishers/{id}/reactivate", h.AdminReactivatePublisher)

			// Statistics
			r.Get("/stats", h.AdminGetStats)

			// System configuration
			r.Get("/config", h.AdminGetConfig)
			r.Put("/config", h.AdminUpdateConfig)
		})
	})

	// Create server
	srv := &http.Server{
		Addr:         ":" + cfg.Server.Port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("Starting server on port %s (environment: %s)", cfg.Server.Port, cfg.Server.Environment)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}
