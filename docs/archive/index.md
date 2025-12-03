> **ARCHIVED DOCUMENT**: This file is historical and references outdated technology (Supabase).
> The project now uses Xata for PostgreSQL hosting. See `docs/README.md` for current documentation.

# Zmanim Lab Documentation

> **Halachic Zmanim Publishing Platform** - A portal for rabbinic authorities to publish customized Jewish prayer times with full algorithm control.

## Project Overview

| Attribute | Value |
|-----------|-------|
| **Project Name** | Zmanim Lab (Alos Hashachar Calculator) |
| **Repository Type** | Multi-part (Web + API) |
| **Domain** | Jewish Prayer Times (Zmanim) Calculation |
| **Primary Users** | Rabbinic/Halachic authorities (publishers) |
| **Secondary Users** | End users consuming published zmanim |

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                        Zmanim Lab                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   Web Frontend  │───▶│   Go Backend    │───▶│  Supabase   │ │
│  │   (Next.js)     │    │   (Chi Router)  │    │ (PostgreSQL)│ │
│  │   Port: 3000    │    │   Port: 8080    │    │   + PostGIS │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│         │                       │                     │         │
│         ▼                       ▼                     ▼         │
│      Vercel               Fly.io                Supabase.com    │
│     (planned)            (deployed)              (hosted)       │
└─────────────────────────────────────────────────────────────────┘
```

## Documentation Index

### Core Documentation

| Document | Description |
|----------|-------------|
| [Architecture](./ARCHITECTURE.md) | Comprehensive system design, database schema, API design |
| [API Reference](./api-reference.md) | REST API endpoints and usage |
| [Data Models](./data-models.md) | Database tables and Go/TypeScript models |
| [Frontend Components](./frontend-components.md) | React components and UI patterns |
| [Deployment Guide](./deployment.md) | Fly.io, Vercel, and local development setup |

### Quick Links

| Resource | Location |
|----------|----------|
| Frontend README | [/README.md](../README.md) |
| Backend README | [/backend/README.md](../backend/README.md) |
| Database Setup | [/setup-database.md](../setup-database.md) |
| DB Migrations | [/supabase/migrations/](../supabase/migrations/) |

## Technology Stack

### Web Frontend (Root Directory)

| Category | Technology | Purpose |
|----------|------------|---------|
| Framework | Next.js 16 | React framework with App Router |
| Language | TypeScript | Type-safe JavaScript |
| UI | React 19 | Component library |
| Styling | Tailwind CSS | Utility-first CSS |
| Date/Time | Luxon | DateTime manipulation |
| Zmanim | kosher-zmanim | Astronomical calculations |
| Testing | Playwright, Jest | E2E and unit tests |

### Backend API (backend/ Directory)

| Category | Technology | Purpose |
|----------|------------|---------|
| Language | Go 1.21 | High-performance API |
| Router | Chi v5 | HTTP routing |
| Database | pgx v5 | PostgreSQL driver |
| Config | godotenv | Environment management |
| Container | Docker | Deployment packaging |

### Database (Supabase)

| Feature | Technology | Purpose |
|---------|------------|---------|
| Database | PostgreSQL | Primary data store |
| Geospatial | PostGIS | Coverage area queries |
| API | Supabase Client | Direct DB access (frontend) |

### Authentication (Clerk)

| Feature | Technology | Purpose |
|---------|------------|---------|
| Auth Provider | Clerk | User authentication & management |
| Session | Clerk Session | JWT-based sessions |
| UI Components | Clerk React | Sign-in/sign-up flows |

## Key Features

1. **Multi-Publisher Support** - Multiple halachic authorities can publish their own zmanim calculations
2. **Algorithm DSL** - JSON-based formula definitions for customizable calculations
3. **Geographic Coverage** - PostGIS-powered coverage areas per publisher
4. **Calculation Caching** - 24-hour cache for performance optimization
5. **Verification System** - Publisher verification workflow

## Project Structure

```
zmanim-lab/
├── app/                    # Next.js App Router pages
├── components/             # React components
├── lib/                    # Frontend utilities
├── backend/
│   ├── cmd/api/           # Go entry point
│   └── internal/          # Go packages
│       ├── config/        # Environment config
│       ├── db/            # Database connection
│       ├── handlers/      # HTTP handlers
│       ├── middleware/    # HTTP middleware
│       ├── models/        # Domain models
│       └── services/      # Business logic
├── supabase/
│   └── migrations/        # SQL migrations
├── docs/                   # Documentation
└── public/                # Static assets
```

## Planned Changes

| Change | Description | Status |
|--------|-------------|--------|
| Repo Restructure | Separate `web/` and `api/` directories | Planned |
| Vercel Deployment | Auto-deploy frontend from GitHub | Planned |
| GitHub Actions CI/CD | Automated testing and deployment | Planned |
| Coder/Devcontainer | Local development environment | Planned |

---

*Generated by BMAD Document Project Workflow - 2025-11-25*
