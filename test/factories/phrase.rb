FactoryBot.define do
  factory :phrase do    
    # Use fixture languages by default
    l1 { languages(:english) }
    l2 { languages(:spanish) }
    
    # Default timestamp
    timestamp { "00:01:30" }
    
    # Transient attributes for passing text content
    transient do
      text_l1 { "Hello world" }
      text_l2 { "Hola mundo" }
    end
    
    # Create text_l1 using nested attributes with default script
    text_l1_attributes do
      {
        language: l1,
        script_variants_attributes: [
          { script: l1.default_script, content: text_l1 }
        ]
      }
    end
    
    # Create text_l2 using nested attributes with default script
    text_l2_attributes do
      {
        language: l2,
        script_variants_attributes: [
          { script: l2.default_script, content: text_l2 }
        ]
      }
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