#!/bin/bash
set -e

# Shtetl Zmanim VM Setup Script
# This script installs all prerequisites for development on a fresh Ubuntu/Debian VM
# Usage: curl -fsSL https://raw.githubusercontent.com/jcom-dev/zmanim/dev/scripts/vm-setup.sh | bash

echo "Starting Shtetl Zmanim Development Environment Setup..."

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect user home directory
USER_HOME="${HOME:-/home/$(whoami)}"

# Update system packages
print_status "Updating system packages..."
sudo apt-get update -qq

# ============================================
# Go 1.24.x (latest stable)
# ============================================
print_status "Installing Go 1.24.4..."
GO_VERSION="1.24.4"
if ! command -v go &> /dev/null || ! go version | grep -q "go${GO_VERSION}"; then
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    print_success "Go ${GO_VERSION} installed"
else
    print_success "Go ${GO_VERSION} already installed"
fi

# Add Go to PATH
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$(go env GOPATH)/bin
grep -qxF 'export PATH=$PATH:/usr/local/go/bin' "$USER_HOME/.bashrc" || echo 'export PATH=$PATH:/usr/local/go/bin' >> "$USER_HOME/.bashrc"
grep -qxF 'export PATH=$PATH:$(go env GOPATH)/bin' "$USER_HOME/.bashrc" || echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> "$USER_HOME/.bashrc"

# ============================================
# sqlc (SQL code generator for Go)
# ============================================
print_status "Installing sqlc..."
if ! command -v sqlc &> /dev/null; then
    go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
    print_success "sqlc installed"
else
    print_success "sqlc already installed"
fi

# ============================================
# Node.js 22.x LTS
# ============================================
print_status "Installing Node.js 22.x LTS..."
if ! command -v node &> /dev/null || ! node --version | grep -q "v22"; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
    print_success "Node.js 22.x LTS installed"
else
    print_success "Node.js 22.x LTS already installed"
fi

# Configure npm global directory (avoid sudo for global packages)
print_status "Configuring npm global directory..."
mkdir -p "$USER_HOME/.npm-global"
npm config set prefix "$USER_HOME/.npm-global"
export PATH="$USER_HOME/.npm-global/bin:$PATH"
grep -qxF 'export PATH="$HOME/.npm-global/bin:$PATH"' "$USER_HOME/.bashrc" || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$USER_HOME/.bashrc"
print_success "npm global directory configured"

# ============================================
# PostgreSQL 17 Client
# ============================================
print_status "Installing PostgreSQL 17 client..."
PSQL_VERSION=$(psql --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "0")
if [ "$PSQL_VERSION" != "17" ]; then
    sudo apt-get install -y curl ca-certificates > /dev/null 2>&1
    sudo install -d /usr/share/postgresql-common/pgdg
    sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc 2>/dev/null
    . /etc/os-release
    sudo sh -c "echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
    sudo apt-get update -qq
    sudo apt-get install -y postgresql-client-17
    print_success "PostgreSQL 17 client installed"
else
    print_success "PostgreSQL 17 client already installed"
fi

# ============================================
# Redis Client
# ============================================
print_status "Installing Redis client..."
if ! command -v redis-cli &> /dev/null; then
    sudo apt-get install -y redis-tools
    print_success "Redis client installed"
else
    print_success "Redis client already installed"
fi

# ============================================
# Development Utilities
# ============================================
print_status "Installing development utilities..."
sudo apt-get install -y \
    git \
    nano \
    vim \
    tmux \
    jq \
    tree \
    htop \
    ncdu \
    curl \
    wget \
    unzip \
    lsof \
    net-tools \
    iproute2 \
    iputils-ping \
    dnsutils \
    telnet \
    procps \
    psmisc \
    strace \
    zstd \
    build-essential \
    libgdal-dev \
    > /dev/null 2>&1
print_success "Development utilities installed"

