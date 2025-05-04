module ActivitiesHelper
  def timestamp_to_seconds(timestamp_mm_ss)
    minutes, seconds = timestamp_mm_ss.split(":").map(&:to_i)
    (minutes * 60) + seconds
  end
end
