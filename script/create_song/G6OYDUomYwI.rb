
en = Language.find_by(iso_name: 'en')
es = Language.find_by(iso_name: 'es')
medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=G6OYDUomYwI')
phrases_data = [["Juraría que no sé bien lo que quiero","I'd swear I don't really know what I want","00:15"],["Pero sé que moriría si me quedo en la mitad","But I know I would die if I stay in the middle","00:20"],["Por eso vuelo a otro sendero","That's why I fly to another path","00:25"],["Para conocer el mundo de verdad","To know the real world","00:30"],["Aún no es tarde pero así me estoy sintiendo","It's not late yet but that's how I'm feeling","00:35"],["Y aparecen tantos miedos que no me dejan pensar","And so many fears appear that don't let me think","00:40"],["Y tengo sueños de amores nuevos","And I have dreams of new loves","00:45"],["Y me cuesta imaginar lo que vendrá","And it's hard for me to imagine what will come","00:50"],["Cambio dolor por libertad","I exchange pain for freedom","00:55"],["Cambio heridas por un sueño que me ayude a continuar","I exchange wounds for a dream that helps me continue","01:00"],["Cambio dolor, felicidad","I exchange pain (for) happiness","01:05"],["Que la suerte sea suerte y no algo que no he de alcanzar","May luck be luck and not something I'm not meant to reach","01:10"],["Juraría que no sé bien lo que quiero","I'd swear I don't really know what I want","01:27"],["Pero sé que moriría si me quedo en la mitad","But I know I would die if I stay in the middle","01:32"],["Por eso vuelo a otro sendero","That's why I fly to another path","01:37"],["Para conocer el mundo de verdad","To know the real world","01:42"],["Aún no es tarde pero así me estoy sintiendo","It's not late yet but that's how I'm feeling","01:47"],["Y aparecen tantos miedos que no me dejan pensar","And so many fears appear that don't let me think","01:52"],["Y tengo sueños de amores nuevos","And I have dreams of new loves","01:57"],["Y me cuesta imaginar lo que vendrá","And it's hard for me to imagine what will come","02:02"],["Cambio dolor por libertad","I exchange pain for freedom","02:07"],["Cambio heridas por un sueño que me ayude a continuar","I exchange wounds for a dream that helps me continue","02:12"],["Cambio dolor, felicidad","I exchange pain, happiness","02:17"],["Que la suerte sea suerte y no algo que no he de alcanzar","May luck be luck and not something I'm not meant to reach","02:22"],["Cambio dolor por libertad","I exchange pain for freedom","02:27"],["Cambio heridas por un sueño que me ayude a continuar","I exchange wounds for a dream that helps me continue","02:32"],["Cambio dolor, felicidad","I exchange pain, happiness","02:38"],["Que la suerte sea suerte y no algo que no he de alcanzar","May luck be luck and not something I'm not meant to reach","02:43"],["Tengo sueños de amores nuevos","I have dreams of new loves","03:09"],["Y me cuesta imaginar lo que vendrá","And it's hard for me to imagine what will come","03:14"],["Cambio dolor por libertad","I exchange pain for freedom","03:19"],["Cambio heridas por un sueño que me ayude a continuar","I exchange wounds for a dream that helps me continue","03:24"],["Cambio dolor, felicidad","I exchange pain, happiness","03:30"],["Que la suerte sea suerte y no algo que no he de alcanzar","May luck be luck and not something I'm not meant to reach","03:35"]];

c = Course.find_or_create_by!(slug: 'cambio-dolor') do
  name = 'Cambio Dolor'
  main_media_url = 'https://www.youtube.com/watch?v=G6OYDUomYwI'
end
c.lessons.destroy_all

Lesson.where("slug like 'cambio-dolor%'").destroy_all
medium.phrases.destroy_all

# Create phrases in DB
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

# Create Lessons in the DB

