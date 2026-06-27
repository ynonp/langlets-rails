class TracedChat < RubyLLM::Chat
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
        span.set_attribute("gen_ai.prompt.#{index}.content", String.new(message.content.to_s))
      end
      messages.each {|m| puts m.content }
      result = super

      # With a schema, result.content is a parsed Hash rather than a String.
      completion_text = result.content.is_a?(String) ? result.content : result.content.to_json
      span.set_attribute("gen_ai.completion.0.role", result.role.to_s)
      span.set_attribute("gen_ai.completion.0.content", String.new(completion_text))
      span.set_attribute("gen_ai.completion_json", result.to_json)

      result
    end
  end
end

