# Zmanim Lab - Epic Breakdown

**Author:** BMad
**Date:** 2025-11-25
**Project Type:** Brownfield (POC → Production MVP)

---

## Overview

Single epic delivering complete Zmanim Lab MVP - a multi-publisher platform for halachic authorities to publish customized prayer times with algorithm transparency.

**Architecture Decisions Applied:**
- City-based coverage (simplified from polygons) with country/region/city hierarchy
- Custom Go calculation engine (not kosher-zmanim library)
- Upstash Redis caching with 24hr TTL (FR32-33)
- TanStack Query for frontend state
- Playwright via MCP for E2E testing
- Coder cloud development environment

---

## Epic Summary

| Epic | Stories | FRs Covered | Status |
|------|---------|-------------|--------|
| **Epic 1: Zmanim Lab MVP** | 11 | FR1-FR42 | COMPLETED |
| **Epic 2: Publisher User Management** | 13 | FR43-FR66 | COMPLETED |
| **Epic 3: Consolidation & Quality** | 5 | Internal (0 FRs) | NEXT |
| **Epic 4: Algorithms** | TBD | TBD | FUTURE |

---

## FR Coverage Map

| Story | FRs |
|-------|-----|
| 1.1 Coder Development Environment | Infrastructure setup |
| 1.2 Foundation & Auth | FR2, FR5, FR6, FR39, FR40, FR41, FR42 |
| 1.3 Admin Publisher Management | FR1, FR4, FR34, FR35, FR36, FR37, FR38 |
| 1.4 Publisher Profile | FR3 |
| 1.5 Global Location System | FR21, FR22 |
| 1.6 Publisher Coverage | FR16, FR17, FR18, FR19, FR20 |
| 1.7 Calculation Engine & Caching | FR27, FR32, FR33 |
| 1.8 Algorithm Editor | FR7, FR8, FR9, FR10, FR11, FR15 |
| 1.9 Algorithm Publishing | FR12, FR13, FR14 |
| 1.10 Zmanim User Experience | FR23, FR24, FR25, FR26, FR28, FR29 |
| 1.11 Formula Reveal | FR30, FR31 |

**Coverage:** All 42 FRs included in MVP

---

## Epic 1: Zmanim Lab MVP

**Goal:** Deliver a complete, production-ready multi-publisher zmanim platform where halachic authorities can configure their calculation algorithms and end users can view zmanim with full formula transparency.

**User Value:** A rabbi can configure their preferred zmanim calculations, define their geographic coverage, and within minutes their community members can look up accurate prayer times and understand exactly how each time is calculated.

---

### Story 1.1: Coder Development Environment

**As a** developer,
**I want** a fully configured cloud development environment,
**So that** I can develop, test, and debug the application with consistent tooling across the team.

**Acceptance Criteria:**

**Given** I open the repository in Coder
**When** the workspace initializes
**Then** I have Go 1.21+, Node.js 20+, and all required tools installed

**Given** I am in the Coder workspace
**When** I run the start script
**Then** the web frontend (port 3000) and API backend (port 8080) are running

**Given** the development environment is running
**When** I access Supabase
**Then** I can connect to the database with proper credentials

**Given** I want to run E2E tests
**When** I execute Playwright tests
**Then** tests run against the local development environment

**Given** I want to cache data
**When** the API connects to Upstash Redis
**Then** I can read/write cache entries using the REST API

**Prerequisites:** None (first story)

**Technical Notes:**
- Adapt `.coder/` directory from "shtetl" project configuration
- Rename workspace from "shtetl" to "zmanim-lab"
- Configure Terraform workspace with:
  - Go 1.21+ installation
  - Node.js 20 LTS
  - npm 10+
  - Supabase CLI
  - Playwright browsers
- Update `start-services.sh` for zmanim-lab ports:
  - Web: 3000
  - API: 8080
- Configure environment variables:
  - `DATABASE_URL` (Supabase)
  - `UPSTASH_REDIS_REST_URL`
  - `UPSTASH_REDIS_REST_TOKEN`
  - `CLERK_SECRET_KEY`
- Remove multi-repo submodule configuration (single monorepo)
- Update README with setup instructions

