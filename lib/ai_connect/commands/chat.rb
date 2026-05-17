# frozen_string_literal: true

require_relative "../copilot_client"
require_relative "base"

module AIConnect
  module Commands
    class Chat < Base
      CHAT_FILE_PATH = "/tmp/ai-chat.md"
      ME_HEADER_PATTERN = /^##\s*me\s*$/

      def call
        response = CopilotClient.new.ask(build_prompt, cwd: cwd)
        stdout.puts
        stdout.puts("## ai")
        stdout.puts
        stdout.puts(response.rstrip)
        stdout.puts
        stdout.puts("## me")
        0
      rescue Errno::ENOENT
        stderr.puts("Chat file not found: #{CHAT_FILE_PATH}")
        1
      rescue ArgumentError => e
        stderr.puts(e.message)
        1
      rescue CopilotClient::Error => e
        stderr.puts("Copilot error: #{e.message}")
        1
      end

      private

      def build_prompt
        template = latest_me_prompt(File.read(CHAT_FILE_PATH))
        file_references = []

        prompt = template.gsub(/@\{file:([^}]+)\}/) do
          resolved_paths = resolve_file_reference(Regexp.last_match(1).strip)
          file_references.concat(resolved_paths)
          resolved_paths.join(", ")
        end

        prompt = prompt.gsub("@{cwd}", cwd)

        sections = [
          "You are replying in an ongoing markdown chat transcript.",
          "You may only inspect files with the view tool.",
          "Do not edit files, run commands, or claim that you changed anything.",
          "Do not describe intended actions or tool usage.",
          "Answer only with the assistant reply body in markdown.",
          "Be concrete and complete: if the user asks for code, a refactor, a patch, or a replacement, provide the exact code directly instead of general advice.",
          "If useful, include fenced code blocks with the final code the user can paste.",
          "Never guess about file contents. If the request mentions a file path, inspect that file before answering and base the answer on what you found there.",
          "Global project context: the current working directory is #{cwd}."
        ]

        unless file_references.empty?
          unique_paths = file_references.uniq
          sections << <<~TEXT.strip
            You must inspect these referenced files before answering:
            #{unique_paths.map { |path| "- #{path}" }.join("\n")}
            Use their actual contents in your answer. Do not say that you assume what is inside them.
          TEXT
        end

        sections << "User request:\n#{prompt.strip}"
        sections.join("\n\n")
      end

      def latest_me_prompt(content)
        marker = content.enum_for(:scan, ME_HEADER_PATTERN).map { Regexp.last_match.begin(0) }.last
        raise ArgumentError, "No ## me section found in #{CHAT_FILE_PATH}" if marker.nil?

        prompt = content[(marker + content[marker..].lines.first.length)..]
        raise ArgumentError, "The last ## me section in #{CHAT_FILE_PATH} is empty" if prompt.nil? || prompt.strip.empty?

        prompt
      end

      def resolve_file_reference(reference)
        direct_path = File.expand_path(reference, cwd)
        return [direct_path] if File.file?(direct_path)

        matches = Dir.glob(File.join(cwd, "**", File.basename(reference))).select { |path| File.file?(path) }.sort
        raise ArgumentError, "Could not find #{reference.inspect} under #{cwd}" if matches.empty?

        matches
      end
    end
  end
end
