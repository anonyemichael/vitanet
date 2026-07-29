from uuid import UUID
import traceback

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.schemas.user import UserSignupRequest, UserSignupResponse, UserOut, UserUpdate
from app.services import user_service, care_circle_service
from app.services.verify_care_email import send_care_circle_invite

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/signup", response_model=UserSignupResponse, status_code=status.HTTP_201_CREATED)
def signup(payload: UserSignupRequest, db: Session = Depends(get_db)):
    existing = user_service.get_user_by_firebase_uid(db, payload.user.firebase_uid)
    if existing:
        raise HTTPException(status_code=400, detail="User already exists")

    user = user_service.create_user(db, payload.user)
    care_circles = care_circle_service.create_care_circle_members(db, user.id, payload.care_circle)

    db.commit()
    db.refresh(user)

    for care_circle in care_circles:
        if care_circle.contact_email:
            try:
                send_care_circle_invite(
                    to_email=care_circle.contact_email,
                    requester_name=user.full_name,
                    invite_token=care_circle.invite_token,
                )
            except Exception as e:
                print("=" * 60)
                print("EMAIL SEND FAILED:")
                traceback.print_exc()
                print("=" * 60)

    return UserSignupResponse(user=user, care_circle_count=len(care_circles))


@router.get("/{user_id}", response_model=UserOut)
def get_user(user_id: UUID, db: Session = Depends(get_db)):
    user = user_service.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.get("/firebase/{firebase_uid}", response_model=UserOut)
def get_user_by_firebase(firebase_uid: str, db: Session = Depends(get_db)):
    user = user_service.get_user_by_firebase_uid(db, firebase_uid)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.patch("/{user_id}", response_model=UserOut)
def update_user(user_id: UUID, payload: UserUpdate, db: Session = Depends(get_db)):
    updates = payload.model_dump(exclude_unset=True)
    user = user_service.update_user(db, user_id, updates)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(user_id: UUID, db: Session = Depends(get_db)):
    deleted = user_service.delete_user(db, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="User not found")