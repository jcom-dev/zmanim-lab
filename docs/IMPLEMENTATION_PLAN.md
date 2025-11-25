# Zmanim Lab - Implementation Plan

## Overview

This document provides a comprehensive plan for implementing the complete Zmanim Lab multi-publisher platform, including backend, frontend, database setup, and deployment strategy.

## Table of Contents

1. [Deployment Strategy & Cost Analysis](#deployment-strategy--cost-analysis)
2. [Supabase Setup](#supabase-setup)
3. [Backend Implementation](#backend-implementation)
4. [Frontend Implementation](#frontend-implementation)
5. [Deployment Pipeline](#deployment-pipeline)
6. [Development Timeline](#development-timeline)

---

## Deployment Strategy & Cost Analysis

### Recommended Cheap Deployment Options

#### 1. **Backend (Go API) Deployment**

**Option A: Fly.io (Recommended - $0-5/month)**
- Free tier: 3 shared-cpu-1x VMs with 256MB RAM each
- Automatic SSL certificates
- Global edge deployment
- Pay-as-you-go beyond free tier (~$2-5/month for small apps)
- Perfect for Go applications

**Option B: Railway.app ($5/month)**
- $5 starter plan with generous resources
- Easy deployment from GitHub
- Built-in metrics and logs
- Automatic SSL

**Option C: Google Cloud Run (Free tier)**
- 2 million requests/month free
- 180,000 vCPU-seconds/month free
- 360,000 GiB-seconds/month free
- Pay only for usage beyond free tier
- Auto-scaling to zero

**Option D: Render.com ($7/month)**
- Free tier available but spins down after inactivity
- $7/month for always-on instance
- Easy GitHub integration

**RECOMMENDATION: Fly.io** - Best balance of free tier + low cost + performance

#### 2. **Frontend Deployment**

**Vercel (Free tier - $0/month)**
- Unlimited personal projects
- 100 GB bandwidth/month
- Automatic SSL
- Global CDN
- Zero configuration for Next.js
- Perfect for this project

**Alternative: Netlify (Free tier)**
- 100 GB bandwidth/month
- Similar features to Vercel
- Good for static sites

**RECOMMENDATION: Vercel** - Built by Next.js creators, zero config

#### 3. **Database (Supabase)**

**Supabase Free Tier ($0/month)**
- 500 MB database space
- Unlimited API requests
- 50,000 monthly active users
- 2 GB file storage
- Social OAuth providers
- 1 GB bandwidth
- 7-day log retention

**Paid tier if needed: $25/month**
- 8 GB database
- 100 GB bandwidth
- Daily backups

**RECOMMENDATION: Start with free tier** - More than sufficient for initial launch

#### 4. **Redis Cache**

**Upstash Redis (Free tier - $0/month)**
- 10,000 commands/day
- 256 MB storage
- Global replication
- HTTP-based (serverless-friendly)

**Paid tier: ~$10/month**
- 100,000 commands/day
- 1 GB storage

**RECOMMENDATION: Upstash Redis free tier**

### Total Estimated Monthly Costs

| Service | Free Tier | Paid (if needed) |
|---------|-----------|------------------|
| Go Backend (Fly.io) | $0 | $5 |
| Frontend (Vercel) | $0 | $0 |
| Database (Supabase) | $0 | $25 |
| Redis (Upstash) | $0 | $10 |
| **TOTAL** | **$0/month** | **$40/month max** |

**Target: Start with $0/month, scale as needed**

---

## Supabase Setup

### Step 1: Create Supabase Project

```bash
# 1. Go to https://supabase.com
# 2. Sign up/Sign in
# 3. Create new project
#    - Project name: zmanim-lab
#    - Database password: (generate strong password)
#    - Region: Choose closest to your users
#    - Pricing: Free tier
```

### Step 2: Install Supabase CLI

```bash
# Install Supabase CLI
npm install -g supabase

# OR using Homebrew (macOS)
brew install supabase/tap/supabase

# Login
supabase login
```

### Step 3: Initialize Project

```bash
# In project root
supabase init

# Link to your Supabase project
supabase link --project-ref your-project-ref
```

### Step 4: Database Schema Setup

Create migration file:

```bash
# Create initial migration
supabase migration new initial_schema
```

**File: `supabase/migrations/20240001_initial_schema.sql`**

```sql
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Publishers table
CREATE TABLE publishers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    organization VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    website VARCHAR(500),
    logo_url VARCHAR(500),
    contact_info JSONB DEFAULT '{}',
    status VARCHAR(20) NOT NULL DEFAULT 'pending_verification',
    verified_at TIMESTAMP WITH TIME ZONE,
    verified_by UUID REFERENCES auth.users(id),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT publishers_status_check
        CHECK (status IN ('pending_verification', 'verified', 'active', 'suspended', 'retired'))
);

CREATE INDEX idx_publishers_status ON publishers(status);
CREATE INDEX idx_publishers_slug ON publishers(slug);

-- Algorithms table
CREATE TABLE algorithms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    version VARCHAR(50) NOT NULL,
    description TEXT,
    formula_definition JSONB NOT NULL,
    calculation_type VARCHAR(50) NOT NULL,
    validation_status VARCHAR(20) DEFAULT 'pending',
    validation_results JSONB,
    is_active BOOLEAN DEFAULT FALSE,
    published_at TIMESTAMP WITH TIME ZONE,
    deprecated_at TIMESTAMP WITH TIME ZONE,
    tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT algorithms_version_unique UNIQUE (publisher_id, name, version),
    CONSTRAINT algorithms_calc_type_check
        CHECK (calculation_type IN ('solar_depression', 'fixed_minutes', 'proportional', 'custom'))
);

CREATE INDEX idx_algorithms_publisher ON algorithms(publisher_id);
CREATE INDEX idx_algorithms_active ON algorithms(is_active);
CREATE INDEX idx_algorithms_type ON algorithms(calculation_type);

-- Geographic Regions table
CREATE TABLE geographic_regions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    name_local VARCHAR(255),
    type VARCHAR(50) NOT NULL,
    parent_id UUID REFERENCES geographic_regions(id),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    boundary GEOGRAPHY(POLYGON, 4326),
    country_code VARCHAR(2),
    timezone VARCHAR(100) NOT NULL,
    elevation NUMERIC,
    population INT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_geo_regions_location ON geographic_regions USING GIST(location);
CREATE INDEX idx_geo_regions_boundary ON geographic_regions USING GIST(boundary);
CREATE INDEX idx_geo_regions_type ON geographic_regions(type);
CREATE INDEX idx_geo_regions_parent ON geographic_regions(parent_id);

-- Coverage Areas table
CREATE TABLE coverage_areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    boundary GEOGRAPHY(POLYGON, 4326) NOT NULL,
    center_point GEOGRAPHY(POINT, 4326),
    priority INT DEFAULT 0,
    country_code VARCHAR(2),
    region VARCHAR(100),
    city VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_coverage_publisher ON coverage_areas(publisher_id);
CREATE INDEX idx_coverage_boundary ON coverage_areas USING GIST(boundary);
CREATE INDEX idx_coverage_center ON coverage_areas USING GIST(center_point);
CREATE INDEX idx_coverage_active ON coverage_areas(is_active);

-- User Profiles table
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name VARCHAR(255),
    avatar_url VARCHAR(500),
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Subscriptions table
CREATE TABLE user_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    subscribed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT user_subscriptions_unique UNIQUE (user_id, publisher_id)
);

CREATE INDEX idx_user_subs_user ON user_subscriptions(user_id);
CREATE INDEX idx_user_subs_publisher ON user_subscriptions(publisher_id);

-- Calculation Cache table
CREATE TABLE calculation_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    algorithm_id UUID NOT NULL REFERENCES algorithms(id) ON DELETE CASCADE,
    location_id UUID NOT NULL REFERENCES geographic_regions(id),
    calculation_date DATE NOT NULL,
    zmanim_data JSONB NOT NULL,
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    hit_count INT DEFAULT 0,
    CONSTRAINT calc_cache_unique UNIQUE (algorithm_id, location_id, calculation_date)
);

CREATE INDEX idx_calc_cache_algo_loc_date ON calculation_cache(algorithm_id, location_id, calculation_date);
CREATE INDEX idx_calc_cache_expires ON calculation_cache(expires_at);

-- Audit Logs table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL,
    actor_id UUID REFERENCES auth.users(id),
    changes JSONB,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_actor ON audit_logs(actor_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers
CREATE TRIGGER update_publishers_updated_at BEFORE UPDATE ON publishers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_algorithms_updated_at BEFORE UPDATE ON algorithms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_coverage_areas_updated_at BEFORE UPDATE ON coverage_areas
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_geo_regions_updated_at BEFORE UPDATE ON geographic_regions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Step 5: Seed Initial Data

**File: `supabase/seed.sql`**

```sql
-- Seed geographic regions (major cities)
INSERT INTO geographic_regions (name, name_local, type, location, timezone, elevation, population, country_code) VALUES
('Jerusalem', 'ירושלים', 'city', ST_SetSRID(ST_MakePoint(35.2137, 31.7683), 4326), 'Asia/Jerusalem', 754, 936425, 'IL'),
('Tel Aviv', 'תל אביב', 'city', ST_SetSRID(ST_MakePoint(34.7818, 32.0853), 4326), 'Asia/Jerusalem', 5, 460613, 'IL'),
('New York', 'New York', 'city', ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326), 'America/New_York', 10, 8336817, 'US'),
('Los Angeles', 'Los Angeles', 'city', ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326), 'America/Los_Angeles', 93, 3979576, 'US'),
('London', 'London', 'city', ST_SetSRID(ST_MakePoint(-0.1278, 51.5074), 4326), 'Europe/London', 11, 8982000, 'GB'),
('Paris', 'Paris', 'city', ST_SetSRID(ST_MakePoint(2.3522, 48.8566), 4326), 'Europe/Paris', 35, 2161000, 'FR');

-- Seed example publisher
INSERT INTO publishers (name, organization, slug, email, description, website, status, verified_at) VALUES
('Chief Rabbinate of Israel', 'Israel Chief Rabbinate', 'israel-chief-rabbinate', 'info@rabbinate.gov.il',
 'Official Jewish legal authority in Israel', 'https://www.rabbinate.gov.il', 'active', NOW());

-- Get publisher ID for algorithm
DO $$
DECLARE
    publisher_uuid UUID;
BEGIN
    SELECT id INTO publisher_uuid FROM publishers WHERE slug = 'israel-chief-rabbinate';

    -- Seed example algorithm
    INSERT INTO algorithms (publisher_id, name, version, description, calculation_type, formula_definition, is_active, published_at) VALUES
    (publisher_uuid, 'Standard Israeli Calculation', '2.0', 'Standard calculation method used in Israel', 'solar_depression',
     '{
       "version": "1.0",
       "type": "solar_depression",
       "zmanim": {
         "alos_hashachar": {"method": "solar_angle", "angle_degrees": 16.1, "direction": "before_sunrise"},
         "sunrise": {"method": "elevation_adjusted", "refraction": 0.833},
         "sof_zman_shma": {"method": "shaos_zmaniyos", "hours": 3, "base": "sunrise"},
         "sof_zman_tefillah": {"method": "shaos_zmaniyos", "hours": 4, "base": "sunrise"},
         "chatzos": {"method": "midpoint", "between": ["sunrise", "sunset"]},
         "mincha_gedola": {"method": "fixed_offset", "minutes": 30, "base": "chatzos", "direction": "after"},
         "mincha_ketana": {"method": "shaos_zmaniyos", "hours": 9.5, "base": "sunrise"},
         "plag_hamincha": {"method": "shaos_zmaniyos", "hours": 10.75, "base": "sunrise"},
         "sunset": {"method": "elevation_adjusted", "refraction": 0.833},
         "tzeis": {"method": "solar_angle", "angle_degrees": 8.5, "direction": "after_sunset"}
       },
       "shaah_zmanis_method": {"type": "gra", "start": "sunrise", "end": "sunset"}
     }'::jsonb,
     TRUE, NOW());

    -- Seed coverage area for Israel
    INSERT INTO coverage_areas (publisher_id, name, description, boundary, priority, country_code, is_active) VALUES
    (publisher_uuid, 'All of Israel', 'National coverage for Israel',
     ST_SetSRID(ST_GeomFromText('POLYGON((34.2 29.5, 35.9 29.5, 35.9 33.3, 34.2 33.3, 34.2 29.5))'), 4326),
     10, 'IL', TRUE);
END $$;
```

### Step 6: Apply Migrations

```bash
# Push migrations to Supabase
supabase db push

# OR if using Supabase dashboard
# Copy SQL content and run in SQL Editor
```

### Step 7: Configure Row Level Security (RLS)

```sql
-- Enable RLS on all tables
ALTER TABLE publishers ENABLE ROW LEVEL SECURITY;
ALTER TABLE algorithms ENABLE ROW LEVEL SECURITY;
ALTER TABLE coverage_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

-- Public read access to published data
CREATE POLICY "Public can view active publishers"
    ON publishers FOR SELECT
    USING (status = 'active');

CREATE POLICY "Public can view active algorithms"
    ON algorithms FOR SELECT
    USING (is_active = TRUE);

-- Publishers can manage their own data
CREATE POLICY "Publishers can update own profile"
    ON publishers FOR UPDATE
    USING (auth.uid() IN (
        SELECT verified_by FROM publishers WHERE id = publishers.id
    ));

-- Users can manage their own profiles
CREATE POLICY "Users can view own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = id);

-- Users can manage their subscriptions
CREATE POLICY "Users can manage own subscriptions"
    ON user_subscriptions FOR ALL
    USING (auth.uid() = user_id);
```

---

## Backend Implementation

### Project Structure

```
backend/
├── cmd/
│   └── api/
│       └── main.go              # Application entry point
├── internal/
│   ├── config/
│   │   └── config.go            # Configuration management
│   ├── db/
│   │   ├── supabase.go          # Supabase client
│   │   └── queries.sql          # SQL queries (for sqlc)
│   ├── handlers/
│   │   ├── zmanim.go            # Zmanim calculation endpoints
│   │   ├── publishers.go        # Publisher management
│   │   ├── locations.go         # Location search
│   │   └── users.go             # User management
│   ├── middleware/
│   │   ├── auth.go              # JWT authentication
│   │   ├── cors.go              # CORS configuration
│   │   ├── logging.go           # Request logging
│   │   └── ratelimit.go         # Rate limiting
│   ├── models/
│   │   ├── publisher.go         # Data models
│   │   ├── algorithm.go
│   │   ├── location.go
│   │   └── zmanim.go
│   ├── services/
│   │   ├── calculation.go       # Zmanim calculation logic
│   │   ├── publisher.go         # Publisher business logic
│   │   ├── location.go          # Location services
│   │   └── cache.go             # Redis caching
│   └── utils/
│       ├── response.go          # HTTP response helpers
│       └── validation.go        # Input validation
├── pkg/
│   └── solar/
│       └── calculator.go        # Solar calculation algorithms
├── migrations/
│   └── *.sql                    # Database migrations
├── Dockerfile
├── go.mod
├── go.sum
└── .env.example
```

### Key Files to Create

**`cmd/api/main.go`**

```go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "github.com/your-org/zmanim-lab/internal/config"
    "github.com/your-org/zmanim-lab/internal/handlers"
    "github.com/your-org/zmanim-lab/internal/middleware"
)

func main() {
    // Load configuration
    cfg := config.Load()

    // Initialize services
    // (Database, Redis, etc.)

    // Setup router
    r := chi.NewRouter()

    // Middleware
    r.Use(middleware.Logger)
    r.Use(middleware.Recoverer)
    r.Use(custommiddleware.CORS)
    r.Use(custommiddleware.RateLimit)

    // Health check
    r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })

    // API routes
    r.Route("/api/v1", func(r chi.Router) {
        // Public routes
        r.Get("/locations/search", handlers.SearchLocations)
        r.Get("/publishers", handlers.ListPublishers)
        r.Post("/zmanim/calculate", handlers.CalculateZmanim)

        // Authenticated routes
        r.Group(func(r chi.Router) {
            r.Use(custommiddleware.AuthRequired)
            r.Post("/users/subscriptions", handlers.CreateSubscription)
        })

        // Publisher routes
        r.Group(func(r chi.Router) {
            r.Use(custommiddleware.PublisherAuth)
            r.Post("/algorithms", handlers.CreateAlgorithm)
        })
    })

    // Start server
    srv := &http.Server{
        Addr:    ":" + cfg.Port,
        Handler: r,
    }

    // Graceful shutdown
    go func() {
        sigint := make(chan os.Signal, 1)
        signal.Notify(sigint, os.Interrupt, syscall.SIGTERM)
        <-sigint

        ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
        defer cancel()
        if err := srv.Shutdown(ctx); err != nil {
            log.Printf("HTTP server shutdown error: %v", err)
        }
    }()

    log.Printf("Server starting on port %s", cfg.Port)
    if err := srv.ListenAndServe(); err != http.ErrServerClosed {
        log.Fatalf("HTTP server error: %v", err)
    }
}
```

**`Dockerfile`**

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./cmd/api

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
```

