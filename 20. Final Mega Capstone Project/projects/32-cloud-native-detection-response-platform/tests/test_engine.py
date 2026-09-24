import unittest
from datetime import datetime,timezone
from detections.engine import detect,validate_rule

RULE={"id":"R1","title":"shell","owner":"security","severity":"high","equals":{"event_type":"process_start","environment":"prod"},"contains":{"command":"/bin/sh"},"runbook":"runbook","test_fixture":"e1","review_after":"2027-01-01T00:00:00Z"}

class DetectionTests(unittest.TestCase):
 def test_expected_match(self):self.assertEqual(len(detect([RULE],[{"id":"e1","event_type":"process_start","environment":"prod","command":"/bin/sh"}])),1)
 def test_dev_event_is_suppressed_by_scope(self):self.assertEqual(detect([RULE],[{"id":"e2","event_type":"process_start","environment":"dev","command":"/bin/sh"}]),[])
 def test_disabled_rule_does_not_fire(self):
  rule={**RULE,"enabled":False};self.assertEqual(detect([rule],[{"id":"e1","event_type":"process_start","environment":"prod","command":"/bin/sh"}]),[])
 def test_rule_contract(self):self.assertEqual(validate_rule(RULE,datetime(2026,8,16,tzinfo=timezone.utc)),[])
 def test_overdue_review_fails(self):self.assertIn("review overdue",validate_rule({**RULE,"review_after":"2025-01-01T00:00:00Z"},datetime(2026,8,16,tzinfo=timezone.utc)))

if __name__=="__main__":unittest.main()
