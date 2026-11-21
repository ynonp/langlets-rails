# Structured output for one Dictionary-tab card (see Dictionary::EntryGenerator).
#
# Built per lookup rather than declared once: each field's description names
# the language it must be written in. Field-level descriptions are what the
# model follows most closely, and without the language spelled out there it
# drifts into the target language for the explanation (seen with Japanese).
#
# Every field is required so the model cannot silently drop one; fields that do
# not apply come back as empty strings or empty arrays.
module DictionaryEntrySchema
  def self.for(native:, target:)
    native_name = native.english_name
    target_name = target.english_name

    Class.new(RubyLLM::Schema) do
      string :detected_language,
        description: "ISO code of the language the learner's input is written in, chosen from the supported codes listed in the instructions, or \"other\"."
      string :headword,
        description: "In #{target_name}: the word or phrase this card teaches, in its natural written form."
      string :transliteration,
        description: "Latin-script romanization of the headword, or an empty string when #{target_name} is written in Latin script."
      string :part_of_speech,
        description: "In #{native_name}: the headword's part of speech (e.g. the #{native_name} word for noun or verb)."
      array :grammar_notes, of: :string,
        description: "In #{native_name}: up to three short grammar chips such as gender or plural. Labels in #{native_name}; only the #{target_name} word forms themselves stay in #{target_name}."
      string :translation,
        description: "In #{native_name}: the headword's meaning — main sense first, then up to two close senses, comma separated."
      string :explanation,
        description: "In #{native_name}, never in #{target_name}: two or three sentences on what the word means and how it is used, contrasting it with a near-synonym when that helps. Quote #{target_name} words only as examples inside the #{native_name} text."
      array :examples, description: "Exactly three short, natural example sentences." do
        object do
          string :sentence, description: "In #{target_name}: the example sentence."
          string :highlight, description: "The exact substring of the sentence where the headword (or its inflected form) appears. Must occur verbatim in the sentence."
          string :translation, description: "In #{native_name}: the sentence's translation."
        end
      end
      string :illustration_prompt,
        description: "In English: one sentence describing a simple, concrete, text-free scene that illustrates the headword's meaning."
    end
  end
end
