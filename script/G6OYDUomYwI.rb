en = Language.find_by(iso_name: 'en')
es = Language.find_by(iso_name: 'es')
medium_url = 'https://www.youtube.com/watch?v=ZowZ3GgL2D4' # Natalia Oreiro - Cambio Dolor
medium = Medium.find_or_create_by!(url: medium_url)

phrases_data = [
  ["Juraría que no sé bien lo que quiero", "I would swear that I don't quite know what I want", "00:15"],
  ["Pero sé que moriría si me quedo en la mitad", "But I know I would die if I stay in the middle", "00:20"],
  ["Por eso vuelo a otro sendero", "That's why I fly to another path", "00:25"],
  ["Para conocer el mundo de verdad", "To know the real world", "00:30"],
  ["Aún no es tarde, pero así me estoy sintiendo", "It's not late yet, but that's how I'm feeling", "00:35"],
  ["Y aparecen tantos miedos que no me dejan pensar", "And so many fears appear that don't let me think", "00:40"],
  ["Y tengo sueños de amores nuevos", "And I have dreams of new loves", "00:45"],
  ["Y me cuesta imaginar lo que vendrá", "And I find it hard to imagine what will come", "00:50"],
  ["Cambio dolor por libertad", "I trade pain for freedom", "00:54"],
  ["Cambio heridas por un sueño que me ayude a continuar", "I trade wounds for a dream that helps me continue", "01:00"],
  ["Cambio dolor por felicidad", "I trade pain for happiness", "01:04"],
  ["Que la suerte sea suerte y no algo que no he de alcanzar", "May luck be luck and not something I can't reach", "01:09"],
  ["Juraría que no sé bien lo que quiero", "I would swear that I don't quite know what I want", "01:27"],
  ["Pero sé que moriría si me quedo en la mitad", "But I know I would die if I stay in the middle", "01:32"],
  ["Por eso vuelo a otro sendero", "That's why I fly to another path", "01:37"],
  ["Para conocer el mundo de verdad", "To know the real world", "01:42"],
  ["Aún no es tarde, pero así me estoy sintiendo", "It's not late yet, but that's how I'm feeling", "01:47"],
  ["Y aparecen tantos miedos que no me dejan pensar", "And so many fears appear that don't let me think", "01:52"],
  ["Y tengo sueños de amores nuevos", "And I have dreams of new loves", "01:57"],
  ["Y me cuesta imaginar lo que vendrá", "And I find it hard to imagine what will come", "02:02"],
  ["Cambio dolor por libertad", "I trade pain for freedom", "02:06"],
  ["Cambio heridas por un sueño que me ayude a continuar", "I trade wounds for a dream that helps me continue", "02:12"],
  ["Cambio dolor por felicidad", "I trade pain for happiness", "02:17"],
  ["Que la suerte sea suerte y no algo que no he de alcanzar", "May luck be luck and not something I can't reach", "02:22"],
  ["Cambio dolor por libertad", "I trade pain for freedom", "02:27"],
  ["Cambio heridas por un sueño que me ayude a continuar", "I trade wounds for a dream that helps me continue", "02:32"],
  ["Cambio dolor por felicidad", "I trade pain for happiness", "02:37"],
  ["Que la suerte sea suerte y no algo que no he de alcanzar", "May luck be luck and not something I can't reach", "02:42"],
  ["Y tengo sueños de amores nuevos", "And I have dreams of new loves", "03:09"],
  ["Y me cuesta imaginar lo que vendrá", "And I find it hard to imagine what will come", "03:14"],
  ["Cambio dolor por libertad", "I trade pain for freedom", "03:18"],
  ["Cambio heridas por un sueño que me ayude a continuar", "I trade wounds for a dream that helps me continue", "03:23"],
  ["Cambio dolor por felicidad", "I trade pain for happiness", "03:28"],
  ["Que la suerte sea suerte y no algo que no he de alcanzar", "May luck be luck and not something I can't reach", "03:33"],
  ["Cambio dolor por libertad", "I trade pain for freedom", "03:39"],
  ["Cambio heridas por un sueño que me ayude a continuar", "I trade wounds for a dream that helps me continue", "03:44"],
  ["Cambio dolor por felicidad", "I trade pain for happiness", "03:49"],
  ["Que la suerte sea suerte y no algo que no he de alcanzar", "May luck be luck and not something I can't reach", "03:54"]
]

