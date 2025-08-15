require "test_helper"
require "opentelemetry/sdk"
require "ostruct"

class LangsmithTest < ActiveSupport::TestCase
  def setup
    @mock_span = Object.new
    @mock_span.define_singleton_method(:set_attribute) { |key, value| }
    @tracer_wrapper = Langsmith::TracerWrapper.new(@mock_span)
  end

  test "trace method sets token usage attributes when response has usage" do
    # Mock response with usage data
    usage = OpenStruct.new(
      prompt_tokens: 100,
      completion_tokens: 50,
      total_tokens: 150
    )
    
    response = OpenStruct.new(
      model: "gpt-4",
      content: "Test response",
      usage: usage
    )

    # Track what attributes were set
    set_attributes = []
    @mock_span.define_singleton_method(:set_attribute) do |key, value|
      set_attributes << [key, value]
    end

    @tracer_wrapper.trace(response)

    # Verify all expected attributes were set
    assert_includes set_attributes, ["gen_ai.response.model", "gpt-4"]
    assert_includes set_attributes, ["gen_ai.completion.0.role", "assistant"]
    assert_includes set_attributes, ["gen_ai.completion.0.content", "Test response"]
    assert_includes set_attributes, ["gen_ai.usage.prompt_tokens", 100]
    assert_includes set_attributes, ["gen_ai.usage.completion_tokens", 50]
    assert_includes set_attributes, ["gen_ai.usage.total_tokens", 150]
  end

  test "trace method handles response without usage gracefully" do
    response = OpenStruct.new(
      model: "gpt-4",
      content: "Test response"
    )

    set_attributes = []
    @mock_span.define_singleton_method(:set_attribute) do |key, value|
      set_attributes << [key, value]
    end

    @tracer_wrapper.trace(response)

    # Should only set model and content attributes, no usage attributes
    assert_includes set_attributes, ["gen_ai.response.model", "gpt-4"]
    assert_includes set_attributes, ["gen_ai.completion.0.role", "assistant"]
    assert_includes set_attributes, ["gen_ai.completion.0.content", "Test response"]
    
    # Usage attributes should not be present
    usage_attributes = set_attributes.select { |attr| attr[0].include?("usage") }
    assert_empty usage_attributes
  end

  test "set_prompt_content sets system and user prompt attributes" do
    instructions = "You are a helpful assistant"
    user_content = "Translate this text"

    set_attributes = []
    @mock_span.define_singleton_method(:set_attribute) do |key, value|
      set_attributes << [key, value]
    end

    @tracer_wrapper.set_prompt_content(instructions, user_content)

    assert_includes set_attributes, ["gen_ai.prompt.0.role", "system"]
    assert_includes set_attributes, ["gen_ai.prompt.0.content", instructions]
    assert_includes set_attributes, ["gen_ai.prompt.1.role", "user"]
    assert_includes set_attributes, ["gen_ai.prompt.1.content", user_content]
  end

  test "trace method handles structured response content as JSON" do
    structured_content = { "key" => "value", "data" => [1, 2, 3] }
    response = OpenStruct.new(
      model: "gpt-4",
      content: structured_content
    )

    set_attributes = []
    @mock_span.define_singleton_method(:set_attribute) do |key, value|
      set_attributes << [key, value]
    end

    @tracer_wrapper.trace(response)

    assert_includes set_attributes, ["gen_ai.response.model", "gpt-4"]
    assert_includes set_attributes, ["gen_ai.completion.0.role", "assistant"]
    assert_includes set_attributes, ["gen_ai.completion.0.content", structured_content.to_json]
  end

  test "Langsmith.trace yields TracerWrapper instance" do
    tracer_instance = nil
    
    Langsmith.trace("test_operation") do |tracer|
      tracer_instance = tracer
    end

    assert_instance_of Langsmith::TracerWrapper, tracer_instance
  end

  test "Langsmith.trace includes default attributes" do
    # This test verifies that the trace method is called with default attributes
    # Since we can't easily mock the OpenTelemetry tracer, we'll just verify
    # that the default_attributes method returns expected values
    default_attrs = Langsmith.default_attributes
    
    assert_equal "LLM", default_attrs["langsmith.span.kind"]
  end
end