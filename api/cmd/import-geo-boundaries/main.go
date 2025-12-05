// Package main provides a CLI tool to seed all geographic data from authoritative online sources.
// NO CSV files are stored in source control - everything is fetched live.
//
// Data Sources:
//   - Countries (ISO2/ISO3): GeoNames countryInfo.txt
//   - Regions (ADM1):        GeoNames admin1CodesASCII.txt
//   - Cities:                GeoNames cities15000.zip
//   - Region Boundaries:     geoBoundaries.org ADM1 API
//   - District Boundaries:   geoBoundaries.org ADM2 API
//
// Main Command:
//
//	import-geo-boundaries seed    # Complete end-to-end seed from online sources
//
// The seed command does everything: reset, load countries/regions/cities,
// download/import ADM1 boundaries, download/import ADM2 boundaries, assign hierarchy.
package main

import (
	"archive/zip"
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	// GeoNames data sources (authoritative, always up-to-date)
	geoNamesCountryInfoURL = "http://download.geonames.org/export/dump/countryInfo.txt"
	geoNamesAdmin1URL      = "http://download.geonames.org/export/dump/admin1CodesASCII.txt"
	geoNamesCities15000URL = "http://download.geonames.org/export/dump/cities15000.zip"

	// geoBoundaries API for boundary polygons
	geoBoundariesADM1API = "https://www.geoboundaries.org/api/current/gbOpen/ALL/ADM1/"
	geoBoundariesADM2API = "https://www.geoboundaries.org/api/current/gbOpen/ALL/ADM2/"

	// Local data directory for downloaded boundaries (not source-controlled)
	defaultDataDir    = "data/geoboundaries"
	defaultConcurrent = 10
)

// Continent codes mapping (static, rarely changes)
var continentCodes = map[string]int{
	"AF": 1, // Africa
	"AN": 2, // Antarctica
	"AS": 3, // Asia
	"EU": 4, // Europe
	"NA": 5, // North America
	"OC": 6, // Oceania
	"SA": 7, // South America
}

// ISO3 to ISO2 mapping - built dynamically from GeoNames countryInfo.txt
// This ensures the mapping is always accurate and up-to-date
var iso3ToISO2 = make(map[string]string)

// Command-line usage
func usage() {
	fmt.Fprintf(os.Stderr, `Geographic Data Seed Tool - Complete Geographic Database Management

All data is fetched directly from authoritative online sources.
NO CSV files are stored in source control.

Usage:
  import-geo-boundaries <command> [flags]

Commands:
  seed        Complete seeding from online sources (GeoNames + geoBoundaries)
  download    Download geoBoundaries ADM2 data from the API
  import      Import downloaded boundaries into the database
  status      Show download and database status

Data Sources:
  - Countries:    GeoNames countryInfo.txt (ISO2, ISO3, name, continent, etc.)
  - Regions:      GeoNames admin1CodesASCII.txt (states, provinces)
  - Cities:       GeoNames cities15000.txt (population > 15,000)
  - Districts:    geoBoundaries.org API (ADM2 polygons, ~180 countries)

ISO Code Handling:
  - Database stores ISO2 codes (GB, US, IL)
  - geoBoundaries uses ISO3 codes (GBR, USA, ISR)
  - Conversion table built dynamically from GeoNames data

Examples:
  # Complete seed: fetch all data from online sources
  import-geo-boundaries seed --all

  # Reset ALL geo data and completely reseed
  import-geo-boundaries seed --all --reset

  # Download boundaries only (no database changes)
  import-geo-boundaries download --all

  # Check current status
  import-geo-boundaries status

Environment:
  DATABASE_URL    PostgreSQL connection string (required for seed/import)

`)
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}

	cmd := os.Args[1]
	args := os.Args[2:]

	switch cmd {
	case "seed":
		cmdSeed(args)
	case "download":
		cmdDownload(args)
	case "import":
		cmdImport(args)
	case "status":
		cmdStatus(args)
	case "help", "-h", "--help":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n\n", cmd)
		usage()
		os.Exit(1)
	}
}

// =============================================================================
// GEONAMES DATA FETCHERS
// =============================================================================

// GeoNamesCountry represents a country from GeoNames countryInfo.txt
type GeoNamesCountry struct {
	ISO2        string // ISO 3166-1 alpha-2
	ISO3        string // ISO 3166-1 alpha-3
	ISONumeric  string // ISO 3166-1 numeric
	Name        string
	Capital     string
	Area        float64
	Population  int64
	Continent   string // 2-letter continent code
	GeoNameID   int
	CurrencyCode string
}

// GeoNamesAdmin1 represents a region/state from GeoNames admin1CodesASCII.txt
type GeoNamesAdmin1 struct {
	Code      string // e.g., "US.CA" or "GB.ENG"
	Name      string
	NameASCII string
	GeoNameID int
}

// GeoNamesCity represents a city from GeoNames cities15000.txt
type GeoNamesCity struct {
	GeoNameID   int
	Name        string
	ASCIIName   string
	Latitude    float64
	Longitude   float64
	CountryCode string // ISO2
	Admin1Code  string // Links to Admin1
	Admin2Code  string
	Population  int64
	Elevation   int
	Timezone    string
}

// fetchGeoNamesCountries fetches country data directly from GeoNames
func fetchGeoNamesCountries(ctx context.Context) ([]GeoNamesCountry, error) {
	log.Println("Fetching countries from GeoNames...")

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Get(geoNamesCountryInfoURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch countryInfo.txt: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GeoNames returned status %d", resp.StatusCode)
	}

	var countries []GeoNamesCountry
	scanner := bufio.NewScanner(resp.Body)

	for scanner.Scan() {
		line := scanner.Text()

		// Skip comments and empty lines
		if strings.HasPrefix(line, "#") || strings.TrimSpace(line) == "" {
			continue
		}

		fields := strings.Split(line, "\t")
		if len(fields) < 17 {
			continue
		}

		// Parse fields: ISO, ISO3, ISO-Numeric, FIPS, Country, Capital, Area, Population, Continent, ...
		country := GeoNamesCountry{
			ISO2:       fields[0],
			ISO3:       fields[1],
			ISONumeric: fields[2],
			Name:       fields[4],
			Capital:    fields[5],
			Continent:  fields[8],
		}

		// Parse numeric fields safely
		if fields[6] != "" {
			country.Area, _ = strconv.ParseFloat(fields[6], 64)
		}
		if fields[7] != "" {
			country.Population, _ = strconv.ParseInt(fields[7], 10, 64)
		}
		if fields[16] != "" {
			country.GeoNameID, _ = strconv.Atoi(fields[16])
		}

		// Build ISO3 -> ISO2 mapping
		if country.ISO2 != "" && country.ISO3 != "" {
			iso3ToISO2[country.ISO3] = country.ISO2
		}

		countries = append(countries, country)
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading countryInfo.txt: %w", err)
	}

	log.Printf("Fetched %d countries from GeoNames", len(countries))
	return countries, nil
}

