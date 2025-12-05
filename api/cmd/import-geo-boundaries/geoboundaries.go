// Package main provides geoBoundaries import functionality for ADM1/ADM2 boundaries.
// geoBoundaries (https://www.geoboundaries.org/) provides open-licensed administrative
// boundary data in GeoJSON format with standardized property names.
//
// Key consideration: geoBoundaries uses ISO3 codes (GBR, USA, ISR) in filenames,
// while the database uses ISO2 codes (GB, US, IL). The import functions accept
// both codes to handle this conversion properly.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

// GeoBoundariesFeature represents a feature from geoBoundaries GeoJSON files.
// Standard properties include:
// - shapeName: Name of the administrative unit (e.g., "Manchester")
// - shapeISO: ISO code if available (often empty for ADM2)
// - shapeGroup: Parent grouping code (varies by country)
// - shapeType: Type of boundary (e.g., "ADM1", "ADM2")
// - shapeID: Unique identifier from source data
type GeoBoundariesFeature struct {
	Type       string                 `json:"type"`
	Properties map[string]interface{} `json:"properties"`
	Geometry   json.RawMessage        `json:"geometry"`
}

// DistrictInfo holds database info for matching
type DistrictInfo struct {
	ID       int32
	Code     string
	Name     string
	RegionID int32
}

// RegionLookup holds region info for district parent matching
type RegionLookup struct {
	ID          int32
	Code        string
	Name        string
	CountryCode string
	CountryID   int16
}

