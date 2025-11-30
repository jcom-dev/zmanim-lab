package main

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	pool, err := pgxpool.New(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Printf("Failed to connect: %v\n", err)
		return
	}
	defer pool.Close()

	var count int
	pool.QueryRow(context.Background(), "SELECT COUNT(*) FROM embeddings").Scan(&count)
	fmt.Printf("Total embeddings: %d\n", count)

	rows, _ := pool.Query(context.Background(), "SELECT source, content_type, COUNT(*) FROM embeddings GROUP BY source, content_type ORDER BY source")
	defer rows.Close()
	for rows.Next() {
		var s, ct string
		var c int
		rows.Scan(&s, &ct, &c)
		fmt.Printf("  %s (%s): %d\n", s, ct, c)
	}
}
