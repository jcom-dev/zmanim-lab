/**
 * Manual cleanup script to remove all MailSlurp test users from Clerk
 * Run with: npx tsx cleanup-clerk-users.ts
 */

import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables FIRST before any imports
dotenv.config({ path: path.resolve(__dirname, '.env') });
dotenv.config({ path: path.resolve(__dirname, '../web/.env.local') });
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// Set a dummy MailSlurp key if not present (cleanup doesn't need it)
if (!process.env.MAILSLURP_API_KEY) {
  process.env.MAILSLURP_API_KEY = 'dummy-key-for-cleanup';
}

// Now import after env is loaded
import { cleanupTestUsers } from './e2e/utils/clerk-auth';

async function main() {
  console.log('🧹 Starting Clerk test user cleanup...\n');

  try {
    await cleanupTestUsers();
    console.log('\n✅ Cleanup completed successfully!');
  } catch (error) {
    console.error('\n❌ Cleanup failed:', error);
    process.exit(1);
  }
}

main();
