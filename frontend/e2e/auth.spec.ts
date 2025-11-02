/**
 * E2E tests for authentication flow
 */
import { test, expect } from '@playwright/test';

test.describe('Authentication', () => {
  test('should display login page', async ({ page }) => {
    await page.goto('/login');

    await expect(page.locator('h1')).toContainText(/login|sign in/i);
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('input[type="password"]')).toBeVisible();
  });

  test('should show error on invalid credentials', async ({ page }) => {
    await page.goto('/login');

    await page.fill('input[type="email"]', 'invalid@example.com');
    await page.fill('input[type="password"]', 'wrongpassword');
    await page.click('button[type="submit"]');

    // Wait for error message
    await expect(page.locator('text=/incorrect|invalid|error/i')).toBeVisible({
      timeout: 5000,
    });
  });

  test('should login successfully with valid credentials', async ({ page }) => {
    await page.goto('/login');

    // Fill in valid credentials (use test account)
    await page.fill('input[type="email"]', 'test@hirewire.com');
    await page.fill('input[type="password"]', 'testpassword');
    await page.click('button[type="submit"]');

    // Should redirect to dashboard
    await expect(page).toHaveURL(/dashboard|overview|applications/i, {
      timeout: 10000,
    });
  });

  test('should persist auth state after refresh', async ({ page, context }) => {
    // Login first
    await page.goto('/login');
    await page.fill('input[type="email"]', 'test@hirewire.com');
    await page.fill('input[type="password"]', 'testpassword');
    await page.click('button[type="submit"]');

    await page.waitForURL(/dashboard|overview/i);

    // Refresh page
    await page.reload();

    // Should still be logged in
    await expect(page).not.toHaveURL(/login/i);
  });

  test('should logout successfully', async ({ page }) => {
    // Login first
    await page.goto('/login');
    await page.fill('input[type="email"]', 'test@hirewire.com');
    await page.fill('input[type="password"]', 'testpassword');
    await page.click('button[type="submit"]');

    await page.waitForURL(/dashboard|overview/i);

    // Find and click logout button
    await page.click('button:has-text("Logout"), button:has-text("Sign out")');

    // Should redirect to login
    await expect(page).toHaveURL(/login/i, { timeout: 5000 });
  });

  test('should redirect to login when accessing protected route', async ({ page }) => {
    // Try to access protected route without auth
    await page.goto('/dashboard');

    // Should redirect to login
    await expect(page).toHaveURL(/login/i, { timeout: 5000 });
  });
});
