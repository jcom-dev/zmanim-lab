// Package main imports geographic data from Who's On First (WOF) + SRTM elevation.
//
// WOF is the SINGLE SOURCE OF TRUTH for geographic hierarchy:
//   - Countries (placetype=country)
//   - Regions (placetype=region) - states, provinces
//   - Districts (placetype=county) - counties, boroughs
//   - Cities (placetype=locality)
//
// Each WOF record contains wof:hierarchy with direct ID links:
//
//	{"country_id": 85633147, "region_id": 85683255, "county_id": 102072387, "locality_id": 101750223}
//
// NO name matching. NO point-in-polygon. Just direct WOF ID references.
//
// SRTM provides elevation data (critical for zmanim calculations).
//
// Data Sources:
//   - WOF: https://data.geocode.earth/wof/dist/sqlite/whosonfirst-data-admin-latest.db.bz2 (~8.6GB)
//   - SRTM: https://opentopography.s3.sdsc.edu/raster/SRTM_GL1/ (~30GB for all tiles)
package main

import (
	"compress/bzip2"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/mattn/go-sqlite3"
	"github.com/tkrajina/go-elevations/geoelevations"
)

const (
	wofAdminDBURL  = "https://data.geocode.earth/wof/dist/sqlite/whosonfirst-data-admin-latest.db.bz2"
	defaultDataDir = "data/wof"
	defaultDBFile  = "whosonfirst-data-admin-latest.db"
	srtmCacheDir   = "data/srtm"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}

	switch os.Args[1] {
	case "download":
		cmdDownload(os.Args[2:])
	case "import":
		cmdImport(os.Args[2:])
	case "seed":
		cmdSeed(os.Args[2:])
	case "status":
		cmdStatus(os.Args[2:])
	case "reset":
		cmdReset(os.Args[2:])
	case "help", "-h", "--help":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", os.Args[1])
		usage()
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintf(os.Stderr, `WOF Geographic Data Import Tool

Single source of truth for geographic hierarchy + SRTM elevation.

Commands:
  download    Download WOF SQLite database (~8.6GB compressed → ~40GB)
  import      Import WOF data into PostgreSQL + lookup SRTM elevation
  seed        Download + import in one step
  status      Show current status
  reset       Nuclear wipe - delete ALL geographic data from database

Environment:
  DATABASE_URL    PostgreSQL connection string (required for import/seed)

Data Sources:
  WOF:  %s
  SRTM: OpenTopography S3 (tiles downloaded on-demand, cached locally)

Hierarchy (from wof:hierarchy property - NO matching needed):
  country_id  → geo_countries
  region_id   → geo_regions
  county_id   → geo_districts
  locality_id → cities
`, wofAdminDBURL)
}

// =============================================================================
// DOWNLOAD
// =============================================================================

func cmdDownload(args []string) {
	dataDir := defaultDataDir
	forceDownload := false
	for i := 0; i < len(args); i++ {
		if args[i] == "--dir" && i+1 < len(args) {
			dataDir = args[i+1]
			i++
		}
		if args[i] == "--force" || args[i] == "-f" {
			forceDownload = true
		}
	}

	if err := os.MkdirAll(dataDir, 0755); err != nil {
		log.Fatalf("Failed to create directory: %v", err)
	}

	dbPath := filepath.Join(dataDir, defaultDBFile)
	tmpPath := dbPath + ".tmp"

	// Clean up any stale .tmp file from interrupted downloads
	if _, err := os.Stat(tmpPath); err == nil {
		fmt.Printf("Removing stale temp file: %s\n", tmpPath)
		os.Remove(tmpPath)
	}

	// Skip if already downloaded (unless --force)
	if info, err := os.Stat(dbPath); err == nil && !forceDownload {
		fmt.Printf("✓ Already downloaded: %s (%.1f GB)\n", dbPath, float64(info.Size())/1e9)
		fmt.Println("  Use --force to re-download")
		return
	}

	fmt.Println("Downloading WOF admin database...")
	fmt.Printf("Source: %s\n", wofAdminDBURL)
	fmt.Printf("Target: %s\n", dbPath)
	fmt.Println("Size: ~8.6GB compressed → ~40GB uncompressed")
	fmt.Println("This may take 30-60 minutes...\n")

	if err := downloadBZ2(wofAdminDBURL, dbPath); err != nil {
		log.Fatalf("Download failed: %v", err)
	}

	info, _ := os.Stat(dbPath)
	fmt.Printf("\nDone: %s (%.1f GB)\n", dbPath, float64(info.Size())/1e9)
}

func downloadBZ2(url, destPath string) error {
	tmpPath := destPath + ".tmp"
	defer os.Remove(tmpPath)

	out, err := os.Create(tmpPath)
	if err != nil {
		return err
	}
	defer out.Close()

	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	fmt.Printf("Downloading and decompressing (%.1f GB compressed)...\n", float64(resp.ContentLength)/1e9)

	pr := &progressReader{r: resp.Body, total: resp.ContentLength, start: time.Now()}
	bzr := bzip2.NewReader(pr)

	if _, err := io.Copy(out, bzr); err != nil {
		return err
	}

	out.Close()
	return os.Rename(tmpPath, destPath)
}

type progressReader struct {
	r       io.Reader
	total   int64
	read    int64
	start   time.Time
	lastLog time.Time
}

