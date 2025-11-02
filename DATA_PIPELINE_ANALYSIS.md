# HireWire Data Pipeline Engineering Analysis

## Executive Summary

HireWire implements a modern data stack with PostgreSQL (transactional) → DuckDB (analytics) transformation using DBT, with comprehensive data quality checks and Airflow orchestration. The architecture demonstrates solid data engineering practices with room for optimization in cross-database query patterns and data model complexity management.

---

## 1. DBT Models Structure & Quality

### 1.1 Architecture Strengths

**Clean Three-Layer Medallion Structure**
- **Staging Layer** (`stg_*`): Direct extraction from PostgreSQL using `postgres_scan()` macro
  - Minimal transformations (column selection, direct mapping)
  - Proper table materialization (persistent tables)
  - Clear 1:1 relationship with source tables

- **Intermediate Layer** (`int_*`): Business logic and enrichment
  - Data standardization (TRIM, LOWER, COALESCE)
  - Calculated fields (days_since_application, derived categories)
  - Status/source categorization with intelligent logic
  - Proper handling of NULL values with meaningful defaults

- **Marts Layer** (`mart_*`): Analytics-ready aggregations
  - Complex business logic for active applications (mart_active_applications)
  - Time-series analytics (mart_monthly_stats, mart_application_daily_stats)
  - Interview analytics and interview summaries

**Configuration Quality**
```yaml
# dbt_project.yml
require-dbt-version: [">=1.9.0", "<2.0.0"]
profile: 'hirewire'
models:
  hirewire:
    staging: materialized: table
    intermediate: materialized: table
    marts: materialized: table

on-run-start:
  - "INSTALL postgres_scanner"
  - "LOAD postgres_scanner"
  - "INSTALL icu"
  - "LOAD icu"
```

**Benefits of table materialization:**
- ✅ Persistent intermediate results avoid re-computation
- ✅ DuckDB columnar storage optimized for analytics
- ✅ Faster downstream query performance
- ✅ Clear data lineage and debugging

### 1.2 Issues & Concerns

**Cross-Database Query Pattern**
```sql
FROM {{ postgres_scan('companies') }}  -- Staging layer
FROM {{ ref('stg_companies') }}        -- Intermediate layer
```

**Issue**: Mixing postgres_scan in staging with ref() in intermediate creates a hybrid approach:
- **Problem 1**: Forces full table extraction into DuckDB at staging layer
- **Problem 2**: Can cause data transfer bottlenecks for large datasets
- **Problem 3**: Less flexible filtering - can't push filters down to PostgreSQL

**Recommendation**: Consider two approaches:
1. **Approach A** (Current): Extract → Transform in DuckDB (good for small datasets, <1M rows)
2. **Approach B** (Alternative): Keep raw data in PostgreSQL, create views in DuckDB via postgres_scanner

```sql
-- Current approach - materializes all companies in DuckDB
{{ postgres_scan('companies') }}

-- Alternative - keeps in PostgreSQL, DuckDB queries dynamically
SELECT * FROM postgres_scan('host=...', 'hirewire', 'companies')
WHERE name = 'TechCorp'  -- Filter pushed to PostgreSQL
```

**Model Complexity**
- `mart_active_applications.sql`: **208 lines** with extensive nested CASE statements
  - Contains 85+ lines just for "next_action" logic
  - Mixes French and business English in output

```sql
CASE
    WHEN ap.current_status = 'offer' THEN 'Négocier/Répondre à l''offre'
    WHEN ri.next_scheduled_interview_date IS NOT NULL AND ...
         ri.interview_types_scheduled ILIKE '%phone_screening%' 
    THEN 'Préparer entretien téléphonique'
    -- ... 20+ more conditions
```

**Recommendation**: Extract logic into a macro or separate table:
```sql
-- macros/get_next_action.sql
{% macro get_next_action(status, interview_types, days_since) %}
  CASE
    WHEN {{ status }} = 'offer' THEN 'Negotiate/Respond to offer'
    -- ... cleaner structure
  END
{% endmacro %}
```

### 1.3 Data Quality & Testing

**Comprehensive Test Coverage** (Excellent)
- **Schema tests**: unique, not_null, accepted_values, relationships
- **Custom data quality tests** (15+ tests):
  - `test_no_orphaned_interviews` - referential integrity
  - `test_unusual_process_durations` - outlier detection
  - `test_stale_applied_processes` - stale data detection
  - `test_currency_consistency` - cross-model validation

