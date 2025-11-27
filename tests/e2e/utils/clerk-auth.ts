/**
 * Clerk Authentication Helpers for E2E Tests
 *
 * Uses @clerk/testing package for reliable authentication in Playwright tests.
 * This approach uses testing tokens to bypass bot detection and provides
 * programmatic sign-in capabilities.
 */

import { createClerkClient } from '@clerk/backend';
import { setupClerkTestingToken, clerk } from '@clerk/testing/playwright';
import type { Page, BrowserContext } from '@playwright/test';
import { createTestInbox } from './email-testing';

// Initialize Clerk client
const getClerkClient = () => {
  const secretKey = process.env.CLERK_SECRET_KEY;
  if (!secretKey) {
    throw new Error('CLERK_SECRET_KEY environment variable is required');
  }
  return createClerkClient({ secretKey });
};

const TEST_PASSWORD = 'TestPassword123!';

// Cache for created test users to avoid recreating
const testUserCache = new Map<string, { id: string; email: string; inboxId: string }>();

/**
 * Generate a unique test email address using MailSlurp
 * This creates a real, functioning email address that Clerk will accept
 */
async function generateTestEmail(prefix: string): Promise<{ email: string; inboxId: string }> {
  const inbox = await createTestInbox(`clerk-${prefix}-${Date.now()}`);
  return {
    email: inbox.emailAddress,
    inboxId: inbox.id,
  };
}

/**
 * Create a test admin user in Clerk
 */
export async function createTestAdmin(): Promise<{ id: string; email: string }> {
  const cacheKey = 'admin';
  if (testUserCache.has(cacheKey)) {
    const cached = testUserCache.get(cacheKey)!;
    return { id: cached.id, email: cached.email };
  }

  const { email, inboxId } = await generateTestEmail('test-admin');
  const clerkClient = getClerkClient();

  try {
    const user = await clerkClient.users.createUser({
      emailAddress: [email],
      password: TEST_PASSWORD,
      publicMetadata: {
        role: 'admin',
      },
      skipPasswordChecks: true,
      skipPasswordRequirement: true,
    });

    const result = { id: user.id, email, inboxId };
    testUserCache.set(cacheKey, result);
    return { id: user.id, email };
  } catch (error: any) {
    // Log the full error for debugging
    console.error('Clerk createUser error:', error?.errors || error?.message || error);
    throw error;
  }
}

/**
 * Create a test publisher user in Clerk linked to a publisher
 */
export async function createTestPublisher(
  publisherId: string
): Promise<{ id: string; email: string }> {
  const cacheKey = `publisher-${publisherId}`;
  if (testUserCache.has(cacheKey)) {
    const cached = testUserCache.get(cacheKey)!;
    return { id: cached.id, email: cached.email };
  }

  const { email, inboxId } = await generateTestEmail('test-publisher');
  const clerkClient = getClerkClient();

  try {
    const user = await clerkClient.users.createUser({
      emailAddress: [email],
      password: TEST_PASSWORD,
      publicMetadata: {
        role: 'publisher',
        publisher_access_list: [publisherId],
      },
      skipPasswordChecks: true,
      skipPasswordRequirement: true,
    });

    const result = { id: user.id, email, inboxId };
    testUserCache.set(cacheKey, result);
    return { id: user.id, email };
  } catch (error: any) {
    console.error('Clerk createUser error:', error?.errors || error?.message || error);
    throw error;
  }
}

/**
 * Create a test regular user in Clerk (no special roles)
 */
export async function createTestUser(): Promise<{ id: string; email: string }> {
  const cacheKey = 'user';
  if (testUserCache.has(cacheKey)) {
    const cached = testUserCache.get(cacheKey)!;
    return { id: cached.id, email: cached.email };
  }

  const { email, inboxId } = await generateTestEmail('test-user');
  const clerkClient = getClerkClient();

  try {
    const user = await clerkClient.users.createUser({
      emailAddress: [email],
      password: TEST_PASSWORD,
      publicMetadata: {
        role: 'user',
      },
      skipPasswordChecks: true,
      skipPasswordRequirement: true,
    });

    const result = { id: user.id, email, inboxId };
    testUserCache.set(cacheKey, result);
    return { id: user.id, email };
  } catch (error: any) {
    console.error('Clerk createUser error:', error?.errors || error?.message || error);
    throw error;
  }
}

/**
 * Setup Clerk testing token and sign in using the official @clerk/testing approach
 * This bypasses bot detection and uses Clerk's programmatic sign-in
 */