// fetchGeoNamesAdmin1 fetches admin1 (regions/states) from GeoNames
func fetchGeoNamesAdmin1(ctx context.Context) ([]GeoNamesAdmin1, error) {
	log.Println("Fetching admin1 codes (regions) from GeoNames...")

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Get(geoNamesAdmin1URL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch admin1CodesASCII.txt: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GeoNames returned status %d", resp.StatusCode)
	}

	var regions []GeoNamesAdmin1
	scanner := bufio.NewScanner(resp.Body)

	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) == "" {
			continue
		}

		fields := strings.Split(line, "\t")
		if len(fields) < 4 {
			continue
		}

		// Format: code, name, name_ascii, geonameid
		// Code format: "US.CA" or "GB.ENG"
		region := GeoNamesAdmin1{
			Code:      fields[0],
			Name:      fields[1],
			NameASCII: fields[2],
		}

		if fields[3] != "" {
			region.GeoNameID, _ = strconv.Atoi(fields[3])
		}

		regions = append(regions, region)
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading admin1CodesASCII.txt: %w", err)
	}

	log.Printf("Fetched %d admin1 regions from GeoNames", len(regions))
	return regions, nil
}

// fetchGeoNamesCities fetches cities from GeoNames cities15000.zip
func fetchGeoNamesCities(ctx context.Context) ([]GeoNamesCity, error) {
	log.Println("Fetching cities from GeoNames (cities15000.zip)...")

	client := &http.Client{Timeout: 5 * time.Minute}
	resp, err := client.Get(geoNamesCities15000URL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch cities15000.zip: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GeoNames returned status %d", resp.StatusCode)
	}

	// Download to temp file (needed for zip)
	tmpFile, err := os.CreateTemp("", "cities15000-*.zip")
	if err != nil {
		return nil, fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

	size, err := io.Copy(tmpFile, resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to download cities15000.zip: %w", err)
	}
	log.Printf("Downloaded cities15000.zip (%.1f MB)", float64(size)/1024/1024)

	// Extract and parse the zip file
	return parseCitiesZip(tmpFile.Name())
}

// parseCitiesZip extracts and parses the cities15000.zip file
func parseCitiesZip(zipPath string) ([]GeoNamesCity, error) {
	// Open zip file
	zipFile, err := os.Open(zipPath)
	if err != nil {
		return nil, err
	}
	defer zipFile.Close()

	stat, _ := zipFile.Stat()
	zipReader, err := newZipReader(zipFile, stat.Size())
	if err != nil {
		return nil, fmt.Errorf("failed to open zip: %w", err)
	}

	var cities []GeoNamesCity

	for _, file := range zipReader.File {
		if !strings.HasSuffix(file.Name, ".txt") {
			continue
		}

		rc, err := file.Open()
		if err != nil {
			return nil, fmt.Errorf("failed to open %s in zip: %w", file.Name, err)
		}

		scanner := bufio.NewScanner(rc)
		// Increase buffer size for long lines
		buf := make([]byte, 0, 1024*1024)
		scanner.Buffer(buf, 1024*1024)

		for scanner.Scan() {
			line := scanner.Text()
			if strings.TrimSpace(line) == "" {
				continue
			}

			fields := strings.Split(line, "\t")
			if len(fields) < 19 {
				continue
			}

			city := GeoNamesCity{
				Name:        fields[1],
				ASCIIName:   fields[2],
				CountryCode: fields[8],
				Admin1Code:  fields[10],
				Admin2Code:  fields[11],
				Timezone:    fields[17],
			}

			// Parse numeric fields
			city.GeoNameID, _ = strconv.Atoi(fields[0])
			city.Latitude, _ = strconv.ParseFloat(fields[4], 64)
			city.Longitude, _ = strconv.ParseFloat(fields[5], 64)
			city.Population, _ = strconv.ParseInt(fields[14], 10, 64)
			city.Elevation, _ = strconv.Atoi(fields[15])

			// Use DEM (digital elevation model) if elevation is empty
			if city.Elevation == 0 && fields[16] != "" {
				city.Elevation, _ = strconv.Atoi(fields[16])
			}

			cities = append(cities, city)
		}

		rc.Close()

		if err := scanner.Err(); err != nil {
			return nil, fmt.Errorf("error reading cities: %w", err)
		}
	}

	log.Printf("Parsed %d cities from GeoNames", len(cities))
	return cities, nil
}

func newZipReader(file *os.File, size int64) (*zip.Reader, error) {
	return zip.NewReader(file, size)
}

// =============================================================================
// DATABASE LOADING FROM GEONAMES
// =============================================================================

// loadCountriesFromGeoNames loads countries directly from GeoNames into the database
func loadCountriesFromGeoNames(ctx context.Context, pool *pgxpool.Pool) (int64, error) {
	countries, err := fetchGeoNamesCountries(ctx)
	if err != nil {
		return 0, err
	}

	// Prepare batch insert
	var rows [][]any
	for _, c := range countries {
		continentID, ok := continentCodes[c.Continent]
		if !ok {
			log.Printf("Warning: Unknown continent code %s for country %s, skipping", c.Continent, c.ISO2)
			continue
		}

		rows = append(rows, []any{
			c.ISO2,      // code
			c.ISO3,      // code_iso3
			c.Name,      // name
			continentID, // continent_id
			c.Population,
			c.Area,
		})
	}

	// Use CopyFrom for fast insertion
	count, err := pool.CopyFrom(
		ctx,
		pgx.Identifier{"geo_countries"},
		[]string{"code", "code_iso3", "name", "continent_id", "population", "area_km2"},
		pgx.CopyFromRows(rows),
	)
	if err != nil {
		return 0, fmt.Errorf("failed to insert countries: %w", err)
	}

	log.Printf("Loaded %d countries from GeoNames", count)
	return count, nil
}

// loadRegionsFromGeoNames loads admin1 regions directly from GeoNames
func loadRegionsFromGeoNames(ctx context.Context, pool *pgxpool.Pool) (int64, error) {
	regions, err := fetchGeoNamesAdmin1(ctx)
	if err != nil {
		return 0, err
	}

	// Build country code -> ID mapping
	countryMap := make(map[string]int16)
	rows, err := pool.Query(ctx, "SELECT code, id FROM geo_countries")
	if err != nil {
		return 0, fmt.Errorf("failed to query countries: %w", err)
	}
	for rows.Next() {
		var code string
		var id int16
		rows.Scan(&code, &id)
		countryMap[code] = id
	}
	rows.Close()

	// Prepare batch insert
	var insertRows [][]any
	for _, r := range regions {
		// Parse country code from admin1 code (e.g., "US.CA" -> "US")
		parts := strings.SplitN(r.Code, ".", 2)
		if len(parts) != 2 {
			continue
		}
		countryCode := parts[0]
		regionCode := parts[1]

		countryID, ok := countryMap[countryCode]
		if !ok {
			// Skip regions for countries we don't have
			continue
		}

		insertRows = append(insertRows, []any{
			countryID,
			regionCode, // Just the region part (CA, ENG, etc.)
			r.Name,
		})
	}

	// Use CopyFrom for fast insertion
	count, err := pool.CopyFrom(
		ctx,
		pgx.Identifier{"geo_regions"},
		[]string{"country_id", "code", "name"},
		pgx.CopyFromRows(insertRows),
	)
	if err != nil {
		return 0, fmt.Errorf("failed to insert regions: %w", err)
	}

	log.Printf("Loaded %d regions from GeoNames", count)
	return count, nil
}

// loadCitiesFromGeoNames loads cities directly from GeoNames
func loadCitiesFromGeoNames(ctx context.Context, pool *pgxpool.Pool) (int64, error) {
	cities, err := fetchGeoNamesCities(ctx)
	if err != nil {
		return 0, err
	}

	// Build lookup maps
	countryMap := make(map[string]int16)
	rows, err := pool.Query(ctx, "SELECT code, id FROM geo_countries")
	if err != nil {
		return 0, fmt.Errorf("failed to query countries: %w", err)
	}
	for rows.Next() {
		var code string
		var id int16
		rows.Scan(&code, &id)
		countryMap[code] = id
	}
	rows.Close()

	// Build region lookup: (country_id, code) -> region_id
	regionMap := make(map[string]int)
	regionRows, err := pool.Query(ctx, "SELECT country_id, code, id FROM geo_regions")
	if err != nil {
		return 0, fmt.Errorf("failed to query regions: %w", err)
	}
	for regionRows.Next() {
		var countryID int16
		var code string
		var id int
		regionRows.Scan(&countryID, &code, &id)
		key := fmt.Sprintf("%d:%s", countryID, code)
		regionMap[key] = id
	}
	regionRows.Close()

	// Insert cities in batches
	const batchSize = 10000
	var totalCount int64

	for i := 0; i < len(cities); i += batchSize {
		end := i + batchSize
		if end > len(cities) {
			end = len(cities)
		}
		batch := cities[i:end]

		var insertRows [][]any
		for _, c := range batch {
			countryID, ok := countryMap[c.CountryCode]
			if !ok {
				continue
			}

			// Try to match region
			var regionID *int
			regionKey := fmt.Sprintf("%d:%s", countryID, c.Admin1Code)
			if rid, found := regionMap[regionKey]; found {
				regionID = &rid
			}

			insertRows = append(insertRows, []any{
				c.GeoNameID,
				c.Name,
				nullStr(c.ASCIIName),
				countryID,
				regionID,
				c.Latitude,
				c.Longitude,
				c.Timezone,
				nullInt(c.Elevation),
				nullInt64(c.Population),
			})
		}

		count, err := pool.CopyFrom(
			ctx,
			pgx.Identifier{"cities"},
			[]string{"geonameid", "name", "name_ascii", "country_id", "region_id",
				"latitude", "longitude", "timezone", "elevation_m", "population"},
			pgx.CopyFromRows(insertRows),
		)
		if err != nil {
			return totalCount, fmt.Errorf("failed to insert cities batch: %w", err)
		}

		totalCount += count
		log.Printf("  Loaded %d cities...", totalCount)
	}

	log.Printf("Loaded %d cities from GeoNames", totalCount)
	return totalCount, nil
}

// Helper functions for nullable values
func nullStr(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func nullInt(i int) any {
	if i == 0 {
		return nil
	}
	return i
}

func nullInt64(i int64) any {
	if i == 0 {
		return nil
	}
	return i
}

// =============================================================================
// GEOBOUNDARIES DOWNLOAD
// =============================================================================

// GeoBoundariesEntry represents a single entry from the geoBoundaries API
type GeoBoundariesEntry struct {
	BoundaryISO   string `json:"boundaryISO"`   // ISO3 code (GBR, USA, etc.)
	BoundaryName  string `json:"boundaryName"`
	BoundaryType  string `json:"boundaryType"`
	GJDownloadURL string `json:"gjDownloadURL"`
	AdmUnitCount  string `json:"admUnitCount"`
}

func cmdDownload(args []string) {
	var (
		all         bool
		countries   string
		dataDir     string
		concurrency int
		level       string // ADM1 or ADM2
		dryRun      bool
		verbose     bool
	)

	level = "ADM2" // default

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--all", "-a":
			all = true
		case "--countries", "-c":
			if i+1 < len(args) {
				countries = args[i+1]
				i++
			}
		case "--dir", "-d":
			if i+1 < len(args) {
				dataDir = args[i+1]
				i++
			}
		case "--concurrency", "-j":
			if i+1 < len(args) {
				fmt.Sscanf(args[i+1], "%d", &concurrency)
				i++
			}
		case "--level", "-l":
			if i+1 < len(args) {
				level = strings.ToUpper(args[i+1])
				i++
			}
		case "--dry-run", "-n":
			dryRun = true
		case "--verbose", "-v":
			verbose = true
		case "--help", "-h":
			fmt.Println(`Download geoBoundaries boundary data

Usage:
  import-geo-boundaries download [flags]

Flags:
  --all, -a              Download all available countries (~180)
  --countries, -c LIST   Comma-separated ISO codes (ISO2 or ISO3, e.g., GB,USA,FRA)
  --dir, -d PATH         Output directory (default: data/geoboundaries)
  --level, -l LEVEL      ADM1 (regions) or ADM2 (districts). Default: ADM2
  --concurrency, -j N    Parallel downloads (default: 10)
  --dry-run, -n          Show what would be downloaded
  --verbose, -v          Show detailed progress
  --help, -h             Show this help

Note: geoBoundaries uses ISO3 codes internally. This tool accepts both ISO2
and ISO3 codes and converts automatically using GeoNames data.

Examples:
  # Download ADM2 (district) boundaries for all countries
  import-geo-boundaries download --all

  # Download ADM1 (region) boundaries for specific countries
  import-geo-boundaries download --level ADM1 --countries GB,US,FR`)
			return
		}
	}

	if dataDir == "" {
		dataDir = defaultDataDir
	}
	if concurrency == 0 {
		concurrency = defaultConcurrent
	}

	if !all && countries == "" {
		fmt.Fprintln(os.Stderr, "Error: specify --all or --countries")
		os.Exit(1)
	}

	// Build ISO code mapping from GeoNames
	fmt.Println("Building ISO code mapping from GeoNames...")
	_, err := fetchGeoNamesCountries(context.Background())
	if err != nil {
		log.Printf("Warning: Could not fetch GeoNames data for ISO mapping: %v", err)
		log.Println("Proceeding with provided codes as-is...")
	}

	// Fetch API for the specified level
	fmt.Printf("Fetching geoBoundaries %s API...\n", level)
	entries, err := fetchGeoBoundariesAPILevel(level)
	if err != nil {
		log.Fatalf("Failed to fetch API: %v", err)
	}
	fmt.Printf("Found %d countries with %s boundaries\n", len(entries), level)

	// Filter by country codes if specified
	if countries != "" {
		codes := parseAndConvertCountryCodes(countries)
		codeSet := make(map[string]bool)
		for _, c := range codes {
			codeSet[c] = true
		}
		var filtered []GeoBoundariesEntry
		for _, e := range entries {
			if codeSet[e.BoundaryISO] {
				filtered = append(filtered, e)
			}
		}
		entries = filtered
		fmt.Printf("Filtered to %d countries\n", len(entries))
	}

	if len(entries) == 0 {
		fmt.Println("No countries to download")
		return
	}

	// Create output directory
	if !dryRun {
		if err := os.MkdirAll(dataDir, 0755); err != nil {
			log.Fatalf("Failed to create directory: %v", err)
		}
	}

	// Download in parallel
	downloadAll(entries, dataDir, concurrency, dryRun, verbose)
}

