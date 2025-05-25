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
phrase.add_token_translation("¡Ay!", 0, "Oh!", 0, similar_sound: ['hay'])

# ["Fonsi, DY", "Fonsi, DY", "00:30"],
phrase = phrases[1]
phrase.add_token_translation("Fonsi,", 0, "Fonsi,", 0)
phrase.add_token_translation("DY", 0, "DY", 0)

#   ["Oh, oh no, oh no (oh)", "Oh, oh no, oh no (oh)", "00:33"],
phrase = phrases[2]
phrase.add_token_translation("Oh", 0, "Oh", 0) # first Oh -> Oh
phrase.add_token_translation("oh no", 0, "oh no", 0, similar_sound: ['o no']) # first oh no -> oh no
phrase.add_token_translation("oh no", 1, "oh no", 1) # second oh no -> oh n o
phrase.add_token_translation("oh", 2, "oh", 2) # second oh -> oh

# ["Hey yeah", "Hey yeah", "00:38"],
phrase = phrases[3]
phrase.add_token_translation("Hey", 0, "Hey", 0)
phrase.add_token_translation("yeah", 0, "yeah", 0, similar_sound: ['ya'])

# ["Diridiri, dirididi Daddy", "Diridiri, dirididi Daddy", "00:39"],
phrase = phrases[4]
phrase.add_token_translation("Diridiri", 0, "Diridiri", 0)
phrase.add_token_translation("dirididi", 0, "dirididi", 0)
phrase.add_token_translation("Daddy", 0, "Daddy", 0, similar_sound: ['dadi'])

# ["Go!", "Go!", "00:40"],
phrase = phrases[5]
phrase.add_token_translation("Go!", 0, "Go!", 0, similar_sound: ['gol'])

# ["Sí, sabes que ya llevo un rato mirándote", "Yes, you know that I've been looking at you for a while", "00:42"],
phrase = phrases[6]
phrase.add_token_translation("Sí", 0, "Yes", 0, questions: [], similar_sound: ['si'])
phrase.add_token_translation("sabes", 0, "you know", 0, similar_sound: ['saves'])
phrase.add_token_translation("que", 0, "that", 0, questions: [], similar_sound: ['qué'])
phrase.add_token_translation("ya", 0, "already", -1)
phrase.add_token_translation("llevo", 0, "I've been", 0, similar_sound: ['luego, nuevo'])
phrase.add_token_translation("un rato", 0, "for a while", 0, questions: ["¿Cuánto tiempo?"], similar_sound: ['un gato'])
phrase.add_token_translation("mirándote", 0, "looking at you", 0, questions: ["¿Qué haces?"], similar_sound: ['llorándote'])

# ["Tengo que bailar contigo hoy (DY)", "I have to dance with you today (DY)", "00:47"],
phrase = phrases[7]
t21 = phrase.add_token_translation("Tengo que", 0, "I have to", 0, similar_sound: ['tango que'])
t22 = phrase.add_token_translation("bailar", 0, "dance", 0, questions: ["¿Qué tienes que hacer?"], similar_sound: ['volar'])
t23 = phrase.add_token_translation("contigo", 0, "with you", 0, similar_sound: ['consigo'])
t24 = phrase.add_token_translation("hoy", 0, "today", 0, questions: ["¿Cuándo tienes que bailar contigo?"], similar_sound: ['voy', 'soy'])
t25 = phrase.add_token_translation("(DY)", 0, "(DY)", 0)

# ["Vi que tu mirada ya estaba llamándome", "I saw that your look was already calling me", "00:52"],
phrase = phrases[8]
phrase.add_token_translation("Vi", 0, "I saw", 0, similar_sound: ['bi', 've'])
phrase.add_token_translation("que", 0, "that", 0, questions: [], similar_sound: ['qué'])
phrase.add_token_translation("tu", 0, "your", 0, questions: [], similar_sound: ['tú'])
phrase.add_token_translation("mirada", 0, "look", 0, similar_sound: ['cansada'])
phrase.add_token_translation("ya", 0, "already", 0, questions: [], similar_sound: ['llá'])
phrase.add_token_translation("estaba", 0, "was", 0, questions: [], similar_sound: ['estado'])
phrase.add_token_translation("llamándome", 0, "calling me", 0, questions: [], similar_sound: ['llorándome'])

# ["Muéstrame el camino que yo voy", "Show me the way to go", "00:57"],
phrase = phrases[9]
phrase.add_token_translation("Muéstrame", 0, "Show me", 0, questions: ["¿Qué pide el hablante?"], similar_sound: ['muéstrale'])
phrase.add_token_translation("el", 0, "the", 0, similar_sound: ['él'])
phrase.add_token_translation("camino", 0, "way", 0, similar_sound: ['destino'])
phrase.add_token_translation("que yo voy", 0, "I'm going", -1, similar_sound: ['que yo soy'])

# ["Oh, tú, tú eres el imán y yo soy el metal", "Oh, you, you are the magnet and I am the metal", "01:02"],
phrase = phrases[10]
phrase.add_token_translation("Oh", 0, "Oh", 0, questions: [])
phrase.add_token_translation("tú", 0, "you", 0, similar_sound: ['tu'])
phrase.add_token_translation("tú", 1, "you", 1, questions: [])
phrase.add_token_translation("eres", 0, "are", 0, similar_sound: ['eras'])
phrase.add_token_translation("el imán", 0, "the magnet", 0, similar_sound: ['hermano'])
phrase.add_token_translation("yo", 0, "I", 0, similar_sound: ['llo'])
phrase.add_token_translation("soy", 0, "am", 0, questions: [], similar_sound: ['voy'])
phrase.add_token_translation("el metal", 0, "the metal", 0, questions: ["¿Quién soy?"], similar_sound: ['el medal'])

# ["Me voy acercando y voy armando el plan", "I'm getting closer and I'm making the plan", "01:06"],
phrase = phrases[11]
phrase.add_token_translation("Me voy acercando", 0, "I'm getting closer", 0, similar_sound: ['me voy esperando'])
phrase.add_token_translation("y", 0, "and", 0, questions: [])
phrase.add_token_translation("voy armando", 0, "I'm making", 0, similar_sound: ['voy gritando'])
phrase.add_token_translation("el plan", 0, "the plan", 0, questions: ["¿Qué está armando?"], similar_sound: ['el clan'])

# ["Solo con pensarlo se acelera el pulso (oh yeah)", "Just thinking about it makes my pulse race (oh yeah)", "01:09"],
phrase = phrases[12]
phrase.add_token_translation("Solo", 0, "Just", 0, questions: [], similar_sound: ['suelo'])
phrase.add_token_translation("con pensarlo", 0, "thinking about it", 0, questions: ["¿Qué acelera el pulso?"], similar_sound: ['sin pensarlo'])
phrase.add_token_translation("se acelera el pulso", 0, "makes my pulse race", 0, similar_sound: ['se acelera el curso'])
phrase.add_token_translation("(oh yeah)", 0, "(oh yeah)", 0, questions: [])

# ["Ya, ya me estás gustando más de lo normal", "Now, I'm liking you more than normal", "01:14"],
phrase = phrases[13]
phrase.add_token_translation("Ya", 0, "Now", 0, questions: [], similar_sound: ['llá'])
phrase.add_token_translation("ya me estás gustando", 0, "I'm liking you", 0, similar_sound: ['ya me estás gostando'])
phrase.add_token_translation("más", 0, "more", 0, questions: [], similar_sound: ['mas'])
phrase.add_token_translation("de lo normal", 0, "than normal", 0, questions: [], similar_sound: ['de lo formal'])

