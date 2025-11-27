/**
 * E2E Tests: Admin Publisher Management
 *
 * Tests for publisher management functionality including:
 * - Listing publishers
 * - Creating publishers
 * - Viewing publisher details
 * - Status changes (verify, suspend, reactivate)
 * - Inviting users to publishers
 */

import { test, expect } from '@playwright/test';
import {
  loginAsAdmin,
  createTestPublisherEntity,
  cleanupTestData,
  BASE_URL,
} from '../utils';

test.describe('Admin Publisher Management', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
  });

  test('admin can view publishers list', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers`);
    await page.waitForLoadState('networkidle');

    // Should see page title
    await expect(page.getByRole('heading', { name: 'Publisher Management' })).toBeVisible();

    // Should see publishers table
    await expect(page.getByText('Publishers')).toBeVisible();
  });

  test('publishers list shows table headers', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers`);
    await page.waitForLoadState('networkidle');

    // Should see table headers
    await expect(page.getByText('Name')).toBeVisible();
    await expect(page.getByText('Organization')).toBeVisible();
    await expect(page.getByText('Email')).toBeVisible();
    await expect(page.getByText('Status')).toBeVisible();
  });

  test('admin can filter publishers by status', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers`);
    await page.waitForLoadState('networkidle');

    // Find status filter dropdown
    const statusFilter = page.locator('select');
    await expect(statusFilter).toBeVisible();

    // Filter should have options
    await expect(statusFilter.locator('option')).toHaveCount(4); // all, pending, verified, suspended
  });

  test('admin can search publishers', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers`);
    await page.waitForLoadState('networkidle');

    // Find search input
    const searchInput = page.locator('input[placeholder*="Search"]');
    await expect(searchInput).toBeVisible();

    // Type in search
    await searchInput.fill('test');
    await page.waitForTimeout(500);

    // Search should filter results (content depends on data)
  });

  test('admin can access create publisher page', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers`);
    await page.waitForLoadState('networkidle');

    // Click create button
    await page.getByRole('link', { name: 'Create New Publisher' }).click();

    await page.waitForURL('**/admin/publishers/new');
    expect(page.url()).toContain('/admin/publishers/new');
  });

  test('create publisher form has required fields', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/new`);
    await page.waitForLoadState('networkidle');

    // Should see form fields
    await expect(page.getByLabel(/name/i)).toBeVisible();
    await expect(page.getByLabel(/organization/i)).toBeVisible();
    await expect(page.getByLabel(/email/i)).toBeVisible();
  });
});

test.describe('Admin Publisher Details', () => {
  let testPublisher: { id: string; name: string };

  test.beforeAll(async () => {
    // Create a test publisher for detail tests
    testPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Publisher_Details',
      organization: 'TEST_E2E_Org_Details',
    });
  });

  test.afterAll(async () => {
    // Cleanup test data
    await cleanupTestData();
  });

  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
  });

  test('admin can view publisher details', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Should see publisher name
    await expect(page.getByRole('heading', { name: testPublisher.name })).toBeVisible();

    // Should see publisher details card
    await expect(page.getByText('Publisher Details')).toBeVisible();
  });

  test('publisher details shows Quick Actions section', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    await expect(page.getByText('Quick Actions')).toBeVisible();
  });

  test('publisher details has impersonation button', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    await expect(page.getByRole('button', { name: /impersonate/i })).toBeVisible();
  });

  test('publisher details shows Users section', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    await expect(page.getByText('Users')).toBeVisible();
  });

  test('admin can open invite user dialog', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Click invite user button
    await page.getByRole('button', { name: 'Invite User' }).click();

    // Should see dialog
    await expect(page.getByText('Invite User to Publisher')).toBeVisible();
    await expect(page.getByPlaceholder('user@example.com')).toBeVisible();
  });

  test('admin can open edit publisher dialog', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Click edit button
    await page.getByRole('button', { name: 'Edit' }).click();

    // Should see edit dialog
    await expect(page.getByText('Edit Publisher')).toBeVisible();
  });

  test('admin sees delete publisher option', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/publishers/${testPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Should see delete button
    await expect(page.getByRole('button', { name: 'Delete' })).toBeVisible();
  });
});

test.describe('Admin Publisher Status Changes', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
  });

  test('pending publisher shows verify button', async ({ page }) => {
    // Create a pending publisher
    const pendingPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Pending_Publisher',
      status: 'pending',
    });

    await page.goto(`${BASE_URL}/admin/publishers/${pendingPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Should see verify button
    await expect(page.getByRole('button', { name: /verify/i })).toBeVisible();

    // Cleanup
    await cleanupTestData();
  });

  test('verified publisher shows suspend button', async ({ page }) => {
    // Create a verified publisher
    const verifiedPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Verified_Publisher',
      status: 'verified',
    });

    await page.goto(`${BASE_URL}/admin/publishers/${verifiedPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Should see suspend button
    await expect(page.getByRole('button', { name: /suspend/i })).toBeVisible();

    // Cleanup
    await cleanupTestData();
  });

  test('suspended publisher shows reactivate button', async ({ page }) => {
    // Create a suspended publisher
    const suspendedPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Suspended_Publisher',
      status: 'suspended',
    });

    await page.goto(`${BASE_URL}/admin/publishers/${suspendedPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Should see reactivate button
    await expect(page.getByRole('button', { name: /reactivate/i })).toBeVisible();

    // Cleanup
    await cleanupTestData();
  });

  test('admin can verify a pending publisher', async ({ page }) => {
    // Create a pending publisher
    const pendingPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_ToVerify_Publisher',
      status: 'pending_verification',
    });

    await page.goto(`${BASE_URL}/admin/publishers/${pendingPublisher.id}`);
    await page.waitForLoadState('networkidle');

    // Click verify button
    await page.getByRole('button', { name: /verify/i }).click();

    // Wait for status to update
    await page.waitForTimeout(1000);

    // Status should now show verified
    await expect(page.getByText('verified')).toBeVisible();

    // Cleanup
    await cleanupTestData();
  });
});
