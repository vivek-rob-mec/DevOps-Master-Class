import json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from workflow.model import OrderState,apply

if len(sys.argv)!=2:raise SystemExit("usage: replay.py HISTORY.json")
history=json.loads(Path(sys.argv[1]).read_text());state=OrderState(history["workflow_id"])
for event in history["events"]:state=apply(state,event)
if state.status!=history["expected_status"]:raise SystemExit(f"expected {history['expected_status']}, got {state.status}")
print(json.dumps({"workflow_id":state.order_id,"status":state.status,"unique_events":len(state.processed_event_ids)},indent=2))