**`.env.example`**

```bash
# Server
PORT=8080
ENVIRONMENT=development

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key
DATABASE_URL=postgresql://postgres:password@db.your-project.supabase.co:5432/postgres

# Redis (Upstash)
REDIS_URL=https://your-redis.upstash.io
REDIS_TOKEN=your-redis-token

# JWT
JWT_SECRET=your-jwt-secret

# CORS
ALLOWED_ORIGINS=http://localhost:3000

# Rate Limiting
RATE_LIMIT_REQUESTS=60
RATE_LIMIT_DURATION=1m
```

---

## Frontend Implementation

### Enhanced Project Structure

```
frontend/
├── app/
│   ├── (auth)/
│   │   ├── login/
│   │   └── signup/
│   ├── (main)/
│   │   ├── page.tsx            # Main calculator
│   │   ├── publishers/
│   │   │   ├── page.tsx        # Publisher list
│   │   │   └── [id]/
│   │   │       └── page.tsx    # Publisher detail
│   │   └── locations/
│   │       └── [id]/
│   │           └── page.tsx    # Location-specific times
│   ├── admin/                   # Publisher admin panel
│   │   ├── layout.tsx
│   │   ├── algorithms/
│   │   ├── coverage/
│   │   └── analytics/
│   ├── layout.tsx
│   └── globals.css
├── components/
│   ├── ui/                      # shadcn/ui components
│   ├── ZmanimCalculator.tsx
│   ├── PublisherCard.tsx
│   ├── LocationSearch.tsx
│   ├── AlgorithmEditor.tsx
│   └── MapComponent.tsx
├── lib/
│   ├── api/
│   │   ├── client.ts            # API client setup
│   │   ├── zmanim.ts            # Zmanim API calls
│   │   ├── publishers.ts        # Publisher API calls
│   │   └── locations.ts         # Location API calls
│   ├── stores/
│   │   ├── authStore.ts         # Auth state
│   │   └── zmanimStore.ts       # Zmanim state
│   ├── supabase.ts              # Supabase client
│   └── utils.ts
├── public/
└── package.json
```

