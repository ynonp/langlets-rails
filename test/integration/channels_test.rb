require "test_helper"

class ChannelsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(email: "flow-owner@example.com", password: "password123", confirmed_at: Time.zone.now)
    @invitee = User.create!(email: "flow-invitee@example.com", password: "password123", confirmed_at: Time.zone.now)
    @stranger = User.create!(email: "flow-stranger@example.com", password: "password123", confirmed_at: Time.zone.now)
    @channel = @owner.default_channel
  end

  test "the channel profile route does not exist" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/channels/#{@channel.slug}", method: :get)
    end
  end

  test "pending invitee accepts from the token page and returns home" do
    @channel.change_visibility!(:shared, actor: @owner)
    course = Course.create!(
      user: @owner, name: "A newly shared video", slug: "newly-shared-video",
      main_media_url: "https://www.youtube.com/watch?v=newlyshared", status: :published
    )
    publish_covering_the_credit(@channel, course)
    invitation = @channel.channel_invitations.create!(
      inviter: @owner, invitee: @invitee, email: @invitee.email,
      token_digest: ChannelInvitation.digest("flow-token"), expires_at: 1.day.from_now
    )
    sign_in @invitee

    get channel_invitation_token_path("flow-token")
    assert_response :success
    assert_select "h1", text: @channel.name
    assert_select "form[action=?]", accept_channel_invitation_token_path("flow-token")

    post accept_channel_invitation_token_path("flow-token")
    assert_redirected_to root_path
    assert @channel.channel_subscriptions.exists?(user: @invitee)

    follow_redirect!
    assert_response :success

    get gallery_path
    assert_select ".gallery-card", text: /#{Regexp.escape(course.name)}/
  end

  test "signed-out invitation links preserve a return location through authentication" do
    @channel.change_visibility!(:shared, actor: @owner)
    @channel.channel_invitations.create!(
      inviter: @owner, invitee: @invitee, email: @invitee.email,
      token_digest: ChannelInvitation.digest("return-token"), expires_at: 1.day.from_now
    )

    get channel_invitation_token_path("return-token")

    assert_redirected_to new_user_session_path
    assert_equal channel_invitation_token_path("return-token"), session["user_return_to"]
  end
end
