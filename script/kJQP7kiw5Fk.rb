en = Language.find_by(iso_name: 'en')
es = Language.find_by(iso_name: 'es')
medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=kJQP7kiw5Fk')

# Setup - split lyrics to phrases with timestamps

phrases_data = [
  ["¡Ay!", "Oh!", "00:28"],
  ["Fonsi, DY", "Fonsi, DY", "00:30"],
  ["Oh, oh no, oh no (oh)", "Oh, oh no, oh no (oh)", "00:33"],
  ["Hey yeah", "Hey yeah", "00:38"],
  ["Diridiri, dirididi Daddy", "Diridiri, dirididi Daddy", "00:39"],
  ["Go!", "Go!", "00:41"],
  ["Sí, sabes que ya llevo un rato mirándote", "Yes, you know that I've been looking at you for a while", "00:42"],
  ["Tengo que bailar contigo hoy (DY)", "I have to dance with you today (DY)", "00:47"],
  ["Vi que tu mirada ya estaba llamándome", "I saw that your look was already calling me", "00:52"],
  ["Muéstrame el camino que yo voy", "Show me the way to go", "00:57"],
  ["Oh, tú, tú eres el imán y yo soy el metal", "Oh, you, you are the magnet and I am the metal", "01:02"],
  ["Me voy acercando y voy armando el plan", "I'm getting closer and I'm making the plan", "01:06"],
  ["Solo con pensarlo se acelera el pulso (oh yeah)", "Just thinking about it makes my pulse race (oh yeah)", "01:09"],
  ["Ya, ya me estás gustando más de lo normal", "Now, I'm liking you more than normal", "01:14"],
  ["Todos mis sentidos van pidiendo más", "All my senses are asking for more", "01:17"],
  ["Esto hay que tomarlo sin ningún apuro", "This must be taken without any rush", "01:20"],
  ["Despacito", "Slowly", "01:24"],
  ["Quiero respirar tu cuello despacito", "I want to breathe your neck slowly", "01:25"],
  ["Deja que te diga cosas al oído", "Let me tell you things in your ear", "01:28"],
  ["Para que te acuerdes si no estás conmigo", "So you remember if you're not with me", "01:31"],
  ["Despacito", "Slowly", "01:35"],
  ["Quiero desnudarte a besos despacito", "I want to undress you with kisses slowly", "01:36"],
  ["Firmar las paredes de tu laberinto", "Sign the walls of your labyrinth", "01:39"],
  ["Y hacer de tu cuerpo todo un manuscrito (sube, sube, sube)", "And make your body a whole manuscript (up, up, up)", "01:42"],
  ["(Sube, sube) Oh", "(Up, up) Oh", "01:45"],
  ["Quiero ver bailar tu pelo", "I want to see your hair dance", "01:47"],
  ["Quiero ser tu ritmo (uh oh, uh oh)", "I want to be your rhythm (uh oh, uh oh)", "01:48"],
  ["Que le enseñes a mi boca (uh oh, uh oh)", "That you teach my mouth (uh oh, uh oh)", "01:51"],
  ["Tus lugares favoritos (favoritos, favoritos baby)", "Your favorite places (favorite, favorite baby)", "01:53"],
  ["Déjame sobrepasar tus zonas de peligro (uh oh, uh oh)", "Let me overcome your danger zones (uh oh, uh oh)", "01:57"],
  ["Hasta provocar tus gritos (uh oh, uh oh)", "Until I make you scream (uh oh, uh oh)", "02:00"],
  ["Y que olvides tu apellido (dirididi Daddy)", "And you forget your last name (dirididi Daddy)", "02:03"],
  ["Yo sé que estás pensándolo (eh)", "I know you're thinking about it (eh)", "02:08"],
  ["Llevo tiempo intentándolo (eh)", "I've been trying for a while (eh)", "02:10"],
  ["Mami, esto es dando y dándolo", "Mommy, this is giving and giving it", "02:11"],
  ["Sabes que tu corazón conmigo te hace bam bam", "You know your heart with me goes bam bam", "02:13"],
  ["Sabe que esa beba 'tá buscando de mi bam bam", "She knows that baby is looking for my bam bam", "02:15"],
  ["Ven prueba de mi boca para ver cómo te sabe", "Come taste my mouth to see how it tastes to you", "02:18"],
  ["Quiero, quiero, quiero ver cuánto amor a ti te cabe", "I want, I want, I want to see how much love fits in you", "02:21"],
  ["Yo no tengo prisa, yo me quiero dar el viaje", "I'm not in a hurry, I want to take the trip", "02:24"],
  ["Empezamo' lento, después salvaje", "We start slow, then wild", "02:26"],
  ["Pasito a pasito, suave suavecito", "Step by step, soft softly", "02:29"],
  ["Nos vamos pegando poquito a poquito", "We get closer little by little", "02:31"],
  ["Cuando tú me besas con esa destreza", "When you kiss me with that skill", "02:34"],
  ["Veo que eres malicia con delicadeza", "I see you are malice with delicacy", "02:37"],
  ["Pasito a pasito, suave suavecito", "Step by step, soft softly", "02:40"],
  ["Nos vamos pegando, poquito a poquito (oh oh)", "We get closer, little by little (oh oh)", "02:42"],
  ["Y es que esa belleza es un rompecabezas (oh no)", "And it's that this beauty is a puzzle (oh no)", "02:45"],
  ["Pero pa' montarlo aquí tengo la pieza (slow, oh yeah)", "But to put it together, here I have the piece (slow, oh yeah)", "02:48"],
  ["Despacito (yeh, yo)", "Slowly (yeh, yo)", "02:51"],
  ["Quiero respirar tu cuello despacito (yo)", "I want to breathe your neck slowly (yo)", "02:53"],
  ["Deja que te diga cosas al oído (yo)", "Let me tell you things in your ear (yo)", "02:56"],
  ["Para que te acuerdes si no estás conmigo", "So you remember if you're not with me", "02:59"],
  ["Despacito", "Slowly", "03:03"],
  ["Quiero desnudarte a besos despacito (yeh)", "I want to undress you with kisses slowly (yeh)", "03:04"],
  ["Firmar las paredes de tu laberinto", "Sign the walls of your labyrinth", "03:07"],
  ["Y hacer de tu cuerpo todo un manuscrito (sube, sube, sube)", "And make your body a whole manuscript (up, up, up)", "03:10"],
  ["(Sube, sube) Oh", "(Up, up) Oh", "03:13"],
  ["Quiero ver bailar tu pelo", "I want to see your hair dance", "03:14"],
  ["Quiero ser tu ritmo (uh oh, uh oh)", "I want to be your rhythm (uh oh, uh oh)", "03:16"],
  ["Que le enseñes a mi boca (uh oh, uh oh)", "That you teach my mouth (uh oh, uh oh)", "03:19"],
  ["Tus lugares favoritos (favoritos, favoritos baby)", "Your favorite places (favorite, favorite baby)", "03:21"],
  ["Déjame sobrepasar tus zonas de peligro (uh oh, uh oh)", "Let me overcome your danger zones (uh oh, uh oh)", "03:25"],
  ["Hasta provocar tus gritos (uh oh, uh oh)", "Until I make you scream (uh oh, uh oh)", "03:28"],
  ["Y que olvides tu apellido", "And you forget your last name", "03:31"],
  ["Despacito", "Slowly", "03:35"],
  ["Vamo' a hacerlo en una playa en Puerto Rico", "Let's do it on a beach in Puerto Rico", "03:36"],
  ["Hasta que las olas griten \"Ay, bendito\"", "Until the waves scream \"Oh, my goodness!\"", "03:39"],
  ["Para que mi sello se quede contigo (báilalo)", "So that my seal stays with you (dance it)", "03:42"],
  ["Pasito a pasito, suave suavecito (hey yeah, yeah)", "Step by step, soft softly (hey yeah, yeah)", "03:46"],
  ["Nos vamos pegando, poquito a poquito (oh no)", "We get closer, little by little (oh no)", "03:48"],
  ["Que le enseñes a mi boca (uh oh, uh oh)", "That you teach my mouth (uh oh, uh oh)", "03:51"],
  ["Tus lugares favoritos (favoritos, favoritos baby)", "Your favorite places (favorite, favorite baby)", "03:54"],
  ["Pasito a pasito, suave suavecito", "Step by step, soft softly", "03:57"],
  ["Nos vamos pegando, poquito a poquito", "We get closer, little by little", "03:59"],
  ["Hasta provocar tus gritos (eh-oh) (Fonsi)", "Until I make you scream (eh-oh) (Fonsi)", "04:02"],
  ["Y que olvides tu apellido (DY)", "And you forget your last name (DY)", "04:05"],
  ["Despacito", "Slowly", "04:07"]
]

# Reset previous DB content
c = Course.find_or_create_by!(slug: 'despacito') do
  name = 'Despacito'
  main_media_url =  'https://www.youtube.com/watch?v=kJQP7kiw5Fk'
end
c.lessons.destroy_all

Lesson.where("slug like 'despacito%'").destroy_all
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

l = [
  Lesson.create!(medium: medium, slug: 'despacito1', course: c, order: 0, name: 'Intro')                     ,
  Lesson.create!(medium: medium, slug: 'despacito2', course: c, order: 1, name: 'el imán y el metal')             ,
  Lesson.create!(medium: medium, slug: 'despacito3', course: c, order: 2, name: 'Chorus')                    ,
  Lesson.create!(medium: medium, slug: 'despacito5', course: c, order: 4, name: 'Quiero ver bailar')         ,
  Lesson.create!(medium: medium, slug: 'despacito6', course: c, order: 5, name: 'Yo sé que estás pensándolo'),
  Lesson.create!(medium: medium, slug: 'despacito7', course: c, order: 6, name: 'Pasito a pasito')           ,
  Lesson.create!(medium: medium, slug: 'despacito8', course: c, order: 7, name: 'Outro')                     ,
]

