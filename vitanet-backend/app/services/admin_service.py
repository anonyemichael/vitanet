from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import date, datetime

from app.models.user import User
from app.models.health_alert import HealthAlert, AlertStatus
from app.models.health_profile import HealthProfile
from app.enums import AccountType
from app.schemas.admin import HospitalStatsOut, AdminPatientOut, StaffInfoOut, WardInfoOut

def get_stats(db: Session) -> HospitalStatsOut:
    # Active patients = users with personal_user account type
    active_patients = db.query(func.count(User.id)).filter(User.account_type == AccountType.PERSONAL_USER).scalar() or 0
    
    # Staff on duty = users with healthcare_professional account type
    staff_on_duty = db.query(func.count(User.id)).filter(User.account_type == AccountType.HEALTHCARE_PROFESSIONAL).scalar() or 0
    
    # Mock some data for wards and system health since we don't have tables for these yet
    available_wards = 12
    system_health = "98%"
    
    return HospitalStatsOut(
        activePatients=active_patients,
        availableWards=available_wards,
        systemHealth=system_health,
        staffOnDuty=staff_on_duty
    )

def get_patients(db: Session) -> list[AdminPatientOut]:
    users = db.query(User).filter(User.account_type == AccountType.PERSONAL_USER).all()
    
    patients_out = []
    for user in users:
        # Calculate age if DOB exists
        age = None
        if user.date_of_birth:
            today = date.today()
            age = today.year - user.date_of_birth.year - ((today.month, today.day) < (user.date_of_birth.month, user.date_of_birth.day))
            
        # Get latest health profile for gender (if stored there) or just mock it based on profile if needed
        # We don't have gender in user model, so we'll leave as Unknown for now
        gender = "Unknown"
        
        # Get latest alert status
        latest_alert = db.query(HealthAlert).filter(HealthAlert.user_id == user.id).order_by(HealthAlert.created_at.desc()).first()
        status = "Stable"
        if latest_alert and latest_alert.status != AlertStatus.ACKNOWLEDGED:
            status = "Monitored" if latest_alert.severity == "watch" else "Critical"
            
        patients_out.append(
            AdminPatientOut(
                id=str(user.id)[:8].upper(),  # Short ID for display
                name=user.full_name,
                age=age,
                gender=gender,
                status=status,
                lastUpdated=user.updated_at
            )
        )
        
    return patients_out

def get_wards(db: Session) -> list[WardInfoOut]:
    # Mock data as we don't have a wards table yet
    return [
        WardInfoOut(name='Intensive Care Unit (ICU)', occupied=4, total=5, type='Critical'),
        WardInfoOut(name='Post-Operative Recovery', occupied=12, total=15, type='Standard'),
        WardInfoOut(name='Maternity Ward', occupied=2, total=10, type='Standard'),
    ]

def get_staff(db: Session) -> list[StaffInfoOut]:
    staff = db.query(User).filter(User.account_type == AccountType.HEALTHCARE_PROFESSIONAL).all()
    
    staff_out = []
    for s in staff:
        staff_out.append(
            StaffInfoOut(
                name=s.full_name,
                role="Healthcare Professional",
                status="On Duty"
            )
        )
    return staff_out
