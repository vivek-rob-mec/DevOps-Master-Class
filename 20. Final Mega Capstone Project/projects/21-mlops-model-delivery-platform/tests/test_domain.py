import unittest
from platform_lib.domain import validate_features
class FeatureContractTests(unittest.TestCase):
 def test_accepts_four_numbers(self):self.assertEqual([1.0,2.0,3.0,4.0],validate_features([1,2,3,4]))
 def test_rejects_wrong_count(self):
  with self.assertRaisesRegex(ValueError,"INVALID_FEATURE_COUNT"):validate_features([1,2])
 def test_rejects_boolean(self):
  with self.assertRaisesRegex(ValueError,"INVALID_FEATURE"):validate_features([1,2,True,4])
if __name__=="__main__":unittest.main()
