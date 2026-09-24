Rails.application.routes.draw do
  root "subscriptions#index"
  resources :subscriptions, only: [:index, :create]
  get "/health", to: proc { |_env|
    ActiveRecord::Base.connection.execute("SELECT 1")
    [200, { "content-type" => "application/json" }, ['{"status":"ok","service":"billing-app"}']]
  }
  get "/metrics", to: proc { |_env|
    [200, { "content-type" => "text/plain; version=0.0.4" }, ["# HELP billing_up Service readiness\n# TYPE billing_up gauge\nbilling_up 1\n"]]
  }
end
