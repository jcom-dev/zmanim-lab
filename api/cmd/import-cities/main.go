// GeoNames City Importer
// Downloads and imports cities1000.txt from GeoNames into the database
// Source: http://download.geonames.org/export/dump/
package main

import (
	"archive/zip"
	"bufio"
	"context"
	"database/sql"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	_ "github.com/lib/pq"
)

const (
	citiesURL   = "http://download.geonames.org/export/dump/cities1000.zip"
	countryURL  = "http://download.geonames.org/export/dump/countryInfo.txt"
	dataDir     = "scripts/data"
	citiesFile  = "cities1000.txt"
	countryFile = "countryInfo.txt"
)

// Country holds country information including continent
type Country struct {
	Code      string
	Name      string
	Continent string
}

// City holds city information from GeoNames
type City struct {
	GeonameID   int
	Name        string
	Latitude    float64
	Longitude   float64
	CountryCode string
	Admin1Code  string // Region/State code
	Population  int64
	Elevation   int
	Timezone    string
}

// Continent code to full name mapping
var continentNames = map[string]string{
	"AF": "Africa",
	"AS": "Asia",
	"EU": "Europe",
	"NA": "North America",
	"SA": "South America",
	"OC": "Oceania",
	"AN": "Antarctica",
}

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

	// Ensure data directory exists
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		log.Fatalf("Failed to create data directory: %v", err)
	}

	// Download and extract cities data
	citiesPath := filepath.Join(dataDir, citiesFile)
	if _, err := os.Stat(citiesPath); os.IsNotExist(err) {
		log.Println("Downloading cities1000.zip...")
		if err := downloadAndExtract(citiesURL, dataDir); err != nil {
			log.Fatalf("Failed to download cities data: %v", err)
		}
	} else {
		log.Println("Using existing cities1000.txt")
	}

	// Download country info
	countryPath := filepath.Join(dataDir, countryFile)
	if _, err := os.Stat(countryPath); os.IsNotExist(err) {
		log.Println("Downloading countryInfo.txt...")
		if err := downloadFile(countryURL, countryPath); err != nil {
			log.Fatalf("Failed to download country info: %v", err)
		}
	} else {
		log.Println("Using existing countryInfo.txt")
	}

	// Parse country info (for continent mapping)
	countries, err := parseCountryInfo(countryPath)
	if err != nil {
		log.Fatalf("Failed to parse country info: %v", err)
	}
	log.Printf("Loaded %d countries", len(countries))

	// Parse cities
	cities, err := parseCities(citiesPath)
	if err != nil {
		log.Fatalf("Failed to parse cities: %v", err)
	}
	log.Printf("Loaded %d cities", len(cities))

	// Import cities to database
	if err := importCities(ctx, db, cities, countries); err != nil {
		log.Fatalf("Failed to import cities: %v", err)
	}

	log.Println("Import complete!")
}

func downloadFile(url, destPath string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	out, err := os.Create(destPath)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}

func downloadAndExtract(url, destDir string) error {
	// Download zip
	zipPath := filepath.Join(destDir, "cities1000.zip")
	if err := downloadFile(url, zipPath); err != nil {
		return err
	}

	// Extract
	r, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer r.Close()

	for _, f := range r.File {
		destPath := filepath.Join(destDir, f.Name)
		if f.FileInfo().IsDir() {
			os.MkdirAll(destPath, 0755)
			continue
		}

		rc, err := f.Open()
		if err != nil {
			return err
		}

		out, err := os.Create(destPath)
		if err != nil {
			rc.Close()
			return err
		}

		_, err = io.Copy(out, rc)
		out.Close()
		rc.Close()
		if err != nil {
			return err
		}
	}

	return nil
}

func parseCountryInfo(path string) (map[string]Country, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	countries := make(map[string]Country)
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := scanner.Text()
		// Skip comments
		if strings.HasPrefix(line, "#") {
			continue
		}

		fields := strings.Split(line, "\t")
		if len(fields) < 9 {
			continue
		}

		code := fields[0]
		name := fields[4]
		continent := fields[8]

		countries[code] = Country{
			Code:      code,
			Name:      name,
			Continent: continent,
		}
	}

	return countries, scanner.Err()
}

