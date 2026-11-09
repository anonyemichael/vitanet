# app/database/seed_data.py
"""Seed the hospitals directory and a demo patient when the database is empty."""
import logging
from uuid import UUID

from sqlalchemy.orm import Session

from app.enums import AccountType
from app.models.care_circle import CareCircle, CareCircleStatus, Relationship
from app.models.hospital import Hospital
from app.models.user import User
from app.models.vitals import VitalReading, VitalType

logger = logging.getLogger(__name__)


def seed_hospital_data(db: Session):
    """Seed Ghanaian hospitals and the demo patient if missing."""
    # Ghanaian hospitals
    if db.query(Hospital).count() == 0:
        hospitals = [
            Hospital(
                name="Korle Bu Teaching Hospital",
                address="Guggisberg Ave, Korle Gonno, Accra",
                latitude=5.5369,
                longitude=-0.2285,
                phone_number="+233 30 267 4070",
                has_ambulance=True,
                ambulance_available=True,
                has_emergency_room=True,
            ),
            Hospital(
                name="Greater Accra Regional Hospital (Ridge)",
                address="Castle Rd, Ridge, Accra",
                latitude=5.5606,
                longitude=-0.1989,
                phone_number="+233 30 222 8382",
                has_ambulance=True,
                ambulance_available=True,
                has_emergency_room=True,
            ),
            Hospital(
                name="37 Military Hospital",
                address="Liberation Rd, 37 Station, Accra",
                latitude=5.5884,
                longitude=-0.1837,
                phone_number="+233 30 277 6111",
                has_ambulance=True,
                ambulance_available=False,
                has_emergency_room=True,
            ),
            Hospital(
                name="Komfo Anokye Teaching Hospital",
                address="Bantama Road, Kumasi",
                latitude=6.6980,
                longitude=-1.6288,
                phone_number="+233 32 202 2301",
                has_ambulance=True,
                ambulance_available=True,
                has_emergency_room=True,
            ),
        ]
        db.add_all(hospitals)
        db.commit()
        logger.info("Seeded %d regional hospitals", len(hospitals))

    # Demo patient, vitals and care circle
    demo_user_id = UUID("00000000-0000-0000-0000-000000000001")
    user = db.query(User).filter(User.id == demo_user_id).first()
    if not user:
        user = User(
            id=demo_user_id,
            firebase_uid="demo_user_uid",
            full_name="Kofi Annan",
            email="kofi.annan@vitanet.health",
            phone_number="+233244000111",
            account_type=AccountType.PERSONAL_USER,
        )
        db.add(user)
        db.commit()
        logger.info("Seeded demo user Kofi Annan")

    if db.query(CareCircle).filter(CareCircle.requester_id == demo_user_id).count() == 0:
        circle_members = [
            CareCircle(
                requester_id=demo_user_id,
                full_name="Sarah Mensah",
                contact_email="sarah.mensah@gmail.com",
                contact_phone="+233241234567",
                relationship=Relationship.FAMILY,
                is_primary=True,
                status=CareCircleStatus.ACCEPTED,
            ),
            CareCircle(
                requester_id=demo_user_id,
                full_name="Dr. Kwesi Appiah",
                contact_email="dr.appiah@korlebu.gov.gh",
                contact_phone="+233209876543",
                relationship=Relationship.DOCTOR,
                is_primary=False,
                status=CareCircleStatus.ACCEPTED,
            ),
            CareCircle(
                requester_id=demo_user_id,
                full_name="Ama Osei",
                contact_email="ama.osei@yahoo.com",
                contact_phone="+233275551234",
                relationship=Relationship.FRIEND,
                is_primary=False,
                status=CareCircleStatus.ACCEPTED,
            ),
        ]
        db.add_all(circle_members)
        db.commit()
        logger.info("Seeded %d care circle members", len(circle_members))

    if db.query(VitalReading).filter(VitalReading.user_id == demo_user_id).count() == 0:
        readings = [
            VitalReading(user_id=demo_user_id, vital_type=VitalType.HEART_RATE, value=74.0, source="device"),
            VitalReading(user_id=demo_user_id, vital_type=VitalType.BLOOD_OXYGEN, value=98.0, source="device"),
            VitalReading(user_id=demo_user_id, vital_type=VitalType.TEMPERATURE, value=36.8, source="device"),
            VitalReading(user_id=demo_user_id, vital_type=VitalType.BP_SYSTOLIC, value=120.0, source="device"),
            VitalReading(user_id=demo_user_id, vital_type=VitalType.BP_DIASTOLIC, value=80.0, source="device"),
            VitalReading(user_id=demo_user_id, vital_type=VitalType.RESPIRATORY_RATE, value=16.0, source="device"),
        ]
        db.add_all(readings)
        db.commit()
        logger.info("Seeded %d vitals readings for demo user", len(readings))

