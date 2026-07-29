from datetime import date, datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, model_validator

from app.enums import AccountType
from app.models.care_circle import Relationship


class CareCircleMemberInput(BaseModel):
    full_name: str
    contact_email: Optional[EmailStr] = None
    contact_phone: Optional[str] = None
    relationship: Relationship
    is_primary: bool = False

    @model_validator(mode="after")
    def check_contact_method(self):
        if not self.contact_email and not self.contact_phone:
            raise ValueError("At least one of contact_email or contact_phone is required")
        return self


class UserSignupInput(BaseModel):
    firebase_uid: str
    full_name: str
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    date_of_birth: Optional[date] = None
    account_type: AccountType

    @model_validator(mode="after")
    def check_contact_method(self):
        if not self.email and not self.phone_number:
            raise ValueError("At least one of email or phone_number is required")
        return self


class UserSignupRequest(BaseModel):
    user: UserSignupInput
    care_circle: List[CareCircleMemberInput] = []


class UserOut(BaseModel):
    id: UUID
    full_name: str
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    date_of_birth: Optional[date] = None
    account_type: AccountType
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UserSignupResponse(BaseModel):
    user: UserOut
    care_circle_count: int


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    date_of_birth: Optional[date] = None