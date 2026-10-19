# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Assessments API', type: :request do
  # The tenant guard (ApplicationController#require_tenant!) runs before auth, so a
  # bare tokenless request is rejected as an unresolved tenant (403). Resolving the
  # tenant (X-Tenant-Scheme) puts the request in front of the auth layer, which is
  # what this example asserts: no token => 401.
  it 'rejects a request without a token' do
    create_organization

    get '/api/v1/assessments', headers: { 'X-Tenant-Scheme' => 'test-corp' }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a token whose tenant cannot be resolved' do
    get '/api/v1/assessments', headers: auth_headers(scheme: 'ghost-corp')

    expect(response).to have_http_status(:forbidden)
  end

  it 'lists only the assessments of the resolved tenant' do
    organization = create_organization
    visible = create(:assessment, tenant_id: organization.id, name: 'Visible Assessment')
    create(:assessment, tenant_id: 999, name: 'Other Tenant Assessment')

    get '/api/v1/assessments', headers: auth_headers

    expect(response).to have_http_status(:ok)
    names = json_body.fetch('assessments').map { |a| a.fetch('name') }
    expect(names).to eq([visible.name])
  end
end
