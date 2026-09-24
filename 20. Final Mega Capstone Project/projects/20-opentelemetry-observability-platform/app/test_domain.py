import unittest
from domain import parse_checkout
class CheckoutTests(unittest.TestCase):
 def test_normalizes(self):self.assertEqual("CART-1",parse_checkout({"cartId":" cart-1 ","items":2,"total":10}).cart_id)
 def test_rejects_empty_cart(self):
  with self.assertRaisesRegex(ValueError,"INVALID_CART"):parse_checkout({"cartId":"","items":2,"total":10})
if __name__=="__main__":unittest.main()
