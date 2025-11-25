# Zmanim Lab - Documentation Hub

Welcome to the comprehensive documentation for Zmanim Lab, a multi-publisher platform for calculating Jewish prayer times (zmanim).

## 📚 Documentation Overview

This documentation suite provides everything you need to understand, develop, and deploy the Zmanim Lab platform.

### Core Documents

1. **[Architecture Documentation](./ARCHITECTURE.md)** - Complete system architecture
   - System overview and high-level design
   - Technology stack details
   - Database schema with PostGIS integration
   - REST API specifications
   - Publisher system design
   - Authentication & authorization
   - Deployment architecture
   - Security & scalability considerations

2. **[Developer Guide](./DEVELOPER_GUIDE.md)** - Complete onboarding guide for developers
   - Local development setup
   - Project structure
   - Development workflow
   - Code standards and testing
   - Common tasks and troubleshooting

## 🎯 Quick Start Guide

### For Users
The platform allows you to:
- Search for locations worldwide
- Select religious authorities (publishers) serving your area
- View accurate zmanim calculations based on authoritative algorithms
- Compare different calculation methods

### For Publishers
Religious authorities can:
- Register and get verified by admins
- Define custom calculation algorithms
- Set geographic coverage areas
- Manage and update their formulas
- View usage analytics

