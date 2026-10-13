require "test_helper"
require "timeout"

class CustomVocabularyConcurrencyTest < ActiveSupport::TestCase
  # Each submission needs its own connection and must see committed records.
  self.use_transactional_tests = false

  test "simultaneous custom saves create one phrase token and saved entry" do
    user = User.create!(email: "concurrent-custom@example.com", password: "password123", confirmed_at: Time.zone.now)
    ready = Queue.new
    start = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          owner = User.find(user.id)
          ready << true
          start.pop
          PhraseTokenUser.create_custom!(
            user: owner, sentence: "no queda tiempo", language: languages(:spanish),
            token_range: 2..2, translation: "time", translation_language: languages(:english)
          ).id
        end
      end
    end

    ids = Timeout.timeout(15) do
      2.times { ready.pop }
      2.times { start << true }
      threads.map(&:value)
    end

    assert_equal 1, ids.uniq.size
    assert_equal 1, user.custom_phrases.count
    assert_equal 1, user.custom_phrases.first.phrase_tokens.count
    assert_equal 1, user.phrase_token_users.count
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    threads&.each(&:join)
    user&.destroy!
  end
end
