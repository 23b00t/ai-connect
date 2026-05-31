# frozen_string_literal: true

require "optparse"

require_relative "../copilot_client"
require_relative "../markdown_response"
require_relative "base"

module AIConnect
  module Commands
    class Inline < Base
      # Executes the main logic for the Inline command.
      #
      # Parses command-line options, determines the file format, gathers context,
      # builds a prompt for Copilot, sends the prompt, and outputs the response.
      # Handles annotation and implementation modes, as well as error handling for
      # option parsing and Copilot client errors.
      #
      # @return [Integer] Exit code (0 for success, 1 for error)
      def call
        # Parse command-line options and extract file path
        options, file_path = parse_options(argv)
        # Determine the format based on the file path
        format = format_for(file_path)
        # Gather context information for the file
        context = context_for(file_path)
        # Build the prompt for Copilot using format, context, and options
        prompt = build_prompt(format: format, context: context, options: options)

        # Send prompt to Copilot and clean the markdown response
        response = MarkdownResponse.clean(CopilotClient.new.ask(prompt))

        # If not in annotation mode, output stdin contents
        unless annotating?(options)
          stdout.puts stdin
        end
        # Output Copilot's response
        stdout.puts response
        0 # Success exit code
      rescue OptionParser::ParseError => e
        # Handle option parsing errors
        stderr.puts e.message
        stderr.puts usage
        1 # Error exit code
      rescue CopilotClient::Error => e
        # Handle Copilot client errors
        stderr.puts "Copilot error: #{e.message}"
        1 # Error exit code
      end

      private

      # Parses command-line options for commenting and documentation features.
      # 
      # @param arguments [Array<String>] The command-line arguments to parse.
      # @return [Array<Hash, String>] A tuple containing the options hash and the first remaining argument.
      # 
      # Recognized options:
      #   -c, --comment       # Comment the selected code
      #   -dc, --doc-comment  # Add doc comments using language best practices
      def parse_options(arguments)
        options = { comment: false, doc_comment: false }
        remaining = arguments.dup

        parser = OptionParser.new do |opts|
          opts.on("-c", "--comment", "Comment the selected code") do
            options[:comment] = true
          end

          opts.on("-dc", "--doc-comment", "Add doc comments using language best practices") do
            options[:doc_comment] = true
          end
        end

        parser.parse!(remaining)
        validate_options!(options)
        [options, remaining.first]
      end

      def validate_options!(options)
        return unless options[:comment] && options[:doc_comment]

        raise OptionParser::ParseError, "Please choose either --comment or --doc-comment."
      end

      def build_prompt(format:, context:, options:)
        return doc_comment_prompt(format: format, context: context) if options[:doc_comment]
        return comment_prompt(format: format, context: context) if options[:comment]

        implementation_prompt(format: format, context: context)
      end

      def annotating?(options)
        options[:comment] || options[:doc_comment]
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

      def doc_comment_prompt(format:, context:)
        <<~PROMPT
          You are an expert .#{format} developer. Only output valid .#{format} code.
          Ensure consistency with the following context:
          #{context}

          Add documentation comments to the following selected .#{format} code using the language's best practices and conventions. Return only the documented code.
          #{stdin}
        PROMPT
      end

      def usage
        "Usage: connect.rb inline [--comment|-c|--doc-comment|-dc] [file_path]"
      end
    end
  end
end
