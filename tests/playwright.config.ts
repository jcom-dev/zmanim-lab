import { defineConfig, devices } from '@playwright/test';
import * as path from 'path';

/**
 * Playwright Configuration for Zmanim Lab E2E Tests
 *
 * This configuration is designed to work with:
 * - Local development (npm run dev in web/)
 * - Coder cloud development environment
 * - CI/CD pipelines
 * - Playwright MCP server for AI-assisted testing
 *
 * Features:
 * - Global setup/teardown for test user management
 * - Authentication setup projects (sign in ONCE, reuse storage state)
 * - Clerk auth helpers for authenticated testing
 * - Database fixtures for test data
 *
 * AUTHENTICATION STRATEGY:
 * To avoid Clerk rate limits (5 sign-ins per 10 seconds), we use:
 * 1. Setup projects that sign in ONCE per role
 * 2. Storage state files that persist authentication
 * 3. Tests reuse the storage state instead of signing in
 *
 * @see https://playwright.dev/docs/test-configuration
 * @see https://playwright.dev/docs/auth
 */

// Base URL from environment or default to local dev
const baseURL = process.env.BASE_URL || 'http://localhost:3001';

// Storage state file paths for authenticated sessions
const ADMIN_STORAGE_STATE = 'test-results/.auth/admin.json';
const PUBLISHER_STORAGE_STATE = 'test-results/.auth/publisher.json';

export default defineConfig({
  // Global setup - runs once before all tests
  globalSetup: path.resolve(__dirname, './e2e/setup/global-setup.ts'),

  // Global teardown - runs once after all tests (cleanup)
  globalTeardown: path.resolve(__dirname, './e2e/setup/global-teardown.ts'),

  // Test directory
  testDir: './e2e',

  // Run tests in parallel (significantly speeds up test execution)
  fullyParallel: true,

  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,

  // Retry on CI only
  retries: process.env.CI ? 2 : 0,

  // Number of parallel workers
  // - CI: 4 workers for parallel execution
  // - Local: Use 50% of CPUs for balance between speed and system responsiveness
  workers: process.env.CI ? 4 : '50%',

  // Reporter to use
  reporter: [
    ['list'],
    ['html', { outputFolder: './test-results/html-report' }],
    ['json', { outputFile: './test-results/results.json' }],
  ],

  // Shared settings for all projects
  use: {
    // Base URL for all tests
    baseURL,

    // Collect trace when retrying the failed test
    trace: 'on-first-retry',

    // Capture screenshot on failure
    screenshot: 'only-on-failure',

    // Record video on failure
    video: 'on-first-retry',

    // Default timeout for actions (increased for Clerk sign-in)
    actionTimeout: 30000,

    // Default navigation timeout (increased for slow loads)
    navigationTimeout: 60000,
  },

  // Configure projects with authentication setup
  // The setup projects run FIRST and create storage state files
  // The test projects then REUSE those files (no sign-in per test)
  projects: [
    // ========================================
    // SETUP PROJECTS - Run first to create auth state
    // ========================================
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },

    // ========================================
    // TEST PROJECTS - Use pre-authenticated state
    // ========================================

    // Chromium tests with admin auth
    {
      name: 'chromium-admin',
      use: {
        ...devices['Desktop Chrome'],
        storageState: ADMIN_STORAGE_STATE,
      },
      dependencies: ['setup'],
      testMatch: /.*\/admin\/.*\.spec\.ts/,
    },

    // Chromium tests with publisher auth
    {
      name: 'chromium-publisher',
      use: {
        ...devices['Desktop Chrome'],
        storageState: PUBLISHER_STORAGE_STATE,
      },
      dependencies: ['setup'],
      testMatch: /.*\/publisher\/.*\.spec\.ts/,
    },

    // Chromium tests without auth (public pages, auth flows)
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
      dependencies: ['setup'],
      testIgnore: [
        /.*\/admin\/.*\.spec\.ts/,
        /.*\/publisher\/.*\.spec\.ts/,
        /.*\.setup\.ts/,
      ],
    },

    // Mobile tests with publisher auth
    {
      name: 'mobile-chrome-publisher',
      use: {
        ...devices['Pixel 5'],
        storageState: PUBLISHER_STORAGE_STATE,
      },
      dependencies: ['setup'],
      testMatch: /.*\/publisher\/.*\.spec\.ts/,
    },

    // Mobile tests with admin auth
    {
      name: 'mobile-chrome-admin',
      use: {
        ...devices['Pixel 5'],
        storageState: ADMIN_STORAGE_STATE,
      },
      dependencies: ['setup'],
      testMatch: /.*\/admin\/.*\.spec\.ts/,
    },

    // Mobile tests without auth
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
      dependencies: ['setup'],
      testIgnore: [
        /.*\/admin\/.*\.spec\.ts/,
        /.*\/publisher\/.*\.spec\.ts/,
        /.*\.setup\.ts/,
      ],
    },
  ],

  // Output folder for test artifacts
  outputDir: './test-results/artifacts',

  // Run local dev server before starting the tests (disabled when using MCP)
  // The MCP server manages browser instances separately
  webServer: process.env.PLAYWRIGHT_MCP
    ? undefined
    : {
        command: 'cd ../web && npm run dev',
        url: baseURL,
        reuseExistingServer: !process.env.CI,
        timeout: 120000,
      },

  // Global timeout for each test (increased for Clerk auth flows)
  timeout: 120000,

  // Expect timeout (increased for dynamic content)
  expect: {
    timeout: 30000,
  },
});
