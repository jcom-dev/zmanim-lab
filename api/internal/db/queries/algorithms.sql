-- Algorithms SQL Queries
-- SQLc will generate type-safe Go code from these queries

-- Get algorithm for publisher --

-- name: GetPublisherDraftAlgorithm :one
SELECT id, name, COALESCE(description, '') as description,
       COALESCE(configuration::text, '{}')::jsonb as configuration,
       status, is_public,
       created_at, updated_at
FROM algorithms
WHERE publisher_id = $1 AND status = 'draft'
ORDER BY created_at DESC
LIMIT 1;

-- name: GetPublisherActiveAlgorithm :one
SELECT id, name, COALESCE(description, '') as description,
       COALESCE(configuration::text, '{}')::jsonb as configuration,
       status, is_public,
       created_at, updated_at
FROM algorithms
WHERE publisher_id = $1 AND status = 'published'
ORDER BY created_at DESC
LIMIT 1;

-- name: GetAlgorithmByID :one
SELECT id, name, COALESCE(description, '') as description,
       COALESCE(configuration::text, '{}')::jsonb as configuration,
       status, is_public,
       created_at, updated_at
FROM algorithms
WHERE id = $1 AND publisher_id = $2;

-- Create or update algorithm --

-- name: CreateAlgorithm :one
INSERT INTO algorithms (
    publisher_id, name, description, configuration, status, is_public
)
VALUES ($1, $2, $3, $4, 'draft', false)
RETURNING id, created_at, updated_at;

-- name: UpdateAlgorithmDraft :one
UPDATE algorithms
SET configuration = $1,
    name = COALESCE(NULLIF($2, ''), name),
    description = COALESCE(NULLIF($3, ''), description),
    updated_at = NOW()
WHERE id = $4
RETURNING id, created_at, updated_at;

-- Publish algorithm --

-- name: ArchiveActiveAlgorithms :exec
UPDATE algorithms
SET status = 'deprecated', updated_at = NOW()
WHERE publisher_id = $1 AND status = 'published';

-- name: PublishAlgorithm :one
UPDATE algorithms
SET status = 'published',
    updated_at = NOW()
WHERE id = $1
RETURNING updated_at;

-- Algorithm versions --

-- name: GetAlgorithmVersions :many
SELECT id, name,
       status,
       is_public,
       created_at
FROM algorithms
WHERE publisher_id = $1
ORDER BY created_at DESC;

-- name: DeprecateAlgorithmVersion :execrows
UPDATE algorithms
SET status = 'deprecated',
    updated_at = NOW()
WHERE id = $1 AND publisher_id = $2;

-- Onboarding related --

-- name: GetOnboardingState :one
SELECT
    id, publisher_id, current_step, completed_steps, wizard_data,
    started_at, last_updated_at, completed_at, skipped
FROM publisher_onboarding
WHERE publisher_id = $1;

-- name: CreateOnboardingState :one
INSERT INTO publisher_onboarding (publisher_id)
VALUES ($1)
RETURNING id, publisher_id, current_step, completed_steps, wizard_data,
    started_at, last_updated_at, completed_at, skipped;

-- name: UpdateOnboardingState :one
UPDATE publisher_onboarding
SET current_step = COALESCE(sqlc.narg('current_step'), current_step),
    completed_steps = COALESCE(sqlc.narg('completed_steps'), completed_steps),
    wizard_data = COALESCE(sqlc.narg('wizard_data'), wizard_data),
    last_updated_at = NOW()
WHERE publisher_id = $1
RETURNING id, publisher_id, current_step, completed_steps, wizard_data,
    started_at, last_updated_at, completed_at, skipped;

-- name: CompleteOnboarding :one
UPDATE publisher_onboarding
SET completed_at = NOW(),
    last_updated_at = NOW()
WHERE publisher_id = $1
RETURNING id;

-- name: SkipOnboarding :one
UPDATE publisher_onboarding
SET skipped = true,
    last_updated_at = NOW()
WHERE publisher_id = $1
RETURNING id;

-- Algorithm Templates --

-- name: GetAlgorithmTemplates :many
SELECT
    id, template_key, name, description,
    configuration, sort_order, is_active,
    created_at, updated_at
FROM algorithm_templates
WHERE is_active = true
ORDER BY sort_order ASC;

-- name: GetAlgorithmTemplateByKey :one
SELECT
    id, template_key, name, description,
    configuration, sort_order, is_active,
    created_at, updated_at
FROM algorithm_templates
WHERE template_key = $1 AND is_active = true;
