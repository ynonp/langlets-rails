class SimilarSoundParser
  attr_reader :phrases, :llm_response, :lines

  def initialize(phrases, llm_response)
    @phrases = phrases
    @llm_response = llm_response
    @lines = llm_response
      .delete_prefix("Output:\n")
      .delete_prefix("```\n")
      .lines
      .map(&:strip)
      .reject {|l| l.blank? }
  end

  def call
    lines.zip(phrases) do |line, phrase|
      phrase&.add_similar_sound_from(line)
    end
  end
end