func (p *progressReader) Read(b []byte) (int, error) {
	n, err := p.r.Read(b)
	p.read += int64(n)
	if time.Since(p.lastLog) > 5*time.Second {
		p.lastLog = time.Now()
		pct := float64(p.read) / float64(p.total) * 100
		elapsed := time.Since(p.start)
		speed := float64(p.read) / elapsed.Seconds() / 1e6
		eta := time.Duration(float64(p.total-p.read)/float64(p.read)*float64(elapsed))
		fmt.Printf("  %.1f%% (%.1f MB/s, ETA %s)\n", pct, speed, eta.Round(time.Second))
	}
	return n, err
}

// =============================================================================
// IMPORT
// =============================================================================

func cmdImport(args []string) {
	dataDir := defaultDataDir
	verbose := false
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--dir":
			if i+1 < len(args) {
				dataDir = args[i+1]
				i++
			}
		case "-v", "--verbose":
			verbose = true
		}
	}

	dbPath := filepath.Join(dataDir, defaultDBFile)
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		log.Fatalf("WOF database not found: %s\nRun 'import-wof download' first.", dbPath)
	}

	pgURL := os.Getenv("DATABASE_URL")
	if pgURL == "" {
		log.Fatal("DATABASE_URL required")
	}

	ctx := context.Background()

	// Open WOF SQLite
	wofDB, err := sql.Open("sqlite3", dbPath+"?mode=ro")
	if err != nil {
		log.Fatalf("Failed to open WOF: %v", err)
	}
	defer wofDB.Close()

	// Open PostgreSQL
	pgPool, err := pgxpool.New(ctx, pgURL)
	if err != nil {
		log.Fatalf("Failed to connect to PostgreSQL: %v", err)
	}
	defer pgPool.Close()

	// Initialize SRTM elevation lookup
	if err := os.MkdirAll(srtmCacheDir, 0755); err != nil {
		log.Fatalf("Failed to create SRTM cache dir: %v", err)
	}
	srtm, err := geoelevations.NewSrtmWithCustomCacheDir(http.DefaultClient, srtmCacheDir)
	if err != nil {
		log.Fatalf("Failed to initialize SRTM: %v", err)
	}

	imp := &Importer{
		wofDB:   wofDB,
		pgPool:  pgPool,
		srtm:    srtm,
		verbose: verbose,
		wofToPG: make(map[int64]int64), // WOF ID → PostgreSQL ID
	}

	if err := imp.Run(ctx); err != nil {
		log.Fatalf("Import failed: %v", err)
	}
}

func cmdSeed(args []string) {
	// Check DATABASE_URL first
	if os.Getenv("DATABASE_URL") == "" {
		log.Fatal("DATABASE_URL required")
	}

	// Download if needed
	cmdDownload(args)
	fmt.Println()

	// Import
	cmdImport(args)
}

func cmdStatus(args []string) {
	dataDir := defaultDataDir
	for i := 0; i < len(args); i++ {
		if args[i] == "--dir" && i+1 < len(args) {
			dataDir = args[i+1]
			i++
		}
	}

	// Check WOF file
	dbPath := filepath.Join(dataDir, defaultDBFile)
	fmt.Println("=== WOF Database ===")
	if info, err := os.Stat(dbPath); err == nil {
		fmt.Printf("Path: %s\n", dbPath)
		fmt.Printf("Size: %.1f GB\n", float64(info.Size())/1e9)
	} else {
		fmt.Printf("Not found: %s\n", dbPath)
	}

	// Check SRTM cache
	fmt.Println("\n=== SRTM Cache ===")
	if entries, err := os.ReadDir(srtmCacheDir); err == nil {
		var totalSize int64
		for _, e := range entries {
			if info, err := e.Info(); err == nil {
				totalSize += info.Size()
			}
		}
		fmt.Printf("Path: %s\n", srtmCacheDir)
		fmt.Printf("Tiles: %d\n", len(entries))
		fmt.Printf("Size: %.1f GB\n", float64(totalSize)/1e9)
	} else {
		fmt.Printf("Not found: %s\n", srtmCacheDir)
	}

	// Check PostgreSQL
	pgURL := os.Getenv("DATABASE_URL")
	if pgURL == "" {
		fmt.Println("\n(Set DATABASE_URL to see PostgreSQL status)")
		return
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, pgURL)
	if err != nil {
		fmt.Printf("\nPostgreSQL error: %v\n", err)
		return
	}
	defer pool.Close()

	fmt.Println("\n=== PostgreSQL ===")
	var c, r, d, ci int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_countries").Scan(&c)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_regions").Scan(&r)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM geo_districts").Scan(&d)
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM cities").Scan(&ci)
	fmt.Printf("Countries:  %d\n", c)
	fmt.Printf("Regions:    %d\n", r)
	fmt.Printf("Districts:  %d\n", d)
	fmt.Printf("Cities:     %d\n", ci)
}

// =============================================================================
// RESET (Nuclear Wipe)
// =============================================================================

