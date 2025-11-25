import { test, expect } from '@playwright/test';

test.describe('Zmanim Lab Homepage', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should visit the homepage and display main elements', async ({ page }) => {
    // Check hero section
    await expect(page.getByRole('heading', { name: 'Alos Hashachar' })).toBeVisible();
    await expect(page.getByText('Dawn time calculated at 16.1° below the horizon')).toBeVisible();

    // Check main sections are present
    await expect(page.getByRole('heading', { name: 'Location' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Date' })).toBeVisible();
  });

  test('should display default location inputs with Jerusalem coordinates', async ({ page }) => {
    // Check latitude and longitude inputs have default values
    const latitudeInput = page.locator('#latitude');
    const longitudeInput = page.locator('#longitude');

    await expect(latitudeInput).toHaveValue('31.7683');
    await expect(longitudeInput).toHaveValue('35.2137');
  });

  test('should display date picker with today\'s date', async ({ page }) => {
    const dateInput = page.locator('#date');

    // Check that date input exists and has a value
    await expect(dateInput).toBeVisible();
    const dateValue = await dateInput.inputValue();
    expect(dateValue).toBeTruthy();
  });

  test('should display zmanim calculation results', async ({ page }) => {
    // Wait for calculations to complete
    await expect(page.getByText('Calculating times...')).toBeHidden({ timeout: 10000 });

    // Check that results section is visible
    await expect(page.getByRole('heading', { name: 'Zmanim Calculations' })).toBeVisible();

    // Check that key zmanim are displayed in the table
    const table = page.getByRole('table');
    await expect(table.getByText('Sunrise (Netz)')).toBeVisible();
    await expect(table.getByText('Alos Hashachar')).toBeVisible();
    await expect(table.getByText('Sunset (Shkiah)')).toBeVisible();
    await expect(table.getByText('Sof Zman Shema')).toBeVisible();
    await expect(table.getByText('Sof Zman Tefillah')).toBeVisible();
    await expect(table.getByText('Chatzos Hayom')).toBeVisible();
    await expect(table.getByText('Tzeis Hakochavim')).toBeVisible();
  });
});

test.describe('Location Input Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should update location when coordinates are changed', async ({ page }) => {
    // Fill in New York coordinates
    await page.locator('#latitude').fill('40.7128');
    await page.locator('#longitude').fill('-74.0060');

    // Click Update Location button
    await page.getByRole('button', { name: 'Update Location' }).click();

    // Wait for recalculation
    await page.waitForTimeout(1000);

    // Verify location is shown in footer
    await expect(page.getByText('40.7128°, -74.0060°')).toBeVisible();
  });

  test('should show error for invalid coordinates', async ({ page }) => {
    // Fill in invalid coordinates (latitude out of range)
    await page.locator('#latitude').fill('100');
    await page.locator('#longitude').fill('0');

    // Click Update Location button
    await page.getByRole('button', { name: 'Update Location' }).click();

    // Check for error message
    await expect(page.getByText('Latitude must be between -90 and 90 degrees')).toBeVisible();
  });
});

test.describe('Date Picker Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should update date when date is changed', async ({ page }) => {
    // Select a specific date
    await page.locator('#date').fill('2024-06-21');

    // Wait for recalculation
    await page.waitForTimeout(1000);

    // Check that the formatted date is displayed
    await expect(page.getByText(/Friday, June 21, 2024/i)).toBeVisible();
  });

  test('should reset to today when Today button is clicked', async ({ page }) => {
    // First change to a different date
    await page.locator('#date').fill('2024-01-01');
    await page.waitForTimeout(500);

    // Click Today button
    await page.getByRole('button', { name: 'Today' }).click();

    // Get today's date
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    const todayString = `${year}-${month}-${day}`;

    // Check that date input has today's date
    await expect(page.locator('#date')).toHaveValue(todayString);
  });
});

