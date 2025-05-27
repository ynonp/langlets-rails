en = Language.find_by(iso_name: 'en')
es = Language.find_by(iso_name: 'es')
medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/shorts/FNCCyGbaWoM')

phrases = [
  ["Hola, muy buenas", "Hi", "00:00"],
  ["Hola, buenas, ¿qué tal? Quería un helado por fa.", "Hi, how is it going? I'd like an ice cream please.", "00:01"],
  ["¿de qué sabor?", "which flavour?", "00:03"],
  ["Eh... a ver... ¡de fresa!", "Ummm... let's see... strawberry!", "00:04"],
  ["Vale, muy bien, ¿en tarrina o en cono?", "Ok very well, in a tub or a cone?", "00:07"],
  ["En cucurucho", "In a cone", "00:10"],
  ["¿en cucurucho?", "in a cone?", "00:12"],
  ["Sí", "Yes", "00:13"],
  ["¿De qué tamaño? ¿Pequeño, mediano, grande?", "Which size? Small, medium, large?", "00:14"],
  ["Pues... mediano.", "Umm mediano.", "00:17"],
  ["¿Cuántas bolas quieres, una, dos...?", "How many scoops would you like? One, two...?", "00:19"],
  ["Ponme dos bolas por fa.", "Give me two scoops please.", "00:22"],
  ["¿Las dos de fresa?", "Both strawberry?", "00:24"],
  ["No, mira, me pones: una bola de fresa y otra de chocolate.", "No, look, give me one strawberry scoop and one chocolate.", "00:25"],
  ["¡Me encanta el chocolate!", "I love chocolate!", "00:32"],
  ["Muy bien, pues aquí tienes. Son tres euros.", "Very well, here you go then. It's 3€.", "00:33"],
  ["¿En efectivo o con tarjeta?", "Card or cash?", "00:36"],
  ["Con tarjeta por fa, es que no tengo efectivo.", "Card please, I don't have any cash.", "00:38"]
]

Lesson.where(medium: medium).destroy_all
medium.phrases.destroy_all

phrases.each do |text_l1, text_l2, timestamp|
  Phrase.create!(
    l1: es,
    l2: en,
    text_l1: text_l1,
    text_l2: text_l2,
    timestamp: timestamp,
    medium: medium
  )
end

medium.phrases.reload
l = Lesson.create!(medium: medium, slug: 'patryruiz')
l.start_timestamp = medium.phrases.ordered_by_timestamp.first.timestamp
l.end_timestamp = medium.phrases.ordered_by_timestamp.last.timestamp
l.save!

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases << medium.phrases.ordered_by_timestamp
l.activities << a

a = Activities::MatchPhrasesActivity.create!(lesson: l, text_header: 'Match each phrase to its translation', order: 2)
a.phrases << medium.phrases.ordered_by_timestamp.first(4)
l.activities << a

# Phrase.find_by(text_l1: '¿Puedes hablar más despacio?').create_mappings
# Phrase.find_by(text_l1: '¿Qué recomiendas?').create_mappings
# Phrase.find_by(text_l1: '¿A qué hora...?').create_mappings
# Phrase.find_by(text_l1: 'Necesito ayuda.').create_mappings
# Phrase.find_by(text_l1: '¿Puedo usar el baño?').create_mappings
# Phrase.find_by(text_l1: 'La cuenta, por favor.').create_mappings
# Phrase.find_by(text_l1: 'No hay problema.').create_mappings

p1 = Phrase.find_by(text_l1: 'Ponme dos bolas por fa.')
p2 = Phrase.find_by(text_l1: '¿En efectivo o con tarjeta?')


TokenTranslation.create!(
  phrase: p1,
  l1_start_index: 0,
  l1_end_index: 5,
  translation: "Give me",
  questions: [],
  l2_start_index: 0,
  l2_end_index: 7
)

TokenTranslation.create!(
  phrase: p2,
  l1_start_index: 19,
  l1_end_index: 26,
  translation: "Card",
  questions: [],
  l2_start_index: 0,
  l2_end_index: 4
)

a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases << p1
a.phrases << p2
a.token_translations << p1.token_translations
a.token_translations << p2.token_translations
l.activities << a

a = Activities::MatchPhrasesActivity.create!(lesson: l, text_header: 'Match each phrase to its translation', order: 4)
a.phrases << medium.phrases.ordered_by_timestamp.first(8).last(4)
l.activities << a


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases << p2
l.activities << a

