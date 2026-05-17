# frozen_string_literal: true

module AIConnect
  module MarkdownResponse
    module_function

    def clean(text)
      match = text.match(/```[a-zA-Z0-9_+-]*\n(.*?)```/m)
      match ? match[1].strip : text.strip
    end
  end
end
