# app/schemas/chat_blocks.py
from typing import Literal, Union, Optional
from pydantic import BaseModel


class TextBlock(BaseModel):
    type: Literal["text"] = "text"
    content: str


class HospitalRecommendationBlock(BaseModel):
    type: Literal["hospital_recommendation"] = "hospital_recommendation"
    name: str
    distance_km: float
    est_time_min: Optional[int] = None
    crowd_level: Optional[str] = None
    address: Optional[str] = None


class VitalCheckLoadingBlock(BaseModel):
    type: Literal["vital_check_loading"] = "vital_check_loading"
    vital_type: str
    label: str


class VitalResultBlock(BaseModel):
    type: Literal["vital_result"] = "vital_result"
    vital_type: str
    label: str
    value: float
    unit: str
    status: str
    min_value: Optional[float] = None
    avg_value: Optional[float] = None
    max_value: Optional[float] = None
    trend_points: Optional[list[dict]] = None


class ActionButton(BaseModel):
    label: str
    action: str
    target_id: Optional[str] = None


class ActionButtonsBlock(BaseModel):
    type: Literal["action_buttons"] = "action_buttons"
    buttons: list[ActionButton]


class StatItem(BaseModel):
    label: str
    value: str


class GenericCardBlock(BaseModel):
    type: Literal["generic_card"] = "generic_card"
    icon: Optional[str] = None
    title: str
    subtitle: Optional[str] = None
    stats: Optional[list[StatItem]] = None


class GenericListBlock(BaseModel):
    type: Literal["generic_list"] = "generic_list"
    title: str
    items: list[StatItem]


class GenericLoadingBlock(BaseModel):
    type: Literal["generic_loading"] = "generic_loading"
    label: str
    percent: Optional[int] = None


ChatBlock = Union[
    TextBlock,
    HospitalRecommendationBlock,
    VitalCheckLoadingBlock,
    VitalResultBlock,
    ActionButtonsBlock,
    GenericCardBlock,
    GenericListBlock,
    GenericLoadingBlock,
]