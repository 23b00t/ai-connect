# frozen_string_literal: true

require "open3"

module AIConnect
  class CopilotClient
    DEFAULT_MODEL = "gpt-4.1"

    def initialize(model: DEFAULT_MODEL)
      @model = model
    end

    def ask(prompt)
      stdout, stderr, status = Open3.capture3(*command(prompt))
      raise Error, stderr.strip unless status.success?

      stdout
    end

    private

    attr_reader :model

    def command(prompt)
      ["copilot", "--model", model, "-p", prompt, "-s"]
    end

    class Error < StandardError; end
  end
end
