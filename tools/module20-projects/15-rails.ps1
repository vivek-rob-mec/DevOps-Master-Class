param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')
$project=@{
 Id='15-rails-subscription-billing';Title='Rails Subscription Billing Monolith';Type='Convention-driven modular monolith';Backend='Ruby 3.4 / Rails 8.1 / PostgreSQL';Frontend='Rails views / Hotwire';Domain='billing';Namespace='billing-rails';PublicPort=8094;Entry='app';Ui='app'
 Diagram=@'
flowchart LR
    Operator --> UI["Rails billing workspace"]
    UI --> Controller["Subscriptions controller"]
    Controller --> Domain["Subscription rules"]
    Controller --> Billing["Billing module"]
    Controller --> Audit["Audit module"]
    Domain --> PG[(PostgreSQL)]
    Billing --> PG
    Audit --> PG
    UI --> Metrics["Health and metrics"]
'@
 Workloads=@(@{Name='app';Port=3000;Health='/health';Responsibility='Rails UI, subscription domain, persistence, health, and metrics in one deployable unit'})
}
$root=New-CommonProject $project -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/Gemfile' @'
source "https://rubygems.org"
ruby "~> 3.4.0"
gem "rails", "8.1.3.1"
gem "pg", "1.6.2"
gem "puma", "7.0.4"
gem "propshaft", "1.3.1"
gem "importmap-rails", "2.2.2"
gem "turbo-rails", "2.0.20"
gem "bootsnap", "1.18.6", require: false
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/boot.rb' @'
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
require "bootsnap/setup"
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/application.rb' @'
require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)
module BillingPlatform
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_paths << Rails.root.join("app/domain")
    config.active_record.schema_format = :ruby
  end
end
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/environment.rb' @'
require_relative "application"
Rails.application.initialize!
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/environments/development.rb' @'
Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
end
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/environments/test.rb' @'
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.consider_all_requests_local = true
end
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/environments/production.rb' @'
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.force_ssl = ENV.fetch("FORCE_SSL", "false") == "true"
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.log_tags = [:request_id]
  config.public_file_server.enabled = true
end
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/database.yml' @'
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
  url: <%= ENV.fetch("DATABASE_URL", "postgresql://app:local-development-only@postgres:5432/app") %>
development:
  <<: *default
test:
  <<: *default
  database: billing_test
production:
  <<: *default
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/routes.rb' @'
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
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/puma.rb' @'
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count
port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "development")
plugin :tmp_restart
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/importmap.rb' @'
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config.ru' @'
require_relative "config/environment"
run Rails.application
Rails.application.load_server
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/Rakefile' @'
require_relative "config/application"
Rails.application.load_tasks
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/bin/rails' @'
#!/usr/bin/env ruby
APP_PATH = File.expand_path("../config/application", __dir__)
require_relative "../config/boot"
require "rails/commands"
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/app/models/application_record.rb' @'
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/app/domain/subscription_rules.rb' @'
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
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/app/models/subscription.rb' @'
class Subscription < ApplicationRecord
  validates :account_name, length: { in: 2..120 }
  validates :owner_email, length: { maximum: 254 }
  validates :plan, inclusion: { in: SubscriptionRules::PLANS }
  validates :idempotency_key, presence: true, uniqueness: true, length: { maximum: 128 }
