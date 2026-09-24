import json,pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).parents[1]));from reliability.budgets import Objectives,score
if len(sys.argv)!=2:raise SystemExit("usage: score_game_day.py evidence.json")
evidence=json.loads(pathlib.Path(sys.argv[1]).read_text());result=score(evidence,Objectives(rto_seconds=300,rpo_seconds=60,availability_percent=99.0));print(json.dumps(result,indent=2));raise SystemExit(0 if result["passed"] else 2)