**FRs:** Infrastructure (enables all FRs)

---

### Story 1.2: Foundation & Authentication

**As an** application user,
**I want** secure authentication and a reliable API,
**So that** I can safely access the platform with appropriate permissions.

**Acceptance Criteria:**

**Given** I am an unauthenticated user
**When** I visit the application
**Then** I can view public pages and access anonymous API endpoints (rate-limited)

**Given** I click "Sign In"
**When** the Clerk modal appears
**Then** I can authenticate via email/password or social providers

**Given** I am authenticated as a publisher
**When** I make API requests
**Then** my JWT is validated and I can access publisher-protected endpoints

**Given** I am authenticated as an admin
**When** I navigate to /admin
**Then** I can access the admin portal

**Given** I make an invalid API request
**When** the server processes it
**Then** I receive a structured error response: `{error: {code, message, details}}`

**Given** I am an anonymous user
**When** I exceed 100 requests/hour
**Then** I receive a 429 rate limit response

**Prerequisites:** Story 1.1 (Coder Development Environment)

**Technical Notes:**
- Install and configure `@clerk/nextjs` in `web/`
- Add Clerk middleware to protect `/publisher/*` and `/admin/*` routes
- Implement Go middleware in `api/internal/middleware/auth.go` for JWT validation
- Use Clerk Go SDK or manual JWT verification with JWKS
- Implement `respondJSON()` and `respondError()` helpers per architecture patterns
- Configure CORS for frontend domain in `api/internal/middleware/cors.go`
- Set up TanStack Query provider in `web/providers/QueryProvider.tsx`

**FRs:** FR2, FR5, FR6, FR39, FR40, FR41, FR42

---

### Story 1.3: Admin Publisher Management

**As an** administrator,
**I want** to create and manage publisher accounts,
**So that** I can onboard halachic authorities to the platform.

**Acceptance Criteria:**

**Given** I am logged in as an admin
**When** I navigate to /admin/publishers
**Then** I see a list of all publishers with their status (pending, verified, suspended)

**Given** I am on the publisher list
**When** I click "Create Publisher"
**Then** I see a form with fields: email, name, organization

**Given** I submit the create publisher form with valid data
**When** the system processes the request
**Then** a new publisher account is created with "pending" status
**And** the publisher receives an email invitation via Clerk

**Given** a publisher has "pending" status
**When** I click "Verify"
**Then** the publisher status changes to "verified"
**And** they can access publisher features

**Given** a publisher has "verified" status
**When** I click "Suspend"
**Then** the publisher status changes to "suspended"
**And** they cannot access publisher features

**Given** a publisher has "suspended" status
**When** I click "Reactivate"
**Then** the publisher status changes to "verified"

**Given** I am on the admin dashboard
**When** I view usage statistics
**Then** I see total publishers, active publishers, total calculations, and cache hit ratio

**Given** I am on the admin settings page
**When** I configure system settings
**Then** I can adjust rate limits, cache TTL, and feature flags

**Prerequisites:** Story 1.2 (Foundation & Auth)

**Technical Notes:**
- Create `web/app/admin/publishers/page.tsx` with publisher list
- Create `web/app/admin/publishers/new/page.tsx` for creation form
- Create `web/app/admin/dashboard/page.tsx` for stats dashboard
- Create `web/app/admin/settings/page.tsx` for system config
- Implement `api/internal/handlers/admin.go` with endpoints:
  - `GET /api/admin/publishers` - list all
  - `POST /api/admin/publishers` - create new
  - `PUT /api/admin/publishers/{id}/verify`
  - `PUT /api/admin/publishers/{id}/suspend`
  - `PUT /api/admin/publishers/{id}/reactivate`
  - `GET /api/admin/stats` - usage statistics
  - `GET /api/admin/config` - get system config
  - `PUT /api/admin/config` - update system config
- Add `publishers` table if not exists (see architecture data model)
- Add `system_config` table for feature flags and settings
- Use Clerk Admin API to create user accounts and send invitations

**FRs:** FR1, FR4, FR34, FR35, FR36, FR37, FR38

---