course_name = 'Cambio Dolor'
course_slug = 'cambio-dolor'
c = Course.find_or_create_by!(slug: course_slug) do |course|
  course.name = course_name
  course.main_media_url = medium_url
end
c.lessons.destroy_all
medium.phrases.destroy_all # Clear phrases for this specific medium if re-running

phrases = phrases_data.map do |text_l1, text_l2, timestamp|
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

# --- Token Translations ---

# Phrase 0: Juraría que no sé bien lo que quiero
phrase = phrases[0]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 7) { |t| t.translation = "I would swear"; t.l2_start_index = 0; t.l2_end_index = 13 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 8, l1_end_index: 11) { |t| t.translation = "that"; t.l2_start_index = 14; t.l2_end_index = 18 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 12, l1_end_index: 22) { |t| t.translation = "I don't quite know"; t.questions = ["¿Qué no sabes?"], t.similar_sound = ["lo sé bien"]; t.l2_start_index = 19; t.l2_end_index = 37 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 23, l1_end_index: 29) { |t| t.translation = "what"; t.l2_start_index = 38; t.l2_end_index = 42 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 30, l1_end_index: 36) { |t| t.translation = "I want"; t.questions = ["¿Qué quieres?"], t.similar_sound = ["muero"]; t.l2_start_index = 43; t.l2_end_index = 49 }

# Phrase 1: Pero sé que moriría si me quedo en la mitad
phrase = phrases[1]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 4) { |t| t.translation = "But"; t.l2_start_index = 0; t.l2_end_index = 3 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 5, l1_end_index: 16) { |t| t.translation = "I know I would die"; t.l2_start_index = 4; t.l2_end_index = 22 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 17, l1_end_index: 19) { |t| t.translation = "if"; t.l2_start_index = 23; t.l2_end_index = 25 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 20, l1_end_index: 28) { |t| t.translation = "I stay"; t.questions = ["¿Dónde te quedas?"], t.similar_sound = ["me muedo"]; t.l2_start_index = 26; t.l2_end_index = 32 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 29, l1_end_index: 39) { |t| t.translation = "in the middle"; t.l2_start_index = 33; t.l2_end_index = 46 }

# Phrase 2: Por eso vuelo a otro sendero
phrase = phrases[2]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 7) { |t| t.translation = "That's why"; t.l2_start_index = 0; t.l2_end_index = 9 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 8, l1_end_index: 13) { |t| t.translation = "I fly"; t.questions = ["¿Adónde vuelas?"], t.similar_sound = ["duelo"]; t.l2_start_index = 10; t.l2_end_index = 15 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 14, l1_end_index: 27) { |t| t.translation = "to another path"; t.l2_start_index = 16; t.l2_end_index = 31 }

# Phrase 3: Para conocer el mundo de verdad
phrase = phrases[3]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 12) { |t| t.translation = "To know"; t.similar_sound = ["para convencer"], t.questions = ["¿Para qué vuelas a otro sendero?"]; t.l2_start_index = 0; t.l2_end_index = 7 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 13, l1_end_index: 21) { |t| t.translation = "the real world"; t.l2_start_index = 8; t.l2_end_index = 22 } # "el mundo de verdad" -> "the real world"
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 13, l1_end_index: 15) { |t| t.translation = "the"; t.l2_start_index = 8; t.l2_end_index = 11 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 16, l1_end_index: 21) { |t| t.translation = "world"; t.l2_start_index = 12; t.l2_end_index = 17 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 22, l1_end_index: 31) { |t| t.translation = "real"; t.l2_start_index = 18; t.l2_end_index = 22 } # "de verdad" as "real"

# Phrase 4: Aún no es tarde, pero así me estoy sintiendo
phrase = phrases[4]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 13) { |t| t.translation = "It's not late yet"; t.similar_sound = ["aun no es arte"]; t.l2_start_index = 0; t.l2_end_index = 17 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 15, l1_end_index: 19) { |t| t.translation = "but"; t.l2_start_index = 19; t.l2_end_index = 22 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 20, l1_end_index: 42) { |t| t.translation = "that's how I'm feeling"; t.questions = ["¿Cómo te sientes?"], t.similar_sound = ["así me estoy mintiendo"]; t.l2_start_index = 23; t.l2_end_index = 45 }

