# frozen_string_literal: true

class CreateSessionEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :session_events do |t|
      t.references :session, null: false, foreign_key: true
      t.string :kind, null: false, limit: 50
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false, default: -> { 'now()' }
      t.datetime :created_at, null: false, default: -> { 'now()' }
    end

    add_index :session_events, %i[session_id occurred_at]
    add_index :session_events, %i[session_id kind]
  end
end
