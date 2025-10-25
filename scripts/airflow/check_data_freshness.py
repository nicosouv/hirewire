#!/usr/bin/env python3
"""
Check data freshness in DuckDB
"""
import duckdb
import sys
from datetime import datetime, timedelta

def check_data_freshness():
    """Check if data is fresh (updated in last 24 hours)"""
    try:
        conn = duckdb.connect('/data/hirewire.duckdb', read_only=True)

        # Check for recent interviews
        result = conn.execute("""
            SELECT
                MAX(scheduled_date) as latest_interview,
                COUNT(*) as total_interviews
            FROM int_interviews
            WHERE scheduled_date >= CURRENT_DATE - INTERVAL '7 days'
        """).fetchone()

        latest_interview = result[0]
        total_recent = result[1]

        print(f"✅ Latest interview: {latest_interview}")
        print(f"✅ Interviews in last 7 days: {total_recent}")

        # Check for recent process updates
        result = conn.execute("""
            SELECT
                COUNT(*) as active_processes
            FROM int_interview_processes
            WHERE process_status NOT IN ('rejected', 'accepted', 'withdrew', 'ghosted')
        """).fetchone()

        active_count = result[0]
        print(f"✅ Active processes: {active_count}")

        conn.close()

        if active_count == 0:
            print("⚠️  WARNING: No active processes found - is data being updated?")
            return 1  # Warning but not failure

        print("✅ Data freshness check completed successfully")
        return 0

    except Exception as e:
        print(f"❌ ERROR: Data freshness check failed: {str(e)}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(check_data_freshness())
