require "test_helper"

class ChannelContentQueryTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "query-owner@example.com", password: "password123", confirmed_at: Time.zone.now)
    @viewer = User.create!(email: "query-viewer@example.com", password: "password123", confirmed_at: Time.zone.now)
    language = languages(:spanish)
    @course = Course.create!(
      user: @owner, language: language, name: "Visible course", slug: "visible-channel-course",
      main_media_url: "https://youtu.be/channelquery", youtube_video_id: "channelquery", status: :published
    )
    @item = publish_covering_the_credit(@owner.default_channel, @course)
  end

  test "private items are owner-only" do
    assert_includes query(@owner), @item
    refute_includes query(@viewer), @item
  end

  test "public courses are readable but absent from listed items" do
    admin = User.create!(email: "ynon@hey.com", password: "password123", confirmed_at: Time.zone.now)
    @owner.default_channel.change_visibility!(:public, actor: admin)

    assert_includes ChannelContentQuery.courses_visible_to(@viewer), @course
    refute_includes query(@viewer), @item
    refute_includes query(@owner), @item
  end

  test "system items are listed for guests and every signed-in user" do
    admin = User.create!(email: "ynon@hey.com", password: "password123", confirmed_at: Time.zone.now)
    system_item = publish_covering_the_credit(Channel.system, @course)

    assert_includes query(nil), system_item
    assert_includes query(@viewer), system_item
    assert_includes ChannelContentQuery.courses_listed_to(nil), @course
    assert_equal admin, system_item.channel.user
  end

  test "subscribed shared items are listed" do
    admin = User.create!(email: "ynon@hey.com", password: "password123", confirmed_at: Time.zone.now)

    @owner.default_channel.change_visibility!(:shared, actor: admin)
    @owner.default_channel.channel_subscriptions.create!(user: @viewer)
    assert_includes query(@viewer), @item
  end

  private

  def query(user)
    ChannelContentQuery.new(user: user).items.to_a
  end
end
