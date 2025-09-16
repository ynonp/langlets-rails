require 'test_helper'
require 'active_support/concern'

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

  test 'parses Arabic RTL text with multi-word mappings' do
    translations = @phrase2.add_tokens_from(@block2).token_translations
    assert_equal 5, translations.length

    first = translations[0]
    assert_equal 2, first[:phrase_id]
    assert_equal 0, first[:l1_start_index]
    assert_equal 0, first[:l1_end_index]
    assert_equal 0, first[:l2_start_index]
    assert_equal 0, first[:l2_end_index]
    assert_equal 'These', first[:translation]

    second = translations[1]
    assert_equal 1, second[:l1_start_index]
    assert_equal 1, second[:l1_end_index]
    assert_equal 1, second[:l2_start_index]
    assert_equal 2, second[:l2_end_index]
    assert_equal 'are stories', second[:translation]

    third = translations[2]
    assert_equal 2, third[:l1_start_index]
    assert_equal 2, third[:l1_end_index]
    assert_equal 3, third[:l2_start_index]
    assert_equal 3, third[:l2_end_index]
    assert_equal 'about', third[:translation]

    fourth = translations[3]
    assert_equal 3, fourth[:l1_start_index]
    assert_equal 3, fourth[:l1_end_index]
    assert_equal 4, fourth[:l2_start_index]
    assert_equal 4, fourth[:l2_end_index]
    assert_equal 'people', fourth[:translation]

    fifth = translations[4]
    assert_equal 4, fifth[:l1_start_index]
    assert_equal 4, fifth[:l1_end_index]
    assert_equal 5, fifth[:l2_start_index]
    assert_equal 5, fifth[:l2_end_index]
    assert_equal 'who', fifth[:translation]
  end

  test 'parse block in Arabic' do
    line = "[كان ييجي] لعنده زباين من كل الأنحاء، => customers [would come] to him from all over,"
    p = Phrase.new(text_l1: "كان ييجي لعنده زباين من كل الأنحاء،", text_l2: "Customers would come to him from all over,")
    p.send(:process_line, line)

    pp p
    pp p.token_translations
  end

  test 'parse line from flowers' do
    p = Phrase.new(text_l1: "'til we weren't", text_l2: "עד שכבר לא")
    p.send(:process_line, "['til] we weren't => [עד שכבר] לא")
    token = p.token_translations.first

    assert_equal 0, token.l1_start_index
    assert_equal 0, token.l1_end_index
    assert_equal 0, token.l2_start_index
    assert_equal 1, token.l2_end_index
  end

  test 'parses spanish text with multi-word mappings' do
    translations = @phrase.add_tokens_from(@block).token_translations
    assert_equal 5, translations.length

    first = translations[0]
    assert_equal 1, first[:phrase_id]
    assert_equal 0, first[:l1_start_index]
    assert_equal 0, first[:l1_end_index]
    assert_equal 0, first[:l2_start_index]
    assert_equal 1, first[:l2_end_index]
    assert_equal 'I thought', first[:translation]

    second = translations[1]
    assert_equal 2, second[:l1_start_index]
    assert_equal 2, second[:l1_end_index]
    assert_equal 2, second[:l2_start_index]
    assert_equal 3, second[:l2_end_index]
    assert_equal 'it was', second[:translation]

    third = translations[2]
    assert_equal 3, third[:l1_start_index]
    assert_equal 3, third[:l1_end_index]
    assert_equal 4, third[:l2_start_index]
    assert_equal 4, third[:l2_end_index]
    assert_equal 'a', third[:translation]


    fourth = translations[3]
    assert_equal 4, fourth[:l1_start_index]
    assert_equal 4, fourth[:l1_end_index]
    assert_equal 5, fourth[:l2_start_index]
    assert_equal 5, fourth[:l2_end_index]
    assert_equal 'good', fourth[:translation]

    fifth = translations[4]
    assert_equal 5, fifth[:l1_start_index]
    assert_equal 5, fifth[:l1_end_index]
    assert_nil fifth[:l2_start_index]
    assert_equal 'moment, time', fifth[:translation]
  end

  test 'ignores comments and empty lines' do
    block_with_comment = @block + "\n\nIgnored line # comment"
    translations = @phrase.add_tokens_from(block_with_comment).token_translations
    assert_equal 5, translations.length
  end

  test 'handles single word tokens' do
    simple_block = "Pensé que [era] un buen momento => I thought [it was] a good time"
    translations = @phrase.add_tokens_from(simple_block).token_translations
    assert_equal 1, translations.length
    assert_equal [2,2], [translations[0][:l1_start_index], translations[0][:l1_end_index]]
  end

  test 'skips invalid lines' do
    invalid_block = "Invalid line without =>\n[Pensé] que era un buen momento => [I thought] it was a good time"
    translations = @phrase.add_tokens_from(invalid_block).token_translations
    assert_equal 1, translations.length
  end

  test 'returns empty for blank input' do
    assert_equal [], @phrase.add_tokens_from('').token_translations
    assert_equal [], @phrase.add_tokens_from(nil).token_translations
  end
end

