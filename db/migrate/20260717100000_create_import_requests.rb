class CreateImportRequests < ActiveRecord::Migration[8.0]
  # One user's intent to import one video. This is a third thing, distinct from
  # the two that already exist, and it has to be:
  #
  #   CreateSongProgress is the *shared pipeline cache* — keyed globally on
  #   (youtubeurl, clip_language, translation_language) with no user_id, so two
  #   users importing the same video deliberately share one row and the AI work
  #   happens once. That's exactly why it can't hold per-user queue state.
  #
  #   Course is the *shared output* — under dedupe there's at most one published
  #   course per video per language pair, and courses.user_id is just whoever got
  #   there first. A second user's queue item has no course of its own to hang on.
  #
  #   ImportRequest is the *per-user intent*: status, credit linkage, retry,
  #   failure reason, push idempotency.
  #
  # So: one CreateSongProgress -> many ImportRequests -> one Course.
  def change
    create_table :import_requests do |t|
      t.references :user, null: false, foreign_key: true

      # Canonical form (Youtube::Url.canonical) so this lines up with
      # create_song_progresses.youtubeurl and courses.main_media_url.
      t.string :youtube_url, null: false
      t.string :youtube_video_id, null: false

      # english_name strings, matching CreateSongProgress's columns rather than
      # language ids, so the two can be compared without a join.
      t.string :clip_language, null: false
      t.string :translation_language, null: false

      # Snapshot of the oEmbed title at submit time, so the Queue can show
      # something before the pipeline has produced a course.
      t.string :title

      t.integer :status, null: false, default: 0

      t.references :course, foreign_key: true
      t.references :create_song_progress, foreign_key: true

      # Written forward by CreateSongProgress#sync_import_requests_progress.
      # Never computed on read: `data` is a multi-megabyte jsonb blob and the
      # Queue polls this every few seconds.
      t.integer :progress_percent, null: false, default: 0

      t.string :failure_reason

      t.boolean :charged,  null: false, default: false
      t.boolean :refunded, null: false, default: false

      # Set once the "your course is ready" push goes out, so a retried job can't
      # notify twice.
      t.datetime :notified_at

      # Client-supplied idempotency for the app and the share extension.
      t.string :client_token

      t.timestamps
    end

    add_index :import_requests, [ :user_id, :status ]
    add_index :import_requests, [ :user_id, :created_at ]
    add_index :import_requests, :client_token, unique: true

    # One *active* request per user per video per pair. Partial so that a failed
    # import can be retried, and so finished ones don't block a re-import.
    # Makes a double-tapped Import button a database impossibility rather than a
    # race we hope to lose gracefully. Values are ImportRequest.statuses:
    # queued = 0, importing = 1.
    add_index :import_requests,
              [ :user_id, :youtube_video_id, :clip_language, :translation_language ],
              unique: true,
              where: "status IN (0, 1)",
              name: "idx_import_requests_active_dedupe"
  end
end
