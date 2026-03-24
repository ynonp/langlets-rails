require 'pycall/import'

class Medium < ApplicationRecord
  include PyCall::Import
  has_many :phrases
  belongs_to :language

  def self.youtube_thumbnail_url(video_id, quality = 'hqdefault')
    "https://img.youtube.com/vi/#{video_id}/#{quality}.jpg"
  end

  def create_phrases(from_language, to_language)
    case
    when youtube?
      create_phrases_from_youtube_video(from_language, to_language)
    else
       raise ArgumentError, "Unsupported URL format: #{url}"
    end
  end

  def thumbnail_url
    video_id = extract_youtube_video_id
    Medium.youtube_thumbnail_url(video_id)
  end

  def create_phrases_from_youtube_video(from_language, to_language)
    video_id = extract_youtube_video_id
    audio_file_path = Rails.root.join("audio", "#{video_id}.mp3")
    download_youtube_video unless File.exist?(audio_file_path)

    phrases = Ai::Gemini.extract_phrases_from_audio(audio_file_path, from_language.english_name, to_language.english_name, "00:00", "02:00")
    phrases.each do |phrase|
      next if phrase[from_language.english_name].blank? || phrase[to_language.english_name].blank?
      Phrase.create(
        medium: self,
        l1: from_language,
        l2: to_language,
        text_l1: phrase[from_language.english_name],
        text_l2: phrase[to_language.english_name],
        timestamp: phrase["timestamp"]
      )
    end
  end

  def youtube?
    !!(url =~ /\Ahttps?:\/\/(www\.)?youtube\.com\/watch\?v=[\w\-]+/i) ||
      !!(url =~ /\Ahttps?:\/\/youtu\.be\/[\w\-]+/i)
  end

  def extract_youtube_video_id
    # Match patterns like:
    # - https://www.youtube.com/watch?v=VIDEO_ID
    # - https://youtu.be/VIDEO_ID
    # - https://www.youtube.com/shorts/VIDEO_ID
    regex = %r{
      (?:youtube\.com/(?:watch\?v=|shorts/)|
       youtu\.be/)           # Match the base domain and path
      ([\w-]{11})            # Capture the 11-character video ID
    }x
  
    match = url.match(regex)
    match[1] if match
  end

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
