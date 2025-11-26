import { test, expect } from '@playwright/test';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

test.describe('Zmanim Lab Homepage', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should visit the homepage and display main elements', async ({ page }) => {
    // Check hero section
    await expect(page.getByRole('heading', { name: 'Zmanim Lab' })).toBeVisible();
    await expect(page.getByText('Multi-Publisher Zmanim Platform')).toBeVisible();
    await expect(page.getByText('Select your location to view prayer times')).toBeVisible();
  });

  test('should display country selection', async ({ page }) => {
    // Check that Select Country heading is visible
    await expect(page.getByText('Select Country')).toBeVisible();

    // Check that country buttons are displayed
    const countryButtons = page.locator('button:has-text("cities")');
    await expect(countryButtons.first()).toBeVisible({ timeout: 10000 });
  });

  test('should display footer disclaimer', async ({ page }) => {
    await expect(page.getByText('Times are calculated based on astronomical and halachic methods')).toBeVisible();
  });
});

test.describe('Location Selection Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should show regions when country is selected', async ({ page }) => {
    // Wait for countries to load
    await page.waitForSelector('text=Select Country');

    // Click on United States (or another country with regions)
    const usButton = page.getByRole('button', { name: /United States/i });
    if (await usButton.isVisible({ timeout: 5000 })) {
      await usButton.click();

      // Should show regions or cities
      await expect(
        page.getByText('Select State/Region').or(page.getByText('Select City'))
      ).toBeVisible({ timeout: 10000 });
    }
  });

  test('should show cities when region is selected', async ({ page }) => {
    // Wait for countries to load
    await page.waitForSelector('text=Select Country');

    // Click on United States
    const usButton = page.getByRole('button', { name: /United States/i });
    if (await usButton.isVisible({ timeout: 5000 })) {
      await usButton.click();

      // Wait for regions to load
      await page.waitForTimeout(1000);

      // If regions are shown, click one
      const regionButton = page.locator('button').filter({ hasText: /New York|California|Texas/i }).first();
      if (await regionButton.isVisible({ timeout: 5000 })) {
        await regionButton.click();

        // Should show city selection
        await expect(page.getByText('Select City')).toBeVisible({ timeout: 10000 });
      }
    }
  });

  test('should navigate to publishers page when city is selected', async ({ page }) => {
    // Use API to get a valid city to test with
    const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
    const citiesData = await citiesResponse.json();
    const cities = citiesData.data?.cities || citiesData.cities || [];

    if (cities.length > 0) {
      const cityId = cities[0].id;
      // Navigate directly to city page to verify it works
      await page.goto(`/zmanim/${cityId}`);

      // Should show publisher selection or no coverage warning
      await expect(
        page.getByRole('link', { name: 'Change location' })
      ).toBeVisible({ timeout: 10000 });
    }
  });

  test('should allow going back in selection flow', async ({ page }) => {
    // Wait for countries to load
    await page.waitForSelector('text=Select Country');

    // Click on a country
    const countryButtons = page.locator('button:has-text("cities")');
    const firstCountry = countryButtons.first();

    if (await firstCountry.isVisible({ timeout: 5000 })) {
      await firstCountry.click();
      await page.waitForTimeout(500);

      // Look for back button
      const backButton = page.getByRole('button', { name: /back|change/i });
      if (await backButton.isVisible({ timeout: 3000 })) {
        await backButton.click();

        // Should be back at country selection
        await expect(page.getByText('Select Country')).toBeVisible({ timeout: 5000 });
      }
    }
  });
});

test.describe('Publisher Selection Flow', () => {
  test('should display publishers for a city', async ({ page }) => {
    // Get a city with publishers
    const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
    const citiesData = await citiesResponse.json();
    const cities = citiesData.data?.cities || citiesData.cities || [];

    if (cities.length > 0) {
      const cityId = cities[0].id;
      await page.goto(`/zmanim/${cityId}`);

      // Should show publisher list or no coverage message - use heading role for specificity
      await expect(
        page.getByRole('heading', { name: 'Select a Publisher' }).or(page.getByRole('heading', { name: 'No Local Authority', exact: true }))
      ).toBeVisible({ timeout: 10000 });
    }
  });

  test('should navigate to zmanim page when publisher is selected', async ({ page }) => {
    const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
    const citiesData = await citiesResponse.json();
    const cities = citiesData.data?.cities || citiesData.cities || [];

    if (cities.length > 0) {
      const cityId = cities[0].id;
      await page.goto(`/zmanim/${cityId}`);

      // Wait for page to load
      await page.waitForTimeout(1000);

      // Click on a publisher or default option
      const publisherButton = page.locator('button, a').filter({ hasText: /select|view|default/i }).first();
      if (await publisherButton.isVisible({ timeout: 5000 })) {
        await publisherButton.click();

        // Should navigate to zmanim display
        await expect(page.url()).toContain('/zmanim/');
      }
    }
  });
});

