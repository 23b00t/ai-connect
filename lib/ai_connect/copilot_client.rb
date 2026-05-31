# frozen_string_literal: true

require "open3"

module AIConnect
  class CopilotClient
    DEFAULT_MODEL = "gpt-4.1"
    CHAT_TOOLS = "view"

    def initialize(model: DEFAULT_MODEL)
      @model = model
    end

    def ask(prompt, cwd: nil)
      stdout, stderr, status = Open3.capture3(*command(prompt, cwd: cwd))
      raise Error, stderr.strip unless status.success?

      stdout
    end

    # Explain the following method
    def stream(prompt, cwd: nil)
      Open3.popen3(*command(prompt, cwd: cwd)) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        Thread.new do
          until (line = stderr.gets).nil?
            warn line
          end
        end
        return enum_for(:each_line, stdout, wait_thr)
      end
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

    def each_line(stdout, wait_thr)
      while (line = stdout.gets)
        yield line
      end
      wait_thr.value
    end

    class Error < StandardError; end
  end
end
