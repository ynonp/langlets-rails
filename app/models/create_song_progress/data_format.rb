# The shape contract for CreateSongProgress#data.
#
# Version 1 (legacy) blobs carry a single language inline: each phrase has a
# "text_l2" and each word a "translation", and the language is named only by
# the record's translation_language column.
#
# Version 2 blobs keep data["phrases"] language-neutral and hold every
# language's content under data["translations"][iso] (see
# CreateSongProgress#add_translation for the payload shape).
#
# Blobs written before versioning existed carry no "format_version" stamp, so
# unstamped blobs are classified by shape; everything written from now on is
# stamped explicitly.
module CreateSongProgress::DataFormat
  VERSION = 2

  module_function

  def version(data)
    return VERSION if data.blank?
    return data["format_version"].to_i if data["format_version"].present?

    legacy_shaped?(data) ? 1 : VERSION
  end

  def current?(data) = version(data) >= VERSION

  def legacy_shaped?(data)
    return true if data["phrases_with_token_translations"].present?

    first = Array(data["phrases"]).first
    return false unless first.is_a?(Hash)

    first.key?("text_l2") || Array(first["words"]).any? { |w| w.is_a?(Hash) && w.key?("translation") }
  end

  # Moves the inline per-phrase/per-word translations out of data["phrases"]
  # into the given language's payload and stamps the version. Mutates and
  # returns `data`. This is the single writer of the payload shape: the
  # pipeline calls it after translating into a new language, and the format
  # converter calls it to upgrade legacy blobs (where the inline content is
  # the translation_language's).
  def pack_translation(data, language)
    data["translations"] ||= {}
    data["translations"][language.iso_name] = {
      "language_id" => language.id,
      "language_name" => language.english_name,
      "phrases" => Array(data["phrases"]).map do |phrase|
        {
          "text" => phrase.delete("text_l2"),
          "words" => Array(phrase["words"]).map { |word| word.is_a?(Hash) ? word.delete("translation") : nil }
        }
      end,
      "lessons" => data["lessons"]
    }
    data["format_version"] = VERSION
    data
  end
end