**Test Configuration**: 
- Severity levels (error, warn)
- Conditional testing with `where` clauses
- Custom test logic with aggregate functions

**Gaps**:
- ❌ No tests for data freshness (e.g., "data should refresh daily")
- ❌ No tests for expected row counts (e.g., "mart_active_applications should have >0 rows")
- ❌ No audit columns (created_by, updated_by) for data lineage
- ❌ No snapshot models for slowly changing dimensions (companies may rename)

**Missing SCD (Slowly Changing Dimensions)**:
```sql
-- Star schema defines SCD Type 2 structure
CREATE TABLE dim_companies (
    effective_date DATE NOT NULL,
    expiry_date DATE,
    is_current BOOLEAN DEFAULT TRUE
);
-- But DBT models don't implement the SCD logic
```

---

## 2. PostgreSQL to DuckDB Transformation

### 2.1 Data Flow Architecture

```
PostgreSQL (OLTP)
    ↓
postgres_scan() [cross-DB query]
    ↓
DuckDB Staging Tables
    ↓
DuckDB Intermediate Tables (enrichment)
    ↓
DuckDB Mart Tables (aggregations)
    ↓
Superset (visualization)
```

### 2.2 Strengths

**postgres_scan() Macro Simplification**
```sql
{% macro postgres_scan(table_name) %}
  postgres_scan(
    'host=postgres port=5432 user={{ env_var("POSTGRES_USER") }} 
     password={{ env_var("POSTGRES_PASSWORD") }} dbname=hirewire',
    'hirewire',
    '{{ table_name }}'
  )
{% endmacro %}
```

**Pros**:
- ✅ Clean abstraction layer
- ✅ Environment variable management
- ✅ Centralized connection configuration
- ✅ DuckDB's postgres_scanner extension works well for medium datasets

### 2.3 Performance Concerns

**1. Full Table Extractions**
- All staging models extract entire tables without filtering
- No incremental loading strategy

```sql
-- Current: Extracts all 1000+ companies every run
SELECT * FROM {{ postgres_scan('companies') }}

-- Better: Incremental strategy
SELECT * FROM {{ postgres_scan('companies') }} 
WHERE updated_at > CAST(dbt_internal_tests.get_max_loaded_at() AS TIMESTAMP)
```

**Impact**: 
- ❌ Slow for large PostgreSQL tables
- ❌ Network bandwidth waste
- ❌ DuckDB processing of unnecessary data
- ⚠️ Not a problem now (<1000 rows), will be problematic at scale

**2. Missing Indexes in Staging**
PostgreSQL schema has good indexes:
```sql
CREATE INDEX idx_companies_name ON hirewire.companies(name);
CREATE INDEX idx_interview_processes_status ON hirewire.interview_processes(status);
```

But DuckDB staging tables have **no indexes**:
```sql
-- DuckDB materialized tables are just heap files
-- No indexes created
```

**Recommendation**:
```sql
-- In DuckDB post-transform
CREATE INDEX idx_stg_companies_id ON stg_companies(id);
CREATE INDEX idx_stg_interview_processes_job_position ON stg_interview_processes(job_position_id);
```

**3. Complex Joins in Morts**
`mart_active_applications` performs expensive joins:
```sql
WITH active_processes AS (...),
     job_details AS (...),
     recent_interviews AS (...)  -- Complex aggregation
SELECT ... FROM active_processes ap
JOIN job_details jd ...
LEFT JOIN recent_interviews ri ...
```

**Analysis**:
- ✅ Well-structured CTEs (readable)
- ⚠️ Processes 3 levels of nested queries
- ⚠️ No explicit optimization (query plan unknown)

**Optimization**:
```sql
-- Add EXPLAIN ANALYZE to understand query performance
EXPLAIN ANALYZE
SELECT ... FROM mart_active_applications
WHERE process_id = 123;
```

### 2.4 Data Consistency Issues

