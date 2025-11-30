#!/bin/bash
# Import GeoNames cities data into the database
# Source: http://download.geonames.org/export/dump/
#
# Usage:
#   ./scripts/import-geonames-cities.sh [DATABASE_URL]
#
# If DATABASE_URL is not provided, uses environment variable

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SCRIPT_DIR/data"

# Get database URL
DB_URL="${1:-$DATABASE_URL}"
if [ -z "$DB_URL" ]; then
    echo "Error: DATABASE_URL is required (as argument or environment variable)"
    echo "Usage: $0 [DATABASE_URL]"
    exit 1
fi

echo "==================================="
echo "GeoNames Cities Import Script"
echo "==================================="
echo ""

# Create data directory
mkdir -p "$DATA_DIR"
cd "$DATA_DIR"

# Download cities data if not exists
if [ ! -f "cities1000.txt" ]; then
    echo "Downloading cities1000.zip from GeoNames..."
    curl -sLO "http://download.geonames.org/export/dump/cities1000.zip"
    echo "Extracting..."
    unzip -o cities1000.zip
    rm -f cities1000.zip
else
    echo "Using existing cities1000.txt"
fi

# Download country info if not exists
if [ ! -f "countryInfo.txt" ]; then
    echo "Downloading countryInfo.txt..."
    curl -sLO "http://download.geonames.org/export/dump/countryInfo.txt"
else
    echo "Using existing countryInfo.txt"
fi

echo ""
echo "Running import via Go tool..."
cd "$PROJECT_DIR/api"

# Build the importer
go build -o import-cities ./cmd/import-cities/

# Run with the database URL
DATABASE_URL="$DB_URL" ./import-cities

# Cleanup binary
rm -f import-cities

echo ""
echo "Import complete!"
