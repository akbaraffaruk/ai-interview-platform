# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Session quality API', type: :request do
  let(:organization) { create_organization }
  let(:assessment)   { create(:assessment_with_skills, tenant_id: organization.id, skill_count: 1) }
  let(:session) do
    create(:session, :ended, assessment: assessment, tenant_id: organization.id, end_reason: 'all_covered')
  end

  # The tenant must resolve for the request to reach the auth check:
  # ApplicationController runs require_tenant! before authorize_auth_token!,
  # so a bare request answers 403 (tenant not found) and never exercises auth.
  it 'requires authentication' do
    get "/api/v1/sessions/#{session.id}/quality", headers: { 'X-Tenant-Scheme' => organization.scheme }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns the verdict and findings for an assessor' do
    session.coverage_maps.create!(skill_label: 'React', state: 'covered', probe_count: 5)
    session.transcript_turns.create!(turn_number: 1, speaker: 'ai', text: 'Tell me about a project.')
    session.transcript_turns.create!(turn_number: 2, speaker: 'candidate', text: 'We built a dashboard.')
    session.coverage_analyses.create!(window_from_turn: 1, window_to_turn: 2, prompt_version: 'abc123abc123')

    get "/api/v1/sessions/#{session.id}/quality", headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('verdict')).to eq('trustworthy')
    expect(json_body.fetch('score')).to eq(100)
    expect(json_body.fetch('findings')).to eq([])
  end

  it 'reports findings for a session that closed early' do
    session.coverage_maps.create!(skill_label: 'React', state: 'partial', probe_count: 3)

    get "/api/v1/sessions/#{session.id}/quality", headers: auth_headers

    expect(json_body.fetch('verdict')).to eq('invalid')
    expect(json_body.fetch('findings').map { |f| f.fetch('code') })
      .to include('session_ended_without_coverage')
  end

  it 'does not leak a session from another tenant' do
    # The requesting tenant (scheme test-corp) must exist, otherwise the request
    # never resolves a tenant and answers 403 before the scoped lookup runs.
    organization
    other = create(:session, :ended, tenant_id: 999, assessment: create(:assessment_with_skills, tenant_id: 999))

    get "/api/v1/sessions/#{other.id}/quality", headers: auth_headers

    expect(response).to have_http_status(:not_found)
  end

  it 'reports the quality verdict to the candidate without authentication' do
    session = create(:session, :ended, assessment: assessment, tenant_id: organization.id, end_reason: 'time_ceiling')
    session.coverage_maps.create!(skill_label: 'React', state: 'partial', probe_count: 2)

    get "/api/v1/sessions/#{session.invite_token}/candidate"

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('quality_verdict')).to eq('review_required')
  end
end