# Setup token translations
# phrase.add_token_translation(text_l1, text_l1_occurence, text_l2, text_l2_occurence, attributes)
# add a token translation from the text
# in case the token translation text appears multiple times in the text,
# you can specify the occurence of the text in the text_l1_occurence and text_l2_occurence parameters
# if the text_l1_occurence is 0, it will add the token translation to the first occurence of the text
# if the text_l2_occurence is 0, it will add the token translation to the first occurence of the text_l2
# if the text_l1_occurence is 1, it will add the token translation to the second occurence of the text
# if the text_l2_occurence is 1, it will add the token translation to the second occurence of the text_l2
# if the text_l1_occurence is 2, it will add the token translation to the third occurence of the text

# ["¡Ay!", "Oh!", "00:28"],
phrase = phrases[0]
t1 = phrase.add_token_translation("¡Ay!", 0, "Oh!", 0)

# ["Fonsi, DY", "Fonsi, DY", "00:30"],
phrase = phrases[1]
t2 = phrase.add_token_translation("Fonsi,", 0, "Fonsi,", 0)
t3 = phrase.add_token_translation("DY", 0, "DY", 0)

#   ["Oh, oh no, oh no (oh)", "Oh, oh no, oh no (oh)", "00:33"],
phrase = phrases[2]
t4 = phrase.add_token_translation("Oh", 0, "Oh", 0) # first Oh -> Oh
t5 = phrase.add_token_translation("oh no", 0, "oh no", 0) # first oh no -> oh no
t6 = phrase.add_token_translation("oh no", 1, "oh no", 1) # second oh no -> oh n o
t7 = phrase.add_token_translation("oh", 2, "oh", 2) # second oh -> oh

# ["Hey yeah", "Hey yeah", "00:38"],
phrase = phrases[3]
t10 = phrase.add_token_translation("Hey", 0, "Hey", 0)
t11 = phrase.add_token_translation("yeah", 0, "yeah", 0)

# ["Diridiri, dirididi Daddy", "Diridiri, dirididi Daddy", "00:39"],
phrase = phrases[4]
t12 = phrase.add_token_translation("Diridiri", 0, "Diridiri", 0)
t13 = phrase.add_token_translation("dirididi", 0, "dirididi", 0)
t14 = phrase.add_token_translation("Daddy", 0, "Daddy", 0)

# ["Go!", "Go!", "00:40"],
phrase = phrases[5]
t14 = phrase.add_token_translation("Go!", 0, "Go!", 0)

# ["Sí, sabes que ya llevo un rato mirándote", "Yes, you know that I've been looking at you for a while", "00:42"],
phrase = phrases[6]
t15 = phrase.add_token_translation("Sí", 0, "Yes", 0, questions: [])
t16 = phrase.add_token_translation("sabes", 0, "you know", 0)
t17 = phrase.add_token_translation("que", 0, "that", 0, questions: [])
t18 = phrase.add_token_translation("ya", 0, "I've been", 0, similar_sound: ['luego', 'nuevo'])
t19 = phrase.add_token_translation("llevo un rato", 0, "for a while", 0, questions: ["¿Cuánto tiempo?"], similar_sound: ['un gato'])
t20 = phrase.add_token_translation("mirándote", 0, "looking at you", 0, questions: ["¿Qué haces?"])

# ["Tengo que bailar contigo hoy (DY)", "I have to dance with you today (DY)", "00:47"],
phrase = phrases[7]
t21 = phrase.add_token_translation("Tengo que", 0, "I have to", 0)
t22 = phrase.add_token_translation("bailar", 0, "dance", 0, questions: ["¿Qué tienes que hacer?"], similar_sound: ['volar'])
t23 = phrase.add_token_translation("contigo", 0, "with you", 0)
t24 = phrase.add_token_translation("hoy", 0, "today", 0, questions: ["¿Cuándo tienes que bailar contigo?"])
t25 = phrase.add_token_translation("(DY)", 0, "(DY)", 0)

# ["Vi que tu mirada ya estaba llamándome", "I saw that your look was already calling me", "00:52"],
phrase = phrases[8]
t26 = phrase.add_token_translation("Vi", 0, "I saw", 0)
t27 = phrase.add_token_translation("que", 0, "that", 0, questions: [])
t28 = phrase.add_token_translation("tu", 0, "your", 0, questions: [])
t29 = phrase.add_token_translation("mirada", 0, "look", 0, similar_sound: ['cansada'])
t30 = phrase.add_token_translation("ya", 0, "already", 0, questions: [])
t31 = phrase.add_token_translation("estaba", 0, "was", 0, questions: [])
t32 = phrase.add_token_translation("llamándome", 0, "calling me", 0, questions: [])

# ["Muéstrame el camino que yo voy", "Show me the way to go", "00:57"],
phrase = phrases[9]
t33 = phrase.add_token_translation("Muéstrame", 0, "Show me", 0, questions: ["¿Qué pide el hablante?"])
t34 = phrase.add_token_translation("el", 0, "the", 0)
t35 = phrase.add_token_translation("camino", 0, "way", 0, similar_sound: ['destino'])
t36 = phrase.add_token_translation("que yo voy", 0, "I'm going", 0)

phrase = phrases[10]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 2
) do |token|
  token.questions = []
  token.translation = "Oh"
  token.l2_start_index = 0
  token.l2_end_index = 2
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 6
) do |token|
  token.translation = "you"
  token.l2_start_index = 4
  token.l2_end_index = 7
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 8,
  l1_end_index: 10
) do |token|
  token.questions = []
  token.translation = "you"
  token.l2_start_index = 9
  token.l2_end_index = 12
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 15
) do |token|
  token.translation = "are"
  token.l2_start_index = 13
  token.l2_end_index = 16
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 16,
  l1_end_index: 23
) do |token|
  token.similar_sound = ['hermano']
  token.translation = "the magnet"
  token.l2_start_index = 17
  token.l2_end_index = 27
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 28
) do |token|
  token.translation = "I"
  token.l2_start_index = 32
  token.l2_end_index = 33
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 29,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "am"
  token.l2_start_index = 34
  token.l2_end_index = 36
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 33,
  l1_end_index: 41
) do |token|
  token.questions = ["¿Quién soy?"]
  token.translation = "the metal"
  token.l2_start_index = 37
  token.l2_end_index = 46
end

phrase = phrases[11]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 16
) do |token|
  token.translation = "I'm getting closer"
  token.l2_start_index = 0
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.translation = "and"
  token.l2_start_index = 19
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 30
) do |token|
  token.similar_sound = ['gritando']
  token.translation = "I'm making"
  token.l2_start_index = 23
  token.l2_end_index = 33
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 31,
  l1_end_index: 38
) do |token|
  token.questions = ["¿Qué está armando?"]
  token.translation = "the plan"
  token.l2_start_index = 34
  token.l2_end_index = 42
end

phrase = phrases[12]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.questions = []
  token.translation = "Just"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 5,
  l1_end_index: 17
) do |token|
  token.questions = ["¿Qué acelera el pulso?"]
  token.translation = "thinking about it"
  token.l2_start_index = 5
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 37
) do |token|
  token.translation = "makes my pulse race"
  token.l2_start_index = 23
  token.l2_end_index = 42
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 38,
  l1_end_index: 47
) do |token|
  token.questions = []
  token.translation = "(oh yeah)"
  token.l2_start_index = 43
  token.l2_end_index = 52
end

phrase = phrases[13]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 2
) do |token|
  token.questions = []
  token.translation = "Now"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 24
) do |token|
  token.translation = "I'm liking you"
  token.l2_start_index = 5
  token.l2_end_index = 19
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 28
) do |token|
  token.questions = []
  token.translation = "more"
  token.l2_start_index = 20
  token.l2_end_index = 24
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 29,
  l1_end_index: 41
) do |token|
  token.questions = []
  token.translation = "than normal"
  token.l2_start_index = 25
  token.l2_end_index = 36
end

phrase = phrases[14]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 5
) do |token|
  token.questions = []
  token.translation = "All"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 6,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "my"
  token.l2_start_index = 4
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.similar_sound = ['sonidos']
  token.translation = "senses"
  token.l2_start_index = 7
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 31
) do |token|
  token.translation = "are asking"
  token.l2_start_index = 14
  token.l2_end_index = 24
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 32,
  l1_end_index: 35
) do |token|
  token.questions = []
  token.translation = "more"
  token.l2_start_index = 29
  token.l2_end_index = 33
end

phrase = phrases[15]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.translation = "This"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 5,
  l1_end_index: 12
) do |token|
  token.questions = []
  token.translation = "must be"
  token.l2_start_index = 5
  token.l2_end_index = 12
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 13,
  l1_end_index: 20
) do |token|
  token.translation = "taken"
  token.l2_start_index = 13
  token.l2_end_index = 18
end

TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 31
) do |token|
  token.questions = []
  token.translation = "any"
  token.l2_start_index = 27
  token.l2_end_index = 30
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 32,
  l1_end_index: 37
) do |token|
  token.questions = []
  token.translation = "rush"
  token.l2_start_index = 31
  token.l2_end_index = 35
end

phrase = phrases[16]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.similar_sound = ['movidito']
  token.translation = "Slowly"
  token.l2_start_index = 0
  token.l2_end_index = 6
end

phrase = phrases[17]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 15
) do |token|
  token.translation = "I want to breathe"
  token.l2_start_index = 0
  token.l2_end_index = 17
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 16,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.translation = "your"
  token.l2_start_index = 18
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 25
) do |token|
  token.questions = ["¿Qué vas a respirar?"]
  token.translation = "neck"
  token.l2_start_index = 23
  token.l2_end_index = 27
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 35
) do |token|
  token.similar_sound = ['cariñito']
  token.translation = "slowly"
  token.l2_start_index = 28
  token.l2_end_index = 34
end

phrase = phrases[18]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.translation = "Let"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 11
) do |token|
  token.translation = "you"
  token.l2_start_index = 12
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 12,
  l1_end_index: 16
) do |token|
  token.translation = "tell"
  token.l2_start_index = 7
  token.l2_end_index = 11
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 22
) do |token|
  token.translation = "things"
  token.l2_start_index = 16
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 30
) do |token|
  token.translation = "in your ear"
  token.l2_start_index = 23
  token.l2_end_index = 34
end

