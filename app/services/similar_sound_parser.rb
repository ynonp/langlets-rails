class SimilarSoundParser
  attr_reader :phrases, :llm_response, :lines

  def initialize(phrases, llm_response)
    @phrases = phrases
    @llm_response = llm_response
    @lines = llm_response.delete_prefix("Output:\n").lines.reject {|l| l.blank? }
  end

  def call
    lines.each_with_index do |line, index|
      phrases[index].add_similar_sound_from(line.strip)
    end
  end
end
