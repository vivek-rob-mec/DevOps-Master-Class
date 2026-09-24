import unittest
from workflow.model import OrderState,activity_key,apply,retry_delay_seconds

class WorkflowModelTests(unittest.TestCase):
 def test_happy_path(self):
  state=OrderState("order-1");state=apply(state,{"id":"1","type":"payment_authorized"});state=apply(state,{"id":"2","type":"inventory_reserved"});state=apply(state,{"id":"3","type":"shipped"});self.assertEqual(state.status,"shipped")
 def test_duplicate_event_is_idempotent(self):
  state=apply(OrderState("order-1"),{"id":"1","type":"payment_authorized"});self.assertEqual(apply(state,{"id":"1","type":"payment_authorized"}),state)
 def test_invalid_transition_fails(self):
  with self.assertRaises(ValueError):apply(OrderState("order-1"),{"id":"1","type":"shipped"})
 def test_compensation_path(self):
  state=apply(OrderState("order-1"),{"id":"1","type":"payment_authorized"});state=apply(state,{"id":"2","type":"payment_released"});self.assertEqual(state.status,"payment_released")
 def test_full_cancellation_path(self):
  state=apply(OrderState("order-1"),{"id":"1","type":"payment_authorized"});state=apply(state,{"id":"2","type":"inventory_reserved"});state=apply(state,{"id":"3","type":"inventory_released"});state=apply(state,{"id":"4","type":"payment_released"});state=apply(state,{"id":"5","type":"cancelled"});self.assertEqual(state.status,"cancelled")
 def test_bounded_backoff(self):self.assertEqual(retry_delay_seconds(10),60)
 def test_activity_idempotency_key(self):self.assertEqual(activity_key("wf-1","charge"),"wf-1:charge")

if __name__=="__main__":unittest.main()
