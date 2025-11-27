/**
 * Playwright Global Setup
 *
 * Runs once before all tests.
 * - Loads environment variables
 * - Validates required configuration
 * - Initializes Clerk testing token (bypasses bot detection)
 * - Seeds test data in the database
 */

import { FullConfig } from '@playwright/test';
import { clerkSetup } from '@clerk/testing/playwright';
import * as dotenv from 'dotenv';
import * as path from 'path';
import { Pool } from 'pg';

// Load environment variables from multiple locations
function loadEnvFiles() {
  // Load from tests/.env
  dotenv.config({ path: path.resolve(__dirname, '../../.env') });

  // Load from web/.env.local (Clerk keys often here)
  dotenv.config({ path: path.resolve(__dirname, '../../../web/.env.local') });

  // Load from root .env
  dotenv.config({ path: path.resolve(__dirname, '../../../.env') });
}

// Seed test publishers in the database
async function seedTestPublishers(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.log('DATABASE_URL not set - skipping database seeding');
    return;
  }

  const pool = new Pool({ connectionString: databaseUrl });

  try {
    // Check if we have test publishers
    const existingResult = await pool.query(
      "SELECT COUNT(*) as count FROM publishers WHERE name LIKE 'E2E Test%'"
    );

    if (parseInt(existingResult.rows[0].count) >= 3) {
      console.log('Test publishers already exist - skipping seeding');
      return;
    }

    console.log('Seeding test publishers in database...');

    // Create test publishers with different statuses
    const testPublishers = [
      {
        name: 'E2E Test Publisher - Verified',
        slug: 'e2e-test-verified',
        email: 'e2e-verified@test.zmanim.com',
        organization: 'E2E Test Organization',
        status: 'verified',
        website: 'https://test.example.com',
        bio: 'Test publisher for E2E testing - verified status',
      },
      {
        name: 'E2E Test Publisher - Pending',
        slug: 'e2e-test-pending',
        email: 'e2e-pending@test.zmanim.com',
        organization: 'E2E Pending Organization',
        status: 'pending',
        website: 'https://pending.example.com',
        bio: 'Test publisher for E2E testing - pending status',
      },
      {
        name: 'E2E Test Publisher - Suspended',
        slug: 'e2e-test-suspended',
        email: 'e2e-suspended@test.zmanim.com',
        organization: 'E2E Suspended Organization',
        status: 'suspended',
        website: 'https://suspended.example.com',
        bio: 'Test publisher for E2E testing - suspended status',
      },
    ];

    for (const pub of testPublishers) {
      // Check if exists
      const exists = await pool.query(
        'SELECT id FROM publishers WHERE slug = $1',
        [pub.slug]
      );

      if (exists.rows.length === 0) {
        const result = await pool.query(
          `INSERT INTO publishers (name, slug, email, organization, status, website, bio)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING id`,
          [pub.name, pub.slug, pub.email, pub.organization, pub.status, pub.website, pub.bio]
        );
        console.log(`Created test publisher: ${pub.name} (${result.rows[0].id})`);

        // Create a test algorithm for verified publisher
        if (pub.status === 'verified') {
          const publisherId = result.rows[0].id;
          await pool.query(
            `INSERT INTO algorithms (publisher_id, name, version, description, formula_definition, calculation_type, status, config, is_active)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
             ON CONFLICT DO NOTHING`,
            [
              publisherId,
              'E2E Test Algorithm',
              '1.0.0',
              'Test algorithm for E2E testing',
              JSON.stringify({
                alos: { method: 'solar_angle', params: { degrees: 16.1 } },
                sunrise: { method: 'sunrise', params: {} },
                sunset: { method: 'sunset', params: {} },
                tzeis: { method: 'solar_angle', params: { degrees: 8.5 } },
              }),
              'solar_depression',
              'published',
              JSON.stringify({
                name: 'E2E Test GRA Algorithm',
                description: 'Test algorithm for E2E testing',
              }),
              true,
            ]
          );
          console.log(`Created test algorithm for ${pub.name}`);
        }
      } else {
        console.log(`Test publisher already exists: ${pub.name}`);
      }
    }

    console.log('Database seeding complete');
  } catch (error) {
    console.error('Error seeding database:', error);
  } finally {
    await pool.end();
  }
}

// Store test publisher IDs for use in tests
async function getTestPublisherIds(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) return;

  const pool = new Pool({ connectionString: databaseUrl });

  try {
    const result = await pool.query(
      "SELECT id, name, status FROM publishers WHERE name LIKE 'E2E Test%' OR status IN ('verified', 'pending', 'suspended')"
    );

    console.log('\nTest Publishers Available:');
    for (const row of result.rows) {
      console.log(`  - ${row.name} (${row.status}): ${row.id}`);
    }

    // Export to environment for tests to use
    const verified = result.rows.find((r) => r.status === 'verified');
    const pending = result.rows.find((r) => r.status === 'pending');
    const suspended = result.rows.find((r) => r.status === 'suspended');

    if (verified) process.env.TEST_PUBLISHER_VERIFIED_ID = verified.id;
    if (pending) process.env.TEST_PUBLISHER_PENDING_ID = pending.id;
    if (suspended) process.env.TEST_PUBLISHER_SUSPENDED_ID = suspended.id;
  } finally {
    await pool.end();
  }
}

async function globalSetup(config: FullConfig) {
  console.log('\n========================================');
  console.log('Playwright Global Setup');
  console.log('========================================\n');

  // Load environment variables
  loadEnvFiles();

  // Validate required environment variables
  const requiredVars = ['CLERK_SECRET_KEY'];

  const optionalVars = [
    'DATABASE_URL',
    'SUPABASE_URL',
    'NEXT_PUBLIC_SUPABASE_URL',
    'SUPABASE_SERVICE_KEY',
  ];

  const missing: string[] = [];
  for (const varName of requiredVars) {
    if (!process.env[varName]) {
      missing.push(varName);
    }
  }

  if (missing.length > 0) {
    console.error('Missing required environment variables:');
    missing.forEach((v) => console.error(`  - ${v}`));
    console.error('\nPlease ensure these are set in:');
    console.error('  - tests/.env');
    console.error('  - web/.env.local');
    console.error('  - Or your CI environment');
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  // Log configuration (without secrets)
  console.log('Environment Configuration:');
  console.log(`  - CLERK_SECRET_KEY: ${process.env.CLERK_SECRET_KEY ? '***set***' : 'NOT SET'}`);
  console.log(`  - DATABASE_URL: ${process.env.DATABASE_URL ? '***set***' : 'NOT SET'}`);
  console.log(`  - MAILSLURP_API_KEY: ${process.env.MAILSLURP_API_KEY ? '***set***' : 'NOT SET (email tests will skip)'}`);
  console.log(`  - BASE_URL: ${process.env.BASE_URL || 'http://localhost:3001'}`);

  // Seed test data in database
  await seedTestPublishers();
  await getTestPublisherIds();

  // Initialize Clerk testing token
  console.log('\nInitializing Clerk testing token...');
  try {
    await clerkSetup();
    console.log('Clerk testing token initialized successfully');
  } catch (error: any) {
    console.warn('Warning: Could not initialize Clerk testing token:', error?.message);
    console.warn('Tests may encounter bot detection issues');
  }

  console.log('\n========================================');
  console.log('Global Setup Complete');
  console.log('========================================\n');
}

export default globalSetup;