phrase = phrases[19]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "So"
  token.l2_start_index = 0
  token.l2_end_index = 2
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 11
) do |token|
  token.questions = []
  token.translation = "you"
  token.l2_start_index = 3
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 12,
  l1_end_index: 20
) do |token|
  token.translation = "remember"
  token.l2_start_index = 7
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 21,
  l1_end_index: 23
) do |token|
  token.questions = []
  token.translation = "if"
  token.l2_start_index = 16
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 24,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "you're not"
  token.l2_start_index = 19
  token.l2_end_index = 29
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 33,
  l1_end_index: 40
) do |token|
  token.similar_sound = ['domingo']
  token.translation = "with me"
  token.l2_start_index = 30
  token.l2_end_index = 37
end

phrase = phrases[20]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "Slowly"
  token.l2_start_index = 0
  token.l2_end_index = 6
end

phrase = phrases[21]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "I want"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 15
) do |token|
  token.questions = []
  token.translation = "undress"
  token.l2_start_index = 10
  token.l2_end_index = 17
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 15,
  l1_end_index: 17
) do |token|
  token.questions = []
  token.translation = "you"
  token.l2_start_index = 18
  token.l2_end_index = 21
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 19
) do |token|
  token.questions = []
  token.translation = "with"
  token.l2_start_index = 22
  token.l2_end_index = 26
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 20,
  l1_end_index: 25
) do |token|
  token.questions = []
  token.translation = "kisses"
  token.l2_start_index = 27
  token.l2_end_index = 33
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 35
) do |token|
  token.questions = []
  token.translation = "slowly"
  token.l2_start_index = 34
  token.l2_end_index = 40
end

phrase = phrases[22]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "Sign"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 10
) do |token|
  token.questions = []
  token.translation = "the"
  token.l2_start_index = 5
  token.l2_end_index = 8
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 18
) do |token|
  token.questions = ["¿Qué vas a firmar?"]
  token.similar_sound = ['pareces']
  token.translation = "walls"
  token.l2_start_index = 9
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 21
) do |token|
  token.questions = []
  token.translation = "of"
  token.l2_start_index = 15
  token.l2_end_index = 17
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 22,
  l1_end_index: 24
) do |token|
  token.translation = "your"
  token.l2_start_index = 18
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 34
) do |token|
  token.translation = "labyrinth"
  token.l2_start_index = 23
  token.l2_end_index = 32
end

phrase = phrases[23]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 1
) do |token|
  token.questions = []
  token.translation = "And"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 2,
  l1_end_index: 7
) do |token|
  token.translation = "make"
  token.l2_start_index = 4
  token.l2_end_index = 8
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 20
) do |token|
  token.translation = "your body"
  token.l2_start_index = 9
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 21,
  l1_end_index: 39
) do |token|
  token.translation = "a whole manuscript"
  token.l2_start_index = 19
  token.l2_end_index = 37
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 40,
  l1_end_index: 58
) do |token|
  token.questions = []
  token.translation = "(up, up, up)"
  token.l2_start_index = 38
  token.l2_end_index = 50
end

phrase = phrases[24]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 1,
  l1_end_index: 5
) do |token|
  token.questions = []
  token.translation = "Up"
  token.l2_start_index = 1
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 11
) do |token|
  token.questions = []
  token.translation = "up"
  token.l2_start_index = 5
  token.l2_end_index = 7
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 13,
  l1_end_index: 15
) do |token|
  token.questions = []
  token.translation = "Oh"
  token.l2_start_index = 9
  token.l2_end_index = 11
end

phrase = phrases[25]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.questions = []
  token.translation = "I want"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 10
) do |token|
  token.similar_sound = ['ayer']
  token.translation = "to see"
  token.l2_start_index = 7
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 17
) do |token|
  token.questions = []
  token.translation = "dance"
  token.l2_start_index = 24
  token.l2_end_index = 29
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 25
) do |token|
  token.questions = ["¿Qué quiere ver bailar?"]
  token.translation = "your hair"
  token.l2_start_index = 14
  token.l2_end_index = 23
end

phrase = phrases[26]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.questions = []
  token.translation = "I want"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 10
) do |token|
  token.questions = []
  token.translation = "to be"
  token.l2_start_index = 7
  token.l2_end_index = 12
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 13
) do |token|
  token.questions = []
  token.translation = "your"
  token.l2_start_index = 13
  token.l2_end_index = 17
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 14,
  l1_end_index: 19
) do |token|
  token.questions = []
  token.translation = "rhythm"
  token.l2_start_index = 18
  token.l2_end_index = 24
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 20,
  l1_end_index: 34
) do |token|
  token.questions = []
  token.translation = "(uh oh, uh oh)"
  token.l2_start_index = 25
  token.l2_end_index = 39
end

phrase = phrases[27]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.questions = []
  token.translation = "That"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 14
) do |token|
  token.questions = []
  token.translation = "teach"
  token.l2_start_index = 9
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 15,
  l1_end_index: 24
) do |token|
  token.questions = ["¿A quién enseñas?"]
  token.translation = "my mouth"
  token.l2_start_index = 15
  token.l2_end_index = 23
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 39
) do |token|
  token.questions = []
  token.translation = "(uh oh, uh oh)"
  token.l2_start_index = 24
  token.l2_end_index = 38
end

phrase = phrases[28]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.questions = []
  token.translation = "Your"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 11
) do |token|
  token.questions = []
  token.translation = "places"
  token.l2_start_index = 14
  token.l2_end_index = 20
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 12,
  l1_end_index: 21
) do |token|
  token.questions = []
  token.translation = "favorite"
  token.l2_start_index = 5
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "favorite"
  token.l2_start_index = 22
  token.l2_end_index = 30
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 34,
  l1_end_index: 48
) do |token|
  token.questions = []
  token.translation = "favorite baby"
  token.l2_start_index = 32
  token.l2_end_index = 45
end

phrase = phrases[29]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.questions = []
  token.translation = "Let me"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 17
) do |token|
  token.questions = []
  token.translation = "overcome"
  token.l2_start_index = 7
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 21
) do |token|
  token.translation = "your"
  token.l2_start_index = 16
  token.l2_end_index = 20
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 22,
  l1_end_index: 38
) do |token|
  token.translation = "danger zones"
  token.l2_start_index = 21
  token.l2_end_index = 33
end

phrase = phrases[30]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 5
) do |token|
  token.questions = []
  token.translation = "Until"
  token.l2_start_index = 0
  token.l2_end_index = 5
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 6,
  l1_end_index: 14
) do |token|
  token.questions = []
  token.translation = "make"
  token.l2_start_index = 8
  token.l2_end_index = 12
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 15,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.translation = "you"
  token.l2_start_index = 13
  token.l2_end_index = 16
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 25
) do |token|
  token.questions = []
  token.translation = "scream"
  token.l2_start_index = 17
  token.l2_end_index = 23
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 40
) do |token|
  token.questions = []
  token.translation = "(uh oh, uh oh)"
  token.l2_start_index = 24
  token.l2_end_index = 38
end

phrase = phrases[31]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 1
) do |token|
  token.questions = []
  token.translation = "And"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 6,
  l1_end_index: 13
) do |token|
  token.questions = []
  token.translation = "forget"
  token.l2_start_index = 8
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 14,
  l1_end_index: 25
) do |token|
  token.questions = ["¿Qué olvidas tú?"]
  token.translation = "your last name"
  token.l2_start_index = 15
  token.l2_end_index = 29
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 42
) do |token|
  token.questions = []
  token.translation = "(dirididi Daddy)"
  token.l2_start_index = 30
  token.l2_end_index = 46
end

phrase = phrases[32]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 2
) do |token|
  token.translation = "I"
  token.l2_start_index = 0
  token.l2_end_index = 1
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 3,
  l1_end_index: 5
) do |token|
  token.questions = []
  token.translation = "know"
  token.l2_start_index = 2
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 24,
  l1_end_index: 26
) do |token|
  token.translation = "it"
  token.l2_start_index = 29
  token.l2_end_index = 31
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 27,
  l1_end_index: 31
) do |token|
  token.questions = []
  token.translation = "(eh)"
  token.l2_start_index = 32
  token.l2_end_index = 36
end

phrase = phrases[33]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 25
) do |token|
  token.translation = "I've been trying for a while"
  token.l2_start_index = 0
  token.l2_end_index = 28
end

phrase = phrases[34]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.translation = "Mommy"
  token.l2_start_index = 0
  token.l2_end_index = 5
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 6,
  l1_end_index: 10
) do |token|
  token.translation = "this"
  token.l2_start_index = 7
  token.l2_end_index = 11
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 13
) do |token|
  token.questions = []
  token.translation = "is"
  token.l2_start_index = 12
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 14,
  l1_end_index: 19
) do |token|
  token.questions = []
  token.translation = "giving"
  token.l2_start_index = 15
  token.l2_end_index = 21
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 20,
  l1_end_index: 21
) do |token|
  token.questions = []
  token.translation = "and"
  token.l2_start_index = 22
  token.l2_end_index = 25
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 22,
  l1_end_index: 29
) do |token|
  token.questions = []
  token.translation = "giving it"
  token.l2_start_index = 26
  token.l2_end_index = 35
end

phrase = phrases[35]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 5
) do |token|
  token.questions = []
  token.translation = "You know"
  token.l2_start_index = 0
  token.l2_end_index = 8
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 12
) do |token|
  token.translation = "your"
  token.l2_start_index = 9
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 13,
  l1_end_index: 20
) do |token|
  token.questions = ["¿Qué late?"]
  token.translation = "heart"
  token.l2_start_index = 14
  token.l2_end_index = 19
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 21,
  l1_end_index: 28
) do |token|
  token.questions = []
  token.translation = "with me"
  token.l2_start_index = 20
  token.l2_end_index = 27
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 37,
  l1_end_index: 44
) do |token|
  token.translation = "bam bam"
  token.l2_start_index = 33
  token.l2_end_index = 40
end

