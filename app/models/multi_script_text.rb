class MultiScriptText < ApplicationRecord
  belongs_to :language
  has_many :script_variants, dependent: :destroy
  
  accepts_nested_attributes_for :script_variants
  
  validates :script_variants, presence: { message: "must have at least one script variant" }
  
  enum :audio_status, {
    not_required: 0,
    audio_required: 1,
    audio_ready: 2
  }

  # Class method to create MultiScriptText with default script content
  def self.create_with_default_content(language:, content:)
    create!(
      language: language,
      script_variants_attributes: [
        { script: language.default_script, content: content }
      ]
    )
  end

  def to_s(script = nil)
    script ? content_for_script(script) : default_content
  end

  def words
    to_s.tokenize.map(&:to_s)
  end

  def character_range(start_word_index, end_word_index, script: nil)
    content = script ? content_for_script(script) : default_content
    start_char = content.tokenize.drop(start_word_index).first.begin(0)
    end_char = content.tokenize.drop(end_word_index).first.end(0)
    start_char...end_char
  end

  def add_variant!(script:, content:)
    clear_caches!
    script_variants.create!(script: script, content: content)
  end

  private

  def clear_caches!
    @script_variants_cache = nil
    @content_cache = nil
  end

  # Find or create a script variant for a specific script
  def variant_for_script(script)
    @script_variants_cache ||= {}
    @script_variants_cache[script.id] ||= script_variants.find_by(script: script)
  end

  # Get content for the default script of the language
  def default_content
    content_for_script(language.default_script)
  end

  # Get content for a specific script, with fallback to default
  def content_for_script(script)
    @content_cache ||= {}
    @content_cache[script.id] ||= begin
      variant = variant_for_script(script)
      variant&.content
    end
  end
end