### Key Frontend Updates

**`lib/supabase.ts`**

```typescript
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type Database = {
  publishers: {
    Row: {
      id: string;
      name: string;
      organization: string;
      slug: string;
      email: string;
      description: string | null;
      website: string | null;
      logo_url: string | null;
      status: string;
      verified_at: string | null;
      created_at: string;
      updated_at: string;
    };
  };
  // ... other tables
};
```

**`lib/api/client.ts`**

```typescript
import axios from 'axios';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080/api/v1';

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add auth token to requests
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});
```

**`.env.local.example`**

```bash
NEXT_PUBLIC_API_URL=http://localhost:8080/api/v1
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

---

## Deployment Pipeline

### 1. Backend Deployment (Fly.io)

**`fly.toml`**

```toml
app = "zmanim-lab-api"
primary_region = "iad"

[build]
  dockerfile = "Dockerfile"

[env]
  PORT = "8080"
  ENVIRONMENT = "production"

[[services]]
  http_checks = []
  internal_port = 8080
  processes = ["app"]
  protocol = "tcp"
  script_checks = []

  [services.concurrency]
    hard_limit = 25
    soft_limit = 20
    type = "connections"

  [[services.ports]]
    force_https = true
    handlers = ["http"]
    port = 80

  [[services.ports]]
    handlers = ["tls", "http"]
    port = 443

  [[services.tcp_checks]]
    grace_period = "1s"
    interval = "15s"
    restart_limit = 0
    timeout = "2s"
