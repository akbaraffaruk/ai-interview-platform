# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InterviewQuality::Evaluator do # rubocop:disable Metrics/BlockLength -- one spec file per service
  let(:assessment) { create(:assessment_with_skills, skill_count: 2) }
  let(:session) do
    create(:session, :ended, assessment: assessment, tenant_id: assessment.tenant_id, end_reason: 'all_covered')
  end

  def covered_skill(label, probes: 3)
    session.coverage_maps.create!(skill_label: label, state: 'covered', probe_count: probes, is_discovered: false)
  end

  def ai_turn(number, text)
    session.transcript_turns.create!(turn_number: number, speaker: 'ai', text: text)
  end

  def candidate_turn(number, text)
    session.transcript_turns.create!(turn_number: number, speaker: 'candidate', text: text)
  end

  def analyse(turns)
    session.coverage_analyses.create!(
      window_from_turn: turns.first, window_to_turn: turns.last,
      prompt_version: 'abc123abc123', status: 'succeeded'
    )
  end

  it 'trusts a session where every configured skill was covered with probes' do
    covered_skill('React', probes: 5)
    covered_skill('Communication', probes: 3)
    ai_turn(1, 'Tell me about a hard project.')
    candidate_turn(2, 'We built a dashboard.')
    analyse([1, 2])

    result = described_class.new(session).call

    expect(result[:verdict]).to eq('trustworthy')
    expect(result[:findings]).to be_empty
    expect(result[:score]).to eq(100)
  end

  it 'invalidates a session that ended as all_covered while a skill was not covered' do
    covered_skill('React', probes: 5)
    session.coverage_maps.create!(skill_label: 'Communication', state: 'partial', probe_count: 2)
    ai_turn(1, 'Tell me about a hard project.')
    candidate_turn(2, 'We built a dashboard.')
    analyse([1, 2])

    result = described_class.new(session).call

    expect(result[:verdict]).to eq('invalid')
    expect(result[:findings].map(&:code)).to include('session_ended_without_coverage')
    expect(result[:findings].map(&:code)).to include('skill_never_covered')
    expect(result[:score]).to eq(50)
  end

  it 'invalidates a skill promoted to covered without the two-probe minimum' do
    covered_skill('React', probes: 1)
    covered_skill('Communication', probes: 3)
    ai_turn(1, 'Opening question.')
    candidate_turn(2, 'Answer.')
    analyse([1, 2])

    result = described_class.new(session).call

    expect(result[:verdict]).to eq('invalid')
    finding = result[:findings].find { |f| f.code == 'promotion_without_probes' }
    expect(finding.severity).to eq('blocker')
    expect(finding.message).to include('React')
  end

  it 'flags an AI closing phrase spoken without a wrap-up signal' do
    covered_skill('React', probes: 4)
    covered_skill('Communication', probes: 3)
    ai_turn(1, 'Tell me about a hard project.')
    ai_turn(2, 'Thanks for your time — you will hear back from the team soon.')
    candidate_turn(3, 'Thank you.')
    analyse([1, 3])

    result = described_class.new(session).call

    finding = result[:findings].find { |f| f.code == 'closing_without_signal' }
    expect(finding).to be_present
    expect(finding.turn_numbers).to eq([2])
  end

  it 'does not flag the closing when a wrap-up event preceded it' do
    covered_skill('React', probes: 4)
    covered_skill('Communication', probes: 3)
    ai_turn(1, 'Tell me about a hard project.')
    ai_turn(2, 'Thanks for your time — you will hear back from the team soon.')
    candidate_turn(3, 'Thank you.')
    session.session_events.create!(kind: 'wrap_up_injected', occurred_at: 10.minutes.ago)
    analyse([1, 3])

    result = described_class.new(session).call

    expect(result[:findings].map(&:code)).not_to include('closing_without_signal')
  end

  it 'invalidates a session whose transcript shows internal system text' do
    covered_skill('React', probes: 4)
    covered_skill('Communication', probes: 3)
    ai_turn(1, 'Hi there. [COVERAGE_MAP] {"skills":[]} [/COVERAGE_MAP] Let us begin.')
    candidate_turn(2, 'Okay.')
    analyse([1, 2])

    result = described_class.new(session).call

    expect(result[:verdict]).to eq('invalid')
    expect(result[:findings].map(&:code)).to include('system_text_leaked')
  end

  it 'warns when candidate turns were never analysed' do
    covered_skill('React', probes: 4)
    covered_skill('Communication', probes: 3)
    ai_turn(1, 'Opening question.')
    candidate_turn(2, 'First answer.')
    candidate_turn(3, 'Second answer that no analysis run ever read.')
    analyse([1, 2])

    result = described_class.new(session).call

    expect(result[:verdict]).to eq('review_required')
    finding = result[:findings].find { |f| f.code == 'turns_never_analysed' }
    expect(finding.turn_numbers).to eq([3])
    expect(result[:score]).to eq(95)
  end
end
