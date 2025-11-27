/**
 * Database Test Fixtures
 *
 * Provides utilities to create test data in the database
 * for E2E testing scenarios.
 *
 * Uses native PostgreSQL client (pg) instead of Supabase.
 */

import { Pool, PoolClient } from 'pg';

// Lazy initialization of pool - only created when needed
let pool: Pool | null = null;

function getPool(): Pool {
  if (!pool) {
    const databaseUrl = process.env.DATABASE_URL;
    if (!databaseUrl) {
      throw new Error('DATABASE_URL is required for test fixtures');
    }
    pool = new Pool({ connectionString: databaseUrl });
  }
  return pool;
}

/**
 * Check if database is configured
 */
export function isDatabaseConfigured(): boolean {
  return !!process.env.DATABASE_URL;
}

// Test data prefix - used to identify and cleanup test data
const TEST_PREFIX = 'TEST_';
const TEST_EMAIL_DOMAIN = 'test-zmanim.example.com';

// Cache for created test entities
const testEntityCache = new Map<string, any>();

/**
 * Create a test publisher entity in the database
 */
export async function createTestPublisherEntity(
  overrides: Partial<{
    name: string;
    organization: string;
    email: string;
    status: string;
    website: string;
    bio: string;
  }> = {}
): Promise<{
  id: string;
  name: string;
  organization: string;
  email: string;
  status: string;
}> {
  if (!isDatabaseConfigured()) {
    throw new Error('Database not configured - cannot create test publisher');
  }

  const cacheKey = 'publisher-entity';
  if (testEntityCache.has(cacheKey) && !Object.keys(overrides).length) {
    return testEntityCache.get(cacheKey);
  }

  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8);
  const testPublisher = {
    name: overrides.name || `${TEST_PREFIX}Publisher ${timestamp}`,
    organization: overrides.organization || `${TEST_PREFIX}Organization`,
    email: overrides.email || `test-publisher-${timestamp}@${TEST_EMAIL_DOMAIN}`,
    slug: `test-publisher-${timestamp}-${random}`,
    status: overrides.status || 'verified',
    website: overrides.website || 'https://test.example.com',
    bio: overrides.bio || 'Test publisher for E2E testing',
  };

  const client = await getPool().connect();
  try {
    const result = await client.query(
      `INSERT INTO publishers (name, organization, email, slug, status, website, bio)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, name, organization, email, status`,
      [
        testPublisher.name,
        testPublisher.organization,
        testPublisher.email,
        testPublisher.slug,
        testPublisher.status,
        testPublisher.website,
        testPublisher.bio,
      ]
    );

    const data = result.rows[0];

    if (!Object.keys(overrides).length) {
      testEntityCache.set(cacheKey, data);
    }

    return data;
  } finally {
    client.release();
  }
}

/**
 * Create a test algorithm for a publisher
 */
export async function createTestAlgorithm(
  publisherId: string,
  overrides: Partial<{
    name: string;
    status: string;
    config: object;
  }> = {}
): Promise<{
  id: string;
  publisher_id: string;
  name: string;
  status: string;
  config: object;
}> {
  if (!isDatabaseConfigured()) {
    throw new Error('Database not configured - cannot create test algorithm');
  }

  const cacheKey = `algorithm-${publisherId}`;
  if (testEntityCache.has(cacheKey) && !Object.keys(overrides).length) {
    return testEntityCache.get(cacheKey);
  }

  const defaultConfig = {
    name: 'Test GRA Algorithm',
    description: 'Test algorithm for E2E testing',
    zmanim: {
      alos: { method: 'solar_angle', params: { degrees: 16.1 } },
      misheyakir: { method: 'solar_angle', params: { degrees: 11.5 } },
      sunrise: { method: 'sunrise', params: {} },
      sof_zman_shma_gra: {
        method: 'proportional',
        params: { hours: 3, base: 'gra' },
      },
      sof_zman_tefillah_gra: {
        method: 'proportional',
        params: { hours: 4, base: 'gra' },
      },
      chatzos: { method: 'midday', params: {} },
      mincha_gedola: {
        method: 'proportional',
        params: { hours: 6.5, base: 'gra' },
      },
      mincha_ketana: {
        method: 'proportional',
        params: { hours: 9.5, base: 'gra' },
      },
      plag_hamincha: {
        method: 'proportional',
        params: { hours: 10.75, base: 'gra' },
      },
      sunset: { method: 'sunset', params: {} },
      tzeis: { method: 'solar_angle', params: { degrees: 8.5 } },
      tzeis_rt: { method: 'fixed_minutes', params: { minutes: 72 } },
    },
  };

  const testAlgorithm = {
    publisher_id: publisherId,
    name: overrides.name || `${TEST_PREFIX}Algorithm`,
    status: overrides.status || 'published',
    config: overrides.config || defaultConfig,
  };

  const client = await getPool().connect();
  try {
    const result = await client.query(
      `INSERT INTO algorithms (publisher_id, name, status, config, version, formula_definition, calculation_type)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, publisher_id, name, status, config`,
      [
        testAlgorithm.publisher_id,
        testAlgorithm.name,
        testAlgorithm.status,
        JSON.stringify(testAlgorithm.config),
        1, // version
        JSON.stringify(testAlgorithm.config), // formula_definition
        'proportional', // calculation_type (valid: solar_depression, fixed_minutes, proportional, custom)
      ]
    );

    const data = result.rows[0];

    if (!Object.keys(overrides).length) {
      testEntityCache.set(cacheKey, data);
    }

    return data;
  } finally {
    client.release();
  }
}

/**
 * Create test coverage for a publisher
 */
