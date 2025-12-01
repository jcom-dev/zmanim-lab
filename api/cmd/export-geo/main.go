// Geographic Data Export Tool
// Exports cities, countries, and regions to compressed CSV files
// for efficient seeding using PostgreSQL COPY protocol.
package main

import (
	"compress/gzip"
	"context"
	"database/sql"
	"encoding/csv"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"

	_ "github.com/lib/pq"
)

const seedDir = "seed"

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Get database URL
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL environment variable is required")
	}

	// Connect to database
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	ctx := context.Background()

	// Test connection
	if err := db.PingContext(ctx); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}
	log.Println("Connected to database")

	// Ensure seed directory exists
	if err := os.MkdirAll(seedDir, 0755); err != nil {
		log.Fatalf("Failed to create seed directory: %v", err)
	}

	// Export all geographic data from normalized tables
	if err := exportCountries(ctx, db); err != nil {
		log.Fatalf("Failed to export countries: %v", err)
	}

	if err := exportRegions(ctx, db); err != nil {
		log.Fatalf("Failed to export regions: %v", err)
	}

	if err := exportCities(ctx, db); err != nil {
		log.Fatalf("Failed to export cities: %v", err)
	}

	log.Println("Export complete!")
	log.Printf("Files written to: %s/", seedDir)
}

// exportCountries exports countries from geo_countries table
func exportCountries(ctx context.Context, db *sql.DB) error {
	log.Println("Exporting countries...")

	query := `
		SELECT id, code, name, continent_id
		FROM geo_countries
		ORDER BY id
	`
	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		return fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	var records [][]string
	for rows.Next() {
		var id, continentID int
		var code, name string
		if err := rows.Scan(&id, &code, &name, &continentID); err != nil {
			return fmt.Errorf("scan failed: %w", err)
		}

		records = append(records, []string{
			strconv.Itoa(id),
			code,
			name,
			strconv.Itoa(continentID),
		})
	}

	if err := rows.Err(); err != nil {
		return fmt.Errorf("rows error: %w", err)
	}

	// Write to CSV
	headers := []string{"id", "code", "name", "continent_id"}
	if err := writeGzipCSV("geo_countries.csv.gz", headers, records); err != nil {
		return fmt.Errorf("write failed: %w", err)
	}

	log.Printf("Exported %d countries", len(records))
	return nil
}

// exportRegions exports regions from geo_regions table
func exportRegions(ctx context.Context, db *sql.DB) error {
	log.Println("Exporting regions...")

	query := `
		SELECT id, country_id, code, name
		FROM geo_regions
		ORDER BY id
	`
	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		return fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	var records [][]string
	for rows.Next() {
		var id, countryID int
		var code, name string
		if err := rows.Scan(&id, &countryID, &code, &name); err != nil {
			return fmt.Errorf("scan failed: %w", err)
		}

		records = append(records, []string{
			strconv.Itoa(id),
			strconv.Itoa(countryID),
			code,
			name,
		})
	}

	if err := rows.Err(); err != nil {
		return fmt.Errorf("rows error: %w", err)
	}

	// Write to CSV
	headers := []string{"id", "country_id", "code", "name"}
	if err := writeGzipCSV("geo_regions.csv.gz", headers, records); err != nil {
		return fmt.Errorf("write failed: %w", err)
	}

	log.Printf("Exported %d regions", len(records))
	return nil
}

// exportCities exports cities with normalized FK references
func exportCities(ctx context.Context, db *sql.DB) error {
	log.Println("Exporting cities...")

	query := `
		SELECT
			id, geonameid, name, hebrew_name, name_ascii,
			country_id, region_id,
			latitude, longitude, timezone, elevation, population
		FROM cities
		ORDER BY population DESC NULLS LAST, name
	`
	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		return fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	// Open CSV writer directly for streaming (cities is large)
	f, err := os.Create(filepath.Join(seedDir, "cities.csv.gz"))
	if err != nil {
		return fmt.Errorf("create file failed: %w", err)
	}
	defer f.Close()

	gz := gzip.NewWriter(f)
	defer gz.Close()

	w := csv.NewWriter(gz)

	// Write header - normalized columns only
	headers := []string{
		"id", "geonameid", "name", "hebrew_name", "name_ascii",
		"country_id", "region_id",
		"latitude", "longitude", "timezone", "elevation", "population",
	}
	if err := w.Write(headers); err != nil {
		return fmt.Errorf("write header failed: %w", err)
	}

	count := 0
	for rows.Next() {
		var (
			id                    string
			geonameid             sql.NullInt64
			name                  string
			hebrewName, nameASCII sql.NullString
			countryID             int
			regionID              sql.NullInt64
			latitude, longitude   float64
			timezone              string
			elevation             sql.NullInt64
			population            sql.NullInt64
		)

		if err := rows.Scan(
			&id, &geonameid, &name, &hebrewName, &nameASCII,
			&countryID, &regionID,
			&latitude, &longitude, &timezone, &elevation, &population,
		); err != nil {
			return fmt.Errorf("scan failed: %w", err)
		}

		record := []string{
			id,
			nullInt64Str(geonameid),
			name,
			nullStr(hebrewName),
			nullStr(nameASCII),
			strconv.Itoa(countryID),
			nullInt64Str(regionID),
			strconv.FormatFloat(latitude, 'f', -1, 64),
			strconv.FormatFloat(longitude, 'f', -1, 64),
			timezone,
			nullInt64Str(elevation),
			nullInt64Str(population),
		}

		if err := w.Write(record); err != nil {
			return fmt.Errorf("write record failed: %w", err)
		}

		count++
		if count%50000 == 0 {
			log.Printf("Exported %d cities...", count)
		}
	}

	if err := rows.Err(); err != nil {
		return fmt.Errorf("rows error: %w", err)
	}

	w.Flush()
	if err := w.Error(); err != nil {
		return fmt.Errorf("flush failed: %w", err)
	}

	log.Printf("Exported %d cities", count)
	return nil
}

func writeGzipCSV(filename string, headers []string, records [][]string) error {
	f, err := os.Create(filepath.Join(seedDir, filename))
	if err != nil {
		return err
	}
	defer f.Close()

	gz := gzip.NewWriter(f)
	defer gz.Close()

	w := csv.NewWriter(gz)

	if err := w.Write(headers); err != nil {
		return err
	}

	for _, record := range records {
		if err := w.Write(record); err != nil {
			return err
		}
	}

	w.Flush()
	return w.Error()
}

func nullStr(ns sql.NullString) string {
	if ns.Valid {
		return ns.String
	}
	return ""
}

func nullInt64Str(ni sql.NullInt64) string {
	if ni.Valid {
		return strconv.FormatInt(ni.Int64, 10)
	}
	return ""
}
