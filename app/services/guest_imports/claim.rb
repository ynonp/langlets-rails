module GuestImports
  class Claim
    def self.call(...) = new(...).call

    def initialize(user:, evaluation_signup: nil, source_import_request: nil)
      @user = user
      @evaluation_signup = evaluation_signup
      @source = evaluation_signup&.admin_import_request&.reload || source_import_request
    end

    def call
      existing = user.import_requests.find_by(
        youtube_video_id: video_id,
        translation_language: translation_language
      )
      return existing if existing

      if source.detecting?
        return user.import_requests.create!(
          youtube_url: video_url,
          youtube_video_id: video_id,
          translation_language: translation_language,
          title: title,
          course: course,
          create_song_progress: source.create_song_progress,
          status: :detecting
        )
      end

      if source.failed?
        return user.import_requests.create!(
          youtube_url: video_url,
          youtube_video_id: video_id,
          translation_language: translation_language,
          title: title,
          clip_language: clip_language,
          course: course,
          create_song_progress: source.create_song_progress,
          status: :failed,
          failure_reason: source.failure_reason
        )
      end

      Imports::Create.call(
        user: user,
        url: video_url,
        clip_language: clip_language,
        translation_language: translation_language
      ).import_request
    rescue ActiveRecord::RecordNotUnique
      user.import_requests.find_by!(
        youtube_video_id: video_id,
        translation_language: translation_language
      )
    end

    private

    attr_reader :user, :source, :evaluation_signup

    def video_url = evaluation_signup&.video_url || source.youtube_url
    def video_id = evaluation_signup&.video_id || source.youtube_video_id
    def title = evaluation_signup&.title || source.title
    def clip_language = evaluation_signup&.clip_language || source.clip_language
    def translation_language = evaluation_signup&.translation_language || source.translation_language
    def course = evaluation_signup&.course || source.course
  end
end
