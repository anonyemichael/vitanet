# app/schemas/connected_device.py
from datetime import datetime
from pydantic import BaseModel, Field
from app.enums import DeviceType


class ConnectedDeviceCreate(BaseModel):
    device_name: str = Field(min_length=1, max_length=100)
    device_type: DeviceType


class ConnectedDeviceResponse(BaseModel):
    id: int
    user_id: int
    device_name: str
    device_type: DeviceType
    created_at: datetime

    class Config:
        from_attributes = True