# ["Todos mis sentidos van pidiendo más", "All my senses are asking for more", "01:17"],
phrase = phrases[14]
phrase.add_token_translation("Todos", 0, "All", 0, questions: [], similar_sound: ['modos'])
phrase.add_token_translation("mis", 0, "my", 0, questions: [], similar_sound: ['bis'])
phrase.add_token_translation("sentidos", 0, "senses", 0, questions: [], similar_sound: ['sonidos'])
phrase.add_token_translation("van pidiendo", 0, "are asking", 0, similar_sound: ['van diciendo'])
phrase.add_token_translation("más", 0, "more", 0, questions: [])

# ["Esto hay que tomarlo sin ningún apuro", "This must be taken without any rush", "01:20"],
phrase = phrases[15]
phrase.add_token_translation("Esto", 0, "This", 0, similar_sound: ['esto'])
phrase.add_token_translation("hay que", 0, "must be", 0, questions: [], similar_sound: ['ay que'])
phrase.add_token_translation("tomarlo", 0, "taken", 0, similar_sound: ['jurarlo'])
phrase.add_token_translation("sin ningún", 0, "any", 0, questions: [], similar_sound: ['sin ninguno'])
phrase.add_token_translation("apuro", 0, "rush", 0, questions: [], similar_sound: ['seguro'])

# ["Despacito", "Slowly", "01:24"],
phrase = phrases[16]
phrase.add_token_translation("Despacito", 0, "Slowly", 0, questions: [], similar_sound: ['movidito'])

# ["Quiero respirar tu cuello despacito", "I want to breathe your neck slowly", "01:25"],
phrase = phrases[17]
phrase.add_token_translation("Quiero", 0, "I want to", 0, similar_sound: ['quiebro'])
phrase.add_token_translation("respirar", 0, "breathe", 0, similar_sound: ['respigar'])
phrase.add_token_translation("tu", 0, "your", 0, questions: [], similar_sound: ['tú'])
phrase.add_token_translation("cuello", 0, "neck", 0, questions: ["¿Qué vas a respirar?"], similar_sound: ['cuero'])
phrase.add_token_translation("despacito", 0, "slowly", 0, similar_sound: ['cariñito'])

# ["Deja que te diga cosas al oído", "Let me tell you things in your ear", "01:28"],
phrase = phrases[18]
phrase.add_token_translation("Deja", 0, "Let", 0, similar_sound: ['deba'])
phrase.add_token_translation("te", 0, "you", 0, similar_sound: ['de'])
phrase.add_token_translation("diga", 0, "tell", 0, similar_sound: ['dijo'])
phrase.add_token_translation("cosas", 0, "things", 0, similar_sound: ['rosas'])
phrase.add_token_translation("al oído", 0, "in your ear", 0, similar_sound: ['al olvido'])

# ["Para que te acuerdes si no estás conmigo", "So you remember if you're not with me", "01:31"],
phrase = phrases[19]
phrase.add_token_translation("Para que", 0, "So", 0, questions: [], similar_sound: ['para qué'])
phrase.add_token_translation("te", 0, "you", 0, questions: [], similar_sound: ['de'])
phrase.add_token_translation("acuerdes", 0, "remember", 0, similar_sound: ['amares'])
phrase.add_token_translation("si", 0, "if", 0, questions: [], similar_sound: ['sí'])
phrase.add_token_translation("no estás", 0, "you're not", 0, questions: [], similar_sound: ['no estas'])
phrase.add_token_translation("conmigo", 0, "with me", 0, similar_sound: ['domingo'])

# ["Despacito", "Slowly", "01:35"],
phrase = phrases[20]
phrase.add_token_translation("Despacito", 0, "Slowly", 0, questions: [], similar_sound: ['movidito'])

# ["Quiero desnudarte a besos despacito", "I want to undress you with kisses slowly", "01:36"],
phrase = phrases[21]
phrase.add_token_translation("Quiero", 0, "I want", 0, similar_sound: ['quiebro'])
phrase.add_token_translation("desnudarte", 0, "undress", 0, questions: [], similar_sound: ['desnudarme'])
phrase.add_token_translation("te", 0, "you", 0, questions: [], similar_sound: ['de'])
phrase.add_token_translation("a", 0, "with", 0, questions: [])
phrase.add_token_translation("besos", 0, "kisses", 0, questions: [], similar_sound: ['huesos'])
phrase.add_token_translation("despacito", 0, "slowly", 0, questions: [])

# ["Firmar las paredes de tu laberinto", "Sign the walls of your labyrinth", "01:39"],
phrase = phrases[22]
phrase.add_token_translation("Firmar", 0, "Sign", 0, similar_sound: ['formar'])
phrase.add_token_translation("las", 0, "the", 0, questions: [], similar_sound: ['los'])
phrase.add_token_translation("paredes", 0, "walls", 0, questions: ["¿Qué vas a firmar?"], similar_sound: ['pareces'])
phrase.add_token_translation("de", 0, "of", 0, questions: [], similar_sound: ['te'])
phrase.add_token_translation("tu", 0, "your", 0, similar_sound: ['tú'])
phrase.add_token_translation("laberinto", 0, "labyrinth", 0, similar_sound: ['laberindo'])

# ["Y hacer de tu cuerpo todo un manuscrito (sube, sube, sube)", "And make your body a whole manuscript (up, up, up)", "01:42"],
phrase = phrases[23]
phrase.add_token_translation("Y", 0, "And", 0, questions: [])
phrase.add_token_translation("hacer", 0, "make", 0, similar_sound: ['nacer'])
phrase.add_token_translation("de tu cuerpo", 0, "your body", 0, similar_sound: ['de tu cuerno'])
phrase.add_token_translation("todo", 0, "a whole", 0, similar_sound: ['modo'])
phrase.add_token_translation("un manuscrito", 0, "manuscript", 0, similar_sound: ['un manuscribo'])
phrase.add_token_translation("(sube, sube, sube)", 0, "(up, up, up)", 0, questions: [])

# ["(Sube, sube) Oh", "(Up, up) Oh", "01:45"],
phrase = phrases[24]
phrase.add_token_translation("Sube", 0, "Up", 0, questions: [], similar_sound: ['supe'])
phrase.add_token_translation("sube", 0, "up", 0, questions: [], similar_sound: ['sume'])
phrase.add_token_translation("Oh", 0, "Oh", 0, questions: [])

# ["Quiero ver bailar tu pelo", "I want to see your hair dance", "01:47"],
phrase = phrases[25]
phrase.add_token_translation("Quiero", 0, "I want", 0, questions: [], similar_sound: ['quiebro'])
phrase.add_token_translation("ver", 0, "to see", 0, similar_sound: ['ayer'])
phrase.add_token_translation("bailar", 0, "dance", 0, questions: [])
phrase.add_token_translation("tu pelo", 0, "your hair", 0, questions: ["¿Qué quiere ver bailar?"], similar_sound: ['tu vuelo'])

# ["Quiero ser tu ritmo (uh oh, uh oh)", "I want to be your rhythm (uh oh, uh oh)", "01:48"],
phrase = phrases[26]
phrase.add_token_translation("Quiero", 0, "I want", 0, questions: [], similar_sound: ['quiebro'])
phrase.add_token_translation("ser", 0, "to be", 0, questions: [], similar_sound: ['ver'])
phrase.add_token_translation("tu", 0, "your", 0, questions: [], similar_sound: ['tú'])
phrase.add_token_translation("ritmo", 0, "rhythm", 0, questions: [], similar_sound: ['mismo'])
phrase.add_token_translation("(uh oh, uh oh)", 0, "(uh oh, uh oh)", 0, questions: [])

# ["Que le enseñes a mi boca (uh oh, uh oh)", "That you teach my mouth (uh oh, uh oh)", "01:51"],
phrase = phrases[27]
phrase.add_token_translation("Que", 0, "That", 0, questions: [], similar_sound: ['qué'])
phrase.add_token_translation("enseñes", 0, "teach", 0, questions: [], similar_sound: ['enseñas'])
phrase.add_token_translation("a mi boca", 0, "my mouth", 0, questions: ["¿A quién enseñas?"], similar_sound: ['a mi coca'])
phrase.add_token_translation("(uh oh, uh oh)", 0, "(uh oh, uh oh)", 0, questions: [])