func parseCities(path string) ([]City, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var cities []City
	scanner := bufio.NewScanner(file)
	// Increase buffer size for long lines
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	lineNum := 0
	for scanner.Scan() {
		lineNum++
		line := scanner.Text()
		fields := strings.Split(line, "\t")

		if len(fields) < 18 {
			continue
		}

		geonameID, _ := strconv.Atoi(fields[0])
		name := fields[1]
		lat, _ := strconv.ParseFloat(fields[4], 64)
		lng, _ := strconv.ParseFloat(fields[5], 64)
		countryCode := fields[8]
		admin1Code := fields[10]
		population, _ := strconv.ParseInt(fields[14], 10, 64)

		// Elevation: use field 15, fall back to DEM (field 16) if empty
		elevation := 0
		if fields[15] != "" {
			elevation, _ = strconv.Atoi(fields[15])
		} else if fields[16] != "" {
			elevation, _ = strconv.Atoi(fields[16])
		}

		timezone := fields[17]

		cities = append(cities, City{
			GeonameID:   geonameID,
			Name:        name,
			Latitude:    lat,
			Longitude:   lng,
			CountryCode: countryCode,
			Admin1Code:  admin1Code,
			Population:  population,
			Elevation:   elevation,
			Timezone:    timezone,
		})

		if lineNum%50000 == 0 {
			log.Printf("Parsed %d cities...", lineNum)
		}
	}

	return cities, scanner.Err()
}

func importCities(ctx context.Context, db *sql.DB, cities []City, countries map[string]Country) error {
	// First, clear existing cities
	log.Println("Clearing existing cities...")
	if _, err := db.ExecContext(ctx, "DELETE FROM cities"); err != nil {
		return fmt.Errorf("failed to clear cities: %w", err)
	}

	// Prepare insert statement
	stmt, err := db.PrepareContext(ctx, `
		INSERT INTO cities (geonameid, name, country, country_code, region, latitude, longitude, timezone, population, elevation, continent)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`)
	if err != nil {
		return fmt.Errorf("failed to prepare statement: %w", err)
	}
	defer stmt.Close()

	// Import in batches using transactions
	batchSize := 1000
	total := len(cities)
	imported := 0
	startTime := time.Now()

	for i := 0; i < total; i += batchSize {
		end := i + batchSize
		if end > total {
			end = total
		}
		batch := cities[i:end]

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			return fmt.Errorf("failed to begin transaction: %w", err)
		}

		for _, city := range batch {
			country := countries[city.CountryCode]
			countryName := country.Name
			if countryName == "" {
				countryName = city.CountryCode
			}
			continentCode := country.Continent
			continentName := continentNames[continentCode]
			if continentName == "" {
				continentName = continentCode
			}

			_, err := tx.Stmt(stmt).ExecContext(ctx,
				city.GeonameID,
				city.Name,
				countryName,
				city.CountryCode,
				city.Admin1Code, // Using admin1 as region
				city.Latitude,
				city.Longitude,
				city.Timezone,
				city.Population,
				city.Elevation,
				continentName,
			)
			if err != nil {
				tx.Rollback()
				return fmt.Errorf("failed to insert city %s: %w", city.Name, err)
			}
		}

		if err := tx.Commit(); err != nil {
			return fmt.Errorf("failed to commit transaction: %w", err)
		}

		imported += len(batch)
		elapsed := time.Since(startTime)
		rate := float64(imported) / elapsed.Seconds()
		remaining := time.Duration(float64(total-imported)/rate) * time.Second
		log.Printf("Imported %d/%d cities (%.0f/sec, ETA: %s)", imported, total, rate, remaining.Round(time.Second))
	}

	log.Printf("Successfully imported %d cities in %s", imported, time.Since(startTime).Round(time.Second))
	return nil
}
