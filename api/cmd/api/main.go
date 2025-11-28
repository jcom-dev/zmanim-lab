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
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token", "X-Publisher-Id"},
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
			r.Get("/publishers/names", h.GetPublisherNames)

			// Publisher registration requests (public)
			r.Post("/publisher-requests", h.SubmitPublisherRequest)

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

			// DSL endpoints (Epic 4)
			r.Post("/dsl/validate", h.ValidateDSLFormula)       // Validate DSL formula
			r.Post("/dsl/preview", h.PreviewDSLFormula)         // Preview/calculate DSL formula
			r.Post("/dsl/preview-week", h.PreviewDSLFormulaWeek) // Weekly preview (Story 4-10)

			// Zman definitions - bilingual naming (Story 4-3)
			r.Get("/zman-definitions", h.GetZmanDefinitions)
			r.Get("/zman-definitions/{key}", h.GetZmanDefinition)

			// AI endpoints (Story 4-7, 4-8)
			r.Post("/ai/search", h.SearchAI)
			r.Post("/ai/context", h.GetAIContext)
			r.Post("/ai/generate-formula", h.GenerateFormula)
			r.Post("/ai/explain-formula", h.ExplainFormula)

			// Hebrew calendar endpoints (Story 4-10)
			r.Get("/calendar/week", h.GetWeekCalendar)
			r.Get("/calendar/hebrew-date", h.GetHebrewDate)
			r.Get("/calendar/shabbat", h.GetShabbatTimes)

			// Public algorithm browsing (Story 4-12)
			r.Get("/algorithms/public", h.BrowsePublicAlgorithms)
			r.Get("/algorithms/{id}/public", h.GetPublicAlgorithm)
		})

		// Authenticated routes for algorithm actions (Story 4-12)
		r.Group(func(r chi.Router) {
			r.Use(authMiddleware.RequireRole("publisher"))
			r.Post("/algorithms/{id}/copy", h.CopyAlgorithm)
			r.Post("/algorithms/{id}/fork", h.ForkAlgorithm)
		})

		// Publisher protected routes
		r.Route("/publisher", func(r chi.Router) {
			r.Use(authMiddleware.RequireRole("publisher"))
			r.Get("/accessible", h.GetAccessiblePublishers)
			r.Get("/dashboard", h.GetPublisherDashboardSummary)
			r.Get("/analytics", h.GetPublisherAnalytics)
			r.Get("/activity", h.GetPublisherActivity)
			r.Get("/profile", h.GetPublisherProfile)
			r.Put("/profile", h.UpdatePublisherProfile)
			r.Post("/logo", h.UploadPublisherLogo)
			r.Get("/algorithm", h.GetPublisherAlgorithmHandler)
			r.Put("/algorithm", h.UpdatePublisherAlgorithmHandler)
			r.Post("/algorithm/preview", h.PreviewAlgorithm)
			r.Get("/algorithm/templates", h.GetAlgorithmTemplates)
			r.Get("/algorithm/methods", h.GetZmanMethods)
			// Publisher zmanim management (Story 4-4)
			r.Get("/zmanim", h.GetPublisherZmanim)
			r.Post("/algorithm/publish", h.PublishAlgorithm)
			r.Get("/algorithm/versions", h.GetAlgorithmVersions)
			r.Get("/algorithm/versions/{id}", h.GetAlgorithmVersion)
			r.Put("/algorithm/versions/{id}/deprecate", h.DeprecateAlgorithmVersion)
			// Coverage management
			r.Get("/coverage", h.GetPublisherCoverage)
			r.Post("/coverage", h.CreatePublisherCoverage)
			r.Put("/coverage/{id}", h.UpdatePublisherCoverage)
			r.Delete("/coverage/{id}", h.DeletePublisherCoverage)
			// Cache management
			r.Delete("/cache", h.InvalidatePublisherCache)
			// Zman definitions management (Story 4-3)
			r.Post("/zman-definitions", h.CreateZmanDefinition)
			r.Put("/zman-definitions/{key}", h.UpdateZmanDefinition)
			// Team management (Story 2-10)
			r.Get("/team", h.GetPublisherTeam)
			r.Post("/team/invite", h.InvitePublisherTeamMember)
			r.Delete("/team/{userId}", h.RemovePublisherTeamMember)
			r.Post("/team/invitations/{id}/resend", h.ResendPublisherInvitation)
			r.Delete("/team/invitations/{id}", h.CancelPublisherInvitation)
			r.Post("/team/accept", h.AcceptPublisherInvitation)
			// Onboarding wizard (Story 4-11)
			r.Get("/onboarding", h.GetOnboardingState)
			r.Put("/onboarding", h.SaveOnboardingState)
			r.Post("/onboarding/complete", h.CompleteOnboarding)
			r.Post("/onboarding/skip", h.SkipOnboarding)
			// Algorithm collaboration (Story 4-12)
			r.Put("/algorithm/visibility", h.SetAlgorithmVisibility)
			r.Get("/algorithm/forks", h.GetMyForks)
			// Version history (Story 4-13)
			r.Get("/algorithm/history", h.GetVersionHistory)
			r.Get("/algorithm/history/{version}", h.GetVersionDetail)
			r.Get("/algorithm/diff", h.GetVersionDiff)
			r.Post("/algorithm/rollback", h.RollbackVersion)
			r.Post("/algorithm/snapshot", h.CreateVersionSnapshot)
		})

		// User routes (authenticated)
		r.Route("/user", func(r chi.Router) {
			r.Use(authMiddleware.OptionalAuth)
			r.Post("/request-password-reset", h.RequestPasswordReset)
		})

		// Admin protected routes
		r.Route("/admin", func(r chi.Router) {
			r.Use(authMiddleware.RequireRole("admin"))

			// Publisher management
			r.Get("/publishers", h.AdminListPublishers)
			r.Post("/publishers", h.AdminCreatePublisher)
			r.Put("/publishers/{id}", h.AdminUpdatePublisher)
			r.Delete("/publishers/{id}", h.AdminDeletePublisher)
			r.Put("/publishers/{id}/verify", h.AdminVerifyPublisher)
			r.Put("/publishers/{id}/suspend", h.AdminSuspendPublisher)
			r.Put("/publishers/{id}/reactivate", h.AdminReactivatePublisher)

			// Publisher user management (Epic 2)
			r.Get("/publishers/{id}/users", h.AdminGetPublisherUsers)
			r.Post("/publishers/{id}/users/invite", h.AdminInviteUserToPublisher)
			r.Delete("/publishers/{id}/users/{userId}", h.AdminRemoveUserFromPublisher)

			// Publisher registration requests (Story 2-9)
			r.Get("/publisher-requests", h.AdminGetPublisherRequests)
			r.Post("/publisher-requests/{id}/approve", h.AdminApprovePublisherRequest)
			r.Post("/publisher-requests/{id}/reject", h.AdminRejectPublisherRequest)

			// Statistics
			r.Get("/stats", h.AdminGetStats)

			// System configuration
			r.Get("/config", h.AdminGetConfig)
			r.Put("/config", h.AdminUpdateConfig)

			// AI management (Story 4-7, 4-8)
			r.Get("/ai/stats", h.GetAIIndexStats)
			r.Post("/ai/reindex", h.TriggerReindex)
			r.Get("/ai/audit", h.GetAIAuditLogs)
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