func cmdReset(args []string) {
	// Check for --confirm flag
	confirmed := false
	for _, arg := range args {
		if arg == "--confirm" || arg == "-y" {
			confirmed = true
		}
	}

	if !confirmed {
		fmt.Println("⚠️  NUCLEAR RESET - This will DELETE ALL geographic data:")
		fmt.Println("")
		fmt.Println("   Tables to be wiped:")
		fmt.Println("   - cities (all rows)")
		fmt.Println("   - geo_districts + geo_district_boundaries")
		fmt.Println("   - geo_regions + geo_region_boundaries")
		fmt.Println("   - geo_countries + geo_country_boundaries")
		fmt.Println("   - geo_continents (imported from WOF)")
		fmt.Println("   - geo_boundary_imports")
		fmt.Println("   - geo_name_mappings")
		fmt.Println("   - publisher_coverage (all geographic coverage)")
		fmt.Println("")
		fmt.Println("   This will NOT delete:")
		fmt.Println("   - publishers (preserved)")
		fmt.Println("   - publisher_zmanim (preserved)")
		fmt.Println("")
		fmt.Println("To proceed, run:")
		fmt.Println("   go run ./cmd/import-wof reset --confirm")
		return
	}

	pgURL := os.Getenv("DATABASE_URL")
	if pgURL == "" {
		log.Fatal("DATABASE_URL not set")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, pgURL)
	if err != nil {
		log.Fatalf("Failed to connect to PostgreSQL: %v", err)
	}
	defer pool.Close()

	fmt.Println("🔥 NUCLEAR RESET - Deleting all geographic data...")
	fmt.Println("")

	// Order matters due to foreign keys - delete from leaf tables first
	tables := []struct {
		name  string
		query string
	}{
		{"publisher_coverage", "DELETE FROM publisher_coverage"},
		{"geo_boundary_imports", "DELETE FROM geo_boundary_imports"},
		{"geo_name_mappings", "DELETE FROM geo_name_mappings"},
		{"cities", "TRUNCATE cities CASCADE"},
		{"geo_district_boundaries", "DELETE FROM geo_district_boundaries"},
		{"geo_districts", "TRUNCATE geo_districts CASCADE"},
		{"geo_region_boundaries", "DELETE FROM geo_region_boundaries"},
		{"geo_regions", "TRUNCATE geo_regions CASCADE"},
		{"geo_country_boundaries", "DELETE FROM geo_country_boundaries"},
		{"geo_countries", "TRUNCATE geo_countries CASCADE"},
		{"geo_continents", "TRUNCATE geo_continents CASCADE"},
	}

	for _, t := range tables {
		result, err := pool.Exec(ctx, t.query)
		if err != nil {
			fmt.Printf("   ❌ %s: %v\n", t.name, err)
		} else {
			fmt.Printf("   ✓ %s: %d rows deleted\n", t.name, result.RowsAffected())
		}
	}

	fmt.Println("")
	fmt.Println("✅ Database reset complete. Ready for fresh import.")
	fmt.Println("   Continents will be imported from WOF during import.")
	fmt.Println("")
	fmt.Println("Next step:")
	fmt.Println("   go run ./cmd/import-wof seed")
}

// =============================================================================
// IMPORTER
// =============================================================================

type Importer struct {
	wofDB           *sql.DB
	pgPool          *pgxpool.Pool
	srtm            *geoelevations.Srtm
	verbose         bool
	wofToPG         map[int64]int64   // WOF ID → PostgreSQL ID (for all placetypes)
	wofContinentMap map[int64]int     // WOF continent ID → our geo_continents.id
	geoNamesBatch   []geoNameEntry    // Batch queue for geo_names inserts
}

// WOFRecord holds data extracted from WOF SQLite
type WOFRecord struct {
	WOFID      int64
	Name       string
	Names      map[string]string // language code -> name (from name:xxx_x_preferred)
	Placetype  string
	Country    string  // ISO2
	Latitude   float64
	Longitude  float64
	Population int64
	Timezone   string
	Geometry   string // GeoJSON geometry
	Hierarchy  map[string]int64
}

// Supported language codes for geo_names (must match languages table)
var supportedLanguages = []string{
	"eng", "heb", "ara", "yid", "rus", "fra", "deu", "spa", "por",
	"zho", "jpn", "kor", "ita", "nld", "pol", "hun", "ukr", "tur", "fas", "hin",
}

// cityNameEntry stores names for batch city import
type cityNameEntry struct {
	wofID int64
	names map[string]string
}

// geoNameEntry holds a single geo_name record for batch insertion
type geoNameEntry struct {
	entityType string
	entityID   string
	lang       string
	name       string
}

// insertGeoNames queues language names for batch insertion (called at flush)
func (imp *Importer) insertGeoNames(ctx context.Context, entityType, entityID string, names map[string]string) {
	for lang, name := range names {
		if name == "" {
			continue
		}
		imp.geoNamesBatch = append(imp.geoNamesBatch, geoNameEntry{
			entityType: entityType,
			entityID:   entityID,
			lang:       lang,
			name:       name,
		})
	}
}

// flushGeoNames batch inserts all queued geo_names using batch INSERT with ON CONFLICT
func (imp *Importer) flushGeoNames(ctx context.Context) error {
	if len(imp.geoNamesBatch) == 0 {
		return nil
	}

	// Use batch INSERT with ON CONFLICT for upsert support
	batch := &pgx.Batch{}
	for _, e := range imp.geoNamesBatch {
		batch.Queue(`
			INSERT INTO geo_names (entity_type, entity_id, language_code, name, is_preferred, source)
			VALUES ($1, $2, $3, $4, true, 'wof')
			ON CONFLICT (entity_type, entity_id, language_code) DO UPDATE SET
				name = EXCLUDED.name
		`, e.entityType, e.entityID, e.lang, e.name)
	}

	br := imp.pgPool.SendBatch(ctx, batch)
	err := br.Close()

	imp.geoNamesBatch = nil
	return err
}

