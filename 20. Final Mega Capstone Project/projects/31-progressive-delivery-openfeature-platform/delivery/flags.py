import hashlib
from datetime import date

def bucket(key:str)->int:
 return int(hashlib.sha256(key.encode()).hexdigest()[:8],16)%100

def enabled(flag:dict,targeting_key:str,groups:set[str]|None=None)->bool:
 groups=groups or set()
 if flag.get("state")!="ENABLED":return False
 if groups.intersection(flag.get("includeGroups",[])):return True
 return bucket(targeting_key)<int(flag.get("percentage",0))

def validate_flag(flag:dict,today:date)->list[str]:
 errors=[]
 for field in ("owner","ticket","expires","safeDefault"):
  if not flag.get(field):errors.append(f"missing {field}")
 try:
  if date.fromisoformat(flag.get("expires","1900-01-01"))<today:errors.append("flag expired")
 except ValueError:errors.append("invalid expiry")
 if not 0<=int(flag.get("percentage",-1))<=100:errors.append("invalid percentage")
 return errors

def validate_steps(weights:list[int])->list[str]:
 errors=[]
 if not weights or weights[-1]!=100:errors.append("rollout must finish at 100")
 if any(weight<=0 or weight>100 for weight in weights):errors.append("weights must be within 1..100")
 if any(current>=following for current,following in zip(weights,weights[1:])):errors.append("weights must increase")
 return errors