// parseAndConvertCountryCodes parses country codes and converts ISO2 to ISO3 where needed
func parseAndConvertCountryCodes(codes string) []string {
	if codes == "" {
		return nil
	}

	// Build reverse mapping (ISO2 -> ISO3)
	iso2ToISO3 := make(map[string]string)
	for iso3, iso2 := range iso3ToISO2 {
		iso2ToISO3[iso2] = iso3
	}

	var result []string
	for _, c := range strings.Split(codes, ",") {
		c = strings.TrimSpace(strings.ToUpper(c))
		if c == "" {
			continue
		}

		// If it's a 2-letter code, try to convert to ISO3
		if len(c) == 2 {
			if iso3, found := iso2ToISO3[c]; found {
				result = append(result, iso3)
			} else {
				log.Printf("Warning: Unknown ISO2 code %s, skipping", c)
			}
		} else if len(c) == 3 {
			// Already ISO3
			result = append(result, c)
		} else {
			log.Printf("Warning: Invalid country code %s, skipping", c)
		}
	}
	return result
}

func fetchGeoBoundariesAPI() ([]GeoBoundariesEntry, error) {
	return fetchGeoBoundariesAPILevel("ADM2")
}

func fetchGeoBoundariesAPILevel(level string) ([]GeoBoundariesEntry, error) {
	var apiURL string
	switch level {
	case "ADM1":
		apiURL = geoBoundariesADM1API
	case "ADM2":
		apiURL = geoBoundariesADM2API
	default:
		return nil, fmt.Errorf("unknown level: %s", level)
	}

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(apiURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned %d", resp.StatusCode)
	}

	var entries []GeoBoundariesEntry
	if err := json.NewDecoder(resp.Body).Decode(&entries); err != nil {
		return nil, err
	}
	return entries, nil
}

