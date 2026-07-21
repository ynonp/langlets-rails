class AddPipelineStepToImportRequests < ActiveRecord::Migration[8.0]
  # The Queue card names the stage the pipeline is on ("Transcribing · step 1 of
  # 6") rather than showing a bare percentage, because the user paid a credit for
  # this run and a spinner tells them nothing about what they bought.
  #
  # Denormalised onto the request for the same reason progress_percent already
  # is: the stage is derived from create_song_progresses.data, that column is a
  # multi-megabyte jsonb blob, and the Queue polls it every 3 seconds. Computing
  # it per card would load one blob per row on every poll. The after_save that
  # syncs the percent has `data` in memory already, so writing this at the same
  # time is free.
  def change
    add_column :import_requests, :pipeline_step, :string
  end
end
