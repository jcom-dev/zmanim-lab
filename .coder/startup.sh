#!/bin/bash
set -e

# Shtetl Development Environment Startup Script
# This script initializes the development environment with all services

echo "🚀 Starting Shtetl Development Environment Setup..."

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

# Install netcat for service health checks (suppress output)
sudo apt-get update -qq && sudo apt-get install -qq -y netcat-openbsd > /dev/null 2>&1

# Change to workspace directory
cd /home/coder/workspace

# Step 1: Install Go 1.25.4
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
    print_success "Go 1.25.4 already installed"
fi

# Step 2: Install Node.js 24.x LTS
print_status "Installing Node.js 24.x LTS..."
if ! command -v node &> /dev/null || [[ $(node --version | grep -o 'v24') == "" ]]; then
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt-get install -y nodejs
    print_success "Node.js 24.x installed"
else
    print_success "Node.js 24.x already installed"
fi

# Step 3: Clone repositories if they don't exist
print_status "Cloning repositories..."

# Add GitHub to known hosts to avoid host key verification prompts
mkdir -p ~/.ssh
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null

# Clone main shtetl repo first (check for .git to verify actual clone, not empty dir)
if [ ! -d "shtetl/.git" ]; then
    print_status "Cloning shtetl (main repo)..."
    rm -rf shtetl 2>/dev/null  # Remove empty directory if exists
    git clone ${SHTETL_REPO} shtetl || print_warning "Failed to clone shtetl"
else
    print_success "shtetl already cloned"
fi

# Create submodules directory
mkdir -p shtetl/submodules

# Clone submodules (check for .git to verify actual clone, not empty dir)
if [ ! -d "shtetl/submodules/shtetl-infra/.git" ]; then
    print_status "Cloning shtetl-infra..."
    rm -rf shtetl/submodules/shtetl-infra 2>/dev/null  # Remove empty directory if exists
    git clone ${SHTETL_INFRA_REPO} shtetl/submodules/shtetl-infra || print_warning "Failed to clone shtetl-infra"
else
    print_success "shtetl-infra already cloned"
fi

if [ ! -d "shtetl/submodules/shtetl-api/.git" ]; then
    print_status "Cloning shtetl-api..."
    rm -rf shtetl/submodules/shtetl-api 2>/dev/null  # Remove empty directory if exists
    git clone ${SHTETL_API_REPO} shtetl/submodules/shtetl-api || print_warning "Failed to clone shtetl-api"
else
    print_success "shtetl-api already cloned"
fi

if [ ! -d "shtetl/submodules/shtetl-web/.git" ]; then
    print_status "Cloning shtetl-web..."
    rm -rf shtetl/submodules/shtetl-web 2>/dev/null  # Remove empty directory if exists
    git clone ${SHTETL_WEB_REPO} shtetl/submodules/shtetl-web || print_warning "Failed to clone shtetl-web"
else
    print_success "shtetl-web already cloned"
fi

if [ ! -d "shtetl/submodules/shtetl-mobile/.git" ]; then
    print_status "Cloning shtetl-mobile..."
    rm -rf shtetl/submodules/shtetl-mobile 2>/dev/null  # Remove empty directory if exists
    git clone ${SHTETL_MOBILE_REPO} shtetl/submodules/shtetl-mobile || print_warning "Failed to clone shtetl-mobile"
else
    print_success "shtetl-mobile already cloned"
fi

# Checkout specified branch for all repos
if [ -n "${SHTETL_BRANCH}" ] && [ "${SHTETL_BRANCH}" != "main" ]; then
    print_status "Checking out branch '${SHTETL_BRANCH}' for all repositories..."

    for repo in shtetl shtetl/submodules/shtetl-infra shtetl/submodules/shtetl-api shtetl/submodules/shtetl-web shtetl/submodules/shtetl-mobile; do
        if [ -d "$repo" ]; then
            cd "$repo"
            if git fetch origin "${SHTETL_BRANCH}" 2>/dev/null && git checkout "${SHTETL_BRANCH}" 2>/dev/null; then
                print_success "Checked out ${SHTETL_BRANCH} in $(basename $repo)"
            else
                print_warning "Branch ${SHTETL_BRANCH} not found in $(basename $repo), staying on default"
            fi
            cd /home/coder/workspace
        fi
    done
fi

# Step 4: Install Go dependencies
print_status "Installing Go dependencies..."

for service in zmanim shul kehilla; do
    if [ -d "shtetl/submodules/shtetl-api/$service" ]; then
        print_status "Running go mod download for $service service..."
        cd shtetl/submodules/shtetl-api/$service
        go mod download || print_warning "Failed to download dependencies for $service"
        cd /home/coder/workspace
        print_success "$service dependencies installed"
    fi
