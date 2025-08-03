# lib/langsmith.rb
require 'opentelemetry-api'

module Langsmith
  class TracerWrapper
    def initialize(span)
      @span = span
    end

    def trace(llm_response)
      # Customize based on RubyLLM / OpenAI / Gemini format
      if llm_response.respond_to?(:model)
        @span.set_attribute("gen_ai.response.model", llm_response.model)
      end

      if llm_response.respond_to?(:content)
        content = llm_response.content

        if content.is_a?(Hash) && content["phrases"].is_a?(Array)
          @span.set_attribute("gen_ai.response.phrase_count", content["phrases"].count)
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

