require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get activities_index_url
    assert_response :success
  end

  test "should get show" do
    get activities_show_url
    assert_response :success
  end
end
