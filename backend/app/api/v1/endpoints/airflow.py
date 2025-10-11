"""
Airflow-specific API endpoints for Nginx auth_request integration.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response

from app.core.security import get_current_user
from app.models.user import User

router = APIRouter()


@router.get("/validate")
def validate_airflow_access(current_user: User = Depends(get_current_user)):
    """
    Validate if the current user has Airflow admin access.

    This endpoint is specifically designed for Nginx auth_request.
    - Returns 200 OK if user has is_airflow_admin = True
    - Returns 403 Forbidden if user does not have Airflow admin privileges
    - Returns 401 Unauthorized if token is invalid (handled by get_current_user)
    """
    if not current_user.is_airflow_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Airflow admin privileges required"
        )

    # Return 200 OK with minimal response for Nginx
    return Response(status_code=status.HTTP_200_OK, content="OK")
