#!/bin/bash
# Restart script for Zmanim Lab services
# This script kills all running services and restarts them in the background

set -e

echo "🔄 Restarting Zmanim Lab services..."
echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to kill processes by pattern
kill_processes() {
    local pattern=$1
    local name=$2
    echo "🛑 Stopping $name..."
    pkill -f "$pattern" 2>/dev/null || true
}

# Kill the tmux session if it exists
echo "🛑 Stopping tmux session 'zmanim'..."
tmux kill-session -t zmanim 2>/dev/null || true

# Kill any stray processes
kill_processes "go run cmd/api/main.go" "Go API server"
kill_processes "next dev" "Next.js dev server"

# Wait a moment for processes to fully terminate
sleep 2

# Check if ports are still in use
echo ""
echo "🔍 Checking if ports are available..."
for port in 8080 3001; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "⚠️  Port $port is still in use, force killing..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 1
    else
        echo "✅ Port $port is available"
    fi
done

echo ""
echo "🚀 Starting services in background..."

# Run the startup script in the background (no-attach mode)
"$SCRIPT_DIR/.coder/start-services.sh" --no-attach

echo ""
echo "✅ Services restarted successfully!"
echo ""
echo "📺 To view service logs:"
echo "  tmux attach -t zmanim"
echo ""
echo "🌐 Service URLs:"
echo "  - Web App: http://localhost:3001"
echo "  - Go API:  http://localhost:8080"
echo ""
