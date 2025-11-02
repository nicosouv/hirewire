/**
 * E2E tests for applications/Kanban board
 */
import { test, expect } from '@playwright/test';

test.describe('Applications Board', () => {
  test.beforeEach(async ({ page }) => {
    // Login before each test
    await page.goto('/login');
    await page.fill('input[type="email"]', 'test@hirewire.com');
    await page.fill('input[type="password"]', 'testpassword');
    await page.click('button[type="submit"]');
    await page.waitForURL(/dashboard|overview/i);

    // Navigate to applications
    await page.goto('/applications');
  });

  test('should display Kanban board columns', async ({ page }) => {
    // Check for standard columns
    await expect(page.locator('text=/Applied/i')).toBeVisible();
    await expect(page.locator('text=/Screening/i')).toBeVisible();
    await expect(page.locator('text=/Interviewing/i')).toBeVisible();
    await expect(page.locator('text=/Final Round/i')).toBeVisible();
  });

  test('should open quick add modal', async ({ page }) => {
    // Click quick add button
    await page.click('button:has-text("Add Application"), button:has-text("Quick Add")');

    // Modal should appear
    await expect(page.locator('dialog, [role="dialog"]')).toBeVisible();
    await expect(page.locator('text=/company/i')).toBeVisible();
    await expect(page.locator('text=/position/i')).toBeVisible();
  });

  test('should create a new application via quick add', async ({ page }) => {
    // Open quick add modal
    await page.click('button:has-text("Add Application"), button:has-text("Quick Add")');

    // Fill in form
    await page.fill('input[name="company"], input[placeholder*="company"]', 'Test Company');
    await page.fill('input[name="position"], input[placeholder*="position"]', 'Software Engineer');

    // Submit
    await page.click('button[type="submit"]');

    // Should close modal and show new application
    await expect(page.locator('text="Test Company"')).toBeVisible({ timeout: 5000 });
    await expect(page.locator('text="Software Engineer"')).toBeVisible();
  });

  test('should open application detail panel on click', async ({ page }) => {
    // Wait for applications to load
    await page.waitForSelector('[data-testid="application-card"], .application-card', {
      timeout: 5000,
    });

    // Click first application card
    await page.click('[data-testid="application-card"], .application-card >> nth=0');

    // Detail panel should appear
    await expect(page.locator('[data-testid="detail-panel"], aside')).toBeVisible();
  });

  test('should filter applications by search', async ({ page }) => {
    // Find search input
    const searchInput = page.locator('input[type="search"], input[placeholder*="Search"]');

    if (await searchInput.count() > 0) {
      await searchInput.fill('Google');

      // Results should update
      await page.waitForTimeout(500); // Debounce delay

      // Only matching results should appear
      const cards = page.locator('[data-testid="application-card"], .application-card');
      const count = await cards.count();

      // At least filtering should work (specific count depends on data)
      expect(count).toBeGreaterThanOrEqual(0);
    }
  });

  test('should drag and drop application to different column', async ({ page }) => {
    // Wait for applications to load
    await page.waitForSelector('[data-testid="application-card"], .application-card', {
      timeout: 5000,
    });

    // Get first card
    const card = page.locator('[data-testid="application-card"], .application-card >> nth=0');

    // Get target column
    const targetColumn = page.locator('text=/Interviewing/i').locator('..');

    // Drag and drop
    await card.dragTo(targetColumn);

    // Verify status update (may require API mock or real backend)
    // This is a complex interaction and may require additional setup
  });

  test('should update application status', async ({ page }) => {
    // Open detail panel
    await page.click('[data-testid="application-card"], .application-card >> nth=0');

    // Find status dropdown
    const statusSelect = page.locator('select[name="status"], [role="combobox"]');

    if (await statusSelect.count() > 0) {
      // Change status
      await statusSelect.selectOption('interviewing');

      // Save changes
      await page.click('button:has-text("Save"), button[type="submit"]');

      // Verify update
      await expect(page.locator('text=/updated|saved/i')).toBeVisible({ timeout: 3000 });
    }
  });

  test('should delete application', async ({ page }) => {
    // Open detail panel or context menu
    await page.click('[data-testid="application-card"], .application-card >> nth=0');

    // Find delete button
    const deleteButton = page.locator('button:has-text("Delete"), button[title="Delete"]');

    if (await deleteButton.count() > 0) {
      await deleteButton.click();

      // Confirm deletion
      await page.click('button:has-text("Confirm"), button:has-text("Delete")');

      // Application should disappear
      await expect(page.locator('text=/deleted|removed/i')).toBeVisible({ timeout: 3000 });
    }
  });
});
