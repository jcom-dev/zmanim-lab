/**
 * E2E Tests: Admin Dashboard
 *
 * Tests for admin dashboard functionality including:
 * - Dashboard access and display
 * - Statistics rendering
 * - Navigation to other admin pages
 */

import { test, expect } from '@playwright/test';
import { loginAsAdmin, BASE_URL, TIMEOUTS } from '../utils';

test.describe('Admin Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
  });

  test('admin can access dashboard and see welcome message', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin`);
    await page.waitForLoadState('networkidle');

    // Should see welcome message
    await expect(page.getByText('Welcome to Admin Portal')).toBeVisible();

    // Should see admin sections
    await expect(page.getByText('Publisher Management')).toBeVisible();
    await expect(page.getByText('Dashboard')).toBeVisible();
    await expect(page.getByText('System Settings')).toBeVisible();
  });

  test('admin can navigate to dashboard stats page', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/dashboard`);
    await page.waitForLoadState('networkidle');

    // Should see dashboard title
    await expect(page.getByRole('heading', { name: 'Admin Dashboard' })).toBeVisible();

    // Should see statistics sections
    await expect(page.getByText('Publisher Statistics')).toBeVisible();
  });

  test('dashboard shows publisher statistics cards', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/dashboard`);
    await page.waitForLoadState('networkidle');

    // Wait for stats to load
    await page.waitForTimeout(1000);

    // Should see stat cards
    await expect(page.getByText('Total Publishers')).toBeVisible();
    await expect(page.getByText('Active Publishers')).toBeVisible();
    await expect(page.getByText('Pending Approval')).toBeVisible();
  });

  test('dashboard has quick action links', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/dashboard`);
    await page.waitForLoadState('networkidle');

    // Should see quick actions section
    await expect(page.getByText('Quick Actions')).toBeVisible();

    // Should have links to other admin pages
    await expect(page.getByText('Manage Publishers')).toBeVisible();
    await expect(page.getByText('Create Publisher')).toBeVisible();
    await expect(page.getByText('System Settings')).toBeVisible();
  });

  test('can refresh dashboard statistics', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin/dashboard`);
    await page.waitForLoadState('networkidle');

    // Find and click refresh button
    const refreshButton = page.getByRole('button', { name: /refresh/i });
    await expect(refreshButton).toBeVisible();

    await refreshButton.click();

    // Button should show loading state or stats should update
    // Wait for refresh to complete
    await page.waitForTimeout(1000);

    // Stats should still be visible after refresh
    await expect(page.getByText('Total Publishers')).toBeVisible();
  });

  test('admin portal shows pending requests banner', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin`);
    await page.waitForLoadState('networkidle');

    // Should see pending requests banner
    await expect(page.getByText('Pending Publisher Requests')).toBeVisible();
  });

  test('admin can navigate from portal to publisher management', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin`);
    await page.waitForLoadState('networkidle');

    // Click on Publisher Management card
    await page.getByText('Publisher Management').click();

    await page.waitForURL('**/admin/publishers');
    expect(page.url()).toContain('/admin/publishers');
  });

  test('admin can navigate from portal to create publisher', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin`);
    await page.waitForLoadState('networkidle');

    // Click on Create Publisher card
    await page.getByText('Create Publisher').click();

    await page.waitForURL('**/admin/publishers/new');
    expect(page.url()).toContain('/admin/publishers/new');
  });

  test('admin can navigate from portal to system settings', async ({ page }) => {
    await page.goto(`${BASE_URL}/admin`);
    await page.waitForLoadState('networkidle');

    // Click on System Settings card
    await page.getByText('System Settings').click();

    await page.waitForURL('**/admin/settings');
    expect(page.url()).toContain('/admin/settings');
  });
});
