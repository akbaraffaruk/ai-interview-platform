# frozen_string_literal: true

module AuthHelpers
  # Request specs need a tenant that TenantResolverMiddleware can resolve, plus a
  # JWT whose `scheme` claim matches it (AuthorizeApiRequest trusts JWT claims only).
  def create_organization(scheme: 'test-corp', name: 'Test Corp')
    Organization.create!(name: name, scheme: scheme, identifier: scheme, host: 'localhost')
  end

  def auth_headers(role: 'admin', scheme: 'test-corp', user_id: 1)
    { 'Authorization' => "Bearer #{JsonWebToken.encode(user_id: user_id, role: role, scheme: scheme)}" }
  end

  def json_body
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
