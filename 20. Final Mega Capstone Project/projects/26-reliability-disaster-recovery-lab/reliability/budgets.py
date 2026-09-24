from dataclasses import dataclass
@dataclass(frozen=True)
class Objectives:rto_seconds:int;rpo_seconds:int;availability_percent:float
def score(evidence,objectives):
 required={"detection_seconds","recovery_seconds","data_loss_seconds","successful_requests","total_requests"}
 missing=required-evidence.keys()
 if missing:raise ValueError("missing evidence: "+",".join(sorted(missing)))
 total=int(evidence["total_requests"]);successful=int(evidence["successful_requests"])
 if total<=0 or not 0<=successful<=total:raise ValueError("invalid request counts")
 availability=100*successful/total
 checks={"detected":evidence["detection_seconds"]<=60,"rto_met":evidence["recovery_seconds"]<=objectives.rto_seconds,"rpo_met":evidence["data_loss_seconds"]<=objectives.rpo_seconds,"availability_met":availability>=objectives.availability_percent}
 return {"availability_percent":round(availability,4),"checks":checks,"passed":all(checks.values())}
