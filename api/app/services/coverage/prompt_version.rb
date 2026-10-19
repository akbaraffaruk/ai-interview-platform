# frozen_string_literal: true

require 'digest'

module Coverage
  # The analyser prompt is a contract with the model: state rules, the probe
  # gate, the confidence test. Ledger rows record which version produced a
  # decision, so a later prompt change can be compared instead of guessed.
  module PromptVersion
    module_function

    # Bump deliberately when the prompt contract changes; the digest also
    # changes on its own when the template text does.
    CONTRACT = 'coverage-analyzer/v1'

    def digest(template = prompt_template)
      Digest::SHA256.hexdigest("#{CONTRACT}\n#{template}")[0, 12]
    end

    def prompt_template
      @prompt_template ||= File.read(
        Rails.root.join('app/services/coverage/analyzer_prompt.txt')
      )
    rescue Errno::ENOENT
      # Until the template is extracted, hash the contract only.
      CONTRACT
    end

    # Test-only helper: hash an arbitrary template without touching the file.
    def stub_prompt_template(template)
      digest(template)
    end
  end
end
