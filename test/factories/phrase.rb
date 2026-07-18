FactoryBot.define do
  factory :phrase do
    # Use fixture languages by default
    l1 { languages(:english) }
    transient do
      l2 { languages(:spanish) }
      text_l2 { "Hola mundo" }
    end
    
    # Default timestamp
    timestamp { "00:01:30" }
    
    text_l1 { "Hello world" }

    after(:create) do |phrase, evaluator|
      phrase.phrase_translations.create!(language: evaluator.l2, text: evaluator.text_l2)
      Current.translation_language ||= evaluator.l2
    end
    
    # Trait for Hebrew phrases
    trait :hebrew do
      l2 { languages(:hebrew) }
      text_l2 { "שלום עולם" }
    end
    
    # Trait for Arabic phrases
    trait :arabic do
      l2 { languages(:arabic) }
      text_l2 { "مرحبا بالعالم" }
    end
    
    # Trait for French phrases
    trait :french do
      l2 { languages(:french) }
      text_l2 { "Bonjour le monde" }
    end
  end
end
