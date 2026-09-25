module Native
  # Explicit wire representations. No controller/HTML activity_params cross this boundary.
  class Serializer
    def initialize(user:, base_url:)
      @user, @base_url = user, base_url
    end

    def prepare_courses(rows)
      ids = rows.map(&:id)
      lesson_ids = rows.flat_map { |row| row.lessons.map(&:id) }
      @completed = @user.lesson_users.where(lesson_id: lesson_ids).pluck(:lesson_id).to_set
      @enrolled = @user.enrollments.where(course_id: ids).pluck(:course_id).to_set
      @shared = ChannelItem.joins(:channel).where(channels: { user_id: @user.id, share: true }, course_id: ids).pluck(:course_id).to_set
      @owned = ChannelItem.joins(:channel).where(channels: { user_id: @user.id }, course_id: ids)
        .where('channels."default" = ? OR channels.type = ?', true, "ProChannel").pluck(:course_id).to_set
    end

    def language(row)
      { id: row.id, code: row.iso_name, name: row.english_name, native_name: row.native_name, rtl: !!row.rtl }
    end

    def course(row)
      { id: row.id, slug: row.slug, name: row.localized_name, language: row.language&.iso_name,
        thumbnail_url: row.thumbnail_url, provider: row.provider, video_id: row.video_id,
        media_url: row.main_media_url, lesson_count: row.lessons.size,
        completed_lesson_ids: @completed ? row.lessons.map(&:id).select { |id| @completed.include?(id) } : @user.lesson_users.where(lesson_id: row.lessons.map(&:id)).pluck(:lesson_id),
        enrolled: @enrolled ? @enrolled.include?(row.id) : @user.enrollments.exists?(course_id: row.id), shared: @shared ? @shared.include?(row.id) : @user.sharing?(row),
        owned: @owned ? @owned.include?(row.id) : @user.owns_publication_of?(row), translation_ready: row.course_translations.any? { |translation| translation.language_id == Current.translation_language_id && translation.ready? },
        lessons: row.lessons.sort_by { |lesson| [ lesson.order || 0, lesson.id ] }.map { |lesson| lesson_summary(lesson) } }
    end

    def course_phrases(course)
      phrases(Phrase.where(medium_id: course.lessons.select(:medium_id)))
    end

    def phrases(scope)
      scope.includes(:l1, :localized_translation, :phrase_translations, :medium,
        phrase_tokens: [ :token_translations, :localized_translation, { l1_audio_attachment: :blob } ])
        .to_a.sort_by { |p| [ p.timestamp_seconds || 0, p.id ] }.map { |p| phrase(p) }
    end

    def lesson_summary(row)
      { id: row.id, name: row.localized_name, slug: row.slug, course_slug: row.course&.slug,
        language: (row.review_language || row.course&.language || row.medium&.language)&.iso_name,
        start: row.start_timestamp_seconds, end: row.end_timestamp_seconds }
    end

    def lesson(row)
      activities = row.activities.order(:order, :id).includes(:phrase_tokens, :phrases).to_a
      ids = activities.flat_map { |a| a.phrases.map(&:id) + a.phrase_tokens.map(&:phrase_id) }.uniq
      phrases = Phrase.where(id: ids).includes(:l1, :localized_translation, :phrase_translations, :medium,
        phrase_tokens: [ :token_translations, :localized_translation, { l1_audio_attachment: :blob } ])
      lesson_summary(row).merge(
        schema_version: 1, downloaded_at: Time.zone.now.iso8601,
        offline_until: 7.days.from_now.iso8601,
        activities: activities.map { |a| { id: a.id, kind: a.type.demodulize, title: a.text_header,
          phrase_ids: a.phrases.sort_by { |p| [ p.timestamp_seconds || 0, p.id ] }.map(&:id),
          token_ids: a.is_a?(Activities::FindAnswerActivity) ? PhraseToken.where(phrase_id: a.phrases.map(&:id)).with_questions.pluck(:id) : a.phrase_tokens.map(&:id) } },
        phrases: phrases.map { |p| phrase(p) },
        completed_activity_ids: @user.activity_users.where(activity_id: activities.map(&:id)).pluck(:activity_id))
    end

    def phrase(row)
      { id: row.id, text: row.text_l1.to_s, translation: row.text_l2.to_s,
        language: row.l1.iso_name, rtl: !!row.l1.rtl, start: row.timestamp_seconds,
        provider: row.medium&.provider, video_id: row.medium&.extract_youtube_video_id,
        audio: nil, tokens: row.phrase_tokens.map { |token| token(token) } }
    end

    def token(row)
      { id: row.id, text: row.original_text, translation: row.translation.to_s,
        start_index: row.l1_start_character_index, end_index: row.l1_end_character_index,
        start: row.start_timestamp_seconds, end: row.end_timestamp_seconds,
        questions: row.questions || [], similar_sounds: row.similar_sound || [], audio: audio(row) }
    end

    def vocabulary(row)
      { id: row.id, token_id: row.phrase_token_id, language: row.source_language.iso_name,
        translation: row.translation.to_s, practicing: row.practicing?, custom: row.custom?,
        phrase: phrase(row.phrase), token: token(row.phrase_token) }
    end

    def audio(row)
      return unless row.l1_audio.attached?
      blob = row.l1_audio.blob
      { id: blob.id, url: Rails.application.routes.url_helpers.rails_blob_url(blob, host: @base_url),
        byte_size: blob.byte_size, checksum: blob.checksum }
    end
  end
end
