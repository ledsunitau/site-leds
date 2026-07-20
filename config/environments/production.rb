require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Uploads no Cloudflare R2 (RNF-13). Ver config/storage.yml (serviço :r2).
  config.active_storage.service = :r2

  # Acesso via proxy SSL do Kamal (Let's Encrypt) atrás do Cloudflare (modo Full).
  config.assume_ssl = true
  config.force_ssl = true

  # Não redireciona o health check /up para https (o load balancer bate em http).
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates. protocol https:
  # sem ele os links do Devise (reset de senha) sairiam http:// (força-ssl até
  # redireciona, mas alguns clientes quebram o token no redirect).
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com"), protocol: "https" }

  # SMTP por env: provedor definido na fase de deploy (feature/deploy-producao);
  # necessário desde já para a recuperação de senha do Devise (RF-AUT-04).
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV["SMTP_ADDRESS"],
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    user_name: ENV["SMTP_USERNAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Proteção contra DNS rebinding / Host header: só o domínio da app (APP_HOST).
  # Vazio (APP_HOST não setado) mantém o comportamento default do Rails.
  config.hosts << ENV["APP_HOST"] if ENV["APP_HOST"].present?
  # O health check /up é batido por IP pelo load balancer — isenta do check de host.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
