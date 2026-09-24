class Subscription < ApplicationRecord
  validates :account_name, length: { in: 2..120 }
  validates :owner_email, length: { maximum: 254 }
  validates :plan, inclusion: { in: SubscriptionRules::PLANS }
  validates :idempotency_key, presence: true, uniqueness: true, length: { maximum: 128 }
end
