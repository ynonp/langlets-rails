require "test_helper"

module Courses
  class NamingTest < ActiveSupport::TestCase
    VIDEO_ID = "kJQP7kiw5Fk".freeze

    test "slugs a plain title and suffixes the video id" do
      result = Naming.call(title: "Valentina y el Dragón — Cuento Completo", video_id: VIDEO_ID)

      assert_equal "Valentina y el Dragón — Cuento Completo", result.name
      assert_equal "valentina-y-el-dragón-cuento-completo-kjqp7kiw5fk", result.slug
    end

    # slug_for_language keeps Unicode letters, so RTL titles slug natively rather
    # than collapsing to the video id.
    test "Hebrew and Arabic titles keep their own slugs" do
      hebrew = Naming.call(title: "ולנטינה והדרקון", video_id: VIDEO_ID)
      arabic = Naming.call(title: "فالنتينا والتنين", video_id: VIDEO_ID)

      assert_equal "ולנטינה-והדרקון-kjqp7kiw5fk", hebrew.slug
      assert_equal "فالنتينا-والتنين-kjqp7kiw5fk", arabic.slug
    end

    # The real edge: titles with no letters at all. slug_for_language returns ""
    # for emoji-only and "-" for punctuation-only, both of which would fail
    # `validates :slug, presence: true` — and the mobile flow has no UI to report
    # that back.
    test "titles with no letters fall back to the video id" do
      {
        "🎵🎶🎵"      => "emoji only",
        "!!! ??? ..."  => "punctuation only",
        "・・・"        => "symbols only"
      }.each do |title, description|
        result = Naming.call(title: title, video_id: VIDEO_ID)

        assert_equal "kjqp7kiw5fk-kjqp7kiw5fk", result.slug, "failed for #{description}"
      end
    end

    # slug_for_language answers "untitled" for a blank string, which is already a
    # usable base — no need to fall back to the id.
    test "a blank title slugs as untitled plus the video id" do
      assert_equal "untitled-kjqp7kiw5fk", Naming.call(title: "", video_id: VIDEO_ID).slug
      assert_equal "untitled-kjqp7kiw5fk", Naming.call(title: "   ", video_id: VIDEO_ID).slug
    end

    # The invariant the mobile flow actually depends on.
    test "never produces a blank slug" do
      [ "🎵", "!!!", "", "   ", "ולנטינה", "Normal Title", "・" ].each do |title|
        assert Naming.call(title: title, video_id: VIDEO_ID).slug.present?,
               "blank slug for #{title.inspect}"
      end
    end

    test "a title with no letters still gets a usable name" do
      assert_equal VIDEO_ID, Naming.call(title: "", video_id: VIDEO_ID).name
      assert_equal "Untitled Course", Naming.call(title: "", video_id: nil).name
    end

    test "mixed emoji and text keeps the text" do
      result = Naming.call(title: "Despacito 🔥 (Official Video)", video_id: VIDEO_ID)

      assert_equal "despacito-official-video-kjqp7kiw5fk", result.slug
    end

    test "two different videos with the same title get different slugs" do
      a = Naming.call(title: "Same Title", video_id: "aaaaaaaaaaa")
      b = Naming.call(title: "Same Title", video_id: "bbbbbbbbbbb")

      assert_not_equal a.slug, b.slug
      assert_equal a.name, b.name, "names may collide; slugs may not"
    end

    test "slugs are deterministic" do
      2.times.map { Naming.call(title: "Cuatro Vientos", video_id: VIDEO_ID).slug }.then do |slugs|
        assert_equal slugs.first, slugs.last
      end
    end
  end
end
