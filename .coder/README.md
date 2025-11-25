# Zmanim Lab Coder Workspace

This directory contains the Coder workspace template for the Zmanim Lab platform.

## Overview

Zmanim Lab uses a **monorepo** structure with:
- `web/` - Next.js frontend
- `api/` - Go backend

**External Services:**
- **Supabase** - PostgreSQL database (managed)
- **Upstash** - Redis caching (serverless REST API)
- **Clerk** - Authentication

## Quick Start

### 1. Create Workspace

```bash
# Login to Coder
coder login http://your-coder-instance

# Push template (first time only)
coder templates push zmanim-lab --directory .coder

# Create workspace
coder create zmanim-lab-dev --template zmanim-lab
```

### 2. Configure Environment

Copy the `.env.example` file and configure your credentials:

```bash
# API configuration
cp .env.example api/.env

# Web configuration
cp .env.example web/.env.local
```

Required variables:
- `DATABASE_URL` - Supabase PostgreSQL connection string
- `UPSTASH_REDIS_REST_URL` - Upstash Redis REST endpoint
- `UPSTASH_REDIS_REST_TOKEN` - Upstash Redis auth token
- `CLERK_SECRET_KEY` - Clerk backend secret
- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` - Clerk frontend key

### 3. Start Services

```bash
# Using the helper script (starts both in tmux)
./.coder/start-services.sh

# Or manually:
# Terminal 1: API
cd api && go run cmd/api/main.go

# Terminal 2: Web
cd web && npm run dev -- -p 3001
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| Web App | 3001 | Next.js frontend |
| Go API | 8080 | REST API backend |

## Development Tools

**Installed in Container:**
- Go 1.25.4 - Backend development
- Node.js 24.x LTS (Krypton) - Frontend development
- npm 10+ - Package manager
- Supabase CLI - Database migrations
- Playwright 1.56+ - E2E testing (Chromium)
- tmux - Service management

## Health Checks

```bash
# API
curl http://localhost:8080/api/health

# Web
curl http://localhost:3001
```

## Testing

```bash
# Go unit tests
cd api && go test ./...

# Playwright E2E tests
cd web && npm run test:e2e
```

## Files

- `zmanim-lab-workspace.tf` - Terraform workspace definition
- `startup.sh` - Initialization script (runs on workspace creation)
- `start-services.sh` - Helper to start web and API in tmux
- `README.md` - This file

## Using Your Own Fork or Branch

```bash
# Create workspace with custom branch
coder create zmanim-lab-dev --template zmanim-lab \
  --parameter zmanim_branch=feature/my-feature

# Or with your fork
coder create zmanim-lab-dev --template zmanim-lab \
  --parameter zmanim_repo=git@github.com:your-username/zmanim-lab.git
```

## Troubleshooting

### Git clone fails
Add your SSH key to GitHub:
```bash
coder ssh zmanim-lab-dev -- "cat ~/.ssh/id_ed25519.pub"
# Add to: https://github.com/settings/ssh/new
```

### Services won't start
Check environment variables are configured:
```bash
cat api/.env
cat web/.env.local
```

### Database connection fails
Verify Supabase connection string in `DATABASE_URL` is correct.

## Architecture

```
Coder Workspace
└── Development Container
    ├── Go 1.25.4
    ├── Node.js 24.x LTS
    ├── Playwright 1.56+
    └── Supabase CLI

External Services:
├── Supabase (PostgreSQL)
├── Upstash (Redis)
└── Clerk (Auth)
```

## References

- [Coder Documentation](https://coder.com/docs)
- [Architecture](../docs/architecture.md)
- [Epics](../docs/epics.md)