// insertCityGeoNames batch inserts city names using batch INSERT with ON CONFLICT
func (imp *Importer) insertCityGeoNames(ctx context.Context, entries []cityNameEntry) error {
	if len(entries) == 0 {
		return nil
	}

	// Build a map of wof_id -> city uuid in chunks to avoid memory issues
	const chunkSize = 10000
	wofToUUID := make(map[int64]string, len(entries))

	for i := 0; i < len(entries); i += chunkSize {
		end := i + chunkSize
		if end > len(entries) {
			end = len(entries)
		}

		wofIDs := make([]int64, 0, end-i)
		for _, e := range entries[i:end] {
			wofIDs = append(wofIDs, e.wofID)
		}

		rows, err := imp.pgPool.Query(ctx, `SELECT id, wof_id FROM cities WHERE wof_id = ANY($1)`, wofIDs)
		if err != nil {
			return err
		}

		for rows.Next() {
			var id string
			var wofID int64
			if err := rows.Scan(&id, &wofID); err != nil {
				continue
			}
			wofToUUID[wofID] = id
		}
		rows.Close()
	}

	// Use batch INSERT with ON CONFLICT (process in chunks to avoid memory issues)
	const batchSize = 5000
	batch := &pgx.Batch{}
	batchCount := 0

	for _, e := range entries {
		cityID, ok := wofToUUID[e.wofID]
		if !ok {
			continue
		}
		for lang, name := range e.names {
			if name == "" {
				continue
			}
			batch.Queue(`
				INSERT INTO geo_names (entity_type, entity_id, language_code, name, is_preferred, source)
				VALUES ($1, $2, $3, $4, true, 'wof')
				ON CONFLICT (entity_type, entity_id, language_code) DO UPDATE SET
					name = EXCLUDED.name
			`, "city", cityID, lang, name)
			batchCount++

			// Flush batch periodically
			if batchCount >= batchSize {
				br := imp.pgPool.SendBatch(ctx, batch)
				if err := br.Close(); err != nil {
					return err
				}
				batch = &pgx.Batch{}
				batchCount = 0
			}
		}
	}

	// Flush remaining
	if batchCount > 0 {
		br := imp.pgPool.SendBatch(ctx, batch)
		if err := br.Close(); err != nil {
			return err
		}
	}

	return nil
}

// toASCII strips accents from a string for name_ascii column
func toASCII(s string) string {
	// Simple approach: just return as-is for now, can enhance with unicode normalization
	return s
}

func (imp *Importer) Run(ctx context.Context) error {
	start := time.Now()

	// Step 1: Reset
	log.Println("Step 1: Resetting database...")
	if err := imp.reset(ctx); err != nil {
		return err
	}

	// Step 2: Import continents from WOF
	log.Println("Step 2: Importing continents from WOF...")
	continents, err := imp.importContinents(ctx)
	if err != nil {
		return err
	}
	log.Printf("  %d continents", continents)

	// Step 3: Import countries
	log.Println("Step 3: Importing countries...")
	countries, err := imp.importPlacetype(ctx, "country")
	if err != nil {
		return err
	}
	log.Printf("  %d countries", countries)
	if err := imp.flushGeoNames(ctx); err != nil {
		log.Printf("  Warning: failed to flush country names: %v", err)
	}

	// Step 4: Import regions
	log.Println("Step 4: Importing regions...")
	regions, err := imp.importPlacetype(ctx, "region")
	if err != nil {
		return err
	}
	log.Printf("  %d regions", regions)
	if err := imp.flushGeoNames(ctx); err != nil {
		log.Printf("  Warning: failed to flush region names: %v", err)
	}

	// Step 5: Import districts (counties)
	log.Println("Step 5: Importing districts...")
	districts, err := imp.importPlacetype(ctx, "county")
	if err != nil {
		return err
	}
	log.Printf("  %d districts", districts)
	if err := imp.flushGeoNames(ctx); err != nil {
		log.Printf("  Warning: failed to flush district names: %v", err)
	}

	// Step 6: Import cities (localities)
	log.Println("Step 6: Importing cities...")
	cities, err := imp.importCities(ctx)
	if err != nil {
		return err
	}
	log.Printf("  %d cities", cities)

	log.Printf("\nComplete in %s", time.Since(start).Round(time.Second))
	return nil
}

func (imp *Importer) reset(ctx context.Context) error {
	// Delete in FK order (leaf tables first)
	queries := []string{
		"DELETE FROM publisher_coverage",
		"DELETE FROM geo_boundary_imports",
		"DELETE FROM geo_name_mappings",
		"DELETE FROM geo_names",
		"DELETE FROM geo_district_boundaries",
		"DELETE FROM geo_region_boundaries",
		"DELETE FROM geo_country_boundaries",
		"DELETE FROM cities",
		"DELETE FROM geo_districts",
		"DELETE FROM geo_regions",
		"DELETE FROM geo_countries",
		"DELETE FROM geo_continents",
	}
	for _, q := range queries {
		if _, err := imp.pgPool.Exec(ctx, q); err != nil {
			return fmt.Errorf("%s: %w", q, err)
		}
	}

	// Continents will be imported from WOF in importContinents()
	return nil
}

