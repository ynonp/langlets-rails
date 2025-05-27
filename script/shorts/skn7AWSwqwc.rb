en = Language.find_by(iso_name: 'en')
es = Language.find_by(iso_name: 'es')
medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/shorts/skn7AWSwqwc')

phrases = [
  ["Vamos a practicar", "Let's practice", "00:00"],
  ["hablar español en voz alta", "speaking Spanish out loud", "00:01"],
  ["en un juego de roles.", "in a role-playing game.", "00:03"],
  ["Tú y yo estamos", "You and I are", "00:06"],
  ["en la parada del autobús.", "at the bus stop.", "00:07"],
  ["El autobús está retrasado", "The bus is late", "00:09"],
  ["y vamos a tener", "and we'll have", "00:11"],
  ["una pequeña conversación.", "a little conversation.", "00:12"],
  ["Yo soy NARANJA", "I'm ORANGE", "00:14"],
  ["Y tú eres BLANCO", "And you're WHITE", "00:16"],
  ["Hola, disculpa,", "Hi, excuse me,", "00:18"],
  ["¿has estado esperando", "have you been waiting", "00:19"],
  ["mucho tiempo?", "long?", "00:20"],
  ["Sí, llevo aquí", "Yes, I've been here", "00:22"],
  ["unos diez minutos.", "for about ten minutes.", "00:24"],
  ["Creo que el autobús", "I think the bus", "00:27"],
  ["está retrasado.", "is delayed.", "00:29"],
  ["¡Qué pena!", "What a shame!", "00:31"],
  ["Espero no llegar", "I hope I don't get", "00:32"],
  ["tarde al trabajo.", "to work late.", "00:33"],
  ["Sí, espero que", "Yeah, I hope", "00:35"],
  ["no tarde mucho más.", "it doesn't take much longer.", "00:37"],
  ["¿Tú dónde vas?", "Where are you going?", "00:41"],
  ["Yo voy al centro.", "I'm going to the city centre.", "00:43"],
  ["¿Y tú?", "And you?", "00:44"],
  ["Yo también, ¡qué casualidad!", "Me too, what a coincidence!", "00:46"],
  ["Mira,", "Look,", "00:49"],
  ["ahí está viniendo.", "there it is coming.", "00:50"],
  ["¡Menos mal!", "Thank goodness!", "00:53"],
  ["Bueno, nos vemos al rato.", "Well, see you later.", "00:55"],
  ["¿Te gustó?", "Did you like it?", "00:57"],
  ["Dime en los comentarios.", "Tell me in the comments.", "00:58"],
  ["Sígueme para más truquitos", "follow me for more tips", "00:59"],
  ["de cómo mejorar tu español.", "on how to improve your Spanish.", "01:01"]
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
l = Lesson.create!(medium: medium, slug: 'holaspanish')
l.start_timestamp = medium.phrases.ordered_by_timestamp.first.timestamp
l.end_timestamp = medium.phrases.ordered_by_timestamp.last.timestamp
l.save!

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases << medium.phrases.ordered_by_timestamp
l.activities << a

a = Activities::MatchPhrasesActivity.create!(lesson: l, text_header: 'Match each phrase to its translation', order: 2)
a.phrases << medium.phrases.ordered_by_timestamp.first(4)
l.activities << a

p1 = Phrase.find_by(text_l1: 'El autobús está retrasado')
p2 = Phrase.find_by(text_l1: 'Yo voy al centro.')

TokenTranslation.create!(
  phrase: p1,
  l1_start_index: 16,
  l1_end_index: 25,
  translation: "late",
  questions: ["¿Qué problema tiene el autobús con respecto al horario?"],
  l2_start_index: 11,
  l2_end_index: 15
)

TokenTranslation.create!(
  phrase: p2,
  l1_start_index: 3,
  l1_end_index: 6,
  translation: "I'm going",
  questions: ["¿Adónde vas tú?"],
  l2_start_index: 0,
  l2_end_index: 8, 
)

a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases << p1
a.phrases << p2
l.activities << a

a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases << p2
l.activities << a