# Phrase 5: Y aparecen tantos miedos que no me dejan pensar
phrase = phrases[5]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 1) { |t| t.translation = "And"; t.l2_start_index = 0; t.l2_end_index = 3 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 2, l1_end_index: 22) { |t| t.translation = "so many fears appear"; t.questions = ["¿Qué aparece?"], t.similar_sound = ["parecen tantos medios"]; t.l2_start_index = 4; t.l2_end_index = 25 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 23, l1_end_index: 26) { |t| t.translation = "that"; t.l2_start_index = 26; t.l2_end_index = 30 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 27, l1_end_index: 45) { |t| t.translation = "don't let me think"; t.l2_start_index = 31; t.l2_end_index = 49 }

# Phrase 6: Y tengo sueños de amores nuevos
phrase = phrases[6]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 1) { |t| t.translation = "And"; t.l2_start_index = 0; t.l2_end_index = 3 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 2, l1_end_index: 15) { |t| t.translation = "I have dreams"; t.questions = ["¿Qué tienes?"], t.similar_sound = ["tengo dueños"]; t.l2_start_index = 4; t.l2_end_index = 17 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 16, l1_end_index: 32) { |t| t.translation = "of new loves"; t.l2_start_index = 18; t.l2_end_index = 30 }

# Phrase 7: Y me cuesta imaginar lo que vendrá
phrase = phrases[7]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 1) { |t| t.translation = "And"; t.l2_start_index = 0; t.l2_end_index = 3 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 2, l1_end_index: 21) { |t| t.translation = "I find it hard to imagine"; t.questions = ["¿Qué te cuesta?"], t.similar_sound = ["me gusta imaginar"]; t.l2_start_index = 4; t.l2_end_index = 29 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 22, l1_end_index: 35) { |t| t.translation = "what will come"; t.l2_start_index = 30; t.l2_end_index = 44 }

# Phrase 8: Cambio dolor por libertad
phrase = phrases[8]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 6) { |t| t.translation = "I trade"; t.similar_sound = ["Canto"], t.questions = ["¿Qué cambias?"]; t.l2_start_index = 0; t.l2_end_index = 7 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 7, l1_end_index: 12) { |t| t.translation = "pain"; t.l2_start_index = 8; t.l2_end_index = 12 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 13, l1_end_index: 25) { |t| t.translation = "for freedom"; t.l2_start_index = 13; t.l2_end_index = 24 }

# Phrase 9: Cambio heridas por un sueño que me ayude a continuar
phrase = phrases[9]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 6) { |t| t.translation = "I trade"; t.l2_start_index = 0; t.l2_end_index = 7 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 7, l1_end_index: 14) { |t| t.translation = "wounds"; t.similar_sound = ["erizas"]; t.l2_start_index = 8; t.l2_end_index = 14 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 15, l1_end_index: 27) { |t| t.translation = "for a dream"; t.questions = ["¿Por qué cambias las heridas?"]; t.l2_start_index = 15; t.l2_end_index = 26 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 28, l1_end_index: 50) { |t| t.translation = "that helps me continue"; t.l2_start_index = 27; t.l2_end_index = 49 }

# Phrase 10: Cambio dolor por felicidad
phrase = phrases[10]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 6) { |t| t.translation = "I trade"; t.l2_start_index = 0; t.l2_end_index = 7 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 7, l1_end_index: 12) { |t| t.translation = "pain"; t.l2_start_index = 8; t.l2_end_index = 12 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 13, l1_end_index: 27) { |t| t.translation = "for happiness"; t.questions = ["¿Por qué cambias el dolor esta vez?"], t.similar_sound = ["por la ciudad"]; t.l2_start_index = 13; t.l2_end_index = 26 }

# Phrase 11: Que la suerte sea suerte y no algo que no he de alcanzar
phrase = phrases[11]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 19) { |t| t.translation = "May luck be luck"; t.questions = ["¿Qué deseas sobre la suerte?"]; t.l2_start_index = 0; t.l2_end_index = 16 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 20, l1_end_index: 23) { |t| t.translation = "and not"; t.l2_start_index = 17; t.l2_end_index = 24 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 24, l1_end_index: 54) { |t| t.translation = "something I can't reach"; t.l2_start_index = 25; t.l2_end_index = 48 }

