module HasTimestamp
  extend ActiveSupport::Concern

  class_methods do
    def has_timestamp(fields)
      Array(fields).each do |field|
        define_method("#{field}_seconds=") do |value|
          total_seconds = value.to_f
          minutes = total_seconds.to_i / 60
          seconds = total_seconds % 60
          self[field] = format("%02d:%05.2f", minutes, seconds)
        end

        define_method("#{field}_seconds") do
          value = send(field)
          return nil unless value.present? && value.include?(":")

          parts = value.split(":")
          case parts.length
          when 2
            parts[0].to_f * 60 + parts[1].to_f
          when 3
            parts[0].to_f * 3600 + parts[1].to_f * 60 + parts[2].to_f
          else
            nil
          end
        end
      end
    end
  end
end
