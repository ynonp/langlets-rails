# lib/langsmith.rb
require 'opentelemetry-api'

module Langsmith
  class TracerWrapper
    def initialize(span)
      @span = span
    end

    def set_prompt_content(instructions, user_content)
      # Set system prompt
      @span.set_attribute("gen_ai.prompt.0.role", "system")
      @span.set_attribute("gen_ai.prompt.0.content", instructions)
      
      # Set user prompt
      @span.set_attribute("gen_ai.prompt.1.role", "user")
      @span.set_attribute("gen_ai.prompt.1.content", user_content.to_s)
    end

    def trace(llm_response)
      # Customize based on RubyLLM / OpenAI / Gemini format
      if llm_response.respond_to?(:model)
        @span.set_attribute("gen_ai.response.model", llm_response.model)
      end

      if llm_response.respond_to?(:content)
        content = llm_response.content

        # Set the completion content according to GenAI semantic conventions
        @span.set_attribute("gen_ai.completion.0.role", "assistant")
        
        if content.is_a?(Hash)
          # For structured responses, store as JSON string
          @span.set_attribute("gen_ai.completion.0.content", content.to_json)
        elsif content.is_a?(String)
          @span.set_attribute("gen_ai.completion.0.content", content)
        end
      end

      if llm_response.respond_to?(:usage)
        usage = llm_response.usage
        @span.set_attribute("gen_ai.usage.prompt_tokens", usage.prompt_tokens)
        @span.set_attribute("gen_ai.usage.completion_tokens", usage.completion_tokens)
        @span.set_attribute("gen_ai.usage.total_tokens", usage.total_tokens)
      end
    end
  end

  def self.trace(name, attributes: {}, &block)
    tracer = OpenTelemetry.tracer_provider.tracer('langsmith')
    tracer.in_span(name, attributes: default_attributes.merge(attributes)) do |span|
      yield TracerWrapper.new(span)
    end
  end

  def self.default_attributes
    {
      "langsmith.span.kind" => "LLM",
    }
  end
end

