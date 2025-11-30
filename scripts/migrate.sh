#!/bin/bash
# Database migration script
# Detects Coder environment and uses local database, otherwise uses Supabase

set -e

# Check if we're in Coder environment
if [[ -d "/home/coder" ]] && [[ -f "/home/coder/workspace/zmanim-lab/api/.env" ]]; then
    echo "Detected Coder environment - using local PostgreSQL"

    # Extract database URL from api/.env
    source /home/coder/workspace/zmanim-lab/api/.env

    # Parse DATABASE_URL
    # Format: postgresql://user:password@host:port/database
    if [[ -z "$DATABASE_URL" ]]; then
        echo "Error: DATABASE_URL not set in api/.env"
        exit 1
    fi

    # Extract components using regex
    if [[ $DATABASE_URL =~ postgresql://([^:]+):([^@]+)@([^:]+):([0-9]+)/(.+) ]]; then
        DB_USER="${BASH_REMATCH[1]}"
        DB_PASS="${BASH_REMATCH[2]}"
        DB_HOST="${BASH_REMATCH[3]}"
        DB_PORT="${BASH_REMATCH[4]}"
        DB_NAME="${BASH_REMATCH[5]}"
    else
        echo "Error: Could not parse DATABASE_URL"
        exit 1
    fi

    MIGRATIONS_DIR="/home/coder/workspace/zmanim-lab/supabase/migrations"

    # Create schema_migrations table if it doesn't exist (compatible with Supabase format)
    PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
        "CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ DEFAULT NOW());" 2>/dev/null || true

    # Get list of applied migrations (Supabase uses 'version' column)
    echo "Checking for applied migrations..."
    APPLIED=$(PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c \
        "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null || echo "")

    # Apply pending migrations
    echo "Looking for migrations in $MIGRATIONS_DIR..."

    for migration in $(ls -1 $MIGRATIONS_DIR/*.sql 2>/dev/null | sort); do
        MIGRATION_NAME=$(basename "$migration")

        # Check if already applied
        if echo "$APPLIED" | grep -q "$MIGRATION_NAME"; then
            echo "  [SKIP] $MIGRATION_NAME (already applied)"
            continue
        fi

        echo "  [APPLY] $MIGRATION_NAME"

        # Apply migration (continue on errors for idempotent migrations)
        PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f "$migration" 2>&1 || true

        # Record migration as applied
        PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
            "INSERT INTO schema_migrations (version) VALUES ('$MIGRATION_NAME') ON CONFLICT DO NOTHING;" 2>/dev/null
        echo "    Done"
    done

    echo ""
    echo "Migration complete!"

else
    echo "Not in Coder environment - using Supabase CLI"

    # Use supabase CLI for remote database
    if ! command -v supabase &> /dev/null; then
        echo "Installing Supabase CLI..."
        npm install -g supabase
    fi

    cd /home/coder/workspace/zmanim-lab
    npx supabase migration up
fi
