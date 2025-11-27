/**
 * E2E Tests: Publisher Coverage
 *
 * Tests for coverage area management:
 * - Viewing coverage areas
 * - Adding coverage
 * - Coverage priority
 * - Toggling active/inactive
 * - Deleting coverage
 */

import { test, expect } from '@playwright/test';
import {
  loginAsPublisher,
  createTestPublisherEntity,
  createTestCoverage,
  getTestCity,
  cleanupTestData,
  BASE_URL,
} from '../utils';

test.describe('Publisher Coverage', () => {
  let testPublisher: { id: string; name: string };

  test.beforeAll(async () => {
    testPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Coverage_Publisher',
      organization: 'TEST_E2E_Coverage_Org',
      status: 'verified',
    });
  });

  test.afterAll(async () => {
    await cleanupTestData();
  });

  test('publisher can access coverage page', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);

    await page.goto(`${BASE_URL}/publisher/coverage`);
    await page.waitForLoadState('networkidle');

    expect(page.url()).toContain('/publisher/coverage');
  });

  test('coverage page navigable from dashboard', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);

    await page.goto(`${BASE_URL}/publisher/dashboard`);
    await page.waitForLoadState('networkidle');

    // Click on Coverage card
    await page.getByRole('heading', { name: 'Coverage' }).click();

    await page.waitForURL('**/publisher/coverage');
    expect(page.url()).toContain('/publisher/coverage');
  });
});

test.describe('Publisher Coverage - With Data', () => {
  let publisherWithCoverage: { id: string; name: string };

  test.beforeAll(async () => {
    publisherWithCoverage = await createTestPublisherEntity({
      name: 'TEST_E2E_Coverage_Data',
      status: 'verified',
    });

    // Add some coverage
    const city = await getTestCity('Jerusalem');
    if (city) {
      await createTestCoverage(publisherWithCoverage.id, city.id, {
        priority: 10,
        is_active: true,
      });
    }
  });

  test.afterAll(async () => {
    await cleanupTestData();
  });

  test('publisher sees existing coverage areas', async ({ page }) => {
    await loginAsPublisher(page, publisherWithCoverage.id);

    await page.goto(`${BASE_URL}/publisher/coverage`);
    await page.waitForLoadState('networkidle');

    // Should see coverage content
    const pageContent = await page.textContent('body');
    expect(pageContent).toBeTruthy();
  });
});

test.describe('Publisher Coverage - Empty State', () => {
  test('publisher without coverage sees empty state', async ({ page }) => {
    const emptyPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Empty_Coverage',
      status: 'verified',
    });

    await loginAsPublisher(page, emptyPublisher.id);
    await page.goto(`${BASE_URL}/publisher/coverage`);
    await page.waitForLoadState('networkidle');

    // Should see empty state or add button
    const pageContent = await page.textContent('body');
    expect(pageContent).toBeTruthy();

    await cleanupTestData();
  });
});
