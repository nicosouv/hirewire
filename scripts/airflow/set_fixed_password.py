#!/usr/bin/env python3
"""
Set fixed password for Airflow admin user.
Works with Airflow 3.x Simple Auth Manager by directly updating the database.
"""

import psycopg2
import os
from werkzeug.security import generate_password_hash

def set_fixed_password():
    username = os.environ.get('AIRFLOW_ADMIN_USERNAME', 'admin')
    password = os.environ.get('AIRFLOW_ADMIN_PASSWORD', 'admin')

    # Hash password using werkzeug pbkdf2:sha256 (compatible with Airflow Simple Auth)
    hashed_password = generate_password_hash(password, method='pbkdf2:sha256')

    # Connect to Airflow metadata DB
    conn_params = {
        'host': 'airflow-postgres',
        'port': 5432,
        'database': 'airflow',
        'user': 'airflow',
        'password': os.environ.get('AIRFLOW_POSTGRES_PASSWORD', 'airflow')
    }

    try:
        conn = psycopg2.connect(**conn_params)
        cur = conn.cursor()

        # Update password in simple_auth_manager_user table
        cur.execute("""
            UPDATE simple_auth_manager_user
            SET password = %s
            WHERE username = %s
        """, (hashed_password, username))

        rows_updated = cur.rowcount

        if rows_updated == 0:
            print(f"⚠️  User '{username}' not found in database")
            print("   User will be created on first webserver start")
        else:
            print(f"✅ Password updated for user '{username}'")

        conn.commit()
        cur.close()
        conn.close()

        print(f"👤 Credentials: {username} / {password}")
        print(f"🌐 Login at: http://localhost:8080")

    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        exit(1)

if __name__ == '__main__':
    set_fixed_password()
