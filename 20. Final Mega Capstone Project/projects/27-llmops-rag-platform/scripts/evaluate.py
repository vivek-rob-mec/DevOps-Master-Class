import json,pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).parents[1]));from llmops.policy import citation_coverage
dataset=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "eval/dataset.jsonl");scores=[]
for line in dataset.read_text().splitlines():
 item=json.loads(line);scores.append(citation_coverage(item["answer"],item["expected_document_ids"]))
result={"cases":len(scores),"mean_citation_coverage":round(sum(scores)/len(scores),4),"passed":bool(scores) and sum(scores)/len(scores)>=0.9};print(json.dumps(result,indent=2));raise SystemExit(0 if result["passed"] else 2)