export async function createTestCoverage(
  publisherId: string,
  cityId: string,
  overrides: Partial<{
    level: string;
    priority: number;
    is_active: boolean;
  }> = {}
): Promise<{
  id: string;
  publisher_id: string;
  city_id: string;
  level: string;
  priority: number;
  is_active: boolean;
}> {
  if (!isDatabaseConfigured()) {
    throw new Error('Database not configured - cannot create test coverage');
  }

  const cacheKey = `coverage-${publisherId}-${cityId}`;
  if (testEntityCache.has(cacheKey) && !Object.keys(overrides).length) {
    return testEntityCache.get(cacheKey);
  }

  const testCoverage = {
    publisher_id: publisherId,
    city_id: cityId,
    level: overrides.level || 'city',
    priority: overrides.priority ?? 5,
    is_active: overrides.is_active ?? true,
  };

  const client = await getPool().connect();
  try {
    const result = await client.query(
      `INSERT INTO publisher_coverage (publisher_id, city_id, level, priority, is_active)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, publisher_id, city_id, level, priority, is_active`,
      [
        testCoverage.publisher_id,
        testCoverage.city_id,
        testCoverage.level,
        testCoverage.priority,
        testCoverage.is_active,
      ]
    );

    const data = result.rows[0];

    if (!Object.keys(overrides).length) {
      testEntityCache.set(cacheKey, data);
    }

    return data;
  } finally {
    client.release();
  }
}

/**
 * Get a test city from the database
 * Returns first city matching name, or any city if name not provided
 */
export async function getTestCity(
  name?: string
): Promise<{ id: string; name: string; country: string } | null> {
  if (!isDatabaseConfigured()) {
    console.warn('Database not configured - cannot get test city');
    return null;
  }

  const client = await getPool().connect();
  try {
    let result;
    if (name) {
      result = await client.query(
        `SELECT id, name, country FROM cities WHERE name ILIKE $1 LIMIT 1`,
        [`%${name}%`]
      );
    } else {
      result = await client.query(
        `SELECT id, name, country FROM cities LIMIT 1`
      );
    }

    if (result.rows.length === 0) {
      console.warn(`Could not find test city${name ? ` matching "${name}"` : ''}`);
      return null;
    }

    return result.rows[0];
  } finally {
    client.release();
  }
}

/**
 * Link a Clerk user ID to a publisher in the database
 */
export async function linkClerkUserToPublisher(
  clerkUserId: string,
  publisherId: string
): Promise<void> {
  if (!isDatabaseConfigured()) {
    console.warn('Database not configured - cannot link user to publisher');
    return;
  }

  const client = await getPool().connect();
  try {
    await client.query(
      `UPDATE publishers SET clerk_user_id = $1 WHERE id = $2`,
      [clerkUserId, publisherId]
    );
    console.log(`Linked Clerk user ${clerkUserId} to publisher ${publisherId}`);
  } finally {
    client.release();
  }
}

/**
 * Create a complete test publisher setup (publisher + algorithm + coverage)
 */
export async function createFullTestPublisher(): Promise<{
  publisher: Awaited<ReturnType<typeof createTestPublisherEntity>>;
  algorithm: Awaited<ReturnType<typeof createTestAlgorithm>>;
  coverage: Awaited<ReturnType<typeof createTestCoverage>> | null;
}> {
  // Create publisher
  const publisher = await createTestPublisherEntity();

  // Create algorithm
  const algorithm = await createTestAlgorithm(publisher.id);

  // Try to create coverage if we have cities
  let coverage = null;
  const city = await getTestCity('New York');
  if (city) {
    coverage = await createTestCoverage(publisher.id, city.id);
  }

  return { publisher, algorithm, coverage };
}

/**
 * Clean up all test data from the database
 * Call this in global teardown
 */
export async function cleanupTestData(): Promise<void> {
  if (!isDatabaseConfigured()) {
    console.log('Database not configured - skipping test data cleanup');
    return;
  }

  console.log('Cleaning up test data from database...');

  const client = await getPool().connect();
  try {
    // First, get all test publisher IDs
    const publisherResult = await client.query(
      `SELECT id FROM publishers WHERE name LIKE $1 OR email LIKE $2`,
      [`${TEST_PREFIX}%`, `%@${TEST_EMAIL_DOMAIN}`]
    );

    const publisherIds = publisherResult.rows.map((p) => p.id);

    if (publisherIds.length > 0) {
      // Delete test algorithms for these publishers
      await client.query(
        `DELETE FROM algorithms WHERE publisher_id = ANY($1)`,
        [publisherIds]
      );

      // Delete test coverage for these publishers
      await client.query(
        `DELETE FROM publisher_coverage WHERE publisher_id = ANY($1)`,
        [publisherIds]
      );

      // Delete test publishers
      await client.query(
        `DELETE FROM publishers WHERE id = ANY($1)`,
        [publisherIds]
      );
    }

    // Also try to delete by name pattern directly (in case some were missed)
    await client.query(
      `DELETE FROM publishers WHERE name LIKE $1`,
      [`${TEST_PREFIX}%`]
    );

    // Clear the cache
    testEntityCache.clear();

    console.log('Test data cleanup complete');
  } catch (error) {
    console.error('Error during test data cleanup:', error);
  } finally {
    client.release();
  }
}

/**
 * Clear the test entity cache
 */
export function clearEntityCache(): void {
  testEntityCache.clear();
}

/**
 * Get the test prefix
 */
export function getTestPrefix(): string {
  return TEST_PREFIX;
}

/**
 * Close the database pool (call in global teardown)
 */
export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
