import unittest
from dbguard.plan import connection_budget,recovery_point_allowed,validate_manifest

class DatabaseGuardTests(unittest.TestCase):
 def test_safe_manifest(self):
  entries=[{"sequence":1,"risk":"additive","backup_verified":False,"rollback":"drop new table"},{"sequence":2,"risk":"drop_column","backup_verified":True,"rollback":"restore old column"}]
  self.assertEqual(validate_manifest(entries),[])
 def test_destructive_change_needs_backup(self):
  errors=validate_manifest([{"sequence":1,"risk":"drop_table","rollback":"restore"}]);self.assertIn("migration 1 requires verified backup",errors)
 def test_sequence_gap_is_rejected(self):self.assertIn("expected migration sequence 1",validate_manifest([{"sequence":2,"risk":"additive","rollback":"drop"}]))
 def test_pitr_window(self):
  self.assertTrue(recovery_point_allowed("2026-08-10T10:00:00Z","2026-08-01T00:00:00Z","2026-08-16T00:00:00Z"))
  self.assertFalse(recovery_point_allowed("2026-07-10T10:00:00Z","2026-08-01T00:00:00Z","2026-08-16T00:00:00Z"))
 def test_connection_budget(self):self.assertEqual(connection_budget(300,30,3),90)

if __name__=="__main__":unittest.main()