# ["Tus lugares favoritos (favoritos, favoritos baby)", "Your favorite places (favorite, favorite baby)", "01:53"],
phrase = phrases[28]
phrase.add_token_translation("Tus", 0, "Your", 0, questions: [], similar_sound: ['sus'])
phrase.add_token_translation("lugares", 0, "places", 0, questions: [], similar_sound: ['hogares'])
phrase.add_token_translation("favoritos", 0, "favorite", 0, questions: [], similar_sound: ['favoridos'])
phrase.add_token_translation("favoritos", 1, "favorite", 1, questions: [])
phrase.add_token_translation("favoritos baby", 0, "favorite baby", 0, questions: [])

# ["Déjame sobrepasar tus zonas de peligro (uh oh, uh oh)", "Let me overcome your danger zones (uh oh, uh oh)", "01:57"],
phrase = phrases[29]
phrase.add_token_translation("Déjame", 0, "Let me", 0, questions: [], similar_sound: ['déjale'])
phrase.add_token_translation("sobrepasar", 0, "overcome", 0, questions: [], similar_sound: ['sobrepagar'])
phrase.add_token_translation("tus", 0, "your", 0, similar_sound: ['sus'])
phrase.add_token_translation("zonas", 0, "zones", 0, similar_sound: ['monas'])
phrase.add_token_translation("peligro", 0, "danger", 0, similar_sound: ['pelirojo'])
phrase.add_token_translation("(uh oh, uh oh)", 0, "(uh oh, uh oh)", 0, questions: [])

# ["Hasta provocar tus gritos (uh oh, uh oh)", "Until I make you scream (uh oh, uh oh)", "02:00"],
phrase = phrases[30]
phrase.add_token_translation("Hasta", 0, "Until", 0, questions: [], similar_sound: ['asta'])
phrase.add_token_translation("provocar", 0, "make", 0, questions: [], similar_sound: ['procurar'])
phrase.add_token_translation("tus", 0, "you", 0, questions: [], similar_sound: ['sus'])
phrase.add_token_translation("gritos", 0, "scream", 0, questions: [], similar_sound: ['chicos'])
phrase.add_token_translation("(uh oh, uh oh)", 0, "(uh oh, uh oh)", 0, questions: [])

# ["Y que olvides tu apellido (dirididi Daddy)", "And you forget your last name (dirididi Daddy)", "02:03"],
phrase = phrases[31]
phrase.add_token_translation("Y", 0, "And", 0, questions: [])
phrase.add_token_translation("olvides", 0, "forget", 0, questions: [], similar_sound: ['que olvises'])
phrase.add_token_translation("tu", 0, "your", 0, similar_sound: ['tú'])
phrase.add_token_translation("apellido", 0, "last name", 0, questions: ["¿Qué olvidas tú?"], similar_sound: ['apellindo'])
phrase.add_token_translation("(dirididi Daddy)", 0, "(dirididi Daddy)", 0, questions: [])

# --- Create additional variables for token translations that will be used in activities ---

# ["Yo sé que estás pensándolo (eh)", "I know you're thinking about it (eh)", "02:08"],
phrase = phrases[32]
phrase.add_token_translation("Yo", 0, "I", 0, similar_sound: ['llo'])
phrase.add_token_translation("sé", 0, "know", 0, questions: [], similar_sound: ['se'])
phrase.add_token_translation("que estás", 0, "you're", 0, similar_sound: ['que estas'])
phrase.add_token_translation("pensándolo", 0, "thinking about it", 0, similar_sound: ['pesándolo'])
phrase.add_token_translation("(eh)", 0, "(eh)", 0, questions: [])

# ["Llevo tiempo intentándolo (eh)", "I've been trying for a while (eh)", "02:10"],
phrase = phrases[33]
phrase.add_token_translation("Llevo tiempo intentándolo", 0, "I've been trying for a while", 0, similar_sound: ['llevo tiempo inventándolo'])
phrase.add_token_translation("(eh)", 0, "(eh)", 0, questions: [])

# ["Mami, esto es dando y dándolo", "Mommy, this is giving and giving it", "02:11"],
phrase = phrases[34]
phrase.add_token_translation("Mami", 0, "Mommy", 0, similar_sound: ['mami'])
phrase.add_token_translation("esto", 0, "this", 0, similar_sound: ['estos'])
phrase.add_token_translation("es", 0, "is", 0, questions: [], similar_sound: ['es'])
phrase.add_token_translation("dando", 0, "giving", 0, questions: [], similar_sound: ['dando'])
phrase.add_token_translation("y", 0, "and", 0, questions: [])
phrase.add_token_translation("dándolo", 0, "giving it", 0, questions: [], similar_sound: ['dándolo'])

# ["Sabes que tu corazón conmigo te hace bam bam", "You know your heart with me goes bam bam", "02:13"],
phrase = phrases[35]
phrase.add_token_translation("Sabes", 0, "You know", 0, questions: [], similar_sound: ['saves'])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: ['qué'])
phrase.add_token_translation("tu", 0, "your", 0, similar_sound: ['tú'])
phrase.add_token_translation("corazón", 0, "heart", 0, questions: ["¿Qué late?"], similar_sound: ['corasón'])
phrase.add_token_translation("conmigo", 0, "with me", 0, questions: [], similar_sound: ['consigo'])
phrase.add_token_translation("te hace", 0, "goes", 0, similar_sound: ['te ace'])
phrase.add_token_translation("bam bam", 0, "bam bam", 0)

# ["Sabe que esa beba 'tá buscando de mi bam bam", "She knows that baby is looking for my bam bam", "02:15"],
phrase = phrases[36]
phrase.add_token_translation("Sabe", 0, "She knows", 0, similar_sound: ['save'])
phrase.add_token_translation("que", 0, "that", 0, questions: [], similar_sound: ['qué'])
phrase.add_token_translation("esa beba", 0, "baby", 0, similar_sound: ['esa beba'])
phrase.add_token_translation("'tá", 0, "is", 0, questions: [], similar_sound: ['esta'])
phrase.add_token_translation("buscando", 0, "looking", 0, similar_sound: ['buscando'])
phrase.add_token_translation("de", 0, "for", 0, questions: [], similar_sound: ['te'])
phrase.add_token_translation("mi", 0, "my", 0, similar_sound: ['me'])
phrase.add_token_translation("bam bam", 0, "bam bam", 0)

# ["Ven prueba de mi boca para ver cómo te sabe", "Come taste my mouth to see how it tastes to you", "02:18"],
phrase = phrases[37]
phrase.add_token_translation("Ven", 0, "Come", 0, similar_sound: ['ben'])
phrase.add_token_translation("prueba", 0, "taste", 0, similar_sound: ['prueva'])
phrase.add_token_translation("de mi boca", 0, "my mouth", 0, similar_sound: ['de mi coca'])
phrase.add_token_translation("para ver", 0, "to see", 0, questions: [], similar_sound: ['para ser'])
phrase.add_token_translation("cómo", 0, "how", 0, similar_sound: ['como'])
phrase.add_token_translation("te", 0, "to you", 0, similar_sound: ['de'])
phrase.add_token_translation("sabe", 0, "tastes", 0, questions: [], similar_sound: ['save'])

