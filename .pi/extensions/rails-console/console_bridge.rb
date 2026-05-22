#!/usr/bin/env ruby
# frozen_string_literal: true

# Rails Console Bridge
# Loads the Rails environment and provides a REPL-like protocol over stdin/stdout.
# Used by the pi rails-console extension to give the AI persistent access to a
# Rails console without writing one-off scripts.

require 'stringio'
require 'json'

$stdout.sync = true
$stderr.sync = true

rails_root = ARGV[0] || Dir.pwd

begin
  # Load Rails environment (this is the slow part - models, gems, etc.)
  require File.join(rails_root, 'config/environment')
rescue LoadError => e
  puts({ status: "error", message: "Failed to load Rails: #{e.message}", phase: "boot" }.to_json)
  exit 1
rescue StandardError => e
  puts({ status: "error", message: "Error booting Rails: #{e.message}", phase: "boot" }.to_json)
  exit 1
end

# Signal that Rails is loaded and ready
puts({ status: "ready" }.to_json)

# Persistent binding so variables, classes, and state survive across evals
$eval_binding = binding

# Keep track of eval count for debugging
$eval_count = 0

# Main REPL loop
loop do
  # Read code until __END__ delimiter (supports multi-line input)
  code_lines = []
  while (line = STDIN.gets)
    line = line.chomp
    break if line == "__END__"
    code_lines << line
  end

  # Exit if stdin closed
  break if code_lines.empty? && STDIN.eof?

  code = code_lines.join("\n")
  next if code.strip.empty?

  $eval_count += 1

  begin
    # Capture stdout so puts/print inside eval don't break the JSON protocol
    captured_stdout = StringIO.new
    original_stdout = $stdout
    $stdout = captured_stdout

    result = eval(code, $eval_binding, "(console)", $eval_count)

    $stdout = original_stdout

    output = captured_stdout.string
    result_str = result.inspect

    # Truncate if result is massive (50KB limit, like pi built-in tools)
    if result_str.bytesize > 50_000
      result_str = result_str.byteslice(0, 50_000) + "...[truncated]"
    end

    puts({
      status: "ok",
      result: result_str,
      output: output.empty? ? nil : output,
      result_class: result.class.name
    }.to_json)

  rescue SystemExit, Interrupt
    break
  rescue Exception => e
    $stdout = original_stdout if defined?(original_stdout)

    puts({
      status: "error",
      error_class: e.class.name,
      message: e.message,
      backtrace: e.backtrace&.first(10)
    }.to_json)
  end
end
