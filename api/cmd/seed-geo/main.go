// Geographic Data Seed Tool
// Loads compressed CSV files using PostgreSQL COPY protocol for fast seeding.
// Works with PostgreSQL.
package main

import (
	"compress/gzip"
	"context"
	"encoding/csv"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const seedDir = "seed"

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Get database URL
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL environment variable is required")
	}

	ctx := context.Background()

	// Connect to database using pgx pool
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	// Test connection
	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}
	log.Println("Connected to database")

	// Check if seed files exist
	if _, err := os.Stat(filepath.Join(seedDir, "geo_countries.csv.gz")); os.IsNotExist(err) {
		log.Fatalf("Seed files not found in %s/. Run export-geo first.", seedDir)
	}

	// Truncate tables in FK order (cities FK -> regions FK -> countries FK -> continents)
	log.Println("Clearing existing data...")
	if err := truncateTables(ctx, pool); err != nil {
		log.Fatalf("Failed to truncate tables: %v", err)
	}

	// Load lookup tables
	log.Println("Loading geo_countries...")
	countryCount, err := loadCountries(ctx, pool)
	if err != nil {
		log.Fatalf("Failed to load countries: %v", err)
	}
	log.Printf("Loaded %d countries", countryCount)

	log.Println("Loading geo_regions...")
	regionCount, err := loadRegions(ctx, pool)
	if err != nil {
		log.Fatalf("Failed to load regions: %v", err)
	}
	log.Printf("Loaded %d regions", regionCount)

	log.Println("Loading cities...")
	cityCount, err := loadCities(ctx, pool)
	if err != nil {
		log.Fatalf("Failed to load cities: %v", err)
	}
	log.Printf("Loaded %d cities", cityCount)

	// Reset sequences
	log.Println("Resetting sequences...")
	if err := resetSequences(ctx, pool); err != nil {
		log.Fatalf("Failed to reset sequences: %v", err)
	}

	// Verify counts
	log.Println("Verifying data...")
	if err := verifyCounts(ctx, pool, countryCount, regionCount, cityCount); err != nil {
		log.Fatalf("Verification failed: %v", err)
	}

	log.Println("Seed complete!")
}

func truncateTables(ctx context.Context, pool *pgxpool.Pool) error {
	// Delete all cities first (they have FK to countries/regions)
	_, err := pool.Exec(ctx, "DELETE FROM cities")
	if err != nil {
		return fmt.Errorf("delete cities: %w", err)
	}

	// Truncate lookup tables
	_, err = pool.Exec(ctx, "TRUNCATE geo_regions RESTART IDENTITY CASCADE")
	if err != nil {
		return fmt.Errorf("truncate regions: %w", err)
	}

	_, err = pool.Exec(ctx, "TRUNCATE geo_countries RESTART IDENTITY CASCADE")
	if err != nil {
		return fmt.Errorf("truncate countries: %w", err)
	}

	// Note: geo_continents is pre-populated in migration, don't truncate

	return nil
}

func loadCountries(ctx context.Context, pool *pgxpool.Pool) (int64, error) {
	f, err := os.Open(filepath.Join(seedDir, "geo_countries.csv.gz"))
	if err != nil {
		return 0, err
	}
	defer f.Close()

	gz, err := gzip.NewReader(f)
	if err != nil {
		return 0, err
	}
	defer gz.Close()

	r := csv.NewReader(gz)

	// Skip header
	if _, err := r.Read(); err != nil {
		return 0, fmt.Errorf("read header: %w", err)
	}

	// Read all records
	var rows [][]any
	for {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return 0, fmt.Errorf("read record: %w", err)
		}

		id, _ := strconv.Atoi(record[0])
		code := record[1]
		name := record[2]
		continentID, _ := strconv.Atoi(record[3])

		rows = append(rows, []any{id, code, name, continentID})
	}

	// Use CopyFrom for fast insertion
	count, err := pool.CopyFrom(
		ctx,
		pgx.Identifier{"geo_countries"},
		[]string{"id", "code", "name", "continent_id"},
		pgx.CopyFromRows(rows),
	)
	if err != nil {
		return 0, fmt.Errorf("copy: %w", err)
	}

	return count, nil
}

func loadRegions(ctx context.Context, pool *pgxpool.Pool) (int64, error) {
	f, err := os.Open(filepath.Join(seedDir, "geo_regions.csv.gz"))
	if err != nil {
		return 0, err
	}
	defer f.Close()

	gz, err := gzip.NewReader(f)
	if err != nil {
		return 0, err
	}
	defer gz.Close()

	r := csv.NewReader(gz)

	// Skip header
	if _, err := r.Read(); err != nil {
		return 0, fmt.Errorf("read header: %w", err)
	}

	// Read all records
	var rows [][]any
	for {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return 0, fmt.Errorf("read record: %w", err)
		}

		id, _ := strconv.Atoi(record[0])
		countryID, _ := strconv.Atoi(record[1])
		code := record[2]
		name := record[3]

		rows = append(rows, []any{id, countryID, code, name})
	}

	// Use CopyFrom for fast insertion
	count, err := pool.CopyFrom(
		ctx,
		pgx.Identifier{"geo_regions"},
		[]string{"id", "country_id", "code", "name"},
		pgx.CopyFromRows(rows),
	)
	if err != nil {
		return 0, fmt.Errorf("copy: %w", err)
	}

	return count, nil
}

