class TokenTranslation < ApplicationRecord
  include AzureTextToSpeech

  belongs_to :phrase
  has_one_attached :l1_audio, service: :s3_public
  has_many :token_translation_users, dependent: :destroy

  attribute :index_type, :integer
  enum :index_type, { word_index: 0, character_index: 1 }, default: :word_index

  has_timestamp [ :start_timestamp, :end_timestamp ]

  validate :validate_indexes

  # Capability: a token with a start timestamp can drive karaoke-style word
  # highlighting in the video players.
  def karaoke?
    start_timestamp.present?
  end

  # Permanent public S3 URL (the s3_public service is public), so playback
  # doesn't round-trip through the Rails blob-redirect controller.
  def l1_audio_url
    l1_audio.attached? ? l1_audio.url : nil
  end

  scope :with_questions, ->() {
    where("questions is not null and cardinality(questions) > 0")
  }

  def l1_start_character_index
    return read_attribute(:l1_start_index) if character_index?
    word_to_char_l1(read_attribute(:l1_start_index))
  end

  def l1_end_character_index
    return read_attribute(:l1_end_index) if character_index?
    word_to_char_l1(read_attribute(:l1_end_index), inclusive: true)
  end

  def l2_start_character_index
    return read_attribute(:l2_start_index) if character_index?
    word_to_char_l2(read_attribute(:l2_start_index))
  end

  def l2_end_character_index
    return read_attribute(:l2_end_index) if character_index?
    word_to_char_l2(read_attribute(:l2_end_index), inclusive: true)
  end

  def original_text
    return "" unless phrase&.text_l1.present?
    phrase.text_l1[l1_start_character_index..l1_end_character_index]
  end

  def span_length
    l1_end_character_index - l1_start_character_index
  end

  def l1_start_index
    l1_start_character_index
  end

  def l1_end_index
    l1_end_character_index
  end

  def l2_start_index
    l2_start_character_index
  end

  def l2_end_index
    l2_end_character_index
  end

  def l1_start_index=(value)
    write_attribute(:l1_start_index, value)
  end

  def l1_end_index=(value)
    write_attribute(:l1_end_index, value)
  end

  def l2_start_index=(value)
    write_attribute(:l2_start_index, value)
  end

  def l2_end_index=(value)
    write_attribute(:l2_end_index, value)
  end

  after_create :generate_l1_audio, if: :should_generate_audio?
  after_update :generate_l1_audio, if: :should_generate_audio_on_update?

  private

  def should_generate_audio?
    original_text.present? && phrase&.l1&.iso_name.present?
  end

  def should_generate_audio_on_update?
    (saved_change_to_l1_start_index? || saved_change_to_l1_end_index?) && should_generate_audio?
  end

  def generate_l1_audio
    GenerateTokenAudioJob.perform_later(id) unless Rails.env.development?
  end

  def word_to_char_l1(word_index, inclusive: false)
    return nil if word_index.nil?
    return nil unless phrase&.text_l1.present?

    words = phrase.text_l1.split
    return nil if word_index >= words.length || word_index < 0

    if word_index == 0
      char_pos = 0
    else
      char_pos = words[0...word_index].join(" ").length + 1
    end

    if inclusive
      char_pos += words[word_index].length - 1
    end

    char_pos
  end

  def word_to_char_l2(word_index, inclusive: false)
    return nil if word_index.nil?
    return nil unless phrase&.text_l2.present?

    words = phrase.text_l2.split
    return nil if word_index >= words.length || word_index < 0

    if word_index == 0
      char_pos = 0
    else
      char_pos = words[0...word_index].join(" ").length + 1
    end

    if inclusive
      char_pos += words[word_index].length - 1
    end

    char_pos
  end

  def validate_indexes
    return unless phrase&.text_l1.present?

    if character_index?
      validate_character_indexes
    else
      validate_word_indexes
    end
  end

  def validate_character_indexes
    l1_start = read_attribute(:l1_start_index)
    l1_end = read_attribute(:l1_end_index)

    if l1_start.present? && l1_end.present?
      if l1_start > l1_end
        errors.add(:l1_start_index, "must be less than or equal to l1_end_index")
      end

      if l1_start < 0 || l1_end >= phrase.text_l1.length
        errors.add(:l1_start_index, "character indexes #{l1_start}-#{l1_end} out of bounds for phrase '#{phrase.text_l1}'")
      end
    else
      errors.add(:l1_start_index, "l1 indexes are required")
    end

    if read_attribute(:l2_start_index).present? && read_attribute(:l2_end_index).present? && phrase&.text_l2.present?
      l2_start = read_attribute(:l2_start_index)
      l2_end = read_attribute(:l2_end_index)

      if l2_start > l2_end
        errors.add(:l2_start_index, "must be less than or equal to l2_end_index")
      end

      if l2_start < 0 || l2_end >= phrase.text_l2.length
        errors.add(:l2_start_index, "character indexes #{l2_start}-#{l2_end} out of bounds in phrase '#{phrase.text_l2}'")
      end
    end
  end

  def validate_word_indexes
    l1_words = phrase.text_l1.split
    l1_start = read_attribute(:l1_start_index)
    l1_end = read_attribute(:l1_end_index)

    if l1_start.present? && l1_end.present?
      if l1_start > l1_end
        errors.add(:l1_start_index, "must be less than or equal to l1_end_index")
      end

      if l1_start < 0 || l1_end >= l1_words.length
        errors.add(:l1_start_index, "word indexes #{l1_start}-#{l1_end} out of bounds for phrase #{phrase.text_l1}")
      end
    else
      errors.add(:l1_start_index, "l1 indexes are required (phrase text #{phrase.text_l1}; translation #{translation})")
    end

    if read_attribute(:l2_start_index).present? && read_attribute(:l2_end_index).present? && phrase&.text_l2.present?
      l2_words = phrase.text_l2.split
      l2_start = read_attribute(:l2_start_index)
      l2_end = read_attribute(:l2_end_index)

      if l2_start > l2_end
        errors.add(:l2_start_index, "must be less than or equal to l2_end_index")
      end

      if l2_start < 0 || l2_end >= l2_words.length
        errors.add(:l2_start_index, "word indexes #{l2_start}-#{l2_end} out of bounds in phrase #{phrase.text_l2}")
      end
    end
  end
end
