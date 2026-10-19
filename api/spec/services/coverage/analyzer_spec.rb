# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Coverage::Analyzer do
  let(:assessment) { create(:assessment_with_skills, skill_count: 1) }
  let(:session)    { create(:session, assessment: assessment, tenant_id: assessment.tenant_id) }

  # These examples build a real analyser, so they build a real Gemini::HttpClient,
  # whose constructor does ENV.fetch('GEMINI_API_KEY') with no default. CI does not
  # export the key, so pin it here instead of changing production code.
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GEMINI_API_KEY').and_return('test-key')
  end

  def turn(number)
    session.transcript_turns.create!(turn_number: number, speaker: number.odd? ? 'ai' : 'candidate',
                                     text: "turn #{number}")
  end

  it 'reports the turn numbers of the sliding window it reads' do
    1.upto(4) { |n| turn(n) }

    expect(described_class.new(session: session).window_turn_numbers).to eq([1, 4])
  end

  it 'caps the window at six turns so the analyser never reads the whole transcript' do
    1.upto(9) { |n| turn(n) }

    expect(described_class.new(session: session).window_turn_numbers).to eq([4, 9])
  end

  it 'reports an empty window when the session has no turns yet' do
    expect(described_class.new(session: session).window_turn_numbers).to eq([0, 0])
  end
end
