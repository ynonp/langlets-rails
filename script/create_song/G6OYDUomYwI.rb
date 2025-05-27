
en = Language.find_by(iso_name: 'en')
es = Language.find_by(iso_name: 'es')
medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=G6OYDUomYwI')
phrases_data = [
  [
    "Juraría que no sé bien lo que quiero",
    "I'd swear I don't really know what I want",
    "00:15"
  ],
  [
    "Pero sé que moriría si me quedo en la mitad",
    "But I know I would die if I stay in the middle",
    "00:20"
  ],
  [
    "Por eso vuelo a otro sendero",
    "That's why I fly to another path",
    "00:25"
  ],
  [
    "Para conocer el mundo de verdad",
    "To know the real world",
    "00:30"
  ],
  [
    "Aún no es tarde pero así me estoy sintiendo",
    "It's not late yet but that's how I'm feeling",
    "00:35"
  ],
  [
    "Y aparecen tantos miedos que no me dejan pensar",
    "And so many fears appear that don't let me think",
    "00:40"
  ],
  [
    "Y tengo sueños de amores nuevos",
    "And I have dreams of new loves",
    "00:45"
  ],
  [
    "Y me cuesta imaginar lo que vendrá",
    "And it's hard for me to imagine what will come",
    "00:50"
  ],
  [
    "Cambio dolor por libertad",
    "I exchange pain for freedom",
    "00:55"
  ],
  [
    "Cambio heridas por un sueño que me ayude a continuar",
    "I exchange wounds for a dream that helps me continue",
    "01:00"
  ],
  [
    "Cambio dolor, felicidad",
    "I exchange pain (for) happiness",
    "01:05"
  ],
  [
    "Que la suerte sea suerte y no algo que no he de alcanzar",
    "May luck be luck and not something I'm not meant to reach",
    "01:10"
  ],
  [
    "Juraría que no sé bien lo que quiero",
    "I'd swear I don't really know what I want",
    "01:27"
  ],
  [
    "Pero sé que moriría si me quedo en la mitad",
    "But I know I would die if I stay in the middle",
    "01:32"
  ],
  [
    "Por eso vuelo a otro sendero",
    "That's why I fly to another path",
    "01:37"
  ],
  [
    "Para conocer el mundo de verdad",
    "To know the real world",
    "01:42"
  ],
  [
    "Aún no es tarde pero así me estoy sintiendo",
    "It's not late yet but that's how I'm feeling",
    "01:47"
  ],
  [
    "Y aparecen tantos miedos que no me dejan pensar",
    "And so many fears appear that don't let me think",
    "01:52"
  ],
  [
    "Y tengo sueños de amores nuevos",
    "And I have dreams of new loves",
    "01:57"
  ],
  [
    "Y me cuesta imaginar lo que vendrá",
    "And it's hard for me to imagine what will come",
    "02:02"
  ],
  [
    "Cambio dolor por libertad",
    "I exchange pain for freedom",
    "02:07"
  ],
  [
    "Cambio heridas por un sueño que me ayude a continuar",
    "I exchange wounds for a dream that helps me continue",
    "02:12"
  ],
  [
    "Cambio dolor, felicidad",
    "I exchange pain, happiness",
    "02:17"
  ],
  [
    "Que la suerte sea suerte y no algo que no he de alcanzar",
    "May luck be luck and not something I'm not meant to reach",
    "02:22"
  ],
  [
    "Cambio dolor por libertad",
    "I exchange pain for freedom",
    "02:27"
  ],
  [
    "Cambio heridas por un sueño que me ayude a continuar",
    "I exchange wounds for a dream that helps me continue",
    "02:32"
  ],
  [
    "Cambio dolor, felicidad",
    "I exchange pain, happiness",
    "02:38"
  ],
  [
    "Que la suerte sea suerte y no algo que no he de alcanzar",
    "May luck be luck and not something I'm not meant to reach",
    "02:43"
  ],
  [
    "Tengo sueños de amores nuevos",
    "I have dreams of new loves",
    "03:09"
  ],
  [
    "Y me cuesta imaginar lo que vendrá",
    "And it's hard for me to imagine what will come",
    "03:14"
  ],
  [
    "Cambio dolor por libertad",
    "I exchange pain for freedom",
    "03:19"
  ],
  [
    "Cambio heridas por un sueño que me ayude a continuar",
    "I exchange wounds for a dream that helps me continue",
    "03:24"
  ],
  [
    "Cambio dolor, felicidad",
    "I exchange pain, happiness",
    "03:30"
  ],
  [
    "Que la suerte sea suerte y no algo que no he de alcanzar",
    "May luck be luck and not something I'm not meant to reach",
    "03:35"
  ]
];

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
phrase.add_token_translation("bien", 0, "really", 0, similar_sound: ["viene"])
phrase.add_token_translation("lo que", 0, "what", 0, similar_sound: [])
phrase.add_token_translation("quiero", 0, "I want", 0, similar_sound: ["pero"])

