# frozen_string_literal: true

module AIConnect
  module Commands
    class Base
      def initialize(argv:, stdin:, cwd:, stdout:, stderr:)
        @argv = argv.dup
        @stdin = stdin
        @cwd = cwd
        @stdout = stdout
        @stderr = stderr
      end

      private

      attr_reader :argv, :stdin, :cwd, :stdout, :stderr

      def format_for(file_path)
        return "plain" if file_path.nil? || File.extname(file_path).empty?

        File.extname(file_path).delete_prefix(".")
      end

      def context_for(file_path)
        return "" if file_path.nil?

        expanded_path = File.expand_path(file_path, cwd)
        return "" unless File.file?(expanded_path)

        File.read(expanded_path)
      end

      def copilot_cwd_for(file_path)
        return cwd if file_path.nil?

        File.dirname(File.expand_path(file_path, cwd))
      end
    end
  end
end
