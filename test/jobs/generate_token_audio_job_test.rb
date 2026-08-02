require "test_helper"

class GenerateTokenAudioJobTest < ActiveJob::TestCase
  test "enqueueing waits for the surrounding transaction to commit" do
    assert GenerateTokenAudioJob.enqueue_after_transaction_commit
  end
end