func downloadAll(entries []GeoBoundariesEntry, dataDir string, concurrency int, dryRun, verbose bool) {
	jobs := make(chan GeoBoundariesEntry, len(entries))
	results := make(chan downloadResult, len(entries))

	var downloaded, skipped, failed atomic.Int32
	var wg sync.WaitGroup

	// Start workers
	for i := 0; i < concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for entry := range jobs {
				result := downloadOne(entry, dataDir, dryRun, verbose)
				results <- result
			}
		}()
	}

	// Send jobs
	go func() {
		for _, e := range entries {
			jobs <- e
		}
		close(jobs)
	}()

	// Collect results
	go func() {
		wg.Wait()
		close(results)
	}()

	// Print progress
	total := len(entries)
	processed := 0
	start := time.Now()

	for r := range results {
		processed++
		switch {
		case r.err != nil:
			failed.Add(1)
			fmt.Printf("[%3d/%d] FAIL %s: %v\n", processed, total, r.iso, r.err)
		case r.skipped:
			skipped.Add(1)
			if verbose {
				fmt.Printf("[%3d/%d] SKIP %s (exists)\n", processed, total, r.iso)
			}
		default:
			downloaded.Add(1)
			size := float64(r.size) / 1024
			if size > 1024 {
				fmt.Printf("[%3d/%d] OK   %s - %.1f MB\n", processed, total, r.iso, size/1024)
			} else {
				fmt.Printf("[%3d/%d] OK   %s - %.0f KB\n", processed, total, r.iso, size)
			}
		}
	}

	fmt.Printf("\n=== Download Summary ===\n")
	fmt.Printf("Downloaded: %d\n", downloaded.Load())
	fmt.Printf("Skipped:    %d (already exist)\n", skipped.Load())
	fmt.Printf("Failed:     %d\n", failed.Load())
	fmt.Printf("Time:       %s\n", time.Since(start).Round(time.Second))
	fmt.Printf("Directory:  %s\n", dataDir)
}

