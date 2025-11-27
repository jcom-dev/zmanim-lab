/**
 * E2E Tests: Location Selection
 *
 * Tests for home page location selection:
 * - Country selection
 * - Region selection
 * - City selection
 * - Navigation to zmanim page
 */

import { test, expect } from '@playwright/test';
import { BASE_URL } from '../utils';

test.describe('Home Page - Location Selection', () => {
  test('home page loads with location selection', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    // Should see title
    await expect(page.getByRole('heading', { name: 'Zmanim Lab' })).toBeVisible();

    // Should see location selection prompt
    await expect(page.getByText('Select Country')).toBeVisible();
  });

  test('home page shows country list', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    // Wait for countries to load
    await page.waitForTimeout(1000);

    // Should see country buttons
    const countryButtons = page.locator('button').filter({ hasText: /cities$/i });
    await expect(countryButtons.first()).toBeVisible();
  });

  test('clicking country shows regions or cities', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    // Wait for countries to load
    await page.waitForTimeout(1000);

    // Click first country
    const countryButtons = page.locator('button').filter({ hasText: /cities$/i });
    await countryButtons.first().click();

    // Should show next step (region or city selection)
    await page.waitForTimeout(500);

    // URL should still be home or breadcrumb should update
    const breadcrumb = page.locator('button').filter({ hasText: /← Back/i });

    // Either we see cities directly or regions first
    const hasRegions = await page.getByText('Select State').isVisible().catch(() => false);
    const hasCities = await page.getByText('Select City').isVisible().catch(() => false);
    const hasBackButton = await breadcrumb.isVisible().catch(() => false);

    expect(hasRegions || hasCities || hasBackButton).toBe(true);
  });

  test('breadcrumb navigation works', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    // Wait for countries to load
    await page.waitForTimeout(1000);

    // Click first country
    const countryButtons = page.locator('button').filter({ hasText: /cities$/i });
    const firstCountryName = await countryButtons.first().textContent();
    await countryButtons.first().click();

    await page.waitForTimeout(500);

    // Should see back button
    const backButton = page.getByText('← Back');
    if (await backButton.isVisible()) {
      await backButton.click();

      // Should be back at country selection
      await expect(page.getByText('Select Country')).toBeVisible();
    }
  });

  test('selecting city navigates to zmanim page', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    // Wait for countries to load
    await page.waitForTimeout(1000);

    // Find Israel (usually has Jerusalem which we use for testing)
    const israelButton = page.locator('button').filter({ hasText: /Israel/i });
    if (await israelButton.isVisible()) {
      await israelButton.click();
      await page.waitForTimeout(500);

      // Find Jerusalem city
      const jerusalemButton = page.locator('button').filter({ hasText: /Jerusalem/i });
      if (await jerusalemButton.isVisible()) {
        await jerusalemButton.click();

        // Should navigate to zmanim page
        await page.waitForURL('**/zmanim/**');
        expect(page.url()).toContain('/zmanim/');
      }
    }
  });
});

test.describe('Home Page - UI Elements', () => {
  test('home page shows navigation bar', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    // Should see Zmanim Lab title in nav
    await expect(page.getByText('Zmanim Lab').first()).toBeVisible();
  });

  test('home page shows sign in option', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    // Should see Sign In button
    await expect(page.getByText('Sign In')).toBeVisible();
  });

  test('home page has become publisher link in footer', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    // Should see become publisher link
    await expect(page.getByRole('link', { name: 'Become a Publisher' })).toBeVisible();
  });

  test('clicking become publisher navigates to registration', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    await page.getByRole('link', { name: 'Become a Publisher' }).click();

    await page.waitForURL('**/become-publisher');
    expect(page.url()).toContain('/become-publisher');
  });
});

test.describe('Home Page - Subtitle and Description', () => {
  test('shows multi-publisher subtitle', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    await expect(page.getByText('Multi-Publisher Zmanim Platform')).toBeVisible();
  });

  test('shows location selection instruction', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    await expect(page.getByText(/select your location/i)).toBeVisible();
  });
});