phrase = phrases[1]
phrase.add_token_translation("Pero", 0, "But", 0, similar_sound: ["perro"])
phrase.add_token_translation("sé que", 0, "I know that", 0, similar_sound: ["saque"])
phrase.add_token_translation("moriría", 0, "I would die", 0, similar_sound: ["correría"])
phrase.add_token_translation("si", 0, "if", 0, similar_sound: ["sin"])
phrase.add_token_translation("me quedo", 0, "I stay", 0, similar_sound: [])
phrase.add_token_translation("en la", 0, "in the", 0, similar_sound: [])
phrase.add_token_translation("mitad", 0, "middle", 0, similar_sound: ["mirada"])

phrase = phrases[2]
phrase.add_token_translation("Por eso", 0, "That's why", 0, similar_sound: [])
phrase.add_token_translation("vuelo", 0, "I fly", 0, similar_sound: ["suelo","duelo"])
phrase.add_token_translation("a", 0, "to", 0, similar_sound: [])
phrase.add_token_translation("otro", 0, "another", 0, similar_sound: ["ocho","oro"])
phrase.add_token_translation("sendero", 0, "path", 0, similar_sound: ["dinero","entero"])

phrase = phrases[3]
phrase.add_token_translation("Para", 0, "To", 0, similar_sound: ["pera","parra"])
phrase.add_token_translation("conocer", 0, "know", 0, similar_sound: ["coser","cocer"])
phrase.add_token_translation("el mundo", 0, "the world", 0, similar_sound: ["mudo","fondo"])
phrase.add_token_translation("de verdad", 0, "for real", 0, similar_sound: ["ciudad","edad"])

phrase = phrases[4]
phrase.add_token_translation("Aún", 0, "Yet", 0, similar_sound: [])
phrase.add_token_translation("no es", 0, "is not", 0, similar_sound: ["nueces"])
phrase.add_token_translation("tarde", 0, "late", 0, similar_sound: ["parte","verde"])
phrase.add_token_translation("pero", 0, "but", 0, similar_sound: ["perro"])
phrase.add_token_translation("así", 0, "that's how", 0, similar_sound: ["allí"])
phrase.add_token_translation("me estoy", 0, "I'm", 0, similar_sound: ["maestro"])
phrase.add_token_translation("sintiendo", 0, "feeling", 0, similar_sound: ["siguiendo"])

phrase = phrases[5]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("aparecen", 0, "appear", 0, similar_sound: ["parecen"])
phrase.add_token_translation("tantos", 0, "so many", 0, similar_sound: ["cantos"])
phrase.add_token_translation("miedos", 0, "fears", 0, similar_sound: ["medios"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 0, "don't", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: [])
phrase.add_token_translation("dejan", 0, "let", 0, similar_sound: ["tejan"])
phrase.add_token_translation("pensar", 0, "think", 0, similar_sound: ["pesar"])

phrase = phrases[6]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("tengo", 0, "I have", 0, similar_sound: ["vengo","ciego"])
phrase.add_token_translation("sueños", 0, "dreams", 0, similar_sound: ["dueños","leños"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: ["ve"])
phrase.add_token_translation("amores", 0, "loves", 0, similar_sound: ["dolores","colores"])
phrase.add_token_translation("nuevos", 0, "new", 0, similar_sound: ["huesos","huevos"])

phrase = phrases[7]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: ["hay"])
phrase.add_token_translation("me cuesta", 0, "it's hard for me", 0, similar_sound: ["puesta","respuesta"])
phrase.add_token_translation("imaginar", 0, "to imagine", 0, similar_sound: ["eliminar","terminar"])
phrase.add_token_translation("lo que", 0, "what", 0, similar_sound: ["loco","luego"])
phrase.add_token_translation("vendrá", 0, "will come", 0, similar_sound: ["tendrá","entrar"])

phrase = phrases[8]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["sol"])
phrase.add_token_translation("libertad", 0, "freedom", 0, similar_sound: ["verdad"])

