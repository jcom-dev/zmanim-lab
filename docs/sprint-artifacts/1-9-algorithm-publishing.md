# Story 1.9: Algorithm Publishing

Status: ready-for-dev

## Story

As a **publisher**,
I want **to publish my algorithm to make it active**,
so that **end users can see zmanim calculated with my method**.

## Acceptance Criteria

1. Draft algorithm can be published (becomes active)
2. Changes to published algorithm save as new draft
3. "Publish Changes" creates new version, archives old
4. Version history shows all versions with dates
5. Deprecated versions show notice to users

## Tasks / Subtasks

- [ ] Task 1: Implement publish endpoint (AC: 1, 3)
  - [ ] 1.1 POST /api/publisher/algorithm/publish
  - [ ] 1.2 Validate algorithm before publish
  - [ ] 1.3 Create new version record
  - [ ] 1.4 Mark previous version as archived
  - [ ] 1.5 Set new version as active
  - [ ] 1.6 Invalidate cache for publisher

- [ ] Task 2: Implement version history endpoint (AC: 4)
  - [ ] 2.1 GET /api/publisher/algorithm/versions
  - [ ] 2.2 Return all versions with dates
  - [ ] 2.3 Include status (published/archived/deprecated)
  - [ ] 2.4 Paginate if needed

- [ ] Task 3: Implement deprecation endpoint (AC: 5)
  - [ ] 3.1 PUT /api/publisher/algorithm/versions/{id}/deprecate
  - [ ] 3.2 Mark version as deprecated
  - [ ] 3.3 Keep deprecated version accessible

- [ ] Task 4: Update algorithm save logic (AC: 2)
  - [ ] 4.1 If published version exists, create draft
  - [ ] 4.2 If draft exists, update draft
  - [ ] 4.3 Show "draft" indicator in UI

- [ ] Task 5: Create publish button component (AC: 1, 3)
  - [ ] 5.1 Add publish button to algorithm editor
  - [ ] 5.2 Confirmation dialog before publish
  - [ ] 5.3 Show success message after publish
  - [ ] 5.4 Handle validation errors

- [ ] Task 6: Create version history panel (AC: 4)
  - [ ] 6.1 Create web/components/publisher/VersionHistory.tsx
  - [ ] 6.2 List all versions with timestamps
  - [ ] 6.3 Show status badges (current/archived/deprecated)
  - [ ] 6.4 Link to view each version

- [ ] Task 7: Create version comparison view (AC: 4)
  - [ ] 7.1 Create web/components/publisher/VersionDiff.tsx
  - [ ] 7.2 Side-by-side configuration comparison
  - [ ] 7.3 Highlight differences

- [ ] Task 8: Implement deprecation notice (AC: 5)
  - [ ] 8.1 Check if user's cached version is deprecated
  - [ ] 8.2 Show notice banner in zmanim view
  - [ ] 8.3 "Refresh" button to get latest version

## Dev Notes

### Architecture Patterns

- **Version Control:** Each save creates new version record
- **Active Version:** Only one active version per publisher
- **Cache Invalidation:** On publish, invalidate all cached calculations

### Version Status Flow

```
draft → published → archived
                 → deprecated (optional)
```

### API Behavior

| Action | Current State | Result |
|--------|---------------|--------|
| Save | No algorithm | Create draft |
| Save | Has draft | Update draft |
| Save | Has published | Create new draft |
| Publish | Has draft | Draft → published, old → archived |
| Deprecate | Published | Published → deprecated |

### Database Operations

```sql
-- Publish new version
BEGIN;
UPDATE algorithms SET status = 'archived', is_active = false
WHERE publisher_id = $1 AND is_active = true;

UPDATE algorithms SET status = 'published', is_active = true, version = version + 1
WHERE id = $2;
COMMIT;
```

### Cache Invalidation on Publish

```go
// After successful publish
cacheService.InvalidatePublisher(ctx, publisherID)
```

### References

- [Source: docs/architecture.md#ADR-003-Upstash-Redis-Caching]
- [Source: docs/epics.md#Story-1.9-Algorithm-Publishing]
- [Source: docs/sprint-artifacts/tech-spec-epic-1.md#Story-1.9]
- [Source: docs/prd.md#FR12-FR14]

## Dev Agent Record

### Context Reference
### Agent Model Used
### Debug Log References
### Completion Notes List
### File List
