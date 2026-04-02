FactoryBot.define do
  factory :token_translation do
    phrase

    l1_start_index { 0 }
    l1_end_index { 4 }
    l2_start_index { 0 }
    l2_end_index { 7 }
    index_type { :character_index }

    translation { "default translation" }

    trait :single_word do
      l1_start_index { 0 }
      l1_end_index { 4 }
      translation { "palabra" }
    end

    trait :multi_word do
      l1_start_index { 0 }
      l1_end_index { 12 }
      translation { "palabras múltiples" }
    end

    trait :invalid_indices do
      l1_start_index { nil }
      l1_end_index { nil }
      translation { "test" }
    end

    trait :out_of_bounds do
      l1_start_index { 999 }
      l1_end_index { 999 }
      translation { "test" }
    end

    trait :word_index_format do
      index_type { :word_index }
      l1_start_index { 0 }
      l1_end_index { 0 }
      l2_start_index { 0 }
      l2_end_index { 0 }
    end
  end
end
