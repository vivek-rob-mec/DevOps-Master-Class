from datetime import datetime,timezone

ALLOWED_SEVERITIES={"low","medium","high","critical"}

def matches(rule:dict,event:dict)->bool:
 return all(event.get(field)==value for field,value in rule.get("equals",{}).items()) and all(value in str(event.get(field,"")) for field,value in rule.get("contains",{}).items())

def detect(rules:list[dict],events:list[dict])->list[dict]:
 findings=[]
 for event in events:
  for rule in rules:
   if rule.get("enabled",True) and matches(rule,event):findings.append({"rule":rule["id"],"severity":rule["severity"],"event_id":event["id"],"owner":rule["owner"]})
 return findings

def validate_rule(rule:dict,today:datetime|None=None)->list[str]:
 today=today or datetime.now(timezone.utc);errors=[]
 for field in ("id","title","owner","severity","runbook","test_fixture","review_after"):
  if not rule.get(field):errors.append(f"missing {field}")
 if rule.get("severity") not in ALLOWED_SEVERITIES:errors.append("invalid severity")
 try:
  review=datetime.fromisoformat(str(rule.get("review_after","")).replace("Z","+00:00"))
  if review<today:errors.append("review overdue")
 except ValueError:errors.append("invalid review date")
 return errors
