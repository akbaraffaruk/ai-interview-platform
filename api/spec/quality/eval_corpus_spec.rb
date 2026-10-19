# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Interview quality eval corpus' do
  # spec/quality is not a RSpec-mapped location, so the shared tenant helper
  # (included for type: :request elsewhere) has to be pulled in explicitly.
  include AuthHelpers

  FIXTURE_DIR = Rails.root.join('spec/fixtures/interview_quality')

  Dir[FIXTURE_DIR.join('*.json')].sort.each do |path|
    fixture = JSON.parse(File.read(path))
    name    = fixture.fetch('name')

    it "matches the expected verdict for #{name}" do
      organization = create_organization(scheme: 'fixture-corp')
      session      = InterviewQuality::FixtureLoader.call(fixture, tenant_id: organization.id)

      result = InterviewQuality::Evaluator.new(session).call

      expect(result[:verdict]).to eq(fixture.dig('expected', 'verdict')),
                                  "#{name}: got #{result[:verdict]} with #{result[:findings].map(&:code).inspect}"
      expect(result[:findings].map(&:code).sort).to eq(Array(fixture.dig('expected', 'codes')).sort)
    end
  end
end
