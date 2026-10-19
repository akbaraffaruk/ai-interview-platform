# frozen_string_literal: true

# One row per N7 run. Makes "was every candidate turn actually analysed, by which
# prompt and model" answerable after the fact — the old pipeline only logged it.
class CoverageAnalysis < ApplicationRecord
  STATUSES = %w[succeeded failed].freeze

  belongs_to :session

  validates :status, inclusion: { in: STATUSES }
  validates :prompt_version, presence: true
  validates :window_from_turn, :window_to_turn, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validate  :window_is_ordered

  scope :chronological, -> { order(:created_at, :id) }
  scope :succeeded,     -> { where(status: 'succeeded') }

  def covered_turn?(turn_number)
    turn_number.between?(window_from_turn, window_to_turn)
  end

  private

  def window_is_ordered
    return if window_from_turn.nil? || window_to_turn.nil?

    errors.add(:window_to_turn, 'must be greater than or equal to window_from_turn') if window_to_turn < window_from_turn
  end
end
