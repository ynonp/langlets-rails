require "test_helper"

# The Pro library: what a subscription actually buys, and what cancelling it
# actually takes away.
#
# A subscriber's imports are published to a ProChannel they own. Ownership alone
# does not grant access — ProChannel.owned_grant contributes rows to
# Channel.visible_to only while the subscription is live — so cancelling makes
# the library go dark and resubscribing brings it back whole, with nothing moved
# or deleted either way.
#
# Saved vocabulary is outside all of it by design: the words belong to the
# learner, not to the channel they were met in.
class ProLibraryTest < ActiveSupport::TestCase
  ORIGINAL = "2000000555555555".freeze

  setup do
    @user = User.create!(email: "subscriber@example.com", password: "password123", confirmed_at: Time.zone.now)
    @stranger = User.create!(email: "stranger@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
  end

  test "a new account still starts with three free credits and no Pro library" do
    assert_equal User::SIGNUP_CREDITS, @user.credit_balance
    assert_not @user.pro?
    assert_nil @user.pro_channel
  end

  test "the Pro library is the subscriber's own private channel" do
    go_pro!
    settle_import!

    channel = @user.reload.pro_channel
    assert_kind_of ProChannel, channel
    assert_equal @user, channel.user
    assert channel.visibility_private?
    assert_not channel.default?
  end

  # Subscribing alone creates nothing; the first import does. An account that
  # subscribes and never imports carries no empty channel.
  test "the Pro library is provisioned lazily, on the first import" do
    go_pro!

    assert_nil @user.pro_channel
    settle_import!
    assert @user.reload.pro_channel
  end

  test "a Pro import is published to the Pro library, not the default channel" do
    go_pro!
    course = settle_import!

    assert @user.reload.pro_channel.channel_items.exists?(course: course)
    assert_not @user.default_channel.channel_items.exists?(course: course)
    assert course.readable_by?(@user)
  end

  test "a free import stays in the default channel and survives everything" do
    course = settle_import!

    assert @user.default_channel.channel_items.exists?(course: course)
    go_pro!
    cancel!
    assert course.reload.readable_by?(@user.reload), "content bought with credits is kept, not rented"
  end

  # The property the whole design exists for: owning the channel is not enough.
  test "cancelling withdraws the library without deleting it" do
    go_pro!
    course = settle_import!

    cancel!

    assert_not @user.reload.pro?
    assert_not course.readable_by?(@user)
    assert_equal 0, ChannelContentQuery.courses_visible_to(@user).where(id: course.id).count
    assert @user.pro_channel.channel_items.exists?(course: course),
           "the library is paused, not emptied — reactivating has to restore it whole"
  end

  test "resubscribing restores the whole library at once" do
    go_pro!
    course = settle_import!
    cancel!

    go_pro!(original_transaction_id: "2000000555555556")

    assert @user.reload.pro?
    assert course.readable_by?(@user)
    assert_equal 1, ChannelContentQuery.courses_visible_to(@user).where(id: course.id).count
  end

  # Entitlement is derived from expires_at, so a dropped App Store notification
  # costs accuracy in `status` and nothing else. This is what buying the derived
  # design over a mirrored ChannelSubscription actually bought.
  test "a lapsed subscription withdraws the library with no notification and no job" do
    go_pro!
    course = settle_import!

    Subscription.sole.update_columns(expires_at: 1.minute.ago)

    assert_not @user.reload.pro?
    assert_not course.readable_by?(@user)
    assert Subscription.sole.status_active?, "status is still stale — and it does not matter"
  end

  test "the expiry sweep only tidies status" do
    go_pro!
    Subscription.sole.update_columns(expires_at: 1.minute.ago)

    ExpireSubscriptionsJob.perform_now

    assert Subscription.sole.status_expired?
  end

  # Pasting a link to your own paused course is the likeliest way to meet the
  # revoked state, and until Imports::Paused existed it produced "already in your
  # library" plus an Open button that 404s: Preview and Create both asked "is it
  # published?", which was the same question as "can you read it?" only while a
  # library was permanent.
  test "re-importing your own paused course offers the subscription, not a 404" do
    go_pro!
    course = settle_import!
    cancel!

    stub_video do
      preview = Imports::Preview.call(user: @user, url: course.main_media_url,
                                      clip_language: "Spanish", translation_language: "English")
      assert preview.paused?
      assert_not preview.in_library?, "must not claim they can open it"

      enrollments = @user.enrollments.count
      requests = @user.import_requests.count

      result = Imports::Create.call(user: @user, url: course.main_media_url,
                                    clip_language: "Spanish", translation_language: "English")

      assert result.paused?
      assert_equal course, result.course
      assert_nil result.import_request
      assert_equal User::SIGNUP_CREDITS, @user.reload.credit_balance, "nothing charged"
      assert_equal requests, @user.import_requests.count, "no new request to poll"
      assert_equal enrollments, @user.enrollments.count, "no second enrollment for a course they still cannot open"
    end
  end

  # The enrollment from the original import is deliberately left alone by all of
  # this: it is what puts the course back on Home the moment they resubscribe.
  # Home and started_courses re-check readability on every render, which is what
  # keeps it off the screen meanwhile.
  test "the original enrollment survives a lapse and is not rendered while paused" do
    go_pro!
    course = settle_import!
    cancel!

    assert @user.enrollments.exists?(course: course)
    assert_not course.readable_by?(@user)

    go_pro!(original_transaction_id: "2000000555555557")
    assert course.readable_by?(@user.reload)
  end

  test "re-importing your own live Pro course is still an ordinary duplicate" do
    go_pro!
    course = settle_import!

    stub_video do
      preview = Imports::Preview.call(user: @user, url: course.main_media_url,
                                      clip_language: "Spanish", translation_language: "English")
      assert preview.in_library?
      assert_not preview.paused?
    end
  end

  # Narrowly scoped on purpose: a course somebody else keeps private is a
  # separate, pre-existing case and must not be relabelled as a Pro pause.
  test "another user's unreadable course is not reported as paused" do
    course = settle_import!(user: @stranger)
    go_pro!

    assert_not course.readable_by?(@user.reload)
    assert_not Imports::Paused.for?(user: @user, course: course)
  end

  test "saved vocabulary survives cancellation" do
    go_pro!
    course = settle_import!
    token = save_a_word!(course)

    cancel!

    assert_not course.readable_by?(@user.reload)
    assert @user.saved_phrase_tokens.exists?(id: token.id), "the words are the learner's, by design"
  end

  test "nobody else can read a Pro library, subscribed or not" do
    go_pro!
    course = settle_import!
    channel = @user.reload.pro_channel

    assert_not channel.readable_by?(@stranger)
    assert_not channel.discoverable_by?(@stranger)
    assert_not course.readable_by?(@stranger)
    assert_equal 0, ChannelContentQuery.courses_visible_to(@stranger).where(id: course.id).count
  end

  test "a Pro library's visibility is fixed for everyone, administrator included" do
    admin = User.create!(email: User::ADMIN_EMAIL, password: "password123", confirmed_at: Time.zone.now)
    go_pro!
    settle_import!
    channel = @user.reload.pro_channel

    assert_raises(Channel::UnauthorizedTransition) { channel.change_visibility!(:public, actor: admin) }
    assert_raises(Channel::UnauthorizedTransition) { channel.change_visibility!(:shared, actor: @user) }
    assert channel.reload.visibility_private?
  end

  # `type: nil` in Ability. Owning the channel does not buy the right to rename
  # it, share it, or invite people into it.
  test "a subscriber cannot administer their own Pro library" do
    go_pro!
    settle_import!
    ability = Ability.new(@user.reload)

    assert ability.can?(:manage, @user.default_channel)
    assert_not ability.can?(:manage, @user.pro_channel)
  end

  test "the administrator's Pro library works like anyone else's" do
    admin = User.create!(email: User::ADMIN_EMAIL, password: "password123", confirmed_at: Time.zone.now)

    go_pro!(user: admin)
    course = settle_import!(user: admin)

    assert_equal admin.reload.pro_channel, admin.publishing_channel
    assert admin.pro_channel.channel_items.exists?(course: course)
  end

  test "deleting a course reaches the Pro library too" do
    go_pro!
    course = settle_import!

    assert @user.reload.owns_publication_of?(course)
    @user.pro_channel.unpublish!(course)
    assert_not @user.owns_publication_of?(course)
  end

  # Regression guard for the STI wart: Channel is a base class, so an unscoped
  # base-class query sees ProChannel rows.
  test "an ordinary Channel query does not sweep up Pro libraries" do
    go_pro!
    settle_import!

    assert_equal 1, Channel.where(type: nil, user_id: @user.id).count
    assert_equal @user.default_channel, Channel.where(type: nil, user_id: @user.id).sole
    assert_equal 2, Channel.where(user_id: @user.id).count, "the base class still sees both"
  end

  private

  def go_pro!(user: @user, original_transaction_id: ORIGINAL)
    Apple::ActivateSubscription.call(
      user: user,
      payload: {
        "transactionId" => original_transaction_id,
        "originalTransactionId" => original_transaction_id,
        "productId" => Apple::SubscriptionPlans.yearly.product_id,
        "type" => Apple::SubscriptionPlans.transaction_type,
        "purchaseDate" => (Time.zone.now.to_f * 1000).round,
        "expiresDate" => (1.year.from_now.to_f * 1000).round,
        "environment" => "Sandbox"
      }
    )
    user.reload
  end

  # What Apple sends when the user cancels and the period ends.
  def cancel!(user: @user)
    subscription = user.subscriptions.order(:id).last
    Apple::ActivateSubscription.call(
      payload: {
        "transactionId" => subscription.latest_transaction_id,
        "originalTransactionId" => subscription.original_transaction_id,
        "productId" => subscription.product_id,
        "type" => Apple::SubscriptionPlans.transaction_type,
        "purchaseDate" => (subscription.purchased_at.to_f * 1000).round,
        "expiresDate" => (1.minute.ago.to_f * 1000).round,
        "environment" => "Sandbox"
      }
    )
    user.reload
  end

  # Runs one import all the way to publication, which is the step that decides
  # which channel the course lands in.
  def settle_import!(user: @user)
    course = Course.create!(
      name: "Despacito", slug: "despacito-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk",
      youtube_video_id: "kJQP7kiw5Fk", language: @spanish,
      user: user, status: :published
    )
    course.course_translations.create!(language: languages(:english), name: "Despacito", status: :ready)

    request = user.import_requests.create!(
      youtube_url: course.main_media_url, youtube_video_id: course.youtube_video_id,
      clip_language: "Spanish", translation_language: "English",
      course: course, status: :queued
    )
    Imports::Settlement.complete!(request)
    course
  end

  def stub_video(&block)
    video = Youtube::Oembed::Video.new(
      video_id: "kJQP7kiw5Fk", title: "Despacito", author_name: "Luis Fonsi",
      thumbnail_url: "https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg",
      canonical_url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk"
    )
    Youtube::Oembed.stub(:fetch, ->(_url) { video }, &block)
  end

  def save_a_word!(course)
    medium = Medium.create!(url: course.main_media_url, language: @spanish)
    phrase = Phrase.create!(medium: medium, text_l1: "despacito", l1: @spanish)
    token = PhraseToken.create!(phrase: phrase, l1_start_index: 0, l1_end_index: 0)
    PhraseTokenUser.create!(user: @user, phrase_token: token, language: @spanish)
    token
  end
end