**1. Status Mapping Inconsistency**
```sql
-- Staging allows these statuses:
VALUES: ['applied', 'screening', 'interviewing', 'tech_test', 'final_round', 'offer', 'rejected', 'accepted', 'ghosted', 'withdrew', 'reminder']

-- But intermediate allows these:
VALUES: ['applied', 'screening', 'interviewing', 'tech_test', 'final_round', 'offer', 'rejected', 'accepted', 'ghosted', 'withdrew', 'reminder', 'failed', 'withdrawn']

-- And outcomes use different values:
VALUES: ['rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew']
```

**Issue**: 
- Process status has 'offer' but outcome has no 'offer' equivalent
- 'rejected' vs 'rejection' inconsistency
- No centralized status dimension/lookup table

**Recommendation**: Create a dimension table:
```sql
-- dbt/models/marts/dim_process_status.sql
SELECT
  status_name,
  status_code,
  status_group,
  sort_order
FROM (VALUES
  ('applied', 'APL', 'ACTIVE', 1),
  ('screening', 'SCR', 'ACTIVE', 2),
  ('offer', 'OFF', 'ACTIVE', 5),
  ('accepted', 'ACC', 'CLOSED', 10),
  ('rejected', 'REJ', 'CLOSED', 11)
) AS t(status_name, status_code, status_group, sort_order)
```

**2. Outcome vs Process Status Misalignment**
```sql
-- mart_active_applications filters:
WHERE o.outcome NOT IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')

-- But tests expect:
WHERE outcome IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
```

This creates confusing logic about what "active" means.

---

## 3. SQL Query Quality & Optimization

### 3.1 Query Patterns - Best Practices

**3.1.1 Well-Written Queries**

✅ **mart_monthly_stats.sql** - Clean aggregation
```sql
WITH monthly_applications AS (
    SELECT
        DATE_TRUNC('month', application_date) as month,
        COUNT(*) as applications_count
    FROM {{ ref('stg_interview_processes') }}
    GROUP BY DATE_TRUNC('month', application_date)
),
monthly_interviews AS (
    SELECT
        DATE_TRUNC('month', scheduled_date) as month,
        COUNT(*) as interviews_count
    FROM {{ ref('stg_interviews') }}
    WHERE scheduled_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', scheduled_date)
)
SELECT
    COALESCE(a.month, i.month) as month,
    COALESCE(a.applications_count, 0) as applications_count,
    ...
FROM monthly_applications a
FULL OUTER JOIN monthly_interviews i ON a.month = i.month
```

**Strengths**:
- ✅ Clear CTE structure
- ✅ FULL OUTER JOIN to preserve all months
- ✅ COALESCE for null handling
- ✅ GROUP BY on calculated field (DATE_TRUNC)

**3.1.2 Problematic Patterns**

❌ **Date Type Confusion** (`mart_active_applications`)
```sql
THEN CURRENT_DATE - ri.last_interview_date::DATE
    -- Cast from timestamp to date mid-calculation
    
WHEN ri.next_scheduled_interview_date IS NOT NULL AND 
     ri.next_scheduled_interview_date >= CURRENT_DATE
     AND (ri.next_scheduled_interview_date::DATE - CURRENT_DATE) <= 3
    -- Multiple casts of same column
```

**Issues**:
- Unnecessary casting (scheduled_date should be DATE not TIMESTAMP)
- Query optimizer struggles with redundant casts
- Potential performance regression

**Better approach**:
```sql
-- Ensure scheduled_date is DATE type in source
-- Then use interval arithmetic:
WHEN CURRENT_DATE - ri.last_interview_date <= INTERVAL '3 days' THEN ...
```

❌ **Cascading CASE for Categorization** (`int_interviews.sql`)
```sql
CASE 
    WHEN TRIM(LOWER(i.interview_type)) LIKE '%technical%' THEN 'Technical'
    WHEN TRIM(LOWER(i.interview_type)) LIKE '%behavioral%' THEN 'Behavioral' 
    WHEN TRIM(LOWER(i.interview_type)) LIKE '%hr%' THEN 'HR'
    -- ... 6+ more conditions
END as interview_category
```

**Issues**:
- Multiple TRIM/LOWER calls on same column
- LIKE pattern matching is slower than lookup table
- Brittle - depends on substring matching

**Better approach**:
```sql
-- Lookup table for categorization
LEFT JOIN dim_interview_types dit ON i.interview_type = dit.interview_type
SELECT ... dit.interview_category
```