phrase = phrases[36]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.translation = "She knows"
  token.l2_start_index = 0
  token.l2_end_index = 9
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 5,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "that"
  token.l2_start_index = 10
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 17
) do |token|
  token.translation = "baby"
  token.l2_start_index = 15
  token.l2_end_index = 19
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 21
) do |token|
  token.questions = []
  token.translation = "is"
  token.l2_start_index = 20
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 22,
  l1_end_index: 30
) do |token|
  token.translation = "looking"
  token.l2_start_index = 23
  token.l2_end_index = 30
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 31,
  l1_end_index: 33
) do |token|
  token.questions = []
  token.translation = "for"
  token.l2_start_index = 31
  token.l2_end_index = 34
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 34,
  l1_end_index: 36
) do |token|
  token.translation = "my"
  token.l2_start_index = 35
  token.l2_end_index = 37
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 37,
  l1_end_index: 44
) do |token|
  token.translation = "bam bam"
  token.l2_start_index = 38
  token.l2_end_index = 45
end

phrase = phrases[37]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.translation = "Come"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 10
) do |token|
  token.translation = "taste"
  token.l2_start_index = 5
  token.l2_end_index = 10
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 21
) do |token|
  token.translation = "my mouth"
  token.l2_start_index = 11
  token.l2_end_index = 19
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 22,
  l1_end_index: 30
) do |token|
  token.questions = []
  token.translation = "to see"
  token.l2_start_index = 20
  token.l2_end_index = 26
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 31,
  l1_end_index: 35
) do |token|
  token.translation = "how"
  token.l2_start_index = 27
  token.l2_end_index = 30
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 36,
  l1_end_index: 38
) do |token|
  token.translation = "to you"
  token.l2_start_index = 41
  token.l2_end_index = 47
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 39,
  l1_end_index: 43
) do |token|
  token.questions = []
  token.translation = "tastes"
  token.l2_start_index = 34
  token.l2_end_index = 40
end

phrase = phrases[38]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "I want"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 8,
  l1_end_index: 14
) do |token|
  token.questions = []
  token.translation = "I want"
  token.l2_start_index = 8
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 16,
  l1_end_index: 22
) do |token|
  token.questions = []
  token.translation = "I want"
  token.l2_start_index = 16
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 26
) do |token|
  token.translation = "to see"
  token.l2_start_index = 23
  token.l2_end_index = 29
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 27,
  l1_end_index: 33
) do |token|
  token.questions = []
  token.translation = "how much"
  token.l2_start_index = 30
  token.l2_end_index = 38
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 34,
  l1_end_index: 38
) do |token|
  token.questions = []
  token.translation = "love"
  token.l2_start_index = 39
  token.l2_end_index = 43
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 39,
  l1_end_index: 43
) do |token|
  token.translation = "in you"
  token.l2_start_index = 49
  token.l2_end_index = 55
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 44,
  l1_end_index: 51
) do |token|
  token.translation = "fits in"
  token.l2_start_index = 44
  token.l2_end_index = 51
end

phrase = phrases[39]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 17
) do |token|
  token.translation = "I'm not in a hurry"
  token.l2_start_index = 0
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 21
) do |token|
  token.questions = []
  token.translation = "I"
  token.l2_start_index = 20
  token.l2_end_index = 21
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 22,
  l1_end_index: 44
) do |token|
  token.translation = "want to take the trip"
  token.l2_start_index = 22
  token.l2_end_index = 43
end

phrase = phrases[40]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.translation = "We start"
  token.l2_start_index = 0
  token.l2_end_index = 8
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 15
) do |token|
  token.translation = "slow"
  token.l2_start_index = 9
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 24
) do |token|
  token.translation = "then"
  token.l2_start_index = 15
  token.l2_end_index = 19
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "wild"
  token.l2_start_index = 20
  token.l2_end_index = 24
end

phrase = phrases[41]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.questions = []
  token.translation = "Step"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "by"
  token.l2_start_index = 5
  token.l2_end_index = 7
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 15
) do |token|
  token.questions = []
  token.translation = "step"
  token.l2_start_index = 8
  token.l2_end_index = 12
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 22
) do |token|
  token.questions = []
  token.translation = "soft"
  token.l2_start_index = 14
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "softly"
  token.l2_start_index = 19
  token.l2_end_index = 25
end

phrase = phrases[42]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.translation = "We"
  token.l2_start_index = 0
  token.l2_end_index = 2
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 17
) do |token|
  token.translation = "get closer"
  token.l2_start_index = 3
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 35
) do |token|
  token.translation = "little by little"
  token.l2_start_index = 14
  token.l2_end_index = 30
end

phrase = phrases[43]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "When"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 9
) do |token|
  token.translation = "you"
  token.l2_start_index = 5
  token.l2_end_index = 8
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 12
) do |token|
  token.translation = "me"
  token.l2_start_index = 14
  token.l2_end_index = 16
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 13,
  l1_end_index: 18
) do |token|
  token.questions = ["¿Qué haces tú?"]
  token.translation = "kiss"
  token.l2_start_index = 9
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 22
) do |token|
  token.questions = []
  token.translation = "with"
  token.l2_start_index = 17
  token.l2_end_index = 21
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 26
) do |token|
  token.questions = []
  token.translation = "that"
  token.l2_start_index = 22
  token.l2_end_index = 26
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 27,
  l1_end_index: 35
) do |token|
  token.translation = "skill"
  token.l2_start_index = 27
  token.l2_end_index = 32
end

phrase = phrases[44]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.translation = "I see"
  token.l2_start_index = 0
  token.l2_end_index = 5
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 8,
  l1_end_index: 12
) do |token|
  token.questions = []
  token.translation = "you are"
  token.l2_start_index = 6
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 13,
  l1_end_index: 20
) do |token|
  token.questions = []
  token.translation = "malice"
  token.l2_start_index = 14
  token.l2_end_index = 20
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 21,
  l1_end_index: 24
) do |token|
  token.questions = []
  token.translation = "with"
  token.l2_start_index = 21
  token.l2_end_index = 25
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 35
) do |token|
  token.questions = []
  token.translation = "delicacy"
  token.l2_start_index = 26
  token.l2_end_index = 34
end

phrase = phrases[45]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.questions = []
  token.translation = "Step"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "by"
  token.l2_start_index = 5
  token.l2_end_index = 7
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 15
) do |token|
  token.questions = []
  token.translation = "step"
  token.l2_start_index = 8
  token.l2_end_index = 12
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 22
) do |token|
  token.questions = []
  token.translation = "soft"
  token.l2_start_index = 14
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "softly"
  token.l2_start_index = 19
  token.l2_end_index = 25
end

phrase = phrases[46]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.translation = "We"
  token.l2_start_index = 0
  token.l2_end_index = 2
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 17
) do |token|
  token.translation = "get closer"
  token.l2_start_index = 3
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 36
) do |token|
  token.translation = "little by little"
  token.l2_start_index = 15
  token.l2_end_index = 31
end

phrase = phrases[47]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 1
) do |token|
  token.questions = []
  token.translation = "And"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 2,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "it's that"
  token.l2_start_index = 4
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 20
) do |token|
  token.questions = []
  token.translation = "this beauty"
  token.l2_start_index = 14
  token.l2_end_index = 25
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 21,
  l1_end_index: 23
) do |token|
  token.translation = "is"
  token.l2_start_index = 26
  token.l2_end_index = 28
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 24,
  l1_end_index: 39
) do |token|
  token.questions = []
  token.similar_sound = ['abrelatas']
  token.translation = "a puzzle"
  token.l2_start_index = 29
  token.l2_end_index = 37
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 40,
  l1_end_index: 47
) do |token|
  token.questions = []
  token.translation = "(oh no)"
  token.l2_start_index = 38
  token.l2_end_index = 45
end

phrase = phrases[48]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.questions = []
  token.translation = "But"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 5,
  l1_end_index: 17
) do |token|
  token.translation = "to put it together"
  token.l2_start_index = 4
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 22
) do |token|
  token.translation = "here"
  token.l2_start_index = 24
  token.l2_end_index = 28
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 28
) do |token|
  token.translation = "I have"
  token.l2_start_index = 29
  token.l2_end_index = 35
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 29,
  l1_end_index: 37
) do |token|
  token.questions = []
  token.questions = ["¿Qué tengo aquí?"]
  token.translation = "the piece"
  token.l2_start_index = 36
  token.l2_end_index = 45
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 38,
  l1_end_index: 53
) do |token|
  token.questions = []
  token.translation = "(slow, oh yeah)"
  token.l2_start_index = 46
  token.l2_end_index = 61
end

phrase = phrases[49]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "Slowly"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 19
) do |token|
  token.questions = []
  token.translation = "(yeh, yo)"
  token.l2_start_index = 7
  token.l2_end_index = 16
end

phrase = phrases[50]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "I want"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 15
) do |token|
  token.similar_sound = ['aspirar']
  token.translation = "to breathe"
  token.l2_start_index = 7
  token.l2_end_index = 17
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 16,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.translation = "your"
  token.l2_start_index = 18
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 25
) do |token|
  token.questions = []
  token.translation = "neck"
  token.l2_start_index = 23
  token.l2_end_index = 27
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 35
) do |token|
  token.questions = ["¿Cómo quiere respirar?"]
  token.translation = "slowly"
  token.l2_start_index = 28
  token.l2_end_index = 34
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 36,
  l1_end_index: 40
) do |token|
  token.questions = []
  token.translation = "(yo)"
  token.l2_start_index = 35
  token.l2_end_index = 39
end

phrase = phrases[51]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.translation = "Let"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 11
) do |token|
  token.questions = []
  token.translation = "you"
  token.l2_start_index = 12
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 12,
  l1_end_index: 16
) do |token|
  token.translation = "tell"
  token.l2_start_index = 7
  token.l2_end_index = 11
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 22
) do |token|
  token.translation = "things"
  token.l2_start_index = 16
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 30
) do |token|
  token.translation = "in your ear"
  token.l2_start_index = 23
  token.l2_end_index = 34
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 31,
  l1_end_index: 35
) do |token|
  token.translation = "(yo)"
  token.l2_start_index = 35
  token.l2_end_index = 39
end

phrase = phrases[52]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 8
) do |token|
  token.translation = "So"
  token.l2_start_index = 0
  token.l2_end_index = 2
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 20
) do |token|
  token.translation = "you remember"
  token.l2_start_index = 3
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 21,
  l1_end_index: 23
) do |token|
  token.questions = []
  token.translation = "if"
  token.l2_start_index = 16
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 24,
  l1_end_index: 32
) do |token|
  token.translation = "you're not"
  token.l2_start_index = 19
  token.l2_end_index = 29
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 33,
  l1_end_index: 40
) do |token|
  token.questions = ["¿Con quién no estás?"]
  token.translation = "with me"
  token.l2_start_index = 30
  token.l2_end_index = 37
