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
        options, arguments = parse_options(argv)
        file_path = file_path_for(options, arguments)
        # Determine the format based on the file path
        format = format_for(file_path)
        # Gather context information for the file
        context = suggesting?(options) ? suggest_context_for(file_path, arguments) : context_for(file_path)
        # Build the prompt for Copilot using format, context, and options
        prompt = build_prompt(
          format: format,
          context: context,
          options: options,
          arguments: arguments,
          file_path: file_path
        )

        # Send prompt to Copilot and clean the markdown response
        response = MarkdownResponse.clean(
          CopilotClient.new.ask(prompt, cwd: copilot_cwd_for(file_path)),
          strip: !options[:suggest]
        )

        # If not in annotation mode, output stdin contents
        if echo_stdin?(options)
          stdout.puts stdin
        end
        # Output Copilot's response
        write_response(response, options)
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
      #   -s, --suggest       # Suggest a completion at the cursor
      def parse_options(arguments)
        options = { comment: false, doc_comment: false, suggest: false }
        remaining = arguments.dup

        parser = OptionParser.new do |opts|
          opts.on("-c", "--comment", "Comment the selected code") do
            options[:comment] = true
          end

          opts.on("-dc", "--doc-comment", "Add doc comments using language best practices") do
            options[:doc_comment] = true
          end

          opts.on("-s", "--suggest", "Suggest a completion at the cursor") do
            options[:suggest] = true
          end
        end

        parser.parse!(remaining)
        validate_options!(options)
        validate_arguments!(options, remaining)
        [options, remaining]
      end

      def validate_options!(options)
        return unless [options[:comment], options[:doc_comment], options[:suggest]].count(true) > 1

        raise OptionParser::ParseError, "Please choose only one of --comment, --doc-comment, or --suggest."
      end

      def validate_arguments!(options, arguments)
        return unless options[:suggest] && arguments.length != 3

        raise OptionParser::ParseError, "Please provide CURSOR_LINE_NUMBER, CURSOR_COLUMN, and FILE_PATH for --suggest."
      end

      def file_path_for(options, arguments)
        return arguments[2] if options[:suggest]

        arguments.first
      end

      def build_prompt(format:, context:, options:, arguments:, file_path:)
        return suggest_prompt(
          format: format,
          context: context,
          file_path: file_path,
          cursor_line_number: arguments[0],
          cursor_column: arguments[1]
        ) if options[:suggest]
        return doc_comment_prompt(format: format, context: context) if options[:doc_comment]
        return comment_prompt(format: format, context: context) if options[:comment]

        implementation_prompt(format: format, context: context)
      end

      def annotating?(options)
        options[:comment] || options[:doc_comment]
      end

      def suggesting?(options)
        options[:suggest]
      end

      def echo_stdin?(options)
        !annotating?(options) && !suggesting?(options)
      end

      def write_response(response, options)
        return stdout.print(response) if options[:suggest]

        stdout.puts response
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

      def suggest_prompt(format:, context:, file_path:, cursor_line_number:, cursor_column:)
        <<~PROMPT
          You are generating an inline code completion for an existing .#{format} file.
          Return only the exact text to insert at the cursor. Do not repeat text that already exists before the cursor.
          Do not explain anything. Do not wrap the response in markdown fences.
          The completion may finish the current line and add following lines, but it must be at most 10 lines total.
          Base the completion on the saved file context around the cursor location. Stay tightly local to that context.
          Preserve indentation, syntax correctness, naming, and the file's existing style.
          Prefer the smallest useful continuation. If the next text is genuinely unclear, return an empty response.

          File path:
          #{file_path}

          Cursor line number:
          #{cursor_line_number}

          Cursor column:
          #{cursor_column}

          Saved cursor context:
          #{context}
        PROMPT
      end

      def suggest_context_for(file_path, arguments)
        line_number = parse_cursor_line_number(arguments[0])
        column_number = parse_cursor_column(arguments[1])
        expanded_path = File.expand_path(file_path, cwd)
        raise OptionParser::ParseError, "FILE_PATH must point to an existing file for --suggest." unless File.file?(expanded_path)

        lines = File.readlines(expanded_path, chomp: true)
        raise OptionParser::ParseError, "CURSOR_LINE_NUMBER is outside the file." if line_number > lines.length

        current_line = lines.fetch(line_number - 1, "")
        graphemes = current_line.scan(/\X/)
        prefix = graphemes[0, [column_number - 1, graphemes.length].min].join
        suffix = graphemes[[column_number - 1, graphemes.length].min..]&.join.to_s
        window_start = [line_number - 5, 1].max
        window_end = [line_number + 5, lines.length].min

        excerpt = (window_start..window_end).map do |number|
          marker = number == line_number ? ">>" : "  "
          "#{marker} #{number}: #{lines[number - 1]}"
        end.join("\n")

        <<~CONTEXT
          Cursor line text:
          #{current_line}

          Text before cursor:
          #{prefix}

          Text after cursor:
          #{suffix}

          Nearby lines:
          #{excerpt}
        CONTEXT
      end

      def parse_cursor_line_number(value)
        number = Integer(value, 10)
        raise OptionParser::ParseError, "CURSOR_LINE_NUMBER must be a positive integer." if number <= 0

        number
      rescue ArgumentError
        raise OptionParser::ParseError, "CURSOR_LINE_NUMBER must be a positive integer."
      end

      def parse_cursor_column(value)
        number = Integer(value, 10)
        raise OptionParser::ParseError, "CURSOR_COLUMN must be a positive integer." if number <= 0

        number
      rescue ArgumentError
        raise OptionParser::ParseError, "CURSOR_COLUMN must be a positive integer."
      end

      def usage
        "Usage: connect.rb inline [--comment|-c|--doc-comment|-dc] [file_path]\n" \
          "       connect.rb inline --suggest|-s CURSOR_LINE_NUMBER CURSOR_COLUMN FILE_PATH"
      end
    end
  end
end