❌ **Missing ORDER BY Optimization**
```sql
-- mart_active_applications ends with:
ORDER BY priority_score DESC, ap.application_date DESC
```

**Analysis**:
- ⚠️ Orders by calculated column (priority_score)
- ✅ Secondary sort by date is good for tie-breaking
- ⚠️ No LIMIT - returns all rows (could be 1000+ rows)

**Recommendation**:
```sql
SELECT ... 
FROM active_processes ap
-- ... joins ...
ORDER BY priority_score DESC, ap.application_date DESC
LIMIT 100  -- Return top 100 active applications for UI
```

### 3.2 DuckDB-Specific Patterns

**3.2.1 Date Arithmetic Issues**
```sql
-- In DuckDB, INTERVAL is type INTERVAL, not INTEGER
-- This works:
EXTRACT(DAY FROM (actual_date - scheduled_date)) as reschedule_days

-- This fails in DuckDB (works in PostgreSQL):
(actual_date - scheduled_date) > 5  -- Can't compare INTERVAL to INT
```

Current code uses `EXTRACT(DAY FROM ...)` correctly (✅).

**3.2.2 String Aggregation**
```sql
STRING_AGG(DISTINCT CASE WHEN i.status = 'completed' THEN i.interview_type END, ', ') 
  as interview_types_completed
```

**Analysis**:
- ✅ DuckDB supports STRING_AGG (PostgreSQL compatible)
- ✅ Handles DISTINCT properly
- ✅ Null-safe (ignores NULL interview_types)

**Alternative** (more performant):
```sql
GROUP_CONCAT(DISTINCT i.interview_type, ', ') as interview_types_completed
-- GROUP_CONCAT is DuckDB-native, might be faster
```

### 3.3 SQL Complexity Metrics

| File | Lines | CTEs | Joins | CASE Statements | Complexity |
|------|-------|------|-------|-----------------|------------|
| stg_companies.sql | 12 | 0 | 0 | 0 | Very Simple |
| int_companies.sql | 18 | 0 | 0 | 1 | Simple |
| int_interview_processes.sql | 50 | 1 | 1 | 2 | Moderate |
| mart_active_applications.sql | 208 | 3 | 2 | 4 | High |
| mart_monthly_stats.sql | 62 | 2 | 1 | 2 | Moderate |
| mart_interview_summary.sql | 52 | 1 | 5 | 1 | Moderate |

**Complexity Hotspot**: `mart_active_applications.sql` (208 lines)
- Contains business logic that should be split
- Next action logic could be a separate macro/model
- Priority scoring could be parameterized

---

## 4. Data Modeling - Star Schema Implementation

### 4.1 Current Schema Design

**Declared in** `sql/duckdb/01_create_star_schema.sql`

#### Dimension Tables
```sql
✅ dim_companies - Company information
   - company_key (surrogate), company_id (natural)
   - SCD Type 2 fields (effective_date, expiry_date, is_current)
   
✅ dim_job_positions - Position details
   - position_key (surrogate), position_id (natural)
   - SCD Type 2 fields
   
✅ dim_date - Time dimension
   - date_key, year, quarter, month, day_of_week
   - is_weekend, is_holiday
   
✅ dim_interview_types - Interview categorization
   - interview_type_key, interview_type, interview_category
   - typical_duration_minutes, description
   
✅ dim_application_sources - Source categorization
✅ dim_process_status - Status dimension with ordering
✅ dim_interviewers - Interviewer information (SCD Type 2)
```

**Fact Tables**
```sql
✅ fact_interview_processes - One row per application
   - process_id (natural key)
   - Foreign keys to all dimensions
   - Measures: total_interviews, process_duration_days, offer_salary
   
✅ fact_interviews - One row per interview
   - interview_id (natural key)
   - Foreign key to process fact table
   - Measures: duration_minutes, rating, interview_round
```

### 4.2 Schema Quality Assessment

**Strengths**:
- ✅ Proper surrogate key design (company_key vs company_id)
- ✅ SCD Type 2 for slowly changing dimensions (companies, positions)
- ✅ Separate fact tables for different granularities (process vs interview)
- ✅ Comprehensive foreign key constraints
- ✅ Good indexing strategy

**Issues**:

**Issue 1: Schema Not Populated**
The DDL is defined in `sql/duckdb/01_create_star_schema.sql` but:
- ❌ No actual population SQL exists
- ❌ No DBT models load data into dim/fact tables
- ❌ DBT models use different table names (stg_*, int_*, mart_*)

**Current approach**:
```
PostgreSQL → DBT Staging → DBT Intermediate → DBT Marts → DuckDB
(no star schema)
```

**Expected approach**:
```
PostgreSQL → DBT Staging → DBT Mart Dimensions → DuckDB Dim Tables
                         → DBT Mart Facts → DuckDB Fact Tables
```

**Recommendation**: Either:
1. **Implement the star schema** (align DBT output with DDL)
2. **Remove the DDL** (keep simplified DBT approach)

**Issue 2: Mart Tables Don't Use Facts**
- `mart_active_applications` queries staging/intermediate tables directly
- Doesn't use `fact_interview_processes` or `fact_interviews`
- Duplicates logic that should be in facts

```sql
-- Current
SELECT * FROM {{ ref('stg_interview_processes') }} p
LEFT JOIN {{ ref('stg_interviews') }} i ...

-- Should be
SELECT * FROM fact_interview_processes f
LEFT JOIN fact_interviews i ...
```

**Issue 3: Incomplete Dimension Design**
```sql
dim_date table defined but:
❌ Not populated (no date spine generated)
❌ Not used in fact tables
```

**Better approach**:
```sql
-- Generate date spine in DBT
-- dbt/models/marts/dim_date.sql
WITH date_range AS (
  SELECT generate_series(
    DATE '2020-01-01',
    CURRENT_DATE,
    INTERVAL '1 day'
  ) AS date
)
SELECT
  CAST(STRFTIME(date, '%Y%m%d') AS INTEGER) as date_key,
  date,
  YEAR(date) as year,
  ...
FROM date_range
```

### 4.3 Star Schema vs Current Approach

**Current Approach** (Simplified):
```
Staging (1:1 copy) → Intermediate (enriched) → Marts (aggregated)
```

**Pros**:
- ✅ Simpler to implement
- ✅ Easier to understand (less indirection)
- ✅ Works well for small datasets
- ✅ Fewer joins needed

**Cons**:
- ❌ Less reusable (marts are specific to use cases)
- ❌ Data redundancy (same logic repeated)
- ❌ Hard to add new marts without duplicating code

**Proper Star Schema Approach**:
```
Staging → Dimensions + Facts → Derived Marts (views on facts)
```

**Pros**:
- ✅ Single source of truth (fact tables)
- ✅ Reusable dimensions
- ✅ Scalable to many marts
- ✅ Better for data warehousing best practices

**Cons**:
- ❌ More complex (more tables)
- ❌ More joins required
- ❌ Slower for simple queries

**Recommendation**: Keep current simplified approach but:
1. Remove unused star schema DDL from `sql/duckdb/01_create_star_schema.sql`
2. Document why simplified approach was chosen
3. Plan migration path if schema complexity grows

---

## 5. Testing & Data Quality Checks

### 5.1 Test Coverage Summary

**Schema Tests** (Column-level):
```yaml
Unique: 8 columns tested
Not Null: 25+ columns tested
Accepted Values: 12+ columns tested
Relationships: 8+ foreign key tests
Expression Tests: 20+ custom expressions
```

**Data Quality Tests** (Custom):
```sql
1. test_recent_applications_exist - Data freshness
2. test_no_null_status_categories - Data integrity
3. test_no_orphaned_interviews - Referential integrity
4. test_potential_duplicate_companies - Duplicate detection
5. test_unusual_process_durations - Outlier detection
6. test_unusual_interview_durations - Outlier detection
7. test_no_future_application_dates - Logical consistency
8. test_completed_interviews_missing_ratings - Data completeness
9. test_offers_missing_salary_info - Business rule enforcement
10. test_currency_consistency - Cross-model validation
11. test_stale_applied_processes - Stale data detection
```

### 5.2 Test Quality Assessment

**Well-Designed Tests**:
✅ `test_no_orphaned_interviews`
```sql
-- Checks referential integrity across models
SELECT i.interview_id, i.process_id, 'Interview exists but process not found' as issue
FROM {{ ref('stg_interviews') }} i
LEFT JOIN {{ ref('stg_interview_processes') }} p ON i.process_id = p.id
WHERE p.id IS NULL
```

