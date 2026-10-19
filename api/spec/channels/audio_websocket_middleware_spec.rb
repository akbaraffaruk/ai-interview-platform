# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AudioWebSocketMiddleware do
  subject(:middleware) { described_class.new(->(_env) { [200, {}, []] }) }

  let(:session) { create(:session) }
  let(:state)   { described_class::ConnectionState.new }
  let(:client)  { double('gemini client') }

  before do
    state.session = session
    state.gemini_client = client
  end

  def deliver!(key: :ceiling, signal: 'signal')
    middleware.send(:mark_warning_if_delivered, state, key, signal, session)
  end

  it 'reports delivered and records the warning when the signal reaches the model' do
    allow(client).to receive(:inject_context).with('signal').and_return(true)

    expect { expect(deliver!).to be true }.to change { session.session_events.count }.by(1)
    expect(session.session_events.of_kind('time_warning').sole.payload).to eq('key' => 'ceiling')
  end

  it 'reports not delivered and records nothing when the signal cannot be injected' do
    allow(client).to receive(:inject_context).with('signal').and_return(false)

    expect { expect(deliver!).to be false }.not_to(change { session.session_events.count })
  end

  it 'is idempotent per key: a second attempt reports not delivered and records nothing extra' do
    allow(client).to receive(:inject_context).with('signal').and_return(true)
    deliver!

    expect { expect(deliver!).to be false }.not_to(change { session.session_events.count })
  end
end
