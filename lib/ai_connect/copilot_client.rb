# frozen_string_literal: true

require "open3"

module AIConnect
  class CopilotClient
    DEFAULT_MODEL = "gpt-4.1"
    SUGGEST_MODEL = "gpt-5-mini"
    CHAT_TOOLS = "view"

    def initialize(model: DEFAULT_MODEL)
      @model = model
    end

    def ask(prompt, cwd: nil)
      stdout, stderr, status = Open3.capture3(*command(prompt, cwd: cwd))
      raise Error, stderr.strip unless status.success?

      stdout
    end

    private

    attr_reader :model

    def command(prompt, cwd:)
      command = [
        "copilot",
        "--model", model,
        "--allow-tool=#{CHAT_TOOLS}",
        "--available-tools=#{CHAT_TOOLS}",
        "--no-ask-user",
        "-p", prompt,
        "-s"
      ]

      command.concat(["--add-dir", cwd]) if cwd
      command
    end

    class Error < StandardError; end
  end
end
