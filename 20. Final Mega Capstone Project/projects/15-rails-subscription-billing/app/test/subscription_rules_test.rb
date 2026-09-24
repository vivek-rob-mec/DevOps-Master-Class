require "minitest/autorun"
require_relative "../app/domain/subscription_rules"
class SubscriptionRulesTest < Minitest::Test
  def test_normalizes_values
    value = SubscriptionRules.parse(account_name: " Acme ", owner_email: "OWNER@EXAMPLE.COM", plan: "growth")
    assert_equal "Acme", value.account_name
    assert_equal "owner@example.com", value.owner_email
  end
  def test_rejects_unknown_plan
    assert_raises(ArgumentError) { SubscriptionRules.parse(account_name: "Acme", owner_email: "o@example.com", plan: "free") }
  end
end
