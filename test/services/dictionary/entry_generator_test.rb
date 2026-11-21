require "test_helper"

module Dictionary
  # The model's answer is untrusted: the direction is re-derived from its
  # detection, language codes are mapped onto ours, and inline markup around
  # the headword is stripped. No network — RubyLLM.chat is stubbed.
  class EntryGeneratorTest < ActiveSupport::TestCase
    FakeChat = Struct.new(:content, :asked, :instructions) do
      def with_schema(*) = self
      def with_instructions(text)
        self.instructions = text
        self
      end
      def ask(prompt)
        self.asked = prompt
        Struct.new(:content).new(content)
      end
    end

    setup do
      @user = User.create!(email: "generator@example.com", password: "password123", confirmed_at: Time.zone.now)
      user = @user
      @lookup = DictionaryLookup.new(user: user, query: "זعيم", target_language: languages(:arabic),
        native_language: languages(:hebrew))
    end

    def generate(answer)
      @chat = FakeChat.new(answer)
      RubyLLM.stub(:chat, @chat) { EntryGenerator.call(@lookup).attributes }
    end

    def answer(**overrides)
      {
        "detected_language" => "he", "headword" => "زعيم", "transliteration" => "zaʿīm",
        "part_of_speech" => "שם עצם", "grammar_notes" => [ "זכר", "", "רבים: زعماء", "x", "y" ],
        "translation" => "מנהיג", "explanation" => "מנהיג.",
        "examples" => [ { "sentence" => "هو <highlight>زعيم</highlight>  [سياسي].", "highlight" => "*زعيم*", "translation" => "הוא מנהיג." } ],
        "illustration_prompt" => "A leader at a podium."
      }.merge(overrides)
    end

    test "input in any other language is translated into the target language" do
      attributes = generate(answer)

      assert_equal "to_target", attributes[:direction]
      assert_equal "he", attributes[:detected_language]
    end

    test "input in the target language is explained in the native language" do
      attributes = generate(answer("detected_language" => "ar"))

      # "ar" is mapped onto our "ar-JO" by its primary subtag.
      assert_equal "ar-JO", attributes[:detected_language]
      assert_equal "to_native", attributes[:direction]
    end

    test "an unsupported language is recorded as other and translated into the target" do
      attributes = generate(answer("detected_language" => "tlh"))

      assert_equal [ "other", "to_target" ], attributes.values_at(:detected_language, :direction)
    end

    test "inline markup is stripped and grammar notes are capped" do
      attributes = generate(answer)

      assert_equal({ "sentence" => "هو زعيم سياسي.", "highlight" => "زعيم", "translation" => "הוא מנהיג." },
        attributes[:examples].first)
      assert_equal [ "זכר", "רבים: زعماء", "x" ], attributes[:grammar_notes]
    end

    test "a JSON string answer is parsed and an empty headword falls back to the query" do
      attributes = generate(answer("headword" => " ").to_json)

      assert_equal @lookup.query, attributes[:headword]
    end

    test "the learner's notes for the target language are passed to the model" do
      @user.set_dictionary_instructions(languages(:arabic), "Use Palestinian colloquial Arabic, not MSA.")
      @user.save!

      generate(answer)

      assert_includes @chat.instructions, "Use Palestinian colloquial Arabic, not MSA."
    end

    test "without notes, or with notes for another language, none are added" do
      @user.set_dictionary_instructions(languages(:spanish), "Mexican Spanish.")
      @user.save!

      generate(answer)

      assert_not_includes @chat.instructions, "learner's own notes"
      assert_not_includes @chat.instructions, "Mexican Spanish."
    end
  end
end
