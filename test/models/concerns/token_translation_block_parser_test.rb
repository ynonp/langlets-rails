require "test_helper"
require "active_support/concern"

class TokenTranslationBlockParserTest < ActiveSupport::TestCase
  setup do
    @phrase = Phrase.new(text_l1: "Pensé que era un buen momento", text_l2: "I thought it was a good time", id: 1)
    @phrase2 = Phrase.new(text_l1: "هاي قصص عن الناس اللي", text_l2: "These are stories about people who", id: 2)

    @block = <<~END
[Pensé] que era un buen momento => [I thought] it was a good time
Pensé que [era] un buen momento => I thought [it was] a good time
Pensé que era [un] buen momento => I thought it was [a] good time
Pensé que era un [buen] momento => I thought it was a [good] time
Pensé que era un buen [momento] => moment, time
    END

    @block2 = <<~END
[هاي] قصص عن الناس اللي => [These] are stories about people who
هاي [قصص] عن الناس اللي => These [are stories] about people who
هاي قصص [عن] الناس اللي => These are stories [about] people who
هاي قصص عن [الناس] اللي => These are stories about [people] who
هاي قصص عن الناس [اللي] => These are stories about people [who]
    END
  end

  test "parses Arabic RTL text with multi-word mappings" do
    translations = @phrase2.add_tokens_from(@block2).token_translations
    assert_equal 5, translations.length

    first = translations[0]
    assert_equal 2, first[:phrase_id]
    assert_equal 0, first[:l1_start_index]
    assert_equal 2, first[:l1_end_index]
    assert_equal 0, first[:l2_start_index]
    assert_equal 4, first[:l2_end_index]
    assert_equal "These", first[:translation]

    second = translations[1]
    assert_equal 4, second[:l1_start_index]
    assert_equal 6, second[:l1_end_index]
    assert_equal 6, second[:l2_start_index]
    assert_equal 16, second[:l2_end_index]
    assert_equal "are stories", second[:translation]

    third = translations[2]
    assert_equal 8, third[:l1_start_index]
    assert_equal 9, third[:l1_end_index]
    assert_equal 18, third[:l2_start_index]
    assert_equal 22, third[:l2_end_index]
    assert_equal "about", third[:translation]

    fourth = translations[3]
    assert_equal 11, fourth[:l1_start_index]
    assert_equal 15, fourth[:l1_end_index]
    assert_equal 24, fourth[:l2_start_index]
    assert_equal 29, fourth[:l2_end_index]
    assert_equal "people", fourth[:translation]

    fifth = translations[4]
    assert_equal 17, fifth[:l1_start_index]
    assert_equal 20, fifth[:l1_end_index]
    assert_equal 31, fifth[:l2_start_index]
    assert_equal 33, fifth[:l2_end_index]
    assert_equal "who", fifth[:translation]
  end

  test "parse block in Arabic" do
    line = "كان ييجي لعنده زباين من [كل الأنحاء،] => customers would come to him from [all over,]"
    p = Phrase.new(text_l1: "كان ييجي لعنده زباين من كل الأنحاء،", text_l2: "Customers would come to him from all over,")
    p.send(:process_line, line)

    assert p.token_translations.all? { |t| t.valid? }
  end

  test "spanish line with question mark" do
    p = Phrase.new("text_l1"=>"¿Quién es?", "text_l2"=>"Who is it?")
    block = <<~END
    [¿Quién] es? => [Who] is it?
    ¿Quién [es?] => Who [is it?]
    END
    p.add_tokens_from(block)
    assert_equal 2, p.token_translations.size
  end

  test "multiple translations with overlapping tokens" do
    p = Phrase.new(text_l1: "לא נגמר לנו היום", text_l2: "لم ينتهِ يومنا بعد", id: 999888)
    block = <<~END
    [לא נגמר לנו היום] => [لم ينتهِ يومna بعد]
    [לא נגמר] לנו היום => [لم ينتهِ] يومنا بعد
    לא נגמר [לנו היום] => لم ينتهِ [يومنا] بعد
    END
    p.add_tokens_from(block)
    # Note: remove_duplicate_translations keeps the smallest span for each character position
    # This results in 3 tokens because:
    # - Token 0-15 (chars 0-15) covers the full sentence
    # - Token 0-6 (chars 0-6) is a smaller span for positions 0-6
    # - Token 8-15 (chars 8-15) is a smaller span for positions 8-15
    assert_equal 3, p.token_translations.size
    # The order depends on how they're stored after deduplication
    assert_equal 0, p.token_translations[0].l1_start_index
    assert_equal 15, p.token_translations[0].l1_end_index

    assert_equal 0, p.token_translations[1].l1_start_index
    assert_equal 6, p.token_translations[1].l1_end_index

    assert_equal 8, p.token_translations[2].l1_start_index
    assert_equal 15, p.token_translations[2].l1_end_index
  end

  test "parse line from flowers" do
    p = Phrase.new(text_l1: "'til we weren't", text_l2: "עד שכבר לא")
    p.send(:process_line, "['til] we weren't => [עד שכבר] לא")
    token = p.token_translations.first

    assert_equal 0, token.l1_start_index
    assert_equal 3, token.l1_end_index
    assert_equal 0, token.l2_start_index
    assert_equal 6, token.l2_end_index
  end

  test "parses spanish text with multi-word mappings" do
    translations = @phrase.add_tokens_from(@block).token_translations
    assert_equal 5, translations.length

    first = translations[0]
    assert_equal 1, first[:phrase_id]
    assert_equal 0, first[:l1_start_index]
    assert_equal 4, first[:l1_end_index]
    assert_equal 0, first[:l2_start_index]
    assert_equal 8, first[:l2_end_index]
    assert_equal "I thought", first[:translation]

    second = translations[1]
    assert_equal 10, second[:l1_start_index]
    assert_equal 12, second[:l1_end_index]
    assert_equal 10, second[:l2_start_index]
    assert_equal 15, second[:l2_end_index]
    assert_equal "it was", second[:translation]

    third = translations[2]
    assert_equal 14, third[:l1_start_index]
    assert_equal 15, third[:l1_end_index]
    assert_equal 17, third[:l2_start_index]
    assert_equal 17, third[:l2_end_index]
    assert_equal "a", third[:translation]


    fourth = translations[3]
    assert_equal 17, fourth[:l1_start_index]
    assert_equal 20, fourth[:l1_end_index]
    assert_equal 19, fourth[:l2_start_index]
    assert_equal 22, fourth[:l2_end_index]
    assert_equal "good", fourth[:translation]

    fifth = translations[4]
    assert_equal 22, fifth[:l1_start_index]
    assert_equal 28, fifth[:l1_end_index]
    assert_nil fifth[:l2_start_index]
    assert_equal "moment, time", fifth[:translation]
  end

  test "ignores comments and empty lines" do
    block_with_comment = @block + "\n\nIgnored line # comment"
    translations = @phrase.add_tokens_from(block_with_comment).token_translations
    assert_equal 5, translations.length
  end

  test "handles single word tokens" do
    simple_block = "Pensé que [era] un buen momento => I thought [it was] a good time"
    translations = @phrase.add_tokens_from(simple_block).token_translations
    assert_equal 1, translations.length
    assert_equal [ 10, 12 ], [ translations[0][:l1_start_index], translations[0][:l1_end_index] ]
  end

  test "skips invalid lines" do
    invalid_block = "Invalid line without =>\n[Pensé] que era un buen momento => [I thought] it was a good time"
    translations = @phrase.add_tokens_from(invalid_block).token_translations
    assert_equal 1, translations.length
  end

  test "returns empty for blank input" do
    assert_equal [], @phrase.add_tokens_from("").token_translations
    assert_equal [], @phrase.add_tokens_from(nil).token_translations
  end

  test "handles partial l1 sentence with missing prefix" do
    phrase = Phrase.new(
      text_l1: "Alors j'ai demandé à Maud si elle avait un copain.",
      text_l2: "So I asked Maud if she had a boyfriend."
    )
    block = <<~END
    [Alors] j'ai demandé à Maud si elle avait un copain. => [So] I asked Maud if she had a boyfriend.
    [j']ai demandé à Maud si elle avait un copain. => [I] asked Maud if she had a boyfriend.
    j'[ai demandé] à Maud si elle avait un copain. => I [asked] Maud if she had a boyfriend.
    END
    translations = phrase.add_tokens_from(block).token_translations

    assert_equal 3, translations.length

    first = translations[0]
    assert_equal 0, first[:l1_start_index]
    assert_equal 4, first[:l1_end_index]
    assert_equal "So", first[:translation]

    second = translations[1]
    assert_equal 6, second[:l1_start_index]
    assert_equal 7, second[:l1_end_index]
    assert_equal "I", second[:translation]

    third = translations[2]
    assert_equal 8, third[:l1_start_index]
    assert_equal 17, third[:l1_end_index]
    assert_equal "asked", third[:translation]
  end

  test "handles partial l1 sentence with missing suffix" do
    phrase = Phrase.new(
      text_l1: "Alors j'ai demandé à Maud si elle avait un copain.",
      text_l2: "So I asked Maud if she had a boyfriend."
    )
    block = "[Alors] j'ai demandé à Maud => [So] I asked Maud"
    translations = phrase.add_tokens_from(block).token_translations

    assert_equal 1, translations.length
    assert_equal 0, translations[0][:l1_start_index]
    assert_equal 4, translations[0][:l1_end_index]
    assert_equal "So", translations[0][:translation]
  end

  test "handles partial l1 in middle position" do
    phrase = Phrase.new(
      text_l1: "Alors j'ai demandé à Maud si elle avait un copain.",
      text_l2: "So I asked Maud if she had a boyfriend."
    )
    block = "j'ai demandé à [Maud] si elle avait un copain. => I asked [Maud] if she had a boyfriend."
    translations = phrase.add_tokens_from(block).token_translations

    assert_equal 1, translations.length
    assert_equal 21, translations[0][:l1_start_index]
    assert_equal 24, translations[0][:l1_end_index]
    assert_equal "Maud", translations[0][:translation]
  end

  test "keeps non-overlapping tokens from multiple lines" do
    phrase = Phrase.new(
      text_l1: "J'ai fait comme si je l'avais pas vu,",
      text_l2: "I pretended I hadn't seen it,"
    )
    block = <<~END
    [J'ai fait comme si] je l'avais pas vu, => [I pretended] I hadn't seen it,
    J'ai fait comme si [je] l'avais pas vu, => I pretended [I] hadn't seen it,
    J'ai fait comme si je [l']avais pas vu, => I pretended I hadn't seen [it],
    END
    translations = phrase.add_tokens_from(block).token_translations

    assert_equal 3, translations.length

    first = translations.find { |t| t.l1_start_index == 0 }
    assert_not_nil first
    assert_equal 17, first.l1_end_index
    assert_equal "I pretended", first.translation

    second = translations.find { |t| t.l1_start_index == 19 }
    assert_not_nil second
    assert_equal 20, second.l1_end_index
    assert_equal "I", second.translation

    third = translations.find { |t| t.l1_start_index == 22 }
    assert_not_nil third
    assert_equal 23, third.l1_end_index
    assert_equal "it,", third.translation
  end

  test "fixes arabic alignment when AI adds spaces after و" do
    phrase = Phrase.new(
      text_l1: "وكل شي منيح معكن.",
      text_l2: "And everything is good with you."
    )
    phrase.l1 = languages(:arabic)

    block = <<~END
      [و] كل شي منيح معكن. => [And] everything is good with you.
      و [كل شي] منيح معكن. => And [everything] is good with you.
      و كل شي [منيح] معكن. => And everything is [good] with you.
      و كل شي منيح [معكن]. => And everything is good [with you].
    END

    translations = phrase.add_tokens_from(block).token_translations
    assert_equal 4, translations.length

    # [و] => character index 0..0 in "وكل شي منيح معكن."
    waw_token = translations.find { |t| t.l1_start_index == 0 && t.l1_end_index == 0 }
    assert_not_nil waw_token, "Expected token for [و] at index 0"
    assert_equal "And", waw_token.translation

    # [كل شي] => characters 1..5 in "وكل شي منيح معكن."
    koll_shi_token = translations.find { |t| t.l1_start_index == 1 && t.l1_end_index == 5 }
    assert_not_nil koll_shi_token, "Expected token for [كل شي] at indices 1..5"
    assert_equal "everything", koll_shi_token.translation

    # [منيح] => characters 7..10 in "وكل شي منيح معكن."
    mnih_token = translations.find { |t| t.l1_start_index == 7 && t.l1_end_index == 10 }
    assert_not_nil mnih_token, "Expected token for [منيح] at indices 7..10"
    assert_equal "good", mnih_token.translation

    # [معكن] => characters 12..15 in "وكل شي منيح معكن."
    ma3kon_token = translations.find { |t| t.l1_start_index == 12 && t.l1_end_index == 15 }
    assert_not_nil ma3kon_token, "Expected token for [معكن] at indices 12..16"
    assert_equal "with you.", ma3kon_token.translation
  end
end
