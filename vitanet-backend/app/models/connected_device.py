# app/models/connected_device.py
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Enum as SQLEnum
from sqlalchemy.sql import func

from app.database.base import Base
from app.enums import DeviceType


class ConnectedDevice(Base):
    __tablename__ = "connected_devices"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    device_name = Column(String(100), nullable=False)
    device_type = Column(SQLEnum(DeviceType, name="device_type_enum"), nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)