```

**Deploy commands:**

```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Login
fly auth login

# Create app
fly apps create zmanim-lab-api

# Set secrets
fly secrets set SUPABASE_URL="https://xxx.supabase.co"
fly secrets set SUPABASE_SERVICE_KEY="your-key"
fly secrets set REDIS_URL="your-redis-url"
fly secrets set JWT_SECRET="your-secret"

# Deploy
fly deploy

# Check status
fly status
fly logs
```

### 2. Frontend Deployment (Vercel)

**`vercel.json`**

```json
{
  "buildCommand": "npm run build",
  "devCommand": "npm run dev",
  "framework": "nextjs",
  "regions": ["iad1"],
  "env": {
    "NEXT_PUBLIC_API_URL": "@api-url",
    "NEXT_PUBLIC_SUPABASE_URL": "@supabase-url",
    "NEXT_PUBLIC_SUPABASE_ANON_KEY": "@supabase-anon-key"
  }
}
```

**Deploy commands:**

```bash
# Install Vercel CLI
npm i -g vercel

# Login
vercel login

# Deploy
vercel --prod

# Set environment variables in Vercel dashboard
# or via CLI:
vercel env add NEXT_PUBLIC_API_URL production
```

### 3. GitHub Actions CI/CD

**`.github/workflows/deploy.yml`**

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Fly
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy to Fly.io
        run: flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}

  deploy-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
```

