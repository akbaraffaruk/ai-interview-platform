# frozen_string_literal: true

class CreateCoverageAnalyses < ActiveRecord::Migration[7.0]
  def change
    create_table :coverage_analyses do |t|
      t.references :session, null: false, foreign_key: true
      t.integer :window_from_turn, null: false
      t.integer :window_to_turn, null: false
      t.string  :prompt_version, null: false, limit: 32
      t.string  :model, limit: 100
      t.string  :status, null: false, default: 'succeeded', limit: 20
      t.integer :latency_ms
      t.jsonb   :applied_deltas, null: false, default: []
      t.string  :error_class, limit: 100
      t.datetime :created_at, null: false, default: -> { 'now()' }
    end

    add_index :coverage_analyses, %i[session_id created_at]
    add_index :coverage_analyses, %i[session_id window_to_turn], unique: true, name: 'idx_coverage_analyses_window'
  end
end
