from uuid import uuid4

from sqlalchemy import Column, String, DateTime, Date, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from app.enums import AccountType
from app.database.base import Base


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)

    firebase_uid = Column(String(128), unique=True, index=True, nullable=False)

    full_name = Column(String(150), nullable=False)

    email = Column(String(255), unique=True, index=True, nullable=True)

    phone_number = Column(String(20), unique=True, index=True, nullable=True)

    date_of_birth = Column(Date, nullable=True)

    account_type = Column(
        SQLEnum(AccountType, name="account_type_enum"),
        nullable=False,
    )

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    def __repr__(self):
        return f"<User id={self.id} firebase_uid={self.firebase_uid!r} account_type={self.account_type!r}>"