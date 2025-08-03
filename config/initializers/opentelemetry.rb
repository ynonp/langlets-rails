require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'base64'

public_key = Rails.application.credentials.langfuse[:pk]
secret_key = Rails.application.credentials.langfuse[:secret]

auth_token = Base64.strict_encode64("#{public_key}:#{secret_key}")

exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(
  endpoint: "https://us.cloud.langfuse.com/api/public/otel/v1/traces",
  headers: { "Authorization" => "Basic #{auth_token}" },
)

span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)

OpenTelemetry::SDK.configure do |c|
  c.add_span_processor(span_processor)
end
