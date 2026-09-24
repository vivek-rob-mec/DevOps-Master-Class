import unittest
from meshguard.rules import evaluate,promotion_allowed,trust_domains_compatible

class MeshPolicyTests(unittest.TestCase):
 def test_complete_namespace_passes(self):
  controls={"strict_mtls","default_deny","explicit_allow","bounded_timeout","telemetry"}
  self.assertTrue(promotion_allowed({"shop":controls}))
 def test_missing_default_deny_fails(self):
  missing=evaluate({"shop":{"strict_mtls","explicit_allow","bounded_timeout","telemetry"}})
  self.assertEqual(missing["shop"],["default_deny"])
 def test_remote_trust_requires_alias(self):
  self.assertFalse(trust_domains_compatible("east.local","west.local",set()))
  self.assertTrue(trust_domains_compatible("east.local","west.local",{"west.local"}))
 def test_empty_inventory_is_rejected(self):
  with self.assertRaises(ValueError):evaluate({})

if __name__=="__main__":unittest.main()
