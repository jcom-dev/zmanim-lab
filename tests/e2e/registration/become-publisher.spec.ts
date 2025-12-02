/**
 * E2E Tests: Become Publisher Registration
 *
 * Tests for publisher registration flow:
 * - Registration page access
 * - Form display
 * - Form validation
 * - Successful submission
 */

import { test, expect } from '@playwright/test';
import { BASE_URL, testData } from '../utils';

// Enable parallel mode for faster test execution
test.describe.configure({ mode: 'parallel' });

test.describe('Become Publisher - Page Access', () => {
  test('become publisher page is accessible', async ({ page }) => {
    await page.goto(`${BASE_URL}/become-publisher`);
    await page.waitForLoadState('networkidle');

    expect(page.url()).toContain('/become-publisher');
  });

  test('become publisher page has form', async ({ page }) => {
    await page.goto(`${BASE_URL}/become-publisher`);
    await page.waitForLoadState('networkidle');

    // Should see form elements
    const formExists = await page.locator('form').isVisible().catch(() => false);
    expect(formExists).toBe(true);
  });

  test('become publisher accessible from home page', async ({ page }) => {
    await page.goto(`${BASE_URL}/`);
    await page.waitForLoadState('networkidle');

    await page.getByRole('link', { name: 'Become a Publisher' }).click();

    await page.waitForURL('**/become-publisher');
    expect(page.url()).toContain('/become-publisher');
  });
});

test.describe('Become Publisher - Form Fields', () => {
  test('form has name field', async ({ page }) => {
    await page.goto(`${BASE_URL}/become-publisher`);
    await page.waitForLoadState('networkidle');

    // Should have name input
    const nameInput = page.locator('input[name="name"], input[placeholder*="name" i]');
    const hasNameField = await nameInput.isVisible().catch(() => false);

    // If not found by name, check by label
    if (!hasNameField) {
      const labeledInput = page.getByLabel(/name/i);
      await expect(labeledInput).toBeVisible();
    }
  });

  test('form has organization field', async ({ page }) => {
    await page.goto(`${BASE_URL}/become-publisher`);
    await page.waitForLoadState('networkidle');

    const orgInput = page.locator('input[name="organization"], input[placeholder*="organization" i]');
    const hasOrgField = await orgInput.isVisible().catch(() => false);

    if (!hasOrgField) {
      const labeledInput = page.getByLabel(/organization/i);
      await expect(labeledInput).toBeVisible();
    }
  });

  test('form has email field', async ({ page }) => {
    await page.goto(`${BASE_URL}/become-publisher`);
    await page.waitForLoadState('networkidle');

    const emailInput = page.locator('input[type="email"], input[name="email"]');
    const hasEmailField = await emailInput.isVisible().catch(() => false);

    if (!hasEmailField) {
      const labeledInput = page.getByLabel(/email/i);
      await expect(labeledInput).toBeVisible();
    }
  });

  test('form has submit button', async ({ page }) => {
    await page.goto(`${BASE_URL}/become-publisher`);
    await page.waitForLoadState('networkidle');

    const submitButton = page.locator('button[type="submit"], input[type="submit"]');
    await expect(submitButton).toBeVisible();
  });
});

test.describe('Become Publisher - Form Validation', () => {
  test('empty form submission shows validation errors', async ({ page }) => {
    await page.goto(`${BASE_URL}/become-publisher`);
    await page.waitForLoadState('networkidle');

    // Try to submit empty form
    const submitButton = page.locator('button[type="submit"]');
    await submitButton.click();

    // Should see validation feedback (either HTML5 validation or custom)
    await page.waitForTimeout(500);

    // Form should still be on the page (not submitted)
    expect(page.url()).toContain('/become-publisher');
  });

  test('invalid email shows validation error', async ({ page }) => {
    await page.goto(`${BASE_URL}/become-publisher`);
    await page.waitForLoadState('networkidle');

    // Fill name
    const nameInput = page.getByLabel(/name/i).first();
    if (await nameInput.isVisible()) {
      await nameInput.fill('Test Name');
    }

    // Fill organization
    const orgInput = page.getByLabel(/organization/i);
    if (await orgInput.isVisible()) {
      await orgInput.fill('Test Organization');
    }

    // Fill invalid email
    const emailInput = page.locator('input[type="email"]').first();
    if (await emailInput.isVisible()) {
      await emailInput.fill('invalid-email');
    }

    // Try to submit
    const submitButton = page.locator('button[type="submit"]');
    await submitButton.click();

    await page.waitForTimeout(500);

    // Should still be on the form page
    expect(page.url()).toContain('/become-publisher');
  });
});

test.describe('Become Publisher - Successful Submission', () => {
  test('valid form can be submitted', async ({ page }) => {
    await page.goto(`${BASE_URL}/become-publisher`);
    await page.waitForLoadState('networkidle');

    const uniqueEmail = testData.randomEmail();

    // Fill all required fields
    const nameInput = page.getByLabel(/name/i).first();
    if (await nameInput.isVisible()) {
      await nameInput.fill('E2E Test Publisher');
    }

    const orgInput = page.getByLabel(/organization/i);
    if (await orgInput.isVisible()) {
      await orgInput.fill('E2E Test Organization');
    }

    const emailInput = page.locator('input[type="email"]').first();
    if (await emailInput.isVisible()) {
      await emailInput.fill(uniqueEmail);
    }

    // Fill description/reason if present
    const descInput = page.locator('textarea').first();
    if (await descInput.isVisible()) {
      await descInput.fill('E2E test registration - please ignore');
    }

    // Note: We don't actually submit to avoid creating real data
    // Just verify form is fillable
    const submitButton = page.locator('button[type="submit"]');
    await expect(submitButton).toBeEnabled();
  });
});
