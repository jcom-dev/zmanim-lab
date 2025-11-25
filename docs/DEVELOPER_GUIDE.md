# Zmanim Lab - Developer Onboarding Guide

## Welcome! 🎉

This guide will help you get started with developing Zmanim Lab, a multi-publisher platform for calculating Jewish prayer times (zmanim). Whether you're working on the Go backend, Next.js frontend, or both, this guide has you covered.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Structure](#project-structure)
3. [Local Development Setup](#local-development-setup)
4. [Development Workflow](#development-workflow)
5. [Code Standards](#code-standards)
6. [Testing](#testing)
7. [Common Tasks](#common-tasks)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

**Backend Development:**
- Go 1.21 or higher
- Docker & Docker Compose
- PostgreSQL client tools
- Git

**Frontend Development:**
- Node.js 18.x or higher
- npm or yarn
- Git

**Database:**
- Supabase CLI (optional but recommended)
- PostgreSQL 15+ (or use Docker)

### Recommended Tools

- VS Code with extensions:
  - Go extension
  - TypeScript and JavaScript extension
  - ESLint
  - Prettier
  - Docker extension
- Postman or Insomnia (API testing)
- pgAdmin or DBeaver (database GUI)

### Sign up for Services

1. **Supabase** - Create a free account at https://supabase.com
2. **Upstash Redis** (optional for local dev) - https://upstash.com
3. **Vercel** (for deployment) - https://vercel.com

---

## Project Structure

```
zmanim-lab/
├── backend/                    # Go backend service
│   ├── cmd/
│   │   └── api/               # API entry point
│   ├── internal/
│   │   ├── handlers/          # HTTP request handlers
│   │   ├── services/          # Business logic
│   │   ├── models/            # Data models
│   │   ├── db/                # Database queries (sqlc)
│   │   ├── middleware/        # HTTP middleware
│   │   └── config/            # Configuration
│   ├── migrations/            # Database migrations
│   ├── pkg/                   # Public packages
│   ├── go.mod
│   └── Dockerfile
│
├── frontend/                   # Next.js web application
│   ├── app/                   # Next.js 16 app router
│   ├── components/            # React components
│   ├── lib/                   # Utilities and helpers
│   ├── public/                # Static assets
│   ├── styles/                # Global styles
│   └── package.json
│
├── admin/                      # Admin panel (Next.js)
│   ├── app/
│   ├── components/
│   ├── lib/
│   └── package.json
│
├── docs/                       # Documentation
│   ├── ARCHITECTURE.md        # System architecture
│   ├── DEVELOPER_GUIDE.md     # This file
│   └── API.md                 # API documentation
│
├── scripts/                    # Utility scripts
├── docker-compose.yml         # Local development services
└── README.md
```

---

## Local Development Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/zmanim-lab.git
cd zmanim-lab
```

### Step 2: Set Up Supabase

**Option A: Use Supabase Cloud (Recommended for beginners)**

1. Go to https://supabase.com and create a new project
2. Save your project URL and anon key
3. Apply the database schema:

```bash
# Copy schema from docs/ARCHITECTURE.md database section
# Paste into Supabase SQL Editor and execute
```

**Option B: Use Supabase CLI (Local development)**

```bash
# Install Supabase CLI
npm install -g supabase

# Initialize Supabase
supabase init

# Start local Supabase
supabase start

# Apply migrations
supabase db push
```

### Step 3: Set Up Backend (Go)

```bash
cd backend

# Install dependencies
go mod download

# Copy environment template
cp .env.example .env

# Edit .env with your values
nano .env
```

**.env file example:**
```bash
# Server
PORT=8080
ENVIRONMENT=development

# Database (Supabase)
DATABASE_URL=postgresql://postgres:password@localhost:54322/postgres
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJxxx...
SUPABASE_SERVICE_KEY=eyJxxx...

# Redis Cache
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=

# JWT
JWT_SECRET=your-secret-key-here

# CORS
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001
```

**Run the backend:**

```bash
# Development mode with hot reload
go run cmd/api/main.go

# Or use air for auto-reload
air

# Run tests
go test ./...

# Build
go build -o bin/api cmd/api/main.go
```

### Step 4: Set Up Frontend (Next.js)

**Web Application:**

```bash
cd frontend

# Install dependencies
npm install

# Copy environment template
cp .env.local.example .env.local

# Edit .env.local
nano .env.local
```

**.env.local example:**
```bash
NEXT_PUBLIC_API_URL=http://localhost:8080/api/v1
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJxxx...
```

**Run the web app:**

```bash
npm run dev
# Opens at http://localhost:3000
```

**Admin Panel:**

```bash
cd admin

npm install
cp .env.local.example .env.local
nano .env.local

npm run dev
# Opens at http://localhost:3001
```

### Step 5: Start Services with Docker (Optional)

If you prefer using Docker for all services:

```bash
# From project root
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  postgres:
    image: postgis/postgis:15-3.3
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: zmanim
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  api:
    build: ./backend
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgresql://postgres:postgres@postgres:5432/zmanim
      REDIS_URL: redis://redis:6379
    depends_on:
      - postgres
      - redis

volumes:
  postgres_data:
  redis_data:
```

---

## Development Workflow

### 1. Create a New Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes

Follow the code standards (see below) and write tests.

### 3. Run Tests

**Backend:**
```bash
cd backend
go test ./... -v
go test -race ./...  # Race condition detection
go test -cover ./... # Coverage report
```

**Frontend:**
```bash
cd frontend
npm test
npm run lint
npm run type-check
```

### 4. Commit Your Changes

```bash
git add .
git commit -m "feat: add zmanim calculation endpoint"
```

**Commit Message Format:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting)
- `refactor:` Code refactoring
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

### 5. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub.

---

## Code Standards

### Go Backend

**Code Style:**
- Follow [Effective Go](https://golang.org/doc/effective_go)
- Run `gofmt` and `golint` before committing
- Use meaningful variable names
- Keep functions small and focused

**Project Structure:**
```go
// internal/handlers/zmanim_handler.go
package handlers

import (
    "net/http"
    "encoding/json"
    "github.com/your-org/zmanim-lab/internal/services"
)

type ZmanimHandler struct {
    service *services.CalculationService
}

func NewZmanimHandler(service *services.CalculationService) *ZmanimHandler {
    return &ZmanimHandler{service: service}
}

func (h *ZmanimHandler) Calculate(w http.ResponseWriter, r *http.Request) {
    // Handler logic
}
```

**Error Handling:**
```go
// Always handle errors explicitly
result, err := service.Calculate(ctx, req)
if err != nil {
    http.Error(w, err.Error(), http.StatusInternalServerError)
    return
}
```

**Testing:**
```go
// internal/handlers/zmanim_handler_test.go
func TestZmanimHandler_Calculate(t *testing.T) {
    // Arrange
    handler := NewZmanimHandler(mockService)
    req := httptest.NewRequest("POST", "/calculate", body)
    w := httptest.NewRecorder()

    // Act
    handler.Calculate(w, req)

    // Assert
    assert.Equal(t, http.StatusOK, w.Code)
}
```

### Next.js Frontend

**Component Structure:**
```tsx
// components/ZmanimCard.tsx
import { FC } from 'react';

interface ZmanimCardProps {
  zman: Zman;
  onSelect?: (id: string) => void;
}

export const ZmanimCard: FC<ZmanimCardProps> = ({ zman, onSelect }) => {
  return (
    <div className="rounded-lg border p-4">
      {/* Component content */}
    </div>
  );
};
```

**API Calls:**
```typescript
// lib/api/zmanim.ts
import axios from 'axios';

const API_BASE = process.env.NEXT_PUBLIC_API_URL;

export const zmanimAPI = {
  calculate: async (params: CalculateParams) => {
    const response = await axios.post(`${API_BASE}/zmanim/calculate`, params);
    return response.data;
  },

  getPublishers: async (locationId: string) => {
    const response = await axios.get(`${API_BASE}/locations/${locationId}/publishers`);
    return response.data;
  },
};
```

**State Management:**
```typescript
// lib/store/zmanim-store.ts
import { create } from 'zustand';

interface ZmanimStore {
  selectedLocation: Location | null;
  selectedPublisher: Publisher | null;
  zmanim: Zmanim | null;
  setLocation: (location: Location) => void;
  setPublisher: (publisher: Publisher) => void;
  setZmanim: (zmanim: Zmanim) => void;
}

export const useZmanimStore = create<ZmanimStore>((set) => ({
  selectedLocation: null,
  selectedPublisher: null,
  zmanim: null,
  setLocation: (location) => set({ selectedLocation: location }),
  setPublisher: (publisher) => set({ selectedPublisher: publisher }),
  setZmanim: (zmanim) => set({ zmanim }),
}));
```

---

## Testing

### Backend Testing

**Unit Tests:**
```go
// internal/services/calculation_service_test.go
func TestCalculationService_Calculate(t *testing.T) {
    tests := []struct {
        name    string
        input   CalculationRequest
        want    *Zmanim
        wantErr bool
    }{
        {
            name: "valid calculation for Jerusalem",
            input: CalculationRequest{
                LocationID: "uuid",
                Date:       "2024-11-24",
            },
            want:    &expectedZmanim,
            wantErr: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            service := NewCalculationService(mockDB, mockCache)
            got, err := service.Calculate(context.Background(), tt.input)

            if tt.wantErr {
                assert.Error(t, err)
                return
            }

            assert.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

**Integration Tests:**
```go
// internal/handlers/integration_test.go
func TestZmanimAPI_Integration(t *testing.T) {
    // Set up test database
    db := setupTestDB(t)
    defer db.Close()

    // Create test server
    server := setupTestServer(db)

    // Make request
    resp, err := http.Post(
        server.URL+"/api/v1/zmanim/calculate",
        "application/json",
        bytes.NewBuffer(requestBody),
    )

    assert.NoError(t, err)
    assert.Equal(t, http.StatusOK, resp.StatusCode)
}
```

### Frontend Testing

**Component Tests:**
```typescript
// components/__tests__/ZmanimCard.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { ZmanimCard } from '../ZmanimCard';

describe('ZmanimCard', () => {
  it('renders zman information', () => {
    const zman = {
      name: 'Sunrise',
      time: '2024-11-24T06:03:45Z',
    };

    render(<ZmanimCard zman={zman} />);

    expect(screen.getByText('Sunrise')).toBeInTheDocument();
    expect(screen.getByText(/06:03/)).toBeInTheDocument();
  });

  it('calls onSelect when clicked', () => {
    const onSelect = jest.fn();
    render(<ZmanimCard zman={mockZman} onSelect={onSelect} />);

    fireEvent.click(screen.getByRole('button'));
    expect(onSelect).toHaveBeenCalledWith(mockZman.id);
  });
});
```

---

## Common Tasks

### Adding a New API Endpoint

**1. Define the route:**
```go
// cmd/api/routes.go
func (s *Server) routes() http.Handler {
    r := chi.NewRouter()

    r.Route("/api/v1", func(r chi.Router) {
        r.Post("/zmanim/calculate", s.handlers.Zmanim.Calculate)
        r.Get("/publishers", s.handlers.Publisher.List)
        // Add your new route here
    })

    return r
}
```

**2. Create the handler:**
```go
// internal/handlers/your_handler.go
func (h *YourHandler) YourMethod(w http.ResponseWriter, r *http.Request) {
    // Parse request
    var req YourRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }

    // Call service
    result, err := h.service.YourMethod(r.Context(), req)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    // Send response
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(result)
}
```

**3. Add the service logic:**
```go
// internal/services/your_service.go
func (s *YourService) YourMethod(ctx context.Context, req YourRequest) (*YourResponse, error) {
    // Business logic here
    return &result, nil
}
```

**4. Write tests:**
```go
// internal/handlers/your_handler_test.go
func TestYourHandler_YourMethod(t *testing.T) {
    // Test implementation
}
```

### Adding a Database Migration

**1. Create migration file:**
```bash
cd backend/migrations
touch 003_add_new_table.up.sql
touch 003_add_new_table.down.sql
```

**2. Write migration:**
```sql
-- 003_add_new_table.up.sql
CREATE TABLE your_table (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_your_table_name ON your_table(name);
```

```sql
-- 003_add_new_table.down.sql
DROP TABLE IF EXISTS your_table;
```

**3. Apply migration:**
```bash
# Using golang-migrate
migrate -path migrations -database "${DATABASE_URL}" up

# Or using Supabase CLI
supabase db push
```

### Adding a New Frontend Component

**1. Create component file:**
```tsx
// components/NewComponent.tsx
import { FC } from 'react';

interface NewComponentProps {
  data: YourData;
}

export const NewComponent: FC<NewComponentProps> = ({ data }) => {
  return (
    <div>
      {/* Component JSX */}
    </div>
  );
};
```

**2. Create test file:**
```tsx
// components/__tests__/NewComponent.test.tsx
import { render, screen } from '@testing-library/react';
import { NewComponent } from '../NewComponent';

describe('NewComponent', () => {
  it('renders correctly', () => {
    render(<NewComponent data={mockData} />);
    expect(screen.getByText('Expected Text')).toBeInTheDocument();
  });
});
```

**3. Export from index:**
```typescript
// components/index.ts
export { NewComponent } from './NewComponent';
```

---

## Troubleshooting

### Backend Issues

**Problem: Database connection fails**
```bash
# Check if PostgreSQL is running
pg_isready -h localhost -p 5432

# Check connection string
echo $DATABASE_URL

# Test connection
psql "${DATABASE_URL}"
```

**Problem: Redis connection fails**
```bash
# Check if Redis is running
redis-cli ping
# Should respond with: PONG

# Check Redis URL
echo $REDIS_URL
```

**Problem: Hot reload not working**
```bash
# Install air for hot reload
go install github.com/cosmtrek/air@latest

# Create .air.toml config
air init

# Run with air
air
```

### Frontend Issues

**Problem: Module not found**
```bash
# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

**Problem: Build fails**
```bash
# Check TypeScript errors
npm run type-check

# Clear Next.js cache
rm -rf .next
npm run build
```

**Problem: API calls fail with CORS error**

Check backend CORS configuration:
```go
// internal/middleware/cors.go
func CORS(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }

        next.ServeHTTP(w, r)
    })
}
```

### Database Issues

**Problem: Migration fails**
```bash
# Check current migration version
migrate -path migrations -database "${DATABASE_URL}" version

# Force to specific version (use with caution!)
migrate -path migrations -database "${DATABASE_URL}" force VERSION

# Roll back one migration
migrate -path migrations -database "${DATABASE_URL}" down 1
```

**Problem: Slow queries**
```sql
-- Enable query logging in PostgreSQL
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();

-- Check slow queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- Analyze table
ANALYZE your_table;
```

---

## Useful Commands

### Backend
```bash
# Format code
go fmt ./...

# Lint code
golint ./...

# Run specific test
go test -run TestName ./internal/services

# Generate test coverage HTML
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# Build for production
CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./cmd/api
```

### Frontend
```bash
# Format code
npm run format

# Lint code
npm run lint
npm run lint:fix

# Type check
npm run type-check

# Build for production
npm run build

# Start production server
npm start

# Analyze bundle size
npm run analyze
```

### Database
```bash
# Dump database
pg_dump $DATABASE_URL > backup.sql

# Restore database
psql $DATABASE_URL < backup.sql

# Connect to database
psql $DATABASE_URL

# Run SQL file
psql $DATABASE_URL -f script.sql
```

---

## Resources

### Documentation
- [Go Documentation](https://golang.org/doc/)
- [Next.js Documentation](https://nextjs.org/docs)
- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PostGIS Documentation](https://postgis.net/documentation/)

### Tools
- [Go Playground](https://play.golang.org/)
- [TypeScript Playground](https://www.typescriptlang.org/play)
- [Regex101](https://regex101.com/)
- [JSON Formatter](https://jsonformatter.org/)

### Learning
- [Effective Go](https://golang.org/doc/effective_go)
- [Go by Example](https://gobyexample.com/)
- [React Documentation](https://react.dev/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)

---

## Getting Help

### Internal Resources
- Architecture Documentation: `docs/ARCHITECTURE.md`
- API Documentation: `docs/API.md`
- Contributing Guidelines: `CONTRIBUTING.md`

### Communication
- GitHub Issues: Report bugs and request features
- GitHub Discussions: Ask questions and share ideas
- Slack Channel: `#zmanim-lab-dev` (if available)

### Code Review Checklist
- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] New tests added for new features
- [ ] Documentation updated
- [ ] No console.log or debugging code
- [ ] Error handling implemented
- [ ] Performance considerations addressed
- [ ] Security best practices followed

---

## Welcome to the Team! 🚀

You're now ready to start developing Zmanim Lab. If you have any questions or run into issues, don't hesitate to reach out to the team. Happy coding!
