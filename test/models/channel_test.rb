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
end