# ["Quiero, quiero, quiero ver cuánto amor a ti te cabe", "I want, I want, I want to see how much love fits in you", "02:21"],
phrase = phrases[38]
phrase.add_token_translation("Quiero", 0, "I want", 0, similar_sound: ['quiebro'])
phrase.add_token_translation("quiero", 0, "I want", 1, questions: [], similar_sound: ['quiebro'])
phrase.add_token_translation("quiero", 1, "I want", 2, questions: [], similar_sound: ['quiebro'])
phrase.add_token_translation("ver", 0, "to see", 0, similar_sound: ['ser'])
phrase.add_token_translation("cuánto", 0, "how much", 0, questions: [], similar_sound: ['cuando'])
phrase.add_token_translation("amor", 0, "love", 0, questions: [], similar_sound: ['humor'])
phrase.add_token_translation("a ti te", 0, "in you", 0, similar_sound: ['a ti de'])
phrase.add_token_translation("cabe", 0, "fits", 0, similar_sound: ['cave'])

# ["Yo no tengo prisa, yo me quiero dar el viaje", "I'm not in a hurry, I want to take the trip", "02:24"],
phrase = phrases[39]
phrase.add_token_translation("Yo no tengo prisa", 0, "I'm not in a hurry", 0, similar_sound: ['yo no tengo prida'])
phrase.add_token_translation("yo", 0, "I", 1, questions: [], similar_sound: ['llo'])
phrase.add_token_translation("me quiero dar el viaje", 0, "want to take the trip", 0, similar_sound: ['me quiero dar el viahe'])

# ["Empezamo' lento, después salvaje", "We start slow, then wild", "02:26"],
phrase = phrases[40]
phrase.add_token_translation("Empezamo'", 0, "We start", 0, similar_sound: ['empesamo'])
phrase.add_token_translation("lento", 0, "slow", 0, similar_sound: ['lendo'])
phrase.add_token_translation("después", 0, "then", 0, similar_sound: ['después'])
phrase.add_token_translation("salvaje", 0, "wild", 0, questions: [], similar_sound: ['salvage'])

# ["Pasito a pasito, suave suavecito", "Step by step, soft softly", "02:29"],
phrase = phrases[41]
phrase.add_token_translation("Pasito", 0, "Step", 0, questions: ["¿Cómo vamos?"], similar_sound: ['despacito'])
phrase.add_token_translation("a", 0, "by", 0, questions: [])
phrase.add_token_translation("pasito", 0, "step", 0, questions: [], similar_sound: ['pasido'])
phrase.add_token_translation("suave", 0, "soft", 0, questions: [], similar_sound: ['suabe'])
phrase.add_token_translation("suavecito", 0, "softly", 0, questions: [], similar_sound: ['suavesito'])

# ["Nos vamos pegando poquito a poquito", "We get closer little by little", "02:31"],
phrase = phrases[42]
phrase.add_token_translation("Nos", 0, "We", 0, similar_sound: ['los'])
phrase.add_token_translation("vamos pegando", 0, "get closer", 0, questions: ["¿Qué hacemos?"], similar_sound: ['vamos llegando'])
phrase.add_token_translation("poquito", 0, "little", 0, questions: [], similar_sound: ['poquido'])
phrase.add_token_translation("a", 0, "by", 0, questions: [])
phrase.add_token_translation("poquito", 1, "little", 1, questions: [], similar_sound: ['poquido'])

# ["Cuando tú me besas con esa destreza", "When you kiss me with that skill", "02:34"],
phrase = phrases[43]
phrase.add_token_translation("Cuando", 0, "When", 0, questions: [], similar_sound: ['cuando'])
phrase.add_token_translation("tú", 0, "you", 0, questions: [], similar_sound: ['tu'])
phrase.add_token_translation("me", 0, "me", 0, questions: [], similar_sound: ['te'])
phrase.add_token_translation("besas", 0, "kiss", 0, questions: ["¿Qué haces?"], similar_sound: ['besas'])
phrase.add_token_translation("con", 0, "with", 0, questions: [], similar_sound: ['son'])
phrase.add_token_translation("esa", 0, "that", 0, questions: [], similar_sound: ['esta'])
phrase.add_token_translation("destreza", 0, "skill", 0, questions: ["¿Con qué me besas?"], similar_sound: ['tristeza'])

# ["Veo que eres malicia con delicadeza", "I see you are malice with delicacy", "02:37"],
phrase = phrases[44]
phrase.add_token_translation("Veo", 0, "I see", 0, questions: [], similar_sound: ['veto'])
phrase.add_token_translation("que", 0, "that", 0, questions: [], similar_sound: ['qué'])
phrase.add_token_translation("eres", 0, "you are", 0, questions: [], similar_sound: ['eras'])
phrase.add_token_translation("malicia", 0, "malice", 0, questions: ["¿Qué eres?"], similar_sound: ['justicia'])
phrase.add_token_translation("con", 0, "with", 0, questions: [], similar_sound: ['son'])
phrase.add_token_translation("delicadeza", 0, "delicacy", 0, questions: ["¿Con qué?"], similar_sound: ['delicadesa'])

# ["Pasito a pasito, suave suavecito", "Step by step, soft softly", "02:40"],
phrase = phrases[45]
phrase.add_token_translation("Pasito", 0, "Step", 0, questions: [], similar_sound: ['pasido'])
phrase.add_token_translation("a", 0, "by", 0, questions: [])
phrase.add_token_translation("pasito", 0, "step", 0, questions: [], similar_sound: ['pasido'])
phrase.add_token_translation("suave", 0, "soft", 0, questions: [], similar_sound: ['suabe'])
phrase.add_token_translation("suavecito", 0, "softly", 0, questions: [], similar_sound: ['suavesito'])

# ["Nos vamos pegando, poquito a poquito (oh oh)", "We get closer, little by little (oh oh)", "02:42"],
phrase = phrases[46]
phrase.add_token_translation("Nos", 0, "We", 0, similar_sound: ['los'])
phrase.add_token_translation("vamos pegando", 0, "get closer", 0, questions: [], similar_sound: ['vamos llegando'])
phrase.add_token_translation("poquito", 0, "little", 0, questions: [], similar_sound: ['poquido'])
phrase.add_token_translation("a", 0, "by", 0, questions: [])
phrase.add_token_translation("poquito", 1, "little", 1, questions: [], similar_sound: ['poquido'])
phrase.add_token_translation("(oh oh)", 0, "(oh oh)", 0, questions: [])

# ["Y es que esa belleza es un rompecabezas (oh no)", "And it's that this beauty is a puzzle (oh no)", "02:45"],
phrase = phrases[47]
phrase.add_token_translation("Y es que", 0, "And it's that", 0, similar_sound: ['y es qué'])
phrase.add_token_translation("esa", 0, "this", 0, questions: [], similar_sound: ['esta'])
phrase.add_token_translation("belleza", 0, "beauty", 0, questions: ["¿Qué es un rompecabezas?"], similar_sound: ['tristeza'])
phrase.add_token_translation("es", 0, "is", 0, questions: [], similar_sound: ['es'])
phrase.add_token_translation("un rompecabezas", 0, "a puzzle", 0, questions: ["¿Qué es la belleza?"], similar_sound: ['un rompecabesas'])
phrase.add_token_translation("(oh no)", 0, "(oh no)", 0, questions: [])

# ["Pero pa' montarlo aquí tengo la pieza (slow, oh yeah)", "But to put it together, here I have the piece (slow, oh yeah)", "02:48"],
phrase = phrases[48]
phrase.add_token_translation("Pero", 0, "But", 0, questions: [], similar_sound: ['perro'])
phrase.add_token_translation("pa'", 0, "to", 0, questions: [], similar_sound: ['pa'])
phrase.add_token_translation("montarlo", 0, "put it together", 0, questions: ["¿Qué vas a hacer?"], similar_sound: ['montardo'])
phrase.add_token_translation("aquí", 0, "here", 0, questions: [], similar_sound: ['ahí'])
phrase.add_token_translation("tengo", 0, "I have", 0, questions: [], similar_sound: ['tango'])
phrase.add_token_translation("la pieza", 0, "the piece", 0, questions: ["¿Qué tienes?"], similar_sound: ['la piesa'])
phrase.add_token_translation("(slow, oh yeah)", 0, "(slow, oh yeah)", 0, questions: [])

