# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CoverageAnalyzerWorker do
  let(:assessment) { create(:assessment_with_skills, skill_count: 2) }
  let(:session)    { create(:session, assessment: assessment, status: 'active', tenant_id: assessment.tenant_id) }

  before do
    1.upto(4) do |n|
      session.transcript_turns.create!(turn_number: n, speaker: n.odd? ? 'ai' : 'candidate', text: "turn #{n} text")
    end
  end

  it 'writes one ledger row per analysis run with the analyser window and prompt version' do
    analyzer = instance_double(Coverage::Analyzer,
                               call: { skill_updates: [], discovered_skills: [] },
                               prompt_version: 'abc123abc123',
                               window_turn_numbers: [1, 4])
    allow(Coverage::Analyzer).to receive(:new).and_return(analyzer)

    described_class.new.perform(session.id, 4)

    ledger = session.coverage_analyses.reload.sole
    expect(ledger.status).to eq('succeeded')
    expect(ledger.window_from_turn).to eq(1)
    expect(ledger.window_to_turn).to eq(4)
    expect(ledger.prompt_version).to eq('abc123abc123')
    expect(ledger.latency_ms).to be >= 0
  end

  it 'records a failed run without raising, so the interview is never interrupted by analysis trouble' do
    analyzer = instance_double(Coverage::Analyzer, prompt_version: 'abc123abc123', window_turn_numbers: [1, 4])
    allow(analyzer).to receive(:call).and_raise(Gemini::HttpClient::TimeoutError.new('timeout'))
    allow(Coverage::Analyzer).to receive(:new).and_return(analyzer)

    expect { described_class.new.perform(session.id, 4) }.not_to raise_error

    ledger = session.coverage_analyses.reload.sole
    expect(ledger.status).to eq('failed')
    expect(ledger.error_class).to eq('Gemini::HttpClient::TimeoutError')
  end
end