# For repeated phrases (12-27, 30-37), tokenization would be identical to their first occurrences (0-11).
# I will define them for completeness in the phrases array but might only create unique token translations
# or use these as opportunities for different activity focuses (e.g. fluency).
# For this example, I'll create them to show the full structure.

# Phrase 12 (Same as 0)
phrase = phrases[12]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 7) { |t| t.translation = "I would swear"; t.l2_start_index = 0; t.l2_end_index = 13 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 8, l1_end_index: 11) { |t| t.translation = "that"; t.l2_start_index = 14; t.l2_end_index = 18 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 12, l1_end_index: 22) { |t| t.translation = "I don't quite know"; t.l2_start_index = 19; t.l2_end_index = 37 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 23, l1_end_index: 29) { |t| t.translation = "what"; t.l2_start_index = 38; t.l2_end_index = 42 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 30, l1_end_index: 36) { |t| t.translation = "I want"; t.l2_start_index = 43; t.l2_end_index = 49 }

# Phrase 13 (Same as 1)
phrase = phrases[13]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 4) { |t| t.translation = "But"; t.l2_start_index = 0; t.l2_end_index = 3 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 5, l1_end_index: 16) { |t| t.translation = "I know I would die"; t.l2_start_index = 4; t.l2_end_index = 22 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 17, l1_end_index: 19) { |t| t.translation = "if"; t.l2_start_index = 23; t.l2_end_index = 25 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 20, l1_end_index: 28) { |t| t.translation = "I stay"; t.l2_start_index = 26; t.l2_end_index = 32 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 29, l1_end_index: 39) { |t| t.translation = "in the middle"; t.l2_start_index = 33; t.l2_end_index = 46 }

# Phrase 14 (Same as 2)
phrase = phrases[14]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 7) { |t| t.translation = "That's why"; t.l2_start_index = 0; t.l2_end_index = 9 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 8, l1_end_index: 13) { |t| t.translation = "I fly"; t.l2_start_index = 10; t.l2_end_index = 15 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 14, l1_end_index: 27) { |t| t.translation = "to another path"; t.l2_start_index = 16; t.l2_end_index = 31 }

# Phrase 15 (Same as 3)
phrase = phrases[15]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 12) { |t| t.translation = "To know"; t.l2_start_index = 0; t.l2_end_index = 7 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 13, l1_end_index: 21) { |t| t.translation = "the real world"; t.l2_start_index = 8; t.l2_end_index = 22 }

# Phrase 16 (Same as 4)
phrase = phrases[16]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 13) { |t| t.translation = "It's not late yet"; t.l2_start_index = 0; t.l2_end_index = 17 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 15, l1_end_index: 19) { |t| t.translation = "but"; t.l2_start_index = 19; t.l2_end_index = 22 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 20, l1_end_index: 42) { |t| t.translation = "that's how I'm feeling"; t.l2_start_index = 23; t.l2_end_index = 45 }

# Phrase 17 (Same as 5)
phrase = phrases[17]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 1) { |t| t.translation = "And"; t.l2_start_index = 0; t.l2_end_index = 3 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 2, l1_end_index: 22) { |t| t.translation = "so many fears appear"; t.l2_start_index = 4; t.l2_end_index = 25 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 23, l1_end_index: 26) { |t| t.translation = "that"; t.l2_start_index = 26; t.l2_end_index = 30 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 27, l1_end_index: 45) { |t| t.translation = "don't let me think"; t.l2_start_index = 31; t.l2_end_index = 49 }

# Phrase 18 (Same as 6)
phrase = phrases[18]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 1) { |t| t.translation = "And"; t.l2_start_index = 0; t.l2_end_index = 3 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 2, l1_end_index: 15) { |t| t.translation = "I have dreams"; t.l2_start_index = 4; t.l2_end_index = 17 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 16, l1_end_index: 32) { |t| t.translation = "of new loves"; t.l2_start_index = 18; t.l2_end_index = 30 }

