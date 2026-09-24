from dataclasses import dataclass,field,replace

TRANSITIONS={
 "created":{"payment_authorized"},
 "payment_authorized":{"inventory_reserved","payment_released"},
 "inventory_reserved":{"shipped","inventory_released"},
 "inventory_released":{"payment_released"},
 "payment_released":{"cancelled"},
 "cancelled":set(),
 "shipped":set(),
}

@dataclass(frozen=True)
class OrderState:
 order_id:str
 status:str="created"
 processed_event_ids:frozenset[str]=field(default_factory=frozenset)

def apply(state:OrderState,event:dict)->OrderState:
 event_id=str(event["id"]);next_status=str(event["type"])
 if event_id in state.processed_event_ids:return state
 if next_status not in TRANSITIONS.get(state.status,set()):raise ValueError(f"invalid transition {state.status}->{next_status}")
 return replace(state,status=next_status,processed_event_ids=state.processed_event_ids|{event_id})

def retry_delay_seconds(attempt:int,base:int=2,cap:int=60)->int:
 if attempt<1:raise ValueError("attempt starts at one")
 return min(cap,base**(attempt-1))

def activity_key(workflow_id:str,activity_name:str)->str:
 if not workflow_id or not activity_name:raise ValueError("identity parts are required")
 return f"{workflow_id}:{activity_name}"
