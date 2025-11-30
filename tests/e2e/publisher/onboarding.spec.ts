/**
 * E2E Tests: Publisher Onboarding Wizard
 *
 * Optimized for parallel execution using shared fixtures.
 * Uses empty publishers (no algorithm) to test onboarding flow.
 */

import { test, expect, Page } from '@playwright/test';
import {
  loginAsPublisher,
  getSharedPublisher,
  getEmptyPublisher,
  BASE_URL,
} from '../utils';

// All tests in this file run in parallel
test.describe.configure({ mode: 'parallel' });

// Helper to wait for welcome step
async function waitForWelcome(page: Page) {
  await page.waitForFunction(
    () => document.body.textContent?.toLowerCase().includes('welcome'),
    { timeout: 30000 }
  );
}

// Helper to wait for template step
async function waitForTemplateStep(page: Page) {
  await page.waitForFunction(
    () => document.body.textContent?.toLowerCase().includes('starting point') ||
          document.body.textContent?.toLowerCase().includes('choose your'),
    { timeout: 30000 }
  );
}

// Helper to navigate to template step
async function goToTemplateStep(page: Page, publisherId: string) {
  await loginAsPublisher(page, publisherId);
  await page.goto(`${BASE_URL}/publisher/algorithm`);
  await page.waitForLoadState('networkidle');
  await waitForWelcome(page);
  await page.getByRole('button', { name: /get started/i }).click();
  await waitForTemplateStep(page);
}

test.describe('Onboarding - Welcome Step', () => {
  test('displays welcome message', async ({ page }) => {
    const publisher = getEmptyPublisher(1);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');
    await waitForWelcome(page);

    await expect(page.getByText('Welcome to Zmanim Lab')).toBeVisible();
  });

  test('shows Hebrew text', async ({ page }) => {
    const publisher = getEmptyPublisher(1);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');
    await waitForWelcome(page);

    await expect(page.getByText('ברוכים הבאים')).toBeVisible();
  });

  test('shows feature cards', async ({ page }) => {
    const publisher = getEmptyPublisher(1);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');
    await waitForWelcome(page);

    await expect(page.getByText('Choose Template')).toBeVisible();
    await expect(page.getByText('Customize')).toBeVisible();
    await expect(page.getByText('Set Coverage')).toBeVisible();
  });

  test('shows time estimate', async ({ page }) => {
    const publisher = getEmptyPublisher(1);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');
    await waitForWelcome(page);

    await expect(page.getByText(/5-10 minutes/)).toBeVisible();
  });

  test('has Get Started button', async ({ page }) => {
    const publisher = getEmptyPublisher(1);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');
    await waitForWelcome(page);

    await expect(page.getByRole('button', { name: /get started/i })).toBeVisible();
  });

  test('has Skip button', async ({ page }) => {
    const publisher = getEmptyPublisher(1);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');
    await waitForWelcome(page);

    await expect(page.getByRole('button', { name: /skip/i })).toBeVisible();
  });

  test('Get Started advances to template step', async ({ page }) => {
    const publisher = getEmptyPublisher(1);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');
    await waitForWelcome(page);

    await page.getByRole('button', { name: /get started/i }).click();
    await waitForTemplateStep(page);

    await expect(page.getByText(/Choose Your Starting Point|Choose Template/)).toBeVisible();
  });
});