end

phrase = phrases[53]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "Slowly"
  token.l2_start_index = 0
  token.l2_end_index = 6
end

phrase = phrases[54]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.questions = []
  token.translation = "I want to"
  token.l2_start_index = 0
  token.l2_end_index = 9
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 17
) do |token|
  token.questions = ["¿Qué quiero hacer?"]
  token.translation = "to undress you"
  token.l2_start_index = 7
  token.l2_end_index = 21
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 25
) do |token|
  token.questions = ["¿Cómo quiero desnudarte?"]
  token.translation = "with kisses"
  token.l2_start_index = 22
  token.l2_end_index = 33
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 35
) do |token|
  token.questions = []
  token.translation = "slowly"
  token.l2_start_index = 34
  token.l2_end_index = 40
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 36,
  l1_end_index: 41
) do |token|
  token.questions = []
  token.translation = "(yeh)"
  token.l2_start_index = 41
  token.l2_end_index = 46
end

phrase = phrases[55]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "Sign"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 18
) do |token|
  token.translation = "the walls"
  token.l2_start_index = 5
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 34
) do |token|
  token.questions = ["Whose labyrinth?"]
  token.translation = "of your labyrinth"
  token.l2_start_index = 15
  token.l2_end_index = 32
end

phrase = phrases[56]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 1
) do |token|
  token.questions = []
  token.translation = "And"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 2,
  l1_end_index: 20
) do |token|
  token.questions = []
  token.translation = "make your body"
  token.l2_start_index = 4
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 21,
  l1_end_index: 39
) do |token|
  token.translation = "a whole manuscript"
  token.l2_start_index = 19
  token.l2_end_index = 37
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 41,
  l1_end_index: 57
) do |token|
  token.questions = []
  token.translation = "up, up, up"
  token.l2_start_index = 39
  token.l2_end_index = 49
end

phrase = phrases[57]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 1,
  l1_end_index: 5
) do |token|
  token.questions = []
  token.translation = "Up"
  token.l2_start_index = 1
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 11
) do |token|
  token.questions = []
  token.translation = "up"
  token.l2_start_index = 5
  token.l2_end_index = 7
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 13,
  l1_end_index: 15
) do |token|
  token.questions = []
  token.translation = "Oh"
  token.l2_start_index = 9
  token.l2_end_index = 11
end

phrase = phrases[58]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "I want"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 10
) do |token|
  token.translation = "to see"
  token.l2_start_index = 7
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 17
) do |token|
  token.translation = "dance"
  token.l2_start_index = 24
  token.l2_end_index = 29
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 25
) do |token|
  token.questions = ["¿Qué baila?"]
  token.translation = "your hair"
  token.l2_start_index = 14
  token.l2_end_index = 23
end

phrase = phrases[59]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "I want"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 10
) do |token|
  token.translation = "to be"
  token.l2_start_index = 7
  token.l2_end_index = 12
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 13
) do |token|
  token.translation = "your"
  token.l2_start_index = 13
  token.l2_end_index = 17
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 14,
  l1_end_index: 19
) do |token|
  token.questions = []
  token.translation = "rhythm"
  token.l2_start_index = 18
  token.l2_end_index = 24
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 20,
  l1_end_index: 34
) do |token|
  token.questions = []
  token.translation = "(uh oh, uh oh)"
  token.l2_start_index = 25
  token.l2_end_index = 39
end

phrase = phrases[60]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.questions = []
  token.translation = "That"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 14
) do |token|
  token.translation = "teach"
  token.l2_start_index = 9
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 15,
  l1_end_index: 19
) do |token|
  token.questions = []
  token.translation = "my"
  token.l2_start_index = 15
  token.l2_end_index = 17
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 20,
  l1_end_index: 24
) do |token|
  token.questions = []
  token.translation = "mouth"
  token.l2_start_index = 18
  token.l2_end_index = 23
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 39
) do |token|
  token.questions = []
  token.translation = "(uh oh, uh oh)"
  token.l2_start_index = 24
  token.l2_end_index = 38
end

phrase = phrases[61]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.translation = "Your"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 11
) do |token|
  token.questions = []
  token.translation = "places"
  token.l2_start_index = 14
  token.l2_end_index = 20
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 12,
  l1_end_index: 21
) do |token|
  token.translation = "favorite"
  token.l2_start_index = 5
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "favorite"
  token.l2_start_index = 22
  token.l2_end_index = 30
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 34,
  l1_end_index: 43
) do |token|
  token.questions = []
  token.translation = "favorite"
  token.l2_start_index = 32
  token.l2_end_index = 40
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 44,
  l1_end_index: 48
) do |token|
  token.questions = []
  token.translation = "baby"
  token.l2_start_index = 41
  token.l2_end_index = 45
end

phrase = phrases[62]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "Let me"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 17
) do |token|
  token.translation = "overcome"
  token.l2_start_index = 7
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 21
) do |token|
  token.translation = "your"
  token.l2_start_index = 16
  token.l2_end_index = 20
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 22,
  l1_end_index: 27
) do |token|
  token.translation = "zones"
  token.l2_start_index = 28
  token.l2_end_index = 33
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 31,
  l1_end_index: 38
) do |token|
  token.questions = ["¿Qué tipo de zonas?"]
  token.translation = "danger"
  token.l2_start_index = 21
  token.l2_end_index = 27
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 39,
  l1_end_index: 53
) do |token|
  token.questions = []
  token.translation = "(uh oh, uh oh)"
  token.l2_start_index = 34
  token.l2_end_index = 48
end

phrase = phrases[63]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 5
) do |token|
  token.translation = "Until"
  token.l2_start_index = 0
  token.l2_end_index = 5
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 6,
  l1_end_index: 14
) do |token|
  token.translation = "make"
  token.l2_start_index = 9
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 15,
  l1_end_index: 18
) do |token|
  token.translation = "you"
  token.l2_start_index = 14
  token.l2_end_index = 17
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 25
) do |token|
  token.questions = []
  token.translation = "scream"
  token.l2_start_index = 18
  token.l2_end_index = 24
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 40
) do |token|
  token.questions = []
  token.translation = "(uh oh, uh oh)"
  token.l2_start_index = 25
  token.l2_end_index = 39
end

phrase = phrases[64]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 1
) do |token|
  token.questions = []
  token.translation = "And"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 6,
  l1_end_index: 13
) do |token|
  token.translation = "forget"
  token.l2_start_index = 8
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 14,
  l1_end_index: 16
) do |token|
  token.questions = []
  token.translation = "your"
  token.l2_start_index = 15
  token.l2_end_index = 19
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 25
) do |token|
  token.questions = ["¿Qué olvidas tú?"]
  token.translation = "last name"
  token.l2_start_index = 20
  token.l2_end_index = 29
end

phrase = phrases[65]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "Slowly"
  token.l2_start_index = 0
  token.l2_end_index = 6
end

phrase = phrases[66]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 7
) do |token|
  token.questions = []
  token.translation = "Let's"
  token.l2_start_index = 0
  token.l2_end_index = 5
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 8,
  l1_end_index: 15
) do |token|
  token.translation = "do it"
  token.l2_start_index = 6
  token.l2_end_index = 11
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 16,
  l1_end_index: 28
) do |token|
  token.questions = ["¿Dónde lo haremos?"]
  token.translation = "on a beach"
  token.l2_start_index = 12
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 29,
  l1_end_index: 43
) do |token|
  token.questions = []
  token.translation = "in Puerto Rico"
  token.l2_start_index = 23
  token.l2_end_index = 37
end

phrase = phrases[67]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "Until"
  token.l2_start_index = 0
  token.l2_end_index = 5
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.translation = "the waves"
  token.l2_start_index = 6
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 25
) do |token|
  token.translation = "scream"
  token.l2_start_index = 16
  token.l2_end_index = 22
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 27,
  l1_end_index: 38
) do |token|
  token.questions = []
  token.translation = "Oh, my goodness!"
  token.l2_start_index = 24
  token.l2_end_index = 40
end

phrase = phrases[68]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "So that"
  token.l2_start_index = 0
  token.l2_end_index = 7
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 11
) do |token|
  token.questions = []
  token.translation = "my"
  token.l2_start_index = 8
  token.l2_end_index = 10
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 12,
  l1_end_index: 17
) do |token|
  token.translation = "seal"
  token.l2_start_index = 11
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 26
) do |token|
  token.translation = "stays"
  token.l2_start_index = 16
  token.l2_end_index = 21
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 27,
  l1_end_index: 34
) do |token|
  token.translation = "with you"
  token.l2_start_index = 22
  token.l2_end_index = 30
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 36,
  l1_end_index: 43
) do |token|
  token.translation = "dance it"
  token.l2_start_index = 32
  token.l2_end_index = 40
end

phrase = phrases[69]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.questions = []
  token.translation = "Step"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "by"
  token.l2_start_index = 5
  token.l2_end_index = 7
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 15
) do |token|
  token.questions = []
  token.translation = "step"
  token.l2_start_index = 8
  token.l2_end_index = 12
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 22
) do |token|
  token.questions = []
  token.translation = "soft"
  token.l2_start_index = 14
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "softly"
  token.l2_start_index = 19
  token.l2_end_index = 25
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 33,
  l1_end_index: 49
) do |token|
  token.questions = []
  token.translation = "(hey yeah, yeah)"
  token.l2_start_index = 26
  token.l2_end_index = 42
end

phrase = phrases[70]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.translation = "We"
  token.l2_start_index = 0
  token.l2_end_index = 2
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 17
) do |token|
  token.translation = "get closer"
  token.l2_start_index = 3
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 36
) do |token|
  token.translation = "little by little"
  token.l2_start_index = 15
  token.l2_end_index = 31
end

