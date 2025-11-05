# CI/CD Unified Testing with build.sh

## Overview

This document describes the unified testing strategy using `build.sh` as the single source of truth for both local development and CI/CD pipelines.

## Why Unify Tests?

### Problems with Duplicate Test Logic

**Before (Current State):**
- ❌ Test commands duplicated between `build.sh` and GitHub Actions workflows
- ❌ Developers test locally with different commands than CI uses
- ❌ "Works on my machine" issues due to environment differences
- ❌ Two places to maintain when test configuration changes

**After (Unified Approach):**
- ✅ **Single source of truth**: `build.sh` contains all test logic
- ✅ **Same commands everywhere**: Developers run exactly what CI runs
- ✅ **Easier maintenance**: Update test logic in one place
- ✅ **Better reproducibility**: CI failures can be reproduced locally with identical commands

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         build.sh                            │
│             (Single Source of Truth)                        │
├─────────────────────────────────────────────────────────────┤
│  • Backend tests (pytest, black, flake8, mypy)             │
│  • Frontend tests (vitest, eslint, typescript, build)      │
│  • Airflow DAG validation (pytest)                         │
│  • DBT validation (deps, parse, compile)                   │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │
        ┌──────────────────┴──────────────────┐
        │                                     │
    Local Dev                           CI/CD Pipeline
  ./build.sh --backend              ./build.sh --backend --ci
  ./build.sh --frontend             ./build.sh --frontend --ci
  ./build.sh --all                  ./build.sh --all --ci
```

## Migration Plan

### Phase 1: Enhance build.sh for CI/CD ✅ DONE

**Changes made:**
1. Added `--ci` flag for CI-friendly output (no colors, verbose)
2. Added XML coverage report generation for Codecov uploads
3. Improved error handling and exit codes

**Example:**
```bash
# Local development (with colors)
./build.sh --backend

# CI/CD (no colors, XML coverage)
./build.sh --backend --ci
```

### Phase 2: Create Unified CI Workflow ✅ DONE

**New workflow:** `.github/workflows/ci-tests-unified.yml`

**Key features:**
- Uses `build.sh` for all test execution
- Maintains change detection for selective testing
- Preserves multi-version matrix testing (Python 3.11/3.12)
- Uploads coverage reports to Codecov

**Example job:**
```yaml
backend-tests:
  steps:
    - name: Run backend tests via build.sh
      run: |
        chmod +x build.sh
        ./build.sh --backend --ci
```

### Phase 3: Gradual Migration Strategy

**Option A: Parallel Testing (Recommended)**
1. Keep existing workflow: `ci-tests.yml` (current approach)
2. Add unified workflow: `ci-tests-unified.yml` (new approach)
3. Run both in parallel for 2-3 weeks
4. Compare results, fix any discrepancies
5. Deprecate old workflow once confident

**Option B: Direct Migration**
1. Rename `ci-tests.yml` → `ci-tests-legacy.yml`
2. Rename `ci-tests-unified.yml` → `ci-tests.yml`
3. Update branch protection rules

### Phase 4: Deprecate Old Workflow

Once unified approach is validated:
```bash
# Remove old workflow
rm .github/workflows/ci-tests-legacy.yml

# Update documentation
git commit -m "chore: complete migration to unified build.sh testing"
```

## Usage Examples

### Local Development

```bash
# Run all tests
./build.sh --all

# Run specific component
./build.sh --backend
./build.sh --frontend
./build.sh --airflow
./build.sh --dbt

# Run multiple components
./build.sh --backend --frontend

# Auto-fix formatting issues
./build.sh --backend --fix
```

### CI/CD Pipeline

```yaml
# Backend tests (Python 3.11 & 3.12)
- name: Run backend tests
  run: ./build.sh --backend --ci

# Frontend tests (Node 20.x)
- name: Run frontend tests
  run: ./build.sh --frontend --ci

# All tests
- name: Run all tests
  run: ./build.sh --all --ci
```

## Benefits

### For Developers

1. **Consistency**: Run exact same commands as CI
2. **Faster debugging**: Reproduce CI failures locally with identical setup
3. **One command**: `./build.sh --all` before every commit
4. **Auto-fix**: `./build.sh --backend --fix` to format code automatically

### For CI/CD

1. **Simplified workflows**: Less YAML duplication
2. **Easier maintenance**: Update test logic in `build.sh`, not multiple workflow files
3. **Better error messages**: Unified error handling and reporting
4. **Selective testing**: Smart change detection still works

### For the Team

1. **Single source of truth**: No confusion about "correct" test commands
2. **Documentation**: `./build.sh --help` always up-to-date
3. **Onboarding**: New team members learn one tool
4. **Consistency**: Same quality checks everywhere

## Comparison: Before vs After

### Before (Current ci-tests.yml)

**Backend tests:**
```yaml
- name: Run linting
  run: |
    cd backend
    pip install black flake8 mypy
    black --check app/
    flake8 app/ --max-line-length=120 --exclude=__pycache__

