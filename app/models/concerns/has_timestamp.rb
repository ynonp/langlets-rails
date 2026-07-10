module HasTimestamp
  extend ActiveSupport::Concern

  # Canonical timestamp <-> seconds conversions. These back the generated
  # <field>_seconds accessors below and are also the single source of truth for
  # model class methods that convert plain strings (e.g. Phrase.timestamp_to_seconds
  # / Phrase.to_string_timestamp delegate here). Kept on this generic concern --
  # rather than a specific model -- so nothing has to depend on Phrase to convert.

  # Parse "MM:SS.ss" or "HH:MM:SS.ss" into float seconds. Returns nil for blank or
  # malformed input so callers can tell "no timestamp" apart from 0 seconds.
  def self.timestamp_to_seconds(value)
    return nil unless value.present? && value.include?(":")

    parts = value.split(":")
    case parts.length
    when 2
      parts[0].to_f * 60 + parts[1].to_f
    when 3
      parts[0].to_f * 3600 + parts[1].to_f * 60 + parts[2].to_f
    end
  end

  # Format float seconds into an "MM:SS.ss" timestamp string.
  def self.seconds_to_timestamp(seconds)
    total_seconds = seconds.to_f
    minutes = total_seconds.to_i / 60
    secs = total_seconds % 60
    format("%02d:%05.2f", minutes, secs)
  end

  class_methods do
    def has_timestamp(fields)
      Array(fields).each do |field|
        define_method("#{field}_seconds=") do |value|
          self[field] = HasTimestamp.seconds_to_timestamp(value)
        end

        define_method("#{field}_seconds") do
          HasTimestamp.timestamp_to_seconds(send(field))
        end
      end
    end
  end
end
