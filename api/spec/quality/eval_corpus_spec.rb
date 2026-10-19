# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Interview quality eval corpus' do
  # spec/quality is not a RSpec-mapped location, so the shared tenant helper
  # (included for type: :request elsewhere) has to be pulled in explicitly.
  include AuthHelpers

  FIXTURE_DIR = Rails.root.join('spec/fixtures/interview_quality')

  # Class-level so the example loop (which runs while the group is defined) and
  # the corpus-size example read the very same list.
  def self.fixture_paths
    Dir[FIXTURE_DIR.join('*.json')].sort
  end

  def fixture_paths
    self.class.fixture_paths
  end

  it 'has a non-empty corpus, so the gate cannot silently disappear' do
    expect(fixture_paths.size).to eq(13)
  end

  fixture_paths.each do |path|
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