type downloadResult struct {
	iso     string
	size    int64
	skipped bool
	err     error
}

func downloadOne(entry GeoBoundariesEntry, dataDir string, dryRun, verbose bool) downloadResult {
	// Use the BoundaryType from API (ADM1 or ADM2)
	outPath := filepath.Join(dataDir, fmt.Sprintf("geoBoundaries-%s-%s.geojson", entry.BoundaryISO, entry.BoundaryType))

	// Check if exists
	if info, err := os.Stat(outPath); err == nil {
		return downloadResult{iso: entry.BoundaryISO, size: info.Size(), skipped: true}
	}

	if dryRun {
		return downloadResult{iso: entry.BoundaryISO}
	}

	// Download
	client := &http.Client{Timeout: 5 * time.Minute}
	resp, err := client.Get(entry.GJDownloadURL)
	if err != nil {
		return downloadResult{iso: entry.BoundaryISO, err: err}
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return downloadResult{iso: entry.BoundaryISO, err: fmt.Errorf("HTTP %d", resp.StatusCode)}
	}

	// Write to temp file first
	tmpPath := outPath + ".tmp"
	f, err := os.Create(tmpPath)
	if err != nil {
		return downloadResult{iso: entry.BoundaryISO, err: err}
	}

	size, err := io.Copy(f, resp.Body)
	f.Close()
	if err != nil {
		os.Remove(tmpPath)
		return downloadResult{iso: entry.BoundaryISO, err: err}
	}

	// Rename to final
	if err := os.Rename(tmpPath, outPath); err != nil {
		os.Remove(tmpPath)
		return downloadResult{iso: entry.BoundaryISO, err: err}
	}

	return downloadResult{iso: entry.BoundaryISO, size: size}
}

// =============================================================================
// IMPORT COMMAND
// =============================================================================

// GeoJSONFeatureCollection represents a GeoJSON FeatureCollection
type GeoJSONFeatureCollection struct {
	Type     string           `json:"type"`
	Features []GeoJSONFeature `json:"features"`
}

// GeoJSONFeature represents a GeoJSON Feature
type GeoJSONFeature struct {
	Type       string                 `json:"type"`
	Properties map[string]interface{} `json:"properties"`
	Geometry   json.RawMessage        `json:"geometry"`
}

// ImportStats tracks import results
type ImportStats struct {
	CountriesMatched   int
	CountriesUnmatched int
	RegionsMatched     int
	RegionsUnmatched   int
	DistrictsMatched   int
	DistrictsUnmatched int
	Errors             []string
}

func cmdImport(args []string) {
	var (
		all             bool
		countries       string
		dataDir         string
		level           string // ADM1 or ADM2
		assignHierarchy bool
		diagnostics     bool
		dryRun          bool
		verbose         bool
	)

	level = "ADM2" // default
	assignHierarchy = true
	diagnostics = true

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--all", "-a":
			all = true
		case "--countries", "-c":
			if i+1 < len(args) {
				countries = args[i+1]
				i++
			}
		case "--dir", "-d":
			if i+1 < len(args) {
				dataDir = args[i+1]
				i++
			}
		case "--level", "-l":
			if i+1 < len(args) {
				level = strings.ToUpper(args[i+1])
				i++
			}
		case "--no-hierarchy":
			assignHierarchy = false
		case "--no-diagnostics":
			diagnostics = false
		case "--dry-run", "-n":
			dryRun = true
		case "--verbose", "-v":
			verbose = true
		case "--help", "-h":
			fmt.Println(`Import geoBoundaries into database

Usage:
  import-geo-boundaries import [flags]

Flags:
  --all, -a              Import all downloaded files
  --countries, -c LIST   Comma-separated ISO codes (ISO2 or ISO3)
  --dir, -d PATH         Data directory (default: data/geoboundaries)
  --level, -l LEVEL      ADM1 (regions) or ADM2 (districts). Default: ADM2
  --no-hierarchy         Skip running assign_all_city_hierarchy()
  --no-diagnostics       Skip diagnostic queries
  --dry-run, -n          Show what would be imported
  --verbose, -v          Show detailed progress
  --help, -h             Show this help

Environment:
  DATABASE_URL           PostgreSQL connection string (required)

Note: ADM1 (region) boundaries MUST be imported before ADM2 (district) boundaries
for countries with multiple regions. This enables accurate point-in-polygon matching.`)
			return
		}
	}

	if dataDir == "" {
		dataDir = defaultDataDir
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL environment variable is required")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	// Build ISO3 -> ISO2 mapping from database
	buildISO3MappingFromDB(ctx, pool)

	// File suffix based on level
	fileSuffix := fmt.Sprintf("-%s.geojson", level)

	// Find files to import
	var codes []string
	if all {
		pattern := filepath.Join(dataDir, "geoBoundaries-*"+fileSuffix)
		files, err := filepath.Glob(pattern)
		if err != nil {
			log.Fatalf("Failed to list files: %v", err)
		}
		for _, f := range files {
			base := filepath.Base(f)
			if strings.HasPrefix(base, "geoBoundaries-") && strings.HasSuffix(base, fileSuffix) {
				code := strings.TrimPrefix(base, "geoBoundaries-")
				code = strings.TrimSuffix(code, fileSuffix)
				codes = append(codes, code)
			}
		}
	} else if countries != "" {
		// Parse codes - accept both ISO2 and ISO3
		for _, c := range strings.Split(countries, ",") {
			c = strings.TrimSpace(strings.ToUpper(c))
			if len(c) == 2 {
				// Convert ISO2 to ISO3 for file lookup
				for iso3, iso2 := range iso3ToISO2 {
					if iso2 == c {
						codes = append(codes, iso3)
						break
					}
				}
			} else if len(c) == 3 {
				codes = append(codes, c)
			}
		}
	} else {
		fmt.Fprintln(os.Stderr, "Error: specify --all or --countries")
		os.Exit(1)
	}

	if len(codes) == 0 {
		fmt.Printf("No %s files found to import\n", level)
		return
	}

	fmt.Printf("Will import %s for %d countries: %s\n\n", level, len(codes), strings.Join(codes, ", "))

	stats := &ImportStats{}

	// Import each country
	for _, code := range codes {
		filePath := filepath.Join(dataDir, fmt.Sprintf("geoBoundaries-%s-%s.geojson", code, level))
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			log.Printf("Warning: File not found for %s, skipping", code)
			continue
		}

		// Convert ISO3 to ISO2 for database lookup
		iso2Code, found := iso3ToISO2[code]
		if !found {
			log.Printf("Warning: No ISO2 mapping for %s, skipping", code)
			continue
		}

		switch level {
		case "ADM1":
			log.Printf("Importing region boundaries for %s (ISO2: %s)...", code, iso2Code)
			if err := importRegionsFromGeoBoundaries(ctx, pool, dataDir, code, iso2Code, dryRun, verbose, stats); err != nil {
				log.Printf("Warning: Failed to import %s: %v", code, err)
			}
		case "ADM2":
			log.Printf("Importing district boundaries for %s (ISO2: %s)...", code, iso2Code)
			if err := importDistricts(ctx, pool, dataDir, code, iso2Code, dryRun, verbose, stats); err != nil {
				log.Printf("Warning: Failed to import %s: %v", code, err)
			}
		}
	}

	// Run hierarchy assignment (only for ADM2)
	if assignHierarchy && !dryRun && level == "ADM2" && stats.DistrictsMatched > 0 {
		fmt.Println("\n=== Running City Hierarchy Assignment ===")
		if err := runHierarchyAssignment(ctx, pool); err != nil {
			log.Printf("Warning: Failed to run hierarchy assignment: %v", err)
		}
	}

	// Print summary
	fmt.Println("\n=== Import Summary ===")
	fmt.Printf("Districts matched:   %d\n", stats.DistrictsMatched)
	fmt.Printf("Districts unmatched: %d\n", stats.DistrictsUnmatched)
	if len(stats.Errors) > 0 {
		fmt.Printf("Errors: %d\n", len(stats.Errors))
		for _, e := range stats.Errors {
			fmt.Printf("  - %s\n", e)
		}
	}

	// Show diagnostics
	if diagnostics && !dryRun {
		fmt.Println("\n=== Diagnostic Queries ===")
		runDiagnosticQueries(ctx, pool)
	}
}