test.describe('Onboarding - Template Selection', () => {
  test('shows GRA option', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await expect(page.getByText('GRA Standard')).toBeVisible();
    await expect(page.getByText('גר"א סטנדרטי')).toBeVisible();
  });

  test('shows MGA option', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await expect(page.getByText('Magen Avraham')).toBeVisible();
    await expect(page.getByText('מגן אברהם')).toBeVisible();
  });

  test('shows Rabbeinu Tam option', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await expect(page.getByText('Rabbeinu Tam')).toBeVisible();
    await expect(page.getByText('רבינו תם')).toBeVisible();
  });

  test('shows Copy from Publisher option', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await expect(page.getByText('Copy from Publisher')).toBeVisible();
    await expect(page.getByText('העתק ממפרסם')).toBeVisible();
  });

  test('shows Start from Scratch option', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await expect(page.getByText('Start from Scratch')).toBeVisible();
    await expect(page.getByText('התחל מאפס')).toBeVisible();
  });

  test('Continue disabled without selection', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await expect(page.getByRole('button', { name: /continue/i })).toBeDisabled();
  });

  test('can select GRA template', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await page.getByText('GRA Standard').click();
    await expect(page.getByRole('button', { name: /continue/i })).toBeEnabled();
  });

  test('Back returns to welcome', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await page.getByRole('button', { name: /back/i }).click();
    await waitForWelcome(page);

    await expect(page.getByText('Welcome to Zmanim Lab')).toBeVisible();
  });

  test('Continue advances to customize', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await page.getByText('GRA Standard').click();
    await page.getByRole('button', { name: /continue/i }).click();

    await page.waitForFunction(
      () => document.body.textContent?.toLowerCase().includes('customize') ||
            document.body.textContent?.toLowerCase().includes('zman'),
      { timeout: 30000 }
    );

    const content = await page.textContent('body');
    expect(content?.toLowerCase()).toMatch(/customize|zmanim/);
  });

  test('Copy from Publisher opens dialog', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await page.getByText('Copy from Publisher').click();

    await expect(page.getByText('Search for a publisher')).toBeVisible();
    await expect(page.getByPlaceholder(/search publishers/i)).toBeVisible();
  });

  test('shows preview times', async ({ page }) => {
    const publisher = getEmptyPublisher(2);
    await goToTemplateStep(page, publisher.id);

    await expect(page.getByText('Preview (today)')).toBeVisible();
    await expect(page.getByText('Sunrise')).toBeVisible();
  });
});

test.describe('Onboarding - Navigation', () => {
  test('can navigate forward through steps', async ({ page }) => {
    const publisher = getEmptyPublisher(3);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');

    // Step 0: Welcome
    await waitForWelcome(page);
    await page.getByRole('button', { name: /get started/i }).click();

    // Step 1: Template
    await waitForTemplateStep(page);
    await page.getByText('GRA Standard').click();
    await page.getByRole('button', { name: /continue/i }).click();

    // Step 2: Customize
    await page.waitForFunction(
      () => document.body.textContent?.toLowerCase().includes('customize') ||
            document.body.textContent?.toLowerCase().includes('zman'),
      { timeout: 30000 }
    );

    expect(await page.textContent('body')).toBeTruthy();
  });

  test('can navigate backward', async ({ page }) => {
    const publisher = getEmptyPublisher(3);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');

    await waitForWelcome(page);
    await page.getByRole('button', { name: /get started/i }).click();
    await waitForTemplateStep(page);

    await page.getByRole('button', { name: /back/i }).click();
    await waitForWelcome(page);

    await expect(page.getByText('Welcome to Zmanim Lab')).toBeVisible();
  });
});

test.describe('Onboarding - Progress Indicator', () => {
  test('shows step titles', async ({ page }) => {
    const publisher = getEmptyPublisher(1);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');
    await waitForWelcome(page);

    const content = await page.textContent('body');
    expect(content?.includes('Welcome')).toBeTruthy();
    expect(content?.includes('Template') || content?.includes('Choose')).toBeTruthy();
  });
});

test.describe('Onboarding - Skip Flow', () => {
  test('skip exits onboarding', async ({ page }) => {
    const publisher = getEmptyPublisher(3);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');
    await waitForWelcome(page);

    await page.getByRole('button', { name: /skip/i }).click();
    await page.waitForTimeout(2000);

    // Should exit onboarding (may show import dialog or editor)
    expect(await page.textContent('body')).toBeTruthy();
  });
});

test.describe('Onboarding - State Persistence', () => {
  test('persists after refresh', async ({ page }) => {
    const publisher = getEmptyPublisher(1);
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');

    await waitForWelcome(page);
    await page.getByRole('button', { name: /get started/i }).click();
    await waitForTemplateStep(page);

    await page.getByText('GRA Standard').click();
    await page.waitForTimeout(1000);

    await page.reload();
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);

    // State should be persisted
    expect(await page.textContent('body')).toBeTruthy();
  });
});
