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
