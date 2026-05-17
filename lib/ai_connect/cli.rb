# frozen_string_literal: true

require_relative "commands/chat"
require_relative "commands/inline"

module AIConnect
  class CLI
    def self.start(argv:, stdin:, cwd:, stdout: $stdout, stderr: $stderr)
      new(argv: argv, stdin: stdin, cwd: cwd, stdout: stdout, stderr: stderr).start
    end

    def initialize(argv:, stdin:, cwd:, stdout:, stderr:)
      @argv = argv.dup
      @stdin = stdin
      @cwd = cwd
      @stdout = stdout
      @stderr = stderr
    end

    def start
      command_name = argv.first
      command_args = argv.drop(1)

      command = case command_name
      when "inline"
        Commands::Inline.new(argv: command_args, stdin: stdin, cwd: cwd, stdout: stdout, stderr: stderr)
      when "chat"
        Commands::Chat.new(argv: command_args, stdin: stdin, cwd: cwd, stdout: stdout, stderr: stderr)
      else
        stderr.puts usage
        return 1
      end

      command.call
    end

    private

    attr_reader :argv, :stdin, :cwd, :stdout, :stderr

    def usage
      <<~USAGE
        Usage:
          connect.rb inline [--comment|-c|--doc-comment|-dc] [file_path]
          connect.rb chat [file_path]
      USAGE
    end
  end
end