done

# Step 5: Install Node.js dependencies
print_status "Installing Node.js dependencies..."

if [ -d "shtetl/submodules/shtetl-web" ]; then
    print_status "Running npm install for web app..."
    cd shtetl/submodules/shtetl-web
    npm install || print_warning "Failed to install web dependencies"
    cd /home/coder/workspace
    print_success "Web app dependencies installed"
fi

if [ -d "shtetl/submodules/shtetl-mobile" ]; then
    print_status "Running npm install for mobile app..."
    cd shtetl/submodules/shtetl-mobile
    npm install --legacy-peer-deps || print_warning "Failed to install mobile dependencies"
    cd /home/coder/workspace
    print_success "Mobile app dependencies installed"
fi

# Step 6: Wait for PostgreSQL to be ready
print_status "Waiting for PostgreSQL to be ready..."
max_attempts=30
attempt=0
pg_ready=false
while [ $attempt -lt $max_attempts ]; do
    if nc -z ${POSTGRES_HOST} ${POSTGRES_PORT} 2>/dev/null; then
        pg_ready=true
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done
if [ "$pg_ready" = true ]; then
    print_success "PostgreSQL is ready"
else
    print_error "PostgreSQL failed to start after $max_attempts attempts"
fi

# Step 7: Wait for Redis to be ready
print_status "Waiting for Redis to be ready..."
max_attempts=30
attempt=0
redis_ready=false
while [ $attempt -lt $max_attempts ]; do
    if nc -z ${REDIS_HOST} ${REDIS_PORT} 2>/dev/null; then
        redis_ready=true
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done
if [ "$redis_ready" = true ]; then
    print_success "Redis is ready"
else
    print_error "Redis failed to start after $max_attempts attempts"
fi

# Step 8: Run database migrations (currently empty, will be populated in Story 1.8)
print_status "Running database migrations..."
# TODO: Add migration command when migrations are created in Story 1.8
print_success "Database migrations complete (currently empty)"

# Step 9: Start all services in tmux
print_status "Starting all services in tmux..."

# Install tmux if not present
if ! command -v tmux &> /dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y tmux
fi

# Kill existing session if it exists
tmux kill-session -t shtetl 2>/dev/null || true

# Create tmux session and start services
tmux new-session -d -s shtetl -n zmanim "cd /home/coder/workspace/shtetl/submodules/shtetl-api/zmanim && go run cmd/zmanim/main.go"
tmux new-window -t shtetl -n shul "cd /home/coder/workspace/shtetl/submodules/shtetl-api/shul && go run cmd/shul/main.go"
tmux new-window -t shtetl -n kehilla "cd /home/coder/workspace/shtetl/submodules/shtetl-api/kehilla && go run cmd/kehilla/main.go"
tmux new-window -t shtetl -n web "cd /home/coder/workspace/shtetl/submodules/shtetl-web && npm run dev -- -p ${WEB_PORT}"

# Wait a moment for services to start
sleep 3

print_success "All services started in tmux session 'shtetl'"

# Step 10: Display status
echo ""
echo "=========================================="
echo "✅ Shtetl Development Environment Ready!"
echo "=========================================="
echo ""
echo "📦 Installed:"
echo "  - Go $(go version | awk '{print $3}')"
echo "  - Node.js $(node --version)"
echo "  - npm $(npm --version)"
echo ""
echo "🗄️  Infrastructure:"
echo "  - PostgreSQL: ${POSTGRES_HOST}:${POSTGRES_PORT}"
echo "  - Redis: ${REDIS_HOST}:${REDIS_PORT}"
echo ""
echo "🚀 Services Running in tmux:"
echo "  - Zmanim: REST ${ZMANIM_REST_PORT}"
echo "  - Shul: REST ${SHUL_REST_PORT}"
echo "  - Kehilla: REST ${KEHILLA_PORT}"
echo "  - Web: http://localhost:${WEB_PORT}"
echo ""
echo "📺 View Services:"
echo "  tmux attach -t shtetl"
echo ""
echo "  Switch windows: Ctrl+B then 0-3"
echo "  Detach: Ctrl+B then D"
echo ""
echo "🔍 Health Checks:"
echo "  curl http://localhost:${ZMANIM_REST_PORT}/health  # Zmanim"
echo "  curl http://localhost:${SHUL_REST_PORT}/health    # Shul"
echo "  curl http://localhost:${KEHILLA_PORT}/health      # Kehilla"
echo "  open http://localhost:${WEB_PORT}                 # Web"
echo ""
echo "📚 Documentation:"
echo "  - Architecture: docs/architecture.md"
echo "  - Epics: docs/epics.md"
echo "  - README: README.md"
echo ""
echo "=========================================="
