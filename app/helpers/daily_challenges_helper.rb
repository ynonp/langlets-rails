module DailyChallengesHelper
  # Content translations include learning languages that are not UI locales.
  VIDEO_DESCRIPTION_FALLBACKS = YAML.safe_load_file(Rails.root.join("config/daily_langlet_descriptions.yml")).freeze

  def daily_langlet_duration(video)
    seconds = video["duration_seconds"]
    return unless seconds.is_a?(Numeric) && seconds.finite? && seconds >= 1

    minutes, remainder = seconds.to_i.divmod(60)
    format("%d:%02d", minutes, remainder)
  end

  def daily_langlet_description(video, language)
    descriptions = video["descriptions"]
    text = descriptions[language.iso_name] if descriptions.is_a?(Hash)
    return text if text.is_a?(String) && text.present? && text.length <= 1000

    template = VIDEO_DESCRIPTION_FALLBACKS[language.iso_name]
    template % { title: video.fetch("title") } if template
  end
end