✅ `test_unusual_process_durations`
```sql
-- Identifies outliers (>180 days) for manual review
SELECT
  process_id, company_name, job_title,
  process_duration_days,
  'Process duration exceeds 180 days' as issue
FROM {{ ref('int_interview_outcomes') }}
WHERE process_duration_days > 180
```

**Issues with Current Tests**:

❌ `test_recent_applications_exist`
```sql
WHERE CURRENT_DATE - application_date <= 90
HAVING COUNT(*) = 0
-- This query has logic issues:
-- - WHERE clause filters for recent applications
-- - HAVING COUNT(*) = 0 will never match (contradictory)
-- - Should be: WHERE CURRENT_DATE - MAX(application_date) > 90
```

❌ `test_potential_duplicate_companies`
```sql
-- Test identifies duplicates but doesn't enforce unique company names
-- Should either:
-- 1. Add unique constraint (prevents duplicates)
-- 2. Merge duplicate company records in ETL
```

❌ `test_stale_applied_processes`
```sql
GROUP BY p.process_id, p.company_name, p.job_title, 
         p.application_date, p.days_since_application
-- Incomplete GROUP BY - missing other selected columns
-- Should list all non-aggregated columns
```

### 5.3 Missing Tests

**Critical Missing Tests**:

1. **Referential Integrity Between Staging & Intermediate**
```sql
-- Missing: Test that all staging rows are in intermediate
SELECT COUNT(*) FROM stg_companies WHERE id NOT IN (SELECT company_id FROM int_companies)
-- Should be 0
```

2. **Null Handling Completeness**
```sql
-- Missing: Test that COALESCE doesn't hide missing data
-- Example: After COALESCE(salary, 0), can't distinguish missing vs zero
```

3. **Temporal Consistency**
```sql
-- Missing: Test that created_at <= updated_at
SELECT * FROM int_companies WHERE created_at > updated_at
-- Should be empty
```

4. **Materialization Validation**
```sql
-- Missing: Test that tables are actually materialized
-- Should check that query returns rows immediately (not on-demand)
```

5. **Row Count Stability**
```sql
-- Missing: Test that row counts don't change unexpectedly
-- Example: Staging tables should have same count as PostgreSQL tables
```

### 5.4 Data Quality Metrics

**Coverage Score**: 7/10

| Category | Coverage | Status |
|----------|----------|--------|
| Schema Validation | 100% | ✅ Excellent |
| Referential Integrity | 60% | ⚠️ Good (missing cross-layer tests) |
| Data Completeness | 50% | ⚠️ Partial |
| Outlier Detection | 70% | ✅ Good |
| Temporal Validation | 40% | ❌ Missing |
| Uniqueness | 70% | ✅ Good |

---

## 6. Overall Assessment & Recommendations

### 6.1 Pros - Data Engineering Strengths

✅ **Well-Structured Medallion Architecture**
- Clear separation of concerns (staging → intermediate → marts)
- Proper table materialization
- Good documentation in YAML files

✅ **Comprehensive Data Quality**
- 15+ custom tests beyond basic schema validation
- Severity levels (error/warn) for test management
- Custom test logic with aggregations and joins

✅ **DuckDB as Analytics DB**
- Good choice for OLAP queries on small-to-medium datasets
- postgres_scanner extension works well for federation
- Columnar format efficient for analytical workloads

✅ **Well-Documented Schema**
- All columns have descriptions
- Test configurations clearly explain data constraints
- CLAUDE.md provides excellent context

✅ **Smart Business Logic Implementation**
- Priority scoring in mart_active_applications is well-thought-out
- Status categorization simplifies frontend logic
- Interview categorization helps with analysis

### 6.2 Cons - Areas for Improvement

❌ **Star Schema Mismatch**
- DDL defines star schema but DBT doesn't populate it
- Creates confusion about data model intent
- Decision: Either implement or remove

⚠️ **Query Complexity**
- mart_active_applications (208 lines) should be split
- Business logic could be in separate macros
- Next action determination is too centralized

⚠️ **Cross-DB Query Pattern**
- Full table extraction without filtering
- No incremental loading strategy
- Won't scale to large PostgreSQL datasets

