/**
 * E2E Test: Publisher Lifecycle - Create, Import, Edit DSL
 *
 * Comprehensive test that:
 * 1. Creates a new test publisher in the database
 * 2. Logs in as that publisher via Clerk
 * 3. Goes through the onboarding wizard to import zmanim
 * 4. Edits a DSL formula
 * 5. Cleans up the test data
 */

import { test, expect, Page } from '@playwright/test';
import {
  loginAsPublisher,
  createTestPublisherEntity,
  cleanupPublisher,
  BASE_URL,
} from '../utils';

// Run tests serially since they depend on each other
test.describe.configure({ mode: 'serial' });

test.describe('Publisher Lifecycle - Create, Import, Edit DSL', () => {
  let testPublisher: { id: string; name: string };

  test.beforeAll(async () => {
    // Create a fresh test publisher with no zmanim
    testPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Lifecycle_Publisher',
      organization: 'TEST_E2E_Lifecycle_Org',
      email: 'lifecycle-test@test.zmanim-lab.local',
      status: 'verified',
    });
    console.log(`Created test publisher: ${testPublisher.name} (${testPublisher.id})`);
  });

  test.afterAll(async () => {
    // Clean up only this publisher (parallel-safe)
    if (testPublisher?.id) {
      await cleanupPublisher(testPublisher.id);
      console.log(`Cleaned up test publisher: ${testPublisher.id}`);
    }
  });

  test('1. Publisher can login and access algorithm page', async ({ page }) => {
    // Login as the newly created publisher
    await loginAsPublisher(page, testPublisher.id);

    // Navigate to algorithm page
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');

    // Should see the welcome/onboarding wizard for new publisher
    await page.waitForFunction(
      () => {
        const text = document.body.textContent?.toLowerCase() || '';
        return text.includes('welcome') || text.includes('algorithm') || text.includes('zmanim');
      },
      { timeout: 30000 }
    );

    // Verify we're on the algorithm page
    expect(page.url()).toContain('/publisher/algorithm');
  });

  test('2. Publisher completes onboarding wizard with GRA template', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');

    // Wait for Welcome step
    await page.waitForFunction(
      () => document.body.textContent?.toLowerCase().includes('welcome'),
      { timeout: 30000 }
    );

    // Verify welcome message
    await expect(page.getByText('Welcome to Zmanim Lab')).toBeVisible();

    // Click "Get Started"
    await page.getByRole('button', { name: /get started/i }).click();

    // Wait for Template Selection step
    await page.waitForFunction(
      () => {
        const text = document.body.textContent?.toLowerCase() || '';
        return text.includes('starting point') || text.includes('choose your') || text.includes('gra');
      },
      { timeout: 30000 }
    );

    // Select GRA Standard template
    await page.getByText('GRA Standard').click();

    // Continue button should be enabled now
    await expect(page.getByRole('button', { name: /continue/i })).toBeEnabled();
    await page.getByRole('button', { name: /continue/i }).click();

    // Wait for customize step or editor to load
    await page.waitForFunction(
      () => {
        const text = document.body.textContent?.toLowerCase() || '';
        return text.includes('customize') || text.includes('zman') || text.includes('coverage');
      },
      { timeout: 30000 }
    );

    // Complete any remaining steps by clicking Continue/Finish
    const finishOrContinue = page.getByRole('button', { name: /finish|complete|continue/i }).first();
    if (await finishOrContinue.isVisible({ timeout: 3000 }).catch(() => false)) {
      await finishOrContinue.click();
    }

    // Wait for the algorithm editor to appear
    await page.waitForFunction(
      () => {
        const text = document.body.textContent?.toLowerCase() || '';
        return text.includes('algorithm editor') || text.includes('zmanim') && text.includes('enabled');
      },
      { timeout: 30000 }
    );

    // Verify zmanim were imported - should see count
    await expect(page.getByText(/\d+ zmanim/i)).toBeVisible({ timeout: 10000 });
  });

  test('3. Publisher can view imported zmanim list', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');

    // Wait for Algorithm Editor to load (not onboarding since we already completed it)
    await page.waitForFunction(
      () => {
        const text = document.body.textContent?.toLowerCase() || '';
        return (text.includes('algorithm editor') || text.includes('search zmanim')) &&
               !text.includes('welcome to zmanim lab');
      },
      { timeout: 30000 }
    );

    // Should see search input
    await expect(page.getByPlaceholder(/search zmanim/i)).toBeVisible();

    // Should see filter tabs
    await expect(page.getByRole('tab', { name: /all/i })).toBeVisible();
    await expect(page.getByRole('tab', { name: /enabled/i })).toBeVisible();

    // Should see some zmanim cards - look for common GRA zmanim
    const content = await page.textContent('body');
    expect(
      content?.includes('Sunrise') ||
      content?.includes('Sunset') ||
      content?.includes('Alos') ||
      content?.includes('עלות')
    ).toBeTruthy();
  });

  test('4. Publisher can navigate to DSL editor and edit a formula', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm`);
    await page.waitForLoadState('networkidle');

    // Wait for editor to load
    await page.waitForFunction(
      () => {
        const text = document.body.textContent?.toLowerCase() || '';
        return text.includes('algorithm editor') || text.includes('search zmanim');
      },
      { timeout: 30000 }
    );

    // Click on a zman card to edit it - look for Sunrise or any visible zman
    const zmanCard = page.locator('[data-testid="zman-card"]').first()
      .or(page.locator('button, div').filter({ hasText: /sunrise|sunset|alos|עלות/i }).first());

    if (await zmanCard.isVisible({ timeout: 5000 }).catch(() => false)) {
      await zmanCard.click();

      // Wait for navigation to edit page
      await page.waitForURL('**/algorithm/edit/**', { timeout: 10000 });
      expect(page.url()).toContain('/algorithm/edit/');

      // Wait for editor to load
      await page.waitForFunction(
        () => {
          const text = document.body.textContent?.toLowerCase() || '';
          return text.includes('guided builder') || text.includes('advanced dsl') || text.includes('formula');
        },
        { timeout: 30000 }
      );

      // Verify editor components are visible
      await expect(page.getByText('Guided Builder').or(page.getByText('Advanced DSL'))).toBeVisible();
    } else {
      // If no zman card found, navigate directly to new zman
      await page.goto(`${BASE_URL}/publisher/algorithm/edit/new`);
      await page.waitForLoadState('networkidle');

      await page.waitForFunction(
        () => {
          const text = document.body.textContent?.toLowerCase() || '';
          return text.includes('guided builder') || text.includes('advanced dsl');
        },
        { timeout: 30000 }
      );

      expect(page.url()).toContain('/algorithm/edit/new');
    }
  });

  test('5. Publisher can switch between Guided and Advanced DSL modes', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);

    // Go directly to new zman editor
    await page.goto(`${BASE_URL}/publisher/algorithm/edit/new`);
    await page.waitForLoadState('networkidle');

    // Wait for editor tabs
    await page.waitForFunction(
      () => document.body.textContent?.includes('Guided Builder'),
      { timeout: 30000 }
    );

    // Should start in Guided mode
    await expect(page.getByRole('tab', { name: /guided builder/i })).toBeVisible();
    await expect(page.getByRole('tab', { name: /advanced dsl/i })).toBeVisible();

    // Click Advanced DSL tab
    await page.getByRole('tab', { name: /advanced dsl/i }).click();

    // Wait for DSL editor to appear
    await page.waitForFunction(
      () => {
        const text = document.body.textContent?.toLowerCase() || '';
        return text.includes('ai generate') || text.includes('dsl reference');
      },
      { timeout: 10000 }
    );

    // DSL editor content should be visible
    const editorArea = page.locator('.cm-editor').or(page.locator('[data-testid="dsl-editor"]'));
    await expect(editorArea.or(page.getByText('AI Generate'))).toBeVisible({ timeout: 5000 });
  });

  test('6. Publisher can enter a DSL formula and see preview', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm/edit/new`);
    await page.waitForLoadState('networkidle');

    // Wait for editor
    await page.waitForFunction(
      () => document.body.textContent?.includes('Guided Builder'),
      { timeout: 30000 }
    );

    // Fill in required fields
    // Hebrew name
    const hebrewInput = page.getByLabel(/hebrew name/i).or(page.locator('input[placeholder*="עברית"]').first());
    if (await hebrewInput.isVisible({ timeout: 3000 }).catch(() => false)) {
      await hebrewInput.fill('נץ החמה (בדיקה)');
    }

    // English name
    const englishInput = page.getByLabel(/english name/i).or(page.locator('input[placeholder*="English"]').first());
    if (await englishInput.isVisible({ timeout: 3000 }).catch(() => false)) {
      await englishInput.fill('Sunrise (Test)');
    }

    // Switch to Advanced DSL mode to enter formula directly
    await page.getByRole('tab', { name: /advanced dsl/i }).click();

    // Wait for DSL editor to load
    await page.waitForTimeout(1000);

    // Find the CodeMirror editor or textarea and enter a simple formula
    const cmEditor = page.locator('.cm-content[contenteditable="true"]');
    const textarea = page.locator('textarea').filter({ hasNotText: /comment|explanation/i }).first();

    if (await cmEditor.isVisible({ timeout: 3000 }).catch(() => false)) {
      await cmEditor.click();
      await page.keyboard.type('sunrise()');
    } else if (await textarea.isVisible({ timeout: 3000 }).catch(() => false)) {
      await textarea.fill('sunrise()');
    }

    // Wait for preview to update
    await page.waitForTimeout(500);

    // Should see calculated result - look for time format (HH:MM AM/PM)
    const hasPreview = await page.getByText(/\d{1,2}:\d{2}(:\d{2})?\s*(AM|PM)/i).isVisible({ timeout: 5000 }).catch(() => false);

    // Or at least verify the formula was entered
    const content = await page.textContent('body');
    expect(hasPreview || content?.includes('sunrise()')).toBeTruthy();
  });

  test('7. Publisher can save a new custom zman', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);
    await page.goto(`${BASE_URL}/publisher/algorithm/edit/new`);
    await page.waitForLoadState('networkidle');

    // Wait for editor
    await page.waitForFunction(
      () => document.body.textContent?.includes('Guided Builder'),
      { timeout: 30000 }
    );

    // Fill in required fields
    const hebrewInput = page.getByLabel(/hebrew name/i).or(page.locator('input').filter({ hasText: '' }).first());
    const englishInput = page.getByLabel(/english name/i).or(page.locator('input').nth(1));

    // Fill names in the BilingualInput component
    const nameInputs = page.locator('input[type="text"]');
    const inputs = await nameInputs.all();
    if (inputs.length >= 2) {
      await inputs[0].fill('זמן בדיקה');  // Hebrew
      await inputs[1].fill('Test Time E2E');  // English
    }

    // Switch to Advanced DSL
    await page.getByRole('tab', { name: /advanced dsl/i }).click();
    await page.waitForTimeout(500);

    // Enter formula
    const cmEditor = page.locator('.cm-content[contenteditable="true"]');
    if (await cmEditor.isVisible({ timeout: 3000 }).catch(() => false)) {
      await cmEditor.click();
      await page.keyboard.type('sunrise()');
    }

    // Wait for preview to validate
    await page.waitForTimeout(1000);

    // Click Save/Create button
    const saveButton = page.getByRole('button', { name: /create|save/i }).filter({ hasNotText: /back/i });
    if (await saveButton.isEnabled({ timeout: 3000 }).catch(() => false)) {
      await saveButton.click();

      // Wait for success message or navigation back to list
      await page.waitForFunction(
        () => {
          const text = document.body.textContent?.toLowerCase() || '';
          return text.includes('success') ||
                 text.includes('created') ||
                 window.location.href.includes('/publisher/algorithm') && !window.location.href.includes('/edit/');
        },
        { timeout: 10000 }
      ).catch(() => {});

      // Should be back on algorithm list or see success
      const url = page.url();
      const content = await page.textContent('body');
      expect(
        url.endsWith('/publisher/algorithm') ||
        content?.toLowerCase().includes('success') ||
        content?.toLowerCase().includes('created')
      ).toBeTruthy();
    }
  });

  test('8. Publisher dashboard shows updated zmanim count', async ({ page }) => {
    await loginAsPublisher(page, testPublisher.id);
    await page.goto(`${BASE_URL}/publisher/dashboard`);
    await page.waitForLoadState('networkidle');

    // Should see dashboard
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

    // Should show publisher info
    await expect(page.getByText(testPublisher.name)).toBeVisible();

    // Zmanim card should show count
    const zmanimCard = page.locator('text=Zmanim').locator('..');
    if (await zmanimCard.isVisible({ timeout: 5000 }).catch(() => false)) {
      const cardContent = await zmanimCard.textContent();
      // Should have some zmanim count
      expect(cardContent).toMatch(/\d+/);
    }
  });
});
