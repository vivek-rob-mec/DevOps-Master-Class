import unittest
from reliability.budgets import Objectives,score
OBJECTIVES=Objectives(300,60,99.0)
class BudgetTests(unittest.TestCase):
 def test_passes_measured_objectives(self):self.assertTrue(score({"detection_seconds":30,"recovery_seconds":180,"data_loss_seconds":10,"successful_requests":999,"total_requests":1000},OBJECTIVES)["passed"])
 def test_fails_rto(self):self.assertFalse(score({"detection_seconds":30,"recovery_seconds":301,"data_loss_seconds":10,"successful_requests":999,"total_requests":1000},OBJECTIVES)["passed"])
 def test_rejects_invalid_counts(self):
  with self.assertRaises(ValueError):score({"detection_seconds":1,"recovery_seconds":1,"data_loss_seconds":1,"successful_requests":2,"total_requests":1},OBJECTIVES)
if __name__=="__main__":unittest.main()
