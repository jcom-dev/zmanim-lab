#!/bin/bash
# Helper script to start all Zmanim Lab services in tmux

# Check for --no-attach flag (used during Coder startup)
NO_ATTACH=false
if [ "$1" = "--no-attach" ]; then
    NO_ATTACH=true
fi

echo "🚀 Starting Zmanim Lab services in tmux..."

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if we're in the right place
if [ ! -d "$PROJECT_ROOT/web" ] || [ ! -d "$PROJECT_ROOT/api" ]; then
    echo "❌ Error: Could not find web/ and api/ directories"
    echo "   Please run this script from the zmanim-lab repository"
    exit 1
fi

# Kill existing session if it exists
tmux kill-session -t zmanim 2>/dev/null || true

# Create a new tmux session with the API service
tmux new-session -d -s zmanim -n api "cd $PROJECT_ROOT/api && go run cmd/api/main.go"

# Create window for web service (port 3001)
tmux new-window -t zmanim -n web "cd $PROJECT_ROOT/web && npm run dev -- -p ${WEB_PORT:-3001}"

# Wait a moment for services to start
sleep 2

# Health check function
check_service() {
    local name=$1
    local url=$2
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            echo "✅ $name is running"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    echo "⚠️  $name may not be ready yet (check tmux)"
    return 1
}

echo ""
echo "🔍 Checking service health..."
check_service "API" "http://localhost:8080/api/health"
check_service "Web" "http://localhost:${WEB_PORT:-3001}"

echo ""
echo "✅ Services started in tmux session 'zmanim'"
echo ""
echo "📺 To view services:"
echo "  tmux attach -t zmanim"
echo ""
echo "🔀 To switch between services:"
echo "  Ctrl+B then 0 (api)"
echo "  Ctrl+B then 1 (web)"
echo ""
echo "📤 To detach: Ctrl+B then D"
echo "🛑 To kill all: tmux kill-session -t zmanim"
echo ""
echo "🌐 Service URLs:"
echo "  - Web App: http://localhost:${WEB_PORT:-3001}"
echo "  - Go API:  http://localhost:8080"
echo ""

# Attach to the session (unless --no-attach was passed)
if [ "$NO_ATTACH" = false ]; then
    tmux attach -t zmanim
fi