# Phrase 19 (Same as 7)
phrase = phrases[19]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 1) { |t| t.translation = "And"; t.l2_start_index = 0; t.l2_end_index = 3 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 2, l1_end_index: 21) { |t| t.translation = "I find it hard to imagine"; t.l2_start_index = 4; t.l2_end_index = 29 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 22, l1_end_index: 35) { |t| t.translation = "what will come"; t.l2_start_index = 30; t.l2_end_index = 44 }

# Phrases 20-27 are chorus repeats (same as 8-11)
# I'll define one set for phrase 20-23
# Phrase 20 (Same as 8)
phrase = phrases[20]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 6) { |t| t.translation = "I trade"; t.l2_start_index = 0; t.l2_end_index = 7 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 7, l1_end_index: 12) { |t| t.translation = "pain"; t.l2_start_index = 8; t.l2_end_index = 12 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 13, l1_end_index: 25) { |t| t.translation = "for freedom"; t.l2_start_index = 13; t.l2_end_index = 24 }

# Phrase 21 (Same as 9)
phrase = phrases[21]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 6) { |t| t.translation = "I trade"; t.l2_start_index = 0; t.l2_end_index = 7 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 7, l1_end_index: 14) { |t| t.translation = "wounds"; t.l2_start_index = 8; t.l2_end_index = 14 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 15, l1_end_index: 27) { |t| t.translation = "for a dream"; t.l2_start_index = 15; t.l2_end_index = 26 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 28, l1_end_index: 50) { |t| t.translation = "that helps me continue"; t.l2_start_index = 27; t.l2_end_index = 49 }

# Phrase 22 (Same as 10)
phrase = phrases[22]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 6) { |t| t.translation = "I trade"; t.l2_start_index = 0; t.l2_end_index = 7 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 7, l1_end_index: 12) { |t| t.translation = "pain"; t.l2_start_index = 8; t.l2_end_index = 12 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 13, l1_end_index: 27) { |t| t.translation = "for happiness"; t.l2_start_index = 13; t.l2_end_index = 26 }

# Phrase 23 (Same as 11)
phrase = phrases[23]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 19) { |t| t.translation = "May luck be luck"; t.l2_start_index = 0; t.l2_end_index = 16 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 20, l1_end_index: 23) { |t| t.translation = "and not"; t.l2_start_index = 17; t.l2_end_index = 24 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 24, l1_end_index: 54) { |t| t.translation = "something I can't reach"; t.l2_start_index = 25; t.l2_end_index = 48 }

# Phrases 24-27 are identical to 20-23. I'll skip defining more TokenTranslations for these specific phrase objects for brevity,
# assuming the system can reuse or they'd be identical. For activities, one might pick one instance.

# Phrase 28 (Bridge - Same as 6)
phrase = phrases[28]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 1) { |t| t.translation = "And"; t.l2_start_index = 0; t.l2_end_index = 3 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 2, l1_end_index: 15) { |t| t.translation = "I have dreams"; t.l2_start_index = 4; t.l2_end_index = 17 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 16, l1_end_index: 32) { |t| t.translation = "of new loves"; t.l2_start_index = 18; t.l2_end_index = 30 }

# Phrase 29 (Bridge - Same as 7)
phrase = phrases[29]
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 0, l1_end_index: 1) { |t| t.translation = "And"; t.l2_start_index = 0; t.l2_end_index = 3 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 2, l1_end_index: 21) { |t| t.translation = "I find it hard to imagine"; t.l2_start_index = 4; t.l2_end_index = 29 }
TokenTranslation.find_or_create_by(phrase: phrase, l1_start_index: 22, l1_end_index: 35) { |t| t.translation = "what will come"; t.l2_start_index = 30; t.l2_end_index = 44 }

# Phrases 30-37 are final chorus repeats. Assume tokenization is the same as phrases 8-11.

# --- Create Lessons ---
lessons_data = [
  { slug_suffix: '1', order: 0, name: 'No sé lo que quiero' },
  { slug_suffix: '2', order: 1, name: 'Miedos y Sueños' },
  { slug_suffix: '3', order: 2, name: 'Coro: Cambio Dolor por Libertad' },
  { slug_suffix: '4', order: 3, name: 'Puente: Sueños y Futuro' },
  { slug_suffix: '5', order: 4, name: 'Coro Final: Afirmación' }
]

