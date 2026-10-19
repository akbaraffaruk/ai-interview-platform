# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionEvents::Recorder do
  let(:session) { create(:session) }

  it 'records an event with payload' do
    event = described_class.call(session, 'gemini_reconnect', attempt: 2, reason: 'go_away')

    expect(event).to be_persisted
    expect(event.kind).to eq('gemini_reconnect')
    expect(event.payload).to eq('attempt' => 2, 'reason' => 'go_away')
  end

  it 'rejects an unknown kind without raising' do
    expect { described_class.call(session, 'not_a_kind') }.not_to raise_error
    expect(session.session_events.count).to eq(0)
  end

  it 'never raises when the database write fails' do
    allow(SessionEvent).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'boom')

    expect { described_class.call(session, 'session_started') }.not_to raise_error
  end
end
