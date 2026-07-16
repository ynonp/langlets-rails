namespace :media do
  desc "Process video"
  task :create_phrases_from_video, [:video_url, :video_language, :translation_language] => :environment do |t, args|
    raise ArgumentError, "You must provide a video_url argument" if args[:video_url].blank?
    
    l1 = Language.find_by(iso_name: args[:video_language])
    raise ArgumentError, "Missing video_language" unless l1

    l2 = Language.find_by(iso_name: args[:translation_language])
    raise ArgumentError, "Missing translation_language" unless l2
    
    m = Medium.find_or_create_by!(url: args[:video_url], language: l1, translation_language: l2)
    m.create_phrases(l1, l2)
  end
end
