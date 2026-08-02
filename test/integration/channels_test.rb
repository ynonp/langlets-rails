require "test_helper"

class ChannelsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(email: "flow-owner@example.com", password: "password123", confirmed_at: Time.zone.now)
    @invitee = User.create!(email: "flow-invitee@example.com", password: "password123", confirmed_at: Time.zone.now)
    @stranger = User.create!(email: "flow-stranger@example.com", password: "password123", confirmed_at: Time.zone.now)
    @channel = @owner.default_channel
  end

  test "private and unauthorized shared channel URLs return not found" do
    sign_in @stranger
    get channel_path(@channel.slug)
    assert_response :not_found

    @channel.change_visibility!(:shared, actor: @owner)
    sign_in @stranger
    get channel_path(@channel.slug)
    assert_response :not_found
  end

  test "pending invitee sees identity but no content and can accept" do
    @channel.change_visibility!(:shared, actor: @owner)
    invitation = @channel.channel_invitations.create!(
      inviter: @owner, invitee: @invitee, email: @invitee.email,
      token_digest: ChannelInvitation.digest("flow-token"), expires_at: 1.day.from_now
    )
    sign_in @invitee

    get channel_path(@channel.slug)
    assert_response :success
    assert_select "h1", text: @channel.name
    assert_select "form[action=?]", accept_channel_invitation_path(invitation)

    post accept_channel_invitation_path(invitation)
    assert_redirected_to channel_path(@channel.slug)
    assert @channel.channel_subscriptions.exists?(user: @invitee)
  end

  test "signed-out channel links preserve a return location through authentication" do
    get channel_path(@channel.slug)

    assert_redirected_to new_user_session_path
    assert_equal channel_path(@channel.slug), session["user_return_to"]
  end
end
