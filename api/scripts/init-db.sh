#!/bin/bash
# Initialize local development database
# Runs migrations from /db/migrations directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
MIGRATIONS_DIR="$PROJECT_ROOT/db/migrations"

# Load environment variables
if [ -f "$SCRIPT_DIR/../.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/../.env" | xargs)
fi

echo "🔧 Running database migrations..."
echo "   Migrations: $MIGRATIONS_DIR"
echo ""

# Run via Go migration tool
cd "$SCRIPT_DIR/.."
go run cmd/init-db/main.go "$MIGRATIONS_DIR"

echo ""
echo "✅ Database migrations complete!"
