Devise::JWT.configure do |config|
  config.secret = Rails.application.secret_key_base
  config.dispatch_requests = [
    ['POST', %r{^/api/v1/users/sign_in$}],
    ['POST', %r{^/api/v1/users$}]
  ]
  config.revocation_requests = [
    ['DELETE', %r{^/api/v1/users/sign_out$}]
  ]
  config.request_formats = {
    user: [:json]
  }
end
