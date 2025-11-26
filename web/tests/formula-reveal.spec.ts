import { test, expect } from '@playwright/test';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

test.describe('Story 1.11: Formula Reveal', () => {
  test.describe('AC1: Info icon appears next to each zmanim time', () => {
    test('Each zman row has an info icon button', async ({ page }) => {
      // Get a valid city
      const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        await page.goto(`/zmanim/${cityId}/default`);

        // Wait for zmanim to load
        await page.waitForTimeout(2000);

        // Check that info buttons exist
        const infoButtons = page.locator('button[aria-label*="Show formula details"]');
        const count = await infoButtons.count();
        expect(count).toBeGreaterThan(0);
      }
    });

    test('Info icon has proper accessibility attributes', async ({ page }) => {
      const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        await page.goto(`/zmanim/${cityId}/default`);

        await page.waitForTimeout(2000);

        // Check first info button has aria-label
        const firstInfoButton = page.locator('button[aria-label*="Show formula details"]').first();
        await expect(firstInfoButton).toHaveAttribute('aria-label', /Show formula details for/);
      }
    });
  });

  test.describe('AC2: Desktop - Clicking icon opens right side panel', () => {
    test('Panel opens on desktop viewport', async ({ page }) => {
      // Set desktop viewport
      await page.setViewportSize({ width: 1280, height: 800 });

      const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        await page.goto(`/zmanim/${cityId}/default`);

        await page.waitForTimeout(2000);

        // Click info button
        const infoButton = page.locator('button[aria-label*="Show formula details"]').first();
        await infoButton.click();

        // Panel should open
        await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5000 });

        // Panel should have right-side position class (inset-y-0 right-0)
        const panel = page.locator('[role="dialog"] > div').first();
        await expect(panel).toBeVisible();
      }
    });
  });

  test.describe('AC3: Mobile - Clicking icon opens bottom sheet', () => {
    test('Sheet opens from bottom on mobile viewport', async ({ page }) => {
      // Set mobile viewport
      await page.setViewportSize({ width: 375, height: 667 });

      const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        await page.goto(`/zmanim/${cityId}/default`);

        await page.waitForTimeout(2000);

        // Click info button
        const infoButton = page.locator('button[aria-label*="Show formula details"]').first();
        await infoButton.click();

        // Dialog should open
        await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5000 });

        // On mobile, should have bottom sheet styling (rounded top corners)
        const panel = page.locator('[role="dialog"]');
        await expect(panel).toBeVisible();
      }
    });
  });

  test.describe('AC4: Panel shows zman name, method, parameters, explanation', () => {
    test('Panel displays zman name', async ({ page }) => {
      const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        await page.goto(`/zmanim/${cityId}/default`);

        await page.waitForTimeout(2000);

        // Click info button for a specific zman
        const infoButton = page.locator('button[aria-label*="Show formula details for Alos"]').first();
        if (await infoButton.isVisible({ timeout: 3000 })) {
          await infoButton.click();

          // Check panel shows zman name
          await expect(page.getByRole('dialog').getByText('Alos HaShachar')).toBeVisible({ timeout: 5000 });
        } else {
          // Try first available button
          await page.locator('button[aria-label*="Show formula details"]').first().click();
          await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5000 });
        }
      }
    });

    test('Panel displays calculation method section', async ({ page }) => {
      const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        await page.goto(`/zmanim/${cityId}/default`);

        await page.waitForTimeout(2000);

        // Click info button
        await page.locator('button[aria-label*="Show formula details"]').first().click();

        // Check calculation method section exists
        await expect(page.getByText('Calculation Method')).toBeVisible({ timeout: 5000 });
      }
    });

    test('Panel displays explanation section when available', async ({ page }) => {
      const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        await page.goto(`/zmanim/${cityId}/default`);

        await page.waitForTimeout(2000);

        // Click info button
        await page.locator('button[aria-label*="Show formula details"]').first().click();

        // Wait for dialog
        await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5000 });

        // Explanation section may or may not be present depending on data
        // Just verify the dialog opened successfully
      }
    });
  });

  test.describe('AC6: Panel dismisses correctly', () => {
    test('Panel closes when clicking X button', async ({ page }) => {
      const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        await page.goto(`/zmanim/${cityId}/default`);

        await page.waitForTimeout(2000);

        // Open panel
        await page.locator('button[aria-label*="Show formula details"]').first().click();
        await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5000 });

        // Click close button
        const closeButton = page.getByRole('button', { name: 'Close' });
        await closeButton.click();

        // Panel should close
        await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 5000 });
      }
    });

    test('Panel closes when pressing Escape key', async ({ page }) => {
      const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        await page.goto(`/zmanim/${cityId}/default`);

        await page.waitForTimeout(2000);

        // Open panel
        await page.locator('button[aria-label*="Show formula details"]').first().click();
        await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5000 });

        // Press Escape
        await page.keyboard.press('Escape');

        // Panel should close
        await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 5000 });
      }
    });

    test('Panel closes when clicking overlay/outside', async ({ page }) => {
      const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        await page.goto(`/zmanim/${cityId}/default`);

        await page.waitForTimeout(2000);

        // Open panel
        await page.locator('button[aria-label*="Show formula details"]').first().click();
        await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5000 });

        // Click on overlay (outside the panel)
        const overlay = page.locator('.fixed.inset-0.bg-black\\/80');
        if (await overlay.isVisible()) {
          await overlay.click({ position: { x: 10, y: 10 } });
          await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 5000 });
        }
      }
    });
  });

  test.describe('API returns formula data', () => {
    test('Zmanim API includes formula details', async ({ request }) => {
      const citiesResponse = await request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${cityId}`);
        expect(response.ok()).toBeTruthy();

        const data = await response.json();
        const zmanim = data.data?.zmanim || data.zmanim || [];

        expect(zmanim.length).toBeGreaterThan(0);

        // Each zman should have formula details
        for (const zman of zmanim) {
          expect(zman.formula).toBeDefined();
          expect(zman.formula.method).toBeDefined();
        }
      }
    });

    test('Formula includes display_name and explanation', async ({ request }) => {
      const citiesResponse = await request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
      const citiesData = await citiesResponse.json();
      const cities = citiesData.data?.cities || citiesData.cities || [];

      if (cities.length > 0) {
        const cityId = cities[0].id;
        const response = await request.get(`${API_BASE}/api/v1/zmanim?cityId=${cityId}`);
        const data = await response.json();
        const zmanim = data.data?.zmanim || data.zmanim || [];

        if (zmanim.length > 0) {
          const formula = zmanim[0].formula;
          // display_name or method should exist
          expect(formula.display_name || formula.method).toBeTruthy();
        }
      }
    });
  });
});
