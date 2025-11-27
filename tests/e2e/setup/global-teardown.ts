/**
 * Playwright Global Teardown
 *
 * Runs once after all tests complete.
 * - Cleans up test users from Clerk
 * - Cleans up test data from database
 */

import { FullConfig } from '@playwright/test';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../../web/.env.local') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

async function globalTeardown(config: FullConfig) {
  console.log('\n========================================');
  console.log('Playwright Global Teardown');
  console.log('========================================\n');

  // Skip cleanup if running in watch mode or explicitly disabled
  if (process.env.SKIP_CLEANUP === 'true') {
    console.log('Skipping cleanup (SKIP_CLEANUP=true)');
    return;
  }

  try {
    // Import cleanup utilities
    const { cleanupTestUsers } = await import('../utils/clerk-auth');
    const { cleanupTestData } = await import('../utils/test-fixtures');
    const { cleanupAllInboxes, isMailSlurpConfigured } = await import('../utils/email-testing');

    // Clean up Clerk users
    console.log('Cleaning up Clerk test users...');
    await cleanupTestUsers();

    // Clean up database data
    console.log('Cleaning up database test data...');
    await cleanupTestData();

    // Clean up MailSlurp inboxes if configured
    if (isMailSlurpConfigured()) {
      console.log('Cleaning up MailSlurp inboxes...');
      await cleanupAllInboxes();
    }

    console.log('All cleanup complete');
  } catch (error) {
    console.error('Error during cleanup:', error);
    // Don't fail the test run due to cleanup errors
  }

  console.log('\n========================================');
  console.log('Global Teardown Complete');
  console.log('========================================\n');
}

export default globalTeardown;