# ["Despacito (yeh, yo)", "Slowly (yeh, yo)", "02:51"],
phrase = phrases[49]
phrase.add_token_translation("Despacito", 0, "Slowly", 0, questions: [])
phrase.add_token_translation("(yeh, yo)", 0, "(yeh, yo)", 0, questions: [])

# ["Quiero respirar tu cuello despacito (yo)", "I want to breathe your neck slowly (yo)", "02:53"],
phrase = phrases[50]
phrase.add_token_translation("Quiero", 0, "I want", 0, questions: [], similar_sound: ['quiebro'])
phrase.add_token_translation("respirar", 0, "to breathe", 0, questions: ["¿Qué quieres hacer?"], similar_sound: ['respigar'])
phrase.add_token_translation("tu", 0, "your", 0, questions: [], similar_sound: ['tú'])
phrase.add_token_translation("cuello", 0, "neck", 0, questions: [], similar_sound: ['cuero'])
phrase.add_token_translation("despacito", 0, "slowly", 0, questions: [], similar_sound: ['cariñito'])
phrase.add_token_translation("(yo)", 0, "(yo)", 0, questions: [])

# ["Deja que te diga cosas al oído (yo)", "Let me tell you things in your ear (yo)", "02:56"],
phrase = phrases[51]
phrase.add_token_translation("Deja", 0, "Let", 0, questions: [], similar_sound: ['deba'])
phrase.add_token_translation("que", 0, "me", 0, questions: [], similar_sound: ['qué'])
phrase.add_token_translation("te", 0, "you", 0, questions: [], similar_sound: ['de'])
phrase.add_token_translation("diga", 0, "tell", 0, questions: [], similar_sound: ['dijo'])
phrase.add_token_translation("cosas", 0, "things", 0, questions: [], similar_sound: ['rosas'])
phrase.add_token_translation("al oído", 0, "in your ear", 0, questions: ["¿Dónde te voy a decir cosas?"], similar_sound: ['al olvido'])
phrase.add_token_translation("(yo)", 0, "(yo)", 0, questions: [])

# ["Para que te acuerdes si no estás conmigo", "So you remember if you're not with me", "02:59"],
phrase = phrases[52]
phrase.add_token_translation("Para que", 0, "So", 0, questions: [], similar_sound: ['para qué'])
phrase.add_token_translation("te", 0, "you", 0, questions: [], similar_sound: ['de'])
phrase.add_token_translation("acuerdes", 0, "remember", 0, questions: ["¿Qué harás?"], similar_sound: ['amares'])
phrase.add_token_translation("si", 0, "if", 0, questions: [], similar_sound: ['sí'])
phrase.add_token_translation("no estás", 0, "you're not", 0, questions: [], similar_sound: ['no estas'])
phrase.add_token_translation("conmigo", 0, "with me", 0, questions: [], similar_sound: ['domingo'])

# ["Despacito", "Slowly", "03:03"],
phrase = phrases[53]
phrase.add_token_translation("Despacito", 0, "Slowly", 0, questions: [], similar_sound: ['movidito'])

# ["Quiero desnudarte a besos despacito (yeh)", "I want to undress you with kisses slowly (yeh)", "03:04"],
phrase = phrases[54]
phrase.add_token_translation("Quiero", 0, "I want", 0, questions: [], similar_sound: ['quiebro'])
phrase.add_token_translation("desnudarte", 0, "to undress you", 0, questions: [], similar_sound: ['desnudarme'])
phrase.add_token_translation("a besos", 0, "with kisses", 0, questions: ["¿Cómo quieres desnudarme?"], similar_sound: ['a huesos'])
phrase.add_token_translation("despacito", 0, "slowly", 0, questions: [], similar_sound: ['cariñito'])
phrase.add_token_translation("(yeh)", 0, "(yeh)", 0, questions: [])

# ["Firmar las paredes de tu laberinto", "Sign the walls of your labyrinth", "03:07"],
phrase = phrases[55]
phrase.add_token_translation("Firmar", 0, "Sign", 0, questions: ["¿Qué quieres hacer?"], similar_sound: ['formar'])
phrase.add_token_translation("las", 0, "the", 0, questions: [], similar_sound: ['los'])
phrase.add_token_translation("paredes", 0, "walls", 0, questions: ["¿Qué vas a firmar?"], similar_sound: ['pareces'])
phrase.add_token_translation("de", 0, "of", 0, questions: [], similar_sound: ['te'])
phrase.add_token_translation("tu", 0, "your", 0, questions: [], similar_sound: ['tú'])
phrase.add_token_translation("laberinto", 0, "labyrinth", 0, questions: ["¿De qué son las paredes?"], similar_sound: ['laberindo'])

# ["Y hacer de tu cuerpo todo un manuscrito (sube, sube, sube)", "And make your body a whole manuscript (up, up, up)", "03:10"],
phrase = phrases[56]
phrase.add_token_translation("Y", 0, "And", 0, questions: [])
phrase.add_token_translation("hacer", 0, "make", 0, similar_sound: ['nacer'])
phrase.add_token_translation("de tu cuerpo", 0, "your body", 0, similar_sound: ['de tu cuerno'])
phrase.add_token_translation("todo un manuscrito", 0, "a whole manuscript", 0, questions: ["¿Qué quieres hacer de mi cuerpo?"], similar_sound: ['todo un manuscribo'])
phrase.add_token_translation("(sube, sube, sube)", 0, "(up, up, up)", 0, questions: [])

# ["(Sube, sube) Oh", "(Up, up) Oh", "03:13"],
phrase = phrases[57]
phrase.add_token_translation("(Sube, sube)", 0, "(Up, up)", 0, questions: [], similar_sound: ['supe, supe'])
phrase.add_token_translation("Oh", 0, "Oh", 0, questions: [])

# ["Quiero ver bailar tu pelo", "I want to see your hair dance", "03:14"],
phrase = phrases[58]
phrase.add_token_translation("Quiero", 0, "I want", 0, questions: [], similar_sound: ['quiebro'])
phrase.add_token_translation("ver", 0, "to see", 0, questions: [], similar_sound: ['dar'])
phrase.add_token_translation("bailar", 0, "dance", 0, questions: [], similar_sound: ['volar'])
phrase.add_token_translation("tu pelo", 0, "your hair", 0, questions: ["¿Qué quieres ver bailar?"])

# ["Quiero ser tu ritmo (uh oh, uh oh)", "I want to be your rhythm (uh oh, uh oh)", "03:16"],
phrase = phrases[59]
phrase.add_token_translation("Quiero", 0, "I want", 0, questions: [], similar_sound: ['quiebro'])
phrase.add_token_translation("ser", 0, "to be", 0, questions: [], similar_sound: ['ver'])
phrase.add_token_translation("tu", 0, "your", 0, questions: [], similar_sound: ['tú'])
phrase.add_token_translation("ritmo", 0, "rhythm", 0, questions: ["¿Qué quieres ser?"], similar_sound: ['mismo'])
phrase.add_token_translation("(uh oh, uh oh)", 0, "(uh oh, uh oh)", 0, questions: [])

# ["Que le enseñes a mi boca (uh oh, uh oh)", "That you teach my mouth (uh oh, uh oh)", "03:19"],
phrase = phrases[60]
phrase.add_token_translation("Que", 0, "That", 0, questions: [], similar_sound: ['qué'])
phrase.add_token_translation("le", 0, "", 0, questions: [])
phrase.add_token_translation("enseñes", 0, "teach", 0, questions: [], similar_sound: ['enseñas'])
phrase.add_token_translation("a mi boca", 0, "my mouth", 0, questions: [], similar_sound: ['a mi coca'])
phrase.add_token_translation("(uh oh, uh oh)", 0, "(uh oh, uh oh)", 0, questions: [])