### For Developers
Get started in 3 steps:
1. Read the [Developer Guide](./DEVELOPER_GUIDE.md#local-development-setup)
2. Set up your local environment
3. Start coding!

## 🏗️ System Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│              FRONTEND LAYER                         │
│  ┌──────────────────┐  ┌──────────────────┐       │
│  │  Web App         │  │  Admin Panel     │       │
│  │  (Next.js)       │  │  (Next.js)       │       │
│  └─────────┬────────┘  └─────────┬────────┘       │
└────────────┼───────────────────────┼────────────────┘
             │                       │
             └───────────┬───────────┘
                         │ REST API
┌────────────────────────┼────────────────────────────┐
│              BACKEND LAYER (Go)                      │
│  ┌──────────────────────┴──────────────────┐       │
│  │  Publisher  │  Calculation  │  Location │       │
│  │  Service    │  Service      │  Service  │       │
│  └──────────────────────────────────────────┘       │
└────────────────────────┬────────────────────────────┘
                         │
┌────────────────────────┼────────────────────────────┐
│              DATA LAYER                              │
│  ┌─────────────────┐  ┌─────────────────┐          │
│  │  Supabase       │  │  Redis Cache    │          │
│  │  PostgreSQL     │  │                 │          │
│  │  + PostGIS      │  │                 │          │
│  └─────────────────┘  └─────────────────┘          │
└──────────────────────────────────────────────────────┘
```

## 🔑 Key Features

### Multi-Publisher Architecture
- Religious authorities maintain independent calculation methods
- Each publisher controls their own algorithms and coverage areas
- Users can choose which authority to follow

### Flexible Algorithm System
Publishers can define algorithms using:
- **Solar Depression Angles** (e.g., 16.1° for Alos)
- **Fixed Time Offsets** (e.g., 72 minutes before sunrise)
- **Proportional Hours** (Shaos Zmaniyos calculations)
- **Custom Formulas** (complete algorithmic control)

### Geographic Coverage
- PostGIS-powered geographic searching
- Publishers define service areas with polygon boundaries
- Automatic publisher matching based on location
- Priority system for overlapping coverage

### Real-Time Calculations
- On-demand REST API calculations
- Multi-tier caching (Redis + in-memory + database)
- Sub-second response times
- Historical data caching

## 🛠️ Technology Stack

### Backend
- **Language**: Go 1.21+
- **Framework**: Chi Router
- **Database**: Supabase (PostgreSQL 15+ with PostGIS)
- **Cache**: Redis
- **Auth**: Supabase Auth with JWT

### Frontend
- **Framework**: Next.js 16 (App Router)
- **Language**: TypeScript
- **UI**: Tailwind CSS + Radix UI
- **State**: Zustand + React Query

### Infrastructure
- **Backend Hosting**: Google Cloud Run / AWS ECS
- **Frontend Hosting**: Vercel
- **Database**: Supabase (managed)
- **Cache**: Upstash Redis / AWS ElastiCache
- **CDN**: Cloudflare

## 📊 Database Schema Overview

The system uses PostgreSQL with PostGIS extension for geographic calculations:

### Core Tables
- **publishers** - Religious authorities and organizations
- **algorithms** - Calculation method definitions
- **calculation_methods** - Individual zmanim formulas
- **coverage_areas** - Geographic service areas (PostGIS polygons)
- **geographic_regions** - Location database
- **user_profiles** - User accounts and preferences
- **calculation_cache** - Performance optimization

### Key Features
- PostGIS for geographic queries
- JSONB for flexible algorithm definitions
- Full audit logging
- Automatic timestamp triggers

## 🔐 Security

- **Authentication**: JWT tokens via Supabase Auth
- **Authorization**: Role-based access control (Public/User/Publisher/Admin)
- **Data Protection**: Encryption at rest and in transit
- **API Security**: Rate limiting, CORS, security headers
- **Input Validation**: Strict validation on all endpoints

## 📈 Performance

### Targets
- API Response: p95 < 100ms
- Calculation: p99 < 500ms
- Throughput: 10,000 req/sec
- Availability: 99.9% uptime

### Optimization
- Multi-tier caching strategy
- Database query optimization with indexes
- Horizontal auto-scaling
- CDN for static assets

## 🚀 Getting Started

### Prerequisites
- Go 1.21+ (backend development)
- Node.js 18+ (frontend development)
- Docker (optional, for services)
- Supabase account

### Quick Setup

**1. Clone the repository:**
```bash
git clone https://github.com/your-org/zmanim-lab.git
cd zmanim-lab
```

**2. Set up Supabase:**
- Create project at https://supabase.com
- Apply database schema from [ARCHITECTURE.md](./ARCHITECTURE.md#database-schema)

**3. Start backend:**
```bash
cd backend
cp .env.example .env
# Edit .env with your Supabase credentials
go run cmd/api/main.go
```

**4. Start frontend:**
```bash
cd frontend
npm install
cp .env.local.example .env.local
# Edit .env.local with API URL
npm run dev
```

See the [Developer Guide](./DEVELOPER_GUIDE.md) for detailed setup instructions.

## 📖 API Documentation

### Base URL
```
https://api.zmanim.lab/v1
```

### Key Endpoints

**Calculate Zmanim:**
```bash
POST /api/v1/zmanim/calculate
{
  "location_id": "uuid",
  "date": "2024-11-24",
  "publisher_id": "uuid"
}
```

**Search Locations:**
```bash
GET /api/v1/locations/search?q=Jerusalem
```

**List Publishers:**
```bash
GET /api/v1/publishers?status=active
```

See [ARCHITECTURE.md - API Design](./ARCHITECTURE.md#api-design) for complete API documentation.

## 🧪 Testing

### Backend Tests
```bash
cd backend
go test ./...                    # Run all tests
go test -race ./...              # Race detection
go test -cover ./...             # Coverage report
```

### Frontend Tests
```bash
cd frontend
npm test                         # Run all tests
npm run lint                     # Linting
npm run type-check               # TypeScript validation
```

## 📦 Deployment

### Backend Deployment
```bash
# Build Docker image
docker build -t zmanim-api:latest .

# Deploy to Cloud Run
gcloud run deploy zmanim-api \
  --image gcr.io/project/zmanim-api:latest \
  --platform managed
```

### Frontend Deployment
```bash
# Deploy to Vercel
vercel deploy --prod
```

See [ARCHITECTURE.md - Deployment](./ARCHITECTURE.md#deployment-architecture) for detailed deployment instructions.

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Read the [Developer Guide](./DEVELOPER_GUIDE.md)
2. Fork the repository
3. Create a feature branch
4. Make your changes with tests
5. Submit a pull request

### Code Standards
- Follow language-specific style guides
- Write comprehensive tests
- Document public APIs
- Use meaningful commit messages

## 📋 Project Roadmap

### Phase 1: Core Platform (Current)
- ✅ System architecture design
- ✅ Database schema with PostGIS
- ✅ REST API specification
- ✅ Authentication & authorization
- 🔄 Go backend implementation
- 🔄 Next.js frontend development
- 🔄 Admin panel

### Phase 2: Publisher Features
- Algorithm validation engine
- Coverage area management UI
- Publisher analytics dashboard
- Algorithm testing suite

### Phase 3: Enhanced Features
- Mobile application
- Offline calculation support
- Multi-language support
- Advanced analytics

### Phase 4: Scale & Optimize
- Global CDN distribution
- Advanced caching strategies
- Performance monitoring
- Auto-scaling optimization

## 🆘 Support & Resources

### Documentation
- [Architecture Documentation](./ARCHITECTURE.md)
- [Developer Guide](./DEVELOPER_GUIDE.md)
- [API Reference](./ARCHITECTURE.md#api-design)

### External Resources
- [Supabase Docs](https://supabase.com/docs)
- [Go Documentation](https://golang.org/doc/)
- [Next.js Documentation](https://nextjs.org/docs)
- [PostGIS Documentation](https://postgis.net/documentation/)

### Community
- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: Questions and ideas
- Contributing Guidelines: `CONTRIBUTING.md`

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **kosher-zmanim** library for reference implementations
- Supabase for managed PostgreSQL and authentication
- PostGIS for geographic calculations
- The Jewish community for domain expertise

---

**Built with ❤️ for accurate zmanim calculations worldwide**

*Last Updated: November 2024*
