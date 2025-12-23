require "test_helper"

class FullPlayerControllerTest < ActionDispatch::IntegrationTest
  test "should route to full player page" do
    assert_routing(
      { path: "/courses/test-course/full-player", method: :get },
      { controller: "full_player", action: "show", course_slug: "test-course" }
    )
  end
end
