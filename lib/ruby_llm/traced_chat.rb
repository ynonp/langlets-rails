# frozen_string_literal: true

module RubyLLM
  # Represents a conversation with an AI model
  def self.traced_chat(...)
    TracedChat.new(...)
  end

  class TracedChat < Chat
    attr_reader :span_name

    def initialize(span_name:, **kwargs)
      @span_name = span_name
      super(**kwargs)
    end

    def complete
      LangfuseTracer.in_span(span_name, attributes: {
        "input" => to_json,
        "gen_ai.prompt_json" => to_json,
        "gen_ai.request.model"  => model.name
      }) do |span|
        messages.each_with_index do |message, index|
          span.set_attribute("gen_ai.prompt.#{index}.role", message.role.to_s)
          span.set_attribute("gen_ai.prompt.#{index}.content", message.content.to_s)
        end
        result = super

        span.set_attribute("gen_ai.completion.0.role", result.role)
        span.set_attribute("gen_ai.completion.0.content", result.content)
        span.set_attribute("gen_ai.completion_json", result.to_json)

        result
      end
    end
  end
end