### Story 1.4: Publisher Profile

**As a** publisher,
**I want** to manage my profile information,
**So that** end users can identify and trust my organization.

**Acceptance Criteria:**

**Given** I am logged in as a verified publisher
**When** I navigate to /publisher/profile
**Then** I see my current profile information

**Given** I am on my profile page
**When** I update my name, organization, website, contact email, or bio
**Then** my changes are saved and displayed

**Given** I am on my profile page
**When** I upload a logo image
**Then** the logo is stored and displayed on my profile
**And** the logo appears when users view my publisher card

**Given** I leave required fields empty
**When** I try to save
**Then** I see inline validation errors below the fields

**Prerequisites:** Story 1.3 (Admin Publisher Management)

**Technical Notes:**
- Create `web/app/publisher/profile/page.tsx`
- Use shadcn/ui form components with react-hook-form
- Implement `api/internal/handlers/publishers.go`:
  - `GET /api/publisher/profile` - get own profile
  - `PUT /api/publisher/profile` - update profile
- Store logo in Supabase Storage or external CDN
- Profile fields: name, organization, email, website, bio, logo_url

**FRs:** FR3

---

### Story 1.5: Global Location System

**As a** user,
**I want** to find my location quickly,
**So that** I can see relevant zmanim publishers.

**Acceptance Criteria:**

**Given** I am on the home page
**When** I type in the location search box
**Then** I see autocomplete suggestions matching cities, regions, and countries

**Given** I search for "Brooklyn"
**When** results appear
**Then** I see "Brooklyn, New York, USA" with the full hierarchy

**Given** I search for "London"
**When** results appear
**Then** I see "London, Greater London, United Kingdom" (using UK-appropriate region type)

**Given** I click "Use My Location"
**When** I grant browser geolocation permission
**Then** my coordinates are resolved to the nearest city

**Given** the location database contains global cities
**When** I search for cities in Israel, UK, Canada, Australia, etc.
**Then** I find them with appropriate regional hierarchy (district, county, province, state)

**Prerequisites:** Story 1.2 (Foundation & Auth)

**Technical Notes:**
- Create `web/components/shared/LocationPicker.tsx` with Command (combobox) from shadcn/ui
- Implement `api/internal/handlers/cities.go`:
  - `GET /api/cities?search={query}` - search cities
  - `GET /api/cities/nearby?lat={lat}&lng={lng}` - reverse geocode
- Database schema for cities:
  ```sql
  cities (id, name, country, region, region_type, latitude, longitude, timezone, population)
  ```
- `region_type` values: 'state', 'county', 'province', 'district', 'prefecture', etc.
- Seed database with global cities (use GeoNames or similar dataset)
- Create `scripts/seed-cities.sql` or use Supabase seed

**FRs:** FR21, FR22

---

### Story 1.6: Publisher Coverage

**As a** publisher,
**I want** to define my geographic coverage areas,
**So that** users in those locations can find me.

**Acceptance Criteria:**

**Given** I am a verified publisher
**When** I navigate to /publisher/coverage
**Then** I see my current coverage areas displayed on a map

**Given** I am on the coverage page
**When** I click "Add Coverage"
**Then** I can select coverage level: Country, Region, or City

**Given** I select "Country"
**When** I search and select "Israel"
**Then** Israel is added to my coverage with all its cities included

**Given** I select "Region"
**When** I search and select "New York" (state)
**Then** all cities in New York state are included in my coverage

**Given** I select "City"
**When** I search and select "Brooklyn"
**Then** only Brooklyn is added to my coverage

**Given** I have multiple coverage areas
**When** I set priority (1-10) for each
**Then** higher priority areas take precedence when users search

**Given** I have coverage areas
**When** I toggle "Active" off for one
**Then** that area is excluded from user searches

**Prerequisites:** Story 1.5 (Global Location System)

**Technical Notes:**
- Create `web/app/publisher/coverage/page.tsx`
- Create `web/components/publisher/CitySelector.tsx` for multi-level selection
- Use a simple map component (Leaflet or Mapbox) to display selected coverage
- Implement API endpoints:
  - `GET /api/publisher/coverage` - list own coverage
  - `POST /api/publisher/coverage` - add coverage area
  - `PUT /api/publisher/coverage/{id}` - update priority/active
  - `DELETE /api/publisher/coverage/{id}` - remove coverage
