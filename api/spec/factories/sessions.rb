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
end
