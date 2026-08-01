require "test_helper"

class ChannelTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "channel-owner@example.com", password: "password123", confirmed_at: Time.zone.now)
    @member = User.create!(email: "channel-member@example.com", password: "password123", confirmed_at: Time.zone.now)
    @admin = User.create!(email: "ynon@hey.com", password: "password123", confirmed_at: Time.zone.now)
    @channel = @owner.default_channel
  end

  test "new users receive one private default channel" do
    assert @channel.visibility_private?
    assert @channel.default?
    assert_equal 1, @owner.channels.where(default: true).count
    assert_equal @channel, @owner.provision_default_channel!
  end

  # Publishing is the sale. Everything about import pricing follows from these
  # four tests: the charge lives here, so no import path can price itself.
  test "publishing into an ordinary channel costs the owner one credit" do
    course = publishable_course

    @channel.publish!(course)

    assert_equal User::SIGNUP_CREDITS - 1, @owner.reload.credit_balance
    assert_equal 1, @owner.credit_ledger_entries.import_spend.count
    assert_equal course, @owner.credit_ledger_entries.import_spend.sole.subject
  end

  test "publishing the same course again is free" do
    course = publishable_course

    3.times { @channel.publish!(course) }

    assert_equal User::SIGNUP_CREDITS - 1, @owner.reload.credit_balance
    assert_equal 1, @channel.channel_items.where(course: course).count
  end

  # The key is the (channel, course) pair rather than the import that asked, so
  # a course removed and imported again is not a second sale.
  test "republishing after an unpublish does not charge twice" do
    course = publishable_course
    @channel.publish!(course)
    @channel.unpublish!(course)

    @channel.publish!(course)

    assert_equal User::SIGNUP_CREDITS - 1, @owner.reload.credit_balance
  end

  test "an owner who cannot pay does not get the publication" do
    course = publishable_course
    User.where(id: @owner.id).update_all(credit_balance: 0)

    assert_raises(Credits::InsufficientCredits) { @channel.publish!(course) }

    assert_not @channel.channel_items.exists?(course: course), "rolled back with the charge"
  end

  # The whole of Langlets Pro, as far as billing is concerned.
  test "publishing into a Pro library is free" do
    course = publishable_course
    pro_channel = ProChannel.create!(user: @owner, name: ProChannel::NAME,
                                     slug: "pro-#{@owner.id}", visibility: :private)
    User.where(id: @owner.id).update_all(credit_balance: 0)

    pro_channel.publish!(course)

    assert pro_channel.channel_items.exists?(course: course)
    assert_equal 0, @owner.reload.credit_balance
    assert_equal 0, @owner.credit_ledger_entries.import_spend.count
  end

  test "unpublish! removes the channel item and is safe to call again" do
    course = Course.create!(
      user: @owner,
      name: "Unpublishable course",
      slug: "unpublishable-course-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=unpub123",
      youtube_video_id: "unpub123",
      status: :published
    )
    @channel.publish!(course)
    assert @channel.channel_items.exists?(course: course)

    @channel.unpublish!(course)

    assert_not @channel.channel_items.exists?(course: course)
    assert_nothing_raised { @channel.unpublish!(course) }
  end

  test "regular owners can switch private and shared but not public" do
    @channel.change_visibility!(:shared, actor: @owner)
    assert @channel.visibility_shared?

    assert_raises(Channel::UnauthorizedTransition) do
      @channel.change_visibility!(:public, actor: @owner)
    end
  end

  test "admin can make a channel public" do
    @channel.change_visibility!(:public, actor: @admin)
    assert @channel.visibility_public?
  end

  test "moving shared to private revokes invitations and subscriptions" do
    @channel.change_visibility!(:shared, actor: @owner)
    invitation = @channel.channel_invitations.create!(
      inviter: @owner, invitee: @member, email: @member.email,
      token_digest: ChannelInvitation.digest("token"), expires_at: 1.day.from_now
    )
    @channel.channel_subscriptions.create!(user: @member)

    @channel.change_visibility!(:private, actor: @owner)

    assert invitation.reload.revoked?
    assert_empty @channel.channel_subscriptions.reload
  end

  test "invitation acceptance is email-bound atomic and replay safe" do
    @channel.change_visibility!(:shared, actor: @owner)
    invitation = @channel.channel_invitations.create!(
      inviter: @owner, invitee: @member, email: @member.email,
      token_digest: ChannelInvitation.digest("single-use"), expires_at: 1.day.from_now
    )

    invitation.accept!(@member)
    invitation.accept!(@member)

    assert invitation.reload.accepted?
    assert_equal 1, @channel.channel_subscriptions.where(user: @member).count
  end

  test "expired invitation cannot be accepted and records expiry" do
    @channel.change_visibility!(:shared, actor: @owner)
    invitation = @channel.channel_invitations.create!(
      inviter: @owner, invitee: @member, email: @member.email,
      token_digest: ChannelInvitation.digest("expired"), expires_at: 1.minute.ago
    )

    assert_raises(ActiveRecord::RecordNotFound) { invitation.accept!(@member) }
    assert invitation.reload.expired?
  end

  private

  def publishable_course
    Course.create!(
      user: @owner,
      name: "Publishable course",
      slug: "publishable-course-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=pub#{SecureRandom.hex(4)}",
      youtube_video_id: "pub#{SecureRandom.hex(4)}",
      status: :published
    )
  end
end
