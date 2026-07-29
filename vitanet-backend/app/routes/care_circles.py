from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session

from app.models.care_circle_activity import ActivityType
from app.services import care_circle_activity_service

from app.schemas.care_circle_activity import CareCircleActivityOut


from app.database.connection import get_db
from app.models.care_circle import CareCircleStatus
from app.schemas.care_circle import CareCircleOut, CareCircleUpdate
from app.services import care_circle_service

from app.models.care_circle_activity import ActivityType
from app.services import care_circle_activity_service


router = APIRouter(prefix="/care-circles", tags=["care-circles"])


def render_response_page(success: bool, title: str, message: str) -> str:
    color = "#16a34a" if success else "#dc2626"
    icon = "✓" if success else "✕"
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>VitaNet</title>
        <style>
            body {{
                margin: 0;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                background: #f8fafc;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                padding: 24px;
                box-sizing: border-box;
            }}
            .card {{
                background: #ffffff;
                border-radius: 16px;
                box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);
                padding: 40px 32px;
                max-width: 420px;
                width: 100%;
                text-align: center;
            }}
            .icon {{
                width: 64px;
                height: 64px;
                border-radius: 50%;
                background: {color};
                color: white;
                font-size: 32px;
                line-height: 64px;
                margin: 0 auto 20px;
            }}
            h1 {{
                font-size: 20px;
                color: #0f172a;
                margin: 0 0 12px;
            }}
            p {{
                font-size: 15px;
                color: #64748b;
                line-height: 1.5;
                margin: 0;
            }}
            .brand {{
                margin-top: 28px;
                font-size: 13px;
                color: #94a3b8;
                letter-spacing: 0.5px;
            }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="icon">{icon}</div>
            <h1>{title}</h1>
            <p>{message}</p>
            <div class="brand">VitaNet</div>
        </div>
    </body>
    </html>
    """


@router.get("/user/{user_id}", response_model=list[CareCircleOut])
def list_care_circle_for_user(user_id: UUID, db: Session = Depends(get_db)):
    return care_circle_service.get_care_circle_for_user(db, user_id)


@router.get("/respond")
def respond_to_invite(token: str, action: str, db: Session = Depends(get_db)):
    if action not in ("accept", "reject"):
        return HTMLResponse(
            render_response_page(
                success=False,
                title="Invalid link",
                message="This invite link isn't valid.",
            ),
            status_code=400,
        )

    new_status = CareCircleStatus.ACCEPTED if action == "accept" else CareCircleStatus.REJECTED
    care_circle = care_circle_service.update_care_circle_status(db, token, new_status)
    if not care_circle:
        return HTMLResponse(
            render_response_page(
                success=False,
                title="Link expired",
                message="This invite link is invalid or has already been used.",
            ),
            status_code=404,
        )

    if action == "accept":
        care_circle_activity_service.create_activity(
            db,
            user_id=care_circle.requester_id,
            care_circle_id=care_circle.id,
            activity_type=ActivityType.CONTACT_ADDED,
            title=f"{care_circle.full_name} is now one of your emergency health contacts",
            message=f"{care_circle.full_name} accepted your invitation and will be notified if you need assistance.",
        )
        db.commit()
        return HTMLResponse(
            render_response_page(
                success=True,
                title="Invite accepted",
                message=f"You're now one of {care_circle.full_name}'s emergency health contacts.",
            )
        )
    else:
        care_circle_activity_service.create_activity(
            db,
            user_id=care_circle.requester_id,
            care_circle_id=care_circle.id,
            activity_type=ActivityType.CONTACT_REJECTED,
            title=f"{care_circle.full_name} declined your invitation",
            message=f"{care_circle.full_name} declined to join your care circle.",
        )
        db.commit()
        return HTMLResponse(
            render_response_page(
                success=False,
                title="Invite declined",
                message="You've declined the invitation.",
            )
        )


@router.get("/activity/{user_id}", response_model=list[CareCircleActivityOut])
def get_activity_feed(user_id: UUID, db: Session = Depends(get_db)):
    return care_circle_activity_service.get_activity_for_user(db, user_id)


@router.get("/{care_circle_id}", response_model=CareCircleOut)
def get_care_circle(care_circle_id: UUID, db: Session = Depends(get_db)):
    care_circle = care_circle_service.get_care_circle_by_id(db, care_circle_id)
    if not care_circle:
        raise HTTPException(status_code=404, detail="Care circle member not found")
    return care_circle


@router.patch("/{care_circle_id}", response_model=CareCircleOut)
def update_care_circle(care_circle_id: UUID, payload: CareCircleUpdate, db: Session = Depends(get_db)):
    updates = payload.model_dump(exclude_unset=True)
    care_circle = care_circle_service.update_care_circle_member(db, care_circle_id, updates)
    if not care_circle:
        raise HTTPException(status_code=404, detail="Care circle member not found")
    return care_circle


@router.delete("/{care_circle_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_care_circle(care_circle_id: UUID, db: Session = Depends(get_db)):
    deleted = care_circle_service.delete_care_circle_member(db, care_circle_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Care circle member not found")