phrase = phrases[71]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.questions = []
  token.translation = "That"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 14
) do |token|
  token.translation = "teach"
  token.l2_start_index = 9
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 15,
  l1_end_index: 24
) do |token|
  token.translation = "my mouth"
  token.l2_start_index = 15
  token.l2_end_index = 23
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 39
) do |token|
  token.questions = []
  token.translation = "(uh oh, uh oh)"
  token.l2_start_index = 24
  token.l2_end_index = 38
end

phrase = phrases[72]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.translation = "Your"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 11
) do |token|
  token.questions = []
  token.translation = "places"
  token.l2_start_index = 14
  token.l2_end_index = 20
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 12,
  l1_end_index: 21
) do |token|
  token.translation = "favorite"
  token.l2_start_index = 5
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "favorite"
  token.l2_start_index = 22
  token.l2_end_index = 30
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 34,
  l1_end_index: 48
) do |token|
  token.questions = []
  token.translation = "favorite baby"
  token.l2_start_index = 32
  token.l2_end_index = 45
end

phrase = phrases[73]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 15
) do |token|
  token.questions = []
  token.translation = "Step by step"
  token.l2_start_index = 0
  token.l2_end_index = 12
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "soft softly"
  token.l2_start_index = 14
  token.l2_end_index = 25
end

phrase = phrases[74]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.translation = "We"
  token.l2_start_index = 0
  token.l2_end_index = 2
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 17
) do |token|
  token.translation = "get closer"
  token.l2_start_index = 3
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 26
) do |token|
  token.questions = []
  token.translation = "little"
  token.l2_start_index = 15
  token.l2_end_index = 21
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 27,
  l1_end_index: 28
) do |token|
  token.questions = []
  token.translation = "by"
  token.l2_start_index = 22
  token.l2_end_index = 24
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 29,
  l1_end_index: 36
) do |token|
  token.questions = []
  token.translation = "little"
  token.l2_start_index = 25
  token.l2_end_index = 31
end

phrase = phrases[75]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 5
) do |token|
  token.translation = "Until"
  token.l2_start_index = 0
  token.l2_end_index = 5
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 6,
  l1_end_index: 14
) do |token|
  token.translation = "make"
  token.l2_start_index = 8
  token.l2_end_index = 12
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 15,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.translation = "you"
  token.l2_start_index = 13
  token.l2_end_index = 16
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 25
) do |token|
  token.questions = []
  token.translation = "scream"
  token.l2_start_index = 17
  token.l2_end_index = 23
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 33
) do |token|
  token.questions = []
  token.translation = "(eh-oh)"
  token.l2_start_index = 24
  token.l2_end_index = 31
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 34,
  l1_end_index: 41
) do |token|
  token.questions = []
  token.translation = "(Fonsi)"
  token.l2_start_index = 32
  token.l2_end_index = 39
end

phrase = phrases[76]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 1
) do |token|
  token.questions = []
  token.translation = "And"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 6,
  l1_end_index: 13
) do |token|
  token.translation = "forget"
  token.l2_start_index = 8
  token.l2_end_index = 14
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 14,
  l1_end_index: 16
) do |token|
  token.questions = []
  token.translation = "your"
  token.l2_start_index = 15
  token.l2_end_index = 19
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 25
) do |token|
  token.questions = []
  token.translation = "last name"
  token.l2_start_index = 20
  token.l2_end_index = 29
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 30
) do |token|
  token.questions = []
  token.translation = "(DY)"
  token.l2_start_index = 30
  token.l2_end_index = 34
end

phrase = phrases[77]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "Slowly"
  token.l2_start_index = 0
  token.l2_end_index = 6
end

# --- End token translation creation ---

# Create additional variables for token translations that will be used in activities
phrase = phrases[10]
t37 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 2
) do |token|
  token.questions = []
  token.translation = "Oh"
  token.l2_start_index = 0
  token.l2_end_index = 2
end
t38 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 6
) do |token|
  token.translation = "you"
  token.l2_start_index = 4
  token.l2_end_index = 7
end
t39 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 8,
  l1_end_index: 10
) do |token|
  token.questions = []
  token.translation = "you"
  token.l2_start_index = 9
  token.l2_end_index = 12
end
t40 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 15
) do |token|
  token.translation = "are"
  token.l2_start_index = 13
  token.l2_end_index = 16
end
t41 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 16,
  l1_end_index: 23
) do |token|
  token.similar_sound = ['hermano']
  token.translation = "the magnet"
  token.l2_start_index = 17
  token.l2_end_index = 27
end
t42 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 28
) do |token|
  token.translation = "I"
  token.l2_start_index = 32
  token.l2_end_index = 33
end
t43 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 29,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "am"
  token.l2_start_index = 34
  token.l2_end_index = 36
end
t44 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 33,
  l1_end_index: 41
) do |token|
  token.questions = ["¿Quién soy?"]
  token.translation = "the metal"
  token.l2_start_index = 37
  token.l2_end_index = 46
end

phrase = phrases[11]
t45 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 16
) do |token|
  token.translation = "I'm getting closer"
  token.l2_start_index = 0
  token.l2_end_index = 18
end
t46 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.translation = "and"
  token.l2_start_index = 19
  token.l2_end_index = 22
end
t47 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 30
) do |token|
  token.similar_sound = ['gritando']
  token.translation = "I'm making"
  token.l2_start_index = 23
  token.l2_end_index = 33
end
t48 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 31,
  l1_end_index: 38
) do |token|
  token.questions = ["¿Qué está armando?"]
  token.translation = "the plan"
  token.l2_start_index = 34
  token.l2_end_index = 42
end

phrase = phrases[12]
t49 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.questions = []
  token.translation = "Just"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
t50 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 5,
  l1_end_index: 17
) do |token|
  token.questions = ["¿Qué acelera el pulso?"]
  token.translation = "thinking about it"
  token.l2_start_index = 5
  token.l2_end_index = 22
end
t51 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 37
) do |token|
  token.translation = "makes my pulse race"
  token.l2_start_index = 23
  token.l2_end_index = 42
end
t52 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 38,
  l1_end_index: 47
) do |token|
  token.questions = []
  token.translation = "(oh yeah)"
  token.l2_start_index = 43
  token.l2_end_index = 52
end

phrase = phrases[13]
t53 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 2
) do |token|
  token.questions = []
  token.translation = "Now"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
t54 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 24
) do |token|
  token.translation = "I'm liking you"
  token.l2_start_index = 5
  token.l2_end_index = 19
end
t55 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 28
) do |token|
  token.questions = []
  token.translation = "more"
  token.l2_start_index = 20
  token.l2_end_index = 24
end
t56 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 29,
  l1_end_index: 41
) do |token|
  token.questions = []
  token.translation = "than normal"
  token.l2_start_index = 25
  token.l2_end_index = 36
end

phrase = phrases[14]
t57 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 5
) do |token|
  token.questions = []
  token.translation = "All"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
t58 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 6,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "my"
  token.l2_start_index = 4
  token.l2_end_index = 6
end
t59 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.similar_sound = ['sonidos']
  token.translation = "senses"
  token.l2_start_index = 7
  token.l2_end_index = 13
end
t60 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 31
) do |token|
  token.translation = "are asking"
  token.l2_start_index = 14
  token.l2_end_index = 24
end
t61 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 32,
  l1_end_index: 35
) do |token|
  token.questions = []
  token.translation = "more"
  token.l2_start_index = 29
  token.l2_end_index = 33
end

phrase = phrases[15]
t62 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.translation = "This"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
t63 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 5,
  l1_end_index: 12
) do |token|
  token.questions = []
  token.translation = "must be"
  token.l2_start_index = 5
  token.l2_end_index = 12
end
t64 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 13,
  l1_end_index: 20
) do |token|
  token.translation = "taken"
  token.l2_start_index = 13
  token.l2_end_index = 18
end
t66 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 31
) do |token|
  token.questions = []
  token.translation = "any"
  token.l2_start_index = 27
  token.l2_end_index = 30
end
t67 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 32,
  l1_end_index: 37
) do |token|
  token.questions = []
  token.translation = "rush"
  token.l2_start_index = 31
  token.l2_end_index = 35
end

phrase = phrases[16]
t68 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.similar_sound = ['movidito']
  token.translation = "Slowly"
  token.l2_start_index = 0
  token.l2_end_index = 6
end

phrase = phrases[17]
t69 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 15
) do |token|
  token.translation = "I want to breathe"
  token.l2_start_index = 0
  token.l2_end_index = 17
end
t70 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 16,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.translation = "your"
  token.l2_start_index = 18
  token.l2_end_index = 22
end
t71 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 25
) do |token|
  token.questions = ["¿Qué vas a respirar?"]
  token.translation = "neck"
  token.l2_start_index = 23
  token.l2_end_index = 27
end
t72 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 35
) do |token|
  token.similar_sound = ['cariñito']
  token.translation = "slowly"
  token.l2_start_index = 28
  token.l2_end_index = 34
end

phrase = phrases[18]
t73 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.translation = "Let"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
t74 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 11
) do |token|
  token.translation = "you"
  token.l2_start_index = 12
  token.l2_end_index = 15
end
t75 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 12,
  l1_end_index: 16
) do |token|
  token.translation = "tell"
  token.l2_start_index = 7
  token.l2_end_index = 11
end
t76 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 22
) do |token|
  token.translation = "things"
  token.l2_start_index = 16
  token.l2_end_index = 22
end
t77 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 30
) do |token|
  token.translation = "in your ear"
  token.l2_start_index = 23
  token.l2_end_index = 34
end

phrase = phrases[19]
t78 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "So"
  token.l2_start_index = 0
  token.l2_end_index = 2
end
t79 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 11
) do |token|
  token.questions = []
  token.translation = "you"
  token.l2_start_index = 3
  token.l2_end_index = 6
end
t80 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 12,
  l1_end_index: 20
) do |token|
  token.translation = "remember"
  token.l2_start_index = 7
  token.l2_end_index = 15
end
t81 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 21,
  l1_end_index: 23
) do |token|
  token.questions = []
  token.translation = "if"
  token.l2_start_index = 16
  token.l2_end_index = 18
end
t82 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 24,
  l1_end_index: 32
) do |token|
  token.questions = []
  token.translation = "you're not"
  token.l2_start_index = 19
  token.l2_end_index = 29
