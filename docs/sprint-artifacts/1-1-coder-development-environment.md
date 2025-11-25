# Story 1.1: Coder Development Environment

Status: ready-for-dev

## Story

As a **developer**,
I want **a fully configured cloud development environment**,
so that **I can develop, test, and debug the application with consistent tooling across the team**.

## Acceptance Criteria

1. Coder workspace initializes with Go 1.21+, Node.js 20+, npm 10+
2. Start script runs web (port 3000) and API (port 8080) simultaneously
3. Supabase connection works with configured credentials
4. Playwright browsers are installed and E2E tests execute
5. Upstash Redis REST API is accessible from the environment

## Tasks / Subtasks

- [ ] Task 1: Adapt .coder directory from shtetl project (AC: 1)
  - [ ] 1.1 Copy .coder directory from shtetl repo
  - [ ] 1.2 Rename workspace from "shtetl" to "zmanim-lab"
  - [ ] 1.3 Remove multi-repo submodule configuration (single monorepo)
  - [ ] 1.4 Update workspace metadata and descriptions

- [ ] Task 2: Configure Terraform workspace tooling (AC: 1)
  - [ ] 2.1 Configure Go 1.21+ installation
  - [ ] 2.2 Configure Node.js 20 LTS installation
  - [ ] 2.3 Configure npm 10+ installation
  - [ ] 2.4 Install Supabase CLI
  - [ ] 2.5 Install Playwright browsers

- [ ] Task 3: Create/update start-services.sh script (AC: 2)
  - [ ] 3.1 Configure web frontend on port 3000
  - [ ] 3.2 Configure API backend on port 8080
  - [ ] 3.3 Add process management for concurrent services
  - [ ] 3.4 Add health check verification after startup

- [ ] Task 4: Configure environment variables (AC: 3, 5)
  - [ ] 4.1 Add DATABASE_URL (Supabase) configuration
  - [ ] 4.2 Add UPSTASH_REDIS_REST_URL configuration
  - [ ] 4.3 Add UPSTASH_REDIS_REST_TOKEN configuration
  - [ ] 4.4 Add CLERK_SECRET_KEY configuration
  - [ ] 4.5 Create .env.example with all required variables

- [ ] Task 5: Verify Playwright E2E testing (AC: 4)
  - [ ] 5.1 Verify Playwright browsers are installed
  - [ ] 5.2 Configure playwright.config.ts for local dev environment
  - [ ] 5.3 Run sample E2E test to verify setup

- [ ] Task 6: Verify external service connectivity (AC: 3, 5)
  - [ ] 6.1 Test Supabase database connection
  - [ ] 6.2 Test Upstash Redis REST API connectivity
  - [ ] 6.3 Document troubleshooting steps for connection issues

- [ ] Task 7: Update documentation (AC: all)
  - [ ] 7.1 Update README with Coder setup instructions
  - [ ] 7.2 Document environment variable requirements
  - [ ] 7.3 Add development workflow documentation

## Dev Notes

### Architecture Patterns

- **Development Environment:** Coder cloud workspace provides consistent development environment across team
- **Monorepo Structure:** Single repository with `web/` and `api/` directories
- **Port Configuration:**
  - Frontend (Next.js): port 3000
  - Backend (Go API): port 8080

### Source Tree Components

```
.coder/                    # Coder workspace configuration (TO CREATE)
  ├── main.tf              # Terraform workspace definition
  ├── variables.tf         # Variable definitions
  └── scripts/
      └── start-services.sh  # Service startup script
web/                       # Next.js frontend (existing)
api/                       # Go backend (existing)
.env.example               # Environment template (TO CREATE)
README.md                  # Setup documentation (TO UPDATE)
```

### Environment Variables Required

| Variable | Service | Purpose |
|----------|---------|---------|
| `DATABASE_URL` | Supabase | PostgreSQL connection string |
| `UPSTASH_REDIS_REST_URL` | Upstash | Redis REST API endpoint |
| `UPSTASH_REDIS_REST_TOKEN` | Upstash | Redis authentication token |
| `CLERK_SECRET_KEY` | Clerk | Backend authentication |
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | Clerk | Frontend authentication |

### Testing Standards

- **E2E Testing:** Playwright via MCP server
- **Test Execution:** Tests run against local development environment
- **Browser Support:** Chromium (primary), optionally Firefox/WebKit

### External Service Dependencies

| Service | Environment | Notes |
|---------|-------------|-------|
| Supabase | Shared dev DB | Production database for MVP |
| Upstash Redis | Shared instance | REST API for caching |
| Clerk | Development app | Auth service |
| Fly.io | N/A for this story | API deployment target |
| Vercel | N/A for this story | Frontend deployment target |

### Project Structure Notes

- **Alignment:** Story establishes the development foundation per architecture document
- **Paths:**
  - `.coder/` - Adapted from shtetl project
  - `web/` - Existing Next.js application
  - `api/` - Existing Go backend
- **No conflicts detected:** First story establishes baseline

### References

- [Source: docs/architecture.md#Project-Structure]
- [Source: docs/architecture.md#Integration-Diagram]
- [Source: docs/epics.md#Story-1.1-Coder-Development-Environment]
- [Source: docs/sprint-artifacts/tech-spec-epic-1.md#Story-1.1-Coder-Development-Environment]

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context XML will be added here by context workflow -->

### Agent Model Used

<!-- To be filled during implementation -->

### Debug Log References

<!-- To be filled during implementation -->

### Completion Notes List

<!-- To be filled during implementation -->

### File List

<!-- To be filled during implementation -->
