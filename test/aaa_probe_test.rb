require "test_helper"

module App
  class ProbeNestedTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    test "probe" do
      u = User.create!(email: "probe1@example.com", password: "password123", confirmed_at: Time.zone.now)
      info = +""
      info << "mappings=#{Devise.mappings.keys.inspect} "
      info << "same_object=#{Devise.mappings[:user]&.to.equal?(User)} "
      info << "mapping_to_id=#{Devise.mappings[:user]&.to&.object_id} user_id=#{User.object_id} "
      info << "is_a=#{begin; u.is_a?(Devise.mappings[:user].to); rescue StandardError; 'ERR'; end}"
      File.write("/tmp/probe.out", info)
    end
  end
end
