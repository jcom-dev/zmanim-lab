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

### Prerequisites

- Node.js 18+
- Go 1.21+
- Supabase account
- Clerk account

### Frontend (web/)

```bash
cd web
npm install
cp .env.example .env.local
# Edit .env.local with your API URL and Clerk keys
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Backend (api/)

```bash
cd api
cp .env.example .env
# Edit .env with your Supabase credentials
go run ./cmd/api
```

API available at [http://localhost:8080](http://localhost:8080)

### Database

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Apply migrations from `supabase/migrations/`
3. Configure environment variables with your Supabase credentials

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
| Frontend | Next.js 16, React 19, TypeScript, Tailwind CSS |
| Backend | Go 1.21, Chi router, pgx |
| Database | PostgreSQL + PostGIS (Supabase) |
| Auth | Clerk |
| Zmanim | kosher-zmanim library |
| Hosting | Vercel, Fly.io, Supabase |

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

- Powered by [kosher-zmanim](https://github.com/BehindTheMath/KosherZmanim) - TypeScript port of KosherJava
- Original KosherJava library by Eliyahu Hershfeld
