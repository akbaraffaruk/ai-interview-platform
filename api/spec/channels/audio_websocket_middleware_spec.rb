# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AudioWebSocketMiddleware do # rubocop:disable Metrics/BlockLength -- one spec file per middleware
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
    state.session = create(:session, tenant_id: session.tenant_id) # a different row: the helper must use its argument

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

  describe '#enforce_time_ceiling' do
    let(:browser_ws) { double('browser websocket') } # only touched by the 60s timer block

    before { allow(EM::Timer).to receive(:new).and_return(nil) }

    it 'records the wrap-up event only after the ceiling signal was delivered' do
      allow(client).to receive(:inject_context).and_return(true)

      expect { middleware.send(:enforce_time_ceiling, session, state, browser_ws) }
        .to change { session.session_events.of_kind('wrap_up_injected').count }.by(1)
      expect(state.ending_scheduled).to be(true)
      expect(session.session_events.of_kind('wrap_up_injected').sole.payload).to eq('trigger' => 'time_ceiling')
    end

    it 'leaves the event log clean when the ceiling signal could not be injected' do
      allow(client).to receive(:inject_context).and_return(false)

      expect { middleware.send(:enforce_time_ceiling, session, state, browser_ws) }
        .not_to(change { session.session_events.count })
      expect(state.ending_scheduled).to be(true)
    end
  end

  describe '#maybe_piggyback_wrap_up' do
    before do
      state.waiting_for_candidate_response = true
      state.wrap_up_injected = false
    end

    it 'records the injection and consumes the wait when the signal is delivered' do
      allow(client).to receive(:inject_context).and_return(true)

      expect { middleware.send(:maybe_piggyback_wrap_up, state, session) }
        .to change { session.session_events.of_kind('wrap_up_injected').count }.by(1)
      expect(state.wrap_up_injected).to be(true)
      expect(state.waiting_for_candidate_response).to be(false)
    end

    it 'leaves both the flag and the log untouched when the signal is refused, so a later turn can retry' do
      allow(client).to receive(:inject_context).and_return(false)

      expect { middleware.send(:maybe_piggyback_wrap_up, state, session) }
        .not_to(change { session.session_events.count })
      expect(state.wrap_up_injected).to be(false)
      expect(state.waiting_for_candidate_response).to be(true)
    end
  end
end
