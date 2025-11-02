# Testing Guide - HireWire

Complete guide for testing frontend and backend applications.

## Table of Contents

- [Overview](#overview)
- [Backend Testing](#backend-testing)
- [Frontend Testing](#frontend-testing)
- [E2E Testing](#e2e-testing)
- [Best Practices](#best-practices)
- [CI/CD Integration](#cicd-integration)

---

## Overview

HireWire uses a comprehensive testing strategy:

| Component | Testing Tools | Coverage |
|-----------|--------------|----------|
| **Backend** | pytest + FastAPI TestClient | API, Services, Models |
| **Frontend** | Vitest + React Testing Library | Hooks, Components |
| **E2E** | Playwright | User workflows |
| **Airflow** | pytest + DagBag | DAG structure |

### Test Pyramid

```
          /\
         /  \  E2E Tests (Playwright)
        /____\
       /      \  Integration Tests (API, DB)
      /________\
     /          \ Unit Tests (Components, Hooks, Services)
    /__________
__\
```

---

## Backend Testing

### Setup

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/api/test_companies.py

# Run specific test
pytest tests/api/test_companies.py::TestCompanyEndpoints::test_create_company
```

### Test Structure

```
backend/
├── pytest.ini              # Pytest configuration
├── tests/
│   ├── conftest.py         # Fixtures and setup
│   ├── api/                # API endpoint tests
│   │   ├── test_companies.py
│   │   ├── test_auth.py
│   │   └── test_processes.py
│   ├── services/           # Service layer tests
│   └── models/             # Model validation tests
```

### Key Fixtures

```python
# conftest.py provides:
- db: Fresh database session (in-memory SQLite)
- client: FastAPI TestClient
- test_user: Regular user
- admin_user: Admin user with Airflow access
- auth_headers: Authenticated request headers
- test_company, test_position, test_process: Sample data
```

### Writing Backend Tests

**API Endpoint Test Example:**

```python
@pytest.mark.api
def test_create_company(client: TestClient):
    """Test creating a new company"""
    response = client.post("/api/v1/companies/", json={
        "name": "New Company",
        "industry": "Finance"
    })

    assert response.status_code == 201
    assert response.json()["name"] == "New Company"
```

**Authentication Test Example:**

```python
@pytest.mark.auth
def test_protected_endpoint(client: TestClient, auth_headers: dict):
    """Test accessing protected endpoint"""
    response = client.get("/api/v1/processes", headers=auth_headers)

    assert response.status_code == 200
```

### Test Markers

- `@pytest.mark.unit` - Fast unit tests
- `@pytest.mark.integration` - Integration tests with DB
- `@pytest.mark.api` - API endpoint tests
- `@pytest.mark.auth` - Authentication tests
- `@pytest.mark.slow` - Slow running tests

```bash
# Run only unit tests
pytest -m unit

# Skip slow tests
pytest -m "not slow"
```

### Database Testing

Tests use in-memory SQLite for speed:

```python
# Each test gets fresh database
def test_company_creation(db: Session):
    company = Company(name="Test")
    db.add(company)
    db.commit()

    assert company.id is not None
```

For PostgreSQL-specific tests:
```bash
# Use docker-compose for integration tests
docker-compose up -d postgres
pytest -m integration
```

---

## Frontend Testing

### Setup

```bash
cd frontend

# Install dependencies (add to package.json devDependencies first)
npm install --save-dev vitest @testing-library/react @testing-library/jest-dom jsdom

# Run all tests
npm test

# Run tests with UI
npm run test:ui

# Run with coverage
npm run test:coverage

# Watch mode
npm test -- --watch
```

### Test Structure

```
frontend/
├── vitest.config.ts         # Vitest configuration
├── src/
│   ├── tests/
│   │   ├── setup.ts         # Test setup
│   │   ├── utils/
│   │   │   └── test-utils.tsx  # Custom render
│   │   └── mocks/
│   │       └── handlers.ts  # MSW handlers
│   ├── hooks/
│   │   └── __tests__/
│   │       └── useCompanies.test.ts
│   └── components/
│       └── __tests__/
│           └── ApplicationCard.test.tsx
```

### Writing Frontend Tests

**Hook Test Example:**

```typescript
describe('useCompanies', () => {
  it('should fetch companies', async () => {
    const { result } = renderHook(() => useCompanies(), { wrapper });

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(Array.isArray(result.current.data)).toBe(true);
  });
});
```

**Component Test Example:**

```typescript
describe('ApplicationCard', () => {
  it('should render company name', () => {
    render(
      <ApplicationCard
        process={mockProcess}
        position={mockPosition}
        company={mockCompany}
      />
    );

    expect(screen.getByText('Test Company')).toBeInTheDocument();
  });

  it('should call onClick handler', () => {
    const handleClick = vi.fn();

    render(<ApplicationCard {...props} onClick={handleClick} />);

    screen.getByRole('button').click();

    expect(handleClick).toHaveBeenCalledTimes(1);
  });
});
```

### Custom Test Utils

Use `renderWithProviders` for components needing React Query, Router, or Auth:

```typescript
import { render } from '@/tests/utils/test-utils';

// Automatically wraps with QueryClient, Router, AuthProvider
render(<MyComponent />);
```

### Mocking API Responses

MSW (Mock Service Worker) handles API mocking:

```typescript
// tests/mocks/handlers.ts
export const handlers = [
  http.get('/api/v1/companies/', () => {
    return HttpResponse.json(mockCompanies);
  }),
];
```

---

## E2E Testing

### Setup

```bash
cd frontend

# Install Playwright
npm install --save-dev @playwright/test

# Install browsers
npx playwright install

# Run E2E tests
npm run test:e2e

# Run with UI
npm run test:e2e:ui

# Run specific browser
npx playwright test --project=chromium

# Debug mode
npm run test:e2e:debug
```

### Test Structure

```
frontend/
├── playwright.config.ts     # Playwright configuration
└── e2e/
    ├── auth.spec.ts         # Authentication flows
    ├── applications.spec.ts # Kanban board
    └── dashboard.spec.ts    # Dashboard
```

### Writing E2E Tests

**Login Flow:**

```typescript
test('should login successfully', async ({ page }) => {
  await page.goto('/login');

  await page.fill('input[type="email"]', 'test@example.com');
  await page.fill('input[type="password"]', 'password');
  await page.click('button[type="submit"]');

  await expect(page).toHaveURL(/dashboard/i);
});
```

**User Interaction:**

```typescript
test('should create application', async ({ page }) => {
  await page.click('button:has-text("Add Application")');

  await page.fill('input[name="company"]', 'Google');
  await page.fill('input[name="position"]', 'Engineer');
  await page.click('button[type="submit"]');

  await expect(page.locator('text="Google"')).toBeVisible();
});
```

### E2E Best Practices

1. **Use data-testid for stable selectors**
   ```tsx
   <button data-testid="submit-btn">Submit</button>
   ```

2. **Wait for elements explicitly**
   ```typescript
   await page.waitForSelector('[data-testid="card"]');
   ```

3. **Test user flows, not implementation**
   ```typescript
   // ✅ Good - tests user behavior
   await page.click('button:has-text("Login")');

   // ❌ Bad - tests implementation details
   await page.click('.auth-form__submit-button');
   ```

4. **Use fixtures for authentication**
   ```typescript
   test.beforeEach(async ({ page }) => {
     await loginAs(page, 'test@example.com');
   });
   ```

---

## Best Practices

### General Principles

1. **Test behavior, not implementation**
   - Focus on what users see and do
   - Avoid testing internal state

2. **Follow AAA pattern**
   ```python
   def test_example():
       # Arrange
       user = create_test_user()

       # Act
       result = login(user)

       # Assert
       assert result.success is True
   ```

3. **One assertion per test** (when possible)
   - Makes failures easier to diagnose
   - Tests stay focused

4. **Use descriptive test names**
   ```python
   # ✅ Good
   def test_user_cannot_access_admin_endpoint_without_permission():
       ...

   # ❌ Bad
   def test_admin():
       ...
   ```

5. **Keep tests independent**
   - Each test should run in isolation
   - Don't rely on test execution order

### Backend Best Practices

- Use fixtures for common setup
- Mock external services (email, APIs)
- Test both success and error cases
- Validate response schemas
- Test edge cases (empty lists, null values, etc.)

### Frontend Best Practices

- Use semantic queries (`getByRole`, `getByText`)
- Avoid testing styles (focus on behavior)
- Mock API responses with MSW
- Test accessibility (ARIA roles)
- Test loading and error states

### E2E Best Practices

- Keep tests fast (avoid unnecessary waits)
- Use page objects for reusable flows
- Test critical user journeys only
- Run E2E tests in CI before deployment
- Take screenshots on failure

---

## CI/CD Integration

### GitHub Actions Workflow

Create `.github/workflows/tests.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: |
          cd backend
          pip install -r requirements.txt
          pytest --cov=app --cov-report=xml
      - uses: codecov/codecov-action@v4

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: |
          cd frontend
          npm ci
          npm test -- --coverage
      - uses: codecov/codecov-action@v4

  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: |
          cd frontend
          npm ci
          npx playwright install --with-deps
          npm run test:e2e
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: frontend/playwright-report/
```

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "Running backend tests..."
cd backend && pytest -x -q || exit 1

echo "Running frontend tests..."
cd ../frontend && npm test -- --run || exit 1

echo "✅ All tests passed!"
```

---

## Test Coverage Goals

| Component | Target Coverage |
|-----------|----------------|
| Backend API | 90%+ |
| Backend Services | 85%+ |
| Frontend Components | 80%+ |
| Frontend Hooks | 90%+ |
| E2E Critical Paths | 100% |

### Checking Coverage

```bash
# Backend
pytest --cov=app --cov-report=html
open htmlcov/index.html

# Frontend
npm run test:coverage
open coverage/index.html
```

---

## Troubleshooting

### Backend Tests Failing

**Issue**: Database connection errors
```bash
# Use in-memory SQLite (default)
pytest

# Or specify test database
export DATABASE_URL="postgresql://test:test@localhost/test_hirewire"
pytest
```

**Issue**: Import errors
```bash
# Ensure app directory is in PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:${PWD}"
pytest
```

### Frontend Tests Failing

**Issue**: Module not found
```bash
# Clear cache and reinstall
rm -rf node_modules package-lock.json
npm install
```

**Issue**: Timeout errors
```typescript
// Increase timeout for slow queries
await waitFor(() => {
  expect(result.current.isSuccess).toBe(true);
}, { timeout: 5000 });
```

### E2E Tests Failing

**Issue**: Flaky tests
```typescript
// Use explicit waits
await page.waitForSelector('[data-testid="element"]');

// Retry flaky assertions
await expect(async () => {
  const text = await page.textContent('.status');
  expect(text).toBe('Success');
}).toPass({ timeout: 5000 });
```

**Issue**: Browser not found
```bash
# Reinstall browsers
npx playwright install --with-deps
```

---

## Summary

✅ **Backend**: pytest + FastAPI TestClient (API, services, models)
✅ **Frontend**: Vitest + RTL (hooks, components)
✅ **E2E**: Playwright (user flows)
✅ **Airflow**: pytest + DagBag (DAG structure)

**Quick Start:**
```bash
# Backend
cd backend && pytest --cov=app

# Frontend
cd frontend && npm test

# E2E
cd frontend && npm run test:e2e
```

For detailed examples, see the test files in `backend/tests/`, `frontend/src/tests/`, and `frontend/e2e/`.
