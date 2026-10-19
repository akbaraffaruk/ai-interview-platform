# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionEvent, type: :model do
  it 'rejects an unknown kind' do
    event = build(:session_event, kind: 'made_up_kind')

    expect(event).not_to be_valid
    expect(event.errors[:kind]).to be_present
  end

  it 'orders events by occurrence' do
    session = create(:session)
    late    = create(:session_event, session: session, kind: 'session_ended', occurred_at: 2.minutes.ago)
    early   = create(:session_event, session: session, kind: 'session_started', occurred_at: 5.minutes.ago)

    expect(session.session_events.ordered.to_a).to eq([early, late])
  end
end
