en = Language.find_by(iso_name: 'en')
es = Language.find_by(iso_name: 'es')
medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=kJQP7kiw5Fk')

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

c = Course.find_or_create_by!(slug: 'despacito') do
  name = 'Despacito'
  main_media_url =  'https://www.youtube.com/watch?v=kJQP7kiw5Fk'
end
c.lessons.destroy_all

Lesson.where("slug like 'despacito%'").destroy_all
medium.phrases.destroy_all

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


l = [
  Lesson.create!(medium: medium, slug: 'despacito1', course: c, order: 0, name: 'Intro')                     ,
  Lesson.create!(medium: medium, slug: 'despacito2', course: c, order: 1, name: 'Si, sabes que')             ,
  Lesson.create!(medium: medium, slug: 'despacito3', course: c, order: 2, name: 'tú eres el imán')           ,
  Lesson.create!(medium: medium, slug: 'despacito4', course: c, order: 3, name: 'Chorus')                    ,
  Lesson.create!(medium: medium, slug: 'despacito5', course: c, order: 4, name: 'Quiero ver bailar')         ,
  Lesson.create!(medium: medium, slug: 'despacito6', course: c, order: 5, name: 'Yo sé que estás pensándolo'),
  Lesson.create!(medium: medium, slug: 'despacito7', course: c, order: 6, name: 'Pasito a pasito')           ,
  Lesson.create!(medium: medium, slug: 'despacito8', course: c, order: 7, name: 'Outro')                     ,
]

# phrases.each_with_index do |p, i|
#   puts "phrase = phrases[#{i}]"
#   p.create_mappings
#   puts ""
# end

phrase = phrases[0]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 4
) do |token|
  token.questions = []
  token.translation = "Oh!"
  token.l2_start_index = 0
  token.l2_end_index = 3
end

phrase = phrases[1]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 6
) do |token|
  token.questions = []
  token.translation = "Fonsi,"
  token.l2_start_index = 0
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "DY"
  token.l2_start_index = 7
  token.l2_end_index = 9
end

phrase = phrases[2]
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
  token.questions = []
  token.translation = "oh"
  token.l2_start_index = 4
  token.l2_end_index = 6
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "no"
  token.l2_start_index = 7
  token.l2_end_index = 9
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 11,
  l1_end_index: 13
) do |token|
  token.questions = []
  token.translation = "oh"
  token.l2_start_index = 11
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 14,
  l1_end_index: 16
) do |token|
  token.questions = []
  token.translation = "no"
  token.l2_start_index = 14
  token.l2_end_index = 16
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 18,
  l1_end_index: 20
) do |token|
  token.questions = []
  token.translation = "oh"
  token.l2_start_index = 18
  token.l2_end_index = 20
end

phrase = phrases[3]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.questions = []
  token.translation = "Hey"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "yeah"
  token.l2_start_index = 4
  token.l2_end_index = 8
end

phrase = phrases[4]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 8
) do |token|
  token.questions = []
  token.translation = "Diridiri"
  token.l2_start_index = 0
  token.l2_end_index = 8
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 18
) do |token|
  token.questions = []
  token.translation = "dirididi"
  token.l2_start_index = 10
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 19,
  l1_end_index: 24
) do |token|
  token.questions = []
  token.translation = "Daddy"
  token.l2_start_index = 19
  token.l2_end_index = 24
end

phrase = phrases[5]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 3
) do |token|
  token.translation = "Go!"
  token.l2_start_index = 0
  token.l2_end_index = 3
end

phrase = phrases[6]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 2
) do |token|
  token.questions = []
  token.translation = "Yes"
  token.l2_start_index = 0
  token.l2_end_index = 3
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 4,
  l1_end_index: 9
) do |token|
  # sabes
  token.translation = "you know"
  token.l2_start_index = 5
  token.l2_end_index = 13
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 13
) do |token|
  token.questions = []
  token.translation = "that"
  token.l2_start_index = 14
  token.l2_end_index = 18
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 22
) do |token|
  token.similar_sound = ['luego', 'nuevo']
  token.translation = "I've been"
  token.l2_start_index = 19
  token.l2_end_index = 28
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 23,
  l1_end_index: 30
) do |token|
  token.questions = ["¿Cuánto tiempo?"]
  token.similar_sound = ['un gato']
  token.translation = "for a while"
  token.l2_start_index = 44
  token.l2_end_index = 55
end

TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 31,
  l1_end_index: 40
) do |token|
  token.questions = ["¿Qué haces?"]
  token.translation = "looking at you"
  token.l2_start_index = 29
  token.l2_end_index = 43
end

phrase = phrases[7]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.translation = "I have to"
  token.l2_start_index = 0
  token.l2_end_index = 9
end

TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 16
) do |token|
  token.questions = ["¿Qué tienes que hacer?"]
  token.similar_sound = ['volar']
  token.translation = "dance"
  token.l2_start_index = 10
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 24
) do |token|
  token.questions = []
  token.translation = "with you"
  token.l2_start_index = 16
  token.l2_end_index = 24
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 25,
  l1_end_index: 28
) do |token|
  token.questions = ["¿Cuándo tienes que bailar contigo?"]
  token.translation = "today"
  token.l2_start_index = 25
  token.l2_end_index = 30
end

TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 29,
  l1_end_index: 33
) do |token|
  token.questions = []
  token.translation = "(DY)"
  token.l2_start_index = 31
  token.l2_end_index = 35
end

phrase = phrases[8]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 2
) do |token|
  token.translation = "I saw"
  token.l2_start_index = 0
  token.l2_end_index = 5
end

TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 3,
  l1_end_index: 6
) do |token|
  token.questions = []
  token.translation = "that"
  token.l2_start_index = 6
  token.l2_end_index = 10
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 7,
  l1_end_index: 9
) do |token|
  token.questions = []
  token.translation = "your"
  token.l2_start_index = 11
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 16
) do |token|
  token.similar_sound = ['cansada']
  token.translation = "look"
  token.l2_start_index = 16
  token.l2_end_index = 20
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 17,
  l1_end_index: 19
) do |token|
  token.questions = []
  token.translation = "already"
  token.l2_start_index = 25
  token.l2_end_index = 32
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 20,
  l1_end_index: 26
) do |token|
  token.questions = []
  token.translation = "was"
  token.l2_start_index = 21
  token.l2_end_index = 24
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 27,
  l1_end_index: 37
) do |token|
  token.questions = []
  token.translation = "calling me"
  token.l2_start_index = 33
  token.l2_end_index = 43
end

phrase = phrases[9]
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 9
) do |token|
  token.questions = ["¿Qué pide el hablante?"]
  token.translation = "Show me"
  token.l2_start_index = 0
  token.l2_end_index = 7
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 10,
  l1_end_index: 12
) do |token|
  token.questions = []
  token.translation = "the"
  token.l2_start_index = 8
  token.l2_end_index = 11
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 13,
  l1_end_index: 19
) do |token|
  token.similar_sound = ['destino']
  token.translation = "way"
  token.l2_start_index = 12
  token.l2_end_index = 15
end
TokenTranslation.find_or_create_by(
  phrase: phrase,
  l1_start_index: 20,
  l1_end_index: 30
) do |token|
  token.translation = "I'm going"
  token.l2_start_index = 17
  token.l2_end_index = 26
end

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
  l1_start_index: 21,
  l1_end_index: 37
) do |token|
  token.translation = "without any rush"
  token.l2_start_index = 19
  token.l2_end_index = 35
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
  token.similar_sound = ['jugares']
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

# Now create the activities

## Lesson 1 - Intro
intro_watch_video = Activities::WatchVideoActivity.create!(lesson: l[0], order: 1)
intro_watch_video.phrases = phrases[0..9]

intro_match_activity = Activities::MatchPhrasesActivity.create!(lesson: l[0], text_header: 'Match each phrase to its translation', order: 2)
intro_match_activity.phrases = phrases[6..9]

intro_sort_phrases_activity = Activities::SortPhrasesActivity.create!(lesson: l[0], order: 3)
intro_sort_phrases_activity.phrases = phrases[6..9]

intro_language_alignment_activity = Activities::LanguageAlignmentActivity.create!(lesson: l[0], order: 4)
intro_language_alignment_activity.phrases = phrases[6..9]
intro_language_alignment_activity.token_translations = [
  phrases[6].token_translations.find_by(translation: "you know"),
  phrases[6].token_translations.find_by(translation: "for a while"),
  phrases[7].token_translations.find_by(translation: "dance"),
  phrases[7].token_translations.find_by(translation: "today"),
  phrases[8].token_translations.find_by(translation: "calling me"),
  phrases[9].token_translations.find_by(translation: "Show me"),
  phrases[9].token_translations.find_by(translation: "way"),
]

intro_speak_activity = Activities::SpeakActivity.create!(lesson: l[0], order: 5)
intro_speak_activity.phrases = phrases[6..9]

intro_listen_activity = Activities::ListenActivity.create!(lesson: l[0], order: 6)
intro_listen_activity.phrases = phrases[6..9]
intro_listen_activity.token_translations = [
  phrases[6].token_translations.find_by(translation: "for a while"),
  phrases[7].token_translations.find_by(translation: "dance"),
  phrases[8].token_translations.find_by(translation: "look"),
  phrases[9].token_translations.find_by(translation: "way"),
]