---

## Development Timeline

### Phase 1: Foundation (Week 1-2)
- [ ] Set up Supabase project and database schema
- [ ] Create Go backend project structure
- [ ] Set up basic API with Chi router
- [ ] Implement authentication middleware
- [ ] Set up Upstash Redis

### Phase 2: Core Backend (Week 3-4)
- [ ] Implement Publisher service
- [ ] Implement Location service
- [ ] Implement Calculation service
- [ ] Add caching layer
- [ ] Write unit tests

### Phase 3: Frontend Development (Week 5-6)
- [ ] Set up Next.js with App Router
- [ ] Build location search UI
- [ ] Build publisher discovery UI
- [ ] Build zmanim calculation display
- [ ] Integrate with backend API

### Phase 4: Publisher Features (Week 7-8)
- [ ] Build admin panel
- [ ] Algorithm editor UI
- [ ] Coverage area management
- [ ] Publisher analytics dashboard

### Phase 5: Testing & Deployment (Week 9-10)
- [ ] Integration testing
- [ ] Performance optimization
- [ ] Set up monitoring
- [ ] Deploy to Fly.io and Vercel
- [ ] Load testing

### Phase 6: Launch (Week 11-12)
- [ ] Beta testing
- [ ] Bug fixes
- [ ] Documentation
- [ ] Public launch

