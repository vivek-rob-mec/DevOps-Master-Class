from dataclasses import dataclass

REQUIRED_LABELS={"owner","product","environment","cost_center"}

@dataclass(frozen=True)
class Allocation:
 name:str
 monthly_cost:float
 requests:int
 labels:dict[str,str]
 cpu_requested:float
 cpu_used:float

def from_dict(item:dict)->Allocation:
 cost=float(item["monthly_cost"]);requests=int(item["requests"])
 if cost<0 or requests<0:raise ValueError("cost and requests must be non-negative")
 return Allocation(str(item["name"]),cost,requests,dict(item.get("labels",{})),float(item["cpu_requested"]),float(item["cpu_used"]))

def unit_cost(allocation:Allocation)->float|None:
 return None if allocation.requests==0 else round(allocation.monthly_cost/allocation.requests,6)

def utilization(allocation:Allocation)->float:
 if allocation.cpu_requested<=0:raise ValueError("cpu request must be positive")
 return allocation.cpu_used/allocation.cpu_requested

def recommendation(allocation:Allocation)->str:
 ratio=utilization(allocation)
 if ratio<0.2:return "review_downsize"
 if ratio>0.8:return "review_headroom"
 return "hold"

def missing_labels(allocation:Allocation)->list[str]:
 return sorted(label for label in REQUIRED_LABELS if not allocation.labels.get(label))

def budget_status(actual:float,budget:float)->str:
 if budget<=0:raise ValueError("budget must be positive")
 ratio=actual/budget
 return "breach" if ratio>=1 else "warning" if ratio>=0.8 else "healthy"