func loadCities(ctx context.Context, pool *pgxpool.Pool) (int64, error) {
	f, err := os.Open(filepath.Join(seedDir, "cities.csv.gz"))
	if err != nil {
		return 0, err
	}
	defer f.Close()

	gz, err := gzip.NewReader(f)
	if err != nil {
		return 0, err
	}
	defer gz.Close()

	r := csv.NewReader(gz)

	// Read header
	header, err := r.Read()
	if err != nil {
		return 0, fmt.Errorf("read header: %w", err)
	}
	log.Printf("CSV columns: %v", header)

	// Stream cities in batches (large dataset ~163k rows)
	const batchSize = 10000
	var totalCount int64

	for {
		var rows [][]any
		for i := 0; i < batchSize; i++ {
			record, err := r.Read()
			if err == io.EOF {
				break
			}
			if err != nil {
				return totalCount, fmt.Errorf("read record: %w", err)
			}

			row := parseCityRecord(record)
			rows = append(rows, row)
		}

		if len(rows) == 0 {
			break
		}

		count, err := pool.CopyFrom(
			ctx,
			pgx.Identifier{"cities"},
			[]string{
				"id", "geonameid", "name", "hebrew_name", "name_ascii",
				"country_id", "region_id",
				"latitude", "longitude", "timezone", "elevation", "population",
			},
			pgx.CopyFromRows(rows),
		)
		if err != nil {
			return totalCount, fmt.Errorf("copy batch: %w", err)
		}

		totalCount += count
		log.Printf("Loaded %d cities...", totalCount)
	}

	return totalCount, nil
}

// parseCityRecord parses a CSV record into database values
// CSV columns: id, geonameid, name, hebrew_name, name_ascii,
//
//	country_id, region_id,
//	latitude, longitude, timezone, elevation, population
func parseCityRecord(record []string) []any {
	id := record[0]
	geonameid := nullableInt(record[1])
	name := record[2]
	hebrewName := nullableString(record[3])
	nameASCII := nullableString(record[4])
	countryID := nullableInt16(record[5])
	regionID := nullableInt(record[6])
	latitude, _ := strconv.ParseFloat(record[7], 64)
	longitude, _ := strconv.ParseFloat(record[8], 64)
	timezone := record[9]
	elevation := nullableInt(record[10])
	population := nullableInt(record[11])

	return []any{
		id, geonameid, name, hebrewName, nameASCII,
		countryID, regionID,
		latitude, longitude, timezone, elevation, population,
	}
}

func nullableString(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func nullableInt(s string) any {
	if s == "" {
		return nil
	}
	v, err := strconv.Atoi(s)
	if err != nil {
		return nil
	}
	return v
}

func nullableInt16(s string) any {
	if s == "" {
		return nil
	}
	v, err := strconv.Atoi(s)
	if err != nil {
		return nil
	}
	return int16(v)
}

func resetSequences(ctx context.Context, pool *pgxpool.Pool) error {
	// Reset geo_countries sequence
	_, err := pool.Exec(ctx, `
		SELECT setval('geo_countries_id_seq', COALESCE((SELECT MAX(id) FROM geo_countries), 0) + 1, false)
	`)
	if err != nil && !strings.Contains(err.Error(), "does not exist") {
		return fmt.Errorf("reset geo_countries_id_seq: %w", err)
	}

	// Reset geo_regions sequence
	_, err = pool.Exec(ctx, `
		SELECT setval('geo_regions_id_seq', COALESCE((SELECT MAX(id) FROM geo_regions), 0) + 1, false)
	`)
	if err != nil && !strings.Contains(err.Error(), "does not exist") {
		return fmt.Errorf("reset geo_regions_id_seq: %w", err)
	}

	return nil
}

func verifyCounts(ctx context.Context, pool *pgxpool.Pool, expectedCountries, expectedRegions, expectedCities int64) error {
	var countryCount, regionCount, cityCount int64

	err := pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_countries").Scan(&countryCount)
	if err != nil {
		return fmt.Errorf("count countries: %w", err)
	}

	err = pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_regions").Scan(&regionCount)
	if err != nil {
		return fmt.Errorf("count regions: %w", err)
	}

	err = pool.QueryRow(ctx, "SELECT COUNT(*) FROM cities").Scan(&cityCount)
	if err != nil {
		return fmt.Errorf("count cities: %w", err)
	}

	log.Printf("Verification: %d countries, %d regions, %d cities", countryCount, regionCount, cityCount)

	if countryCount != expectedCountries {
		return fmt.Errorf("country count mismatch: expected %d, got %d", expectedCountries, countryCount)
	}
	if regionCount != expectedRegions {
		return fmt.Errorf("region count mismatch: expected %d, got %d", expectedRegions, regionCount)
	}
	if cityCount != expectedCities {
		return fmt.Errorf("city count mismatch: expected %d, got %d", expectedCities, cityCount)
	}

	return nil
}
