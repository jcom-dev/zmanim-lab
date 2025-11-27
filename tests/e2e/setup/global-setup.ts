/**
 * Playwright Global Setup
 *
 * Runs once before all tests.
 * - Loads environment variables
 * - Validates required configuration
 * - Initializes Clerk testing token (bypasses bot detection)
 */

import { FullConfig } from '@playwright/test';
import { clerkSetup } from '@clerk/testing/playwright';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables from multiple locations
function loadEnvFiles() {
  // Load from tests/.env
  dotenv.config({ path: path.resolve(__dirname, '../../.env') });

  // Load from web/.env.local (Clerk keys often here)
  dotenv.config({ path: path.resolve(__dirname, '../../../web/.env.local') });

  // Load from root .env
  dotenv.config({ path: path.resolve(__dirname, '../../../.env') });
}

async function globalSetup(config: FullConfig) {
  console.log('\n========================================');
  console.log('Playwright Global Setup');
  console.log('========================================\n');

  // Load environment variables
  loadEnvFiles();

  // Validate required environment variables
  const requiredVars = [
    'CLERK_SECRET_KEY',
  ];

  const optionalVars = [
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
  console.log(`  - SUPABASE_URL: ${process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'NOT SET'}`);
  console.log(`  - SUPABASE_SERVICE_KEY: ${process.env.SUPABASE_SERVICE_KEY ? '***set***' : 'NOT SET'}`);
  console.log(`  - MAILSLURP_API_KEY: ${process.env.MAILSLURP_API_KEY ? '***set***' : 'NOT SET (email tests will skip)'}`);
  console.log(`  - BASE_URL: ${process.env.BASE_URL || 'http://localhost:3001'}`);

  // Check for optional vars
  const missingOptional = optionalVars.filter((v) => !process.env[v]);
  if (missingOptional.length > 0) {
    console.log('\nNote: Some optional vars not set (database fixtures may not work):');
    missingOptional.forEach((v) => console.log(`  - ${v}`));
  }

  // Initialize Clerk testing token
  // This sets CLERK_FAPI and CLERK_TESTING_TOKEN env vars
  // to bypass bot detection in tests
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
