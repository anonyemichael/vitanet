# app/schemas/health_metric.py
from datetime import datetime
from pydantic import BaseModel, field_validator, model_validator
from app.enums import MetricType

# sane physiological bounds — reject obvious garbage/typos before they hit the DB
METRIC_RANGES: dict[MetricType, tuple[float, float]] = {
    MetricType.HEART_RATE: (20, 250),                 # bpm
    MetricType.BLOOD_PRESSURE_SYSTOLIC: (50, 260),     # mmHg
    MetricType.BLOOD_PRESSURE_DIASTOLIC: (30, 180),    # mmHg
    MetricType.TEMPERATURE: (30, 45),                  # °C
    MetricType.SPO2: (50, 100),                        # %
    MetricType.WEIGHT: (1, 400),                       # kg
    MetricType.GLUCOSE: (20, 700),                     # mg/dL
}

METRIC_UNITS: dict[MetricType, str] = {
    MetricType.HEART_RATE: "bpm",
    MetricType.BLOOD_PRESSURE_SYSTOLIC: "mmHg",
    MetricType.BLOOD_PRESSURE_DIASTOLIC: "mmHg",
    MetricType.TEMPERATURE: "°C",
    MetricType.SPO2: "%",
    MetricType.WEIGHT: "kg",
    MetricType.GLUCOSE: "mg/dL",
}


class HealthMetricCreate(BaseModel):
    device_id: int | None = None
    metric_type: MetricType
    value: float
    unit: str | None = None  # auto-filled from metric_type if not provided

    @model_validator(mode="after")
    def validate_value_and_unit(self):
        low, high = METRIC_RANGES[self.metric_type]
        if not (low <= self.value <= high):
            raise ValueError(
                f"{self.metric_type.value} of {self.value} is outside plausible range ({low}-{high})"
            )
        if self.unit is None:
            self.unit = METRIC_UNITS[self.metric_type]
        return self


class HealthMetricResponse(BaseModel):
    id: int
    user_id: int
    device_id: int | None
    metric_type: MetricType
    value: float
    unit: str
    recorded_at: datetime

    class Config:
        from_attributes = True