end
t83 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 33,
  l1_end_index: 40
) do |token|
  token.similar_sound = ['domingo']
  token.translation = "with me"
  token.l2_start_index = 30
  token.l2_end_index = 37
end

# Similar_sound attributes are now set directly in the creation blocks above

# Additional token translations for chorus lesson
phrase = phrases[20]
t84 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "Slowly"
  token.l2_start_index = 0
  token.l2_end_index = 6
end

phrase = phrases[21]
t85 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "I want"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
t86 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 15
) do |token|
  token.questions = []
  token.translation = "undress"
  token.l2_start_index = 10
  token.l2_end_index = 17
end
t87 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 15,
  l1_end_index: 17
) do |token|
  token.questions = []
  token.translation = "you"
  token.l2_start_index = 18
  token.l2_end_index = 21
end
t88 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 19
) do |token|
  token.questions = []
  token.translation = "with"
  token.l2_start_index = 22
  token.l2_end_index = 26
end
t89 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 20,
  l1_end_index: 25
) do |token|
  token.questions = []
  token.translation = "kisses"
  token.l2_start_index = 27
  token.l2_end_index = 33
end
t90 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 26,
  l1_end_index: 35
) do |token|
  token.questions = []
  token.translation = "slowly"
  token.l2_start_index = 34
  token.l2_end_index = 40
end

phrase = phrases[22]
t91 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.translation = "Sign"
  token.l2_start_index = 0
  token.l2_end_index = 4
end
t92 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 10
) do |token|
  token.questions = []
  token.translation = "the"
  token.l2_start_index = 5
  token.l2_end_index = 8
end
t93 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 18
) do |token|
  token.questions = ["¿Qué vas a firmar?"]
  token.similar_sound = ['pareces']
  token.translation = "walls"
  token.l2_start_index = 9
  token.l2_end_index = 14
end
t94 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 21
) do |token|
  token.questions = []
  token.translation = "of"
  token.l2_start_index = 15
  token.l2_end_index = 17
end
t95 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 22,
  l1_end_index: 24
) do |token|
  token.translation = "your"
  token.l2_start_index = 18
  token.l2_end_index = 22
end
t96 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 34
) do |token|
  token.translation = "labyrinth"
  token.l2_start_index = 23
  token.l2_end_index = 32
end

phrase = phrases[23]
t97 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 1
) do |token|
  token.questions = []
  token.translation = "And"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
t98 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 2,
  l1_end_index: 7
) do |token|
  token.translation = "make"
  token.l2_start_index = 4
  token.l2_end_index = 8
end
t99 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 20
) do |token|
  token.translation = "your body"
  token.l2_start_index = 9
  token.l2_end_index = 18
end
t100 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 21,
  l1_end_index: 39
) do |token|
  token.translation = "a whole manuscript"
  token.l2_start_index = 19
  token.l2_end_index = 37
end
t101 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 40,
  l1_end_index: 58
) do |token|
  token.questions = []
  token.translation = "(up, up, up)"
  token.l2_start_index = 38
  token.l2_end_index = 50
end

# Token translations for lesson 8 (outro)
phrase = phrases[66]
t202 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 7
) do |token|
  token.questions = []
  token.translation = "Let's"
  token.l2_start_index = 0
  token.l2_end_index = 5
end
t203 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 8,
  l1_end_index: 15
) do |token|
  token.translation = "do it"
  token.l2_start_index = 6
  token.l2_end_index = 11
end
t204 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 16,
  l1_end_index: 28
) do |token|
  token.questions = ["¿Dónde lo haremos?"]
  token.similar_sound = ['playa']
  token.translation = "on a beach"
  token.l2_start_index = 12
  token.l2_end_index = 22
end
t205 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 29,
  l1_end_index: 43
) do |token|
  token.questions = []
  token.translation = "in Puerto Rico"
  token.l2_start_index = 23
  token.l2_end_index = 37
end

phrase = phrases[67]
t206 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "Until"
  token.l2_start_index = 0
  token.l2_end_index = 5
end
t207 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.similar_sound = ['olas']
  token.translation = "the waves"
  token.l2_start_index = 6
  token.l2_end_index = 15
end
t208 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 25
) do |token|
  token.translation = "scream"
  token.l2_start_index = 16
  token.l2_end_index = 22
end
t209 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 27,
  l1_end_index: 38
) do |token|
  token.questions = []
  token.translation = "Oh, my goodness!"
  token.l2_start_index = 24
  token.l2_end_index = 40
end

phrase = phrases[68]
t210 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "So that"
  token.l2_start_index = 0
  token.l2_end_index = 7
end
t211 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 9,
  l1_end_index: 11
) do |token|
  token.questions = []
  token.translation = "my"
  token.l2_start_index = 8
  token.l2_end_index = 10
end
t212 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 12,
  l1_end_index: 17
) do |token|
  token.similar_sound = ['cello']
  token.translation = "seal"
  token.l2_start_index = 11
  token.l2_end_index = 15
end
t213 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 26
) do |token|
  token.translation = "stays"
  token.l2_start_index = 16
  token.l2_end_index = 21
end
t214 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 27,
  l1_end_index: 34
) do |token|
  token.translation = "with you"
  token.l2_start_index = 22
  token.l2_end_index = 30
end
t215 = TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 36,
  l1_end_index: 43
) do |token|
  token.translation = "dance it"
  token.l2_start_index = 32
  token.l2_end_index = 40
end

# Create lesson activities

## Lesson 1 - Intro
intro_watch_video = Activities::WatchVideoActivity.create!(lesson: l[0], order: 0)
intro_watch_video.phrases = phrases[0..9]

intro_match_activity = Activities::MatchPhrasesActivity.create!(lesson: l[0], text_header: 'Match each phrase to its translation', order: 2)
intro_match_activity.phrases = phrases[6..9]

intro_sort_phrases_activity = Activities::SortPhrasesActivity.create!(lesson: l[0], order: 3)
intro_sort_phrases_activity.phrases = phrases[6..9]

intro_language_alignment_activity = Activities::LanguageAlignmentActivity.create!(lesson: l[0], order: 4)
intro_language_alignment_activity.phrases = phrases[6..9]
intro_language_alignment_activity.token_translations = [
  t19, # un rato (key time expression)
  t22, # bailar (main verb)
  t29, # mirada (key noun)
  t35, # camino (key noun)
]

intro_speak_activity = Activities::SpeakActivity.create!(lesson: l[0], order: 5)
intro_speak_activity.phrases = phrases[6..9]

intro_listen_activity = Activities::ListenActivity.create!(lesson: l[0], order: 6, text_header: 'Listen and click on the missing word')
intro_listen_activity.phrases = phrases[6..9]
intro_listen_activity.token_translations = [
  t22, # bailar (most important verb)
  t35, # camino (distinctive noun)
]

## Lesson 2 - el imán y el metal
iman_watch_video = Activities::WatchVideoActivity.create!(lesson: l[1], order: 1)
iman_watch_video.phrases = phrases[10..15]

iman_match_activity = Activities::MatchPhrasesActivity.create!(lesson: l[1], text_header: 'Match each phrase to its translation', order: 2)
iman_match_activity.phrases = phrases[10..13]

iman_sort_phrases_activity = Activities::SortPhrasesActivity.create!(lesson: l[1], order: 3)
iman_sort_phrases_activity.phrases = phrases[10..13]

iman_language_alignment_activity = Activities::LanguageAlignmentActivity.create!(lesson: l[1], order: 4)
iman_language_alignment_activity.phrases = phrases[10..15]
iman_language_alignment_activity.token_translations = [
  t41, # el imán (key metaphor)
  t44, # el metal (key metaphor)
  t47, # voy armando (important verb)
  t48, # el plan (key noun)
  t50, # pensarlo (key verb)
  t54, # me estás gustando (key expression)
  t59, # sentidos (important noun)
  t67, # apuro (key concept)
]

iman_speak_activity = Activities::SpeakActivity.create!(lesson: l[1], order: 5)
iman_speak_activity.phrases = phrases[10..15]

iman_listen_activity = Activities::ListenActivity.create!(lesson: l[1], order: 6)
iman_listen_activity.phrases = phrases[10..15]
iman_listen_activity.token_translations = [
  t41, # el imán (distinctive and important)
  t47, # voy armando (challenging pronunciation)
  t59, # sentidos (key vocabulary)
]

## Lesson 3 - Chorus
chorus_watch_video = Activities::WatchVideoActivity.create!(lesson: l[2], order: 1)
chorus_watch_video.phrases = phrases[16..24]

chorus_match_activity = Activities::MatchPhrasesActivity.create!(lesson: l[2], text_header: 'Match each phrase to its translation', order: 2)
chorus_match_activity.phrases = phrases[16..19]

chorus_sort_phrases_activity = Activities::SortPhrasesActivity.create!(lesson: l[2], order: 3)
chorus_sort_phrases_activity.phrases = phrases[16..19]

chorus_language_alignment_activity = Activities::LanguageAlignmentActivity.create!(lesson: l[2], order: 4)
chorus_language_alignment_activity.phrases = phrases[16..24]
chorus_language_alignment_activity.token_translations = [
  t68, # Despacito (key word)
  t69, # quiero respirar (key phrase)
  t71, # cuello (key noun)
  t75, # diga (key verb)
  t77, # al oído (key phrase)
  t80, # acuerdes (key verb)
  t83, # conmigo (key phrase)
  t84, # Despacito (repeated)
  t85, # quiero (repeated key verb)
  t86, # desnudarte (intimate/key verb)
  t93, # paredes (key noun with similar_sound)
  t96, # laberinto (distinctive noun)
  t98, # hacer (key verb)
  t100, # manuscrito (distinctive/poetic noun)
]

chorus_speak_activity = Activities::SpeakActivity.create!(lesson: l[2], order: 5)
chorus_speak_activity.phrases = phrases[16..24]

chorus_listen_activity = Activities::ListenActivity.create!(lesson: l[2], order: 6)
chorus_listen_activity.phrases = phrases[16..24]
chorus_listen_activity.token_translations = [
  t72, # despacito (similar_sound: ['cariñito'])
  t83, # conmigo (similar_sound: ['domingo'])
  t93, # paredes (similar_sound: ['pareces'])
  t96, # laberinto (distinctive and challenging)
]

