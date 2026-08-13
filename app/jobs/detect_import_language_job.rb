class DetectImportLanguageJob < ApplicationJob
  queue_as :default

  def perform(import_request_id)
    import_request = ImportRequest.find(import_request_id)
    return unless import_request.detecting?

    language, detected_data = detect_language!(import_request)
    promote_progress!(import_request, language, detected_data)

    Imports::Create.call(
      user: import_request.user,
      url: import_request.youtube_url,
      clip_language: language.english_name,
      translation_language: import_request.translation_language,
      client_token: import_request.client_token,
      detected_data: detected_data,
      existing_request: import_request,
      guest_started: import_request.guest_started?
    )

    if import_request.guest_started?
      import_request.reload
      EvaluationSignup.where(admin_import_request: import_request)
                      .update_all(
                        course_id: import_request.course_id,
                        clip_language: language.english_name,
                        updated_at: Time.zone.now
                      )
      attach_guest_claims(import_request, language, detected_data)
    end
  rescue => error
    Imports::Settlement.fail!(import_request, error.message) if import_request&.persisted?
    raise
  end

  private

  def attach_guest_claims(source, language, detected_data)
    ImportRequest.detecting
                 .where(create_song_progress_id: source.create_song_progress_id, guest_started: false)
                 .where.not(id: source.id)
                 .find_each do |claim|
      begin
        Imports::Create.call(
          user: claim.user,
          url: source.youtube_url,
          clip_language: language.english_name,
          translation_language: claim.translation_language,
          detected_data: detected_data,
          existing_request: claim
        )
        claim.user.update!(ios_lang: language.iso_name) if claim.user.ios_lang.blank?
      rescue => error
        Imports::Settlement.fail!(claim, error.message)
        Rails.logger.error "Could not attach guest import claim #{claim.id}: #{error.message}"
      end
    end
  end

  def detect_language!(import_request)
    CreateSongProgress.detect_language(url: import_request.youtube_url)
  rescue => error
    record_detection_error(import_request, error)
    raise
  end

  def promote_progress!(import_request, language, detected_data)
    import_request.create_song_progress.update!(
      clip_language: language.english_name,
      data: detected_data
    )
  rescue ActiveRecord::RecordNotUnique
    provisional = import_request.create_song_progress
    canonical = CreateSongProgress.find_by!(
      youtubeurl: import_request.youtube_url,
      clip_language: language.english_name
    )
    import_request.update!(create_song_progress: canonical)
    provisional.destroy!
  end

  def record_detection_error(import_request, error)
    progress = import_request.create_song_progress
    return if progress.nil?

    progress.update!(data: {
      "errors" => [ {
        "step" => "detect_language",
        "occurred_at" => Time.zone.now.iso8601,
        "error_class" => error.class.name,
        "error_message" => error.message
      } ]
    })
  rescue => persistence_error
    Rails.logger.error "Could not record language detection failure: #{persistence_error.message}"
  end
end
