import json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from finops.model import budget_status,from_dict,missing_labels,recommendation,unit_cost

if len(sys.argv)!=3:raise SystemExit("usage: report.py ALLOCATIONS.json BUDGETS.json")
allocations=[from_dict(item) for item in json.loads(Path(sys.argv[1]).read_text())]
budgets=json.loads(Path(sys.argv[2]).read_text())
rows=[]
for item in allocations:
 product=item.labels.get("product");budget=budgets.get(product) if product else None
 status="unallocated" if not product else "unbudgeted" if budget is None else budget_status(item.monthly_cost,float(budget))
 rows.append({"name":item.name,"monthly_cost":item.monthly_cost,"unit_cost":unit_cost(item),"budget_status":status,"recommendation":recommendation(item),"missing_labels":missing_labels(item)})
print(json.dumps({"allocations":rows,"total":round(sum(item.monthly_cost for item in allocations),2)},indent=2))