---

## Next Steps

1. **Immediate Actions:**
   - Create Supabase account and project
   - Set up Fly.io account
   - Initialize Go backend repository
   - Set up development environment

2. **Week 1 Goals:**
   - Complete database schema in Supabase
   - Create basic Go API structure
   - Set up authentication flow
   - Deploy "Hello World" to Fly.io

3. **Week 2 Goals:**
   - Implement first API endpoints
   - Set up frontend project structure
   - Integrate Supabase auth in frontend
   - Test end-to-end connection

---

## Cost Optimization Tips

1. **Start with free tiers** - Use Fly.io, Vercel, and Supabase free tiers
2. **Optimize caching** - Reduce database queries with Redis caching
3. **Lazy loading** - Load data only when needed
4. **Image optimization** - Use WebP format and CDN
5. **Monitor usage** - Set up alerts for tier limits
6. **Scale gradually** - Upgrade only when necessary

---

## Support & Resources

- **Fly.io Docs:** https://fly.io/docs
- **Vercel Docs:** https://vercel.com/docs
- **Supabase Docs:** https://supabase.com/docs
- **Upstash Docs:** https://upstash.com/docs
- **Go Chi Router:** https://github.com/go-chi/chi
- **Next.js 14:** https://nextjs.org/docs

---

**Ready to start building! 🚀**