## Lesson 4 - Quiero ver bailar
bailar_watch_video = Activities::WatchVideoActivity.create!(lesson: l[3], order: 1)
bailar_watch_video.phrases = phrases[25..31]

bailar_match_activity = Activities::MatchPhrasesActivity.create!(lesson: l[3], text_header: 'Match each phrase to its translation', order: 2)
bailar_match_activity.phrases = phrases[25..28]

bailar_sort_phrases_activity = Activities::SortPhrasesActivity.create!(lesson: l[3], order: 3)
bailar_sort_phrases_activity.phrases = phrases[25..28]

bailar_language_alignment_activity = Activities::LanguageAlignmentActivity.create!(lesson: l[3], order: 4)
bailar_language_alignment_activity.phrases = phrases[25..31]
bailar_language_alignment_activity.token_translations = [
  TokenTranslation.find_by(phrase: phrases[25], l1_start_index: 11, l1_end_index: 17), # bailar (key verb)
  TokenTranslation.find_by(phrase: phrases[25], l1_start_index: 18, l1_end_index: 25), # tu pelo (distinctive image)
  TokenTranslation.find_by(phrase: phrases[26], l1_start_index: 14, l1_end_index: 19), # ritmo (key concept)
  TokenTranslation.find_by(phrase: phrases[27], l1_start_index: 15, l1_end_index: 24), # mi boca (intimate/distinctive)
  TokenTranslation.find_by(phrase: phrases[28], l1_start_index: 12, l1_end_index: 21), # favoritos (key adjective)
  TokenTranslation.find_by(phrase: phrases[29], l1_start_index: 7, l1_end_index: 17), # sobrepasar (challenging verb)
  TokenTranslation.find_by(phrase: phrases[30], l1_start_index: 19, l1_end_index: 25), # gritos (vivid noun)
  TokenTranslation.find_by(phrase: phrases[31], l1_start_index: 14, l1_end_index: 25), # tu apellido (distinctive phrase)
]

bailar_speak_activity = Activities::SpeakActivity.create!(lesson: l[3], order: 5)
bailar_speak_activity.phrases = phrases[25..31]

bailar_listen_activity = Activities::ListenActivity.create!(lesson: l[3], order: 6)
bailar_listen_activity.phrases = phrases[25..31]
bailar_listen_activity.token_translations = [
  TokenTranslation.find_by(phrase: phrases[25], l1_start_index: 11, l1_end_index: 17), # bailar
  TokenTranslation.find_by(phrase: phrases[26], l1_start_index: 14, l1_end_index: 19), # ritmo
  TokenTranslation.find_by(phrase: phrases[29], l1_start_index: 7, l1_end_index: 17), # sobrepasar
  TokenTranslation.find_by(phrase: phrases[31], l1_start_index: 14, l1_end_index: 25), # tu apellido
]

## Lesson 5 - Yo sé que estás pensándolo
pensando_watch_video = Activities::WatchVideoActivity.create!(lesson: l[4], order: 1)
pensando_watch_video.phrases = phrases[32..40]

pensando_match_activity = Activities::MatchPhrasesActivity.create!(lesson: l[4], text_header: 'Match each phrase to its translation', order: 2)
pensando_match_activity.phrases = phrases[32..36]

pensando_sort_phrases_activity = Activities::SortPhrasesActivity.create!(lesson: l[4], order: 3)
pensando_sort_phrases_activity.phrases = phrases[32..36]

pensando_language_alignment_activity = Activities::LanguageAlignmentActivity.create!(lesson: l[4], order: 4)
pensando_language_alignment_activity.phrases = phrases[32..40]
pensando_language_alignment_activity.token_translations = [
  TokenTranslation.find_by(phrase: phrases[32], l1_start_index: 3, l1_end_index: 5), # sé (key verb)
  TokenTranslation.find_by(phrase: phrases[33], l1_start_index: 0, l1_end_index: 25), # Llevo tiempo intentándolo (complete thought)
  TokenTranslation.find_by(phrase: phrases[34], l1_start_index: 0, l1_end_index: 4), # Mami (colloquial)
  TokenTranslation.find_by(phrase: phrases[34], l1_start_index: 14, l1_end_index: 19), # dando (key concept)
  TokenTranslation.find_by(phrase: phrases[35], l1_start_index: 13, l1_end_index: 20), # corazón (key noun)
  TokenTranslation.find_by(phrase: phrases[36], l1_start_index: 22, l1_end_index: 30), # buscando (key verb)
  TokenTranslation.find_by(phrase: phrases[37], l1_start_index: 4, l1_end_index: 10), # prueba (imperative)
  TokenTranslation.find_by(phrase: phrases[38], l1_start_index: 34, l1_end_index: 38), # amor (key concept)
  TokenTranslation.find_by(phrase: phrases[39], l1_start_index: 0, l1_end_index: 17), # no tengo prisa (important phrase)
  TokenTranslation.find_by(phrase: phrases[40], l1_start_index: 25, l1_end_index: 32), # salvaje (vivid adjective)
]

pensando_speak_activity = Activities::SpeakActivity.create!(lesson: l[4], order: 5)
pensando_speak_activity.phrases = phrases[32..40]

pensando_listen_activity = Activities::ListenActivity.create!(lesson: l[4], order: 6)
pensando_listen_activity.phrases = phrases[32..40]
pensando_listen_activity.token_translations = [
  TokenTranslation.find_by(phrase: phrases[33], l1_start_index: 0, l1_end_index: 25), # Llevo tiempo intentándolo
  TokenTranslation.find_by(phrase: phrases[35], l1_start_index: 13, l1_end_index: 20), # corazón
  TokenTranslation.find_by(phrase: phrases[36], l1_start_index: 22, l1_end_index: 30), # buscando
  TokenTranslation.find_by(phrase: phrases[38], l1_start_index: 34, l1_end_index: 38), # amor
  TokenTranslation.find_by(phrase: phrases[40], l1_start_index: 25, l1_end_index: 32), # salvaje
]

## Lesson 6 - Pasito a pasito
pasito_watch_video = Activities::WatchVideoActivity.create!(lesson: l[5], order: 1)
pasito_watch_video.phrases = phrases[41..48]

pasito_match_activity = Activities::MatchPhrasesActivity.create!(lesson: l[5], text_header: 'Match each phrase to its translation', order: 2)
pasito_match_activity.phrases = phrases[41..44]

pasito_sort_phrases_activity = Activities::SortPhrasesActivity.create!(lesson: l[5], order: 3)
pasito_sort_phrases_activity.phrases = phrases[41..44]

pasito_language_alignment_activity = Activities::LanguageAlignmentActivity.create!(lesson: l[5], order: 4)
pasito_language_alignment_activity.phrases = phrases[41..48]
pasito_language_alignment_activity.token_translations = [
  TokenTranslation.find_by(phrase: phrases[41], l1_start_index: 0, l1_end_index: 6), # Pasito (key rhythmic word)
  TokenTranslation.find_by(phrase: phrases[41], l1_start_index: 23, l1_end_index: 32), # suavecito (diminutive)
  TokenTranslation.find_by(phrase: phrases[42], l1_start_index: 4, l1_end_index: 17), # vamos pegando (key concept)
  TokenTranslation.find_by(phrase: phrases[43], l1_start_index: 13, l1_end_index: 18), # besas (intimate verb)
  TokenTranslation.find_by(phrase: phrases[43], l1_start_index: 27, l1_end_index: 35), # destreza (sophisticated noun)
  TokenTranslation.find_by(phrase: phrases[44], l1_start_index: 13, l1_end_index: 20), # malicia (complex concept)
  TokenTranslation.find_by(phrase: phrases[47], l1_start_index: 24, l1_end_index: 39), # un rompecabezas (metaphor)
  TokenTranslation.find_by(phrase: phrases[48], l1_start_index: 29, l1_end_index: 37), # la pieza (metaphor completion)
]

pasito_speak_activity = Activities::SpeakActivity.create!(lesson: l[5], order: 5)
pasito_speak_activity.phrases = phrases[41..48]

pasito_listen_activity = Activities::ListenActivity.create!(lesson: l[5], order: 6)
pasito_listen_activity.phrases = phrases[41..48]
pasito_listen_activity.token_translations = [
  TokenTranslation.find_by(phrase: phrases[41], l1_start_index: 0, l1_end_index: 6), # Pasito
  TokenTranslation.find_by(phrase: phrases[43], l1_start_index: 27, l1_end_index: 35), # destreza
  TokenTranslation.find_by(phrase: phrases[44], l1_start_index: 13, l1_end_index: 20), # malicia
  TokenTranslation.find_by(phrase: phrases[47], l1_start_index: 24, l1_end_index: 39), # un rompecabezas
]

## Lesson 7 - Outro
outro_watch_video = Activities::WatchVideoActivity.create!(lesson: l[6], order: 1)
outro_watch_video.phrases = phrases[65..68]

outro_match_activity = Activities::MatchPhrasesActivity.create!(lesson: l[6], text_header: 'Match each phrase to its translation', order: 2)
outro_match_activity.phrases = phrases[66..68]

outro_sort_phrases_activity = Activities::SortPhrasesActivity.create!(lesson: l[6], order: 3)
outro_sort_phrases_activity.phrases = phrases[66..68]

outro_language_alignment_activity = Activities::LanguageAlignmentActivity.create!(lesson: l[6], order: 4)
outro_language_alignment_activity.phrases = phrases[65..68]
outro_language_alignment_activity.token_translations = [
  t203, # hacerlo (key verb)
  t204, # en una playa (distinctive location)
  t207, # las olas (poetic/distinctive)
  t209, # "Ay, bendito" (cultural expression)
  t212, # sello (metaphorical)
  t215, # báilalo (imperative/action)
]

outro_speak_activity = Activities::SpeakActivity.create!(lesson: l[6], order: 5)
outro_speak_activity.phrases = phrases[65..68]

outro_listen_activity = Activities::ListenActivity.create!(lesson: l[6], order: 6)
outro_listen_activity.phrases = phrases[65..68]
outro_listen_activity.token_translations = [
  t204, # en una playa (distinctive)
  t212, # sello (challenging/metaphorical)
]

