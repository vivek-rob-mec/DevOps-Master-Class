import unittest
from domain import course_draft,normalized_email
class DomainTests(unittest.TestCase):
    def test_course_is_normalized(self): self.assertEqual(course_draft({"title":" Platform Engineering ","level":"advanced","capacity":"30"}).title,"Platform Engineering")
    def test_capacity_is_bounded(self):
        with self.assertRaisesRegex(ValueError,"INVALID_CAPACITY"):course_draft({"title":"A valid course","capacity":0})
    def test_email_is_normalized(self):self.assertEqual(normalized_email(" LEARNER@EXAMPLE.COM "),"learner@example.com")
if __name__=="__main__":unittest.main()
