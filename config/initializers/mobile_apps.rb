release_properties = Rails.root.join("config/android_release.properties").each_line.with_object({}) do |line, properties|
  key, value = line.strip.split("=", 2)
  properties[key] = value if key.present? && !key.start_with?("#")
end

android_version = release_properties.fetch("version_name")

Rails.application.config.x.mobile_apps = ActiveSupport::OrderedOptions.new
Rails.application.config.x.mobile_apps.android_download_path = "/downloads/android/langlets-#{android_version}.apk"
Rails.application.config.x.mobile_apps.iphone_download_url = nil
