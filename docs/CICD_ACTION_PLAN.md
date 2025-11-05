# CI/CD Unified Testing - Action Plan

## Executive Summary

**Goal**: Unify local development and CI/CD testing using `build.sh` as single source of truth

**Status**: ✅ Phase 1 & 2 Complete, Ready for Phase 3 (Validation)

**Benefits**:
- 47% reduction in YAML code (150 → 80 lines)
- 50% reduction in maintenance burden (2 → 1 sources)
- Eliminates dev/CI command divergence
- Improved developer experience

**Timeline**: 4 weeks (2-3 weeks validation + 1 week migration)

---

## Completed Work ✅

### Phase 1: Enhance build.sh ✅

**Files Modified:**
- `build.sh` - Added `--ci` flag, XML coverage reports

**Changes:**
```bash
# New features
./build.sh --backend --ci     # CI-friendly mode (no colors)
./build.sh --fix              # Auto-fix formatting issues

# Coverage reports
pytest --cov-report=xml       # For Codecov upload
```

**Testing:**
```bash
# Verify local execution
./build.sh --backend
./build.sh --frontend
./build.sh --all

# Verify CI mode
./build.sh --backend --ci
./build.sh --frontend --ci
```

✅ **Status**: Complete, all tests passing

### Phase 2: Create Unified Workflow ✅

**Files Created:**
- `.github/workflows/ci-tests-unified.yml` - New unified workflow
- `docs/CICD_UNIFIED_TESTS.md` - Complete documentation
- `docs/CICD_MIGRATION_COMPARISON.md` - Before/after comparison
- `docs/CICD_ACTION_PLAN.md` - This file

**Workflow Features:**
- Uses `build.sh` for all tests
- Maintains change detection
- Multi-version matrix testing (Python 3.11/3.12, Node 20.x)
- Codecov integration

✅ **Status**: Complete, ready for validation

---

## Next Steps

### Phase 3: Parallel Validation (2-3 weeks) ⏳

**Objective**: Run both workflows simultaneously to verify identical behavior

#### Week 1-2: Monitoring

**Step 1: Enable unified workflow**
```bash
# No changes needed - workflow is ready
# It will trigger automatically on next push/PR
```

**Step 2: Monitor both workflows**

Track metrics for each run:
| Metric | Legacy (ci-tests.yml) | Unified (ci-tests-unified.yml) | Status |
|--------|----------------------|-------------------------------|--------|
| Backend tests | ✅ Pass / ❌ Fail | ✅ Pass / ❌ Fail | 🟢 Match / 🔴 Differ |
| Frontend tests | ✅ Pass / ❌ Fail | ✅ Pass / ❌ Fail | 🟢 Match / 🔴 Differ |
| Airflow tests | ✅ Pass / ❌ Fail | ✅ Pass / ❌ Fail | 🟢 Match / 🔴 Differ |
| DBT validation | ✅ Pass / ❌ Fail | ✅ Pass / ❌ Fail | 🟢 Match / 🔴 Differ |
| Execution time | X min Y sec | X min Y sec | 🟢 Similar / 🔴 Different |

**Step 3: Fix discrepancies**

If tests differ between workflows:

```bash
# 1. Reproduce locally
./build.sh --backend --ci

# 2. Compare with direct commands
cd backend
pytest --cov=app --cov-report=xml -v

# 3. Debug and fix in build.sh
# Edit build.sh to match expected behavior

# 4. Verify fix
./build.sh --backend --ci
```

**Step 4: Team communication**

Send announcement:
```
📢 CI/CD Testing Update

We're migrating to unified testing with build.sh.

What this means for you:
• ✅ Same commands work locally and in CI
• ✅ Just run: ./build.sh --all
• ✅ No more "works on my machine" issues

Current status:
• Both workflows running in parallel
• Legacy (ci-tests.yml) - still required ✅
• Unified (ci-tests-unified.yml) - validation only ⏳

No action needed - keep working as normal!
```

