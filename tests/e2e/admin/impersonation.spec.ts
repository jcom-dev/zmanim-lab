/**
 * E2E Tests: Admin Impersonation
 *
 * Tests for admin impersonation functionality:
 * - Starting impersonation from publisher details
 * - Viewing publisher dashboard as admin
 * - Impersonation banner visibility
 * - Exiting impersonation
 */

import { test, expect } from '@playwright/test';
import {
  loginAsAdmin,
  createTestPublisherEntity,
  cleanupTestData,
  BASE_URL,
} from '../utils';

test.describe('Admin Impersonation', () => {
  let testPublisher: { id: string; name: string };

  test.beforeAll(async () => {
    // Create a verified test publisher for impersonation tests
    testPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Impersonation_Publisher',
      organization: 'TEST_E2E_Impersonation_Org',
      status: 'verified',
    });
  });

  test.afterAll(async () => {
    await cleanupTestData();
  });

  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
  });

  test('admin can click impersonate button on publisher details', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Should see impersonation button
    const impersonateButton = page.getByRole('button', { name: /impersonate/i });
    await expect(impersonateButton).toBeVisible();

    // Click impersonate
    await impersonateButton.click();

    // Should navigate to publisher dashboard
    await page.waitForURL('**/publisher/dashboard');
    expect(page.url()).toContain('/publisher/dashboard');
  });

  test('impersonation stores state in session storage', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Click impersonate
    await page.getByRole('button', { name: /impersonate/i }).click();
    await page.waitForURL('**/publisher/dashboard');

    // Check session storage
    const impersonating = await page.evaluate(() => {
      return sessionStorage.getItem('impersonating');
    });

    expect(impersonating).toBeTruthy();
    const parsed = JSON.parse(impersonating!);
    expect(parsed.publisherId).toBe(testPublisher.id);
  });

  test('admin can view publisher dashboard while impersonating', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Click impersonate
    await page.getByRole('button', { name: /impersonate/i }).click();
    await page.waitForURL('**/publisher/dashboard');
    await page.waitForLoadState('networkidle');

    // Should see dashboard content
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('admin can exit impersonation by clearing session', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Start impersonation
    await page.getByRole('button', { name: /impersonate/i }).click();
    await page.waitForURL('**/publisher/dashboard');

    // Clear session storage to exit impersonation
    await page.evaluate(() => {
      sessionStorage.removeItem('impersonating');
    });

    // Navigate back to admin
    await page.goto(`${BASE_URL}/admin`);
    await page.waitForLoadState('networkidle');

    // Should see admin portal
    await expect(page.getByText('Welcome to Admin Portal')).toBeVisible();
  });

  test('admin can navigate to different publisher pages while impersonating', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Start impersonation
    await page.getByRole('button', { name: /impersonate/i }).click();
    await page.waitForURL('**/publisher/dashboard');

    // Navigate to profile
    await page.goto(`${BASE_URL}/publisher/profile`);
    await page.waitForLoadState('networkidle');

    // Should still be on publisher pages
    expect(page.url()).toContain('/publisher/profile');
  });
});
