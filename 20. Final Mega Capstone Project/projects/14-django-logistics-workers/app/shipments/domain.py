import re

def parse_shipment(payload):
    reference=str(payload.get("reference","")).strip().upper()
    destination=str(payload.get("destination","")).strip()
    if not re.fullmatch(r"[A-Z0-9-]{4,64}",reference) or not 3<=len(destination)<=160:
        raise ValueError("INVALID_SHIPMENT")
    return {"reference":reference,"destination":destination}