// buildISO3MappingFromDB builds the ISO3->ISO2 mapping from the database
func buildISO3MappingFromDB(ctx context.Context, pool *pgxpool.Pool) {
	rows, err := pool.Query(ctx, "SELECT code, code_iso3 FROM geo_countries WHERE code_iso3 IS NOT NULL")
	if err != nil {
		log.Printf("Warning: Could not build ISO mapping from database: %v", err)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var iso2, iso3 string
		if err := rows.Scan(&iso2, &iso3); err != nil {
			continue
		}
		iso3ToISO2[iso3] = iso2
	}
	log.Printf("Built ISO3->ISO2 mapping for %d countries from database", len(iso3ToISO2))
}

// =============================================================================
// STATUS COMMAND
// =============================================================================

func cmdStatus(args []string) {
	dataDir := defaultDataDir

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--dir", "-d":
			if i+1 < len(args) {
				dataDir = args[i+1]
				i++
			}
		case "--help", "-h":
			fmt.Println(`Show download and import status

Usage:
  import-geo-boundaries status [flags]

Flags:
  --dir, -d PATH    Data directory (default: data/geoboundaries)
  --help, -h        Show this help`)
			return
		}
	}

	// Check downloaded files
	fmt.Println("=== Downloaded Files ===")
	files, _ := filepath.Glob(filepath.Join(dataDir, "geoBoundaries-*-ADM2.geojson"))

	if len(files) == 0 {
		fmt.Printf("No files found in %s\n", dataDir)
		fmt.Println("\nRun: import-geo-boundaries download --all")
	} else {
		var totalSize int64
		for _, f := range files {
			if info, err := os.Stat(f); err == nil {
				totalSize += info.Size()
			}
		}
		fmt.Printf("Directory: %s\n", dataDir)
		fmt.Printf("Files:     %d countries\n", len(files))
		fmt.Printf("Total:     %.1f MB\n", float64(totalSize)/1024/1024)
	}

	// Check database
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		fmt.Println("\n(Set DATABASE_URL to see database status)")
		return
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		fmt.Printf("\nFailed to connect to database: %v\n", err)
		return
	}
	defer pool.Close()

	fmt.Println("\n=== Database Status ===")

	var districtCount, districtWithBoundary int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_districts").Scan(&districtCount)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_district_boundaries").Scan(&districtWithBoundary)
	fmt.Printf("Districts:          %d total, %d with boundaries\n", districtCount, districtWithBoundary)

	var regionCount, regionWithBoundary int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_regions").Scan(&regionCount)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_region_boundaries").Scan(&regionWithBoundary)
	fmt.Printf("Regions:            %d total, %d with boundaries\n", regionCount, regionWithBoundary)

	var countryCount, countryWithBoundary int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_countries").Scan(&countryCount)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_country_boundaries").Scan(&countryWithBoundary)
	fmt.Printf("Countries:          %d total, %d with boundaries\n", countryCount, countryWithBoundary)

	var cityTotal, cityWithRegion, cityWithDistrict int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM cities").Scan(&cityTotal)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM cities WHERE region_id IS NOT NULL").Scan(&cityWithRegion)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM cities WHERE district_id IS NOT NULL").Scan(&cityWithDistrict)
	fmt.Printf("Cities:             %d total, %d with region, %d with district\n", cityTotal, cityWithRegion, cityWithDistrict)

	// Show ISO code mapping status
	var withISO3 int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_countries WHERE code_iso3 IS NOT NULL").Scan(&withISO3)
	fmt.Printf("\nISO3 codes:         %d/%d countries have ISO3 mapping\n", withISO3, countryCount)
}

