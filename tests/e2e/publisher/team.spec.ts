/**
 * E2E Tests: Publisher Team Management
 *
 * Tests for team/user management:
 * - Viewing team members
 * - Team page access
 */

import { test, expect } from '@playwright/test';
import {
  loginAsPublisher,
  createTestPublisherEntity,
  cleanupTestData,
  BASE_URL,
} from '../utils';

test.describe('Publisher Team', () => {
  let testPublisher: { id: string; name: string };

  test.beforeAll(async () => {
    testPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Team_Publisher',
      organization: 'TEST_E2E_Team_Org',
      status: 'verified',
    });
  });

  test.afterAll(async () => {
    await cleanupTestData();
  });

  test('publisher can access team page', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);

    await page.goto(`${BASE_URL}/publisher/team`);
    await page.waitForLoadState('networkidle');

    expect(page.url()).toContain('/publisher/team');
  });

  test('team page loads without error', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);

    await page.goto(`${BASE_URL}/publisher/team`);
    await page.waitForLoadState('networkidle');

    // Page should load (no error state)
    const pageContent = await page.textContent('body');
    expect(pageContent).toBeTruthy();
    expect(pageContent?.toLowerCase()).not.toContain('error loading');
  });
});
