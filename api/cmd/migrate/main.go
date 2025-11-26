package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/jackc/pgx/v5"
)

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL not set")
	}

	ctx := context.Background()
	conn, err := pgx.Connect(ctx, dbURL)
	if err != nil {
		log.Fatal("Failed to connect:", err)
	}
	defer conn.Close(ctx)

	// Check if configuration column exists
	var exists bool
	err = conn.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_name = 'algorithms' AND column_name = 'configuration'
		)
	`).Scan(&exists)
	if err != nil {
		log.Fatal("Failed to check column:", err)
	}
	fmt.Printf("configuration column exists: %v\n", exists)

	if !exists {
		fmt.Println("Adding configuration column...")
		_, err = conn.Exec(ctx, "ALTER TABLE algorithms ADD COLUMN configuration JSONB")
		if err != nil {
			log.Fatal("Failed to add column:", err)
		}
		fmt.Println("Added configuration column")
	}

	// Check current columns
	rows, err := conn.Query(ctx, `
		SELECT column_name, data_type
		FROM information_schema.columns
		WHERE table_name = 'algorithms'
		ORDER BY ordinal_position
	`)
	if err != nil {
		log.Fatal("Failed to query columns:", err)
	}
	defer rows.Close()

	fmt.Println("\nAlgorithms table columns:")
	for rows.Next() {
		var name, dtype string
		rows.Scan(&name, &dtype)
		fmt.Printf("  - %s (%s)\n", name, dtype)
	}
}