⚠️ **Inconsistent Status Mapping**
- Process status vs outcome status use different values
- No centralized lookup table
- Hard to reason about status transitions

⚠️ **Missing Temporal Dimension**
- No effective dating logic implemented
- Can't track dimension changes over time
- SCD Type 2 fields defined but not used

### 6.3 Priority Recommendations

**High Priority** (Do First):
1. **Clarify star schema intent**
   - Either: Implement full star schema with DBT loading
   - Or: Remove `sql/duckdb/01_create_star_schema.sql` DDL
   
2. **Fix test_recent_applications_exist logic**
   ```sql
   -- Current is broken
   -- Fixed version:
   HAVING MAX(application_date) < CURRENT_DATE - INTERVAL '90 days'
   ```

3. **Create status dimension table**
   ```sql
   -- Centralize all status values in one table
   -- Reference from all models
   ```

**Medium Priority** (Do Next):
4. **Add missing tests**
   - Row count stability test
   - Temporal consistency test
   - Null handling validation

5. **Refactor mart_active_applications**
   ```sql
   -- Split into:
   -- - mart_active_applications (simple query)
   -- - macros/get_next_action.sql (complex logic)
   -- - macros/get_priority_score.sql (scoring logic)
   ```

6. **Add incremental materialization**
   ```sql
   {{ config(
     materialized='incremental',
     incremental_strategy='merge',
     unique_key='process_id'
   ) }}
   ```

**Low Priority** (Do Later):
7. **Implement SCD Type 2 logic**
   - Create slowly changing dimension models
   - Add effective_date/expiry_date logic

8. **Add query performance monitoring**
   - EXPLAIN ANALYZE critical queries
   - Add indexes to DuckDB staging tables
   - Monitor query execution times

9. **Optimize date type handling**
   - Ensure consistent DATE vs TIMESTAMP usage
   - Remove unnecessary casts
   - Simplify date arithmetic

### 6.4 Architecture Scorecard

| Dimension | Score | Notes |
|-----------|-------|-------|
| **Model Organization** | 9/10 | Clear three-layer structure, minor complexity |
| **Data Quality Tests** | 7/10 | Good coverage, some logic issues |
| **Query Optimization** | 6/10 | Works but room for performance gains |
| **Cross-DB Integration** | 7/10 | Good abstraction, could be more efficient |
| **Data Modeling** | 6/10 | Mixed approach (star schema mismatch) |
| **Documentation** | 9/10 | Excellent YAML docs, clear comments |
| **Scalability** | 5/10 | Works small, needs optimization for growth |
| **Maintainability** | 7/10 | Clear code structure, some complexity hotspots |

**Overall Score: 7.1/10** - Solid foundation with targeted improvements needed for production-grade data warehouse.

---

## 7. Specific Code Examples & Fixes

### 7.1 Fix: test_recent_applications_exist

**Current (Broken)**:
```sql
test: >
  SELECT
    'No applications in last 90 days' as issue,
    MAX(application_date) as last_application_date,
    CURRENT_DATE - MAX(application_date) as days_since_last_application
  FROM {{ ref('int_interview_processes') }}
  WHERE CURRENT_DATE - application_date <= 90
  HAVING COUNT(*) = 0
  -- PROBLEM: WHERE filters for recent apps, then HAVING looks for zero count
  -- This query always returns empty (contradictory logic)
```

**Fixed**:
```sql
test: >
  SELECT
    process_id,
    MAX(application_date) as last_application_date,
    'No applications in last 90 days' as issue
  FROM {{ ref('int_interview_processes') }}
  GROUP BY process_id
  HAVING MAX(application_date) < CURRENT_DATE - INTERVAL '90 days'
  -- Returns: Processes with no activity in 90+ days
```

### 7.2 Fix: Create Status Dimension

