from dataclasses import dataclass

LEVELS = {"beginner", "intermediate", "advanced"}

@dataclass(frozen=True)
class CourseDraft:
    title: str
    level: str
    capacity: int

def course_draft(payload: dict) -> CourseDraft:
    title = str(payload.get("title", "")).strip()
    level = str(payload.get("level", "beginner")).lower()
    try:
        capacity = int(payload.get("capacity", 0))
    except (TypeError, ValueError) as exc:
        raise ValueError("INVALID_CAPACITY") from exc
    if not 3 <= len(title) <= 160:
        raise ValueError("INVALID_TITLE")
    if level not in LEVELS:
        raise ValueError("INVALID_LEVEL")
    if not 1 <= capacity <= 10_000:
        raise ValueError("INVALID_CAPACITY")
    return CourseDraft(title, level, capacity)

def normalized_email(value: object) -> str:
    email = str(value or "").strip().lower()
    if len(email) > 254 or "@" not in email or "." not in email.rsplit("@", 1)[-1]:
        raise ValueError("INVALID_EMAIL")
    return email
