# app/database/seed_data.py
import logging
from sqlalchemy.orm import Session
from app.models.hospital_ops import (
    HospitalPatientRecord,
    HospitalCase,
    HospitalWard,
    HospitalEquipment,
    HospitalStaff,
)
from uuid import UUID
from app.models.hospital import Hospital
from app.models.user import User
from app.models.vitals import VitalReading, VitalType
from app.models.care_circle import CareCircle, CareCircleStatus, Relationship
from app.enums import AccountType

logger = logging.getLogger(__name__)


def seed_hospital_data(db: Session):
    """Seed initial clinical and hospital operational records if empty."""
    # 1. Wards
    if db.query(HospitalWard).count() == 0:
        wards = [
            HospitalWard(name="Emergency", occupied=68, total=80, ward_type="Critical"),
            HospitalWard(name="ICU", occupied=11, total=12, ward_type="Critical"),
            HospitalWard(name="Maternity", occupied=30, total=44, ward_type="Standard"),
            HospitalWard(name="Paediatrics", occupied=22, total=36, ward_type="Standard"),
            HospitalWard(name="General medicine", occupied=51, total=60, ward_type="Standard"),
        ]
        db.add_all(wards)
        db.commit()
        logger.info("Seeded %d hospital wards", len(wards))

    # 2. Equipment
    if db.query(HospitalEquipment).count() == 0:
        equip = [
            HospitalEquipment(name="Ventilators", status="6 of 9 free", tone="green"),
            HospitalEquipment(name="Oxygen supply", status="72% OK", tone="green"),
            HospitalEquipment(name="CT scanner", status="2 in queue", tone="amber"),
            HospitalEquipment(name="Defibrillator B", status="Service due", tone="danger"),
        ]
        db.add_all(equip)
        db.commit()
        logger.info("Seeded %d hospital equipment items", len(equip))

    # 3. Staff
    if db.query(HospitalStaff).count() == 0:
        staff_members = [
            HospitalStaff(
                name="Dr. Kwame Mensah",
                role="Emergency physician",
                status="With patient",
                department="Emergency",
                patients="2",
                shift="07–19",
                phone="Ext 201",
                license="MDC/RN/04712 · valid to Mar 2028",
                email="k.mensah@korlebu.gov.gh",
            ),
            HospitalStaff(
                name="Dr. Akosua Addo",
                role="Obstetrics registrar",
                status="Available",
                department="Maternity",
                patients="4",
                shift="07–19",
                phone="Ext 214",
                license="MDC/RN/03318 · valid to Jun 2027",
                email="a.addo@korlebu.gov.gh",
                photo="assets/images/photos/clinician_female.jpg",
            ),
            HospitalStaff(
                name="Nurse Esi Badu",
                role="Charge nurse, ED",
                status="With patient",
                department="Emergency",
                patients="6",
                shift="07–19",
                phone="Ext 230",
                license="NMC/RGN/22871 · valid to Jan 2027",
                email="e.badu@korlebu.gov.gh",
            ),
            HospitalStaff(
                name="Dr. Kojo Asare",
                role="Cardiology consultant",
                status="In theatre",
                department="Cardiology",
                patients="3",
                shift="08–17",
                phone="Ext 340",
                license="MDC/RN/01954 · valid to Sep 2027",
                email="k.asare@korlebu.gov.gh",
            ),
            HospitalStaff(
                name="Nurse Yaa Amponsah",
                role="Staff nurse, ICU",
                status="Available",
                department="ICU",
                patients="2",
                shift="07–19",
                phone="Ext 410",
                license="NMC/RGN/30442 · valid to Nov 2027",
                email="y.amponsah@korlebu.gov.gh",
            ),
            HospitalStaff(
                name="Dr. Selorm Dzidzienyo",
                role="Paediatric resident",
                status="With patient",
                department="Paediatrics",
                patients="5",
                shift="07–19",
                phone="Ext 512",
                license="MDC/RN/05207 · valid to Feb 2028",
                email="s.dzidzienyo@korlebu.gov.gh",
            ),
        ]
        db.add_all(staff_members)
        db.commit()
        logger.info("Seeded %d staff members", len(staff_members))

    # 4. Patient Records
    if db.query(HospitalPatientRecord).count() == 0:
        records = [
            HospitalPatientRecord(
                id="P-10233",
                name="Ama Kuffour",
                age=54,
                sex="F",
                location="Emergency · Bed 7",
                status="critical",
                diagnosis="Community-acquired pneumonia",
                allergy="Allergy: sulfonamides",
                vitals=[
                    {"label": "HR", "value": "118", "alert": True},
                    {"label": "BP", "value": "104/66", "alert": False},
                    {"label": "SpO2", "value": "88%", "alert": True},
                    {"label": "RR", "value": "28", "alert": True},
                ],
                timeline=[
                    {"time": "10:40", "text": "SpO2 88% for 3 min on 2 L oxygen. Alert raised.", "tone": "critical"},
                    {"time": "09:20", "text": "IV co-amoxiclav started. Blood cultures sent.", "tone": "action"},
                    {"time": "08:55", "text": "Chest X-ray: right lower lobe consolidation.", "tone": "action"},
                    {"time": "08:10", "text": "Arrived by ambulance. Productive cough 4 days.", "tone": "neutral"},
                ],
                note="Type 2 diabetic. Titrate oxygen to SpO2 94–98%. Consider HDU review if no improvement within the hour.",
                note_author="Dr. Mensah",
            ),
            HospitalPatientRecord(
                id="P-10241",
                name="Yaw Boateng",
                age=62,
                sex="M",
                location="Resus bay 2",
                status="critical",
                diagnosis="Suspected NSTEMI",
                allergy="Allergy: none known",
                vitals=[
                    {"label": "HR", "value": "108", "alert": True},
                    {"label": "BP", "value": "162/98", "alert": True},
                    {"label": "SpO2", "value": "95%", "alert": False},
                    {"label": "Temp", "value": "36.9", "alert": False},
                ],
                timeline=[
                    {"time": "10:12", "text": "hs-Troponin T 112 ng/L. Cardiology paged.", "tone": "critical"},
                    {"time": "09:58", "text": "Aspirin 300 mg given. GTN spray ×1, pain 7 → 4.", "tone": "action"},
                    {"time": "09:44", "text": "ECG: ST depression V4–V6.", "tone": "action"},
                    {"time": "09:31", "text": "Arrived. Alerted by daughter via VitaNet care circle.", "tone": "neutral"},
                ],
                note="Known hypertensive on amlodipine. Pain eased after GTN. Awaiting cardiology review for angiography. Keep nil by mouth.",
                note_author="Dr. Mensah",
            ),
            HospitalPatientRecord(
                id="P-10198",
                name="Kwesi Nyarko",
                age=47,
                sex="M",
                location="Ward B · Bed 3",
                status="observation",
                diagnosis="Cellulitis, left leg",
                allergy="Allergy: none known",
                vitals=[
                    {"label": "HR", "value": "92", "alert": False},
                    {"label": "BP", "value": "128/82", "alert": False},
                    {"label": "SpO2", "value": "98%", "alert": False},
                    {"label": "Temp", "value": "38.1", "alert": True},
                ],
                timeline=[
                    {"time": "09:30", "text": "IV ceftriaxone 2 g due. Not yet charted.", "tone": "critical"},
                    {"time": "06:00", "text": "Erythema margin marked. Spreading 2 cm overnight.", "tone": "action"},
                    {"time": "Yesterday", "text": "Admitted from ED.", "tone": "neutral"},
                ],
                note="Elevate limb. Repeat CRP in the morning. Switch to oral antibiotics once afebrile for 24 h.",
                note_author="Dr. Addo",
            ),
            HospitalPatientRecord(
                id="P-10238",
                name="Kofi Owusu",
                age=9,
                sex="M",
                location="Minors 4",
                status="stable",
                diagnosis="Distal radius fracture",
                allergy="Allergy: none known",
                vitals=[
                    {"label": "HR", "value": "96", "alert": False},
                    {"label": "BP", "value": "108/68", "alert": False},
                    {"label": "SpO2", "value": "99%", "alert": False},
                    {"label": "Pain", "value": "3/10", "alert": False},
                ],
                timeline=[
                    {"time": "10:05", "text": "Back slab applied. Neurovascularly intact.", "tone": "action"},
                    {"time": "09:40", "text": "X-ray: undisplaced distal radius fracture.", "tone": "action"},
                    {"time": "09:15", "text": "Fell from bicycle. Arrived with mother.", "tone": "neutral"},
                ],
                note="Fracture clinic in 7 days. Paracetamol and ibuprofen as needed. Safeguarding screen completed.",
                note_author="Nurse Badu",
            ),
            HospitalPatientRecord(
                id="P-10235",
                name="Abena Darko",
                age=71,
                sex="F",
                location="Waiting area",
                status="observation",
                diagnosis="Fall, query postural hypotension",
                allergy="Allergy: penicillin",
                vitals=[
                    {"label": "HR", "value": "64", "alert": False},
                    {"label": "BP", "value": "98/60", "alert": True},
                    {"label": "SpO2", "value": "97%", "alert": False},
                    {"label": "Temp", "value": "36.6", "alert": False},
                ],
                timeline=[
                    {"time": "09:50", "text": "Lying and standing BP requested.", "tone": "action"},
                    {"time": "09:30", "text": "Triaged: dizziness on standing, fall at home.", "tone": "neutral"},
                ],
                note="On bendroflumethiazide and ramipril. Check sodium and potassium. Falls risk: assist when mobilising.",
                note_author="Nurse Badu",
            ),
            HospitalPatientRecord(
                id="P-10177",
                name="Esi Mensah",
                age=33,
                sex="F",
                location="Ward A · Bed 12",
                status="recovering",
                diagnosis="Post laparoscopic appendicectomy",
                allergy="Allergy: none known",
                vitals=[
                    {"label": "HR", "value": "78", "alert": False},
                    {"label": "BP", "value": "118/74", "alert": False},
                    {"label": "SpO2", "value": "99%", "alert": False},
                    {"label": "Temp", "value": "36.8", "alert": False},
                ],
                timeline=[
                    {"time": "08:30", "text": "Tolerating diet. Mobilising independently.", "tone": "action"},
                    {"time": "Yesterday", "text": "Theatre: uncomplicated laparoscopic appendicectomy.", "tone": "neutral"},
                ],
                note="Likely discharge this afternoon with oral analgesia. Wound check at clinic in 10 days.",
                note_author="Dr. Asare",
            ),
            HospitalPatientRecord(
                id="P-10164",
                name="Nana Agyei",
                age=58,
                sex="M",
                location="Ward C · Bed 5",
                status="stable",
                diagnosis="Hyperglycaemia, type 2 diabetes",
                allergy="Allergy: none known",
                vitals=[
                    {"label": "HR", "value": "82", "alert": False},
                    {"label": "BP", "value": "136/84", "alert": False},
                    {"label": "SpO2", "value": "98%", "alert": False},
                    {"label": "BG", "value": "11.2", "alert": False},
                ],
                timeline=[
                    {"time": "07:00", "text": "Fasting glucose 11.2 mmol/L. Insulin regimen adjusted.", "tone": "action"},
                    {"time": "2 days ago", "text": "Admitted with glucose 24 mmol/L, no ketones.", "tone": "neutral"},
                ],
                note="Diabetes nurse education today. Plan discharge tomorrow if glucose stays under 12.",
                note_author="Dr. Addo",
            ),
            HospitalPatientRecord(
                id="P-10243",
                name="Amara Okafor",
                age=35,
                sex="F",
                location="Arriving · ETA 9 min",
                status="critical",
                diagnosis="Query meningitis",
                allergy="Allergy: penicillin",
                vitals=[
                    {"label": "HR", "value": "94", "alert": False},
                    {"label": "SpO2", "value": "97%", "alert": False},
                    {"label": "Temp", "value": "38.4", "alert": True},
                    {"label": "RR", "value": "20", "alert": False},
                ],
                timeline=[
                    {"time": "10:24", "text": "VitaNet triage: URGENT. Self-referred, en route.", "tone": "critical"},
                    {"time": "10:20", "text": "Reported fever, severe neck stiffness, photophobia.", "tone": "neutral"},
                ],
                note="Prepare side room and blood cultures. Penicillin allergy: use alternative empirical cover per protocol.",
                note_author="Dr. Mensah",
            ),
            HospitalPatientRecord(
                id="P-10244",
                name="Efua Asante",
                age=28,
                sex="F",
                location="Arriving · ETA 22 min",
                status="observation",
                diagnosis="Abdominal pain in pregnancy, 14 weeks",
                allergy="Allergy: none known",
                vitals=[
                    {"label": "HR", "value": "88", "alert": False},
                    {"label": "SpO2", "value": "99%", "alert": False},
                    {"label": "Temp", "value": "37.6", "alert": False},
                    {"label": "Pain", "value": "6/10", "alert": False},
                ],
                timeline=[
                    {"time": "10:38", "text": "VitaNet triage: DOCTOR. Self-referred.", "tone": "action"},
                    {"time": "10:35", "text": "Lower right abdominal pain 6 h, nausea, no vomiting.", "tone": "neutral"},
                ],
                note="Obstetrics registrar informed. Ultrasound slot requested on arrival.",
                note_author="Dr. Addo",
            ),
        ]
        db.add_all(records)
        db.commit()
        logger.info("Seeded %d patient records", len(records))

    # 5. Cases
    if db.query(HospitalCase).count() == 0:
        cases = [
            HospitalCase(id="C-2041", name_age="Yaw Boateng, 62 M", complaint="Chest pain", level="urgent", time="31 min", where="Resus bay 2", initials="KM", assignee="Dr. Mensah", status="waiting", record_id="P-10241"),
            HospitalCase(id="C-2043", name_age="Amara Okafor, 35 F", complaint="Fever, neck stiffness", level="urgent", time="ETA 9 min", where="Arriving", initials="—", assignee="Unassigned", status="waiting", record_id="P-10243"),
            HospitalCase(id="C-2044", name_age="Efua Asante, 28 F", complaint="Abdominal pain, pregnant", level="doctor", time="ETA 22 min", where="Arriving", initials="AA", assignee="Dr. Addo", status="waiting", record_id="P-10244"),
            HospitalCase(id="C-2038", name_age="Kofi Owusu, 9 M", complaint="Forearm injury", level="doctor", time="48 min", where="Minors 4", initials="EB", assignee="Nurse Badu", status="waiting", record_id="P-10238"),
            HospitalCase(id="C-2035", name_age="Abena Darko, 71 F", complaint="Dizziness, fall", level="routine", time="1 h 12 m", where="Waiting area", initials="EB", assignee="Nurse Badu", status="waiting", record_id="P-10235"),
            HospitalCase(id="C-2029", name_age="Ama Kuffour, 54 F", complaint="Pneumonia, low SpO2", level="urgent", time="2 h 32 m", where="Emergency · Bed 7", initials="KM", assignee="Dr. Mensah", status="treatment", record_id="P-10233"),
            HospitalCase(id="C-2017", name_age="Kwesi Nyarko, 47 M", complaint="Cellulitis, left leg", level="doctor", time="1 d 4 h", where="Ward B · Bed 3", initials="AA", assignee="Dr. Addo", status="treatment", record_id="P-10198"),
            HospitalCase(id="C-2009", name_age="Nana Agyei, 58 M", complaint="High blood glucose", level="routine", time="2 d 3 h", where="Ward C · Bed 5", initials="AA", assignee="Dr. Addo", status="treatment", record_id="P-10164"),
            HospitalCase(id="C-2011", name_age="Esi Mensah, 33 F", complaint="Appendicitis, post-op", level="doctor", time="1 d 22 h", where="Ward A · Bed 12", initials="KA", assignee="Dr. Asare", status="treatment", record_id="P-10177"),
            HospitalCase(id="C-2032", name_age="Kojo Antwi, 24 M", complaint="Ankle sprain", level="routine", time="09:52", where="Home, follow-up GP", initials="EB", assignee="Nurse Badu", status="discharged"),
            HospitalCase(id="C-2027", name_age="Akua Sarpong, 41 F", complaint="Migraine", level="routine", time="08:40", where="Home", initials="KM", assignee="Dr. Mensah", status="discharged"),
            HospitalCase(id="C-2020", name_age="Fiifi Quaye, 66 M", complaint="Asthma exacerbation", level="doctor", time="07:15", where="Home, inhaler plan", initials="AA", assignee="Dr. Addo", status="discharged"),
        ]
        db.add_all(cases)
        db.commit()
        logger.info("Seeded %d hospital cases", len(cases))

    # 6. Ghanaian Hospitals
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

    # 7. Demo Patient User, Vitals & Care Circle
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

