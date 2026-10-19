# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Coverage::PromptVersion do
  it 'returns a short stable digest' do
    digest = described_class.digest

    expect(digest).to match(/\A[0-9a-f]{12}\z/)
    expect(described_class.digest).to eq(digest)
  end

  it 'changes when the prompt contract changes' do
    original = described_class.prompt_template
    stubbed  = described_class.stub_prompt_template(original + "\nEXTRA LINE")

    expect(stubbed).not_to eq(described_class.digest(original))
  end

  it 'loads the template from the file rather than falling back to the contract string' do
    expect(described_class.prompt_template).to include('%{skills}')
    expect(described_class.prompt_template).to include('%{coverage_json}')
    expect(described_class.prompt_template).to include('%{turn_count}')
    expect(described_class.prompt_template).to include('%{turns}')
  end

  it 'changes the digest when the contract string changes' do
    original = described_class.digest
    stub_const('Coverage::PromptVersion::CONTRACT', 'coverage-analyzer/v2')

    expect(described_class.digest).not_to eq(original)
  end
end