**New Model: `dbt/models/marts/dim_process_status.sql`**
```sql
{{ config(materialized='table') }}

SELECT
  status_key,
  status_name,
  status_code,
  status_group,  -- ACTIVE, CLOSED, WITHDRAWN
  sort_order,
  description
FROM (
  VALUES
    (1, 'applied', 'APL', 'ACTIVE', 1, 'Application submitted'),
    (2, 'screening', 'SCR', 'ACTIVE', 2, 'Screening round'),
    (3, 'interviewing', 'INT', 'ACTIVE', 3, 'Technical interviews'),
    (4, 'final_round', 'FIN', 'ACTIVE', 4, 'Final round interview'),
    (5, 'tech_test', 'TST', 'ACTIVE', 2.5, 'Technical test/challenge'),
    (6, 'offer', 'OFF', 'ACTIVE', 5, 'Offer received'),
    (7, 'accepted', 'ACC', 'CLOSED', 10, 'Offer accepted'),
    (8, 'rejected', 'REJ', 'CLOSED', 11, 'Rejected by company'),
    (9, 'ghosted', 'GHO', 'CLOSED', 12, 'No response (ghosted)'),
    (10, 'withdrew', 'WTH', 'WITHDRAWN', 13, 'Withdrew application'),
    (11, 'reminder', 'REM', 'ACTIVE', 2, 'Follow-up reminder set')
) AS status_values(
  status_key, status_name, status_code, status_group, 
  sort_order, description
)
```

**Update model to reference**:
```sql
-- int_interview_processes.sql
LEFT JOIN {{ ref('dim_process_status') }} dps 
  ON LOWER(ip.status) = dps.status_name
...
SELECT
  ...
  dps.status_key,
  dps.status_group,
  ...
```

### 7.3 Fix: Refactor mart_active_applications

**Extract next_action logic into macro**:
```sql
-- dbt/macros/get_next_action.sql
{% macro get_next_action(
    status,
    last_completed_date,
    next_scheduled_date,
    interview_types_scheduled,
    days_since_application
) %}
  CASE
    WHEN {{ status }} = 'offer' THEN 'Respond to offer'
    
    -- Scheduled interviews within 3 days
    WHEN {{ next_scheduled_date }} IS NOT NULL 
         AND {{ next_scheduled_date }}::DATE >= CURRENT_DATE
         AND ({{ next_scheduled_date }}::DATE - CURRENT_DATE) <= 3
    THEN CASE
      WHEN {{ interview_types_scheduled }} ILIKE '%technical%' 
        THEN 'Prepare technical interview'
      WHEN {{ interview_types_scheduled }} ILIKE '%phone%' 
        THEN 'Prepare phone screening'
      ELSE 'Prepare next interview'
    END
    
    -- Stale applications
    WHEN {{ status }} = 'applied' AND {{ days_since_application }} > 14
    THEN 'Follow up with company'
    
    ELSE 'Continue monitoring'
  END
{% endmacro %}

-- Usage in mart:
get_next_action(
  ap.current_status,
  ri.last_completed_interview_date,
  ri.next_scheduled_interview_date,
  ri.interview_types_scheduled,
  (CURRENT_DATE - ap.application_date)
) as next_action
```

### 7.4 Fix: Add Incremental Loading

**Update staging models**:
```sql
-- dbt/models/staging/stg_companies.sql
{{ config(
  materialized='incremental',
  unique_key='id',
  on_schema_change='fail'
) }}

SELECT
    id,
    name,
    industry,
    size,
    location,
    website,
    created_at,
    updated_at
FROM {{ postgres_scan('companies') }}

{% if execute %}
  -- Only fetch updated records in incremental runs
  WHERE 1=1
  {% if is_incremental() %}
    AND updated_at > (SELECT MAX(updated_at) FROM {{ this }})
  {% endif %}
{% endif %}
```

**Benefits**:
- ✅ Faster incremental runs (only new/changed records)
- ✅ Reduces network I/O from PostgreSQL
- ✅ Scales to larger datasets
- ✅ Better for production scheduling

---

## Conclusion

HireWire implements a **solid data engineering foundation** with clear architecture, good documentation, and comprehensive testing. The main opportunities for improvement are:

1. **Clarify data model intent** (star schema vs simplified)
2. **Optimize for scale** (incremental loading, query performance)
3. **Standardize status management** (centralized dimension)
4. **Refactor complex logic** (split large models)

The current approach works well for a small-to-medium sized dataset (<1M rows). As the application scales, implementing the recommended optimizations will ensure the data pipeline remains performant and maintainable.

**Estimated effort to address recommendations**:
- High priority fixes: 2-3 days
- Medium priority improvements: 1-2 weeks
- Low priority enhancements: 2-3 weeks
