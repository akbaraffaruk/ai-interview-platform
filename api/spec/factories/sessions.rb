# frozen_string_literal: true

FactoryBot.define do
  factory :session do
    tenant_id { 1 }
    assessment
    candidate_id { 101 }
    candidate_name { 'Ahmad Rizky' }
    status { 'pending' }

    trait :ended do
      status { 'ended' }
      end_reason { 'manual_assessor' }
      started_at { 40.minutes.ago }
      ended_at { 2.minutes.ago }
      duration_seconds { 2280 }
    end
  end

  factory :session_event do
    session
    kind        { 'session_started' }
    occurred_at { Time.current }
    payload     { {} }
  end

  factory :transcript_turn do
    session
    sequence(:turn_number) { |n| n }
    speaker { 'ai' }
    text    { 'A transcript line.' }
  end

  factory :coverage_map do
    session
    skill_label   { 'React' }
    state         { 'covered' }
    probe_count   { 3 }
    is_discovered { false }
  end

  factory :coverage_analysis do
    session
    window_from_turn { 1 }
    window_to_turn   { 6 }
    prompt_version   { 'abc123abc123' }
    status           { 'succeeded' }
  end
end
