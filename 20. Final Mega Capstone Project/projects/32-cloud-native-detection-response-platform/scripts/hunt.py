import json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from detections.engine import detect,validate_rule

if len(sys.argv)!=3:raise SystemExit("usage: hunt.py EVENTS.jsonl RULES.json")
events=[json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines() if line.strip()]
rules=json.loads(Path(sys.argv[2]).read_text())
errors={rule["id"]:validate_rule(rule) for rule in rules if validate_rule(rule)}
if errors:raise SystemExit(f"invalid rules: {errors}")
print(json.dumps({"events":len(events),"findings":detect(rules,events)},indent=2))
