# frozen_string_literal: true

require "optparse"

require_relative "../copilot_client"
require_relative "../markdown_response"
require_relative "base"

module AIConnect
  module Commands
    class Inline < Base
      def call
        options, file_path = parse_options(argv)
        format = format_for(file_path)
        context = context_for(file_path)
        prompt = build_prompt(format: format, context: context, comment: options[:comment])

        response = MarkdownResponse.clean(CopilotClient.new.ask(prompt))

        unless options[:comment]
          stdout.puts stdin
        end
        stdout.puts response
        0
      rescue OptionParser::ParseError => e
        stderr.puts e.message
        stderr.puts usage
        1
      rescue CopilotClient::Error => e
        stderr.puts "Copilot error: #{e.message}"
        1
      end

      private

      def parse_options(arguments)
        options = { comment: false }
        remaining = arguments.dup

        parser = OptionParser.new do |opts|
          opts.on("-c", "--comment", "Comment the selected code instead of implementing it") do
            options[:comment] = true
          end
        end

        parser.parse!(remaining)
        [options, remaining.first]
      end

      def build_prompt(format:, context:, comment:)
        comment ? comment_prompt(format: format, context: context) : implementation_prompt(format: format, context: context)
      end

      def implementation_prompt(format:, context:)
        <<~PROMPT
          You are an expert .#{format} developer. Only output valid .#{format} code.
          Ensure consistency with the following context:
          #{context}

          Implement the following prompt in .#{format} and return only the implementation.
          #{stdin}
        PROMPT
      end

      def comment_prompt(format:, context:)
        <<~PROMPT
          You are an expert .#{format} developer. Only output valid .#{format} code.
          Ensure consistency with the following context:
          #{context}

          Add concise, useful comments to the following selected .#{format} code and return only the commented code.
          #{stdin}
        PROMPT
      end

      def usage
        "Usage: connect.rb inline [--comment|-c] [file_path]"
      end
    end
  end
end
