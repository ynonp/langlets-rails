module HasTimestamp
  extend ActiveSupport::Concern

  class_methods do
    def has_timestamp(fields)
      Array(fields).each do |field|
        define_method("#{field}_seconds=") do |value|
          minutes = value.to_i / 60
          seconds = value.to_i % 60
          self[field] = format("%02d:%02d", minutes, seconds)
        end

        define_method("#{field}_seconds") do
          value = send(field)
          return nil unless value.present? && value.include?(":")

          parts = value.split(":").map(&:to_i)
          case parts.length
          when 2
            parts[0] * 60 + parts[1]            # MM:SS
          when 3
            parts[0] * 3600 + parts[1] * 60 + parts[2]  # HH:MM:SS
          else
            nil
          end
        end
      end
    end
  end
end