// importContinents imports continents from WOF and builds the wofContinentMap
func (imp *Importer) importContinents(ctx context.Context) (int, error) {
	imp.wofContinentMap = make(map[int64]int)

	// Query WOF for all continents
	rows, err := imp.wofDB.Query(`
		SELECT s.id, s.name
		FROM spr s
		WHERE s.placetype = 'continent'
		  AND s.is_deprecated = 0
		  AND s.is_ceased = 0
		ORDER BY s.name
	`)
	if err != nil {
		return 0, fmt.Errorf("query WOF continents: %w", err)
	}
	defer rows.Close()

	// Generate 2-letter codes from continent names
	nameToCode := map[string]string{
		"Africa":        "AF",
		"Antarctica":    "AN",
		"Asia":          "AS",
		"Europe":        "EU",
		"North America": "NA",
		"Oceania":       "OC",
		"South America": "SA",
		"Seven Seas":    "XS", // Maritime territories get their own code
	}

	var count int
	for rows.Next() {
		var wofID int64
		var name string
		if err := rows.Scan(&wofID, &name); err != nil {
			return 0, fmt.Errorf("scan continent: %w", err)
		}

		// Get code for this continent
		code, ok := nameToCode[name]
		if !ok {
			// Generate code from first 2 chars if unknown
			if len(name) >= 2 {
				code = strings.ToUpper(name[:2])
			} else {
				code = "XX"
			}
			log.Printf("  Warning: Unknown continent %q, using code %s", name, code)
		}

		// Insert into database
		var pgID int
		err := imp.pgPool.QueryRow(ctx, `
			INSERT INTO geo_continents (code, name, wof_id)
			VALUES ($1, $2, $3)
			ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, wof_id = EXCLUDED.wof_id
			RETURNING id
		`, code, name, wofID).Scan(&pgID)
		if err != nil {
			return 0, fmt.Errorf("insert continent %s: %w", name, err)
		}

		imp.wofContinentMap[wofID] = pgID
		count++

		if imp.verbose {
			log.Printf("  Continent: %s (%s) WOF %d → PG %d", name, code, wofID, pgID)
		}
	}

	if count == 0 {
		return 0, fmt.Errorf("no continents found in WOF database")
	}

	return count, nil
}

func (imp *Importer) importPlacetype(ctx context.Context, placetype string) (int, error) {
	// Query WOF for this placetype
	rows, err := imp.wofDB.Query(`
		SELECT s.id, s.name, s.placetype, s.country, s.latitude, s.longitude,
		       g.body
		FROM spr s
		JOIN geojson g ON s.id = g.id AND g.is_alt = 0
		WHERE s.placetype = ?
		  AND s.is_deprecated = 0
		  AND s.is_ceased = 0
		ORDER BY s.name
	`, placetype)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	var count, skipped int
	for rows.Next() {
		rec, err := imp.scanRecord(rows)
		if err != nil {
			return 0, fmt.Errorf("scan %s record: %w", placetype, err)
		}

		pgID, err := imp.insertRecord(ctx, rec)
		if err != nil {
			if errors.Is(err, ErrSkipRecord) {
				log.Printf("  SKIP: %s (WOF %d) - %v", rec.Name, rec.WOFID, err)
				skipped++
				continue
			}
			return 0, fmt.Errorf("insert %s (WOF %d): %w", rec.Name, rec.WOFID, err)
		}

		imp.wofToPG[rec.WOFID] = pgID
		count++

		if imp.verbose && count%1000 == 0 {
			log.Printf("  %d %ss...", count, placetype)
		}
	}

	if skipped > 0 {
		log.Printf("  (skipped %d invalid entries)", skipped)
	}

	return count, nil
}

func (imp *Importer) scanRecord(rows *sql.Rows) (*WOFRecord, error) {
	var rec WOFRecord
	var body string

	if err := rows.Scan(&rec.WOFID, &rec.Name, &rec.Placetype, &rec.Country,
		&rec.Latitude, &rec.Longitude, &body); err != nil {
		return nil, err
	}

	// Parse GeoJSON to extract properties and geometry
	var feature struct {
		Properties map[string]interface{} `json:"properties"`
		Geometry   json.RawMessage        `json:"geometry"`
	}
	if err := json.Unmarshal([]byte(body), &feature); err != nil {
		return nil, err
	}

	rec.Geometry = string(feature.Geometry)

	// Extract hierarchy
	rec.Hierarchy = make(map[string]int64)
	if hier, ok := feature.Properties["wof:hierarchy"].([]interface{}); ok && len(hier) > 0 {
		if h, ok := hier[0].(map[string]interface{}); ok {
			for k, v := range h {
				switch vv := v.(type) {
				case float64:
					rec.Hierarchy[k] = int64(vv)
				case int64:
					rec.Hierarchy[k] = vv
				}
			}
		}
	}

	// Extract timezone
	if tz, ok := feature.Properties["wof:timezone"].(string); ok {
		rec.Timezone = tz
	}

	// Extract population
	if pop, ok := feature.Properties["wof:population"].(float64); ok {
		rec.Population = int64(pop)
	}

	// Extract all available language names
	rec.Names = make(map[string]string)
	for _, lang := range supportedLanguages {
		key := fmt.Sprintf("name:%s_x_preferred", lang)
		if names, ok := feature.Properties[key].([]interface{}); ok && len(names) > 0 {
			if name, ok := names[0].(string); ok && name != "" {
				rec.Names[lang] = name
			}
		}
	}

	return &rec, nil
}

func (imp *Importer) insertRecord(ctx context.Context, rec *WOFRecord) (int64, error) {
	switch rec.Placetype {
	case "country":
		return imp.insertCountry(ctx, rec)
	case "region":
		return imp.insertRegion(ctx, rec)
	case "county":
		return imp.insertDistrict(ctx, rec)
	default:
		return 0, fmt.Errorf("unknown placetype: %s", rec.Placetype)
	}
}

// ErrSkipRecord indicates a record should be skipped (not fatal)
var ErrSkipRecord = fmt.Errorf("skip record")