end
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/app/controllers/application_controller.rb' @'
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
end
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/app/controllers/subscriptions_controller.rb' @'
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
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/app/views/layouts/application.html.erb' @'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Ledgerline</title><%= csrf_meta_tags %><%= csp_meta_tag %><%= stylesheet_link_tag "application" %><%= javascript_importmap_tags %></head><body><%= yield %></body></html>
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/app/views/subscriptions/index.html.erb' @'
<main><header><p>LEDGERLINE / RAILS</p><h1>Recurring revenue.<br>Visible control.</h1><output><%= notice || alert || "Ready" %></output></header><%= form_with model: @subscription do |form| %><%= hidden_field_tag :idempotency_key, SecureRandom.uuid %><%= form.text_field :account_name, placeholder: "Account name", required: true %><%= form.email_field :owner_email, placeholder: "owner@example.com", required: true %><%= form.select :plan, SubscriptionRules::PLANS %><%= form.submit "Activate" %><% end %><section id="subscriptions"><% @subscriptions.each do |subscription| %><article><span><%= subscription.status %> / <%= subscription.plan %></span><h2><%= subscription.account_name %></h2><p><%= subscription.owner_email %></p></article><% end %></section></main>
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/app/assets/stylesheets/application.css' @'
:root{font-family:system-ui;color:#231942;background:#f7f0f5}*{box-sizing:border-box}body{margin:0}main{max-width:1080px;margin:auto;padding:4rem 2rem}header p{letter-spacing:.2em;color:#9f2b68;font-weight:800}h1{font-size:clamp(3rem,8vw,6rem);line-height:.9}form{display:grid;grid-template-columns:2fr 2fr 1fr auto;gap:.5rem;background:#231942;padding:.8rem}input,select,button{padding:.9rem;border:0}button{background:#e0b1cb;font-weight:bold}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:1rem;margin-top:2rem}article{background:white;padding:1.2rem;border-right:5px solid #9f2b68}article span{color:#9f2b68;text-transform:uppercase;font-size:.7rem}@media(max-width:720px){form{grid-template-columns:1fr}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/app/javascript/application.js' @'
import "@hotwired/turbo-rails"
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/db/migrate/20260816000000_create_subscriptions.rb' @'
class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions, id: :uuid do |table|
      table.string :account_name, null: false, limit: 120
      table.string :owner_email, null: false, limit: 254
      table.string :plan, null: false, limit: 24
      table.string :status, null: false, limit: 24, default: "active"
      table.string :idempotency_key, null: false, limit: 128
      table.timestamps
    end
    add_index :subscriptions, :idempotency_key, unique: true
  end
end
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/test/subscription_rules_test.rb' @'
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
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'Dockerfile' @'
FROM ruby:3.4-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY app/Gemfile ./
RUN bundle config set without development:test && bundle install --jobs 4
COPY app/ ./
RUN bundle exec ruby test/subscription_rules_test.rb && SECRET_KEY_BASE_DUMMY=1 DATABASE_URL=postgresql://app:placeholder@localhost/app bundle exec rails assets:precompile
FROM ruby:3.4-slim
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 && rm -rf /var/lib/apt/lists/* && groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
ENV RAILS_ENV=production RAILS_LOG_TO_STDOUT=true PORT=3000
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=app:app /app ./
USER 10001:10001
EXPOSE 3000
CMD ["sh","-c","bundle exec rails db:prepare && bundle exec puma -C config/puma.rb"]
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  postgres:
    image: postgres:16-alpine
    environment: { POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}", POSTGRES_DB: "${POSTGRES_DB:-app}" }
    volumes: [postgres-data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD-SHELL","pg_isready -U ${POSTGRES_USER:-app} -d ${POSTGRES_DB:-app}"], interval: 5s, timeout: 3s, retries: 30 }
    networks: [data]
  app:
    image: ${REGISTRY:-local}/15-rails-subscription-billing-app:${IMAGE_TAG:-dev}
    build: .
    environment: { DATABASE_URL: "postgresql://${POSTGRES_USER:-app}:${POSTGRES_PASSWORD:-local-development-only}@postgres:5432/${POSTGRES_DB:-app}", SECRET_KEY_BASE: "${SECRET_KEY_BASE:-replace-with-64-byte-secret}", RAILS_ENV: production }
    ports: ["${PUBLIC_PORT:-8094}:3000"]
    depends_on: { postgres: { condition: service_healthy } }
    read_only: true
    tmpfs: [/tmp,/app/tmp,/app/log]
    security_opt: [no-new-privileges:true]
    networks: [edge,data]
networks: { edge: {}, data: { internal: true } }
volumes: { postgres-data: {} }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD/app:/app" -w /app ruby:3.4 ruby test/subscription_rules_test.rb
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode
[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}