# ============================================
# Jest (global)
# ============================================
print_status "Installing Jest globally..."
if ! npm list -g jest &> /dev/null 2>&1; then
    npm install -g jest
    print_success "Jest installed globally"
else
    print_success "Jest already installed globally"
fi

# ============================================
# Fly.io CLI (optional)
# ============================================
print_status "Installing Fly.io CLI..."
if ! command -v flyctl &> /dev/null; then
    curl -L https://fly.io/install.sh | sh
    export FLYCTL_INSTALL="$USER_HOME/.fly"
    export PATH="$FLYCTL_INSTALL/bin:$PATH"
    grep -qxF 'export FLYCTL_INSTALL="$HOME/.fly"' "$USER_HOME/.bashrc" || echo 'export FLYCTL_INSTALL="$HOME/.fly"' >> "$USER_HOME/.bashrc"
    grep -qxF 'export PATH="$FLYCTL_INSTALL/bin:$PATH"' "$USER_HOME/.bashrc" || echo 'export PATH="$FLYCTL_INSTALL/bin:$PATH"' >> "$USER_HOME/.bashrc"
    print_success "Fly.io CLI installed"
else
    print_success "Fly.io CLI already installed"
fi

# ============================================
# uv (Python package manager)
# ============================================
print_status "Installing uv (Python package manager)..."
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$USER_HOME/.local/bin:$PATH"
    grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$USER_HOME/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"
    print_success "uv installed"
else
    print_success "uv already installed"
fi

# ============================================
# Claude Code CLI (optional)
# ============================================
print_status "Installing Claude Code CLI..."
if ! command -v claude &> /dev/null; then
    curl -fsSL https://claude.ai/install.sh | bash
    export PATH="$USER_HOME/.claude/bin:$PATH"
    grep -qxF 'export PATH="$HOME/.claude/bin:$PATH"' "$USER_HOME/.bashrc" || echo 'export PATH="$HOME/.claude/bin:$PATH"' >> "$USER_HOME/.bashrc"
    print_success "Claude Code installed"
else
    print_success "Claude Code already installed"
fi

# ============================================
# Git Configuration (optional - set your own)
# ============================================
print_status "Checking git configuration..."
if [ -z "$(git config --global user.name)" ]; then
    print_warning "Git user.name not set. Run: git config --global user.name 'Your Name'"
fi
if [ -z "$(git config --global user.email)" ]; then
    print_warning "Git user.email not set. Run: git config --global user.email 'your@email.com'"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo "VM Setup Complete!"
echo "=========================================="
echo ""
echo "Installed:"
echo "  - Go $(go version 2>/dev/null | awk '{print $3}' || echo 'not found')"
echo "  - sqlc $(sqlc version 2>/dev/null || echo 'not found')"
echo "  - Node.js $(node --version 2>/dev/null || echo 'not found')"
echo "  - npm $(npm --version 2>/dev/null || echo 'not found')"
echo "  - PostgreSQL client $(psql --version 2>/dev/null | head -1 || echo 'not found')"
echo "  - Redis client $(redis-cli --version 2>/dev/null || echo 'not found')"
echo "  - tmux, jq, htop, tree, vim, nano"
echo "  - Fly.io CLI $(flyctl version 2>/dev/null | head -1 || echo 'not found')"
echo "  - uv $(uv --version 2>/dev/null || echo 'not found')"
echo "  - Claude Code $(claude --version 2>/dev/null || echo 'not found')"
echo ""
echo "Next Steps:"
echo "  1. Source your shell: source ~/.bashrc"
echo "  2. Clone the repo: git clone git@github.com:jcom-dev/zmanim.git"
echo "  3. Install dependencies:"
echo "     cd zmanim/api && go mod download"
echo "     cd zmanim/web && npm install"
echo "  4. Install Playwright browsers:"
echo "     cd zmanim/web && npx playwright install --with-deps chromium"
echo "  5. Copy .env.example files and configure"
echo "  6. Start services: ./restart.sh"
echo ""
echo "=========================================="
