require "test_helper"
require "rake"
require "minitest/mock"

class CreateSongProgressPipelineTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("create_song_progress:pipeline")
    @task = Rake::Task["create_song_progress:pipeline"]
    @task.reenable
    @creator = User.create!(
      email: "pipeline-owner@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
  end

  teardown do
    @task.reenable
  end

  test "creates the course after the Deno pipeline finishes" do
    progress = Struct.new(:id).new(123)
    pipeline = Minitest::Mock.new
    pipeline.expect(:call, progress)
    imported = nil

    CreateSongPipelineCli.stub(:new, ->(**) { pipeline }) do
      ImportCourseJob.stub(:perform_now, ->(progress_id, user_id) { imported = [ progress_id, user_id ] }) do
        @task.invoke("https://www.youtube.com/watch?v=XXXX", "French", "Hebrew", @creator.email)
      end
    end

    pipeline.verify
    assert_equal [ progress.id, @creator.id ], imported
  end

  test "does not create a course when the Deno pipeline fails" do
    pipeline = Object.new
    pipeline.define_singleton_method(:call) { raise "pipeline failed" }

    CreateSongPipelineCli.stub(:new, ->(**) { pipeline }) do
      ImportCourseJob.stub(:perform_now, ->(*) { flunk "course creation should not run" }) do
        assert_raises(RuntimeError, "pipeline failed") do
          @task.invoke("https://www.youtube.com/watch?v=XXXX", "French", "Hebrew", @creator.email)
        end
      end
    end
  end
end
