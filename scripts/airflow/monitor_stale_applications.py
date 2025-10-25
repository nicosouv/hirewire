#!/usr/bin/env python3
"""
Monitor stale applications in DuckDB
"""
import duckdb
import sys

def monitor_stale_applications():
    """Identify applications with no recent activity"""
    try:
        conn = duckdb.connect('/data/hirewire.duckdb', read_only=True)

        stale = conn.execute("""
            SELECT
                company_name,
                job_title,
                current_status,
                days_since_last_interview
            FROM mart_active_applications
            WHERE days_since_last_interview > 14
                AND days_since_last_interview IS NOT NULL
            ORDER BY days_since_last_interview DESC
        """).fetchall()

        if stale:
            print(f"⚠️  Found {len(stale)} stale applications (no activity in 14+ days):")
            for app in stale[:5]:  # Show top 5
                print(f"   - {app[0]} ({app[1]}): {app[3]} days since last interview")
            if len(stale) > 5:
                print(f"   ... and {len(stale) - 5} more")
        else:
            print("✅ No stale applications found")

        conn.close()
        print("✅ Stale applications check completed")
        return 0

    except Exception as e:
        print(f"❌ ERROR: Stale applications check failed: {str(e)}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(monitor_stale_applications())
