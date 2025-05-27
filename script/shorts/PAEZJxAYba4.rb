en = Language.find_by(iso_name: 'en')
es = Language.find_by(iso_name: 'es')
medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/shorts/PAEZJxAYba4')

phrases = [
  ["El mes pasado viajé a la playa con mi familia.", "Last month I traveled to the beach with my family.", "00:02"],
  ["Nadamos en el mar y tomamos el sol todo el día.", "We swam in the sea and sunbathed all day.", "00:05"],
  ["Por la noche cenamos en un restaurante frente al mar.", "At night we had dinner in a restaurant facing the sea.", "00:09"],
  ["Regresamos a casa muy tarde, pero felices.", "We returned home very late, but happy.", "00:13"]
]

Lesson.where(medium: medium).destroy_all
medium.phrases.destroy_all

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
l = Lesson.create!(medium: medium, slug: 'spanishcool')
l.start_timestamp = medium.phrases.ordered_by_timestamp.first.timestamp
l.end_timestamp = medium.phrases.ordered_by_timestamp.last.timestamp
l.save!

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases << medium.phrases.ordered_by_timestamp
l.activities << a

a = Activities::MatchPhrasesActivity.create!(lesson: l, text_header: 'Match each phrase to its translation', order: 2)
a.phrases << medium.phrases.ordered_by_timestamp.first(4)
l.activities << a

p1 = Phrase.find_by(text_l1: "El mes pasado viajé a la playa con mi familia.")
p2 = Phrase.find_by(text_l1: "Nadamos en el mar y tomamos el sol todo el día.")


TokenTranslation.create!(
  phrase: p1,
  l1_start_index: 22,
  l1_end_index: 30,
  translation: "the beach",
  questions: ["¿Adónde viajaste el mes pasado con tu familia?"],
  l2_start_index: 25,
  l2_end_index: 34
)

TokenTranslation.create!(
  phrase: p2,
  l1_start_index: 20,
  l1_end_index: 34,
  translation: "sunbathed",
  questions: ["¿Qué hicieron ustedes después de nadar en el mar?"],
  l2_start_index: 23,
  l2_end_index: 32
)

a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases << p1
a.phrases << p2
l.activities << a

a = Activities::FindAnswerActivity.create!(lesson: l, order: 4)
a.phrases << p1
a.phrases << p2
l.activities << a

a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases << p2
l.activities << a
  
