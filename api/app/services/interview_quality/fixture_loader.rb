# frozen_string_literal: true

module InterviewQuality
  # Builds a persisted session from a fixture hash. Used by the eval corpus spec
  # and by bin/eval-interview-quality. No network, no Sidekiq, no Gemini.
  module FixtureLoader
    module_function

    def call(fixture, tenant_id:)
      assessment = build_assessment(fixture, tenant_id)
      session    = build_session(fixture, assessment, tenant_id)

      Array(fixture['skills']).each { |skill| build_skill(session, skill) }
      Array(fixture['turns']).each  { |turn| build_turn(session, turn) }
      Array(fixture['events']).each { |event| build_event(session, event) }
      Array(fixture['analyses']).each { |analysis| build_analysis(session, analysis) }

      session
    end

    def build_assessment(fixture, tenant_id)
      assessment = Assessment.create!(
        tenant_id:      tenant_id,
        created_by:     1,
        name:           "[FIXTURE] #{fixture.fetch('name')}",
        time_limit_min: 45,
        language:       'en'
      )

      Array(fixture['skills']).reject { |s| s['is_discovered'] }.each_with_index do |skill, index|
        assessment.assessment_skills.create!(
          skill_label:   skill.fetch('label'),
          l1_anchor:     'L1',
          l2_anchor:     'L2',
          l3_anchor:     'L3',
          l4_anchor:     'L4',
          l5_anchor:     'L5',
          display_order: index
        )
      end

      assessment
    end

    def build_session(fixture, assessment, tenant_id)
      session_attrs = fixture.fetch('session', {})
      Session.create!(
        tenant_id:        tenant_id,
        assessment_id:    assessment.id,
        candidate_id:     901,
        candidate_name:   'Fixture Candidate',
        status:           session_attrs.fetch('status', 'ended'),
        end_reason:       session_attrs['end_reason'],
        started_at:       session_attrs.fetch('started_at', 40.minutes.ago),
        ended_at:         session_attrs['duration_seconds'] ? 2.minutes.ago : nil,
        duration_seconds: session_attrs['duration_seconds']
      )
    end

    def build_skill(session, skill)
      session.coverage_maps.create!(
        skill_label:   skill.fetch('label'),
        is_discovered: skill.fetch('is_discovered', false),
        state:         skill.fetch('state'),
        probe_count:   skill.fetch('probes', 0),
        last_signal:   skill['last_signal']
      )
    end

    def build_turn(session, turn)
      session.transcript_turns.create!(
        turn_number: turn.fetch('n'),
        speaker:     turn.fetch('speaker'),
        text:        turn.fetch('text'),
        created_at:  (30 - turn.fetch('n')).minutes.ago
      )
    end

    def build_event(session, event)
      session.session_events.create!(
        kind:        event.fetch('kind'),
        payload:     event.fetch('payload', {}),
        occurred_at: event.fetch('seconds_ago', 600).seconds.ago
      )
    end

    def build_analysis(session, analysis)
      session.coverage_analyses.create!(
        window_from_turn: analysis.fetch('from'),
        window_to_turn:   analysis.fetch('to'),
        prompt_version:   analysis.fetch('prompt_version', 'abc123abc123'),
        status:           analysis.fetch('status', 'succeeded')
      )
    end
  end
end
