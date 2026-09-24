import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from delivery.flags import enabled
flag=json.loads(Path("flags/governance.json").read_text())["checkout-v2"]
population=[f"customer-{index}" for index in range(1000)]
exposed=sum(enabled(flag,key) for key in population)
print(json.dumps({"population":len(population),"exposed":exposed,"observedPercent":round(exposed/len(population)*100,1)},indent=2))