l = lessons_data.map do |lesson_data|
  Lesson.create!(
    medium: medium,
    slug: "#{course_slug}#{lesson_data[:slug_suffix]}",
    course: c,
    order: lesson_data[:order],
    name: lesson_data[:name]
  )
end

# --- Activities ---

# Lesson 1: "No sé lo que quiero" (phrases 0-3)
lesson1_phrases = phrases[0..3]
lesson1 = l[0]
Activities::WatchVideoActivity.create!(lesson: lesson1, order: 1, phrases: lesson1_phrases)
Activities::MatchPhrasesActivity.create!(lesson: lesson1, text_header: 'Une cada frase con su traducción', order: 2, phrases: lesson1_phrases)
Activities::SortPhrasesActivity.create!(lesson: lesson1, order: 3, phrases: lesson1_phrases)
lang_align_l1 = Activities::LanguageAlignmentActivity.create!(lesson: lesson1, order: 4, phrases: lesson1_phrases)
lang_align_l1.token_translations = [
  phrases[0].token_translations.find_by(translation: "I don't quite know"),
  phrases[0].token_translations.find_by(translation: "I want"),
  phrases[1].token_translations.find_by(translation: "I stay"),
  phrases[2].token_translations.find_by(translation: "I fly"),
  phrases[3].token_translations.find_by(translation: "To know")
]
Activities::SpeakActivity.create!(lesson: lesson1, order: 5, phrases: lesson1_phrases)
listen_l1 = Activities::ListenActivity.create!(lesson: lesson1, order: 6, phrases: lesson1_phrases)
listen_l1.token_translations = [
  phrases[0].token_translations.find_by(translation: "I would swear"),
  phrases[1].token_translations.find_by(translation: "in the middle"),
  phrases[2].token_translations.find_by(translation: "another path"),
  phrases[3].token_translations.find_by(translation: "the real world")
]

# Lesson 2: "Miedos y Sueños" (phrases 4-7)
lesson2_phrases = phrases[4..7]
lesson2 = l[1]
Activities::WatchVideoActivity.create!(lesson: lesson2, order: 1, phrases: lesson2_phrases)
Activities::MatchPhrasesActivity.create!(lesson: lesson2, text_header: 'Une cada frase con su traducción', order: 2, phrases: lesson2_phrases)
Activities::SortPhrasesActivity.create!(lesson: lesson2, order: 3, phrases: lesson2_phrases)
lang_align_l2 = Activities::LanguageAlignmentActivity.create!(lesson: lesson2, order: 4, phrases: lesson2_phrases)
lang_align_l2.token_translations = [
  phrases[4].token_translations.find_by(translation: "It's not late yet"),
  phrases[4].token_translations.find_by(translation: "that's how I'm feeling"),
  phrases[5].token_translations.find_by(translation: "so many fears appear"),
  phrases[6].token_translations.find_by(translation: "I have dreams"),
  phrases[7].token_translations.find_by(translation: "I find it hard to imagine")
]
Activities::SpeakActivity.create!(lesson: lesson2, order: 5, phrases: lesson2_phrases)
listen_l2 = Activities::ListenActivity.create!(lesson: lesson2, order: 6, phrases: lesson2_phrases)
listen_l2.token_translations = [
  phrases[5].token_translations.find_by(translation: "don't let me think"),
  phrases[6].token_translations.find_by(translation: "of new loves"),
  phrases[7].token_translations.find_by(translation: "what will come")
]

