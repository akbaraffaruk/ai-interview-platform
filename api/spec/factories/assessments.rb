# frozen_string_literal: true

FactoryBot.define do
  factory :assessment do
    tenant_id { 1 }
    created_by { 1 }
    sequence(:name) { |n| "Assessment #{n}" }
    time_limit_min { 45 }
    language { 'en' }

    factory :assessment_with_skills do
      transient do
        skill_count { 2 }
      end

      after(:create) do |assessment, evaluator|
        evaluator.skill_count.times do |index|
          create(
            :assessment_skill,
            assessment: assessment,
            skill_id: "SK-TEST-#{index + 1}",
            skill_label: "Test Skill #{index + 1}",
            display_order: index,
            expected_level: 3
          )
        end
      end
    end
  end
end

FactoryBot.define do
  factory :assessment_skill do
    assessment
    skill_label { 'Test Skill' }
    l1_anchor { 'L1' }
    l2_anchor { 'L2' }
    l3_anchor { 'L3' }
    l4_anchor { 'L4' }
    l5_anchor { 'L5' }
    display_order { 0 }
  end
end