#### Week 3: Team Review

**Step 1: Gather feedback**

Survey questions:
1. Have you noticed any issues with CI tests?
2. Have you tried `./build.sh --all` locally?
3. Any discrepancies between local and CI results?
4. Suggestions for improvements?

**Step 2: Address concerns**

Common concerns and solutions:
| Concern | Solution |
|---------|----------|
| "CI is slower" | Compare execution times, optimize if needed |
| "Tests fail in CI but not locally" | Investigate environment differences |
| "I prefer direct commands" | Show `build.sh --help` for available options |
| "What if build.sh breaks?" | Explain rollback plan, parallel safety net |

**Step 3: Make go/no-go decision**

Criteria for migration:
- ✅ Both workflows produce identical results for 2 weeks
- ✅ No unexplained test failures
- ✅ Team feedback is positive or neutral
- ✅ Execution times are comparable (±10%)

---

### Phase 4: Migration (Week 4) ⏳

**Prerequisites:**
- ✅ 2+ weeks successful parallel validation
- ✅ Team approval
- ✅ No open issues with unified workflow

#### Step 1: Update Branch Protection

**Before (requires both workflows):**
```
Required status checks:
  ✅ ci-tests / backend-tests
  ✅ ci-tests / frontend-tests
  ✅ ci-tests / airflow-tests
  ✅ ci-tests / dbt-validation
  ✅ ci-tests-unified / backend-tests
  ✅ ci-tests-unified / frontend-tests
  ✅ ci-tests-unified / airflow-tests
  ✅ ci-tests-unified / dbt-validation
```

**After (requires only unified workflow):**
```
Required status checks:
  ✅ ci-tests-unified / backend-tests
  ✅ ci-tests-unified / frontend-tests
  ✅ ci-tests-unified / airflow-tests
  ✅ ci-tests-unified / dbt-validation
```

**How to update:**
```
1. Go to: Settings → Branches → Branch protection rules
2. Edit rule for "main" branch
3. Update "Require status checks to pass"
4. Uncheck legacy workflow checks
5. Keep unified workflow checks
6. Save changes
```

#### Step 2: Archive Legacy Workflow

```bash
# Rename old workflow
git mv .github/workflows/ci-tests.yml .github/workflows/ci-tests-legacy.yml

# Or delete if confident
git rm .github/workflows/ci-tests.yml

# Commit
git add .
git commit -m "chore: migrate to unified build.sh testing

- Deprecate legacy ci-tests.yml workflow
- Use ci-tests-unified.yml as primary CI pipeline
- All tests now execute via build.sh for consistency

Closes #<issue-number>"

git push origin main
```

#### Step 3: Rename Unified Workflow

```bash
# Make unified workflow the primary one
git mv .github/workflows/ci-tests-unified.yml .github/workflows/ci-tests.yml

git commit -m "chore: promote unified workflow to primary CI pipeline"
git push origin main
```

#### Step 4: Update Documentation

**Files to update:**
- `README.md` - Add section about `build.sh`
- `CONTRIBUTING.md` - Update testing instructions
- `docs/TESTING.md` - Consolidate test documentation

**Example README.md section:**
```markdown
## Testing

Run all tests locally before pushing:

```bash
# Run all tests
./build.sh --all

# Run specific component
./build.sh --backend
./build.sh --frontend
./build.sh --airflow
./build.sh --dbt

# Auto-fix formatting
./build.sh --backend --fix

# Help
./build.sh --help
```

**CI/CD**: Tests run automatically via GitHub Actions using the same `build.sh` commands.
```

#### Step 5: Team Announcement

