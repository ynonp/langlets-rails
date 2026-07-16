class AddTranslationLanguageToMedia < ActiveRecord::Migration[8.0]
  # media.url was uniquely indexed, so one row represented one video. But phrases
  # hang off a medium and carry a language pair, and CreateSongProgress is keyed
  # on (youtubeurl, clip_language, translation_language). So importing the same
  # video for a second translation language resolved to the *same* medium, and
  # CourseBuilder::BuildSong's `medium.phrases.destroy_all` wiped the first
  # course's phrases.
  #
  # The read paths have the same flaw: `medium.phrases` is treated as "this
  # course's phrases" in ~20 places (FullPlayerController, the activity builders,
  # Lesson#... ), so a shared medium would interleave two languages at runtime.
  #
  # Keying a medium on (url, clip language, translation language) makes
  # `medium.phrases` correct everywhere by construction.
  def up
    add_reference :media, :translation_language, foreign_key: { to_table: :languages }

    # A medium's translation language is the l2 of the phrases it already owns.
    # Phrase#l2 is a required belongs_to, so this is total for any medium with
    # phrases; phrase-less media keep NULL and are left alone.
    execute <<~SQL.squish
      UPDATE media
         SET translation_language_id = sub.l2_id
        FROM (
          SELECT DISTINCT ON (medium_id) medium_id, l2_id
            FROM phrases
           ORDER BY medium_id, id
        ) sub
       WHERE media.id = sub.medium_id
    SQL

    remove_index :media, :url
    add_index :media,
              [ :url, :language_id, :translation_language_id ],
              unique: true,
              name: "index_media_on_url_and_language_pair"
  end

  def down
    remove_index :media, name: "index_media_on_url_and_language_pair"
    add_index :media, :url, unique: true
    remove_reference :media, :translation_language
  end
end