# ["Tus lugares favoritos (favoritos, favoritos baby)", "Your favorite places (favorite, favorite baby)", "03:21"],
phrase = phrases[61]
phrase.add_token_translation("Tus", 0, "Your", 0, questions: [])
phrase.add_token_translation("lugares", 0, "places", 0, questions: [], similar_sound: ['hogares'])
phrase.add_token_translation("favoritos", 0, "favorite", 0, questions: [])
phrase.add_token_translation("(favoritos, favoritos baby)", 0, "(favorite, favorite baby)", 0, questions: [])

# ["Déjame sobrepasar tus zonas de peligro (uh oh, uh oh)", "Let me overcome your danger zones (uh oh, uh oh)", "03:25"],
phrase = phrases[62]
phrase.add_token_translation("Déjame", 0, "Let me", 0, questions: [])
phrase.add_token_translation("sobrepasar", 0, "overcome", 0, questions: [])
phrase.add_token_translation("tus", 0, "your", 0)
phrase.add_token_translation("zonas", 0, "zones", 0, similar_sound: ['monas'])
phrase.add_token_translation("peligro", 0, "danger", 0)
phrase.add_token_translation("(uh oh, uh oh)", 0, "(uh oh, uh oh)", 0, questions: [])

# ["Hasta provocar tus gritos (uh oh, uh oh)", "Until I make you scream (uh oh, uh oh)", "03:28"],
phrase = phrases[63]
phrase.add_token_translation("Hasta", 0, "Until", 0, questions: [])
phrase.add_token_translation("provocar", 0, "I make", 0, questions: [])
phrase.add_token_translation("tus", 0, "you", 0, questions: [])
phrase.add_token_translation("gritos", 0, "scream", 0, questions: [], similar_sound: ['chicos'])
phrase.add_token_translation("(uh oh, uh oh)", 0, "(uh oh, uh oh)", 0, questions: [])

# ["Y que olvides tu apellido", "And you forget your last name", "03:31"],
phrase = phrases[64]
phrase.add_token_translation("Y que", 0, "And", 0, questions: [])
phrase.add_token_translation("olvides", 0, "forget", 0, questions: [], similar_sound: ['olvises'])
phrase.add_token_translation("tu apellido", 0, "your last name", 0, questions: ["¿Qué olvidas?"])

# ["Despacito", "Slowly", "03:35"],
phrase = phrases[65]
phrase.add_token_translation("Despacito", 0, "Slowly", 0, questions: [], similar_sound: ['movidito'])

# ["Vamo' a hacerlo en una playa en Puerto Rico", "Let's do it on a beach in Puerto Rico", "03:36"],
phrase = phrases[66]
phrase.add_token_translation("Vamo'", 0, "Let's", 0, questions: [], similar_sound: ['vamos'])
phrase.add_token_translation("a", 0, "", 0, questions: [])
phrase.add_token_translation("hacerlo", 0, "do it", 0, questions: ["¿Qué vamos a hacer?"], similar_sound: ['aserto'])
phrase.add_token_translation("en una playa", 0, "on a beach", 0, questions: ["¿Dónde lo vamos a hacer?"], similar_sound: ['en una raya'])
phrase.add_token_translation("en", 1, "in", 0, questions: [])
phrase.add_token_translation("Puerto Rico", 0, "Puerto Rico", 0, questions: ["¿En qué país?"])

# ["Hasta que las olas griten \"Ay, bendito\"", "Until the waves scream \"Oh, my goodness!\"", "03:39"],
phrase = phrases[67]
phrase.add_token_translation("Hasta que", 0, "Until", 0, questions: [])
phrase.add_token_translation("las olas", 0, "the waves", 0, questions: ["¿Qué va a gritar?"], similar_sound: ['las horas'])
phrase.add_token_translation("griten", 0, "scream", 0, questions: ["¿Qué hacen las olas?"], similar_sound: ['griten'])
phrase.add_token_translation("\"Ay, bendito\"", 0, "\"Oh, my goodness!\"", 0, questions: ["¿Qué gritan las olas?"], similar_sound: ['ay vendito'])

# ["Para que mi sello se quede contigo (báilalo)", "So that my seal stays with you (dance it)", "03:42"],
phrase = phrases[68]
phrase.add_token_translation("Para que", 0, "So that", 0, questions: [])
phrase.add_token_translation("mi sello", 0, "my seal", 0, questions: ["¿Qué se queda contigo?"], similar_sound: ['mi sero'])
phrase.add_token_translation("se quede", 0, "stays", 0, questions: [], similar_sound: ['se quese'])
phrase.add_token_translation("contigo", 0, "with you", 0, questions: [])
phrase.add_token_translation("(báilalo)", 0, "(dance it)", 0, questions: [], similar_sound: ['bájalo'])

# ["Pasito a pasito, suave suavecito (hey yeah, yeah)", "Step by step, soft softly (hey yeah, yeah)", "03:46"],
phrase = phrases[69]
phrase.add_token_translation("Pasito", 0, "Step", 0, questions: [])
phrase.add_token_translation("a", 0, "by", 0, questions: [])
phrase.add_token_translation("pasito", 0, "step", 0, questions: [])
phrase.add_token_translation("suave", 0, "soft", 0, questions: [])
phrase.add_token_translation("suavecito", 0, "softly", 0, questions: [])
phrase.add_token_translation("(hey yeah, yeah)", 0, "(hey yeah, yeah)", 0, questions: [])

# ["Nos vamos pegando, poquito a poquito (oh no)", "We get closer, little by little (oh no)", "03:48"],
phrase = phrases[70]
phrase.add_token_translation("Nos", 0, "We", 0, similar_sound: ['los'])
phrase.add_token_translation("vamos pegando", 0, "get closer", 0, questions: [], similar_sound: ['vamos llegando'])
phrase.add_token_translation("poquito", 0, "little", 0, questions: [], similar_sound: ['poquido'])
phrase.add_token_translation("a", 0, "by", 0, questions: [])
phrase.add_token_translation("poquito", 1, "little", 1, questions: [], similar_sound: ['poquido'])
phrase.add_token_translation("(oh no)", 0, "(oh no)", 0, questions: [])

# ["Que le enseñes a mi boca (uh oh, uh oh)", "That you teach my mouth (uh oh, uh oh)", "03:51"],
phrase = phrases[71]
phrase.add_token_translation("Que", 0, "That", 0, questions: [])
phrase.add_token_translation("le", 0, "", 0, questions: [])
phrase.add_token_translation("enseñes", 0, "teach", 0, questions: [])
phrase.add_token_translation("a mi boca", 0, "my mouth", 0, questions: [])
phrase.add_token_translation("(uh oh, uh oh)", 0, "(uh oh, uh oh)", 0, questions: [])

# ["Tus lugares favoritos (favoritos, favoritos baby)", "Your favorite places (favorite, favorite baby)", "03:54"],
phrase = phrases[72]
phrase.add_token_translation("Tus", 0, "Your", 0, questions: [])
phrase.add_token_translation("lugares", 0, "places", 0, questions: [])
phrase.add_token_translation("favoritos", 0, "favorite", 0, questions: [])
phrase.add_token_translation("(favoritos, favoritos baby)", 0, "(favorite, favorite baby)", 0, questions: [])

# ["Pasito a pasito, suave suavecito", "Step by step, soft softly", "03:57"],
phrase = phrases[73]
phrase.add_token_translation("Pasito", 0, "Step", 0, questions: [])
phrase.add_token_translation("a", 0, "by", 0, questions: [])
phrase.add_token_translation("pasito", 0, "step", 0, questions: [])
phrase.add_token_translation("suave", 0, "soft", 0, questions: [])
phrase.add_token_translation("suavecito", 0, "softly", 0, questions: [])

