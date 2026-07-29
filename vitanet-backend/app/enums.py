# app/enums.py
from enum import Enum

class AccountType(str, Enum):
    PERSONAL_USER = "personal_user"
    HEALTHCARE_PROFESSIONAL = "healthcare_professional"


class MessageSender(str, Enum):
    USER = "user"
    ASSISTANT = "assistant"


class MessageType(str, Enum):
    TEXT = "text"
    CHECKIN = "checkin"
    TRIAGE_RESULT = "triage_result"


class ConversationStatus(str, Enum):
    ACTIVE = "active"
    CLOSED = "closed"


class DeviceType(str, Enum):
    THERMOMETER = "thermometer"
    BP_MONITOR = "bp_monitor"
    PULSE_OXIMETER = "pulse_oximeter"
    GLUCOMETER = "glucometer"
    SCALE = "scale"
    OTHER = "other"


class ConnectionStatus(str, Enum):
    CONNECTED = "connected"
    DISCONNECTED = "disconnected"


class MetricType(str, Enum):
    HEART_RATE = "heart_rate"
    BLOOD_PRESSURE_SYSTOLIC = "blood_pressure_systolic"
    BLOOD_PRESSURE_DIASTOLIC = "blood_pressure_diastolic"
    TEMPERATURE = "temperature"
    SPO2 = "spo2"
    WEIGHT = "weight"
    GLUCOSE = "glucose"


class MetricSource(str, Enum):
    MANUAL = "manual"
    DEVICE = "device"


class Language(str, Enum):
    ENGLISH = "en"
    AKAN = "ak"