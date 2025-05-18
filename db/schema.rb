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

ActiveRecord::Schema[8.0].define(version: 2025_05_18_092246) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activities", force: :cascade do |t|
    t.bigint "lesson_id", null: false
    t.integer "order"
    t.string "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "text_header"
    t.string "text_subheader"
    t.index ["lesson_id"], name: "index_activities_on_lesson_id"
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

  create_table "course_lessons", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "lesson_id", null: false
    t.integer "order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["course_id"], name: "index_course_lessons_on_course_id"
    t.index ["lesson_id"], name: "index_course_lessons_on_lesson_id"
  end

  create_table "courses", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.string "main_media_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "languages", force: :cascade do |t|
    t.string "iso_name"
    t.string "english_name"
    t.string "native_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pronunciation_variant_name"
    t.index ["iso_name"], name: "index_languages_on_iso_name", unique: true
  end

  create_table "lessons", force: :cascade do |t|
    t.string "slug"
    t.bigint "medium_id", null: false
    t.string "start_timestamp"
    t.string "end_timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["medium_id"], name: "index_lessons_on_medium_id"
    t.index ["slug"], name: "index_lessons_on_slug", unique: true
  end

  create_table "media", force: :cascade do |t|
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["url"], name: "index_media_on_url", unique: true
  end

  create_table "phrases", force: :cascade do |t|
    t.bigint "medium_id", null: false
    t.bigint "l1_id", null: false
    t.bigint "l2_id", null: false
    t.string "text_l1"
    t.string "text_l2"
    t.string "timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["l1_id"], name: "index_phrases_on_l1_id"
    t.index ["l2_id"], name: "index_phrases_on_l2_id"
    t.index ["medium_id"], name: "index_phrases_on_medium_id"
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
    t.index ["phrase_id", "l1_start_index", "l1_end_index"], name: "idx_on_phrase_id_l1_start_index_l1_end_index_22c662cc13", unique: true
    t.index ["phrase_id"], name: "index_token_translations_on_phrase_id"
  end

  add_foreign_key "activities", "lessons"
  add_foreign_key "activity_phrases", "activities"
  add_foreign_key "activity_phrases", "phrases"
  add_foreign_key "activity_token_translations", "activities"
  add_foreign_key "activity_token_translations", "token_translations"
  add_foreign_key "course_lessons", "courses"
  add_foreign_key "course_lessons", "lessons"
  add_foreign_key "lessons", "media"
  add_foreign_key "phrases", "languages", column: "l1_id"
  add_foreign_key "phrases", "languages", column: "l2_id"
  add_foreign_key "phrases", "media"
  add_foreign_key "token_translations", "phrases"
end