// =============================================================================
// SEED COMMAND - Complete geographic database seeding from online sources
// =============================================================================

func cmdSeed(args []string) {
	var (
		verbose bool
	)

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--verbose", "-v":
			verbose = true
		case "--help", "-h":
			fmt.Println(`Complete geographic data seed from online sources

This command performs a COMPLETE seed of all geographic data directly from
authoritative online sources. No options needed - it does everything:

  1. Reset all existing geo data
  2. Load countries from GeoNames (with ISO2/ISO3 codes)
  3. Load regions from GeoNames (admin1)
  4. Load cities from GeoNames (cities15000)
  5. Download ADM1 (region) boundaries from geoBoundaries
  6. Import ADM1 boundaries (required for district matching)
  7. Download ADM2 (district) boundaries from geoBoundaries
  8. Import ADM2 boundaries (using point-in-polygon to assign to regions)
  9. Assign cities to geographic hierarchy

Usage:
  import-geo-boundaries seed [flags]

Flags:
  --verbose, -v    Show detailed progress
  --help, -h       Show this help

Environment:
  DATABASE_URL     PostgreSQL connection string (required)

Example:
  import-geo-boundaries seed`)
			return
		}
	}

	dataDir := defaultDataDir
	concurrency := defaultConcurrent

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL environment variable is required")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	start := time.Now()
	fmt.Println("===================================================================")
	fmt.Println("       Complete Geographic Data Seed - From Online Sources         ")
	fmt.Println("===================================================================")
	fmt.Println()
	fmt.Println("Data Sources (all fetched live, no CSV files):")
	fmt.Println("  - Countries + ISO codes: GeoNames countryInfo.txt")
	fmt.Println("  - Regions (ADM1):        GeoNames admin1CodesASCII.txt")
	fmt.Println("  - Cities:                GeoNames cities15000.zip")
	fmt.Println("  - Region boundaries:     geoBoundaries.org ADM1 API")
	fmt.Println("  - District boundaries:   geoBoundaries.org ADM2 API")
	fmt.Println()

	// Step 1: Reset ALL geo data
	fmt.Println("--- Step 1: Reset Database ---")
	fmt.Println("Clearing ALL geographic data...")
	if err := resetAllGeoData(ctx, pool); err != nil {
		log.Fatalf("Failed to reset: %v", err)
	}
	fmt.Println("OK")
	fmt.Println()

	// Step 2: Load countries from GeoNames
	fmt.Println("--- Step 2: Load Countries from GeoNames ---")
	countryCount, err := loadCountriesFromGeoNames(ctx, pool)
	if err != nil {
		log.Fatalf("Failed to load countries: %v", err)
	}
	fmt.Printf("OK Loaded %d countries with ISO2/ISO3 codes\n", countryCount)
	fmt.Println()

	// Step 3: Load regions from GeoNames
	fmt.Println("--- Step 3: Load Regions from GeoNames ---")
	regionCount, err := loadRegionsFromGeoNames(ctx, pool)
	if err != nil {
		log.Fatalf("Failed to load regions: %v", err)
	}
	fmt.Printf("OK Loaded %d regions\n", regionCount)
	fmt.Println()

	// Step 4: Load cities from GeoNames
	fmt.Println("--- Step 4: Load Cities from GeoNames ---")
	cityCount, err := loadCitiesFromGeoNames(ctx, pool)
	if err != nil {
		log.Fatalf("Failed to load cities: %v", err)
	}
	fmt.Printf("OK Loaded %d cities\n", cityCount)
	fmt.Println()

	// Build ISO mapping from database
	buildISO3MappingFromDB(ctx, pool)

	if err := os.MkdirAll(dataDir, 0755); err != nil {
		log.Fatalf("Failed to create directory: %v", err)
	}

	// Step 5: Download ADM1 (region) boundaries
	fmt.Println("--- Step 5: Download ADM1 (Region) Boundaries ---")
	adm1Entries, err := fetchGeoBoundariesAPILevel("ADM1")
	if err != nil {
		log.Fatalf("Failed to fetch ADM1 API: %v", err)
	}
	fmt.Printf("Found %d countries with ADM1 boundaries\n", len(adm1Entries))
	downloadAll(adm1Entries, dataDir, concurrency, false, verbose)
	fmt.Println()

	// Step 6: Import ADM1 boundaries
	fmt.Println("--- Step 6: Import ADM1 (Region) Boundaries ---")
	adm1Stats := &ImportStats{}
	for _, entry := range adm1Entries {
		iso3Code := entry.BoundaryISO
		iso2Code, found := iso3ToISO2[iso3Code]
		if !found {
			continue
		}

		filePath := filepath.Join(dataDir, fmt.Sprintf("geoBoundaries-%s-ADM1.geojson", iso3Code))
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			continue
		}

		if err := importRegionsFromGeoBoundaries(ctx, pool, dataDir, iso3Code, iso2Code, false, verbose, adm1Stats); err != nil {
			if verbose {
				log.Printf("  Warning: Failed to import ADM1 for %s: %v", iso3Code, err)
			}
		}
	}
	fmt.Printf("OK Imported %d region boundaries\n", adm1Stats.RegionsMatched)
	fmt.Println()

	// Step 7: Download ADM2 (district) boundaries
	fmt.Println("--- Step 7: Download ADM2 (District) Boundaries ---")
	adm2Entries, err := fetchGeoBoundariesAPILevel("ADM2")
	if err != nil {
		log.Fatalf("Failed to fetch ADM2 API: %v", err)
	}
	fmt.Printf("Found %d countries with ADM2 boundaries\n", len(adm2Entries))
	downloadAll(adm2Entries, dataDir, concurrency, false, verbose)
	fmt.Println()

	// Step 8: Import ADM2 boundaries
	fmt.Println("--- Step 8: Import ADM2 (District) Boundaries ---")
	adm2Stats := &ImportStats{}
	var importedCount, skippedCount int
	for _, entry := range adm2Entries {
		iso3Code := entry.BoundaryISO
		iso2Code, found := iso3ToISO2[iso3Code]
		if !found {
			continue
		}

		filePath := filepath.Join(dataDir, fmt.Sprintf("geoBoundaries-%s-ADM2.geojson", iso3Code))
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			continue
		}

		if err := importDistricts(ctx, pool, dataDir, iso3Code, iso2Code, false, verbose, adm2Stats); err != nil {
			// Expected for multi-region countries without ADM1 boundaries
			skippedCount++
			if verbose {
				log.Printf("  Skipped %s: %v", iso3Code, err)
			}
		} else {
			importedCount++
		}
	}
	fmt.Printf("OK Imported districts for %d countries (%d skipped - missing region boundaries)\n", importedCount, skippedCount)
	fmt.Printf("   Total districts: %d\n", adm2Stats.DistrictsMatched)
	fmt.Println()

	// Step 9: Hierarchy assignment
	fmt.Println("--- Step 9: Assign City Hierarchy ---")
	if err := runHierarchyAssignment(ctx, pool); err != nil {
		log.Printf("Warning: Failed to run hierarchy assignment: %v", err)
	}
	fmt.Println()

	// Step 10: Final diagnostics
	fmt.Println("--- Step 10: Final Status ---")
	runDiagnosticQueries(ctx, pool)

	elapsed := time.Since(start).Round(time.Second)
	fmt.Println()
	fmt.Println("===================================================================")
	fmt.Printf("  COMPLETE - Total time: %s\n", elapsed)
	fmt.Println("===================================================================")
}

