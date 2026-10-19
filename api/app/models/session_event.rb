# frozen_string_literal: true

# Append-only record of what actually happened inside a live interview.
# Nothing here is user-facing on its own — InterviewQuality::Evaluator reads it.
class SessionEvent < ApplicationRecord
  KINDS = %w[
    session_started
    gemini_connected
    gemini_reconnect
    wrap_up_injected
    time_warning
    system_text_leaked
    coverage_analyzed
    coverage_analysis_failed
    session_ended
  ].freeze

  belongs_to :session

  validates :kind, inclusion: { in: KINDS }
  validates :occurred_at, presence: true

  scope :ordered,  -> { order(:occurred_at, :id) }
  scope :of_kind,  ->(kind) { where(kind: Array(kind)) }

  def occurred?(before:)
    occurred_at < before
  end
end
