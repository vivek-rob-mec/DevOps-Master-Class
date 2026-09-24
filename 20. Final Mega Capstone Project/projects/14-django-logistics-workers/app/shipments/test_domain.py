import unittest
from .domain import parse_shipment

class ShipmentDomainTests(unittest.TestCase):
    def test_normalizes_shipment(self):
        self.assertEqual({"reference":"SHIP-1001","destination":"Bengaluru"},parse_shipment({"reference":" ship-1001 ","destination":" Bengaluru "}))
    def test_rejects_invalid_reference(self):
        with self.assertRaisesRegex(ValueError,"INVALID_SHIPMENT"):
            parse_shipment({"reference":"x","destination":"Bengaluru"})
