import resend

from app.core.config import settings

resend.api_key = settings.RESEND_API_KEY


def send_care_circle_invite(to_email: str, requester_name: str, invite_token: str):
    base_url = "https://dreaded-bagpipe-trapped.ngrok-free.dev"
    accept_url = f"{base_url}/care-circles/respond?token={invite_token}&action=accept"
    reject_url = f"{base_url}/care-circles/respond?token={invite_token}&action=reject"

    resend.Emails.send({
        "from": "VitaNet <onboarding@resend.dev>",
        "to": [to_email],
        "subject": f"{requester_name} added you to their care circle",
        "html": f"""
            <p><strong>{requester_name}</strong> has added you as an emergency health contact on VitaNet.</p>
            <p>If you accept, you'll receive important health alerts if they need assistance.</p>
            <p>
                <a href="{accept_url}" style="padding:10px 20px;background:#16a34a;color:white;text-decoration:none;border-radius:6px;margin-right:10px;">Accept</a>
                <a href="{reject_url}" style="padding:10px 20px;background:#dc2626;color:white;text-decoration:none;border-radius:6px;">Decline</a>
            </p>
        """,
    })
    
# # app/services/email.py
# def send_care_circle_invite(to_email: str, requester_name: str, invite_token: str):
#     print(f"[EMAIL STUB] Would send invite to {to_email} from {requester_name}, token={invite_token}")