async function performClerkSignIn(page: Page, email: string): Promise<void> {
  const baseUrl = process.env.BASE_URL || 'http://localhost:3001';

  // Navigate to the app first (Clerk needs to be loaded)
  await page.goto(baseUrl);
  await page.waitForLoadState('domcontentloaded');

  // Setup testing token to bypass bot detection
  // This must be done after navigating to the page
  try {
    await setupClerkTestingToken({ page });
  } catch (error: any) {
    console.warn('Warning: setupClerkTestingToken failed:', error?.message);
    // Continue anyway - the global setup may have already set it up
  }

  // Wait for Clerk to be loaded
  await page.waitForFunction(() => {
    return typeof (window as any).Clerk !== 'undefined';
  }, { timeout: 30000 });

  await page.waitForFunction(() => {
    return (window as any).Clerk?.loaded === true;
  }, { timeout: 30000 });

  // Sign in using the email address
  // The @clerk/testing package handles creating a sign-in token internally
  try {
    await clerk.signIn({
      page,
      signInParams: {
        strategy: 'password',
        identifier: email,
        password: TEST_PASSWORD,
      },
    });
  } catch (error: any) {
    // If password sign-in fails, try the email-based approach
    console.log('Password sign-in failed, trying email-based sign-in...');
    await clerk.signIn({
      page,
      emailAddress: email,
    });
  }

  // Wait for authentication to complete
  await page.waitForFunction(() => {
    return (window as any).Clerk?.user !== null;
  }, { timeout: 30000 });

  // Give the app a moment to update state
  await page.waitForTimeout(1000);
}

/**
 * Inject admin authentication into a Playwright page
 *
 * Strategy: Use @clerk/testing for reliable programmatic authentication
 */
export async function loginAsAdmin(page: Page): Promise<void> {
  const user = await createTestAdmin();
  await performClerkSignIn(page, user.email);
}

/**
 * Inject publisher authentication into a Playwright page
 */
export async function loginAsPublisher(
  page: Page,
  publisherId: string
): Promise<void> {
  const user = await createTestPublisher(publisherId);
  await performClerkSignIn(page, user.email);
}

/**
 * Inject regular user authentication into a Playwright page
 */
export async function loginAsUser(page: Page): Promise<void> {
  const user = await createTestUser();
  await performClerkSignIn(page, user.email);
}

/**
 * Sign out the current user
 */
export async function logout(page: Page): Promise<void> {
  try {
    await clerk.signOut({ page });
  } catch (error) {
    // If clerk.signOut fails, navigate to sign-out URL
    const baseUrl = process.env.BASE_URL || 'http://localhost:3001';
    await page.goto(`${baseUrl}/sign-out`);
  }
}

/**
 * Clean up all test users from Clerk
 * Call this in global teardown
 */
export async function cleanupTestUsers(): Promise<void> {
  console.log('Cleaning up test users from Clerk...');

  const clerkClient = getClerkClient();

  // Test email domains to identify test users
  const testDomains = [
    '@mailslurp.xyz',
    '@mailslurp.world',
    '@mailslurp.com',
    '@tempsmtp.com',
    '@test-zmanim.example.com', // Old test domain
    '@zmanim-e2e-test.com', // Another old test domain
    '@clerk.test', // Another old test domain
  ];

  // Get all users (paginated)
  let offset = 0;
  const limit = 100;
  let hasMore = true;
  let deletedCount = 0;

  while (hasMore) {
    const response = await clerkClient.users.getUserList({
      limit,
      offset,
    });

    // Filter for test users using test domains
    const testUsers = response.data.filter((user) =>
      user.emailAddresses.some((email) =>
        testDomains.some((domain) => email.emailAddress.endsWith(domain))
      )
    );

    for (const user of testUsers) {
      try {
        await clerkClient.users.deleteUser(user.id);
        deletedCount++;
        const userEmail = user.emailAddresses[0]?.emailAddress || user.id;
        console.log(`Deleted test user: ${userEmail}`);
      } catch (error) {
        console.error(`Failed to delete user ${user.id}:`, error);
      }
    }

    hasMore = response.data.length === limit;
    offset += limit;
  }

  // Clear the cache
  testUserCache.clear();
  console.log(`Test user cleanup complete. Deleted ${deletedCount} test users.`);
}

/**
 * Clear the test user cache (useful between test files)
 */
export function clearUserCache(): void {
  testUserCache.clear();
}

/**
 * Get the test password (for UI login fallback)
 */
export function getTestPassword(): string {
  return TEST_PASSWORD;
}

/**
 * Get the test email domains (MailSlurp uses multiple domains)
 */
export function getTestEmailDomains(): string[] {
  return ['mailslurp.xyz', 'mailslurp.world', 'mailslurp.com', 'tempsmtp.com'];
}
