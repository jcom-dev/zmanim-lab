# Story 1.4: Publisher Profile

Status: ready-for-dev

## Story

As a **publisher**,
I want **to manage my profile information**,
so that **end users can identify and trust my organization**.

## Acceptance Criteria

1. Publisher can view their current profile information
2. Publisher can update name, organization, website, contact email, bio
3. Publisher can upload logo image
4. Logo appears on publisher cards when users view zmanim
5. Required fields show inline validation errors

## Tasks / Subtasks

- [ ] Task 1: Extend publishers table for profile fields (AC: 2, 3)
  - [ ] 1.1 Add migration for website, logo_url, bio columns
  - [ ] 1.2 Run migration in Supabase

- [ ] Task 2: Implement publisher profile API (AC: 1, 2)
  - [ ] 2.1 Create api/internal/handlers/publishers.go
  - [ ] 2.2 GET /api/publisher/profile - get own profile
  - [ ] 2.3 PUT /api/publisher/profile - update profile
  - [ ] 2.4 Validate required fields server-side

- [ ] Task 3: Implement logo upload (AC: 3)
  - [ ] 3.1 Configure Supabase Storage bucket for logos
  - [ ] 3.2 POST /api/publisher/logo - upload logo
  - [ ] 3.3 Return logo_url after upload
  - [ ] 3.4 Validate file type and size

- [ ] Task 4: Create publisher profile page (AC: 1, 2, 5)
  - [ ] 4.1 Create web/app/publisher/profile/page.tsx
  - [ ] 4.2 Use react-hook-form with shadcn/ui Form
  - [ ] 4.3 Display current profile data
  - [ ] 4.4 Inline validation errors for required fields
  - [ ] 4.5 Success/error toast on save

- [ ] Task 5: Create logo upload component (AC: 3)
  - [ ] 5.1 Create web/components/publisher/LogoUpload.tsx
  - [ ] 5.2 Preview current logo
  - [ ] 5.3 File picker with drag-drop support
  - [ ] 5.4 Upload progress indicator

- [ ] Task 6: Create PublisherCard component (AC: 4)
  - [ ] 6.1 Create web/components/shared/PublisherCard.tsx
  - [ ] 6.2 Display name, organization, logo
  - [ ] 6.3 Handle missing logo gracefully (placeholder)

## Dev Notes

### Architecture Patterns

- **Form Handling:** react-hook-form + zod validation
- **File Storage:** Supabase Storage with public bucket
- **Image Optimization:** Consider next/image for logo display

### Source Tree Components

```
web/app/publisher/
  └── profile/
      └── page.tsx
web/components/
  ├── publisher/
  │   └── LogoUpload.tsx
  └── shared/
      └── PublisherCard.tsx
api/internal/handlers/
  └── publishers.go
```

### Profile Fields

| Field | Required | Type | Notes |
|-------|----------|------|-------|
| name | Yes | string | Display name |
| organization | No | string | Organization/synagogue |
| email | Yes | string | Contact email |
| website | No | string | URL |
| bio | No | string | Description |
| logo_url | No | string | Supabase Storage URL |

### References

- [Source: docs/architecture.md#Data-Model]
- [Source: docs/epics.md#Story-1.4-Publisher-Profile]
- [Source: docs/sprint-artifacts/tech-spec-epic-1.md#Story-1.4]
- [Source: docs/ux-design-specification.md#Publisher-Components]

## Dev Agent Record

### Context Reference
### Agent Model Used
### Debug Log References
### Completion Notes List
### File List