test.describe('Calculation Methods Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for initial calculations
    await expect(page.getByText('Calculating times...')).toBeHidden({ timeout: 10000 });
  });

  test('should change sunrise calculation method', async ({ page }) => {
    // Find sunrise method dropdown
    const sunriseSelect = page.locator('select').filter({ hasText: 'Elevation-Adjusted' }).first();

    // Change to sea-level
    await sunriseSelect.selectOption('sealevel');

    // Wait for recalculation
    await page.waitForTimeout(1000);

    // Verify the method shows in the table
    await expect(page.getByText('Sea Level')).toBeVisible();
  });

  test('should change sunset calculation method', async ({ page }) => {
    // Find sunset method dropdown (second one)
    const dropdowns = page.locator('select').filter({ hasText: 'Elevation-Adjusted' });
    const sunsetSelect = dropdowns.nth(1);

    // Change to sea-level
    await sunsetSelect.selectOption('sealevel');

    // Wait for recalculation
    await page.waitForTimeout(1000);

    // Verify sea level method is visible
    await expect(page.getByText('Sea Level')).toBeVisible();
  });

  test('should change shaah zmanis calculation method', async ({ page }) => {
    // Find shaah zmanis dropdown by its label
    const shaahZmanisSelect = page.locator('select').nth(2);

    // Change to MGA method
    await shaahZmanisSelect.selectOption('mga');

    // Wait for recalculation
    await page.waitForTimeout(1000);

    // Verify MGA method is selected
    await expect(shaahZmanisSelect).toHaveValue('mga');
  });
});

test.describe('Formula Explanation Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for initial calculations
    await expect(page.getByText('Calculating times...')).toBeHidden({ timeout: 10000 });
  });

  test('should show and hide formula explanations', async ({ page }) => {
    // Find first Explain button
    const explainButtons = page.getByRole('button', { name: 'Explain' });
    const firstExplainButton = explainButtons.first();

    // Click to expand
    await firstExplainButton.click();

    // Check that explanation is visible
    await expect(page.getByText(/How is.*calculated/i)).toBeVisible();

    // Find Hide button (the button text changes)
    const hideButton = page.getByRole('button', { name: 'Hide' }).first();

    // Click to collapse
    await hideButton.click();

    // Wait for animation
    await page.waitForTimeout(300);
  });

  test('should display detailed explanation content', async ({ page }) => {
    // Click Explain button for Alos (second row in table)
    const explainButtons = page.getByRole('button', { name: 'Explain' });
    await explainButtons.nth(1).click();

    // Verify detailed explanation content is present in the expanded section
    await expect(page.getByText(/16.1° uses the solar depression angle method/i)).toBeVisible();
  });
});

test.describe('Complete User Flow', () => {
  test('should complete full workflow: visit, change location, change date, view results', async ({ page }) => {
    // Step 1: Visit homepage
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Alos Hashachar' })).toBeVisible();

    // Step 2: Update location to London
    await page.locator('#latitude').fill('51.5074');
    await page.locator('#longitude').fill('-0.1278');
    await page.getByRole('button', { name: 'Update Location' }).click();

    // Wait for calculation
    await page.waitForTimeout(1000);

    // Step 3: Change date to summer solstice
    await page.locator('#date').fill('2024-06-21');
    await page.waitForTimeout(1000);

    // Step 4: Verify results are displayed correctly
    await expect(page.getByText('Calculating times...')).toBeHidden({ timeout: 10000 });

    // Check that location is updated
    await expect(page.getByText('51.5074°, -0.1278°')).toBeVisible();

    // Check that key zmanim are visible in the table
    const table = page.getByRole('table');
    await expect(table.getByText('Sunrise (Netz)')).toBeVisible();
    await expect(table.getByText('Alos Hashachar')).toBeVisible();
    await expect(table.getByText('Sunset (Shkiah)')).toBeVisible();

    // Step 5: Change calculation method
    const shaahZmanisSelect = page.locator('select').filter({ hasText: 'GRA' });
    await shaahZmanisSelect.selectOption('mga');
    await page.waitForTimeout(1000);

    // Step 6: Open formula explanation
    const explainButton = page.getByRole('button', { name: 'Explain' }).first();
    await explainButton.click();
    await expect(page.getByText(/How is.*calculated/i)).toBeVisible();

    // Test completed successfully
  });
});
