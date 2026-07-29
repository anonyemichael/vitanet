# app/schemas/validators.py
import phonenumbers


def normalize_phone_number(v: str | None) -> str | None:
    if not v:
        return v
    try:
        parsed = phonenumbers.parse(v, None)
        if not phonenumbers.is_valid_number(parsed):
            raise ValueError("Invalid phone number")
        return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
    except phonenumbers.NumberParseException:
        raise ValueError("Invalid phone number format")