#!/usr/bin/env python3
"""Create Airflow admin user"""

import os
from airflow.www import app as application
from airflow import models, settings
from airflow.auth.managers.models.resource_details import DagAccessEntity

def create_user():
    username = os.environ.get('_AIRFLOW_WWW_USER_USERNAME', 'admin')
    password = os.environ.get('_AIRFLOW_WWW_USER_PASSWORD', 'admin')

    session = settings.Session()

    try:
        # Check if user already exists
        user = session.query(models.User).filter(
            models.User.username == username
        ).first()

        if user:
            print(f"User '{username}' already exists")
            return

        # Create new user
        user = models.User()
        user.username = username
        user.email = 'admin@hirewire.com'
        user.password = password
        user.first_name = 'Admin'
        user.last_name = 'User'

        session.add(user)
        session.commit()

        print(f"User '{username}' created successfully")

    except Exception as e:
        print(f"Error creating user: {e}")
        session.rollback()
    finally:
        session.close()

if __name__ == '__main__':
    create_user()
