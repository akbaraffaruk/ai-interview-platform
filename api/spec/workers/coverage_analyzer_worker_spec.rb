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
                               model: 'gemini-2.0-flash-001',
                               window_turn_numbers: [1, 4])
    allow(Coverage::Analyzer).to receive(:new).and_return(analyzer)

    described_class.new.perform(session.id, 4)

    ledger = session.coverage_analyses.reload.sole
    expect(ledger.status).to eq('succeeded')
    expect(ledger.window_from_turn).to eq(1)
    expect(ledger.window_to_turn).to eq(4)
    expect(ledger.prompt_version).to eq('abc123abc123')
    expect(ledger.model).to eq('gemini-2.0-flash-001')
    expect(ledger.latency_ms).to be >= 0
  end

  it 'records a failed run without raising, so the interview is never interrupted by analysis trouble' do
    analyzer = instance_double(Coverage::Analyzer, prompt_version: 'abc123abc123',
                                                  model: 'gemini-2.0-flash-001',
                                                  window_turn_numbers: [1, 4])
    allow(analyzer).to receive(:call).and_raise(Gemini::HttpClient::TimeoutError.new('timeout'))
    allow(Coverage::Analyzer).to receive(:new).and_return(analyzer)

    expect { described_class.new.perform(session.id, 4) }.not_to raise_error

    ledger = session.coverage_analyses.reload.sole
    expect(ledger.status).to eq('failed')
    expect(ledger.error_class).to eq('Gemini::HttpClient::TimeoutError')

    event = session.session_events.of_kind('coverage_analysis_failed').sole
    expect(event.payload).to include('error_class' => 'Gemini::HttpClient::TimeoutError', 'turn_number' => 4)
  end

  it 'records a failure event when the analyser cannot even be constructed (no ledger row without a window)' do
    allow(Coverage::Analyzer).to receive(:new).and_raise(KeyError, 'key not found: "GEMINI_API_KEY"')

    expect { described_class.new.perform(session.id, 4) }.not_to raise_error

    event = session.session_events.of_kind('coverage_analysis_failed').sole
    expect(event.payload).to include('error_class' => 'KeyError', 'turn_number' => 4)
    expect(session.coverage_analyses.count).to eq(0)
  end

  it 'records a failure event when the analysis window cannot be computed' do
    analyzer = instance_double(Coverage::Analyzer, prompt_version: 'abc123abc123')
    allow(analyzer).to receive(:window_turn_numbers).and_raise(ActiveRecord::StatementInvalid, 'boom')
    allow(Coverage::Analyzer).to receive(:new).and_return(analyzer)

    expect { described_class.new.perform(session.id, 4) }.not_to raise_error

    expect(session.session_events.of_kind('coverage_analysis_failed').sole.payload)
      .to include('error_class' => 'ActiveRecord::StatementInvalid')
  end
end