phrase = phrases[0]
phrase.add_token_translation("Juraría", 0, "I would swear", 0, similar_sound: ["curaría"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("no sé", 0, "I don't know", 0, similar_sound: [])
phrase.add_token_translation("bien", 0, "well", 0, similar_sound: ["viene"])
phrase.add_token_translation("lo que", 0, "what", 0, similar_sound: ["luego"])
phrase.add_token_translation("quiero", 0, "I want", 0, similar_sound: ["pero"])

phrase = phrases[1]
phrase.add_token_translation("Pero", 0, "But", 0, similar_sound: [])
phrase.add_token_translation("sé", 0, "I know", 0, similar_sound: [])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("moriría", 0, "I would die", 0, similar_sound: [])
phrase.add_token_translation("si", 0, "if", 0, similar_sound: [])
phrase.add_token_translation("me quedo", 0, "I stay", 0, similar_sound: [])
phrase.add_token_translation("en", 0, "in", 0, similar_sound: [])
phrase.add_token_translation("la mitad", 0, "the middle", 0, similar_sound: ["mirada"])

phrase = phrases[2]
phrase.add_token_translation("Por eso", 0, "That's why", 0, similar_sound: [])
phrase.add_token_translation("vuelo", 0, "I fly", 0, similar_sound: ["suelo"])
phrase.add_token_translation("a", 0, "to", 0, similar_sound: [])
phrase.add_token_translation("otro", 0, "another", 0, similar_sound: ["ocho"])
phrase.add_token_translation("sendero", 0, "path", 0, similar_sound: ["dinero"])

phrase = phrases[3]
phrase.add_token_translation("Para", 0, "To", 0, similar_sound: ["pera","parra"])
phrase.add_token_translation("conocer", 0, "know", 0, similar_sound: ["coser","cocer"])
phrase.add_token_translation("el", 0, "the", 0, similar_sound: [])
phrase.add_token_translation("mundo", 0, "world", 0, similar_sound: ["mudo","punto"])
phrase.add_token_translation("de verdad", 0, "for real", 0, similar_sound: ["ciudad"])

phrase = phrases[4]
phrase.add_token_translation("Aún", 0, "Yet", 0, similar_sound: ["a uno"])
phrase.add_token_translation("no es", 0, "is not", 0, similar_sound: ["nueces"])
phrase.add_token_translation("tarde", 0, "late", 0, similar_sound: ["verde"])
phrase.add_token_translation("pero", 0, "but", 0, similar_sound: ["perro"])
phrase.add_token_translation("así", 0, "that's how", 0, similar_sound: ["azul"])
phrase.add_token_translation("me estoy sintiendo", 0, "I'm feeling", 0, similar_sound: ["me estoy sentando"])

phrase = phrases[5]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("aparecen", 0, "appear", 0, similar_sound: ["parecen"])
phrase.add_token_translation("tantos", 0, "so many", 0, similar_sound: ["santos"])
phrase.add_token_translation("miedos", 0, "fears", 0, similar_sound: ["medios"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 0, "don't", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: [])
phrase.add_token_translation("dejan", 0, "let", 0, similar_sound: ["tejan"])
phrase.add_token_translation("pensar", 0, "think", 0, similar_sound: ["pesar"])

phrase = phrases[6]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("tengo", 0, "I have", 0, similar_sound: ["tango","luego"])
phrase.add_token_translation("sueños", 0, "dreams", 0, similar_sound: ["dueños","leños"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: [])
phrase.add_token_translation("amores", 0, "loves", 0, similar_sound: ["dolores","flores"])
phrase.add_token_translation("nuevos", 0, "new", 0, similar_sound: ["huesos","nervios"])

phrase = phrases[7]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("me cuesta", 0, "it's hard for me", 0, similar_sound: ["me gusta"])
phrase.add_token_translation("imaginar", 0, "to imagine", 0, similar_sound: ["maquinar"])
phrase.add_token_translation("lo que", 0, "what", 0, similar_sound: [])
phrase.add_token_translation("vendrá", 0, "will come", 0, similar_sound: ["tendrá"])

phrase = phrases[8]
phrase.add_token_translation("Cambio", 0, "I exchange", -1, similar_sound: ["canto"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["sol"])
phrase.add_token_translation("libertad", 0, "freedom", 0, similar_sound: ["verdad"])

phrase = phrases[9]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("heridas", 0, "wounds", 0, similar_sound: ["bebidas"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: [])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: ["con"])
phrase.add_token_translation("sueño", 0, "dream", 0, similar_sound: ["dueño"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: ["de"])
phrase.add_token_translation("ayude", 0, "helps", 0, similar_sound: ["ayuno"])
phrase.add_token_translation("a", 0, "to", 0, similar_sound: ["o"])
phrase.add_token_translation("continuar", 0, "continue", 0, similar_sound: ["terminar"])

phrase = phrases[10]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: [])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color","valor"])
phrase.add_token_translation("felicidad", 0, "happiness", 0, similar_sound: ["ciudad","facilidad"])

phrase = phrases[11]
phrase.add_token_translation("Que", 0, "May", 0, similar_sound: [])
phrase.add_token_translation("la suerte", 0, "luck", 0, similar_sound: ["la muerte"])
phrase.add_token_translation("sea", 0, "be", 0, similar_sound: ["vea"])
phrase.add_token_translation("suerte", 1, "luck", 1, similar_sound: ["muerte"])
phrase.add_token_translation("y", 0, "and", 0, similar_sound: [])
phrase.add_token_translation("no", 0, "not", 0, similar_sound: [])
phrase.add_token_translation("algo", 0, "something", 0, similar_sound: ["alto"])
phrase.add_token_translation("que", 1, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 1, "not", 1, similar_sound: [])
phrase.add_token_translation("he de", 0, "I must", 0, similar_sound: ["cede"])
phrase.add_token_translation("alcanzar", 0, "reach", 0, similar_sound: ["descansar"])

phrase = phrases[12]
phrase.add_token_translation("Juraría", 0, "I would swear", 0, similar_sound: ["curaría"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("no sé", 0, "I don't know", 0, similar_sound: [])
phrase.add_token_translation("bien", 0, "well", 0, similar_sound: ["viene"])
phrase.add_token_translation("lo que", 0, "what", 0, similar_sound: ["luego"])
phrase.add_token_translation("quiero", 0, "I want", 0, similar_sound: ["pero"])

phrase = phrases[13]
phrase.add_token_translation("Pero", 0, "But", 0, similar_sound: [])
phrase.add_token_translation("sé", 0, "I know", 0, similar_sound: [])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("moriría", 0, "I would die", 0, similar_sound: [])
phrase.add_token_translation("si", 0, "if", 0, similar_sound: [])
phrase.add_token_translation("me quedo", 0, "I stay", 0, similar_sound: [])
phrase.add_token_translation("en", 0, "in", 0, similar_sound: [])
phrase.add_token_translation("la mitad", 0, "the middle", 0, similar_sound: ["mirada"])

phrase = phrases[14]
phrase.add_token_translation("Por eso", 0, "That's why", 0, similar_sound: [])
phrase.add_token_translation("vuelo", 0, "I fly", 0, similar_sound: ["suelo","duelo"])
phrase.add_token_translation("a", 0, "to", 0, similar_sound: [])
phrase.add_token_translation("otro", 0, "another", 0, similar_sound: ["ocho","oro"])
phrase.add_token_translation("sendero", 0, "path", 0, similar_sound: ["dinero","sombrero"])

phrase = phrases[15]
phrase.add_token_translation("Para", 0, "To", 0, similar_sound: ["pera","parra"])
phrase.add_token_translation("conocer", 0, "know", 0, similar_sound: ["coser","cocer"])
phrase.add_token_translation("el", 0, "the", 0, similar_sound: [])
phrase.add_token_translation("mundo", 0, "world", 0, similar_sound: ["mudo","punto"])
phrase.add_token_translation("de verdad", 0, "for real", 0, similar_sound: ["ciudad"])

phrase = phrases[16]
phrase.add_token_translation("Aún", 0, "Yet", 0, similar_sound: ["a uno"])
phrase.add_token_translation("no es", 0, "is not", 0, similar_sound: ["nueces"])
phrase.add_token_translation("tarde", 0, "late", 0, similar_sound: ["verde"])
phrase.add_token_translation("pero", 0, "but", 0, similar_sound: ["perro"])
phrase.add_token_translation("así", 0, "that's how", 0, similar_sound: ["azul"])
phrase.add_token_translation("me estoy sintiendo", 0, "I'm feeling", 0, similar_sound: ["me estoy sentando"])

phrase = phrases[17]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("aparecen", 0, "appear", 0, similar_sound: ["parecen"])
phrase.add_token_translation("tantos", 0, "so many", 0, similar_sound: ["santos"])
phrase.add_token_translation("miedos", 0, "fears", 0, similar_sound: ["medios"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 0, "don't", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: [])
phrase.add_token_translation("dejan", 0, "let", 0, similar_sound: ["tejan"])
phrase.add_token_translation("pensar", 0, "think", 0, similar_sound: ["pesar"])

phrase = phrases[18]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("tengo", 0, "I have", 0, similar_sound: ["tango","luego"])
phrase.add_token_translation("sueños", 0, "dreams", 0, similar_sound: ["dueños","leños"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: [])
phrase.add_token_translation("amores", 0, "loves", 0, similar_sound: ["dolores","flores"])
phrase.add_token_translation("nuevos", 0, "new", 0, similar_sound: ["huesos","nervios"])

phrase = phrases[19]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("me cuesta", 0, "it's hard for me", 0, similar_sound: ["me gusta"])
phrase.add_token_translation("imaginar", 0, "to imagine", 0, similar_sound: ["maquinar"])
phrase.add_token_translation("lo que", 0, "what", 0, similar_sound: [])
phrase.add_token_translation("vendrá", 0, "will come", 0, similar_sound: ["tendrá"])

phrase = phrases[20]
phrase.add_token_translation("Cambio", 0, "I exchange", -1, similar_sound: ["canto"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["sol"])
phrase.add_token_translation("libertad", 0, "freedom", 0, similar_sound: ["verdad"])

phrase = phrases[21]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("heridas", 0, "wounds", 0, similar_sound: ["bebidas"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: [])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: ["con"])
phrase.add_token_translation("sueño", 0, "dream", 0, similar_sound: ["dueño"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: ["de"])
phrase.add_token_translation("ayude", 0, "helps", 0, similar_sound: ["ayuno"])
phrase.add_token_translation("a", 0, "to", 0, similar_sound: ["o"])
phrase.add_token_translation("continuar", 0, "continue", 0, similar_sound: ["terminar"])

phrase = phrases[22]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: [])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color","valor"])
phrase.add_token_translation("felicidad", 0, "happiness", 0, similar_sound: ["ciudad","facilidad"])

phrase = phrases[23]
phrase.add_token_translation("Que", 0, "May", 0, similar_sound: [])
phrase.add_token_translation("la suerte", 0, "luck", 0, similar_sound: ["la muerte","la fuente"])
phrase.add_token_translation("sea", 0, "be", 0, similar_sound: ["fea","vea"])
phrase.add_token_translation("suerte", 1, "luck", 1, similar_sound: ["muerte","fuente"])
phrase.add_token_translation("y", 0, "and", 0, similar_sound: ["o"])
phrase.add_token_translation("no", 0, "not", 0, similar_sound: ["nos","dos"])
phrase.add_token_translation("algo", 0, "something", 0, similar_sound: ["alto","salgo"])
phrase.add_token_translation("que", 1, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 1, "not", 1, similar_sound: ["nos","dos"])
phrase.add_token_translation("he de", 0, "I am to", 0, similar_sound: ["de","cede"])
phrase.add_token_translation("alcanzar", 0, "achieve", 0, similar_sound: ["cansar","lanzar"])

phrase = phrases[24]
phrase.add_token_translation("Cambio", 0, "I exchange", -1, similar_sound: ["canto"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["sol"])
phrase.add_token_translation("libertad", 0, "freedom", 0, similar_sound: ["verdad"])

phrase = phrases[25]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("heridas", 0, "wounds", 0, similar_sound: ["bebidas"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: [])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: ["con"])
phrase.add_token_translation("sueño", 0, "dream", 0, similar_sound: ["dueño"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: ["de"])
phrase.add_token_translation("ayude", 0, "helps", 0, similar_sound: ["ayuno"])
phrase.add_token_translation("a", 0, "to", 0, similar_sound: ["o"])
phrase.add_token_translation("continuar", 0, "continue", 0, similar_sound: ["terminar"])

phrase = phrases[26]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: [])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color","valor"])
phrase.add_token_translation("felicidad", 0, "happiness", 0, similar_sound: ["ciudad","facilidad"])

phrase = phrases[27]
phrase.add_token_translation("Que", 0, "May", 0, similar_sound: [])
phrase.add_token_translation("la suerte", 0, "luck", 0, similar_sound: ["la muerte"])
phrase.add_token_translation("sea", 0, "be", 0, similar_sound: ["vea"])
phrase.add_token_translation("suerte", 1, "luck", 1, similar_sound: ["muerte"])
phrase.add_token_translation("y", 0, "and", 0, similar_sound: [])
phrase.add_token_translation("no", 0, "not", 0, similar_sound: [])
phrase.add_token_translation("algo", 0, "something", 0, similar_sound: ["alto"])
phrase.add_token_translation("que", 1, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 1, "not", 1, similar_sound: [])
phrase.add_token_translation("he de", 0, "I must", 0, similar_sound: ["cede"])
phrase.add_token_translation("alcanzar", 0, "reach", 0, similar_sound: ["descansar"])

phrase = phrases[28]
phrase.add_token_translation("Tengo", 0, "I have", 0, similar_sound: ["vengo"])
phrase.add_token_translation("sueños", 0, "dreams", 0, similar_sound: ["dueños"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: ["le"])
phrase.add_token_translation("amores", 0, "loves", 0, similar_sound: ["dolores"])
phrase.add_token_translation("nuevos", 0, "new", 0, similar_sound: ["huevos"])

phrase = phrases[29]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: ["hay"])
phrase.add_token_translation("me cuesta", 0, "it's hard for me", 0, similar_sound: ["respuesta"])
phrase.add_token_translation("imaginar", 0, "to imagine", 0, similar_sound: ["eliminar"])
phrase.add_token_translation("lo que", 0, "what", 0, similar_sound: ["la que"])
phrase.add_token_translation("vendrá", 0, "will come", 0, similar_sound: ["tendrá"])

phrase = phrases[30]
phrase.add_token_translation("Cambio", 0, "I exchange", -1, similar_sound: ["canto"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["sol"])
phrase.add_token_translation("libertad", 0, "freedom", 0, similar_sound: ["verdad"])

phrase = phrases[31]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("heridas", 0, "wounds", 0, similar_sound: ["bebidas"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: [])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: ["con"])
phrase.add_token_translation("sueño", 0, "dream", 0, similar_sound: ["dueño"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: ["de"])
phrase.add_token_translation("ayude", 0, "helps", 0, similar_sound: ["ayuno"])
phrase.add_token_translation("a", 0, "to", 0, similar_sound: ["o"])
phrase.add_token_translation("continuar", 0, "continue", 0, similar_sound: ["terminar"])

phrase = phrases[32]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: [])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color","valor"])
phrase.add_token_translation("felicidad", 0, "happiness", 0, similar_sound: ["ciudad","facilidad"])

phrase = phrases[33]
phrase.add_token_translation("Que", 0, "May", 0, similar_sound: [])
phrase.add_token_translation("la suerte", 0, "luck", 0, similar_sound: ["la muerte"])
phrase.add_token_translation("sea", 0, "be", 0, similar_sound: ["vea"])
phrase.add_token_translation("suerte", 1, "luck", 1, similar_sound: ["muerte"])
phrase.add_token_translation("y", 0, "and", 0, similar_sound: [])
phrase.add_token_translation("no", 0, "not", 0, similar_sound: [])
phrase.add_token_translation("algo", 0, "something", 0, similar_sound: ["alto"])
phrase.add_token_translation("que", 1, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 1, "not", 1, similar_sound: [])
phrase.add_token_translation("he de", 0, "I must", 0, similar_sound: ["cede"])
phrase.add_token_translation("alcanzar", 0, "reach", 0, similar_sound: ["descansar"])

l = Lesson.create!(medium: medium, slug: 'cambio-dolor0', course: c, order: 0, name: 'Intro - Uncertainty and Desire')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = [phrases[0].find_token_translation("Juraría"),, phrases[0].find_token_translation("que"),, phrases[0].find_token_translation("no sé"),, phrases[0].find_token_translation("bien"),, phrases[0].find_token_translation("lo que"),, phrases[1].find_token_translation("Pero"),, phrases[1].find_token_translation("sé"),, phrases[1].find_token_translation("que"),, phrases[1].find_token_translation("moriría"),, phrases[1].find_token_translation("si"),, phrases[1].find_token_translation("la mitad"),, phrases[2].find_token_translation("Por eso"),, phrases[2].find_token_translation("vuelo"),, phrases[2].find_token_translation("a"),, phrases[2].find_token_translation("otro"),, phrases[2].find_token_translation("sendero"),, phrases[3].find_token_translation("Para"),, phrases[3].find_token_translation("conocer"),, phrases[3].find_token_translation("el"),, phrases[3].find_token_translation("mundo"),, phrases[3].find_token_translation("de verdad"),]


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = []

l = Lesson.create!(medium: medium, slug: 'cambio-dolor1', course: c, order: 1, name: 'Verse - Fears and Dreams')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = [phrases[0].find_token_translation("Aún"),, phrases[0].find_token_translation("no es"),, phrases[0].find_token_translation("tarde"),, phrases[0].find_token_translation("me estoy sintiendo"),, phrases[1].find_token_translation("Y"),, phrases[1].find_token_translation("aparecen"),, phrases[1].find_token_translation("tantos"),, phrases[1].find_token_translation("no"),, phrases[1].find_token_translation("dejan"),, phrases[2].find_token_translation("Y"),, phrases[2].find_token_translation("tengo"),, phrases[2].find_token_translation("sueños"),, phrases[2].find_token_translation("nuevos"),, phrases[3].find_token_translation("Y"),, phrases[3].find_token_translation("me cuesta"),, phrases[3].find_token_translation("imaginar"),]


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = []

l = Lesson.create!(medium: medium, slug: 'cambio-dolor2', course: c, order: 2, name: 'Chorus - Exchange for Freedom')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = [phrases[0].find_token_translation("Cambio"),, phrases[0].find_token_translation("dolor"),, phrases[0].find_token_translation("por"),, phrases[0].find_token_translation("libertad"),, phrases[1].find_token_translation("Cambio"),, phrases[1].find_token_translation("heridas"),, phrases[1].find_token_translation("por"),, phrases[1].find_token_translation("un"),, phrases[1].find_token_translation("continuar"),, phrases[2].find_token_translation("Cambio"),, phrases[2].find_token_translation("dolor"),, phrases[2].find_token_translation("felicidad"),, phrases[3].find_token_translation("Que"),, phrases[3].find_token_translation("la suerte"),, phrases[3].find_token_translation("sea"),, phrases[3].find_token_translation("suerte"),, phrases[3].find_token_translation("he de"),, phrases[3].find_token_translation("alcanzar"),]


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = []

l = Lesson.create!(medium: medium, slug: 'cambio-dolor3', course: c, order: 3, name: 'Bridge - Dreams of Love')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(28, 29)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(28, 29)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(28, 29)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(28, 29)
a.token_translations = [phrases[0].find_token_translation("Tengo"),, phrases[0].find_token_translation("sueños"),, phrases[0].find_token_translation("de"),, phrases[1].find_token_translation("Y"),, phrases[1].find_token_translation("me cuesta"),, phrases[1].find_token_translation("imaginar"),]


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(28, 29)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(28, 29)
a.token_translations = []

l = Lesson.create!(medium: medium, slug: 'cambio-dolor4', course: c, order: 4, name: 'Final Chorus - Ultimate Exchange')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = [phrases[0].find_token_translation("Cambio"),, phrases[0].find_token_translation("dolor"),, phrases[0].find_token_translation("por"),, phrases[0].find_token_translation("libertad"),, phrases[1].find_token_translation("Cambio"),, phrases[1].find_token_translation("heridas"),, phrases[1].find_token_translation("por"),, phrases[1].find_token_translation("un"),, phrases[1].find_token_translation("continuar"),, phrases[2].find_token_translation("Cambio"),, phrases[2].find_token_translation("dolor"),, phrases[2].find_token_translation("felicidad"),, phrases[3].find_token_translation("Que"),, phrases[3].find_token_translation("la suerte"),, phrases[3].find_token_translation("sea"),, phrases[3].find_token_translation("suerte"),, phrases[3].find_token_translation("he de"),, phrases[3].find_token_translation("alcanzar"),]


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = []
