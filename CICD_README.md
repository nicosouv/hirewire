# CI/CD - HireWire

Automated testing, building, and deployment pipeline using GitHub Actions.

## 🚀 Quick Start

### Create a Release

```bash
# Use the release helper script
./scripts/release.sh 1.2.3

# Or bump version automatically
./scripts/release.sh patch   # 1.0.0 -> 1.0.1
./scripts/release.sh minor   # 1.0.0 -> 1.1.0
./scripts/release.sh major   # 1.0.0 -> 2.0.0
```

This will:
1. ✅ Create git tag `v1.2.3`
2. 🔍 Detect which services changed since last tag
3. 🐳 Build Docker images for changed services only
4. 📦 Push images to GitHub Container Registry (GHCR)
5. 🚀 Create GitHub Release with automatic changelog

### Pull Docker Images

```bash
# Pull latest images
docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:latest
docker pull ghcr.io/YOUR_USERNAME/hirewire-frontend:latest
docker pull ghcr.io/YOUR_USERNAME/hirewire-airflow:latest
docker pull ghcr.io/YOUR_USERNAME/hirewire-dbt:latest

# Pull specific version
docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:1.2.3
```

---

## 🔄 CI/CD Pipeline

### On Push / Pull Request

**Workflow**: `.github/workflows/ci-tests.yml`

```
Push/PR → Detect Changes → Run Tests → Post Results
```

**Smart Testing**:
- ✅ Only runs tests for changed services
- ⚡ Parallel execution (faster CI)
- 📊 Coverage reporting
- 💬 PR comments with results

**Example**:
```
Frontend changed → Run frontend tests only
Backend changed → Run backend tests only
Both changed → Run both in parallel
```

### On Tag Push (Release)

**Workflow**: `.github/workflows/build-and-push.yml`

```
Tag v1.2.3 → Detect Changes → Build Images → Push to GHCR → Create Release
```

**Smart Building**:
- ✅ Only builds changed services
- 🐳 Multi-architecture (amd64 + arm64)
- 📦 Layer caching for fast rebuilds
- 🏷️  Multiple tags (v1.2.3, v1.2, v1, latest)

**Example**:
```bash
# Only frontend changed since v1.0.0
✅ Frontend image built: ghcr.io/.../hirewire-frontend:1.1.0
⏭️  Backend skipped (no changes)
⏭️  Airflow skipped (no changes)
⏭️  DBT skipped (no changes)
```

---

## 📦 Docker Images

| Service | Image | Size | Platforms |
|---------|-------|------|-----------|
| Backend | `ghcr.io/.../hirewire-backend` | ~200MB | amd64, arm64 |
| Frontend | `ghcr.io/.../hirewire-frontend` | ~50MB | amd64, arm64 |
| Airflow | `ghcr.io/.../hirewire-airflow` | ~1.5GB | amd64 |
| DBT | `ghcr.io/.../hirewire-dbt` | ~300MB | amd64 |

### Image Tags

For version `v1.2.3`, creates:
- `1.2.3` - Exact version
- `1.2` - Minor version
- `1` - Major version
- `latest` - Latest stable

---

## 🧪 Testing

### Run All Tests Locally

```bash
# From project root
./scripts/run_all_tests.sh
```

### Test Specific Service

```bash
# Backend
cd backend && pytest --cov=app

# Frontend
cd frontend && npm test

# Airflow DAGs
cd airflow && ./scripts/run_tests.sh
```

---

## 📝 Semantic Versioning