# ["Nos vamos pegando, poquito a poquito", "We get closer, little by little", "03:59"],
phrase = phrases[74]
phrase.add_token_translation("Nos", 0, "We", 0, similar_sound: ['los'])
phrase.add_token_translation("vamos pegando", 0, "get closer", 0, questions: [], similar_sound: ['vamos llegando'])
phrase.add_token_translation("poquito", 0, "little", 0, questions: [], similar_sound: ['poquido'])
phrase.add_token_translation("a", 0, "by", 0, questions: [])
phrase.add_token_translation("poquito", 1, "little", 1, questions: [], similar_sound: ['poquido'])

# ["Hasta provocar tus gritos (eh-oh) (Fonsi)", "Until I make you scream (eh-oh) (Fonsi)", "04:02"],
phrase = phrases[75]
phrase.add_token_translation("Hasta", 0, "Until", 0, questions: [], similar_sound: ['asta'])
phrase.add_token_translation("provocar", 0, "I make", 0, questions: [], similar_sound: ['procurar'])
phrase.add_token_translation("tus", 0, "you", 0, questions: [], similar_sound: ['sus'])
phrase.add_token_translation("gritos", 0, "scream", 0, questions: [], similar_sound: ['chicos'])
phrase.add_token_translation("(eh-oh)", 0, "(eh-oh)", 0, questions: [])
phrase.add_token_translation("(Fonsi)", 0, "(Fonsi)", 0, questions: [])

# ["Y que olvides tu apellido (DY)", "And you forget your last name (DY)", "04:05"],
phrase = phrases[76]
phrase.add_token_translation("Y que", 0, "And", 0, questions: [], similar_sound: ['y qué'])
phrase.add_token_translation("olvides", 0, "forget", 0, questions: [], similar_sound: ['olvises'])
phrase.add_token_translation("tu apellido", 0, "your last name", 0, questions: [], similar_sound: ['tu apellindo'])
phrase.add_token_translation("(DY)", 0, "(DY)", 0, questions: [])

# ["Despacito", "Slowly", "04:07"],
phrase = phrases[77]
phrase.add_token_translation("Despacito", 0, "Slowly", 0, questions: [], similar_sound: ['movidito'])



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
  phrases[6].find_token_translation("sabes"), # sabes - key verb "you know"
  phrases[6].find_token_translation("un rato"), # un rato - time expression
  phrases[7].find_token_translation("Tengo que"), # Tengo que - "I have to"
  phrases[7].find_token_translation("bailar"), # bailar - main verb "dance"
  phrases[8].find_token_translation("mirada"), # mirada - key noun "look"
  phrases[8].find_token_translation("llamándome"), # llamándome - "calling me"
  phrases[9].find_token_translation("Muéstrame"), # Muéstrame - imperative "show me"
  phrases[9].find_token_translation("camino"), # camino - "way/path"
]

intro_speak_activity = Activities::SpeakActivity.create!(lesson: l[0], order: 5)
intro_speak_activity.phrases = phrases[6..9]

intro_listen_activity = Activities::ListenActivity.create!(lesson: l[0], order: 6, text_header: 'Listen and click on the missing word')
intro_listen_activity.phrases = phrases[6..9]
intro_listen_activity.token_translations = [
  phrases[6].find_token_translation("sabes"), # sabes (has similar_sound: ['saves'])
  phrases[7].find_token_translation("bailar"), # bailar (has similar_sound: ['volar'])
  phrases[8].find_token_translation("mirada"), # mirada (has similar_sound: ['cansada'])
  phrases[9].find_token_translation("camino"), # camino (has similar_sound: ['destino'])
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
  phrases[10].find_token_translation("el imán"), # el imán - key metaphor "the magnet"
  phrases[10].find_token_translation("el metal"), # el metal - key metaphor "the metal"
  phrases[11].find_token_translation("voy armando"), # voy armando - "I'm making"
  phrases[11].find_token_translation("el plan"), # el plan - "the plan"
  phrases[12].find_token_translation("Solo"), # Solo - "just"
  phrases[12].find_token_translation("con pensarlo"), # con pensarlo - "thinking about it"
  phrases[13].find_token_translation("ya me estás gustando"), # ya me estás gustando - "I'm liking you"
  phrases[13].find_token_translation("más"), # más - "more"
  phrases[14].find_token_translation("sentidos"), # sentidos - "senses"
  phrases[14].find_token_translation("van pidiendo"), # van pidiendo - "are asking"
  phrases[15].find_token_translation("tomarlo"), # tomarlo - "take it"
  phrases[15].find_token_translation("apuro"), # apuro - "rush"
]

iman_speak_activity = Activities::SpeakActivity.create!(lesson: l[1], order: 5)
iman_speak_activity.phrases = phrases[10..15]

iman_listen_activity = Activities::ListenActivity.create!(lesson: l[1], order: 6)
iman_listen_activity.phrases = phrases[10..15]
iman_listen_activity.token_translations = [
  phrases[10].find_token_translation("el imán"), # el imán (has similar_sound: ['hermano'])
  phrases[11].find_token_translation("voy armando"), # voy armando (has similar_sound: ['voy gritando'])
  phrases[12].find_token_translation("Solo"), # Solo (has similar_sound: ['suelo'])
  phrases[14].find_token_translation("sentidos"), # sentidos (has similar_sound: ['sonidos'])
  phrases[15].find_token_translation("apuro"), # apuro (has similar_sound: ['seguro'])
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
  phrases[16].find_token_translation("Despacito"), # Despacito - title word "slowly"
  phrases[17].find_token_translation("Quiero"), # Quiero - "I want"
  phrases[17].find_token_translation("respirar"), # respirar - "breathe"
  phrases[17].find_token_translation("cuello"), # cuello - "neck"
  phrases[18].find_token_translation("Deja"), # Deja - "let"
  phrases[18].find_token_translation("diga"), # diga - "tell"
  phrases[18].find_token_translation("al oído"), # al oído - "in your ear"
  phrases[19].find_token_translation("acuerdes"), # acuerdes - "remember"
  phrases[19].find_token_translation("conmigo"), # conmigo - "with me"
  phrases[21].find_token_translation("desnudarte"), # desnudarte - "undress you"
  phrases[21].find_token_translation("besos"), # besos - "kisses"
  phrases[22].find_token_translation("Firmar"), # Firmar - "sign"
  phrases[22].find_token_translation("paredes"), # paredes - "walls"
  phrases[22].find_token_translation("laberinto"), # laberinto - "labyrinth"
  phrases[23].find_token_translation("hacer"), # hacer - "make"
  phrases[23].find_token_translation("un manuscrito"), # un manuscrito - "a manuscript"
  phrases[24].find_token_translation("Sube"), # Sube - "up"
]

chorus_speak_activity = Activities::SpeakActivity.create!(lesson: l[2], order: 5)
chorus_speak_activity.phrases = phrases[16..24]

chorus_listen_activity = Activities::ListenActivity.create!(lesson: l[2], order: 6)
chorus_listen_activity.phrases = phrases[16..24]
chorus_listen_activity.token_translations = [
  phrases[16].find_token_translation("Despacito"), # Despacito (has similar_sound: ['movidito'])
  phrases[17].find_token_translation("cuello"), # cuello (has similar_sound: ['cuero'])
  phrases[18].find_token_translation("cosas"), # cosas (has similar_sound: ['rosas'])
  phrases[19].find_token_translation("conmigo"), # conmigo (has similar_sound: ['domingo'])
  phrases[22].find_token_translation("paredes"), # paredes (has similar_sound: ['pareces'])
  phrases[22].find_token_translation("laberinto"), # laberinto (has similar_sound: ['laberindo'])
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
  phrases[25].find_token_translation("ver"), # ver - "to see"
  phrases[25].find_token_translation("bailar"), # bailar - "dance"
  phrases[25].find_token_translation("tu pelo"), # tu pelo - "your hair"
  phrases[26].find_token_translation("ser"), # ser - "to be"
  phrases[26].find_token_translation("ritmo"), # ritmo - "rhythm"
  phrases[27].find_token_translation("enseñes"), # enseñes - "teach"
  phrases[27].find_token_translation("a mi boca"), # a mi boca - "my mouth"
  phrases[28].find_token_translation("lugares"), # lugares - "places"
  phrases[28].find_token_translation("favoritos"), # favoritos - "favorite"
  phrases[29].find_token_translation("sobrepasar"), # sobrepasar - "overcome"
  phrases[29].find_token_translation("peligro"), # peligro - "danger"
  phrases[30].find_token_translation("provocar"), # provocar - "make"
  phrases[30].find_token_translation("gritos"), # gritos - "scream"
  phrases[31].find_token_translation("olvides"), # olvides - "forget"
  phrases[31].find_token_translation("apellido"), # apellido - "last name"
]

