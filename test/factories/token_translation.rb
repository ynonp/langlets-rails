FactoryBot.define do
  factory :token_translation do
    # Associate with a phrase (uses phrase factory)
    phrase

    # Default word indices (must be valid for the phrase)
    l1_start_index { 0 }
    l1_end_index { 0 }
    l2_start_index { 0 }
    l2_end_index { 0 }

    # Default translation
    translation { "default translation" }

    # Trait for single word translations
    trait :single_word do
      l1_start_index { 0 }
      l1_end_index { 0 }
      translation { "palabra" }
    end

    # Trait for multi-word translations
    trait :multi_word do
      l1_start_index { 0 }
      l1_end_index { 1 }
      translation { "palabras múltiples" }
    end

    # Trait for second word
    trait :second_word do
      l1_start_index { 1 }
      l1_end_index { 1 }
      translation { "segunda" }
    end

    # Trait for invalid indices (for testing error cases)
    trait :invalid_indices do
      l1_start_index { nil }
      l1_end_index { nil }
      translation { "test" }
    end
    
    # Trait for out of bounds indices (for testing error cases)
    trait :out_of_bounds do
      l1_start_index { 999 }
      l1_end_index { 999 }
      translation { "test" }
    end
  end
end
