# Applies the pipeline's patch operations to a CreateSongProgress data blob.
# Semantics mirror pipeline/src/progress.ts#applyOp exactly (the pipeline
# applies every op to its local copy through the same rules, so the two copies
# stay identical):
#
#   { "op" => "set",    "path" => "translations.he.phrases.3.text", "value" => ... }
#   { "op" => "append", "path" => "errors",                         "value" => ... }
#
# Paths are dot-separated; numeric segments index arrays. Missing intermediate
# containers are created on demand — an array when the next segment is numeric,
# a hash otherwise. "append" pushes onto an array, creating it when missing.
module ProgressPatch
  class InvalidOp < StandardError; end

  module_function

  def apply_all(data, ops)
    raise InvalidOp, "ops must be an array" unless ops.is_a?(Array)

    ops.each { |op| apply(data, op) }
    data
  end

  def apply(data, op)
    raise InvalidOp, "op must be an object" unless op.is_a?(Hash)

    kind = op["op"]
    raise InvalidOp, "unknown op #{kind.inspect}" unless %w[set append clear_errors].include?(kind)

    if kind == "clear_errors"
      raise InvalidOp, "clear_errors requires the errors path and a string step" unless op["path"] == "errors" && op["value"].is_a?(String)

      errors = data["errors"]
      return if errors.nil?
      raise InvalidOp, "clear_errors target is not an array: errors" unless errors.is_a?(Array)

      errors.reject! { |entry| entry.is_a?(Hash) && entry["step"] == op["value"] }
      return
    end

    segments = op["path"].to_s.split(".", -1)
    raise InvalidOp, "invalid patch path: #{op['path'].inspect}" if segments.empty? || segments.any?(&:empty?)

    node = data
    segments[0..-2].each_with_index do |segment, i|
      key = container_key(node, segment)
      node[key] = (numeric?(segments[i + 1]) ? [] : {}) if node[key].nil?
      node = node[key]
    end

    key = container_key(node, segments.last)
    if kind == "set"
      node[key] = op["value"]
    else
      node[key] = [] if node[key].nil?
      raise InvalidOp, "append target is not an array: #{op['path']}" unless node[key].is_a?(Array)

      node[key] << op["value"]
    end
  end

  def container_key(node, segment)
    case node
    when Array
      raise InvalidOp, "array index expected, got #{segment.inspect}" unless numeric?(segment)

      segment.to_i
    when Hash
      segment
    else
      raise InvalidOp, "cannot descend into #{node.class} at #{segment.inspect}"
    end
  end

  def numeric?(segment)
    segment.match?(/\A\d+\z/)
  end
end
