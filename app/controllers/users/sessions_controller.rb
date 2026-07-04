class Users::SessionsController < Devise::SessionsController
  # RNF-15 exige as duas camadas de app: rate_limit nativo + Rack::Attack
  # (ver config/initializers/rack_attack.rb).
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { head :too_many_requests }
end
