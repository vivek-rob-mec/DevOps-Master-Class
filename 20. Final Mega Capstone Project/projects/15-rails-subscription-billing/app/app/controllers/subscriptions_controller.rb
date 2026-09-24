class SubscriptionsController < ApplicationController
  def index
    @subscriptions = Subscription.order(created_at: :desc).limit(200)
    @subscription = Subscription.new
  end
  def create
    key = request.headers["Idempotency-Key"].presence || params[:idempotency_key].presence
    return render plain: "Idempotency key required", status: :bad_request if key.blank? || key.length > 128
    value = SubscriptionRules.parse(**subscription_params.to_h.symbolize_keys)
    @subscription = Subscription.find_or_initialize_by(idempotency_key: key)
    @subscription.assign_attributes(value.to_h.merge(status: "active"))
    @subscription.save!
    redirect_to subscriptions_path, status: :see_other, notice: "Subscription activated"
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    redirect_to subscriptions_path, status: :see_other, alert: error.message
  end
  private
  def subscription_params
    params.require(:subscription).permit(:account_name, :owner_email, :plan)
  end
end
