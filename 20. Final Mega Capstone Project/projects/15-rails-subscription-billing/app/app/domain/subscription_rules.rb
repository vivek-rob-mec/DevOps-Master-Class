class SubscriptionRules
  PLANS = %w[starter growth enterprise].freeze
  Result = Data.define(:account_name, :owner_email, :plan)
  def self.parse(account_name:, owner_email:, plan:)
    name = account_name.to_s.strip
    email = owner_email.to_s.strip.downcase
    normalized_plan = plan.to_s.strip.downcase
    raise ArgumentError, "INVALID_ACCOUNT" unless name.length.between?(2, 120)
    raise ArgumentError, "INVALID_EMAIL" unless email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
    raise ArgumentError, "INVALID_PLAN" unless PLANS.include?(normalized_plan)
    Result.new(account_name: name, owner_email: email, plan: normalized_plan)
  end
end
