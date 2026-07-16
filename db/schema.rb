# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_07_16_230000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.bigint "lesson_id", null: false
    t.integer "order"
    t.string "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "text_header"
    t.string "text_subheader"
    t.bigint "user_id", null: false
    t.index ["lesson_id"], name: "index_activities_on_lesson_id"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "activity_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "active_time"
    t.integer "xp_gained"
    t.bigint "lesson_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id"], name: "index_activity_logs_on_lesson_id"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "activity_phrases", force: :cascade do |t|
    t.bigint "activity_id", null: false
    t.bigint "phrase_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_id"], name: "index_activity_phrases_on_activity_id"
    t.index ["phrase_id"], name: "index_activity_phrases_on_phrase_id"
  end

  create_table "activity_token_translations", force: :cascade do |t|
    t.bigint "activity_id", null: false
    t.bigint "token_translation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_id", "token_translation_id"], name: "idx_on_activity_id_token_translation_id_86aadb2c62"
    t.index ["activity_id"], name: "index_activity_token_translations_on_activity_id"
    t.index ["token_translation_id"], name: "index_activity_token_translations_on_token_translation_id"
  end

  create_table "activity_users", force: :cascade do |t|
    t.bigint "activity_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_id", "user_id"], name: "index_activity_users_on_activity_id_and_user_id", unique: true
    t.index ["activity_id"], name: "index_activity_users_on_activity_id"
    t.index ["user_id"], name: "index_activity_users_on_user_id"
  end

  create_table "course_tags", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "tag_id"], name: "index_course_tags_on_course_id_and_tag_id", unique: true
    t.index ["course_id"], name: "index_course_tags_on_course_id"
    t.index ["tag_id"], name: "index_course_tags_on_tag_id"
  end

  create_table "courses", force: :cascade do |t|
    t.string "name"
    t.string "slug", null: false
    t.string "main_media_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "language_id"
    t.bigint "user_id", null: false
    t.integer "status", default: 0, null: false
    t.boolean "show_full_course_player", default: true, null: false
    t.bigint "create_song_progress_id"
    t.index ["create_song_progress_id"], name: "index_courses_on_create_song_progress_id"
    t.index ["language_id"], name: "index_courses_on_language_id"
    t.index ["name"], name: "index_courses_on_name", unique: true
    t.index ["slug"], name: "index_courses_on_slug", unique: true
    t.index ["user_id"], name: "index_courses_on_user_id"
  end

  create_table "courses_learning_paths", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "learning_path_id", null: false
    t.integer "order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_courses_learning_paths_on_course_id"
    t.index ["learning_path_id"], name: "index_courses_learning_paths_on_learning_path_id"
  end

  create_table "create_song_progresses", force: :cascade do |t|
    t.string "youtubeurl", null: false
    t.string "clip_language", null: false
    t.string "translation_language", null: false
    t.integer "step"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "lyrics"
    t.index ["youtubeurl", "clip_language", "translation_language"], name: "idx_on_youtubeurl_clip_language_translation_languag_d876aa04dc", unique: true
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at", where: "((retried_good_job_id IS NULL) AND (finished_at IS NOT NULL))"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "languages", force: :cascade do |t|
    t.string "iso_name"
    t.string "english_name"
    t.string "native_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pronunciation_variant_name"
    t.boolean "rtl", default: false
    t.index ["iso_name"], name: "index_languages_on_iso_name", unique: true
  end

  create_table "learning_paths", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "difficulty_level"
    t.boolean "published"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "subtitle"
    t.string "hero_image_url"
    t.string "cta_text"
    t.string "cta_link"
    t.string "primary_color"
    t.string "layout_style", default: "default"
    t.string "slug"
  end

  create_table "lesson_users", force: :cascade do |t|
    t.bigint "lesson_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id", "user_id"], name: "index_lesson_users_on_lesson_id_and_user_id", unique: true
    t.index ["lesson_id"], name: "index_lesson_users_on_lesson_id"
    t.index ["user_id"], name: "index_lesson_users_on_user_id"
  end

  create_table "lessons", force: :cascade do |t|
    t.string "slug"
    t.bigint "medium_id"
    t.string "start_timestamp"
    t.string "end_timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "course_id"
    t.integer "order", default: 0
    t.string "name"
    t.bigint "user_id", null: false
    t.index ["course_id", "slug"], name: "index_lessons_on_course_id_and_slug", unique: true, where: "(course_id IS NOT NULL)"
    t.index ["course_id"], name: "index_lessons_on_course_id"
    t.index ["medium_id"], name: "index_lessons_on_medium_id"
    t.index ["user_id"], name: "index_lessons_on_user_id"
  end

  create_table "media", force: :cascade do |t|
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "language_id"
    t.bigint "translation_language_id"
    t.index ["language_id"], name: "index_media_on_language_id"
    t.index ["translation_language_id"], name: "index_media_on_translation_language_id"
    t.index ["url", "language_id", "translation_language_id"], name: "index_media_on_url_and_language_pair", unique: true
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "code_challenge"
    t.string "code_challenge_method"
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.string "scopes"
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "previous_refresh_token", default: "", null: false
    t.datetime "last_used_at"
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "dynamically_registered", default: false, null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "phrases", force: :cascade do |t|
    t.bigint "medium_id", null: false
    t.bigint "l1_id", null: false
    t.bigint "l2_id", null: false
    t.string "timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "text_l1"
    t.string "text_l2"
    t.index ["l1_id"], name: "index_phrases_on_l1_id"
    t.index ["l2_id"], name: "index_phrases_on_l2_id"
    t.index ["medium_id"], name: "index_phrases_on_medium_id"
  end

  create_table "similar_sounds", force: :cascade do |t|
    t.integer "start_word_index", null: false
    t.integer "end_word_index", null: false
    t.string "replacement_text", null: false
    t.bigint "phrase_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["phrase_id"], name: "index_similar_sounds_on_phrase_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "token_translation_users", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "token_translation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_translation_id"], name: "index_token_translation_users_on_token_translation_id"
    t.index ["user_id", "token_translation_id"], name: "idx_token_translation_users_unique", unique: true
    t.index ["user_id"], name: "index_token_translation_users_on_user_id"
  end

  create_table "token_translations", force: :cascade do |t|
    t.bigint "phrase_id", null: false
    t.integer "l1_start_index"
    t.integer "l1_end_index"
    t.string "translation"
    t.string "questions", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "l2_start_index"
    t.integer "l2_end_index"
    t.string "similar_sound", array: true
    t.integer "index_type", default: 0, null: false
    t.string "start_timestamp"
    t.string "end_timestamp"
    t.index ["index_type"], name: "index_token_translations_on_index_type"
    t.index ["phrase_id", "l1_start_index", "l1_end_index", "index_type"], name: "idx_token_translations_unique", unique: true
    t.index ["phrase_id"], name: "index_token_translations_on_phrase_id"
  end

  create_table "user_game_stats", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "total_xp", default: 0
    t.integer "current_streak", default: 0
    t.date "last_activity_date"
    t.integer "daily_xp", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_game_stats_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.bigint "preferred_language_id"
    t.jsonb "preferences", default: {}, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["preferred_language_id"], name: "index_users_on_preferred_language_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "lessons"
  add_foreign_key "activities", "users"
  add_foreign_key "activity_logs", "lessons"
  add_foreign_key "activity_logs", "users"
  add_foreign_key "activity_phrases", "activities"
  add_foreign_key "activity_phrases", "phrases"
  add_foreign_key "activity_token_translations", "activities"
  add_foreign_key "activity_token_translations", "token_translations"
  add_foreign_key "activity_users", "activities"
  add_foreign_key "activity_users", "users"
  add_foreign_key "course_tags", "courses"
  add_foreign_key "course_tags", "tags"
  add_foreign_key "courses", "languages"
  add_foreign_key "courses", "users"
  add_foreign_key "courses_learning_paths", "courses"
  add_foreign_key "courses_learning_paths", "learning_paths"
  add_foreign_key "lesson_users", "lessons"
  add_foreign_key "lesson_users", "users"
  add_foreign_key "lessons", "courses", on_delete: :cascade
  add_foreign_key "lessons", "media"
  add_foreign_key "lessons", "users"
  add_foreign_key "media", "languages", column: "translation_language_id"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "phrases", "languages", column: "l1_id"
  add_foreign_key "phrases", "languages", column: "l2_id"
  add_foreign_key "phrases", "media"
  add_foreign_key "similar_sounds", "phrases"
  add_foreign_key "token_translation_users", "token_translations"
  add_foreign_key "token_translation_users", "users"
  add_foreign_key "token_translations", "phrases"
  add_foreign_key "user_game_stats", "users"
  add_foreign_key "users", "languages", column: "preferred_language_id"
end