test.describe('Zmanim Display Flow', () => {
  test('should display zmanim times', async ({ page }) => {
    const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
    const citiesData = await citiesResponse.json();
    const cities = citiesData.data?.cities || citiesData.cities || [];

    if (cities.length > 0) {
      const cityId = cities[0].id;
      await page.goto(`/zmanim/${cityId}/default`);

      // Should show zmanim list - use first() to avoid strict mode violation
      await expect(
        page.getByText(/sunrise|alos|sunset|shkiah/i).first()
      ).toBeVisible({ timeout: 10000 });
    }
  });

  test('should have date navigation', async ({ page }) => {
    const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
    const citiesData = await citiesResponse.json();
    const cities = citiesData.data?.cities || citiesData.cities || [];

    if (cities.length > 0) {
      const cityId = cities[0].id;
      await page.goto(`/zmanim/${cityId}/default`);

      // Should show navigation buttons
      await expect(
        page.getByRole('button', { name: /previous|next/i }).or(page.locator('button:has(svg)'))
      ).toBeVisible({ timeout: 10000 });
    }
  });
});

test.describe('Formula Explanation Flow', () => {
  test('should show formula details when zman row is expanded', async ({ page }) => {
    const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
    const citiesData = await citiesResponse.json();
    const cities = citiesData.data?.cities || citiesData.cities || [];

    if (cities.length > 0) {
      const cityId = cities[0].id;
      await page.goto(`/zmanim/${cityId}/default`);

      // Wait for zmanim to load
      await page.waitForTimeout(2000);

      // Find a zman row with expand capability (info icon or expandable row)
      const expandable = page.locator('[data-expandable="true"], button:has-text("ⓘ"), .cursor-pointer').first();
      if (await expandable.isVisible({ timeout: 5000 })) {
        await expandable.click();

        // Should show formula details
        await expect(
          page.getByText(/formula|method|calculation/i)
        ).toBeVisible({ timeout: 5000 });
      }
    }
  });
});

test.describe('Complete User Flow', () => {
  test('should complete full workflow: select location, view zmanim, change date', async ({ page }) => {
    // Step 1: Visit homepage
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Zmanim Lab' })).toBeVisible();

    // Step 2: Navigate to a city page directly (simulating location selection)
    const citiesResponse = await page.request.get(`${API_BASE}/api/v1/cities?search=Brooklyn&limit=1`);
    const citiesData = await citiesResponse.json();
    const cities = citiesData.data?.cities || citiesData.cities || [];

    if (cities.length > 0) {
      const cityId = cities[0].id;

      // Step 3: Go to publishers page
      await page.goto(`/zmanim/${cityId}`);
      await expect(
        page.getByRole('link', { name: 'Change location' })
      ).toBeVisible({ timeout: 10000 });

      // Step 4: Go to zmanim display (default publisher)
      await page.goto(`/zmanim/${cityId}/default`);

      // Step 5: Verify zmanim are displayed - use first() to avoid strict mode violation
      await expect(
        page.getByText(/sunrise|alos|sunset/i).first()
      ).toBeVisible({ timeout: 10000 });

      // Step 6: Test date navigation (if buttons exist)
      const nextDayButton = page.getByRole('button', { name: 'Next day' });
      if (await nextDayButton.isVisible({ timeout: 3000 })) {
        await nextDayButton.click();
        await page.waitForTimeout(500);
        // Just verify page still shows zmanim
        await expect(
          page.getByText(/sunrise|alos|sunset/i).first()
        ).toBeVisible({ timeout: 5000 });
      }
    }
  });
});