- Database: `publisher_coverage (id, publisher_id, level, geo_id, priority, is_active)`
  - `level`: 'country', 'region', 'city'
  - `geo_id`: references cities.id for city, or country/region code for higher levels

**FRs:** FR16, FR17, FR18, FR19, FR20

---

### Story 1.7: Calculation Engine & Caching

**As the** system,
**I want** to calculate accurate zmanim times,
**So that** users receive correct prayer times based on publisher algorithms.

**Acceptance Criteria:**

**Given** a location with latitude, longitude, and timezone
**When** I request zmanim calculation for a specific date
**Then** the system calculates all standard zmanim times

**Given** an algorithm specifies solar_angle method with 16.1 degrees for Alos
**When** calculation runs
**Then** Alos time is when sun is 16.1° below horizon (before sunrise)

**Given** an algorithm specifies fixed_minutes method with 72 minutes for Tzeis
**When** calculation runs
**Then** Tzeis time is exactly 72 minutes after sunset

**Given** an algorithm specifies proportional method with 3 hours GRA for Sof Zman Shma
**When** calculation runs
**Then** the time is 3 proportional hours (shaos zmaniyos) after sunrise
**And** proportional hour = (sunset - sunrise) / 12

**Given** an algorithm specifies proportional method with MGA base
**When** calculation runs
**Then** proportional hours are calculated from Alos to Tzeis (not sunrise to sunset)

**Given** calculated times
**When** returned to the API
**Then** times include the formula details (method, parameters) for each zman

**Given** a zmanim calculation is requested
**When** the same publisher/city/date was calculated within 24 hours
**Then** the cached result is returned from Upstash Redis (<100ms response)

**Given** a cached calculation exists
**When** the publisher updates their algorithm
**Then** the cache for that publisher is invalidated

**Given** the cache is empty or expired
**When** a calculation is requested
**Then** the result is calculated, cached with 24hr TTL, and returned

**Prerequisites:** Story 1.2 (Foundation & Auth)

**Technical Notes:**
- Create `api/internal/astro/` package:
  - `sun.go` - sunrise/sunset calculations using solar position algorithms
  - `angles.go` - solar depression angle calculations
  - `times.go` - time arithmetic and proportional hours
- Create `api/internal/services/algorithm/`:
  - `parser.go` - parse algorithm DSL JSON
  - `executor.go` - execute algorithm against date/location
  - `methods.go` - implement calculation methods
- Reference kosher-zmanim for algorithm inspiration but implement from scratch
- Test against known reference values (e.g., MyZmanim, Chabad.org)
- All times in UTC internally, convert to local timezone on output
- Create `api/internal/services/cache_service.go`:
  - Use Upstash Redis REST API (github.com/upstash/go-upstash-redis)
  - Cache key format: `zmanim:{publisher_id}:{city_id}:{date}`
  - TTL: 24 hours
  - Invalidation: Pattern delete on algorithm publish
- Environment variables: `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`

**FRs:** FR27, FR32, FR33

---

### Story 1.8: Algorithm Editor

**As a** publisher,
**I want** to configure my zmanim calculation algorithm,
**So that** my community receives times according to my halachic opinions.

**Acceptance Criteria:**

**Given** I am a verified publisher
**When** I navigate to /publisher/algorithm
**Then** I see my current algorithm configuration (or empty state if none)

**Given** I am creating a new algorithm
**When** I click "Start from Template"
**Then** I can choose: Standard GRA, Magen Avraham, Rabbeinu Tam, or Custom

**Given** I am editing an algorithm
**When** I click on a zman (e.g., Alos Hashachar)
**Then** a modal opens with configuration options:
- Method: Solar Angle / Fixed Minutes / Proportional
- Parameters based on method (degrees, minutes, hours, base)

**Given** I configure Alos with solar_angle 16.1°
**When** I look at the preview panel
**Then** I see the calculated time for today's date at a sample location

