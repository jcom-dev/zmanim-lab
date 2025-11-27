/**
 * Database Test Fixtures
 *
 * Provides utilities to create test data in the database
 * for E2E testing scenarios.
 */

import { createClient } from '@supabase/supabase-js';

// Initialize Supabase client with service role key for admin access
const supabase = createClient(
  process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

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
  const cacheKey = 'publisher-entity';
  if (testEntityCache.has(cacheKey) && !Object.keys(overrides).length) {
    return testEntityCache.get(cacheKey);
  }

  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8);
  const testPublisher = {
    name: `${TEST_PREFIX}Publisher ${timestamp}`,
    organization: `${TEST_PREFIX}Organization`,
    email: `test-publisher-${timestamp}@${TEST_EMAIL_DOMAIN}`,
    slug: `test-publisher-${timestamp}-${random}`,
    status: 'verified',
    website: 'https://test.example.com',
    bio: 'Test publisher for E2E testing',
    ...overrides,
  };

  const { data, error } = await supabase
    .from('publishers')
    .insert(testPublisher)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to create test publisher: ${error.message}`);
  }

  if (!Object.keys(overrides).length) {
    testEntityCache.set(cacheKey, data);
  }

  return data;
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
  const cacheKey = `algorithm-${publisherId}`;
  if (testEntityCache.has(cacheKey) && !Object.keys(overrides).length) {
    return testEntityCache.get(cacheKey);
  }

  const testAlgorithm = {
    publisher_id: publisherId,
    name: `${TEST_PREFIX}Algorithm`,
    status: 'published',
    config: {
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
    },
    ...overrides,
  };

  const { data, error } = await supabase
    .from('algorithms')
    .insert(testAlgorithm)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to create test algorithm: ${error.message}`);
  }

  if (!Object.keys(overrides).length) {
    testEntityCache.set(cacheKey, data);
  }

  return data;
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
  const cacheKey = `coverage-${publisherId}-${cityId}`;
  if (testEntityCache.has(cacheKey) && !Object.keys(overrides).length) {
    return testEntityCache.get(cacheKey);
  }

  const testCoverage = {
    publisher_id: publisherId,
    city_id: cityId,
    level: 'city',
    priority: 5,
    is_active: true,
    ...overrides,
  };

  const { data, error } = await supabase
    .from('publisher_coverage')
    .insert(testCoverage)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to create test coverage: ${error.message}`);
  }

  if (!Object.keys(overrides).length) {
    testEntityCache.set(cacheKey, data);
  }

  return data;
}

/**
 * Get a test city from the database
 * Returns first city matching name, or any city if name not provided
 */
export async function getTestCity(
  name?: string
): Promise<{ id: string; name: string; country: string } | null> {
  let query = supabase.from('cities').select('id, name, country').limit(1);

  if (name) {
    query = query.ilike('name', `%${name}%`);
  }

  const { data, error } = await query.single();

  if (error) {
    console.warn(`Could not find test city: ${error.message}`);
    return null;
  }

  return data;
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
  console.log('Cleaning up test data from database...');

  try {
    // First, get all test publisher IDs
    const { data: testPublishers } = await supabase
      .from('publishers')
      .select('id')
      .or(`name.ilike.${TEST_PREFIX}%,email.ilike.%@${TEST_EMAIL_DOMAIN}`);

    const publisherIds = testPublishers?.map((p) => p.id) || [];

    if (publisherIds.length > 0) {
      // Delete test algorithms for these publishers
      const { error: algoError } = await supabase
        .from('algorithms')
        .delete()
        .in('publisher_id', publisherIds);

      if (algoError) {
        console.warn(`Error cleaning algorithms: ${algoError.message}`);
      }

      // Delete test coverage for these publishers
      const { error: coverageError } = await supabase
        .from('publisher_coverage')
        .delete()
        .in('publisher_id', publisherIds);

      if (coverageError) {
        console.warn(`Error cleaning coverage: ${coverageError.message}`);
      }

      // Delete test publishers
      const { error: pubError } = await supabase
        .from('publishers')
        .delete()
        .in('id', publisherIds);

      if (pubError) {
        console.warn(`Error cleaning publishers: ${pubError.message}`);
      }
    }

    // Also try to delete by name pattern directly (in case some were missed)
    const { error: nameError } = await supabase
      .from('publishers')
      .delete()
      .ilike('name', `${TEST_PREFIX}%`);

    if (nameError) {
      console.warn(`Error cleaning publishers by name: ${nameError.message}`);
    }

    // Clear the cache
    testEntityCache.clear();

    console.log('Test data cleanup complete');
  } catch (error) {
    console.error('Error during test data cleanup:', error);
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
