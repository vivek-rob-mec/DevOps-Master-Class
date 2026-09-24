import unittest
from datetime import date
from delivery.flags import bucket,enabled,validate_flag,validate_steps

class DeliveryTests(unittest.TestCase):
 def test_bucketing_is_deterministic(self):self.assertEqual(bucket("customer-1"),bucket("customer-1"))
 def test_group_override(self):self.assertTrue(enabled({"state":"ENABLED","percentage":0,"includeGroups":["qa"]},"user",{"qa"}))
 def test_disabled_flag_is_safe(self):self.assertFalse(enabled({"state":"DISABLED","percentage":100},"user"))
 def test_governed_flag(self):
  flag={"owner":"team","ticket":"REL-1","expires":"2027-01-01","safeDefault":"off","percentage":10}
  self.assertEqual(validate_flag(flag,date(2026,8,16)),[])
 def test_expired_flag_fails(self):
  flag={"owner":"team","ticket":"REL-1","expires":"2025-01-01","safeDefault":"off","percentage":10}
  self.assertIn("flag expired",validate_flag(flag,date(2026,8,16)))
 def test_rollout_steps(self):self.assertEqual(validate_steps([5,20,50,100]),[])
 def test_non_monotonic_rollout_fails(self):self.assertIn("weights must increase",validate_steps([10,5,100]))

if __name__=="__main__":unittest.main()