**Given** I click "View Month"
**When** the preview expands
**Then** I see a calendar month view with all zmanim for each day

**Given** I enter invalid configuration (e.g., negative degrees)
**When** I try to save
**Then** I see validation error and cannot save

**Given** I have unsaved changes
**When** I try to navigate away
**Then** I am warned about losing changes

**Prerequisites:** Story 1.7 (Calculation Engine & Caching)

**Technical Notes:**
- Create `web/app/publisher/algorithm/page.tsx`
- Create `web/components/publisher/AlgorithmEditor.tsx`:
  - List of zmanim with current configuration
  - Modal for editing each zman
  - Live preview panel
  - Month view expansion
- Use shadcn/ui Dialog, Select, Input components
- Algorithm stored as JSON DSL (see architecture):
  ```json
  {
    "name": "My Algorithm",
    "zmanim": {
      "alos": {"method": "solar_angle", "params": {"degrees": 16.1}},
      ...
    }
  }
  ```
- API endpoints:
  - `GET /api/publisher/algorithm` - get current algorithm
  - `PUT /api/publisher/algorithm` - save algorithm (draft)
  - `POST /api/publisher/algorithm/preview` - calculate preview

**FRs:** FR7, FR8, FR9, FR10, FR11, FR15

---

### Story 1.9: Algorithm Publishing

**As a** publisher,
**I want** to publish my algorithm to make it active,
**So that** end users can see zmanim calculated with my method.

**Acceptance Criteria:**

**Given** I have a configured algorithm in draft status
**When** I click "Publish"
**Then** the algorithm becomes active and visible to users

**Given** I have a published algorithm
**When** I make changes and save
**Then** changes are saved as a new draft version
**And** the published version remains active

**Given** I have draft changes
**When** I click "Publish Changes"
**Then** the draft becomes the new active version
**And** the old version is archived

**Given** I have multiple algorithm versions
**When** I view version history
**Then** I see all versions with dates and can compare

**Given** I have an old published version
**When** I click "Deprecate"
**Then** that version is marked deprecated
**And** users on that version see a notice to refresh

**Prerequisites:** Story 1.8 (Algorithm Editor)

**Technical Notes:**
- Add version management to algorithm table:
  ```sql
  algorithms (id, publisher_id, version, config, status, created_at)
  ```
  - `status`: 'draft', 'published', 'deprecated'
- API endpoints:
  - `POST /api/publisher/algorithm/publish` - publish current draft
  - `GET /api/publisher/algorithm/versions` - list versions
  - `PUT /api/publisher/algorithm/versions/{id}/deprecate`
- Only one active (published) version per publisher at a time
- When new version published, old version auto-archived

**FRs:** FR12, FR13, FR14

---

### Story 1.10: Zmanim User Experience

**As an** end user,
**I want** to view zmanim times for my location,
**So that** I know when to pray according to my chosen authority.

**Acceptance Criteria:**

**Given** I am on the home page
**When** I select my city
**Then** I see a list of publishers covering that location

**Given** I see the publisher list
**When** publishers are displayed
**Then** they are sorted by priority (higher first), then alphabetically
**And** each card shows: name, organization, logo

**Given** I click on a publisher card
**When** I view publisher details
**Then** I see their full profile before selecting

**Given** I select a publisher
**When** the zmanim page loads
**Then** I see today's zmanim times in a clean list:
- Zman name, time, info icon (ⓘ)
- Times in local timezone with AM/PM

**Given** I am viewing zmanim
**When** I click the date navigation arrows (← →)
**Then** I can view zmanim for any past or future date

**Given** I am viewing zmanim
**When** I click the date
**Then** a date picker opens for quick navigation

**Given** no publisher covers my location
**When** I search for my city
**Then** I see a warning: "No local authority covers this area yet"
**And** I see default (non-authoritative) zmanim with disclaimer

**Prerequisites:** Story 1.6 (Publisher Coverage), Story 1.7 (Calculation Engine & Caching)

