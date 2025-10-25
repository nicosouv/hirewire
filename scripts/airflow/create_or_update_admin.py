#!/usr/bin/env python3
"""
Create or update Airflow admin user with fixed credentials.
Compatible with Airflow 3.x Simple Auth Manager.
"""

import os
import sys
from werkzeug.security import generate_password_hash

# Add Airflow to path
sys.path.insert(0, '/home/airflow/.local/lib/python3.13/site-packages')

def create_or_update_admin():
    username = os.environ.get('AIRFLOW_ADMIN_USERNAME', 'admin')
    password = os.environ.get('AIRFLOW_ADMIN_PASSWORD', 'admin')

    try:
        from airflow.auth.managers.simple.models.user import SimpleAuthManagerUser
        from airflow.utils.session import create_session

        # Hash password using werkzeug (compatible with Airflow Simple Auth)
        hashed_password = generate_password_hash(password, method='pbkdf2:sha256')

        with create_session() as session:
            # Check if user exists
            user = session.query(SimpleAuthManagerUser).filter(
                SimpleAuthManagerUser.username == username
            ).first()

            if user:
                # Update existing user
                user.password = hashed_password
                print(f"✅ Updated password for user '{username}'")
            else:
                # Create new user
                user = SimpleAuthManagerUser(
                    username=username,
                    password=hashed_password
                )
                session.add(user)
                print(f"✅ Created new user '{username}'")

            session.commit()
            print(f"👤 Credentials: {username} / {password}")
            print(f"🌐 Login at: http://localhost:8080")

    except ImportError as e:
        print(f"❌ Import error (Airflow modules not found): {e}")
        print("Make sure this script runs inside the Airflow container")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    create_or_update_admin()
