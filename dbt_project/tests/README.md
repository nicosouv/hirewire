# DBT Testing Strategy - HireWire

This directory contains comprehensive tests for the HireWire DBT project, following DBT best practices.

## Test Structure

### 1. Schema Tests (`_*__models.yml` files)
Located within model directories, these tests validate:
- **Column-level constraints**: `unique`, `not_null`, `accepted_values`
- **Relationships**: Foreign key integrity between models
- **Custom data_tests**: Using `dbt_utils` for advanced validations

**Files:**
- `models/staging/_staging__models.yml` - Staging layer tests
- `models/intermediate/_intermediate__models.yml` - Intermediate layer tests
- `models/marts/_marts__models.yml` - Marts layer tests

### 2. Cross-Model Relationship Tests (`tests/relationships/`)
Validates data integrity across model layers:
- Staging → Intermediate → Marts pipeline integrity
- Foreign key relationships across layers
- Denormalized field consistency

**Tests:**
- `test_cross_model_relationships.yml` - Comprehensive cross-layer validation

### 3. Business Logic Tests (`tests/business_logic/`)
Singular SQL tests validating domain-specific rules:

**Tests:**
- `test_process_status_consistency.sql` - Process status aligns with outcome category
- `test_interview_dates_logical_order.sql` - Temporal ordering of dates
- `test_active_applications_have_no_final_outcomes.sql` - Active applications mart accuracy
- `test_salary_ranges_valid.sql` - Salary logic validation
- `test_interview_rounds_sequential.sql` - Interview rounds are sequential
- `test_priority_score_logic.sql` - Priority scoring business rules
- `test_one_outcome_per_process.sql` - One outcome per process rule

### 4. Data Quality Tests (`tests/data_quality/`)
Advanced quality checks using `dbt_utils`:

**Tests:**
- `test_data_quality_checks.yml` - Multiple quality checks:
  - Data freshness (recent applications)
  - Null status categories
  - Orphaned records
  - Duplicate detection
  - Outlier detection (durations, amounts)
  - Missing data (ratings, salaries)
  - Stale processes
- `test_recency_checks.sql` - Timestamp validation across all models

## Test Execution

### Run All Tests
```bash
docker-compose exec dbt dbt test
```

### Run Tests by Category
```bash
# Schema tests only
docker-compose exec dbt dbt test --select test_type:schema

# Singular tests only (business logic + data quality)
docker-compose exec dbt dbt test --select test_type:singular

# Tests for specific model
docker-compose exec dbt dbt test --select mart_active_applications

# Tests for specific layer
docker-compose exec dbt dbt test --select staging
docker-compose exec dbt dbt test --select intermediate
docker-compose exec dbt dbt test --select marts
```

### Run Tests by Severity
```bash
# Error-level tests only (will fail builds)
docker-compose exec dbt dbt test --select config.severity:error

# Warning-level tests only (informational)
docker-compose exec dbt dbt test --select config.severity:warn
```

### Run Specific Test
```bash
docker-compose exec dbt dbt test --select test_name:test_process_status_consistency
```

## Test Coverage Summary

### Staging Layer (100% coverage)
- ✅ Primary keys (unique, not_null)
- ✅ Foreign key relationships
- ✅ Accepted values for enums
- ✅ Date validations
- ✅ Numeric range checks
- ✅ Expression validations (dbt_utils)

### Intermediate Layer (100% coverage)
- ✅ All staging tests + enrichments
- ✅ Denormalized field consistency
- ✅ Calculated field validations
- ✅ Category mappings
- ✅ Cross-table joins

### Marts Layer (100% coverage)
- ✅ Aggregation validations
- ✅ Business metric calculations
- ✅ Priority scoring logic
- ✅ Date range validations
- ✅ Completeness checks

### Business Logic (Critical Rules)
- ✅ One outcome per process
- ✅ Sequential interview rounds
- ✅ Temporal consistency
- ✅ Status-outcome alignment
- ✅ Active application filtering
- ✅ Salary range logic
- ✅ Priority score rules

### Data Quality (Ongoing Monitoring)
- ✅ Data freshness
- ✅ Outlier detection
- ✅ Duplicate prevention
- ✅ Missing data identification
- ✅ Timestamp integrity
- ✅ Currency consistency

## Test Severity Levels

### Error (Fails Build)
Used for critical data integrity issues:
- Primary key violations
- Foreign key violations
- Temporal logic violations
- One-to-one relationship violations
- Required field nulls

### Warn (Informational)
Used for data quality monitoring:
- Outlier detection
- Missing optional data
- Stale processes
- Potential duplicates
- Data freshness

## Best Practices Applied

### 1. **Layered Testing**
Tests at each layer (staging → intermediate → marts) with increasing complexity.

### 2. **DRY Principle**
- Schema tests in YAML for common validations
- Singular tests for complex business logic
- Reusable dbt_utils tests

### 3. **Clear Test Names**
All tests named descriptively: `test_{domain}_{what_is_tested}.sql`

### 4. **Documented Tests**
Each test includes:
- Description of what it validates
- Business rule being enforced
- Severity level

### 5. **Comprehensive Coverage**
- **Schema tests**: Column constraints and relationships
- **Singular tests**: Business logic and data quality
- **dbt_utils**: Advanced patterns (unique combinations, expressions)

### 6. **Performance Optimized**
- WHERE clauses to limit test scope
- Indexed foreign keys
- Materialized models for faster testing

### 7. **Actionable Failures**
Tests return:
- Record IDs
- Violation reasons
- Context for debugging

## Continuous Integration

Tests should be run:
1. **After every model change** (`dbt run --models {changed_model}` → `dbt test --select {changed_model}`)
2. **Before deployments** (`dbt test` in CI/CD pipeline)
3. **On schedule** (daily data quality checks)

## Adding New Tests

### For New Models
1. Add schema tests in model's `_*__models.yml`
2. Test primary keys, foreign keys, enums
3. Add cross-layer relationships in `tests/relationships/`

### For New Business Rules
1. Create singular test in `tests/business_logic/`
2. Document the rule in test comments
3. Set appropriate severity

### For Data Quality Monitoring
1. Add to `tests/data_quality/test_data_quality_checks.yml`
2. Use `warn` severity for monitoring
3. Include issue description in output

## Test Maintenance

- Review failing tests immediately
- Update tests when business rules change
- Archive obsolete tests with comments
- Keep test documentation current

## References

- [DBT Testing Documentation](https://docs.getdbt.com/docs/build/tests)
- [dbt_utils Package](https://github.com/dbt-labs/dbt-utils)
- [Testing Best Practices](https://docs.getdbt.com/best-practices/how-we-structure/6-testing)