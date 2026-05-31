# frozen_string_literal: true

module AIConnect
  module MarkdownResponse
    module_function

    def clean(text, strip: true)
      match = text.match(/```[a-zA-Z0-9_+-]*\n(.*?)```/m)
      body = match ? match[1] : text
      strip ? body.strip : body
    end
  end
end