// importDistricts imports ADM2 boundaries from geoBoundaries GeoJSON files.
// It creates new geo_districts records if they don't exist and inserts boundaries.
//
// Parameters:
//   - iso3Code: The ISO3 code used in the geoBoundaries filename (e.g., "GBR")
//   - iso2Code: The ISO2 code used in the database (e.g., "GB")
//
// Matching strategy:
// 1. Look for existing geo_districts record by (region_id, name) - case insensitive
// 2. If not found, create new geo_districts record with generated code
// 3. Insert boundary to geo_district_boundaries
//
// The function expects files named like: geoBoundaries-{ISO3}-ADM2.geojson
func importDistricts(ctx context.Context, pool *pgxpool.Pool, dirPath string, iso3Code string, iso2Code string, dryRun, verbose bool, stats *ImportStats) error {
	// Build the expected filename using ISO3 code
	fileName := fmt.Sprintf("geoBoundaries-%s-ADM2.geojson", iso3Code)
	filePath := filepath.Join(dirPath, fileName)

	// Check if file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return fmt.Errorf("file not found: %s", filePath)
	}

	// Read GeoJSON file
	data, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	var fc GeoJSONFeatureCollection
	if err := json.Unmarshal(data, &fc); err != nil {
		return fmt.Errorf("failed to parse GeoJSON: %w", err)
	}

	log.Printf("Found %d district features in %s\n", len(fc.Features), fileName)

	// Get the country from database using ISO2 code
	var countryID int16
	var countryName string
	var hasADM1, hasADM2 bool
	err = pool.QueryRow(ctx, `
		SELECT id, name, has_adm1, has_adm2
		FROM geo_countries
		WHERE code = $1
	`, iso2Code).Scan(&countryID, &countryName, &hasADM1, &hasADM2)
	if err != nil {
		return fmt.Errorf("country %s (ISO2: %s) not found in database: %w", iso3Code, iso2Code, err)
	}

	log.Printf("Processing districts for %s (ISO2: %s, ID: %d, has_adm1: %v, has_adm2: %v)\n",
		countryName, iso2Code, countryID, hasADM1, hasADM2)

	// Enable ADM2 for this country if not already
	if !hasADM2 && !dryRun {
		_, err = pool.Exec(ctx, `UPDATE geo_countries SET has_adm2 = true WHERE id = $1`, countryID)
		if err != nil {
			log.Printf("Warning: Failed to enable has_adm2 for %s: %v\n", iso2Code, err)
		} else {
			log.Printf("Enabled has_adm2 for %s\n", iso2Code)
		}
	}

	// Build lookup maps for regions in this country
	rows, err := pool.Query(ctx, `
		SELECT r.id, r.code, r.name, c.code as country_code, c.id as country_id
		FROM geo_regions r
		JOIN geo_countries c ON r.country_id = c.id
		WHERE c.code = $1
	`, iso2Code)
	if err != nil {
		return fmt.Errorf("failed to query regions: %w", err)
	}
	defer rows.Close()

	// Map region name (lowercase) -> RegionLookup
	regionsByName := make(map[string]RegionLookup)
	// Map region code -> RegionLookup
	regionsByCode := make(map[string]RegionLookup)
	// All regions for this country
	var allRegions []RegionLookup

	for rows.Next() {
		var rl RegionLookup
		if err := rows.Scan(&rl.ID, &rl.Code, &rl.Name, &rl.CountryCode, &rl.CountryID); err != nil {
			return fmt.Errorf("failed to scan region: %w", err)
		}
		regionsByName[strings.ToLower(rl.Name)] = rl
		regionsByCode[rl.Code] = rl
		allRegions = append(allRegions, rl)
	}

	log.Printf("Found %d regions in %s\n", len(allRegions), iso2Code)

	if len(allRegions) == 0 {
		return fmt.Errorf("no regions found for country %s - import regions first", iso2Code)
	}

	// Build lookup map for existing districts
	districtRows, err := pool.Query(ctx, `
		SELECT d.id, d.code, d.name, d.region_id
		FROM geo_districts d
		JOIN geo_regions r ON d.region_id = r.id
		WHERE r.country_id = $1
	`, countryID)
	if err != nil {
		return fmt.Errorf("failed to query existing districts: %w", err)
	}
	defer districtRows.Close()

	// Map (region_id, name_lowercase) -> DistrictInfo
	existingDistricts := make(map[string]DistrictInfo)
	for districtRows.Next() {
		var di DistrictInfo
		if err := districtRows.Scan(&di.ID, &di.Code, &di.Name, &di.RegionID); err != nil {
			return fmt.Errorf("failed to scan district: %w", err)
		}
		key := fmt.Sprintf("%d:%s", di.RegionID, strings.ToLower(di.Name))
		existingDistricts[key] = di
	}

	log.Printf("Found %d existing districts in %s\n", len(existingDistricts), iso2Code)

	// Track which regions we've matched districts to
	regionDistrictCount := make(map[int32]int)

	// Check if we have region boundaries for this country (REQUIRED for point-in-polygon)
	var regionBoundaryCount int
	pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM geo_region_boundaries rb
		JOIN geo_regions r ON rb.region_id = r.id
		WHERE r.country_id = $1
	`, countryID).Scan(&regionBoundaryCount)

	// STRICT: Require region boundaries for countries with multiple regions
	if regionBoundaryCount == 0 && len(allRegions) > 1 {
		return fmt.Errorf("MISSING REGION BOUNDARIES for %s (%d regions). "+
			"Import ADM1 boundaries first: import-geo-boundaries download --level ADM1 --countries %s && "+
			"import-geo-boundaries import --level ADM1 --countries %s",
			iso2Code, len(allRegions), iso2Code, iso2Code)
	}

	log.Printf("Using %d region boundaries for point-in-polygon matching\n", regionBoundaryCount)

	// Process each feature
	var districtsCreated, boundariesInserted, unmatched int

	for i, feature := range fc.Features {
		// Extract properties from geoBoundaries format
		shapeName, _ := feature.Properties["shapeName"].(string)
		shapeID, _ := feature.Properties["shapeID"].(string)

		if shapeName == "" {
			if verbose {
				log.Printf("  [%d] SKIP: No shapeName\n", i)
			}
			unmatched++
			continue
		}

		// Find parent region using ONLY point-in-polygon (no fallbacks)
		var parentRegion *RegionLookup

		if len(allRegions) == 1 {
			// Single-region country: use the only region available
			parentRegion = &allRegions[0]
		} else {
			// Multi-region country: MUST use point-in-polygon
			geomJSON := string(feature.Geometry)
			var regionID int32
			var regionName string
			err := pool.QueryRow(ctx, `
				SELECT r.id, r.name
				FROM geo_regions r
				JOIN geo_region_boundaries rb ON r.id = rb.region_id
				WHERE r.country_id = $1
				  AND ST_Contains(
					rb.boundary::geometry,
					ST_Centroid(ST_GeomFromGeoJSON($2))
				  )
				LIMIT 1
			`, countryID, geomJSON).Scan(&regionID, &regionName)

			if err == nil {
				for _, r := range allRegions {
					if r.ID == regionID {
						parentRegion = &r
						break
					}
				}
			}
		}

		if parentRegion == nil {
			if verbose {
				log.Printf("  [%d] MISS: District '%s' centroid not within any region boundary\n",
					i, shapeName)
			}
			unmatched++
			stats.Errors = append(stats.Errors, fmt.Sprintf("District not in any region: %s", shapeName))
			continue
		}

		// Check if district already exists
		districtKey := fmt.Sprintf("%d:%s", parentRegion.ID, strings.ToLower(shapeName))
		existingDistrict, districtExists := existingDistricts[districtKey]

		var districtID int32
		var districtCode string

		if districtExists {
			districtID = existingDistrict.ID
			districtCode = existingDistrict.Code
		} else {
			// Generate a code for the new district
			// Use shapeID if available, otherwise generate from name
			if shapeID != "" {
				districtCode = shapeID
			} else {
				// Generate code: region_code + first 3 chars of name + index
				regionDistrictCount[parentRegion.ID]++
				districtCode = fmt.Sprintf("%s-%s%d",
					parentRegion.Code,
					strings.ToUpper(shapeName[:min(3, len(shapeName))]),
					regionDistrictCount[parentRegion.ID])
			}

			if dryRun {
				log.Printf("  [%d] DRY: Would create district '%s' (code: %s) in region %s\n",
					i, shapeName, districtCode, parentRegion.Name)
				districtsCreated++
				stats.DistrictsMatched++
				continue
			}

			// Create the district record
			err = pool.QueryRow(ctx, `
				INSERT INTO geo_districts (region_id, code, name)
				VALUES ($1, $2, $3)
				ON CONFLICT (region_id, code) DO UPDATE SET name = EXCLUDED.name
				RETURNING id
			`, parentRegion.ID, districtCode, shapeName).Scan(&districtID)
			if err != nil {
				log.Printf("  [%d] ERROR: Failed to create district '%s': %v\n", i, shapeName, err)
				stats.Errors = append(stats.Errors, fmt.Sprintf("Failed to create: %s - %v", shapeName, err))
				unmatched++
				continue
			}

			districtsCreated++

			// Add to lookup map for future iterations
			existingDistricts[districtKey] = DistrictInfo{
				ID:       districtID,
				Code:     districtCode,
				Name:     shapeName,
				RegionID: parentRegion.ID,
			}
		}

		if dryRun {
			log.Printf("  [%d] DRY: Would update boundary for district '%s' (ID: %d)\n",
				i, shapeName, districtID)
			boundariesInserted++
			stats.DistrictsMatched++
			continue
		}

		// Insert/update the boundary
		geomJSON := string(feature.Geometry)
		_, err = pool.Exec(ctx, `
			INSERT INTO geo_district_boundaries (district_id, boundary, area_km2, centroid)
			VALUES ($1, ST_GeomFromGeoJSON($2)::geography,
					ST_Area(ST_GeomFromGeoJSON($2)::geography) / 1000000,
					ST_Centroid(ST_GeomFromGeoJSON($2))::geography)
			ON CONFLICT (district_id) DO UPDATE SET
				boundary = ST_GeomFromGeoJSON($2)::geography,
				area_km2 = ST_Area(ST_GeomFromGeoJSON($2)::geography) / 1000000,
				centroid = ST_Centroid(ST_GeomFromGeoJSON($2))::geography,
				updated_at = now()
		`, districtID, geomJSON)
		if err != nil {
			log.Printf("  [%d] ERROR: Failed to insert boundary for '%s': %v\n", i, shapeName, err)
			stats.Errors = append(stats.Errors, fmt.Sprintf("Boundary insert failed: %s - %v", shapeName, err))
			unmatched++
			continue
		}

		boundariesInserted++

		if verbose {
			log.Printf("  [%d] OK: %s -> Region %s (ID: %d)\n",
				i, shapeName, parentRegion.Name, districtID)
		}
		stats.DistrictsMatched++
	}

	// Record import in tracking table
	if !dryRun {
		_, err = pool.Exec(ctx, `
			INSERT INTO geo_boundary_imports (source, level, country_code, version, records_imported, records_matched, records_unmatched, notes)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		`, "geoboundaries", "district", iso2Code, "current",
			len(fc.Features), boundariesInserted, unmatched,
			fmt.Sprintf("ISO3: %s, Created %d new districts, %d boundaries inserted", iso3Code, districtsCreated, boundariesInserted))
		if err != nil {
			log.Printf("Warning: Failed to record import: %v\n", err)
		}
	}

	log.Printf("District import for %s complete: %d created, %d boundaries, %d unmatched\n",
		iso2Code, districtsCreated, boundariesInserted, unmatched)

	stats.DistrictsUnmatched += unmatched

	return nil
}

// importRegionsFromGeoBoundaries imports ADM1 boundaries from geoBoundaries.
// This can be used to supplement or replace Natural Earth ADM1 boundaries
// with higher resolution data from geoBoundaries.
//
// Parameters:
//   - iso3Code: The ISO3 code used in the geoBoundaries filename (e.g., "GBR")
//   - iso2Code: The ISO2 code used in the database (e.g., "GB")
func importRegionsFromGeoBoundaries(ctx context.Context, pool *pgxpool.Pool, dirPath string, iso3Code string, iso2Code string, dryRun, verbose bool, stats *ImportStats) error {
	// Build the expected filename using ISO3 code
	fileName := fmt.Sprintf("geoBoundaries-%s-ADM1.geojson", iso3Code)
	filePath := filepath.Join(dirPath, fileName)

	// Check if file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return fmt.Errorf("file not found: %s", filePath)
	}

	// Read GeoJSON file
	data, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	var fc GeoJSONFeatureCollection
	if err := json.Unmarshal(data, &fc); err != nil {
		return fmt.Errorf("failed to parse GeoJSON: %w", err)
	}

	log.Printf("Found %d region features in %s\n", len(fc.Features), fileName)

	// Get the country from database using ISO2 code
	var countryID int16
	var countryName string
	err = pool.QueryRow(ctx, `
		SELECT id, name FROM geo_countries WHERE code = $1
	`, iso2Code).Scan(&countryID, &countryName)
	if err != nil {
		return fmt.Errorf("country %s (ISO2: %s) not found in database: %w", iso3Code, iso2Code, err)
	}

	log.Printf("Processing regions for %s (ISO2: %s, ID: %d)\n", countryName, iso2Code, countryID)

	// Build lookup map of existing regions
	rows, err := pool.Query(ctx, `
		SELECT id, code, name FROM geo_regions WHERE country_id = $1
	`, countryID)
	if err != nil {
		return fmt.Errorf("failed to query regions: %w", err)
	}
	defer rows.Close()

	type RegionInfo struct {
		ID   int32
		Code string
		Name string
	}

	// Map by name (lowercase) -> RegionInfo
	regionsByName := make(map[string]RegionInfo)
	for rows.Next() {
		var ri RegionInfo
		if err := rows.Scan(&ri.ID, &ri.Code, &ri.Name); err != nil {
			return fmt.Errorf("failed to scan region: %w", err)
		}
		regionsByName[strings.ToLower(ri.Name)] = ri
	}

	log.Printf("Found %d existing regions in %s\n", len(regionsByName), iso2Code)

	var matched, unmatched int

	for i, feature := range fc.Features {
		shapeName, _ := feature.Properties["shapeName"].(string)
		shapeISO, _ := feature.Properties["shapeISO"].(string)

		if shapeName == "" {
			unmatched++
			continue
		}

		// Try to match to existing region
		var region *RegionInfo

		// Strategy 1: Exact name match (case-insensitive)
		if r, found := regionsByName[strings.ToLower(shapeName)]; found {
			region = &r
		}

		// Strategy 2: ISO code match
		if region == nil && shapeISO != "" {
			for _, r := range regionsByName {
				if r.Code == shapeISO {
					region = &r
					break
				}
			}
		}

		// Strategy 3: Substring matching
		if region == nil {
			shapeNameLower := strings.ToLower(shapeName)
			for dbName, r := range regionsByName {
				if len(dbName) >= 3 && len(shapeNameLower) >= 3 {
					if strings.Contains(shapeNameLower, dbName) || strings.Contains(dbName, shapeNameLower) {
						region = &r
						break
					}
				}
			}
		}

		if region == nil {
			if verbose {
				log.Printf("  [%d] MISS: No match for region '%s' (ISO: %s)\n", i, shapeName, shapeISO)
			}
			unmatched++
			stats.RegionsUnmatched++
			continue
		}

		if dryRun {
			log.Printf("  [%d] DRY: Would update boundary for '%s' -> %s (ID: %d)\n",
				i, shapeName, region.Name, region.ID)
			matched++
			stats.RegionsMatched++
			continue
		}

		// Insert/update the boundary
		geomJSON := string(feature.Geometry)
		_, err = pool.Exec(ctx, `
			INSERT INTO geo_region_boundaries (region_id, boundary, area_km2, centroid)
			VALUES ($1, ST_GeomFromGeoJSON($2)::geography,
					ST_Area(ST_GeomFromGeoJSON($2)::geography) / 1000000,
					ST_Centroid(ST_GeomFromGeoJSON($2))::geography)
			ON CONFLICT (region_id) DO UPDATE SET
				boundary = ST_GeomFromGeoJSON($2)::geography,
				area_km2 = ST_Area(ST_GeomFromGeoJSON($2)::geography) / 1000000,
				centroid = ST_Centroid(ST_GeomFromGeoJSON($2))::geography,
				updated_at = now()
		`, region.ID, geomJSON)
		if err != nil {
			log.Printf("  [%d] ERROR: Failed to insert boundary for '%s': %v\n", i, shapeName, err)
			stats.Errors = append(stats.Errors, fmt.Sprintf("Boundary insert failed: %s - %v", shapeName, err))
			unmatched++
			continue
		}

		matched++
		if verbose {
			log.Printf("  [%d] OK: %s -> %s (ID: %d)\n", i, shapeName, region.Name, region.ID)
		}
		stats.RegionsMatched++
	}

	// Record import
	if !dryRun {
		_, err = pool.Exec(ctx, `
			INSERT INTO geo_boundary_imports (source, level, country_code, version, records_imported, records_matched, records_unmatched)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
		`, "geoboundaries", "region", iso2Code, "current", len(fc.Features), matched, unmatched)
		if err != nil {
			log.Printf("Warning: Failed to record import: %v\n", err)
		}
	}

	log.Printf("Region import for %s complete: %d matched, %d unmatched\n", iso2Code, matched, unmatched)

	return nil
}