We follow [SemVer](https://semver.org/):

- **Major (X.0.0)**: Breaking changes
  - API breaking changes
  - Database migrations
  - Removed features

- **Minor (1.X.0)**: New features (backwards compatible)
  - New endpoints
  - New frontend features
  - New DAGs

- **Patch (1.2.X)**: Bug fixes
  - Bug fixes
  - Security patches
  - Documentation

---

## ⚙️  Configuration

### Required: Enable GitHub Packages

1. Go to **Settings → Actions → General**
2. Under "Workflow permissions":
   - ✅ Read and write permissions
   - ✅ Allow GitHub Actions to create and approve pull requests

### Optional: Branch Protection

Protect `main` branch:

1. Go to **Settings → Branches**
2. Add rule for `main`:
   - ✅ Require status checks: `ci-tests-summary`
   - ✅ Require branches to be up to date

### Optional: Codecov

For coverage reports:

1. Sign up at [codecov.io](https://codecov.io)
2. Add `CODECOV_TOKEN` to repository secrets

---

## 📚 Documentation

- **[Complete CI/CD Guide](docs/CICD_GUIDE.md)** - Detailed documentation
- **[Testing Guide](docs/TESTING_GUIDE.md)** - How to write and run tests
- **[Release Script](scripts/release.sh)** - Automated release helper

---

## 🎯 Workflow Files

| File | Purpose | Trigger |
|------|---------|---------|
| [`ci-tests.yml`](.github/workflows/ci-tests.yml) | Run tests | Push, PR |
| [`build-and-push.yml`](.github/workflows/build-and-push.yml) | Build images | Tag (v*.*.*) |

---

## 🔍 Monitoring

### View Workflows

```bash
# GitHub Actions dashboard
https://github.com/YOUR_USERNAME/hirewire/actions

# Specific workflow run
https://github.com/YOUR_USERNAME/hirewire/actions/runs/RUN_ID
```

### View Images

```bash
# GitHub Packages
https://github.com/YOUR_USERNAME?tab=packages

# Pull image
docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:latest
```

### View Releases

```bash
# GitHub Releases
https://github.com/YOUR_USERNAME/hirewire/releases
```

---

## 🐛 Troubleshooting

### Tests Failing in CI

```bash
# Check workflow logs
gh run view --log

# Run tests locally with same environment
cd backend && pytest -v
```

### Image Build Failing

```bash
# Test Dockerfile locally
docker build -f .infra/docker/backend.Dockerfile ./backend

# Check workflow logs for details
```

### Tag Not Triggering Build

```bash
# Ensure tag is annotated
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Verify tag exists
git tag -l "v*"
```

---

## 💡 Tips

### Fast Development Cycle

```bash
# 1. Make changes
git add .
git commit -m "feat: add new feature"

# 2. Push to branch (runs tests)
git push origin feature/my-feature

# 3. Create PR (tests run again + PR comment)
gh pr create

# 4. Merge to main (tests run again)
gh pr merge

# 5. Create release (builds images)
./scripts/release.sh minor
```

### Selective Testing Locally

```bash
# Only changed files
git diff --name-only HEAD~1 | grep "^backend/" && cd backend && pytest

# Specific markers
pytest -m "not slow"  # Skip slow tests
```

### Skip CI for Docs Changes

```bash
git commit -m "docs: update README [skip ci]"
```

---

## 📊 CI/CD Metrics

### Average Times

| Workflow | Duration |
|----------|----------|
| CI Tests (changed service only) | 2-5 min |
| CI Tests (all services) | 8-12 min |
| Build & Push (one service) | 5-10 min |
| Build & Push (all services) | 20-30 min |

### Cost Optimization

- ✅ **Smart change detection** - Saves 60-80% CI minutes
- ✅ **Parallel jobs** - Faster feedback
- ✅ **Workflow cancellation** - Cancel outdated runs
- ✅ **Cache layers** - Fast Docker builds

---

## ✅ Checklist: First Release

- [ ] Review and update `.github/workflows/` files
- [ ] Replace `YOUR_USERNAME` with actual GitHub username
- [ ] Enable GitHub Packages permissions
- [ ] Run tests locally: `./scripts/run_all_tests.sh`
- [ ] Test release script: `./scripts/release.sh --dry-run`
- [ ] Create first tag: `./scripts/release.sh 1.0.0`
- [ ] Verify images: `docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:1.0.0`
- [ ] Check GitHub Release was created

---

## 🎉 Summary

✅ **Automated Testing** - Every push/PR
✅ **Smart Detection** - Only test/build what changed
✅ **Docker Images** - GHCR with multi-arch support
✅ **Semantic Versioning** - Clear version management
✅ **GitHub Releases** - Automatic changelog
✅ **Developer Friendly** - Simple `./scripts/release.sh`

**Ready to deploy?** See the [Complete CI/CD Guide](docs/CICD_GUIDE.md) for detailed instructions.