**Technical Notes:**
- Create `web/app/zmanim/page.tsx` - location selection
- Create `web/app/zmanim/[city]/page.tsx` - publisher list
- Create `web/app/zmanim/[city]/[publisher]/page.tsx` - zmanim display
- Create components:
  - `web/components/shared/PublisherCard.tsx`
  - `web/components/zmanim/ZmanimList.tsx`
  - `web/components/zmanim/ZmanRow.tsx`
- Use Luxon for date handling and timezone conversion
- Implement `GET /api/cities/{cityId}/publishers` - list publishers for city
- Implement `GET /api/zmanim?cityId={}&publisherId={}&date={}` - calculate zmanim
- Store last selected city in localStorage (FR per UX spec)

**FRs:** FR23, FR24, FR25, FR26, FR28, FR29

---

### Story 1.11: Formula Reveal

**As an** end user,
**I want** to see how each zmanim time is calculated,
**So that** I understand the halachic basis for my prayer times.

**Acceptance Criteria:**

**Given** I am viewing zmanim times
**When** I click the info icon (ⓘ) next to any time
**Then** a panel slides in showing formula details

**Given** I am on desktop (≥768px)
**When** the formula panel opens
**Then** it slides in from the right as a side panel

**Given** I am on mobile (<768px)
**When** the formula panel opens
**Then** it slides up from the bottom as a bottom sheet

**Given** the formula panel is open
**When** I view the contents
**Then** I see:
- Zman name (e.g., "Alos HaShachar")
- Method name (e.g., "Solar Depression Angle")
- Parameters (e.g., "16.1° below horizon")
- Brief explanation (e.g., "Dawn begins when the sun is 16.1° below the eastern horizon")

**Given** the publisher provided halachic context
**When** I view the formula panel
**Then** I also see the halachic source/reasoning (optional field)

**Given** the formula panel is open
**When** I click outside, press X, or swipe down (mobile)
**Then** the panel closes

**Prerequisites:** Story 1.10 (Zmanim User Experience)

**Technical Notes:**
- Create `web/components/zmanim/FormulaPanel.tsx`
- Use Radix Dialog (via shadcn/ui Sheet component) for side panel
- Implement responsive behavior with `useMediaQuery` hook or CSS media queries
- Formula data is included in zmanim API response (no extra API call):
  ```json
  {
    "name": "Alos HaShachar",
    "time": "05:23:00",
    "formula": {
      "method": "solar_angle",
      "display_name": "Solar Depression Angle",
      "parameters": {"degrees": 16.1},
      "explanation": "Dawn begins when..."
    }
  }
  ```
- Add subtle slide animation via Tailwind/CSS transitions
- Ensure keyboard accessibility (Escape to close, focus trap)

**FRs:** FR30, FR31

---

## FR Coverage Matrix

| FR | Description | Story |
|----|-------------|-------|
| FR1 | Admin creates publisher accounts | 1.3 |
| FR2 | Publishers login via Clerk | 1.2 |
| FR3 | Publishers update profile | 1.4 |
| FR4 | Admin verify/suspend/reactivate | 1.3 |
| FR5 | Anonymous access | 1.2 |
| FR6 | Auth users higher rate limits | 1.2 |
| FR7 | Create algorithms | 1.8 |
| FR8 | Configure zmanim methods | 1.8 |
| FR9 | Algorithm templates | 1.8 |
| FR10 | Preview calculations (+ month) | 1.8 |
| FR11 | Save as draft | 1.8 |
| FR12 | Publish algorithms | 1.9 |
| FR13 | Update creates new version | 1.9 |
| FR14 | Deprecate old versions | 1.9 |
| FR15 | Validate before publish | 1.8 |
| FR16 | Define coverage (country/region/city) | 1.6 |
| FR17 | View coverage on map | 1.6 |
| FR18 | Coverage priorities | 1.6 |
| FR19 | Name/describe coverage | 1.6 |
| FR20 | Activate/deactivate coverage | 1.6 |
| FR21 | Search locations | 1.5 |
| FR22 | Browser geolocation | 1.5 |
| FR23 | Display publishers for location | 1.10 |
| FR24 | Sort by priority/distance | 1.10 |
| FR25 | View publisher profile | 1.10 |
| FR26 | Select publisher for zmanim | 1.10 |
| FR27 | Calculate using algorithm | 1.7 |
| FR28 | Date selection | 1.10 |
| FR29 | Timezone display | 1.10 |
| FR30 | Reveal formula | 1.11 |
| FR31 | Show method/params/explanation | 1.11 |
| FR32 | Cache calculations (Upstash Redis) | 1.7 |
| FR33 | Cache invalidation | 1.7 |
| FR34 | Admin view publishers | 1.3 |
| FR35 | Admin create publishers | 1.3 |
| FR36 | Admin verify publishers | 1.3 |
| FR37 | Admin usage stats | 1.3 |
| FR38 | Admin system config | 1.3 |
| FR39 | REST API endpoints | 1.2 |
| FR40 | Error messages | 1.2 |
| FR41 | Rate limiting | 1.2 |
| FR42 | CORS support | 1.2 |

