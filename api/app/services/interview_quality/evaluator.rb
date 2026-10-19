# frozen_string_literal: true

module InterviewQuality
  # Deterministic contract evaluation of a finished interview.
  #
  # PRD-01 §7 lists the failure modes the interviewer must never exhibit. Until
  # now nothing checked them, so an interview that covered two of five skills and
  # closed early looked exactly like a good one. This service turns transcript +
  # coverage + event log + analysis ledger into a verdict an assessor can act on.
  class Evaluator
    VERDICTS = %w[trustworthy review_required invalid].freeze

    BLOCKER = 'blocker' # → invalid
    WARNING = 'warning' # → review_required

    Finding = Struct.new(:code, :severity, :message, :turn_numbers, keyword_init: true)

    SCORE_PENALTY = { BLOCKER => 25, WARNING => 5 }.freeze

    SYSTEM_TEXT_PATTERN = /\[COVERAGE[_ ]MAP|\[TIME[_ ]CONTROL|SYS-TC-7x9k|\[Start the interview/i

    def initialize(session)
      @session = session
    end

    def call
      findings = checks.flat_map { |check| send(check) }.compact
      {
        verdict:  verdict_for(findings),
        score:    score_for(findings),
        findings: findings
      }
    end

    private

    attr_reader :session

    def checks
      %i[
        check_session_ended_consistent
        check_probe_discipline
        check_closing_discipline
        check_system_text_leak
        check_analysis_completeness
      ]
    end

    # ── checks ──────────────────────────────────────────────────────────────

    def check_session_ended_consistent
      uncovered = configured_maps.reject { |map| map.state == 'covered' }
      return [] if uncovered.empty?

      findings = [Finding.new(
        code: 'skill_never_covered',
        severity: session.end_reason == 'all_covered' ? BLOCKER : WARNING,
        message: "#{uncovered.size} configured skill(s) never reached covered: " \
                 "#{uncovered.map { |m| "#{m.skill_label} (#{m.state}, #{m.probe_count} probes)" }.join(', ')}",
        turn_numbers: []
      )]

      if session.end_reason == 'all_covered'
        findings << Finding.new(
          code: 'session_ended_without_coverage',
          severity: BLOCKER,
          message: 'Session closed as "all_covered" while configured skills were still uncovered — ' \
                   'the candidate lost the remaining interview time.',
          turn_numbers: []
        )
      end

      findings
    end

    def check_probe_discipline
      configured_maps.filter_map do |map|
        next unless %w[partial covered].include?(map.state)
        next if map.probe_count >= 2

        Finding.new(
          code: 'promotion_without_probes',
          severity: BLOCKER,
          message: "#{map.skill_label} reached #{map.state} with #{map.probe_count} probe(s); " \
                   'the two-probe minimum is a hard rule.',
          turn_numbers: []
        )
      end
    end

    def check_closing_discipline
      wrap_up_at = session.session_events.of_kind('wrap_up_injected').map(&:occurred_at).min
      closing_turns = ai_turns.select do |turn|
        closing_phrase?(turn.text) && (wrap_up_at.nil? || turn.created_at < wrap_up_at)
      end
      return [] if closing_turns.empty?

      Finding.new(
        code: 'closing_without_signal',
        severity: WARNING,
        message: wrap_up_at.nil? ?
          'The interviewer delivered a closing line but no wrap-up signal was ever recorded.' :
          'The interviewer closed the interview before the wrap-up signal was injected.',
        turn_numbers: closing_turns.map(&:turn_number)
      )
    end

    def check_system_text_leak
      leaked_turns = ai_turns.select { |turn| turn.text.match?(SYSTEM_TEXT_PATTERN) }
      recorded     = session.session_events.of_kind('system_text_leaked').count

      return [] if leaked_turns.empty? && recorded.zero?

      Finding.new(
        code: 'system_text_leaked',
        severity: BLOCKER,
        message: 'Internal system text (coverage map / time control) reached the candidate: ' \
                 "#{recorded} recorded leak(s), #{leaked_turns.size} still visible in the transcript.",
        turn_numbers: leaked_turns.map(&:turn_number)
      )
    end

    def check_analysis_completeness
      analysed_through = session.coverage_analyses.succeeded.maximum(:window_to_turn).to_i
      unanalysed = candidate_turns.select { |turn| turn.turn_number > analysed_through }
      return [] if unanalysed.empty?

      Finding.new(
        code: 'turns_never_analysed',
        severity: WARNING,
        message: "#{unanalysed.size} candidate turn(s) were never read by a coverage analysis run " \
                 "(ledger covers turns up to #{analysed_through}).",
        turn_numbers: unanalysed.map(&:turn_number)
      )
    end

    # ── helpers ─────────────────────────────────────────────────────────────

    def configured_maps
      @configured_maps ||= session.coverage_maps.reject(&:is_discovered)
    end

    def transcript
      @transcript ||= session.transcript_turns.ordered.to_a
    end

    def ai_turns
      @ai_turns ||= transcript.select { |turn| turn.speaker == 'ai' }
    end

    def candidate_turns
      @candidate_turns ||= transcript.select { |turn| turn.speaker == 'candidate' }
    end

    def closing_phrase?(text)
      downcased = text.to_s.downcase
      AudioWebSocketMiddleware::CLOSING_PHRASES.any? { |phrase| downcased.include?(phrase) }
    end

    def verdict_for(findings)
      return 'invalid' if findings.any? { |f| f.severity == BLOCKER }
      return 'review_required' if findings.any?

      'trustworthy'
    end

    def score_for(findings)
      penalty = findings.sum { |f| SCORE_PENALTY.fetch(f.severity, 0) }
      [100 - penalty, 0].max
    end
  end
end
