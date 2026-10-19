# frozen_string_literal: true

# Demo dataset for local exploration of the assessor + candidate flows.
#
#   docker compose -f docker-compose.dev.yml exec api bundle exec rails runner db/seeds/demo.rb
#
# Creates (all idempotent, marked with a "[DEMO]" prefix):
#   - 2 assessments (Frontend, Backend) compiled from the seeded B7 taxonomy
#   - 2 vacancies
#   - 4 sessions: one completed with transcript + coverage + portfolio + fit/gap report,
#     one running (for Live Monitor), one pending (fresh invite link),
#     one deliberately degraded (four quality findings, expected verdict "invalid")
#
# Re-running is a no-op unless SEED_DEMO_REFRESH=1, which deletes the demo rows first.
module DemoSeed
  PREFIX        = '[DEMO] '
  CANDIDATE_ID  = 101
  CANDIDATE     = 'Ahmad Rizky (Demo)'
  ASSESSOR_ID   = 1

  module_function

  def call(refresh: ENV['SEED_DEMO_REFRESH'] == '1')
    org = Organization.identify('test-corp')
    abort('  [demo] organization "test-corp" not found — run `rails db:seed` first') unless org

    @tenant_id = org.id

    if refresh
      puts '  [demo] SEED_DEMO_REFRESH=1 — removing previous demo rows'
      wipe!
    end

    if Assessment.unscoped.where(name: "#{PREFIX}Senior Frontend Engineer").exists?
      puts '  [demo] already seeded (set SEED_DEMO_REFRESH=1 to recreate)'
      return
    end

    frontend = assessment(
      name:           "#{PREFIX}Senior Frontend Engineer",
      time_limit_min: 45,
      skill_ids:      %w[SK-ENG-001 SK-ENG-009 SK-ENG-006],
      expected:       [3, 3, 2]
    )
    backend = assessment(
      name:           "#{PREFIX}Backend Engineer (Node.js)",
      time_limit_min: 60,
      skill_ids:      %w[SK-ENG-002 SK-ENG-003 SK-ENG-004],
      expected:       [3, 3, 4]
    )

    fe_vacancy = vacancy(
      role_title:            "#{PREFIX}Senior Frontend Engineer — TechCorp",
      culture_dimensions:    'Ownership, direct feedback, async-first documentation, decisions backed by measurement.',
      competency_expectations: 'Owns frontend features end to end, argues tradeoffs with data, raises the testing bar for the team.',
      skills:                [['SK-ENG-001', 3], ['SK-ENG-009', 3], ['SK-ENG-006', 2]]
    )
    be_vacancy = vacancy(
      role_title:            "#{PREFIX}Backend Engineer — Logistics Platform",
      culture_dimensions:    'Systems thinking, incident ownership, low-ego code review.',
      competency_expectations: 'Designs services with clear data contracts; comfortable with queues, retries and idempotency.',
      skills:                [['SK-ENG-002', 3], ['SK-ENG-003', 3], ['SK-ENG-004', 4]]
    )

    completed(frontend, fe_vacancy)
    running(frontend)
    pending(backend)
    degraded_session = degraded(frontend)

    puts '  [demo] done.'
    puts
    puts "  Completed session   : #{Session.unscoped.where(candidate_name: CANDIDATE).maximum(:id)}"
    puts "  Degraded session    : ##{degraded_session.id} — expected verdict invalid (see /api/v1/sessions/#{degraded_session.id}/quality)"
    puts "  Invite links        :"
    Session.unscoped.where(tenant_id: @tenant_id).order(:id).each do |s|
      puts "    ##{s.id} #{s.status.ljust(7)} #{s.candidate_name.to_s.ljust(24)} http://localhost:5173/interview/#{s.invite_token}"
    end
  end

  # ── wipe ─────────────────────────────────────────────────────────────────────

  def wipe!
    assessment_ids = Assessment.unscoped.where('name LIKE ?', "#{PREFIX}%").pluck(:id)
    vacancy_ids    = Vacancy.unscoped.where('role_title LIKE ?', "#{PREFIX}%").pluck(:id)
    session_ids    = Session.unscoped.where(assessment_id: assessment_ids).pluck(:id)
    portfolio_ids  = Portfolio.unscoped.where(session_id: session_ids).pluck(:id)
    skill_ids      = PortfolioSkill.unscoped.where(portfolio_id: portfolio_ids).pluck(:id)

    FitGapReport.unscoped.where(portfolio_id: portfolio_ids).destroy_all
    FitGapReport.unscoped.where(vacancy_id: vacancy_ids).destroy_all
    AssessorOverride.unscoped.where(portfolio_skill_id: skill_ids).delete_all
    PortfolioSkill.unscoped.where(portfolio_id: portfolio_ids).delete_all
    Portfolio.unscoped.where(id: portfolio_ids).delete_all
    TranscriptTurn.unscoped.where(session_id: session_ids).delete_all
    CoverageMap.unscoped.where(session_id: session_ids).delete_all
    SessionEvent.unscoped.where(session_id: session_ids).delete_all
    CoverageAnalysis.unscoped.where(session_id: session_ids).delete_all
    Session.unscoped.where(id: session_ids).delete_all
    AssessmentSkill.unscoped.where(assessment_id: assessment_ids).delete_all
    Assessment.unscoped.where(id: assessment_ids).delete_all
    VacancySkill.unscoped.where(vacancy_id: vacancy_ids).delete_all
    Vacancy.unscoped.where(id: vacancy_ids).delete_all
  end

  # ── builders ─────────────────────────────────────────────────────────────────

  def assessment(name:, time_limit_min:, skill_ids:, expected:)
    record = Assessment.unscoped.create!(
      tenant_id:      @tenant_id,
      created_by:     ASSESSOR_ID,
      name:           name,
      time_limit_min: time_limit_min,
      language:       'en'
    )

    skill_ids.each_with_index do |skill_id, index|
      taxonomy = SkillTaxonomy.find_by!(skill_id: skill_id)
      record.assessment_skills.create!(
        skill_id:       taxonomy.skill_id,
        skill_label:    taxonomy.skill_label,
        is_custom:      false,
        scope_include:  taxonomy.scope_include,
        scope_exclude:  taxonomy.scope_exclude,
        l1_anchor:      taxonomy.l1_anchor,
        l2_anchor:      taxonomy.l2_anchor,
        l3_anchor:      taxonomy.l3_anchor,
        l4_anchor:      taxonomy.l4_anchor,
        l5_anchor:      taxonomy.l5_anchor,
        expected_level: expected[index],
        display_order:  index
      )
    end

    record.update!(system_prompt: Assessments::SystemPromptCompiler.new(record).call)
    puts "  [demo] assessment ##{record.id} #{record.name} (#{record.assessment_skills.count} skills)"
    record
  end

  def vacancy(role_title:, culture_dimensions:, competency_expectations:, skills:)
    record = Vacancy.unscoped.create!(
      tenant_id:              @tenant_id,
      created_by:             ASSESSOR_ID,
      role_title:             role_title,
      culture_dimensions:     culture_dimensions,
      competency_expectations: competency_expectations
    )

    skills.each do |skill_id, level|
      taxonomy = SkillTaxonomy.find_by!(skill_id: skill_id)
      record.vacancy_skills.create!(
        skill_id:       taxonomy.skill_id,
        skill_label:    taxonomy.skill_label,
        expected_level: level
      )
    end

    puts "  [demo] vacancy ##{record.id} #{record.role_title}"
    record
  end

  def session_for(assessment, status:, end_reason: nil, started_at: nil, ended_at: nil, duration: nil,
                  candidate_name: CANDIDATE)
    Session.unscoped.create!(
      tenant_id:        @tenant_id,
      assessment_id:    assessment.id,
      candidate_id:     CANDIDATE_ID,
      candidate_name:   candidate_name,
      status:           status,
      end_reason:       end_reason,
      started_at:       started_at,
      ended_at:         ended_at,
      duration_seconds: duration
    )
  end

  def turn(session, number, speaker, text)
    session.transcript_turns.create!(turn_number: number, speaker: speaker, text: text)
  end

  def coverage(session, assessment, states:)
    assessment.assessment_skills.order(:display_order).each_with_index do |skill, index|
      state, probes, signal = states[index]
      session.coverage_maps.create!(
        skill_id:      skill.skill_id,
        skill_label:   skill.skill_label,
        is_discovered: false,
        state:         state,
        probe_count:   probes,
        last_signal:   signal
      )
    end
  end

  # ── scenario 1: finished interview with portfolio + fit/gap ───────────────────

  def completed(assessment, vacancy)
    session = session_for(
      assessment,
      status:     'ended',
      end_reason: 'all_covered',
      started_at: 55.minutes.ago,
      ended_at:   17.minutes.ago,
      duration:   2325
    )

    coverage(session, assessment, states: [
      ['covered', 5, 'Explained state partitioning, profiling methodology and test layering with concrete numbers'],
      ['covered', 3, 'Described type boundaries between API and UI, plus one migration of a legacy JS module'],
      ['covered', 3, 'Testing pyramid described with concrete layers; e2e layer explicitly acknowledged as the weakest']
    ])
    session.coverage_maps.create!(
      skill_id:      nil,
      skill_label:   'Micro-frontend Architecture',
      is_discovered: true,
      state:         'partial',
      probe_count:   2,
      last_signal:   'Candidate mentioned leading a module-federation split across four apps'
    )

    script = [
      ['ai',        "Hi Ahmad, thanks for joining. Let's jump straight in — tell me about the most technically challenging frontend project you've worked on recently."],
      ['candidate', "We built a real-time logistics dashboard that had to render a few hundred updates per second. The hard part was keeping state in sync without re-rendering everything."],
      ['ai',        'A few hundred updates per second is a lot. How was that state actually flowing before you changed anything?'],
      ['candidate', "Everything went through Redux and every websocket event dispatched an action. We profiled it and roughly 80% of the renders were unnecessary."],
      ['ai',        'So how did you decide what stays in Redux and what moves closer to the component?'],
      ['candidate', "I split the context into a read-only provider and a write provider, so components that only consume state stop re-rendering. Shared or persisted data stayed in Redux, ephemeral UI state moved to local state, and things that must not trigger a render went into a ref."],
      ['ai',        'What did the profiling show after that change — and how did you know it was actually better?'],
      ['candidate', "React DevTools Profiler plus the Chrome performance tab. Re-render count dropped about 60%, and we set a performance budget in CI so it could not silently regress."],
      ['ai',        'You mentioned a module split earlier — how did the team grow into that decision?'],
      ['candidate', "At twelve engineers one deployable frontend became a bottleneck, so we decomposed into four micro-frontends with module federation and a shared design system shell. The shared state across boundaries was the painful part."],
      ['ai',        'And what broke first at those boundaries?'],
      ['candidate', "Version skew — two apps on different versions of the design system. We fixed it with a contract test on the shared package rather than process."],
      ['ai',        'Switching gears a bit: how do you draw the line on types between the API and the UI?'],
      ['candidate', "The API is the source of truth, so generated types from the OpenAPI schema, plus a narrow hand-written mapper at the edge. When the payload is JSON-heavy we validate with zod before it reaches components."],
      ['candidate', "I also migrated one legacy module from JS to strict TS incrementally — strict mode on the new files first, then a ratchet so the old ones could not get worse."],
      ['ai',        'When you look at how your team tests frontend work, what does that look like in practice?'],
      ['candidate', "Unit tests on pure logic, integration tests on the data-fetching layer with MSW, and a small set of end-to-end tests on critical user paths. Honestly the e2e layer is the thinnest — we never got it below about twenty minutes."],
      ['ai',        'If you had to make that e2e suite earn its keep tomorrow, where would you start?'],
      ['candidate', "Tag by risk instead of by page, run the critical path on every PR and the rest nightly, and delete tests that never caught anything. It is a prioritisation problem more than a tooling one."],
      ['ai',        'Last area — when you are designing a frontend system from scratch, where do you start?'],
      ['candidate', "Data contracts first: what each component consumes and how often it changes. Then a performance budget before the architecture, otherwise you optimise the wrong thing."],
      ['ai',        "That's a really thoughtful approach — I can see you've dealt with this hands-on. I think I've got a clear picture, thank you for your time. You'll hear back from the team soon."],
      ['candidate', 'Thanks, appreciate it.']
    ]

    script.each_with_index { |(speaker, text), index| turn(session, index + 1, speaker, text) }

    session.session_events.create!(kind: 'session_started',  occurred_at: 55.minutes.ago)
    session.session_events.create!(kind: 'wrap_up_injected', occurred_at: 20.minutes.ago)

    session.coverage_analyses.create!(
      window_from_turn: 18,
      window_to_turn:   23,
      prompt_version:   Coverage::PromptVersion.digest,
      model:            ENV.fetch('GEMINI_FLASH_MODEL', 'gemini-2.0-flash-001'),
      status:           'succeeded'
    )
    session.session_events.create!(kind: 'coverage_analyzed', occurred_at: 18.minutes.ago)
    session.session_events.create!(kind: 'session_ended',    occurred_at: 17.minutes.ago)

    portfolio = Portfolio.unscoped.create!(
      session_id:        session.id,
      candidate_id:      CANDIDATE_ID,
      generation_status: 'complete',
      generated_at:      16.minutes.ago
    )

    react_skill = portfolio.portfolio_skills.create!(
      skill_id:           'SK-ENG-001',
      skill_label:        'React / Frontend Development Core',
      is_discovered:      false,
      ai_level:           3,
      ai_confidence:      'high',
      evidence:           [
        'I split the context into a read-only provider and a write provider, so components that only consume state stop re-rendering.',
        'Re-render count dropped about 60%, and we set a performance budget in CI so it could not silently regress.'
      ],
      competency_summary: 'Handles complex state architecture with explicit tradeoff reasoning and owns performance work end to end, including measurement. Consistent L3. The step to L4 is missing: the patterns stay with him instead of becoming team-level standards.'
    )

    portfolio.portfolio_skills.create!(
      skill_id:           'SK-ENG-009',
      skill_label:        'TypeScript & Type Systems',
      is_discovered:      false,
      ai_level:           3,
      ai_confidence:      'medium',
      evidence:           [
        'Generated types from the OpenAPI schema, plus a narrow hand-written mapper at the edge.',
        'Strict mode on the new files first, then a ratchet so the old ones could not get worse.'
      ],
      competency_summary: 'Treats types as a boundary contract rather than decoration and has run an incremental strict-mode migration. Evidence is solid but only two exchanges explored it.'
    )

    testing_skill = portfolio.portfolio_skills.create!(
      skill_id:           'SK-ENG-006',
      skill_label:        'Testing & Quality Assurance',
      is_discovered:      false,
      ai_level:           3,
      ai_confidence:      'medium',
      evidence:           [
        'Unit tests on pure logic, integration tests on the data-fetching layer with MSW, and a small set of end-to-end tests on critical user paths.',
        'Tag by risk instead of by page, run the critical path on every PR and the rest nightly, and delete tests that never caught anything.'
      ],
      competency_summary: 'Has a working test pyramid and reasons about suite cost, not just coverage. The end-to-end layer is still the weakest part of the story.'
    )

    portfolio.portfolio_skills.create!(
      skill_id:           nil,
      skill_label:        'Micro-frontend Architecture',
      is_discovered:      true,
      ai_level:           2,
      ai_confidence:      'low',
      evidence:           [
        'We decomposed into four micro-frontends with module federation and a shared design system shell.'
      ],
      competency_summary: 'Hands-on with module federation and the coordination problems it creates. Only briefly explored — confidence is low and a dedicated session would be needed before acting on it.'
    )

    testing_skill.create_assessor_override!(
      ai_level:       3,
      override_level: 2,
      assessor_notes: 'E2E coverage in the last team was nominal — the candidate described intent, not a suite that actually gated releases.',
      overridden_by:  ASSESSOR_ID,
      overridden_at:  10.minutes.ago
    )

    comparisons = vacancy.vacancy_skills.order(:id).map do |vacancy_skill|
      skill = portfolio.portfolio_skills.find { |s| s.skill_id == vacancy_skill.skill_id } ||
              portfolio.portfolio_skills.find { |s| s.skill_label.casecmp?(vacancy_skill.skill_label) }

      candidate_level =
        if skill.nil? then nil
        elsif skill.assessor_override then skill.assessor_override.override_level
        else skill.ai_level
        end

      delta = candidate_level ? candidate_level - vacancy_skill.expected_level : nil
      result =
        if candidate_level.nil? then 'not_assessed'
        elsif delta.zero? then 'match'
        elsif delta.positive? then 'exceed'
        else 'gap'
        end

      {
        skill_label:     vacancy_skill.skill_label,
        skill_id:        vacancy_skill.skill_id,
        candidate_level: candidate_level,
        expected_level:  vacancy_skill.expected_level,
        result:          result,
        delta:           delta,
        confidence:      skill&.ai_confidence
      }
    end

    FitGapReport.unscoped.create!(
      portfolio_id:      portfolio.id,
      vacancy_id:        vacancy.id,
      skill_comparisons: comparisons,
      culture_narrative: "Ahmad frames problems commercially — he measured the render cost before touching the architecture and set a budget so it could not regress. That ownership pattern fits TechCorp's measurement-driven culture. The one flag is the testing gap below: the intent is there, the enforcement habit is not yet.",
      overall_narrative:  'Strong match on core frontend depth and type discipline, with a one-level gap on testing that is worth probing in the hiring conversation. Recommend advancing to a technical interview focused on how this candidate raises quality standards for a team, not just for their own work.',
      generated_at:      9.minutes.ago
    )

    puts "  [demo] completed session ##{session.id} (+#{session.transcript_turns.count} turns, #{portfolio.portfolio_skills.count} portfolio skills, fit/gap vs vacancy ##{vacancy.id})"
  end

  # ── scenario 2: interview in progress (Live Monitor) ─────────────────────────

  def running(assessment)
    session = session_for(
      assessment,
      status:     'active',
      started_at: 7.minutes.ago
    )

    coverage(session, assessment, states: [
      ['covered', 4, 'Strong signal on state partitioning and profiling; enough for a confident L3'],
      ['partial', 2, 'Type boundaries discussed once; no migration experience explored yet'],
      ['not_yet', 0, nil]
    ])

    [
      ['ai',        "Hi Ahmad, thanks for joining. Let's jump straight in — tell me about the most technically challenging frontend project you've worked on recently."],
      ['candidate', "A real-time logistics dashboard — hundreds of concurrent updates per second, and the challenge was keeping React state in sync without tanking the frame rate."],
      ['ai',        'Hundreds of concurrent updates is significant. How was that state managed, and what was breaking before you fixed it?'],
      ['candidate', "Redux with every websocket event dispatching an action. We profiled it: about 80% of renders were unnecessary. Moving ephemeral state local and keeping only shared state in Redux cut renders by roughly 60%."],
      ['ai',        'What tooling did you use to decide where that line sits?'],
      ['candidate', "React DevTools Profiler for the render counts and the Chrome performance tab for layout thrash. The rule we settled on was: shared or persisted stays in Redux, everything else stays close to the component."]
    ].each_with_index { |(speaker, text), index| turn(session, index + 1, speaker, text) }

    puts "  [demo] running session ##{session.id} (+#{session.transcript_turns.count} turns) — monitor: /assessments/#{assessment.id}/sessions/#{session.id}/monitor"
  end

  # ── scenario 3: fresh invite link ────────────────────────────────────────────

  def pending(assessment)
    session = session_for(assessment, status: 'pending')
    puts "  [demo] pending session ##{session.id} — invite: http://localhost:5173/interview/#{session.invite_token}"
  end

  # ── scenario 4: deliberately degraded run (shows the quality findings panel) ─
  #
  # Two defects are seeded as data, never by touching the evaluator:
  #   1. the session claims all_covered while Testing is still partial;
  #   2. no session_events / coverage_analyses rows were ever written, so the
  #      closing line has no wrap-up signal and the turns were never analysed.

  def degraded(assessment)
    session = session_for(
      assessment,
      status:         'ended',
      end_reason:     'all_covered',
      started_at:     48.minutes.ago,
      ended_at:       12.minutes.ago,
      duration:       2160,
      candidate_name: 'Budi Santoso (Demo)'
    )

    coverage(session, assessment, states: [
      ['covered', 5, 'Reducer ownership, render scope and measured typing latency explored in depth'],
      ['covered', 3, 'Generated API types, view-model mapping and an incremental strict-mode migration'],
      ['partial', 3, 'Only unit tests and two Playwright flows described; drag interactions never covered']
    ])

    [
      ['ai',        "Hi Budi, thanks for joining. Let's start with the React work you're most proud of — what was the hardest state problem you had to solve?"],
      ['candidate', 'An onboarding builder where users drag steps around while the preview re-renders. The tree was deep, and every keystroke in a step settings panel re-rendered the whole canvas.'],
      ['ai',        'How did you keep that from turning into a rewrite?'],
      ['candidate', 'I moved the draft into a reducer with a single action log, memoised the step list on the step ids, and kept the live editing text in local state. The canvas subscribed to the store with one selector per step instead of a selector for the whole tree.'],
      ['ai',        'What did you measure before and after that change?'],
      ['candidate', 'Typing latency in the settings panel — it went from around 120 milliseconds to under 40 on the mid-range laptop we tested on. I used the profiler to confirm the step components stopped re-rendering on every keystroke.'],
      ['ai',        "Let's talk about types. Where do you draw the boundary between what the API returns and what the components consume?"],
      ['candidate', 'The API types are generated, but components get a mapped view model, because a nullable address and an absent address mean different things in the UI. I keep the mapper in one module so the conversion is testable.'],
      ['ai',        'Have you had to do that kind of work in an existing JavaScript codebase?'],
      ['candidate', 'Yes — one dashboard was plain JS. I started by adding types to the API client only, enabled strict mode for that folder, and then lifted components over one at a time when someone touched them.'],
      ['ai',        'And how do you convince a team not to stop halfway through that migration?'],
      ['candidate', 'A ratchet in CI: existing files get grandfathered, but every file touched has to pass strict checks. It is visible in the pull request, which is usually incentive enough.'],
      ['ai',        'Last topic: what does testing look like on that team?'],
      ['candidate', 'Honestly it is mostly unit tests for the reducer and a couple of Playwright flows for the builder. We never found time to cover the drag interactions, so the most fragile part is the least tested.'],
      ['ai',        "Thanks for your time — you'll hear back from the team soon."]
    ].each_with_index { |(speaker, text), index| turn(session, index + 1, speaker, text) }

    portfolio = Portfolio.unscoped.create!(
      session_id:        session.id,
      candidate_id:      CANDIDATE_ID,
      generation_status: 'complete',
      generated_at:      11.minutes.ago
    )

    portfolio.portfolio_skills.create!(
      skill_id:           'SK-ENG-001',
      skill_label:        'React / Frontend Development Core',
      is_discovered:      false,
      ai_level:           2,
      ai_confidence:      'high',
      evidence:           [
        'I moved the draft into a reducer with a single action log, memoised the step list on the step ids, and kept the live editing text in local state.',
        'Typing latency in the settings panel — it went from around 120 milliseconds to under 40 on the mid-range laptop we tested on.'
      ],
      competency_summary: 'Comfortable owning component state and render scope, and measures the result rather than guessing. The work stays local to the editor component; there is no evidence yet of setting a rendering or performance standard for the team.'
    )

    portfolio.portfolio_skills.create!(
      skill_id:           'SK-ENG-009',
      skill_label:        'TypeScript & Type Systems',
      is_discovered:      false,
      ai_level:           2,
      ai_confidence:      'medium',
      evidence:           [
        'The API types are generated, but components get a mapped view model, because a nullable address and an absent address mean different things in the UI.',
        'I started by adding types to the API client only, enabled strict mode for that folder, and then lifted components over one at a time when someone touched them.'
      ],
      competency_summary: 'Understands the API/UI type boundary and has run a pragmatic strict-mode migration with a CI ratchet. The evidence is one project deep and the exploration stopped before harder generics or library typing were discussed.'
    )

    portfolio.portfolio_skills.create!(
      skill_id:           'SK-ENG-006',
      skill_label:        'Testing & Quality Assurance',
      is_discovered:      false,
      ai_level:           2,
      ai_confidence:      'low',
      evidence:           [
        'Honestly it is mostly unit tests for the reducer and a couple of Playwright flows for the builder. We never found time to cover the drag interactions, so the most fragile part is the least tested.'
      ],
      competency_summary: 'Knows the shape of a reasonable test suite and can name what is missing, but describes an incomplete pyramid in practice. Only one topic was explored and the interview closed before the gap could be probed further.'
    )

    puts "  [demo] degraded demo session ##{session.id} — expected verdict invalid"
    session
  end
end

if Rails.env.production?
  puts '  [demo] skipped (production)'
else
  DemoSeed.call
end
