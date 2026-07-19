require "test_helper"

# These mirror the Deno suite (pipeline/tests/progress_test.ts): the pipeline
# applies every op to its local copy with the same rules, so any divergence
# here means the two copies of the data blob drift apart.
class ProgressPatchTest < ActiveSupport::TestCase
  test "set builds nested containers on demand" do
    data = {}
    ProgressPatch.apply(data, { "op" => "set", "path" => "translations.he.phrases.1.text", "value" => "שלום" })

    assert_equal "שלום", data.dig("translations", "he", "phrases", 1, "text")
    # Index 0 was auto-created as an empty slot.
    assert_equal 2, data.dig("translations", "he", "phrases").length
    assert_nil data.dig("translations", "he", "phrases", 0)
  end

  test "set overwrites existing values" do
    data = { "lessons" => "old" }
    ProgressPatch.apply(data, { "op" => "set", "path" => "lessons", "value" => "new" })

    assert_equal "new", data["lessons"]
  end

  test "append creates the array and pushes in order" do
    data = {}
    ProgressPatch.apply(data, { "op" => "append", "path" => "errors", "value" => { "step" => "x" } })
    ProgressPatch.apply(data, { "op" => "append", "path" => "errors", "value" => { "step" => "y" } })

    assert_equal %w[x y], data["errors"].map { |e| e["step"] }
  end

  test "append onto a non-array is rejected" do
    data = { "lessons" => "text" }

    assert_raises(ProgressPatch::InvalidOp) do
      ProgressPatch.apply(data, { "op" => "append", "path" => "lessons", "value" => 1 })
    end
  end

  test "clear_errors removes only failures for the recovered step" do
    data = {
      "errors" => [
        { "step" => "translate", "error_message" => "old" },
        { "step" => "rate_lessons", "error_message" => "current" },
        { "step" => "translate", "error_message" => "also old" }
      ]
    }

    ProgressPatch.apply(data, { "op" => "clear_errors", "path" => "errors", "value" => "translate" })

    assert_equal [ "rate_lessons" ], data["errors"].map { |error| error["step"] }
  end

  test "invalid paths and ops are rejected" do
    assert_raises(ProgressPatch::InvalidOp) do
      ProgressPatch.apply({}, { "op" => "set", "path" => "a..b", "value" => 1 })
    end
    assert_raises(ProgressPatch::InvalidOp) do
      ProgressPatch.apply({}, { "op" => "set", "path" => "", "value" => 1 })
    end
    assert_raises(ProgressPatch::InvalidOp) do
      ProgressPatch.apply({}, { "op" => "delete", "path" => "a", "value" => 1 })
    end
    assert_raises(ProgressPatch::InvalidOp) do
      ProgressPatch.apply({}, "not an op")
    end
  end

  test "non-numeric segment against an array is rejected" do
    data = { "phrases" => [] }

    assert_raises(ProgressPatch::InvalidOp) do
      ProgressPatch.apply(data, { "op" => "set", "path" => "phrases.first.text", "value" => "x" })
    end
  end

  test "descending into a scalar is rejected" do
    data = { "lessons" => "text" }

    assert_raises(ProgressPatch::InvalidOp) do
      ProgressPatch.apply(data, { "op" => "set", "path" => "lessons.deep", "value" => "x" })
    end
  end

  test "apply_all applies ops in order and returns the data" do
    data = {}
    result = ProgressPatch.apply_all(data, [
      { "op" => "set", "path" => "video_length_seconds", "value" => 225 },
      { "op" => "set", "path" => "extract_lyrics_in_progress", "value" => false }
    ])

    assert_same data, result
    assert_equal 225, data["video_length_seconds"]
    assert_equal false, data["extract_lyrics_in_progress"]
  end
end
