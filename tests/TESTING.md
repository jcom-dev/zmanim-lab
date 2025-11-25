# Zmanim Lab Testing Guide

This guide covers how to run, write, and maintain tests for Zmanim Lab.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [Playwright MCP Integration](#playwright-mcp-integration)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)

---

## Overview

Zmanim Lab uses **Playwright** for end-to-end (E2E) testing. The test infrastructure supports:

- **Standard Playwright tests** - Run via CLI or VS Code extension
- **Playwright MCP** - AI-assisted testing via Model Context Protocol
- **Multiple browsers** - Chromium (default) + mobile viewports
- **Visual regression** - Screenshots on failure
- **Trace recording** - Debug failed tests with full trace

### Test Types

| Type | Location | Purpose |
|------|----------|---------|
| E2E Tests | `tests/e2e/*.spec.ts` | Full user flow testing |
| Legacy POC Tests | `web/tests/*.spec.ts` | Original POC tests (deprecated) |

---

## Quick Start

### Prerequisites

1. **Node.js 20+** installed
2. **Application running** on `http://localhost:3001` (web) and `http://localhost:8080` (API)

### Install Dependencies

```bash
cd tests
npm install

# Install Playwright browsers (first time only)
npx playwright install chromium
```

### Run All Tests

```bash
cd tests
npx playwright test
```

### Run Tests in UI Mode

```bash
npx playwright test --ui
```

---

## Test Structure

```
tests/
├── playwright.config.ts      # Playwright configuration
├── package.json              # Test dependencies
├── e2e/                      # E2E test specs
│   ├── home.spec.ts          # Home page tests
│   ├── auth.spec.ts          # Authentication tests
│   └── helpers/              # Test utilities
│       └── mcp-playwright.ts # MCP helper functions
└── test-results/             # Test output (gitignored)
    ├── html-report/          # HTML test report
    ├── results.json          # JSON results
    └── artifacts/            # Screenshots, videos, traces
```

---

## Running Tests

### Command Reference

| Command | Description |
|---------|-------------|
| `npx playwright test` | Run all tests |
| `npx playwright test home.spec.ts` | Run specific test file |
| `npx playwright test --grep "sign-in"` | Run tests matching pattern |
| `npx playwright test --ui` | Open interactive UI mode |
| `npx playwright test --headed` | Run with visible browser |
| `npx playwright test --debug` | Debug mode with inspector |
| `npx playwright test --project=chromium` | Run on specific browser |
| `npx playwright test --project=mobile-chrome` | Run mobile tests |
| `npx playwright show-report` | Open HTML report |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_URL` | `http://localhost:3001` | Application URL |
| `CI` | - | Set in CI environments |
| `PLAYWRIGHT_MCP` | - | Set when using MCP server |

### Running with Application

**Option 1: Start app manually (recommended for development)**

```bash
# Terminal 1: Start web app
cd web && npm run dev

# Terminal 2: Start API
cd api && go run ./cmd/api

# Terminal 3: Run tests
cd tests && npx playwright test
```

**Option 2: Let Playwright start the app**

```bash
cd tests
npx playwright test
# Playwright will automatically start the web server
```

**Option 3: Using Coder environment**

```bash
# Services already running via tmux
cd tests && npx playwright test
```

---

## Writing Tests

### Test File Structure

Create new test files in `tests/e2e/` with the `.spec.ts` extension:

```typescript
import { test, expect } from '@playwright/test';
import { pages, selectors, TIMEOUTS } from './helpers/mcp-playwright';

test.describe('Feature Name', () => {
  test.beforeEach(async ({ page }) => {
    // Setup before each test
    await page.goto(pages.home);
    await page.waitForLoadState('networkidle');
  });

  test('should do something', async ({ page }) => {
    // Test implementation
    await expect(page.locator('h1')).toBeVisible();
  });
});
```

### Using MCP Helpers

The `helpers/mcp-playwright.ts` module provides:

```typescript
import { pages, selectors, TIMEOUTS, testData } from './helpers/mcp-playwright';

// Pre-defined page URLs
await page.goto(pages.home);        // http://localhost:3001/
await page.goto(pages.signIn);      // http://localhost:3001/sign-in
await page.goto(pages.publisher);   // http://localhost:3001/publisher/dashboard

// Common selectors
const heading = page.getByText(selectors.home.title);

// Timeouts
await expect(element).toBeVisible({ timeout: TIMEOUTS.MEDIUM });

// Test data generators
const email = testData.randomEmail(); // test-1234567890-abc@example.com
```

### Best Practices

1. **Use semantic locators**
   ```typescript
   // Good - resilient to UI changes
   page.getByRole('button', { name: 'Sign In' })
   page.getByLabel('Email')
   page.getByText('Welcome')

   // Avoid - brittle selectors
   page.locator('.btn-primary')
   page.locator('#submit-btn')
   ```

2. **Wait for network idle**
   ```typescript
   await page.waitForLoadState('networkidle');
   ```

3. **Use test isolation**
   ```typescript
   test.beforeEach(async ({ page }) => {
     await page.goto('/');
   });
   ```

4. **Add descriptive test names**
   ```typescript
   test('should redirect to sign-in when accessing protected route without auth', ...);
   ```

5. **Group related tests**
   ```typescript
   test.describe('Authentication', () => {
     test.describe('Sign In', () => { ... });
     test.describe('Sign Up', () => { ... });
   });
   ```

### Adding New Test Files

1. Create file in `tests/e2e/` with `.spec.ts` extension
2. Import test utilities:
   ```typescript
   import { test, expect } from '@playwright/test';
   import { pages, TIMEOUTS } from './helpers/mcp-playwright';
   ```
3. Write tests following the patterns above
4. Run to verify: `npx playwright test your-new-file.spec.ts`

---

## Playwright MCP Integration

Zmanim Lab supports AI-assisted testing via the Playwright MCP server.

### What is Playwright MCP?

The Model Context Protocol (MCP) allows AI assistants (like Claude) to interact with Playwright directly, enabling:

- AI-driven test exploration
- Automated test generation
- Visual debugging with snapshots
- Interactive test development

### MCP Helper Interface

The `mcp-playwright.ts` helper defines the MCP server interface:

```typescript
interface MCPPlaywrightServer {
  navigate: (url: string) => Promise<void>;
  snapshot: () => Promise<string>;
  click: (element: string, ref: string) => Promise<void>;
  type: (element: string, ref: string, text: string, submit?: boolean) => Promise<void>;
  screenshot: (options?: ScreenshotOptions) => Promise<string>;
  waitFor: (options: WaitForOptions) => Promise<void>;
  close: () => Promise<void>;
}
```

### Using with Claude Code

When using Claude Code with Playwright MCP server:

1. The MCP server manages browser instances
2. Use `PLAYWRIGHT_MCP=true` to skip webServer config
3. Claude can run tests and capture snapshots interactively

Example workflow:
```
User: "Test the sign-in flow"
Claude: [Uses MCP to navigate, fill forms, and verify results]
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: E2E Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: |
          cd tests
          npm ci
          npx playwright install --with-deps chromium

      - name: Start application
        run: |
          cd web && npm ci && npm run build && npm start &
          cd api && go run ./cmd/api &
          sleep 10

      - name: Run tests
        run: |
          cd tests
          npx playwright test
        env:
          CI: true
          BASE_URL: http://localhost:3001

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: tests/test-results/
```

---

## Troubleshooting

### Common Issues

**Tests timeout waiting for server**

```bash
# Ensure app is running first
curl http://localhost:3001  # Should return HTML
curl http://localhost:8080/health  # Should return OK
```

**Browser not found**

```bash
cd tests
npx playwright install chromium
```

**Tests pass locally but fail in CI**

- Check `CI=true` environment variable
- Verify all services are fully started before tests run
- Increase timeouts if needed

**Element not found**

```typescript
// Add explicit wait
await page.waitForSelector('button:has-text("Submit")');

// Or use Playwright's auto-waiting with expect
await expect(page.getByRole('button', { name: 'Submit' })).toBeVisible();
```

### Debug Mode

```bash
# Run with debugger
npx playwright test --debug

# Run headed (visible browser)
npx playwright test --headed

# Generate trace for all tests
npx playwright test --trace on
```

### View Test Report

```bash
npx playwright show-report test-results/html-report
```

---

## Test Coverage by Feature

| Feature | Test File | Status |
|---------|-----------|--------|
| Home Page | `home.spec.ts` | ✅ Complete |
| Authentication | `auth.spec.ts` | ✅ Complete |
| Publisher Dashboard | - | ⏳ Pending |
| Algorithm Editor | - | ⏳ Pending |
| Zmanim Display | - | ⏳ Pending |
| Formula Reveal | - | ⏳ Pending |
| Admin Portal | - | ⏳ Pending |

---

## Resources

- [Playwright Documentation](https://playwright.dev/docs/intro)
- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
- [Playwright MCP](https://github.com/anthropics/anthropic-mcp/tree/main/playwright)
- [Locator API](https://playwright.dev/docs/locators)
- [Assertions](https://playwright.dev/docs/test-assertions)
