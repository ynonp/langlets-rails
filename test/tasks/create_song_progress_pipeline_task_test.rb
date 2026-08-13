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
    pipeline_arguments = nil
    imported = nil

    CreateSongProgressTasks.stub(:with_local_pipeline_servers, ->(&block) { block.call }) do
      CreateSongProgress.stub(:run_pipeline, ->(**kwargs) { pipeline_arguments = kwargs; progress }) do
        ImportCourseJob.stub(:perform_now, ->(progress_id, user_id, language_id) { imported = [ progress_id, user_id, language_id ] }) do
          @task.invoke("https://www.youtube.com/watch?v=XXXX", "French", "Hebrew", @creator.email)
        end
      end
    end

    assert_equal "https://www.youtube.com/watch?v=XXXX", pipeline_arguments.fetch(:youtube_url)
    assert_equal "French", pipeline_arguments.fetch(:clip_language)
    assert_equal "Hebrew", pipeline_arguments.fetch(:translation_language)
    assert pipeline_arguments.fetch(:wait)
    assert_equal [ progress.id, @creator.id, languages(:hebrew).id ], imported
  end

  test "does not create a course when the Deno pipeline fails" do
    CreateSongProgressTasks.stub(:with_local_pipeline_servers, ->(&block) { block.call }) do
      CreateSongProgress.stub(:run_pipeline, ->(**) { raise "pipeline failed" }) do
        ImportCourseJob.stub(:perform_now, ->(*) { flunk "course creation should not run" }) do
          assert_raises(RuntimeError, "pipeline failed") do
            @task.invoke("https://www.youtube.com/watch?v=XXXX", "French", "Hebrew", @creator.email)
          end
        end
      end
    end
  end

  test "starts Rails and the pipeline on separate local ports" do
    old_secret = ENV["PIPELINE_HMAC_SECRET"]
    old_pipeline_url = Rails.configuration.x.pipeline.url
    old_callback_url = Rails.configuration.x.pipeline.callback_base_url
    ENV["PIPELINE_HMAC_SECRET"] = "local-secret"
    ports = [ 41_001, 41_002 ]
    commands = []
    waited = []
    stopped = []

    CreateSongProgressTasks.stub(:free_port, -> { ports.shift }) do
      CreateSongProgressTasks.stub(:spawn_process, ->(environment, command, directory) {
        commands << [ environment, command, directory ]
        commands.length
      }) do
        CreateSongProgressTasks.stub(:wait_for_port, ->(port, name) { waited << [ port, name ] }) do
          CreateSongProgressTasks.stub(:stop_process, ->(pid) { stopped << pid }) do
            CreateSongProgressTasks.with_local_pipeline_servers do
              assert_equal "http://127.0.0.1:41001", Rails.configuration.x.pipeline.url
              assert_equal "http://127.0.0.1:41002", Rails.configuration.x.pipeline.callback_base_url
            end
          end
        end
      end
    end

    pipeline_environment, pipeline_command = commands.first
    rails_environment, rails_command = commands.second
    assert_equal "41001", pipeline_environment.fetch("PORT")
    assert_equal [ "deno", "task", "serve" ], pipeline_command
    assert_equal "http://127.0.0.1:41001", rails_environment.fetch("PIPELINE_URL")
    assert_includes rails_command, "41002"
    assert_equal [ [ 41_001, "pipeline" ], [ 41_002, "Rails" ] ], waited
    assert_equal [ 2, 1 ], stopped
    assert_equal old_pipeline_url, Rails.configuration.x.pipeline.url
    assert_equal old_callback_url, Rails.configuration.x.pipeline.callback_base_url
  ensure
    ENV["PIPELINE_HMAC_SECRET"] = old_secret
  end
end