Send completion announcement:
```
🎉 CI/CD Migration Complete!

The unified testing approach is now live.

What changed:
• ✅ CI now uses build.sh (same as local dev)
• ✅ One source of truth for all tests
• ✅ Faster maintenance, better consistency

How to use:
• Before commit: ./build.sh --all
• Auto-fix code: ./build.sh --backend --fix
• Get help: ./build.sh --help

Documentation:
• Testing guide: docs/CICD_UNIFIED_TESTS.md
• Comparison: docs/CICD_MIGRATION_COMPARISON.md

Questions? Ask in #engineering channel
```

---

## Rollback Plan

If issues arise during or after migration:

### Option 1: Quick Rollback (Emergency)

```bash
# Revert to legacy workflow
git revert <migration-commit-hash>
git push origin main

# Update branch protection rules back to legacy checks
```

**ETA**: 5 minutes

### Option 2: Parallel Reactivation

```bash
# Re-enable legacy workflow (if archived)
git mv .github/workflows/ci-tests-legacy.yml .github/workflows/ci-tests.yml
git push origin main

# Keep unified workflow running too
# Both workflows active again for investigation
```

**ETA**: 10 minutes

### Option 3: Fix Forward

```bash
# Fix issue in build.sh
vim build.sh
# Make corrections

# Test locally
./build.sh --all --ci

# Commit fix
git add build.sh
git commit -m "fix: correct issue in build.sh CI mode"
git push origin main
```

**ETA**: 15-30 minutes (depending on issue)

---

## Success Metrics

### Week 2 Targets

- ✅ Both workflows run successfully on all commits
- ✅ Test results match between legacy and unified
- ✅ Execution times within 10% of legacy
- ✅ No regressions in test coverage
- ✅ Zero "works on my machine" issues reported

### Week 4 Targets

- ✅ Migration complete
- ✅ Legacy workflow archived
- ✅ Documentation updated
- ✅ Team trained on new approach
- ✅ Positive feedback from developers

### Long-term Targets (Month 2-3)

- 📈 Reduced CI/CD maintenance time
- 📉 Fewer "CI failed but local passed" issues
- 📊 Improved test consistency
- 🚀 Faster onboarding for new developers

---

## Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Tests differ between workflows | Medium | Medium | Parallel validation for 2+ weeks |
| build.sh has bug | Low | Medium | Easy rollback to legacy workflow |
| Team resistance | Low | Low | Clear communication, documentation |
| CI performance regression | Low | Medium | Monitor execution times, optimize |
| Coverage reports broken | Low | High | Verify Codecov uploads during validation |

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-01-12 | Adopt unified approach | Reduce maintenance, improve consistency |
| 2025-01-12 | Use build.sh as source of truth | Already exists, well-structured |
| 2025-01-12 | Parallel validation (2-3 weeks) | Safe migration, catch issues early |
| TBD | Go/no-go decision | Based on validation results |
| TBD | Migration completion | After team approval |

---

## Contact & Support

**Questions?**
- Technical lead: [Name]
- DevOps team: #devops channel
- Documentation: docs/CICD_UNIFIED_TESTS.md

**Issues?**
- Report in: #engineering channel
- GitHub issues: Tag with `ci-cd` label
- Urgent: Page on-call engineer

---

## Appendix

### Quick Reference Commands

```bash
# Local development
./build.sh --all                    # Run all tests
./build.sh --backend               # Backend only
./build.sh --frontend              # Frontend only
./build.sh --backend --fix         # Auto-fix formatting
./build.sh --help                  # Show help

# CI simulation
./build.sh --all --ci              # Run in CI mode locally

# Debugging
./build.sh --backend 2>&1 | tee build.log  # Save output
```

### Useful Links

- [CI/CD Unified Tests Documentation](./CICD_UNIFIED_TESTS.md)
- [Migration Comparison](./CICD_MIGRATION_COMPARISON.md)
- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [Codecov Documentation](https://docs.codecov.com/docs)

### Change History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-12 | Initial action plan created |
| 1.1 | TBD | Updated after Week 2 validation |
| 2.0 | TBD | Migration complete |