// resetAllGeoData clears ALL geographic data (cities, regions, countries, districts)
func resetAllGeoData(ctx context.Context, pool *pgxpool.Pool) error {
	queries := []struct {
		desc  string
		query string
	}{
		{"Clearing city district assignments", "UPDATE cities SET district_id = NULL WHERE district_id IS NOT NULL"},
		{"Clearing district boundaries", "DELETE FROM geo_district_boundaries"},
		{"Clearing districts", "DELETE FROM geo_districts"},
		{"Deleting cities", "DELETE FROM cities"},
		{"Clearing region boundaries", "DELETE FROM geo_region_boundaries"},
		{"Truncating regions", "TRUNCATE geo_regions RESTART IDENTITY CASCADE"},
		{"Clearing country boundaries", "DELETE FROM geo_country_boundaries"},
		{"Truncating countries", "TRUNCATE geo_countries RESTART IDENTITY CASCADE"},
	}

	for _, q := range queries {
		fmt.Printf("  %s...\n", q.desc)
		result, err := pool.Exec(ctx, q.query)
		if err != nil {
			return fmt.Errorf("%s: %w", q.desc, err)
		}
		fmt.Printf("    %d rows affected\n", result.RowsAffected())
	}

	return nil
}

// =============================================================================
// SHARED HELPERS
// =============================================================================

func runHierarchyAssignment(ctx context.Context, pool *pgxpool.Pool) error {
	rows, err := pool.Query(ctx, "SELECT * FROM assign_all_city_hierarchy()")
	if err != nil {
		return fmt.Errorf("failed to run assign_all_city_hierarchy: %w", err)
	}
	defer rows.Close()

	fmt.Println("Level          Updated    Unmatched")
	fmt.Println("-------------  ---------  ---------")
	for rows.Next() {
		var level string
		var updated, unmatched int
		if err := rows.Scan(&level, &updated, &unmatched); err != nil {
			return fmt.Errorf("failed to scan result: %w", err)
		}
		fmt.Printf("%-13s  %9d  %9d\n", level, updated, unmatched)
	}
	return nil
}

func runDiagnosticQueries(ctx context.Context, pool *pgxpool.Pool) {
	// 1. Boundary coverage
	fmt.Println("\n1. Boundary Coverage Summary:")
	fmt.Println("   Level       Total    With Boundaries")
	fmt.Println("   ----------  -------  ---------------")

	var countryTotal, countryWithBoundary int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_countries").Scan(&countryTotal)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_country_boundaries").Scan(&countryWithBoundary)
	fmt.Printf("   Countries   %7d  %15d\n", countryTotal, countryWithBoundary)

	var regionTotal, regionWithBoundary int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_regions").Scan(&regionTotal)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_region_boundaries").Scan(&regionWithBoundary)
	fmt.Printf("   Regions     %7d  %15d\n", regionTotal, regionWithBoundary)

	var districtTotal, districtWithBoundary int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_districts").Scan(&districtTotal)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_district_boundaries").Scan(&districtWithBoundary)
	fmt.Printf("   Districts   %7d  %15d\n", districtTotal, districtWithBoundary)

	// 2. City assignment by country
	fmt.Println("\n2. City Assignment by Country (Top 10):")
	fmt.Println("   Country  Total     With Region  With District")
	fmt.Println("   -------  --------  -----------  -------------")

	rows, err := pool.Query(ctx, `
		SELECT co.code, COUNT(*) as total,
			COUNT(c.region_id) as with_region,
			COUNT(c.district_id) as with_district
		FROM cities c
		JOIN geo_regions r ON c.region_id = r.id
		JOIN geo_countries co ON r.country_id = co.id
		GROUP BY co.id, co.code
		ORDER BY total DESC
		LIMIT 10
	`)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var code string
			var total, withRegion, withDistrict int
			rows.Scan(&code, &total, &withRegion, &withDistrict)
			fmt.Printf("   %-7s  %8d  %11d  %13d\n", code, total, withRegion, withDistrict)
		}
	}

	// 3. ISO3 mapping verification
	fmt.Println("\n3. ISO Code Mapping Sample:")
	sampleRows, err := pool.Query(ctx, `
		SELECT code, code_iso3, name
		FROM geo_countries
		WHERE code_iso3 IS NOT NULL
		ORDER BY population DESC NULLS LAST
		LIMIT 5
	`)
	if err == nil {
		defer sampleRows.Close()
		fmt.Println("   ISO2  ISO3  Country")
		fmt.Println("   ----  ----  -------------------------")
		for sampleRows.Next() {
			var code, iso3, name string
			sampleRows.Scan(&code, &iso3, &name)
			if len(name) > 25 {
				name = name[:22] + "..."
			}
			fmt.Printf("   %-4s  %-4s  %s\n", code, iso3, name)
		}
	}
}