- name: Run tests with coverage
  run: |
    cd backend
    pytest --cov=app --cov-report=xml --cov-report=term-missing -v
```

**Problems:**
- Commands duplicated from `build.sh`
- Easy to get out of sync
- Developers might run different commands locally

### After (Unified ci-tests-unified.yml)

**Backend tests:**
```yaml
- name: Run backend tests via build.sh
  run: ./build.sh --backend --ci
```

**Benefits:**
- ✅ One line instead of 10+
- ✅ Guaranteed to match local development
- ✅ Update once in `build.sh`, works everywhere

## Testing the Migration

### 1. Parallel Validation

Run both workflows side-by-side:
```bash
# Trigger both workflows on same commit
git commit -m "test: validate unified build.sh approach"
git push
```

**Compare:**
- Test coverage reports
- Execution times
- Pass/fail results

### 2. Local Validation

Reproduce CI environment locally:
```bash
# Backend (Python 3.11)
docker run -it python:3.11 bash
git clone <repo>
./build.sh --backend --ci

# Frontend (Node 20.x)
docker run -it node:20 bash
git clone <repo>
./build.sh --frontend --ci
```

### 3. Branch Protection

During migration, keep both workflows as required checks:
```
Required status checks:
  ✅ ci-tests (legacy)
  ✅ ci-tests-unified (new)
```

After migration:
```
Required status checks:
  ✅ ci-tests-unified
```

## Rollback Plan

If issues arise during migration:

```bash
# 1. Revert to old workflow
git revert <commit-hash>

# 2. Or disable unified workflow temporarily
# Edit .github/workflows/ci-tests-unified.yml
on:
  workflow_dispatch:  # Manual trigger only

# 3. Keep using legacy workflow
# No changes needed to ci-tests.yml
```

## Future Enhancements

### 1. Docker-based Testing

Run tests inside Docker for even better reproducibility:
```bash
# Build test container
docker build -t hirewire-test -f .infra/docker/test.Dockerfile .

# Run tests
docker run hirewire-test ./build.sh --backend --ci
```

### 2. Pre-commit Hooks

Enforce tests before commit:
```bash
# .git/hooks/pre-commit
#!/bin/bash
./build.sh --backend --frontend --ci
```

### 3. Make Integration

Create Makefile for common tasks:
```makefile
test-all:
    ./build.sh --all

test-backend:
    ./build.sh --backend

test-ci:
    ./build.sh --all --ci
```

## FAQ

### Q: Does this slow down CI?

**A:** No, same tests run in same order. Only difference is execution path (through `build.sh` instead of direct commands).

### Q: What if build.sh has bugs?

**A:**
1. Tests run locally first (developers catch issues)
2. Parallel validation catches discrepancies
3. Easy rollback to legacy workflow

### Q: How do I update test configuration?

**A:** Edit `build.sh` once, changes apply to:
- Local development (`./build.sh`)
- CI/CD pipeline (`.github/workflows/ci-tests-unified.yml`)
- Documentation (`./build.sh --help`)

### Q: Can I still run tests manually in CI?

**A:** Yes, workflow_dispatch is enabled:
```bash
# GitHub UI: Actions → CI - Unified Tests → Run workflow
# Or via GitHub CLI:
gh workflow run ci-tests-unified.yml
```

## Conclusion

Unifying tests with `build.sh` provides:
- ✅ Consistency between local and CI environments
- ✅ Easier maintenance (single source of truth)
- ✅ Better developer experience
- ✅ Reproducible test failures
- ✅ Simplified CI/CD workflows

**Recommended next steps:**
1. ✅ Review this document
2. ⏳ Test unified workflow in parallel with existing workflow (2-3 weeks)
3. ⏳ Compare results and fix discrepancies
4. ⏳ Update branch protection rules
5. ⏳ Deprecate legacy workflow
6. ⏳ Update team documentation

**Timeline:**
- Week 1-2: Parallel validation
- Week 3: Team review and feedback
- Week 4: Migration and deprecation
