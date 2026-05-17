# frozen_string_literal: true

require_relative "base"

module AIConnect
  module Commands
    class Chat < Base
      def call
        stderr.puts "The chat command is prepared but not implemented yet."
        1
      end
    end
  end
end
