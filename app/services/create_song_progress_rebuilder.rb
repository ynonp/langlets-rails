# Reconstructs a CreateSongProgress data blob from a course's persisted rows.
#
# The blob is the working format for the translation pipeline and the export
# interchange format between deployments, but the stored record is only a
# cache: everything the translation steps consume -- L1 phrase texts,
# per-token words, lesson names, and the already-applied translations -- also
# lives on the course. So when the record is gone (or exists with an empty
# blob, as the import flow creates it), rebuild it from the course instead of
# re-running transcription: a fresh transcription may segment differently and
# silently misalign with the course's persisted tokens, while a blob rebuilt
# from those same rows is aligned with them by construction.
class CreateSongProgressRebuilder
  attr_reader :course

  def initialize(course, progress: nil)
    @course = course
    @progress = progress
  end

  def call
    progress = @progress || find_or_create_progress
    rebuild!(progress) if progress.data.blank? || progress.data["phrases"].blank?
    course.update!(create_song_progress: progress) unless course.create_song_progress_id == progress.id
    progress
  end

  private

  def find_or_create_progress
    course.create_song_progress || CreateSongProgress.find_or_create_by!(
      youtubeurl: course.main_media_url,
      clip_language: course.language.english_name
    ) do |row|
      row.translation_language = default_translation_language
      row.data = {}
    end
  end

  def default_translation_language
    language = course.course_translations.order(:id).first&.language
    raise ArgumentError, "course #{course.id} has no course_translations to name a translation language" unless language

    language.english_name
  end

  def rebuild!(progress)
    phrases = course.medium&.phrases&.order(:timestamp)
                    &.includes(:phrase_translations, phrase_tokens: :token_translations)&.to_a
    raise ArgumentError, "course #{course.id} has no phrases to rebuild from" if phrases.blank?

    tokens_by_phrase = phrases.to_h { |phrase| [ phrase.id, ordered_tokens(phrase) ] }

    data = progress.data.presence || {}
    data["phrases"] = phrases.map { |phrase| phrase_entry(phrase, tokens_by_phrase[phrase.id]) }
    data["lessons"] = lessons_text { |lesson| lesson.name }
    data["translations"] = ready_languages.to_h do |language|
      [ language.iso_name, translation_payload(language, phrases, tokens_by_phrase) ]
    end
    data["format_version"] = CreateSongProgress::DataFormat::VERSION
    data["rebuilt_from_course_id"] = course.id
    progress.data = data
    progress.save!
    progress
  end

  # Token order must match BuildSong#add_translation exactly -- it maps
  # per-word translations back onto tokens by position.
  def ordered_tokens(phrase)
    phrase.phrase_tokens.sort_by { |t| [ t.read_attribute(:l1_start_index) || Float::INFINITY, t.id ] }
  end

  def phrase_entry(phrase, tokens)
    {
      "text_l1" => phrase.text_l1,
      "timestamp" => phrase.timestamp,
      "timestamp_end" => tokens.map(&:end_timestamp).compact.last,
      "words" => tokens.map do |token|
        {
          "text" => token.original_text,
          "timestamp" => token.start_timestamp,
          "timestamp_end" => token.end_timestamp,
          "l1_start_index" => token.l1_start_character_index,
          "l1_end_index" => token.l1_end_character_index
        }
      end
    }
  end

  # One block per persisted lesson, in lesson order, so lesson_name_for's
  # index-based lookup lines up 1:1 with course.lessons.order(:order).
  def lessons_text
    lessons.map do |lesson|
      "# #{yield(lesson)}\n#{lesson.start_timestamp}\n#{lesson.end_timestamp || lesson.start_timestamp}"
    end.join("\n\n")
  end

  def lessons
    @lessons ||= course.lessons.includes(:lesson_translations).order(:order).to_a
  end

  def ready_languages
    Language.where(id: course.course_translations.ready.select(:language_id))
  end

  def translation_payload(language, phrases, tokens_by_phrase)
    {
      "language_id" => language.id,
      "language_name" => language.english_name,
      "phrases" => phrases.map do |phrase|
        {
          "text" => phrase.phrase_translations.find { |pt| pt.language_id == language.id }&.text,
          "words" => tokens_by_phrase[phrase.id].map do |token|
            token.token_translations.find { |tt| tt.language_id == language.id }&.translation
          end
        }
      end,
      "lessons" => lessons_text { |lesson| lesson.lesson_translations.find { |lt| lt.language_id == language.id }&.name || lesson.name }
    }
  end
end
