package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
)

func main() {
	// Load .env file
	_ = godotenv.Load()

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL not set")
	}

	ctx := context.Background()
	conn, err := pgx.Connect(ctx, dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer conn.Close(ctx)

	// Determine migration path
	var migrationsDir string
	if len(os.Args) > 1 {
		// Single file mode (backward compatibility)
		sqlFile := os.Args[1]
		if strings.HasSuffix(sqlFile, ".sql") {
			sqlContent, err := os.ReadFile(sqlFile)
			if err != nil {
				log.Fatalf("Failed to read SQL file: %v", err)
			}
			fmt.Printf("Running single migration: %s\n", sqlFile)
			_, err = conn.Exec(ctx, string(sqlContent))
			if err != nil {
				log.Fatalf("Failed to execute SQL: %v", err)
			}
			fmt.Println("Migration complete!")
			return
		}
		migrationsDir = os.Args[1]
	} else {
		// Default to supabase migrations directory
		migrationsDir = "../supabase/migrations"
	}

	// Find all .sql files in migrations directory
	files, err := filepath.Glob(filepath.Join(migrationsDir, "*.sql"))
	if err != nil {
		log.Fatalf("Failed to glob migrations: %v", err)
	}

	if len(files) == 0 {
		log.Fatalf("No migration files found in %s", migrationsDir)
	}

	// Sort files to ensure correct order
	sort.Strings(files)

	fmt.Printf("Found %d migrations in %s\n", len(files), migrationsDir)
	fmt.Println("---")

	// Create migrations tracking table
	_, err = conn.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version VARCHAR(255) PRIMARY KEY,
			applied_at TIMESTAMPTZ DEFAULT NOW()
		)
	`)
	if err != nil {
		log.Fatalf("Failed to create schema_migrations table: %v", err)
	}

	// Run each migration
	successCount := 0
	skipCount := 0
	for _, file := range files {
		filename := filepath.Base(file)
		version := strings.TrimSuffix(filename, ".sql")

		// Check if already applied
		var exists bool
		err := conn.QueryRow(ctx,
			"SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)",
			version,
		).Scan(&exists)
		if err != nil {
			log.Fatalf("Failed to check migration status: %v", err)
		}

		if exists {
			fmt.Printf("⏭️  Skipping (already applied): %s\n", filename)
			skipCount++
			continue
		}

		// Read and execute migration
		sqlContent, err := os.ReadFile(file)
		if err != nil {
			log.Fatalf("Failed to read %s: %v", file, err)
		}

		fmt.Printf("▶️  Running: %s\n", filename)

		_, err = conn.Exec(ctx, string(sqlContent))
		if err != nil {
			log.Fatalf("❌ Failed to execute %s: %v", filename, err)
		}

		// Record migration
		_, err = conn.Exec(ctx,
			"INSERT INTO schema_migrations (version) VALUES ($1)",
			version,
		)
		if err != nil {
			log.Fatalf("Failed to record migration: %v", err)
		}

		fmt.Printf("✅ Applied: %s\n", filename)
		successCount++
	}

	fmt.Println("---")
	fmt.Printf("✅ Migrations complete! Applied: %d, Skipped: %d\n", successCount, skipCount)
}