phrase = phrases[9]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("heridas", 0, "wounds", 0, similar_sound: ["queridas"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["flor"])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: ["luz"])
phrase.add_token_translation("sueño", 0, "dream", 0, similar_sound: ["dueño"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: ["vez"])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: ["miel"])
phrase.add_token_translation("ayude a", 0, "helps to", 0, similar_sound: ["ayuno"])
phrase.add_token_translation("continuar", 0, "continue", 0, similar_sound: ["contar"])

phrase = phrases[10]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("felicidad", 0, "happiness", 0, similar_sound: ["ciudad"])

phrase = phrases[11]
phrase.add_token_translation("Que", 0, "May", 0, similar_sound: [])
phrase.add_token_translation("la suerte", 0, "luck", 0, similar_sound: ["la muerte"])
phrase.add_token_translation("sea", 0, "be", 0, similar_sound: ["seda"])
phrase.add_token_translation("suerte", 1, "luck", 1, similar_sound: ["muerte"])
phrase.add_token_translation("y", 0, "and", 0, similar_sound: ["hay"])
phrase.add_token_translation("no", 0, "not", 0, similar_sound: ["nos"])
phrase.add_token_translation("algo", 0, "something", 0, similar_sound: ["alto"])
phrase.add_token_translation("que", 1, "that", 1, similar_sound: [])
phrase.add_token_translation("no", 1, "not", 1, similar_sound: ["nos"])
phrase.add_token_translation("he de", 0, "I should", 0, similar_sound: ["sede"])
phrase.add_token_translation("alcanzar", 0, "reach", 0, similar_sound: ["cansar","lanzar"])

