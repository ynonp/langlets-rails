# frozen_string_literal: true

Rails.application.configure do
  # Cron entries run inside the `good_job start` process (the kamal `job`
  # container in production).
  config.good_job.enable_cron = true
  config.good_job.cron = {
    cleanup_stale_oauth_registrations: {
      cron: "0 4 * * *",
      class: "CleanupStaleOauthRegistrationsJob",
      description: "Delete dynamically registered OAuth clients that never obtained a token"
    }
  }
end
