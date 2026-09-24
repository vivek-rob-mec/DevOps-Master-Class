import unittest

from app.main import response_for


class ApiContractTests(unittest.TestCase):
    def test_health_contract(self):
        self.assertEqual(response_for("/healthz"), (200, {"status": "ok"}))

    def test_unknown_route_is_not_found(self):
        self.assertEqual(response_for("/missing")[0], 404)


if __name__ == "__main__":
    unittest.main()
