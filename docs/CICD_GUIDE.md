# CI/CD Guide - HireWire

Complete CI/CD pipeline using GitHub Actions with intelligent change detection and Docker image building.

## 📋 Table of Contents

- [Overview](#overview)
- [Workflows](#workflows)
- [Docker Images](#docker-images)
- [Release Process](#release-process)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

### CI/CD Strategy

HireWire uses a **smart CI/CD pipeline** that:

1. ✅ **Runs tests on every push/PR** - Validates code quality
2. 🔍 **Detects changes intelligently** - Only tests affected services
3. 🐳 **Builds Docker images on tags** - Semantic versioning (v1.2.3)
4. 🎯 **Selective image building** - Only rebuilds changed services
5. 📦 **Pushes to GHCR** - GitHub Container Registry
6. 🚀 **Creates GitHub Releases** - Automated changelog

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Push to Branch / PR                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
          ┌────────────────────────┐
          │   Detect Changes       │
          │  (paths-filter)        │
          └────────┬───────────────┘
                   │
       ┌───────────┼───────────┬─────────────┐
       │           │           │             │
       ▼           ▼           ▼             ▼
  ┌────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐
  │Backend │ │Frontend │ │Airflow  │ │   DBT    │
  │ Tests  │ │ Tests   │ │ Tests   │ │Validation│
  └────────┘ └─────────┘ └─────────┘ └──────────┘
       │           │           │             │
       └───────────┴───────────┴─────────────┘
                       │
                       ▼
              ┌────────────────┐
              │ All Tests Pass │
              └────────────────┘


┌─────────────────────────────────────────────────────────────┐
│                    Push Tag (v1.2.3)                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
          ┌────────────────────────┐
          │ Detect Changed Services│
          │  (git diff last tag)   │
          └────────┬───────────────┘
                   │
       ┌───────────┼───────────┬─────────────┐
       │           │           │             │
       ▼           ▼           ▼             ▼
  ┌────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐
  │Backend │ │Frontend │ │Airflow  │ │   DBT    │
  │ Build  │ │ Build   │ │ Build   │ │  Build   │
  └────┬───┘ └────┬────┘ └────┬────┘ └────┬─────┘
       │          │           │            │
       └──────────┴───────────┴────────────┘
                       │
                       ▼
              ┌────────────────┐
              │  Push to GHCR  │
              │   (Multi-arch) │
              └────────┬───────┘
                       │
                       ▼
              ┌────────────────┐
              │ Create Release │
              │  + Changelog   │
              └────────────────┘
```

---

## 🔄 Workflows

### 1. CI Tests (`ci-tests.yml`)

**Trigger**: Push to `main`/`develop` or Pull Request

**Purpose**: Validate code quality and run tests

**Features**:
- 🔍 **Smart change detection** - Only runs relevant tests
- 🔄 **Matrix builds** - Tests on multiple Python/Node versions
- 📊 **Coverage reporting** - Uploads to Codecov
- 💬 **PR comments** - Test results posted on PRs
- 🚫 **Cancel in-progress** - Saves CI minutes

**Jobs**:

| Job | Runs If | Purpose |
|-----|---------|---------|
| `detect-changes` | Always | Detect which services changed |
| `backend-tests` | Backend changed | pytest + coverage (Python 3.11, 3.12) |
| `frontend-tests` | Frontend changed | Vitest + coverage (Node 20) |
| `airflow-tests` | Airflow changed | pytest + DAG validation |
| `dbt-validation` | DBT changed | Compile & parse DBT models |
| `ci-tests-summary` | Always | Aggregate results + PR comment |

**Change Detection**:

```yaml
filters: |
  backend:
    - 'backend/**'
    - '.github/workflows/backend-tests.yml'
  frontend:
    - 'frontend/**'
  airflow:
    - 'airflow/**'
  dbt:
    - 'dbt_project/**'
    - 'profiles/**'
```

**Example Output**:

```
✅ Backend tests passed (Python 3.11, 3.12)
✅ Frontend tests passed
⏭️  Airflow tests skipped (no changes)
⏭️  DBT validation skipped (no changes)
```

### 2. Build and Push (`build-and-push.yml`)

**Trigger**: Push tag matching `v*.*.*` (e.g., `v1.2.3`)

**Purpose**: Build and publish Docker images

**Features**:
- 🔍 **Selective building** - Only rebuilds changed services
- 🐳 **Multi-arch images** - linux/amd64 + linux/arm64
- 📦 **Layer caching** - Fast rebuilds with GitHub cache
- 🏷️  **Smart tagging** - v1.2.3, v1.2, v1, latest
- 📝 **Auto-changelog** - Generated from git commits
- 🚀 **GitHub Releases** - Automatic release creation

**Change Detection Logic**:

```bash
# Compares current tag with previous tag
git diff --name-only v1.0.0 v1.1.0 | grep '^backend/'

# If first tag (no previous), builds all services
```

**Image Tags**:

For tag `v1.2.3`, creates:
- `ghcr.io/YOUR_USERNAME/hirewire-backend:1.2.3`
- `ghcr.io/YOUR_USERNAME/hirewire-backend:1.2`
- `ghcr.io/YOUR_USERNAME/hirewire-backend:1`
- `ghcr.io/YOUR_USERNAME/hirewire-backend:latest`

**Jobs**:

| Job | Purpose |
|-----|---------|
| `detect-changes` | Compare with previous tag |
| `build-backend` | Build backend image (if changed) |
| `build-frontend` | Build frontend image (if changed) |
| `build-airflow` | Build Airflow image (if changed) |
| `build-dbt` | Build DBT image (if changed) |
| `create-release` | Create GitHub Release with changelog |
| `build-summary` | Report build results |

**Example Scenario**:

```bash
# Only frontend changed since v1.0.0
$ git diff --name-only v1.0.0..v1.1.0
frontend/src/App.tsx
frontend/src/components/Dashboard.tsx

# Result:
✅ Frontend image built and pushed
⏭️  Backend image skipped (no changes)
⏭️  Airflow image skipped (no changes)
⏭️  DBT image skipped (no changes)
```

---

## 🐳 Docker Images

### Available Images

| Service | Image | Base | Size |
|---------|-------|------|------|
| **Backend** | `ghcr.io/.../hirewire-backend` | Python 3.11-slim | ~200MB |
| **Frontend** | `ghcr.io/.../hirewire-frontend` | Nginx Alpine | ~50MB |
| **Airflow** | `ghcr.io/.../hirewire-airflow` | Apache Airflow 3.1.0 | ~1.5GB |
| **DBT** | `ghcr.io/.../hirewire-dbt` | Python 3.11 | ~300MB |

### Image Optimizations

#### Backend
- ✅ Multi-stage build (builder + runtime)
- ✅ Non-root user
- ✅ Health checks
- ✅ uvicorn with 4 workers

#### Frontend
- ✅ Multi-stage build (Node + Nginx)
- ✅ Gzip compression
- ✅ Cache headers for static assets
- ✅ SPA routing support

#### Airflow
- ✅ Custom DAGs included
- ✅ DBT + DuckDB + PostgreSQL support
- ✅ Docker socket access
- ✅ Celery executor ready

### Pulling Images

```bash
# Latest version
docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:latest

# Specific version
docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:1.2.3

# All services for v1.2.3
docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:1.2.3
docker pull ghcr.io/YOUR_USERNAME/hirewire-frontend:1.2.3
docker pull ghcr.io/YOUR_USERNAME/hirewire-airflow:1.2.3
docker pull ghcr.io/YOUR_USERNAME/hirewire-dbt:1.2.3
```

### Using Images

Update `docker-compose.yml`:

```yaml
services:
  backend:
    image: ghcr.io/YOUR_USERNAME/hirewire-backend:1.2.3
    # Remove: build: ./backend

  frontend:
    image: ghcr.io/YOUR_USERNAME/hirewire-frontend:1.2.3
    # Remove: build: ./frontend
```

---

## 🚀 Release Process

### Quick Start

```bash
# Create a new release (interactive)
./scripts/release.sh

# Specify version
./scripts/release.sh 1.2.3

# Bump version automatically
./scripts/release.sh patch   # 1.0.0 -> 1.0.1
./scripts/release.sh minor   # 1.0.0 -> 1.1.0
./scripts/release.sh major   # 1.0.0 -> 2.0.0

# Dry run (test without creating tag)
./scripts/release.sh --dry-run
```

### Manual Release Process

#### 1. Prepare Release

```bash
# Ensure you're on main branch
git checkout main
git pull origin main

# Ensure all tests pass locally
./scripts/run_all_tests.sh

# Check for uncommitted changes
git status
```

#### 2. Create Tag

```bash
# Choose semantic version
VERSION="1.2.3"

# Create annotated tag
git tag -a "v${VERSION}" -m "Release v${VERSION}"

# Push tag to trigger CI/CD
git push origin "v${VERSION}"
```

#### 3. Monitor CI/CD

```bash
# Watch GitHub Actions
open "https://github.com/YOUR_USERNAME/hirewire/actions"

# Workflow will:
# 1. Detect changed services
# 2. Build Docker images
# 3. Push to GHCR
# 4. Create GitHub Release
```

#### 4. Verify Release

```bash
# Check images
docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:${VERSION}

# Check GitHub Release
open "https://github.com/YOUR_USERNAME/hirewire/releases/latest"
```

### Semantic Versioning

Follow [SemVer](https://semver.org/) specification:

- **Major (X.0.0)**: Breaking changes
  - API changes that break compatibility
  - Database schema changes requiring migrations
  - Removed features

- **Minor (1.X.0)**: New features (backwards compatible)
  - New API endpoints
  - New frontend features
  - New DAGs

- **Patch (1.2.X)**: Bug fixes
  - Bug fixes
  - Security patches
  - Documentation updates

**Examples**:

```bash
# Bug fix
v1.2.0 -> v1.2.1

# New feature (dashboard widget)
v1.2.1 -> v1.3.0

# Breaking change (API v2)
v1.3.0 -> v2.0.0
```

### Release Checklist

- [ ] All tests passing locally
- [ ] Changelog updated (auto-generated)
- [ ] Version number chosen (SemVer)
- [ ] No uncommitted changes
- [ ] On `main` branch
- [ ] Tag created and pushed
- [ ] CI/CD completed successfully
- [ ] Docker images pulled and tested
- [ ] GitHub Release created
- [ ] Documentation updated (if needed)

---

## ⚙️  Configuration

### GitHub Secrets

**Required**:

None! Workflows use `GITHUB_TOKEN` (automatic).

**Optional**:

| Secret | Purpose | Required? |
|--------|---------|-----------|
| `CODECOV_TOKEN` | Upload coverage to Codecov | No |

### Repository Settings

#### 1. Enable GitHub Packages

Go to: **Settings → Actions → General**

Enable:
- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

#### 2. Branch Protection

Go to: **Settings → Branches → Branch protection rules**

For `main` branch:
- ✅ Require status checks to pass
  - `ci-tests-summary`
- ✅ Require branches to be up to date
- ✅ Require linear history

#### 3. Enable Dependabot

Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/backend"
    schedule:
      interval: "weekly"

  - package-ecosystem: "npm"
    directory: "/frontend"
    schedule:
      interval: "weekly"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Environment Variables

Add to `.env` (not committed):

```bash
# GitHub Container Registry
GITHUB_TOKEN=ghp_xxxxxxxxxxxxx  # For local docker login
```

### Docker Login

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Pull private images
docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:latest
```

---

## 🐛 Troubleshooting

### CI Tests Failing

**Issue**: Tests fail in CI but pass locally

**Solution**:
```bash
# Ensure Python/Node versions match
# CI uses: Python 3.11/3.12, Node 20

# Check .github/workflows/ci-tests.yml for exact versions
```

**Issue**: "Permission denied" writing to coverage

**Solution**: Codecov token is optional, remove if not needed.

### Build Failures

**Issue**: Docker build fails with "No space left on device"

**Solution**: GitHub Actions has 14GB disk space. Optimize images:
```dockerfile
# Remove build dependencies
RUN apt-get purge -y build-essential && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*
```

**Issue**: Multi-arch build times out

**Solution**: Build only amd64 initially:
```yaml
platforms: linux/amd64  # Remove linux/arm64
```

### Image Push Failures

**Issue**: "denied: permission_denied"

**Solution**: Check repository settings:
```bash
# Settings → Actions → General
# Enable: "Read and write permissions"
```

**Issue**: Image not found after push

**Solution**: Make package public:
```bash
# Go to: Packages → hirewire-backend → Package settings
# Change visibility: Private → Public
```

### Release Script Issues

**Issue**: "Not in a git repository"

**Solution**:
```bash
cd /path/to/hirewire  # Ensure in project root
./scripts/release.sh
```

**Issue**: "Uncommitted changes detected"

**Solution**:
```bash
git status
git add .
git commit -m "Prepare release"
./scripts/release.sh
```

### Change Detection Issues

**Issue**: Service not building despite changes

**Solution**: Check path filters in workflow:
```yaml
filters: |
  backend:
    - 'backend/**'
    - '.infra/docker/backend.Dockerfile'  # Add if needed
```

**Issue**: All services building every time

**Solution**: Ensure annotated tags:
```bash
# ❌ Wrong
git tag v1.0.0

# ✅ Correct
git tag -a v1.0.0 -m "Release v1.0.0"
```

---

## 📚 Additional Resources

### Documentation

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [Semantic Versioning](https://semver.org/)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

### Examples

- [View Workflows](.github/workflows/)
- [View Dockerfiles](.infra/docker/)
- [Release Script](scripts/release.sh)

### Support

- 🐛 [Report Issues](https://github.com/YOUR_USERNAME/hirewire/issues)
- 💬 [Discussions](https://github.com/YOUR_USERNAME/hirewire/discussions)
- 📖 [Wiki](https://github.com/YOUR_USERNAME/hirewire/wiki)

---

## 🎉 Summary

✅ **Smart CI/CD** - Tests only what changed
✅ **Selective Builds** - Build only modified services
✅ **Automated Releases** - Tag → Build → Push → Release
✅ **Multi-arch Images** - amd64 + arm64 support
✅ **GitHub Integration** - GHCR + Releases + Comments
✅ **Developer Friendly** - Simple release script

**Quick Reference**:

```bash
# Run tests
./scripts/run_all_tests.sh

# Create release
./scripts/release.sh 1.2.3

# Pull image
docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:latest
```

For questions, see [Troubleshooting](#troubleshooting) or open an issue.
