require 'pycall/import'

class Medium < ApplicationRecord
  include PyCall::Import
  has_many :lessons, dependent: :destroy
  has_many :phrases, dependent: :destroy
  belongs_to :language

  # One row per video and spoken language. Translations are attached below it.

  # Constructs the selected phrases from this medium and assigns each one the
  # end of its playback window. Boundaries come from the complete medium
  # timeline, not just the selected phrases, so skipped phrases still delimit
  # the preceding phrase. Association#find raises when an id belongs to a
  # different medium (or to a custom phrase), rather than silently dropping it.
  def phrases_with_playback_boundaries(phrase_ids:)
    ids = Array(phrase_ids).compact.uniq
    return [] if ids.empty?

    selected_phrases = phrases
      .includes(:localized_translation, phrase_tokens: [ :localized_translation, { l1_audio_attachment: :blob } ])
      .find(ids)
      .index_by(&:id)

    timeline = phrases.ordered_by_timestamp.pluck(:id, :timestamp)
    timeline.each_with_index.filter_map do |(phrase_id, _timestamp), index|
      phrase = selected_phrases[phrase_id]
      next unless phrase

      next_timestamp = timeline[index + 1]&.second
      phrase.calculated_end_timestamp = next_timestamp
      phrase.calculated_end_timestamp ||= HasTimestamp.seconds_to_timestamp(phrase.timestamp_seconds + 5) if phrase.timestamp_seconds
      phrase
    end
  end

  def self.youtube_thumbnail_url(video_id, quality = 'hqdefault')
    Youtube::Url.thumbnail_url(video_id, quality)
  end

  def create_phrases(from_language, to_language)
    case
    when youtube?
      create_phrases_from_youtube_video(from_language, to_language)
    else
       raise ArgumentError, "Unsupported URL format: #{url}"
    end
  end

  # nil for providers whose covers aren't derivable from the URL (TikTok). The
  # course-level cover is the one to render; see Course#thumbnail_url.
  def thumbnail_url
    VideoSource.derived_thumbnail_url(url)
  end

  def provider
    VideoSource.provider(url)
  end

  def tiktok?
    provider == :tiktok
  end

  def create_phrases_from_youtube_video(from_language, to_language)
    video_id = extract_youtube_video_id
    audio_file_path = Rails.root.join("audio", "#{video_id}.mp3")
    download_youtube_video unless File.exist?(audio_file_path)

    phrases = Ai::Gemini.extract_phrases_from_audio(audio_file_path, from_language.english_name, to_language.english_name, "00:00", "02:00")
    phrases.each do |phrase|
      next if phrase[from_language.english_name].blank? || phrase[to_language.english_name].blank?
      phrase_record = Phrase.create(
        medium: self,
        l1: from_language,
        text_l1: phrase[from_language.english_name],
        timestamp: phrase["timestamp"]
      )
      phrase_record.phrase_translations.create!(
        language: to_language,
        text: phrase[to_language.english_name]
      )
    end
  end

  def youtube?
    !!(url =~ /\Ahttps?:\/\/(www\.)?youtube\.com\/watch\?v=[\w\-]+/i) ||
      !!(url =~ /\Ahttps?:\/\/youtu\.be\/[\w\-]+/i)
  end

  # Name predates TikTok; it returns whichever provider's id the URL carries.
  # extract_video_id is the name to use in new code.
  def extract_video_id
    VideoSource.video_id(url)
  end
  alias_method :extract_youtube_video_id, :extract_video_id

  def download_youtube_video
    pyimport :yt_dlp
    video_id = extract_youtube_video_id
    
    ydl_opts = {
      'format' => 'bestaudio/best',
      'postprocessors' => [{
          'key' => 'FFmpegExtractAudio',
          'preferredcodec' => 'mp3',
          'preferredquality' => '192',
      }],
      'outtmpl' => Rails.root.join("audio", video_id).to_s,
      'quiet' => true,
      'no_warnings' => false
    }

    PyCall.with(yt_dlp.YoutubeDL.new(PyCall.builtins.dict.call(ydl_opts))) do |ydl|
      ydl.download(["https://www.youtube.com/watch?v=#{video_id}"])
    end
  end
end
