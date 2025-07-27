module Activities
  class WatchVideoActivity < Activity
    include ActivityWithTokens

    def activity_params
      lesson = self.lesson
      l1 = ordered_phrases.first.l1
      l2 = ordered_phrases.first.l2

      {
        **video_params,
        phrases: ordered_phrases,
        video_player: true,
        l1_rtl: l1.rtl,
        l2_rtl: l2.rtl
      }
    end

  def ordered_phrases
    @ordered_phrases ||= phrases.order(:timestamp).includes(:text_l1 => :script_variants, :text_l2 => :script_variants).to_a
  end

  end
end