phrase = phrases[12]
phrase.add_token_translation("Juraría", 0, "I would swear", 0, similar_sound: ["jugaría","curaría"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("no sé", 0, "I don't know", 0, similar_sound: ["no es"])
phrase.add_token_translation("bien", 0, "really", 0, similar_sound: ["cien","pie"])
phrase.add_token_translation("lo que", 0, "what", 0, similar_sound: ["lo sé","luego"])
phrase.add_token_translation("quiero", 0, "I want", 0, similar_sound: ["pero","cero"])

phrase = phrases[13]
phrase.add_token_translation("Pero", 0, "But", 0, similar_sound: ["perro"])
phrase.add_token_translation("sé que", 0, "I know that", 0, similar_sound: ["saque"])
phrase.add_token_translation("moriría", 0, "I would die", 0, similar_sound: ["correría"])
phrase.add_token_translation("si", 0, "if", 0, similar_sound: ["sin"])
phrase.add_token_translation("me quedo", 0, "I stay", 0, similar_sound: [])
phrase.add_token_translation("en la", 0, "in the", 0, similar_sound: [])
phrase.add_token_translation("mitad", 0, "middle", 0, similar_sound: ["mirada"])

phrase = phrases[14]
phrase.add_token_translation("Por eso", 0, "That's why", 0, similar_sound: [])
phrase.add_token_translation("vuelo", 0, "I fly", 0, similar_sound: ["suelo","duelo"])
phrase.add_token_translation("a", 0, "to", 0, similar_sound: [])
phrase.add_token_translation("otro", 0, "another", 0, similar_sound: ["ocho","oro"])
phrase.add_token_translation("sendero", 0, "path", 0, similar_sound: ["dinero","entero"])

phrase = phrases[15]
phrase.add_token_translation("Para", 0, "To", 0, similar_sound: ["pera"])
phrase.add_token_translation("conocer", 0, "know", 0, similar_sound: ["coser"])
phrase.add_token_translation("el mundo", 0, "the world", 0, similar_sound: ["mudo"])
phrase.add_token_translation("de verdad", 0, "for real", 0, similar_sound: ["ciudad"])

phrase = phrases[16]
phrase.add_token_translation("Aún", 0, "Yet", 0, similar_sound: ["aun"])
phrase.add_token_translation("no es", 0, "is not", 0, similar_sound: [])
phrase.add_token_translation("tarde", 0, "late", 0, similar_sound: ["verde","parte"])
phrase.add_token_translation("pero", 0, "but", 0, similar_sound: ["perro","quiero"])
phrase.add_token_translation("así", 0, "that's how", 0, similar_sound: ["aquí","allí"])
phrase.add_token_translation("me estoy sintiendo", 0, "I'm feeling", 0, similar_sound: [])

phrase = phrases[17]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("aparecen", 0, "appear", 0, similar_sound: ["parecen"])
phrase.add_token_translation("tantos", 0, "so many", 0, similar_sound: ["cantos"])
phrase.add_token_translation("miedos", 0, "fears", 0, similar_sound: ["medios"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 0, "don't", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: [])
phrase.add_token_translation("dejan", 0, "let", 0, similar_sound: ["tejan"])
phrase.add_token_translation("pensar", 0, "think", 0, similar_sound: ["pesar"])

phrase = phrases[18]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("tengo", 0, "I have", 0, similar_sound: ["tango"])
phrase.add_token_translation("sueños", 0, "dreams", 0, similar_sound: ["dueños"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: ["te"])
phrase.add_token_translation("amores", 0, "loves", 0, similar_sound: ["dolores"])
phrase.add_token_translation("nuevos", 0, "new", 0, similar_sound: ["huesos"])

phrase = phrases[19]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: ["hay"])
phrase.add_token_translation("me cuesta", 0, "it's hard for me", 0, similar_sound: ["puesta","respuesta"])
phrase.add_token_translation("imaginar", 0, "to imagine", 0, similar_sound: ["eliminar","terminar"])
phrase.add_token_translation("lo que", 0, "what", 0, similar_sound: ["loco","luego"])
phrase.add_token_translation("vendrá", 0, "will come", 0, similar_sound: ["tendrá","entrar"])

phrase = phrases[20]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["sol"])
phrase.add_token_translation("libertad", 0, "freedom", 0, similar_sound: ["verdad"])

phrase = phrases[21]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("heridas", 0, "wounds", 0, similar_sound: ["queridas"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["flor"])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: ["luz"])
phrase.add_token_translation("sueño", 0, "dream", 0, similar_sound: ["dueño"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: ["vez"])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: ["miel"])
phrase.add_token_translation("ayude a", 0, "helps to", 0, similar_sound: ["ayuno"])
phrase.add_token_translation("continuar", 0, "continue", 0, similar_sound: ["contar"])

phrase = phrases[22]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("felicidad", 0, "happiness", 0, similar_sound: ["ciudad"])

phrase = phrases[23]
phrase.add_token_translation("Que", 0, "May", 0, similar_sound: [])
phrase.add_token_translation("la suerte", 0, "luck", 0, similar_sound: ["la muerte"])
phrase.add_token_translation("sea", 0, "be", 0, similar_sound: ["seda"])
phrase.add_token_translation("suerte", 1, "luck", 1, similar_sound: ["muerte"])
phrase.add_token_translation("y", 0, "and", 0, similar_sound: ["hay"])
phrase.add_token_translation("no", 0, "not", 0, similar_sound: ["nos"])
phrase.add_token_translation("algo", 0, "something", 0, similar_sound: ["alto"])
phrase.add_token_translation("que", 1, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 1, "not", 1, similar_sound: ["nos"])
phrase.add_token_translation("he de", 0, "I should", 0, similar_sound: ["sede"])
phrase.add_token_translation("alcanzar", 0, "reach", 0, similar_sound: ["cansar","lanzar"])

phrase = phrases[24]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["sol"])
phrase.add_token_translation("libertad", 0, "freedom", 0, similar_sound: ["verdad"])

phrase = phrases[25]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo","canto"])
phrase.add_token_translation("heridas", 0, "wounds", 0, similar_sound: ["queridas","bebidas"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["sol","flor"])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: ["en","sin"])
phrase.add_token_translation("sueño", 0, "dream", 0, similar_sound: ["dueño","pequeño"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: ["te","se"])
phrase.add_token_translation("ayude", 0, "helps", 0, similar_sound: ["ayuda","salude"])
phrase.add_token_translation("a", 0, "to", 0, similar_sound: ["y","o"])
phrase.add_token_translation("continuar", 0, "continue", 0, similar_sound: ["caminar","terminar"])

phrase = phrases[26]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("felicidad", 0, "happiness", 0, similar_sound: ["ciudad"])

phrase = phrases[27]
phrase.add_token_translation("Que", 0, "May", 0, similar_sound: [])
phrase.add_token_translation("la suerte", 0, "luck", 0, similar_sound: ["la muerte"])
phrase.add_token_translation("sea", 0, "be", 0, similar_sound: ["seda"])
phrase.add_token_translation("suerte", 1, "luck", 1, similar_sound: ["muerte"])
phrase.add_token_translation("y", 0, "and", 0, similar_sound: ["hay"])
phrase.add_token_translation("no", 0, "not", 0, similar_sound: ["nos"])
phrase.add_token_translation("algo", 0, "something", 0, similar_sound: ["alto"])
phrase.add_token_translation("que", 1, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 1, "not", 1, similar_sound: ["nos"])
phrase.add_token_translation("he de", 0, "I should", 0, similar_sound: ["sede"])
phrase.add_token_translation("alcanzar", 0, "reach", 0, similar_sound: ["cansar","lanzar"])

phrase = phrases[28]
phrase.add_token_translation("Tengo", 0, "I have", 0, similar_sound: ["vengo"])
phrase.add_token_translation("sueños", 0, "dreams", 0, similar_sound: ["dueños"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: ["te"])
phrase.add_token_translation("amores", 0, "loves", 0, similar_sound: ["dolores"])
phrase.add_token_translation("nuevos", 0, "new", 0, similar_sound: ["huesos"])

phrase = phrases[29]
phrase.add_token_translation("Y", 0, "And", 0, similar_sound: ["hay","ahí"])
phrase.add_token_translation("me cuesta", 0, "it's hard for me", 0, similar_sound: ["puesta","respuesta"])
phrase.add_token_translation("imaginar", 0, "to imagine", 0, similar_sound: ["terminar","caminar"])
phrase.add_token_translation("lo que", 0, "what", 0, similar_sound: ["la que","el que"])
phrase.add_token_translation("vendrá", 0, "will come", 0, similar_sound: ["tendrá","entrar"])

phrase = phrases[30]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["sol"])
phrase.add_token_translation("libertad", 0, "freedom", 0, similar_sound: ["verdad"])

phrase = phrases[31]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("heridas", 0, "wounds", 0, similar_sound: ["queridas"])
phrase.add_token_translation("por", 0, "for", 0, similar_sound: ["flor"])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: ["luz"])
phrase.add_token_translation("sueño", 0, "dream", 0, similar_sound: ["dueño"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: ["vez"])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: ["miel"])
phrase.add_token_translation("ayude a", 0, "helps to", 0, similar_sound: ["ayuno"])
phrase.add_token_translation("continuar", 0, "continue", 0, similar_sound: ["contar"])

phrase = phrases[32]
phrase.add_token_translation("Cambio", 0, "I exchange", 0, similar_sound: ["campo"])
phrase.add_token_translation("dolor", 0, "pain", 0, similar_sound: ["color"])
phrase.add_token_translation("felicidad", 0, "happiness", 0, similar_sound: ["ciudad"])

phrase = phrases[33]
phrase.add_token_translation("Que", 0, "May", 0, similar_sound: [])
phrase.add_token_translation("la suerte", 0, "luck", 0, similar_sound: ["la muerte"])
phrase.add_token_translation("sea", 0, "be", 0, similar_sound: ["seda"])
phrase.add_token_translation("suerte", 1, "luck", 1, similar_sound: ["muerte"])
phrase.add_token_translation("y", 0, "and", 0, similar_sound: ["hay"])
phrase.add_token_translation("no", 0, "not", 0, similar_sound: ["nos"])
phrase.add_token_translation("algo", 0, "something", 0, similar_sound: ["alto"])
phrase.add_token_translation("que", 1, "that", 0, similar_sound: [])
phrase.add_token_translation("no", 1, "not", 1, similar_sound: ["nos"])
phrase.add_token_translation("he de", 0, "I should", 0, similar_sound: ["sede"])
phrase.add_token_translation("alcanzar", 0, "reach", 0, similar_sound: ["cansar","lanzar"])

l = Lesson.create!(medium: medium, slug: 'cambio-dolor0', course: c, order: 0, name: 'Intro - Uncertainty and Desire')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = [phrases[0].find_token_translation("Juraría"),
phrases[0].find_token_translation("que"),
phrases[0].find_token_translation("bien"),
phrases[1].find_token_translation("Pero"),
phrases[1].find_token_translation("sé que"),
phrases[1].find_token_translation("moriría"),
phrases[1].find_token_translation("mitad"),
phrases[2].find_token_translation("vuelo"),
phrases[2].find_token_translation("otro"),
phrases[3].find_token_translation("Para"),
phrases[3].find_token_translation("el mundo")].filter {|t| t.l2_start_index.present? }


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(0, 1, 2, 3)
a.token_translations = [phrases[0].find_token_translation("bien"),
phrases[0].find_token_translation("quiero"),
phrases[1].find_token_translation("mitad"),
phrases[2].find_token_translation("sendero"),
phrases[3].find_token_translation("de verdad")]

l = Lesson.create!(medium: medium, slug: 'cambio-dolor1', course: c, order: 1, name: 'Verse - Fears and Dreams')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = [phrases[4].find_token_translation("tarde"),
phrases[4].find_token_translation("me estoy"),
phrases[5].find_token_translation("aparecen"),
phrases[5].find_token_translation("tantos"),
phrases[6].find_token_translation("tengo"),
phrases[6].find_token_translation("sueños"),
phrases[6].find_token_translation("amores"),
phrases[6].find_token_translation("nuevos"),
phrases[7].find_token_translation("me cuesta"),
phrases[7].find_token_translation("imaginar"),
phrases[7].find_token_translation("vendrá")].filter {|t| t.l2_start_index.present? }


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(4, 5, 6, 7)
a.token_translations = [phrases[4].find_token_translation("tarde"),
phrases[5].find_token_translation("aparecen"),
phrases[5].find_token_translation("tantos"),
phrases[6].find_token_translation("sueños"),
phrases[7].find_token_translation("me cuesta"),
phrases[7].find_token_translation("imaginar")]

l = Lesson.create!(medium: medium, slug: 'cambio-dolor2', course: c, order: 2, name: 'Chorus - Exchange for Freedom')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = [phrases[8].find_token_translation("Cambio"),
phrases[8].find_token_translation("libertad"),
phrases[9].find_token_translation("Cambio"),
phrases[9].find_token_translation("sueño"),
phrases[10].find_token_translation("Cambio"),
phrases[10].find_token_translation("dolor"),
phrases[10].find_token_translation("felicidad"),
phrases[11].find_token_translation("la suerte"),
phrases[11].find_token_translation("suerte", 1),
phrases[11].find_token_translation("alcanzar")].filter {|t| t.l2_start_index.present? }


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(8, 9, 10, 11)
a.token_translations = [phrases[8].find_token_translation("dolor"),
phrases[9].find_token_translation("heridas"),
phrases[9].find_token_translation("sueño"),
phrases[10].find_token_translation("dolor"),
phrases[11].find_token_translation("la suerte"),
phrases[11].find_token_translation("sea"),
phrases[11].find_token_translation("alcanzar")]

l = Lesson.create!(medium: medium, slug: 'cambio-dolor3', course: c, order: 3, name: 'Bridge - Dreams of Love')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(28, 29)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(28, 29)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(28, 29)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(28, 29)
a.token_translations = [phrases[28].find_token_translation("Tengo"),
phrases[28].find_token_translation("sueños"),
phrases[28].find_token_translation("nuevos"),
phrases[29].find_token_translation("Y"),
phrases[29].find_token_translation("me cuesta"),
phrases[29].find_token_translation("vendrá")].filter {|t| t.l2_start_index.present? }


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(28, 29)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(28, 29)
a.token_translations = [phrases[28].find_token_translation("sueños"),
phrases[29].find_token_translation("me cuesta")]

l = Lesson.create!(medium: medium, slug: 'cambio-dolor4', course: c, order: 4, name: 'Final Chorus - Ultimate Exchange')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = [phrases[30].find_token_translation("Cambio"),
phrases[30].find_token_translation("dolor"),
phrases[30].find_token_translation("por"),
phrases[31].find_token_translation("Cambio"),
phrases[32].find_token_translation("Cambio"),
phrases[32].find_token_translation("felicidad"),
phrases[33].find_token_translation("la suerte"),
phrases[33].find_token_translation("suerte", 1),
phrases[33].find_token_translation("alcanzar")].filter {|t| t.l2_start_index.present? }


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(30, 31, 32, 33)
a.token_translations = [phrases[30].find_token_translation("por"),
phrases[30].find_token_translation("libertad"),
phrases[31].find_token_translation("sueño"),
phrases[32].find_token_translation("felicidad"),
phrases[33].find_token_translation("suerte", 1),
phrases[33].find_token_translation("alcanzar")]