func (imp *Importer) insertCountry(ctx context.Context, rec *WOFRecord) (int64, error) {
	code := strings.ToUpper(rec.Country)
	if code == "" {
		// Skip entries without country code (like "Null Island")
		if imp.verbose {
			log.Printf("  Skipping %s (WOF %d): no country code", rec.Name, rec.WOFID)
		}
		return 0, ErrSkipRecord
	}

	// Determine continent from WOF hierarchy
	continentID := imp.getContinentID(rec)
	if continentID == 0 {
		// Skip entries without valid continent (like special WOF entries)
		if imp.verbose {
			log.Printf("  Skipping %s (WOF %d): no continent in hierarchy", rec.Name, rec.WOFID)
		}
		return 0, ErrSkipRecord
	}

	var pgID int64
	err := imp.pgPool.QueryRow(ctx, `
		INSERT INTO geo_countries (code, name, continent_id, wof_id)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (code) DO UPDATE SET
			name = EXCLUDED.name,
			wof_id = EXCLUDED.wof_id
		RETURNING id
	`, code, rec.Name, continentID, rec.WOFID).Scan(&pgID)
	if err != nil {
		return 0, err
	}

	// Insert language names into geo_names
	imp.insertGeoNames(ctx, "country", fmt.Sprintf("%d", pgID), rec.Names)

	// Insert boundary if available
	if rec.Geometry != "" && rec.Geometry != "null" {
		imp.pgPool.Exec(ctx, `
			INSERT INTO geo_country_boundaries (country_id, boundary, centroid, area_km2)
			VALUES ($1, ST_GeomFromGeoJSON($2)::geography,
			        ST_Centroid(ST_GeomFromGeoJSON($2))::geography,
			        ST_Area(ST_GeomFromGeoJSON($2)::geography) / 1e6)
			ON CONFLICT (country_id) DO UPDATE SET
				boundary = EXCLUDED.boundary, centroid = EXCLUDED.centroid, area_km2 = EXCLUDED.area_km2
		`, pgID, rec.Geometry)
	}

	return pgID, nil
}

func (imp *Importer) insertRegion(ctx context.Context, rec *WOFRecord) (int64, error) {
	// Get continent (REQUIRED - anchor point for all regions)
	continentID := imp.getContinentID(rec)
	if continentID == 0 {
		return 0, fmt.Errorf("%w: no valid continent in hierarchy for %s", ErrSkipRecord, rec.Name)
	}

	// Get country (optional - must belong to same continent)
	// Overseas territories (e.g., French Guiana/France) have geographic continent != country's continent
	var countryPGID *int64
	countryWOFID := rec.Hierarchy["country_id"]
	if countryWOFID > 0 {
		if pgID, ok := imp.wofToPG[countryWOFID]; ok {
			// Verify country belongs to same continent
			var countryContinent int
			err := imp.pgPool.QueryRow(ctx, "SELECT continent_id FROM geo_countries WHERE id = $1", pgID).Scan(&countryContinent)
			if err == nil && countryContinent == continentID {
				countryPGID = &pgID
			}
			// If country is in different continent (overseas territory), skip setting country_id
		}
	}

	code := fmt.Sprintf("wof-%d", rec.WOFID)

	var pgID int64
	err := imp.pgPool.QueryRow(ctx, `
		INSERT INTO geo_regions (continent_id, country_id, code, name, wof_id)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (wof_id) DO UPDATE SET
			continent_id = EXCLUDED.continent_id,
			country_id = EXCLUDED.country_id,
			name = EXCLUDED.name
		RETURNING id
	`, continentID, countryPGID, code, rec.Name, rec.WOFID).Scan(&pgID)
	if err != nil {
		return 0, err
	}

	// Insert language names into geo_names
	imp.insertGeoNames(ctx, "region", fmt.Sprintf("%d", pgID), rec.Names)

	// Insert boundary
	if rec.Geometry != "" && rec.Geometry != "null" {
		imp.pgPool.Exec(ctx, `
			INSERT INTO geo_region_boundaries (region_id, boundary, centroid, area_km2)
			VALUES ($1, ST_GeomFromGeoJSON($2)::geography,
			        ST_Centroid(ST_GeomFromGeoJSON($2))::geography,
			        ST_Area(ST_GeomFromGeoJSON($2)::geography) / 1e6)
			ON CONFLICT (region_id) DO UPDATE SET
				boundary = EXCLUDED.boundary, centroid = EXCLUDED.centroid, area_km2 = EXCLUDED.area_km2
		`, pgID, rec.Geometry)
	}

	return pgID, nil
}

func (imp *Importer) insertDistrict(ctx context.Context, rec *WOFRecord) (int64, error) {
	// Get continent (REQUIRED - anchor point for all districts)
	continentID := imp.getContinentID(rec)
	if continentID == 0 {
		return 0, fmt.Errorf("%w: no valid continent in hierarchy for %s", ErrSkipRecord, rec.Name)
	}

	// Get country (optional - must belong to same continent)
	// Overseas territories (e.g., New Caledonia/France) have geographic continent != country's continent
	var countryPGID *int64
	countryWOFID := rec.Hierarchy["country_id"]
	if countryWOFID > 0 {
		if pgID, ok := imp.wofToPG[countryWOFID]; ok {
			// Verify country belongs to same continent
			var countryContinent int
			err := imp.pgPool.QueryRow(ctx, "SELECT continent_id FROM geo_countries WHERE id = $1", pgID).Scan(&countryContinent)
			if err == nil && countryContinent == continentID {
				countryPGID = &pgID
			}
			// If country is in different continent (overseas territory), skip setting country_id
		}
	}

	// Get region (optional - must belong to same continent)
	var regionPGID *int64
	regionWOFID := rec.Hierarchy["region_id"]
	if regionWOFID > 0 {
		if pgID, ok := imp.wofToPG[regionWOFID]; ok {
			// Verify region belongs to same continent
			var regionContinent int
			err := imp.pgPool.QueryRow(ctx, "SELECT continent_id FROM geo_regions WHERE id = $1", pgID).Scan(&regionContinent)
			if err == nil && regionContinent == continentID {
				regionPGID = &pgID
				// Inherit country_id from region if we don't have one
				if countryPGID == nil {
					var regionCountryID *int64
					imp.pgPool.QueryRow(ctx, "SELECT country_id FROM geo_regions WHERE id = $1", pgID).Scan(&regionCountryID)
					if regionCountryID != nil {
						countryPGID = regionCountryID
					}
				}
			}
		}
	}

	code := fmt.Sprintf("wof-%d", rec.WOFID)

	var pgID int64
	err := imp.pgPool.QueryRow(ctx, `
		INSERT INTO geo_districts (continent_id, country_id, region_id, code, name, wof_id)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (wof_id) DO UPDATE SET
			continent_id = EXCLUDED.continent_id,
			country_id = EXCLUDED.country_id,
			region_id = EXCLUDED.region_id,
			name = EXCLUDED.name
		RETURNING id
	`, continentID, countryPGID, regionPGID, code, rec.Name, rec.WOFID).Scan(&pgID)
	if err != nil {
		return 0, err
	}

	// Insert language names into geo_names
	imp.insertGeoNames(ctx, "district", fmt.Sprintf("%d", pgID), rec.Names)

	// Insert boundary
	if rec.Geometry != "" && rec.Geometry != "null" {
		imp.pgPool.Exec(ctx, `
			INSERT INTO geo_district_boundaries (district_id, boundary, centroid, area_km2)
			VALUES ($1, ST_GeomFromGeoJSON($2)::geography,
			        ST_Centroid(ST_GeomFromGeoJSON($2))::geography,
			        ST_Area(ST_GeomFromGeoJSON($2)::geography) / 1e6)
			ON CONFLICT (district_id) DO UPDATE SET
				boundary = EXCLUDED.boundary, centroid = EXCLUDED.centroid, area_km2 = EXCLUDED.area_km2
		`, pgID, rec.Geometry)
	}

	return pgID, nil
}

// cityRecord holds pre-processed city data for batch operations
type cityRecord struct {
	continentID int16
	countryID   *int32
	regionID    *int32
	districtID  *int32
	name        string
	lat         float64
	lng         float64
	tz          string
	population  int64
	wofID       int64
	names       map[string]string
	elevation   *int32 // filled in by parallel elevation lookup
}

func (imp *Importer) importCities(ctx context.Context) (int, error) {
	// Disable trigger for bulk import performance (COPY doesn't fire row triggers anyway,
	// but this ensures consistency if we switch to INSERT)
	if _, err := imp.pgPool.Exec(ctx, "ALTER TABLE cities DISABLE TRIGGER trg_validate_city_hierarchy"); err != nil {
		log.Printf("  Warning: could not disable trigger: %v", err)
	}
	defer func() {
		// Re-enable trigger after import
		if _, err := imp.pgPool.Exec(ctx, "ALTER TABLE cities ENABLE TRIGGER trg_validate_city_hierarchy"); err != nil {
			log.Printf("  Warning: could not re-enable trigger: %v", err)
		}
	}()

	// Query WOF for localities
	rows, err := imp.wofDB.Query(`
		SELECT s.id, s.name, s.placetype, s.country, s.latitude, s.longitude,
		       g.body
		FROM spr s
		JOIN geojson g ON s.id = g.id AND g.is_alt = 0
		WHERE s.placetype = 'locality'
		  AND s.is_deprecated = 0
		  AND s.is_ceased = 0
		  AND s.latitude != 0
		  AND s.longitude != 0
		ORDER BY s.country, s.name
	`)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	// Phase 1: Collect all records
	log.Println("  Phase 1: Reading localities from WOF...")
	var records []*cityRecord
	var skipped int

	for rows.Next() {
		rec, err := imp.scanRecord(rows)
		if err != nil {
			return 0, fmt.Errorf("scan locality record: %w", err)
		}

		// Get hierarchy IDs from WOF
		// Cities MUST have a continent (anchor point), everything else is optional

		// Get continent (REQUIRED)
		continentWOFID := rec.Hierarchy["continent_id"]
		var continentPGID int16
		if continentWOFID > 0 {
			if pgID, ok := imp.wofContinentMap[continentWOFID]; ok {
				continentPGID = int16(pgID)
			}
		}

		if continentPGID == 0 {
			if imp.verbose {
				log.Printf("  SKIP: locality %s (WOF %d) - no valid continent", rec.Name, rec.WOFID)
			}
			skipped++
			continue
		}

		// Get optional hierarchy IDs
		var countryPGID, regionPGID, districtPGID *int32
		if countryWOFID := rec.Hierarchy["country_id"]; countryWOFID > 0 {
			if pgID, ok := imp.wofToPG[countryWOFID]; ok {
				v := int32(pgID)
				countryPGID = &v
			}
		}
		if regionWOFID := rec.Hierarchy["region_id"]; regionWOFID > 0 {
			if pgID, ok := imp.wofToPG[regionWOFID]; ok {
				v := int32(pgID)
				regionPGID = &v
			}
		}
		if countyWOFID := rec.Hierarchy["county_id"]; countyWOFID > 0 {
			if pgID, ok := imp.wofToPG[countyWOFID]; ok {
				v := int32(pgID)
				districtPGID = &v
			}
		}

		tz := rec.Timezone
		if tz == "" {
			tz = "UTC"
		}

		records = append(records, &cityRecord{
			continentID: continentPGID,
			countryID:   countryPGID,
			regionID:    regionPGID,
			districtID:  districtPGID,
			name:        rec.Name,
			lat:         rec.Latitude,
			lng:         rec.Longitude,
			tz:          tz,
			population:  rec.Population,
			wofID:       rec.WOFID,
			names:       rec.Names,
		})

		if len(records)%50000 == 0 {
			log.Printf("  Read %d localities...", len(records))
		}
	}
	log.Printf("  Read %d localities total (%d skipped)", len(records), skipped)

	// Phase 2: Parallel elevation lookups
	log.Println("  Phase 2: Looking up elevations (parallel)...")
	var elevationLookups int64
	elevationLookups = imp.lookupElevationsParallel(records)
	log.Printf("  Elevation lookups: %d", elevationLookups)

	// Phase 3: Batch insert into PostgreSQL
	log.Println("  Phase 3: Inserting into PostgreSQL...")
	var count int
	var cityNames []cityNameEntry
	const batchSize = 10000

	for i := 0; i < len(records); i += batchSize {
		end := i + batchSize
		if end > len(records) {
			end = len(records)
		}

		batch := make([][]interface{}, 0, end-i)
		for _, r := range records[i:end] {
			batch = append(batch, []interface{}{
				r.continentID,
				r.countryID,
				r.regionID,
				r.districtID,
				r.name,
				toASCII(r.name),
				r.lat,
				r.lng,
				r.tz,
				r.elevation,
				nullInt32(r.population),
				r.wofID,
			})
			if len(r.names) > 0 {
				cityNames = append(cityNames, cityNameEntry{wofID: r.wofID, names: r.names})
			}
		}

		inserted, err := imp.insertCityBatch(ctx, batch)
		if err != nil {
			return 0, fmt.Errorf("batch insert cities: %w", err)
		}
		count += inserted

		if count%50000 == 0 || end == len(records) {
			log.Printf("  Inserted %d/%d cities...", count, len(records))
		}
	}

	log.Printf("  Total cities inserted: %d", count)

	// Insert city names into geo_names
	if len(cityNames) > 0 {
		log.Printf("  Inserting %d city name translations...", len(cityNames))
		if err := imp.insertCityGeoNames(ctx, cityNames); err != nil {
			log.Printf("  Warning: could not insert city names: %v", err)
		}
	}

	// Validate hierarchy integrity after bulk import
	log.Println("  Validating hierarchy integrity...")
	validationRows, validationErr := imp.pgPool.Query(ctx, "SELECT city_id, city_name, error_type, details FROM validate_all_city_hierarchies()")
	if validationErr != nil {
		log.Printf("  Warning: could not validate hierarchies: %v", validationErr)
	} else {
		defer validationRows.Close()
		var integrityErrors int
		for validationRows.Next() {
			var cityID int64
			var cityName, errorType, details string
			if err := validationRows.Scan(&cityID, &cityName, &errorType, &details); err != nil {
				continue
			}
			log.Printf("  INTEGRITY ERROR: city %d (%s) - %s: %s", cityID, cityName, errorType, details)
			integrityErrors++
		}
		if integrityErrors > 0 {
			return 0, fmt.Errorf("hierarchy integrity validation failed: %d errors found", integrityErrors)
		}
		log.Println("  Hierarchy integrity OK")
	}

	return count, nil
}

// lookupElevationsParallel looks up SRTM elevations for all cities in parallel
// Note: SRTM library internal caching is not fully thread-safe for file I/O,
// so we use a mutex. However, once tiles are cached (which happens early in the
// import), the lookups are fast memory reads.
func (imp *Importer) lookupElevationsParallel(records []*cityRecord) int64 {
	var successCount int64
	var processed int64

	// Process in chunks to show progress
	total := len(records)
	for i, r := range records {
		// Skip if outside SRTM coverage
		if r.lat < -60 || r.lat > 60 {
			continue
		}

		elev, err := imp.srtm.GetElevation(http.DefaultClient, r.lat, r.lng)
		if err == nil {
			e := int32(elev)
			r.elevation = &e
			successCount++
		}

		processed++
		if processed%25000 == 0 {
			log.Printf("    Elevation progress: %d/%d (%.1f%%)", i+1, total, float64(i+1)/float64(total)*100)
		}
	}

	return successCount
}

func (imp *Importer) insertCityBatch(ctx context.Context, batch [][]interface{}) (int, error) {
	// Batch format: [continent_id, country_id, region_id, district_id, name, name_local, lat, lng, tz, elevation, population, wof_id]
	// continent_id is required (anchor point), country/region/district are optional
	// Trigger validates: country belongs to continent, region belongs to country, district belongs to region
	count, err := imp.pgPool.CopyFrom(
		ctx,
		pgx.Identifier{"cities"},
		[]string{"continent_id", "country_id", "region_id", "district_id", "name", "name_ascii",
			"latitude", "longitude", "timezone", "elevation_m", "population", "wof_id"},
		pgx.CopyFromRows(batch),
	)

	return int(count), err
}

// getContinentID looks up the continent for a country using WOF hierarchy.
// Returns 0 if continent cannot be determined (country will be skipped).
func (imp *Importer) getContinentID(rec *WOFRecord) int {
	wofContID := rec.Hierarchy["continent_id"]
	if wofContID == 0 {
		return 0 // No continent in hierarchy
	}

	if ourID, ok := imp.wofContinentMap[wofContID]; ok {
		return ourID
	}

	return 0 // Unknown continent
}

func nullString(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}

func nullInt64(i int64) interface{} {
	if i == 0 {
		return nil
	}
	return i
}

// nullInt32 converts int64 to *int32 for PostgreSQL integer columns, returning nil if zero
func nullInt32(i int64) interface{} {
	if i == 0 {
		return nil
	}
	v := int32(i)
	return v
}
