en = Language.find_by(iso_name: 'en')
es = Language.find_by(iso_name: 'es')
medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/shorts/oCHLQSi3L_8')

phrases = [
  ['¿Cómo estás?', 'How are you?', '00:03'],
  ['Mucho gusto.', 'Nice to meet you.', '00:07'],
  ['¿Dónde está...?', 'Where is...?', '00:10'],
  ['No entiendo.', 'I don’t understand.', '00:11'],
  ['¿Puedes hablar más despacio?', 'Can you speak more slowly?', '00:14'],
  ['Gracias.', 'Thank you.', '00:19'],
  ['Por favor.', 'Please.', '00:22'],
  ['¿Cuánto cuesta?', 'How much does it cost?', '00:24'],
  ['Me llamo...', 'My name is...', '00:27'],
  ['¿Qué recomiendas?', 'What do you recommend?', '00:30'],
  ['¿Hablas inglés?', 'Do you speak English?', '00:33'],
  ['Lo siento.', 'I’m sorry.', '00:36'],
  ['¿A qué hora...?', 'At what time...?', '00:39'],
  ['Necesito ayuda.', 'I need help.', '00:42'],
  ['¿Puedo usar el baño?', 'Can I use the bathroom?', '00:45'],
  ['La cuenta, por favor.', 'The check, please.', '00:48'],
  ['Buen provecho.', 'Enjoy your meal.', '00:51'],
  ['¿Cómo se dice...?', 'How do you say...?', '00:54'],
  ['No hay problema.', 'No problem.', '00:57']
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
l = Lesson.create!(medium: medium, slug: 'speakspanishfaster')
l.start_timestamp = medium.phrases.order(timestamp: :asc).first.timestamp
l.end_timestamp = medium.phrases.order(timestamp: :desc).first.timestamp
l.save!

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1, phrases: medium.phrases)
a.phrases << medium.phrases
l.activities << a
