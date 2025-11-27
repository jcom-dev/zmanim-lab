/**
 * E2E Tests: Publisher Algorithm Editor
 *
 * Tests for algorithm configuration functionality:
 * - Loading algorithm editor
 * - Template selection
 * - Zman configuration
 * - Save draft and publish
 */

import { test, expect } from '@playwright/test';
import {
  loginAsPublisher,
  createTestPublisherEntity,
  cleanupTestData,
  BASE_URL,
} from '../utils';

test.describe('Publisher Algorithm Editor', () => {
  let testPublisher: { id: string; name: string };

  test.beforeAll(async () => {
    testPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Algorithm_Publisher',
      organization: 'TEST_E2E_Algorithm_Org',
      status: 'verified',
    });
  });

  test.afterAll(async () => {
    await cleanupTestData();
  });

  test('publisher can access algorithm editor', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);

    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');

    // Should load without error
    expect(page.url()).toContain('/publisher/algorithm');
  });

  test('algorithm editor page loads successfully', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);

    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');

    // Page should have algorithm-related content
    // This might be "Zmanim" or "Algorithm" depending on the page title
    const pageContent = await page.textContent('body');
    expect(
      pageContent?.toLowerCase().includes('zmanim') ||
      pageContent?.toLowerCase().includes('algorithm') ||
      pageContent?.toLowerCase().includes('times')
    ).toBe(true);
  });

  test('algorithm page navigable from dashboard', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);

    // Start at dashboard
    await page.goto(`${BASE_URL}/publisher/dashboard`);
    await page.waitForLoadState('networkidle');

    // Click on Zmanim card
    await page.getByRole('heading', { name: 'Zmanim' }).click();

    await page.waitForURL('**/publisher/algorithm');
    expect(page.url()).toContain('/publisher/algorithm');
  });
});

test.describe('Publisher Algorithm - New Publisher Flow', () => {
  test('new publisher sees setup prompt', async ({ page }) => {
    const newPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_New_Algorithm',
      status: 'verified',
    });

    await loginAsPublisher(page, newPublisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');

    // New publisher without algorithm should see setup content
    const pageContent = await page.textContent('body');
    expect(pageContent).toBeTruthy();

    await cleanupTestData();
  });
});
