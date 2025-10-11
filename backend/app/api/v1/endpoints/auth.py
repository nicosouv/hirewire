"""
Authentication API endpoints.
"""
from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import (
    authenticate_user,
    create_access_token,
    get_password_hash,
    get_current_user
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse, Token, UserLogin

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user: UserCreate, db: Session = Depends(get_db)):
    """Register a new user."""
    # Check if user already exists
    existing_user = db.query(User).filter(User.email == user.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    # Create new user
    db_user = User(
        email=user.email,
        hashed_password=get_password_hash(user.password),
        first_name=user.first_name,
        last_name=user.last_name,
        is_active=user.is_active,
        is_superuser=user.is_superuser,
        is_airflow_admin=user.is_airflow_admin
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    return db_user


@router.post("/login", response_model=Token)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    """Login and get access token (OAuth2 compatible)."""
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={
            "sub": str(user.id),
            "email": user.email,
            "is_airflow_admin": user.is_airflow_admin
        },
        expires_delta=access_token_expires
    )

    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/login/json", response_model=Token)
def login_json(credentials: UserLogin, db: Session = Depends(get_db)):
    """Login with JSON body (alternative to form data)."""
    user = authenticate_user(db, credentials.email, credentials.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={
            "sub": str(user.id),
            "email": user.email,
            "is_airflow_admin": user.is_airflow_admin
        },
        expires_delta=access_token_expires
    )

    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me")
def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current user information with custom headers for Nginx auth."""
    from fastapi.responses import JSONResponse

    # Return JSON with custom headers for Nginx auth_request
    response = JSONResponse(
        content={
            "id": current_user.id,
            "email": current_user.email,
            "first_name": current_user.first_name,
            "last_name": current_user.last_name,
            "is_active": current_user.is_active,
            "is_superuser": current_user.is_superuser,
            "is_airflow_admin": current_user.is_airflow_admin,
            "created_at": current_user.created_at.isoformat(),
            "updated_at": current_user.updated_at.isoformat(),
            "full_name": current_user.full_name
        }
    )
    response.headers["X-User-Email"] = current_user.email
    response.headers["X-Is-Airflow-Admin"] = "true" if current_user.is_airflow_admin else "false"
    response.headers["X-User-ID"] = str(current_user.id)

    return response


@router.post("/test-token", response_model=UserResponse)
def test_token(current_user: User = Depends(get_current_user)):
    """Test if the token is valid."""
    return current_user
