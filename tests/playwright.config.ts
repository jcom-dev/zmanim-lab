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
 * - Clerk auth helpers for authenticated testing
 * - Database fixtures for test data
 *
 * @see https://playwright.dev/docs/test-configuration
 */

// Base URL from environment or default to local dev
const baseURL = process.env.BASE_URL || 'http://localhost:3001';

export default defineConfig({
  // Global setup - runs once before all tests
  globalSetup: path.resolve(__dirname, './e2e/setup/global-setup.ts'),

  // Global teardown - runs once after all tests (cleanup)
  globalTeardown: path.resolve(__dirname, './e2e/setup/global-teardown.ts'),

  // Test directory
  testDir: './e2e',

  // Run tests in parallel
  fullyParallel: true,

  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,

  // Retry on CI only
  retries: process.env.CI ? 2 : 0,

  // Opt out of parallel tests on CI
  workers: process.env.CI ? 1 : undefined,

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

  // Configure projects for major browsers
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },

    // Uncomment for additional browser coverage
    // {
    //   name: 'firefox',
    //   use: { ...devices['Desktop Firefox'] },
    // },
    // {
    //   name: 'webkit',
    //   use: { ...devices['Desktop Safari'] },
    // },

    // Mobile viewport tests
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    },
    // {
    //   name: 'mobile-safari',
    //   use: { ...devices['iPhone 12'] },
    // },
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
