#!/bin/bash
set -e

# Zmanim Lab Development Environment Startup Script
# This script initializes the development environment for the monorepo

echo "🚀 Starting Zmanim Lab Development Environment Setup..."

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fix workspace directory ownership (needed for Docker volumes)
sudo chown -R coder:coder /home/coder/workspace

# Change to workspace directory
cd /home/coder/workspace

# Step 1: Install Go 1.25.4 (latest)
print_status "Installing Go 1.25.4..."
if ! command -v go &> /dev/null || [[ $(go version | grep -o '1\.25\.4') == "" ]]; then
    wget -q https://go.dev/dl/go1.25.4.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.25.4.linux-amd64.tar.gz
    rm go1.25.4.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    print_success "Go 1.25.4 installed"
else
    print_success "Go 1.25.4 already installed ($(go version))"
fi

# Step 2: Install Node.js 24.x LTS (Krypton - latest LTS)
print_status "Installing Node.js 24.x LTS..."
if ! command -v node &> /dev/null || [[ $(node --version | grep -o 'v24') == "" ]]; then
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt-get install -y nodejs
    print_success "Node.js 24.x LTS installed"
else
    print_success "Node.js 24.x LTS already installed ($(node --version))"
fi

# Step 3: Clone repository if it doesn't exist (monorepo)
print_status "Checking repository..."

# Add GitHub to known hosts
mkdir -p ~/.ssh
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null

if [ ! -d "zmanim-lab/.git" ]; then
    print_status "Cloning zmanim-lab repository..."
    rm -rf zmanim-lab 2>/dev/null
    git clone ${ZMANIM_REPO:-git@github.com:jcom-dev/zmanim-lab.git} zmanim-lab || print_warning "Failed to clone zmanim-lab"
else
    print_success "zmanim-lab already cloned"
fi

# Checkout specified branch
if [ -n "${ZMANIM_BRANCH}" ] && [ "${ZMANIM_BRANCH}" != "main" ]; then
    print_status "Checking out branch '${ZMANIM_BRANCH}'..."
    cd zmanim-lab
    if git fetch origin "${ZMANIM_BRANCH}" 2>/dev/null && git checkout "${ZMANIM_BRANCH}" 2>/dev/null; then
        print_success "Checked out ${ZMANIM_BRANCH}"
    else
        print_warning "Branch ${ZMANIM_BRANCH} not found, staying on default"
    fi
    cd /home/coder/workspace
fi

# Step 4: Install Go dependencies
print_status "Installing Go dependencies..."
if [ -d "zmanim-lab/api" ]; then
    cd zmanim-lab/api
    go mod download || print_warning "Failed to download Go dependencies"
    cd /home/coder/workspace
    print_success "Go dependencies installed"
fi

# Step 5: Install Node.js dependencies
print_status "Installing Node.js dependencies..."
if [ -d "zmanim-lab/web" ]; then
    cd zmanim-lab/web
    npm install || print_warning "Failed to install web dependencies"
    cd /home/coder/workspace
    print_success "Web dependencies installed"
fi

# Step 6: Install Playwright browsers for E2E testing
print_status "Installing Playwright browsers..."
if [ -d "zmanim-lab/web" ]; then
    cd zmanim-lab/web
    npx playwright install --with-deps chromium || print_warning "Failed to install Playwright browsers"
    cd /home/coder/workspace
    print_success "Playwright browsers installed"
fi

# Step 7: Copy .env.example to .env files if they don't exist
print_status "Setting up environment files..."
cd zmanim-lab

if [ -f ".env.example" ] && [ ! -f "api/.env" ]; then
    cp .env.example api/.env
    print_warning "Created api/.env from template - please configure with your credentials"
fi

if [ -f ".env.example" ] && [ ! -f "web/.env.local" ]; then
    cp .env.example web/.env.local
    print_warning "Created web/.env.local from template - please configure with your credentials"
fi

cd /home/coder/workspace

# Step 8: Install tmux for service management
print_status "Installing tmux..."
if ! command -v tmux &> /dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y tmux > /dev/null 2>&1
    print_success "tmux installed"
else
    print_success "tmux already installed"
fi

# Step 9: Display status
echo ""
echo "=========================================="
echo "✅ Zmanim Lab Development Environment Ready!"
echo "=========================================="
echo ""
echo "📦 Installed:"
echo "  - Go $(go version 2>/dev/null | awk '{print $3}' || echo 'not found')"
echo "  - Node.js $(node --version 2>/dev/null || echo 'not found')"
echo "  - npm $(npm --version 2>/dev/null || echo 'not found')"
echo "  - Supabase CLI (via npx supabase)"
echo "  - Playwright (Chromium)"
echo ""
echo "🗄️  External Services (configure in .env):"
echo "  - Supabase: PostgreSQL database"
echo "  - Upstash: Redis caching"
echo "  - Clerk: Authentication"
echo ""
echo "🚀 To Start Services:"
echo "  cd /home/coder/workspace/zmanim-lab"
echo "  ./.coder/start-services.sh"
echo ""
echo "  Or manually:"
echo "  - Web: cd web && npm run dev"
echo "  - API: cd api && go run cmd/api/main.go"
echo ""
echo "📋 Service Ports:"
echo "  - Web App: http://localhost:3001"
echo "  - Go API: http://localhost:8080"
echo ""
echo "🧪 Testing:"
echo "  - Go tests: cd api && go test ./..."
echo "  - E2E tests: cd web && npm run test:e2e"
echo ""
echo "📚 Documentation:"
echo "  - Architecture: docs/architecture.md"
echo "  - Epics: docs/epics.md"
echo "  - README: README.md"
echo ""
echo "=========================================="

# Step 10: Auto-start services
print_status "Starting services in background..."
cd /home/coder/workspace/zmanim-lab
if [ -f ".coder/start-services.sh" ]; then
    chmod +x .coder/start-services.sh
    ./.coder/start-services.sh --no-attach
    print_success "Services started in tmux session 'zmanim'"
    echo ""
    echo "🎯 Services are now running!"
    echo "   - Attach to tmux: tmux attach -t zmanim"
    echo "   - View API logs: tmux select-window -t zmanim:api"
    echo "   - View Web logs: tmux select-window -t zmanim:web"
else
    print_warning "start-services.sh not found - start services manually"
fi