# Lesson 3: "Coro: Cambio Dolor por Libertad" (phrases 8-11)
lesson3_phrases = phrases[8..11]
lesson3 = l[2]
Activities::WatchVideoActivity.create!(lesson: lesson3, order: 1, phrases: lesson3_phrases)
Activities::MatchPhrasesActivity.create!(lesson: lesson3, text_header: 'Une cada frase del coro con su traducción', order: 2, phrases: lesson3_phrases)
Activities::SortPhrasesActivity.create!(lesson: lesson3, order: 3, phrases: lesson3_phrases)
lang_align_l3 = Activities::LanguageAlignmentActivity.create!(lesson: lesson3, order: 4, phrases: lesson3_phrases)
lang_align_l3.token_translations = [
  phrases[8].token_translations.find_by(translation: "I trade"),
  phrases[8].token_translations.find_by(translation: "for freedom"),
  phrases[9].token_translations.find_by(translation: "wounds"),
  phrases[9].token_translations.find_by(translation: "that helps me continue"),
  phrases[10].token_translations.find_by(translation: "for happiness"),
  phrases[11].token_translations.find_by(translation: "May luck be luck")
]
Activities::SpeakActivity.create!(lesson: lesson3, order: 5, phrases: lesson3_phrases)
listen_l3 = Activities::ListenActivity.create!(lesson: lesson3, order: 6, phrases: lesson3_phrases)
listen_l3.token_translations = [
  phrases[9].token_translations.find_by(translation: "for a dream"),
  phrases[11].token_translations.find_by(translation: "something I can't reach")
]

# Lesson 4: "Puente: Sueños y Futuro" (phrases 28-29, these are unique before final choruses)
# These are repeats of 6 and 7. We can use them for reinforcement.
lesson4_phrases = phrases[28..29] # These correspond to original phrases 6 and 7
lesson4 = l[3]
Activities::WatchVideoActivity.create!(lesson: lesson4, order: 1, phrases: lesson4_phrases)
Activities::MatchPhrasesActivity.create!(lesson: lesson4, text_header: 'Une cada frase con su traducción', order: 2, phrases: lesson4_phrases)
Activities::SortPhrasesActivity.create!(lesson: lesson4, order: 3, phrases: lesson4_phrases)
# Using token translations from the original phrases 6 and 7 for alignment targets
lang_align_l4 = Activities::LanguageAlignmentActivity.create!(lesson: lesson4, order: 4, phrases: lesson4_phrases)
lang_align_l4.token_translations = [
  phrases[6].token_translations.find_by(translation: "I have dreams"), # Mapped to phrase[28] which is phrase index 6
  phrases[6].token_translations.find_by(translation: "of new loves"),
  phrases[7].token_translations.find_by(translation: "I find it hard to imagine"), # Mapped to phrase[29] which is phrase index 7
  phrases[7].token_translations.find_by(translation: "what will come")
]
Activities::SpeakActivity.create!(lesson: lesson4, order: 5, phrases: lesson4_phrases)
listen_l4 = Activities::ListenActivity.create!(lesson: lesson4, order: 6, phrases: lesson4_phrases)
listen_l4.token_translations = [
  phrases[6].token_translations.find_by(translation: "I have dreams"),
  phrases[7].token_translations.find_by(translation: "what will come")
]


# Lesson 5: "Coro Final: Afirmación" (phrases 30-33 for activities - one instance of the final chorus)
lesson5_phrases = phrases[30..33]
lesson5 = l[4]
# Watch video can include more of the ending, e.g., phrases[30..37]
Activities::WatchVideoActivity.create!(lesson: lesson5, order: 1, phrases: phrases[30..37])
Activities::MatchPhrasesActivity.create!(lesson: lesson5, text_header: 'Une cada frase del coro final con su traducción', order: 2, phrases: lesson5_phrases)
Activities::SortPhrasesActivity.create!(lesson: lesson5, order: 3, phrases: lesson5_phrases)
# For alignment, use token translations from the first instance of the chorus (phrases 8-11)
lang_align_l5 = Activities::LanguageAlignmentActivity.create!(lesson: lesson5, order: 4, phrases: lesson5_phrases)
lang_align_l5.token_translations = [
  phrases[8].token_translations.find_by(translation: "I trade"),
  phrases[9].token_translations.find_by(translation: "wounds"),
  phrases[10].token_translations.find_by(translation: "for happiness"),
  phrases[11].token_translations.find_by(translation: "something I can't reach")
]
Activities::SpeakActivity.create!(lesson: lesson5, order: 5, phrases: lesson5_phrases)
listen_l5 = Activities::ListenActivity.create!(lesson: lesson5, order: 6, phrases: lesson5_phrases)
listen_l5.token_translations = [
  phrases[8].token_translations.find_by(translation: "for freedom"),
  phrases[9].token_translations.find_by(translation: "that helps me continue")
]

puts "Lesson for '#{course_name}' created successfully."
