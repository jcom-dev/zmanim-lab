# Zmanim Lab

**Halachic Zmanim Publishing Platform** - A portal for rabbinic authorities to publish customized Jewish prayer times with full algorithm control.

## Overview

Zmanim Lab enables halachic authorities to:
- Define custom zmanim calculation algorithms using a friendly UX
- Publish prayer times for specific geographic regions
- Provide end users with accurate, authority-specific zmanim

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Zmanim Lab                               │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   Web Frontend  │───▶│    Go API       │───▶│  Supabase   │ │
│  │   (Next.js)     │    │   (Chi Router)  │    │ (PostgreSQL)│ │
│  │     /web        │    │     /api        │    │   + PostGIS │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│         │                       │                     │         │
│         ▼                       ▼                     ▼         │
│      Vercel               Fly.io                Supabase.com    │
└─────────────────────────────────────────────────────────────────┘

Authentication: Clerk
```

## Project Structure

```
zmanim-lab/
├── web/                 # Next.js frontend (Vercel)
│   ├── app/            # App Router pages
│   ├── components/     # React components
│   ├── lib/            # Utilities & API client
│   └── package.json
├── api/                 # Go backend (Fly.io)
│   ├── cmd/api/        # Entry point
│   ├── internal/       # Business logic
│   ├── Dockerfile
│   └── fly.toml
├── supabase/           # Database migrations
│   └── migrations/
├── docs/               # Documentation
└── .github/workflows/  # CI/CD
```

## Quick Start

### Option 1: Coder Cloud Development (Recommended)

Use Coder for a fully configured cloud development environment:

```bash
# Login to Coder
coder login http://your-coder-instance

# Push template (first time only)
coder templates push zmanim-lab --directory .coder

# Create workspace
coder create zmanim-lab-dev --template zmanim-lab
```

See [.coder/README.md](./.coder/README.md) for details.

### Option 2: Local Development

#### Prerequisites

- Node.js 24+ LTS
- Go 1.25+
- npm 10+
- Supabase account
- Clerk account
- Upstash account

#### Setup

```bash
# Clone repository
git clone https://github.com/jcom-dev/zmanim-lab.git
cd zmanim-lab

# Copy environment template
cp .env.example api/.env
cp .env.example web/.env.local
# Edit both files with your credentials
```

#### Frontend (web/)

```bash
cd web
npm install
npm run dev -- -p 3001
```

Open [http://localhost:3001](http://localhost:3001) in your browser.

#### Backend (api/)

```bash
cd api
go mod download
go run ./cmd/api
```

API available at [http://localhost:8080](http://localhost:8080)

### Environment Variables

Required services:
- **Supabase** - PostgreSQL database ([supabase.com](https://supabase.com))
- **Upstash** - Redis caching ([upstash.com](https://upstash.com))
- **Clerk** - Authentication ([clerk.com](https://clerk.com))

See `.env.example` for all required variables.

## Deployment

| Component | Platform | Directory | URL |
|-----------|----------|-----------|-----|
| Frontend | Vercel | `web/` | TBD |
| Backend | Fly.io | `api/` | https://zmanim-lab.fly.dev |
| Database | Supabase | — | — |
| Auth | Clerk | — | — |

### Deploy Backend

```bash
cd api
fly deploy
```

### Deploy Frontend

Connect repository to Vercel with root directory set to `web/`.

## Documentation

See [docs/](./docs/) for comprehensive documentation:

- [Index](./docs/index.md) - Documentation overview
- [Architecture](./docs/ARCHITECTURE.md) - System design
- [API Reference](./docs/api-reference.md) - REST endpoints
- [Data Models](./docs/data-models.md) - Database schema
- [Deployment](./docs/deployment.md) - Deployment guide

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js 16, React 19, TypeScript, Tailwind CSS, shadcn/ui |
| Backend | Go 1.25, Chi router, pgx |
| Database | PostgreSQL (Supabase) |
| Caching | Upstash Redis (REST API, 24hr TTL) |
| Auth | Clerk |
| Zmanim | Custom Go calculation engine |
| Testing | Vitest (unit), Playwright (E2E) |
| Hosting | Vercel, Fly.io, Supabase |
| Dev Environment | Coder (cloud IDE) |

## Features

- **Multi-Publisher Support** - Multiple halachic authorities can publish their zmanim
- **Algorithm DSL** - JSON-based formula definitions for custom calculations
- **Geographic Coverage** - PostGIS-powered coverage areas per publisher
- **Calculation Caching** - 24-hour cache for performance
- **Verification System** - Publisher verification workflow

## Halachic Disclaimer

Times are calculated based on astronomical and halachic methods. Consult your local rabbi for practical halachic guidance.

## License

[Add license here]

## Acknowledgments

- Calculation algorithms inspired by [KosherJava](https://github.com/KosherJava/zmanim) by Eliyahu Hershfeld
- Built with [BMad Method](https://github.com/bmad-agent/bmad-method) AI-first development methodology
