import unittest
from finops.model import budget_status,from_dict,missing_labels,recommendation,unit_cost

def sample(**changes):
 data={"name":"checkout","monthly_cost":100,"requests":1000,"labels":{"owner":"payments","product":"shop","environment":"prod","cost_center":"cc-1"},"cpu_requested":4,"cpu_used":1.5};data.update(changes);return from_dict(data)

class FinOpsTests(unittest.TestCase):
 def test_unit_cost(self):self.assertEqual(unit_cost(sample()),0.1)
 def test_zero_volume_is_not_divided(self):self.assertIsNone(unit_cost(sample(requests=0)))
 def test_rightsizing_is_review_not_automatic(self):self.assertEqual(recommendation(sample(cpu_used=.4)),"review_downsize")
 def test_missing_attribution_is_visible(self):self.assertEqual(missing_labels(sample(labels={"owner":"payments"})),["cost_center","environment","product"])
 def test_budget_thresholds(self):
  self.assertEqual(budget_status(79,100),"healthy");self.assertEqual(budget_status(80,100),"warning");self.assertEqual(budget_status(100,100),"breach")
 def test_invalid_budget_rejected(self):
  with self.assertRaises(ValueError):budget_status(1,0)

if __name__=="__main__":unittest.main()
