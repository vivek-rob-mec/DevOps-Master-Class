from datetime import datetime,timezone

DESTRUCTIVE={"drop_table","drop_column","rewrite_table"}

def validate_manifest(entries:list[dict])->list[str]:
 errors=[];expected=1
 for entry in entries:
  if int(entry.get("sequence",-1))!=expected:errors.append(f"expected migration sequence {expected}")
  if entry.get("risk") in DESTRUCTIVE and not entry.get("backup_verified"):errors.append(f"migration {expected} requires verified backup")
  if not entry.get("rollback"):errors.append(f"migration {expected} requires rollback")
  expected+=1
 return errors

def recovery_point_allowed(target:str,oldest_restorable:str,now:str)->bool:
 def parse(value:str):return datetime.fromisoformat(value.replace("Z","+00:00")).astimezone(timezone.utc)
 target_time,oldest,now_time=parse(target),parse(oldest_restorable),parse(now)
 return oldest<=target_time<=now_time

def connection_budget(max_connections:int,reserved:int,pool_replicas:int)->int:
 if min(max_connections,pool_replicas)<=0 or reserved<0 or reserved>=max_connections:raise ValueError("invalid connection budget")
 return (max_connections-reserved)//pool_replicas
