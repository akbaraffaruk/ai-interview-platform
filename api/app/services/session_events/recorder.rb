# frozen_string_literal: true

module SessionEvents
  # The single write path for session events.
  # Called from the live audio path, so it must never raise: a lost event is
  # acceptable, a dropped interview is not.
  module Recorder
    module_function

    def call(session, kind, payload = {})
      kind = kind.to_s
      unless SessionEvent::KINDS.include?(kind)
        Rails.logger.warn("[SessionEvents] Unknown kind #{kind.inspect} for session #{session&.id}")
        return nil
      end

      SessionEvent.create!(
        session_id:  session.id,
        kind:        kind,
        payload:     payload.compact,
        occurred_at: Time.current
      )
    rescue StandardError => e
      Rails.logger.error("[SessionEvents] Failed to record #{kind} for session #{session&.id}: #{e.class} #{e.message}")
      nil
    end
  end
end