bailar_speak_activity = Activities::SpeakActivity.create!(lesson: l[3], order: 5)
bailar_speak_activity.phrases = phrases[25..31]

bailar_listen_activity = Activities::ListenActivity.create!(lesson: l[3], order: 6)
bailar_listen_activity.phrases = phrases[25..31]
bailar_listen_activity.token_translations = [
  phrases[25].find_token_translation("ver"), # ver (has similar_sound: ['ayer'])
  phrases[26].find_token_translation("ritmo"), # ritmo (has similar_sound: ['mismo'])
  phrases[27].find_token_translation("a mi boca"), # a mi boca (has similar_sound: ['a mi coca'])
  phrases[29].find_token_translation("sobrepasar"), # sobrepasar (has similar_sound: ['sobrepagar'])
  phrases[30].find_token_translation("gritos"), # gritos (has similar_sound: ['chicos'])
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
  phrases[32].find_token_translation("sé"), # sé - "know"
  phrases[32].find_token_translation("pensándolo"), # pensándolo - "thinking about it"
  phrases[33].find_token_translation("Llevo tiempo intentándolo"), # Llevo tiempo intentándolo - "I've been trying for a while"
  phrases[34].find_token_translation("Mami"), # Mami - "Mommy"
  phrases[34].find_token_translation("dando"), # dando - "giving"
  phrases[35].find_token_translation("corazón"), # corazón - "heart"
  phrases[35].find_token_translation("te hace"), # te hace - "goes"
  phrases[36].find_token_translation("esa beba"), # esa beba - "that baby"
  phrases[36].find_token_translation("buscando"), # buscando - "looking"
  phrases[37].find_token_translation("prueba"), # prueba - "taste"
  phrases[37].find_token_translation("cómo"), # cómo - "how"
  phrases[38].find_token_translation("cuánto"), # cuánto - "how much"
  phrases[38].find_token_translation("amor"), # amor - "love"
  phrases[39].find_token_translation("Yo no tengo prisa"), # Yo no tengo prisa - "I'm not in a hurry"
  phrases[40].find_token_translation("lento"), # lento - "slow"
  phrases[40].find_token_translation("salvaje"), # salvaje - "wild"
]

pensando_speak_activity = Activities::SpeakActivity.create!(lesson: l[4], order: 5)
pensando_speak_activity.phrases = phrases[32..40]

pensando_listen_activity = Activities::ListenActivity.create!(lesson: l[4], order: 6)
pensando_listen_activity.phrases = phrases[32..40]
pensando_listen_activity.token_translations = [
  phrases[32].find_token_translation("pensándolo"), # pensándolo (has similar_sound: ['pesándolo'])
  phrases[33].find_token_translation("Llevo tiempo intentándolo"), # Llevo tiempo intentándolo (has similar_sound: ['llevo tiempo inventándolo'])
  phrases[35].find_token_translation("corazón"), # corazón (has similar_sound: ['corasón'])
  phrases[37].find_token_translation("prueba"), # prueba (has similar_sound: ['prueva'])
  phrases[38].find_token_translation("amor"), # amor (has similar_sound: ['humor'])
  phrases[40].find_token_translation("salvaje"), # salvaje (has similar_sound: ['salvage'])
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
  phrases[41].find_token_translation("Pasito"), # Pasito - key rhythmic word
  phrases[41].find_token_translation("suavecito"), # suavecito - diminutive "softly"
  phrases[42].find_token_translation("vamos pegando"), # vamos pegando - "get closer"
  phrases[42].find_token_translation("poquito"), # poquito - "little"
  phrases[43].find_token_translation("besas"), # besas - "kiss"
  phrases[43].find_token_translation("destreza"), # destreza - "skill"
  phrases[44].find_token_translation("malicia"), # malicia - "malice"
  phrases[44].find_token_translation("delicadeza"), # delicadeza - "delicacy"
  phrases[45].find_token_translation("Pasito"), # Pasito - repeated key word
  phrases[46].find_token_translation("vamos pegando"), # vamos pegando - repeated phrase
  phrases[47].find_token_translation("belleza"), # belleza - "beauty"
  phrases[47].find_token_translation("un rompecabezas"), # un rompecabezas - "a puzzle"
  phrases[48].find_token_translation("montarlo"), # montarlo - "put it together"
  phrases[48].find_token_translation("la pieza"), # la pieza - "the piece"
]

pasito_speak_activity = Activities::SpeakActivity.create!(lesson: l[5], order: 5)
pasito_speak_activity.phrases = phrases[41..48]

pasito_listen_activity = Activities::ListenActivity.create!(lesson: l[5], order: 6)
pasito_listen_activity.phrases = phrases[41..48]
pasito_listen_activity.token_translations = [
  phrases[41].find_token_translation("Pasito"), # Pasito (has similar_sound: ['despacito'])
  phrases[42].find_token_translation("vamos pegando"), # vamos pegando (has similar_sound: ['vamos llegando'])
  phrases[43].find_token_translation("destreza"), # destreza (has similar_sound: ['tristeza'])
  phrases[44].find_token_translation("malicia"), # malicia (has similar_sound: ['justicia'])
  phrases[47].find_token_translation("un rompecabezas"), # un rompecabezas (has similar_sound: ['un rompecabesas'])
  phrases[48].find_token_translation("la pieza"), # la pieza (has similar_sound: ['la piesa'])
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
  phrases[65].find_token_translation("Despacito"), # Despacito - title word "slowly"
  phrases[66].find_token_translation("Vamo'"), # Vamo' - "Let's"
  phrases[66].find_token_translation("hacerlo"), # hacerlo - "do it"
  phrases[66].find_token_translation("en una playa"), # en una playa - "on a beach"
  phrases[66].find_token_translation("Puerto Rico"), # Puerto Rico - location
  phrases[67].find_token_translation("las olas"), # las olas - "the waves"
  phrases[67].find_token_translation("griten"), # griten - "scream"
  phrases[67].find_token_translation("\"Ay, bendito\""), # "Ay, bendito" - cultural expression
  phrases[68].find_token_translation("mi sello"), # mi sello - "my seal"
  phrases[68].find_token_translation("se quede"), # se quede - "stays"
  phrases[68].find_token_translation("(báilalo)"), # (báilalo) - "(dance it)"
]

outro_speak_activity = Activities::SpeakActivity.create!(lesson: l[6], order: 5)
outro_speak_activity.phrases = phrases[65..68]

outro_listen_activity = Activities::ListenActivity.create!(lesson: l[6], order: 6)
outro_listen_activity.phrases = phrases[65..68]
outro_listen_activity.token_translations = [
  phrases[66].find_token_translation("hacerlo"), # hacerlo (has similar_sound: ['aserto'])
  phrases[66].find_token_translation("en una playa"), # en una playa (has similar_sound: ['en una raya'])
  phrases[67].find_token_translation("las olas"), # las olas (has similar_sound: ['las horas'])
  phrases[68].find_token_translation("mi sello"), # mi sello (has similar_sound: ['mi sero'])
]

