import json, tempfile, unittest
from pathlib import Path
from platform_lib.contracts import validate_file

ROOT = Path(__file__).parents[1]
class ContractTests(unittest.TestCase):
    def test_sample_events_satisfy_contract(self):
        values = validate_file(ROOT / "contracts/order-event.schema.json", ROOT / "data/raw/orders.jsonl")
        self.assertEqual(3, len(values))
    def test_negative_amount_is_rejected(self):
        event = {"event_id":"8ea0485f-d48a-4f62-85e1-83cd49ccb2e3","event_time":"2026-08-16T08:00:00Z","customer_id":"C-1","country":"IN","amount":-1,"currency":"INR"}
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "bad.jsonl"
            target.write_text(json.dumps(event), encoding="utf-8")
            with self.assertRaises(ValueError):
                validate_file(ROOT / "contracts/order-event.schema.json", target)
if __name__ == "__main__": unittest.main()