---

## Summary

**Epic 1: Zmanim Lab MVP**
- **Stories:** 11
- **FRs Covered:** 42 of 42 (100%)
- **Sequence:** Coder → Foundation → Publisher Management → Location → Algorithms → User Experience

**Story Dependency Chain:**
```
1.1 Coder Development Environment
 └── 1.2 Foundation
      ├── 1.3 Admin Publisher Management
      │    └── 1.4 Publisher Profile
      ├── 1.5 Global Location System
      │    └── 1.6 Publisher Coverage
      └── 1.7 Calculation Engine & Caching
           └── 1.8 Algorithm Editor
                └── 1.9 Algorithm Publishing
                     └── 1.10 Zmanim UX
                          └── 1.11 Formula Reveal
```

**After Epic 1 Completion:**
- Admins can onboard publishers
- Publishers can configure algorithms and define global coverage
- Users can find their location, select a publisher, view zmanim, and understand the calculations
- Calculations are cached with 24hr TTL via Upstash Redis
- **MVP is complete!**

---

## Epic 2: Publisher User Management & Dashboard

**Status:** COMPLETED (2025-11-26)
**Stories:** 13 (2.0 - 2.12)
**FRs:** FR43-FR66

See: [epic-2-publisher-user-management.md](epic-2-publisher-user-management.md)

**Key Deliverables:**
- Multi-publisher user access and switcher (FR43-FR46)
- Admin impersonation mode (FR47-FR49)
- Publisher dashboard hub (FR50)
- Enhanced coverage management (FR51-FR52)
- Analytics and activity logging (FR53-FR54)
- Email service via Resend (FR61-FR62, FR66)
- Self-service publisher registration (FR55-FR57)
- Publisher team invitations (FR58-FR60)
- User profile dropdown (FR63-FR65)

---

## Epic 3: Consolidation & Quality

**Status:** NEXT
**Stories:** 5 (3.0 - 3.4)
**FRs:** None (internal quality work)

See: [epic-3-consolidation-quality.md](epic-3-consolidation-quality.md)

**Goal:** Harden the foundation before building new features. Quality as a first-class citizen.

**Stories:**
| Story | Name | Focus |
|-------|------|-------|
| 3.0 | Testing Infrastructure | Clerk auth helpers, test fixtures |
| 3.1 | Comprehensive E2E Test Suite | 50+ scenarios validating Epic 1 & 2 |
| 3.2 | Codebase Audit & Documentation | Study patterns, document learnings |
| 3.3 | Coding Standards & Architecture | Formalize patterns, update docs |
| 3.4 | Refactor to Standards | Apply standards, fix inconsistencies |

**Key Outcomes:**
- `loginAsAdmin()` and `loginAsPublisher()` test helpers
- Comprehensive E2E coverage for authenticated flows
- `coding-standards.md` with clear guidelines
- Updated `architecture.md` with proven patterns
- Technical debt reduced
- New Definition of Done includes mandatory E2E tests

---

## Epic 4: Algorithms (Future)

**Status:** FUTURE (after Epic 3)
**Stories:** TBD
**FRs:** TBD

Enhanced algorithm features built on the solid, tested, documented foundation from Epic 3.

---

_Generated by BMAD Epic Workflow v1.0_
_Last Updated: 2025-11-27_
