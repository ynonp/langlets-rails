
en = Language.find_by(iso_name: 'en')
l1 = Language.find_by(iso_name: 'fr')
admin_user = User.find_by(email: 'ynon@hey.com')
raise "Admin user not found" unless admin_user

medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=zAoO52K-7Mo')
phrases_data = [
  [
    "Voilà, plus d'une heure que je te tiens dans les bras",
    "It's been over an hour that I've been holding you in my arms",
    "00:07"
  ],
  [
    "Voilà quelques jours que je suis tout à toi",
    "It's been a few days that I'm all yours",
    "00:10"
  ],
  [
    "Il est très tard et tu dors pas",
    "It's very late and you're not sleeping",
    "00:14"
  ],
  [
    "Je t'ai fait une berceuse, la voilà",
    "I made you a lullaby, here it is",
    "00:17"
  ],
  [
    "Demain le jour sera là",
    "Tomorrow the day will be here",
    "00:23"
  ],
  [
    "Et les oiseaux chanteront leur joie",
    "And the birds will sing their joy",
    "00:26"
  ],
  [
    "Tes paupières d'or s'ouvriront",
    "Your golden eyelids will open",
    "00:29"
  ],
  [
    "Sur le soleil et sur sa chanson",
    "To the sun and to its song",
    "00:33"
  ],
  [
    "Ferme les yeux, c'est merveilleux",
    "Close your eyes, it's wonderful",
    "00:37"
  ],
  [
    "Et dans tes rêves toutes les fées",
    "And in your dreams all the fairies",
    "00:40"
  ],
  [
    "Viendront te réveiller",
    "Will come to wake you up",
    "00:44"
  ],
  [
    "Fais dodo",
    "Go to sleep / Sleepy time",
    "00:47"
  ],
  [
    "Pourquoi tu dors pas?",
    "Why aren't you sleeping?",
    "00:50"
  ],
  [
    "Demain il faut que je me lève tôt",
    "Tomorrow I have to get up early",
    "00:58"
  ],
  [
    "J'ai un rendez-vous hyper important",
    "I have a very important meeting",
    "01:01"
  ],
  [
    "Si t'aimes ton père, si tu l'aimes vraiment",
    "If you love your father, if you really love him",
    "01:04"
  ],
  [
    "Sois fatigué et dors maintenant",
    "Be tired and sleep now",
    "01:07"
  ],
  [
    "J'ai sauté sur l'occase, t'avalais ton biberon",
    "I seized the opportunity while you were gulping down your bottle",
    "01:11"
  ],
  [
    "Pour un micro sommeil de dix secondes environ",
    "For a micro-sleep of about ten seconds",
    "01:14"
  ],
  [
    "C'était confort, j'ai bien récupéré",
    "It was comfortable, I've recovered well",
    "01:18"
  ],
  [
    "Maintenant tu dors, t'arrêtes de nous faire chier.",
    "Now you sleep, stop driving us crazy.",
    "01:21"
  ],
  [
    "Fais dodo",
    "Go to sleep / Sleepy time",
    "01:24"
  ],
  [
    "Demain le jour sera là",
    "Tomorrow the day will be here",
    "01:27"
  ],
  [
    "Et les oiseaux chanteront leur joie",
    "And the birds will sing their joy",
    "01:30"
  ],
  [
    "Tes paupières d'or s'ouvriront",
    "Your golden eyelids will open",
    "01:34"
  ],
  [
    "Sur le soleil et sur sa chanson",
    "To the sun and to its song",
    "01:37"
  ],
  [
    "Ferme les yeux, c'est merveilleux",
    "Close your eyes, it's wonderful",
    "01:41"
  ],
  [
    "Et dans tes rêves toutes les fées",
    "And in your dreams all the fairies",
    "01:44"
  ],
  [
    "Dors, dors, dors",
    "Sleep, sleep, sleep",
    "01:49"
  ],
  [
    "Bordel, pourquoi tu dors pas?",
    "Damn it, why aren't you sleeping?",
    "01:52"
  ],
  [
    "Dors, dors, dors",
    "Sleep, sleep, sleep",
    "01:57"
  ],
  [
    "Laisse dormir ton papa",
    "Let your daddy sleep",
    "02:01"
  ],
  [
    "Ce que tu regardes en riant",
    "What you're looking at while laughing",
    "02:05"
  ],
  [
    "Que tu prends pour des parachutes",
    "That you take for parachutes",
    "02:09"
  ],
  [
    "Ce sont mes paupières, mon enfant",
    "Those are my eyelids, my child",
    "02:12"
  ],
  [
    "C'est dur d'être un adulte",
    "It's hard to be an adult",
    "02:16"
  ],
  [
    "Allez on joue franc jeu, on met cartes sur table",
    "Come on, let's play fair, let's put our cards on the table",
    "02:19"
  ],
  [
    "Si tu t'endors, je t'achète un portable",
    "If you fall asleep, I'll buy you a mobile phone",
    "02:22"
  ],
  [
    "Un troupeau de poneys, un bâton de dynamite",
    "A herd of ponies, a stick of dynamite",
    "02:26"
  ],
  [
    "J'ajoute un kangourou si tu t'endors tout de suite",
    "I'll add a kangaroo if you fall asleep right away",
    "02:29"
  ],
  [
    "Tes paupières sont lourdes",
    "Your eyelids are heavy",
    "02:34"
  ],
  [
    "Tu es à mon pouvoir",
    "You are in my power",
    "02:36"
  ],
  [
    "Une sensation de chaleur engourdit ton corps",
    "A sensation of warmth numbs your body",
    "02:39"
  ],
  [
    "Tu es bien, tu n'entends plus que ma voix",
    "You are well, you only hear my voice now",
    "02:43"
  ],
  [
    "Je compte jusqu'à trois et tu vas t'endormir",
    "I'll count to three and you will fall asleep",
    "02:46"
  ],
  [
    "Pourquoi tu veux pas dormir?",
    "Why don't you want to sleep?",
    "02:50"
  ],
  [
    "Pourquoi tu dors pas?",
    "Why aren't you sleeping?",
    "02:54"
  ],
  [
    "Je te donnerais bien un somnifère",
    "I would gladly give you a sleeping pill",
    "02:56"
  ],
  [
    "Mais y'en a plus, demande à ta mère",
    "But there are no more, ask your mother",
    "03:00"
  ],
  [
    "T'es insomniaque ou quoi?",
    "Are you an insomniac or what?",
    "03:04"
  ],
  [
    "Puisque tu me laisses pas le choix",
    "Since you're not giving me a choice",
    "03:07"
  ],
  [
    "Voici le temps des menaces",
    "Here comes the time for threats",
    "03:11"
  ],
  [
    "Si tu dors pas, je te place",
    "If you don't sleep, I'll put you into care",
    "03:15"
  ],
  [
    "Dors, dors, dors",
    "Sleep, sleep, sleep",
    "03:20"
  ],
  [
    "Mais on dirait que ça marche",
    "But it looks like it's working",
    "03:24"
  ],
  [
    "Tu fermes les yeux, tu es si sage",
    "You close your eyes, you are so well-behaved",
    "03:31"
  ],
  [
    "C'est merveilleux, tu dors comme un ange",
    "It's wonderful, you sleep like an angel",
    "03:35"
  ],
  [
    "Tu as de la chance, moi aussi j'ai sommeil",
    "You are lucky, I'm sleepy too",
    "03:38"
  ],
  [
    "Mais c'est le matin, il faut que je m'habille",
    "But it's morning, I have to get dressed",
    "03:41"
  ],
  [
    "Je me suis énervé, mon amour, je le regrette",
    "I got angry, my love, I regret it",
    "03:45"
  ],
  [
    "Pour me faire pardonner",
    "To be forgiven",
    "03:48"
  ],
  [
    "Je vais te jouer un peu de trompette",
    "I'm going to play a little trumpet for you",
    "03:51"
  ]
];

c = Course.find_or_create_by!(slug: 'berceuse')
c.name = 'La berceuse'
c.main_media_url = 'https://www.youtube.com/watch?v=zAoO52K-7Mo'
c.user = admin_user if c.user.nil?
c.lessons.destroy_all
c.save!

Lesson.where("slug like 'berceuse%'").destroy_all
medium.phrases.destroy_all

# Create phrases in DB
phrases = phrases_data.map do |text_l1, text_l2, timestamp|
  Phrase.create!(
    l1: l1,
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
phrase.add_token_translation("Voilà", 0, "There", 0, similar_sound: [])
phrase.add_token_translation("plus d'une heure", 0, "over an hour", 0, similar_sound: [])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("te", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("tiens", 0, "held", 0, similar_sound: ["chien"])
phrase.add_token_translation("dans", 0, "in", 0, similar_sound: ["dent"])
phrase.add_token_translation("les bras", 0, "my arms", 0, similar_sound: [])

phrase = phrases[1]
phrase.add_token_translation("Voilà", 0, "It's been", 0, similar_sound: ["voile","voix"])
phrase.add_token_translation("quelques", 0, "a few", 0, similar_sound: ["quelque","calque"])
phrase.add_token_translation("jours", 0, "days", 0, similar_sound: ["toujours","cours"])
phrase.add_token_translation("que", 0, "that", 0, similar_sound: ["qui","quai"])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: ["jeu"])
phrase.add_token_translation("suis", 0, "am", 0, similar_sound: ["suit","suie"])
phrase.add_token_translation("tout à toi", 0, "all yours", 0, similar_sound: ["toutou","trois"])

phrase = phrases[2]
phrase.add_token_translation("Il", 0, "It", 0, similar_sound: [])
phrase.add_token_translation("est", 0, "is", 0, similar_sound: ["et"])
phrase.add_token_translation("très", 0, "very", 0, similar_sound: ["trois"])
phrase.add_token_translation("tard", 0, "late", 0, similar_sound: ["part"])
phrase.add_token_translation("et", 0, "and", 0, similar_sound: ["est"])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: ["tout"])
phrase.add_token_translation("dors", 0, "sleep", 0, similar_sound: ["dos"])
phrase.add_token_translation("pas", 0, "not", 0, similar_sound: ["pain"])

phrase = phrases[3]
phrase.add_token_translation("Je", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("t'ai fait", 0, "made you", 0, similar_sound: ["fête","fais"])
phrase.add_token_translation("une berceuse", 0, "a lullaby", 0, similar_sound: [])
phrase.add_token_translation("la voilà", 0, "here it is", 0, similar_sound: ["voile"])

phrase = phrases[4]
phrase.add_token_translation("Demain", 0, "Tomorrow", 0, similar_sound: [])
phrase.add_token_translation("le jour", 0, "the day", 0, similar_sound: [])
phrase.add_token_translation("sera", 0, "will be", 0, similar_sound: ["saura"])
phrase.add_token_translation("là", 0, "here", 0, similar_sound: ["la"])

phrase = phrases[5]
phrase.add_token_translation("Et", 0, "And", 0, similar_sound: ["est"])
phrase.add_token_translation("les", 0, "the", 0, similar_sound: ["lait"])
phrase.add_token_translation("oiseaux", 0, "birds", 0, similar_sound: ["eaux"])
phrase.add_token_translation("chanteront", 0, "will sing", 0, similar_sound: ["chanterons"])
phrase.add_token_translation("leur", 0, "their", 0, similar_sound: ["l'heure"])
phrase.add_token_translation("joie", 0, "joy", 0, similar_sound: ["bois"])

phrase = phrases[6]
phrase.add_token_translation("Tes", 0, "Your", 0, similar_sound: ["ses","mes","les"])
phrase.add_token_translation("paupières", 0, "eyelids", 0, similar_sound: ["papiers"])
phrase.add_token_translation("d'or", 0, "golden", 0, similar_sound: ["dort","mort"])
phrase.add_token_translation("s'ouvriront", 0, "will open", 0, similar_sound: ["souviendront"])

phrase = phrases[7]
phrase.add_token_translation("Sur", 0, "On", 0, similar_sound: ["sourd"])
phrase.add_token_translation("le", 0, "the", 0, similar_sound: ["lait"])
phrase.add_token_translation("soleil", 0, "sun", 0, similar_sound: ["sommeil"])
phrase.add_token_translation("et", 0, "and", 0, similar_sound: ["eux"])
phrase.add_token_translation("sur", 1, "on", 1, similar_sound: ["sourd"])
phrase.add_token_translation("sa", 0, "its", 0, similar_sound: ["sans"])
phrase.add_token_translation("chanson", 0, "song", 0, similar_sound: ["maison"])

phrase = phrases[8]
phrase.add_token_translation("Ferme", 0, "Close", 0, similar_sound: ["forme"])
phrase.add_token_translation("les yeux", 0, "your eyes", 0, similar_sound: ["lait","eux"])
phrase.add_token_translation("c'est", 0, "it's", 0, similar_sound: ["sait","ces"])
phrase.add_token_translation("merveilleux", 0, "wonderful", 0, similar_sound: ["curieux"])

phrase = phrases[9]
phrase.add_token_translation("Et", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("dans", 0, "in", 0, similar_sound: [])
phrase.add_token_translation("tes", 0, "your", 0, similar_sound: [])
phrase.add_token_translation("rêves", 0, "dreams", 0, similar_sound: ["grèves"])
phrase.add_token_translation("toutes", 0, "all", 0, similar_sound: ["routes"])
phrase.add_token_translation("les", 0, "the", 0, similar_sound: [])
phrase.add_token_translation("fées", 0, "fairies", 0, similar_sound: ["faits"])

phrase = phrases[10]
phrase.add_token_translation("Viendront", 0, "Will come", 0, similar_sound: ["viennent","vient"])
phrase.add_token_translation("te", 0, "you", 0, similar_sound: ["thé","taie"])
phrase.add_token_translation("réveiller", 0, "wake up", 0, similar_sound: ["révéler","rêver"])

phrase = phrases[11]
phrase.add_token_translation("Fais", 0, "Go", 0, similar_sound: ["fée","fait"])
phrase.add_token_translation("dodo", 0, "to sleep", 0, similar_sound: ["dos","doux"])

phrase = phrases[12]
phrase.add_token_translation("Pourquoi", 0, "Why", 0, similar_sound: [])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("dors", 0, "sleeping", 0, similar_sound: ["d'or","dos"])
phrase.add_token_translation("pas", 0, "not", 0, similar_sound: ["papa","pas"])

phrase = phrases[13]
phrase.add_token_translation("Demain", 0, "Tomorrow", 0, similar_sound: [])
phrase.add_token_translation("il faut que", 0, "I have to", 0, similar_sound: [])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("me lève", 0, "get up", 0, similar_sound: ["m'élève"])
phrase.add_token_translation("tôt", 0, "early", 0, similar_sound: ["taux"])

phrase = phrases[14]
phrase.add_token_translation("J'ai", 0, "I have", 0, similar_sound: [])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: ["on"])
phrase.add_token_translation("rendez-vous", 0, "appointment", 0, similar_sound: [])
phrase.add_token_translation("hyper", 0, "very", 0, similar_sound: [])
phrase.add_token_translation("important", 0, "important", 0, similar_sound: [])

phrase = phrases[15]
phrase.add_token_translation("Si", 0, "If", 0, similar_sound: ["six","ci"])
phrase.add_token_translation("t'aimes", 0, "you love", 0, similar_sound: ["thème"])
phrase.add_token_translation("ton", 0, "your", 0, similar_sound: ["thon","t'ont"])
phrase.add_token_translation("père", 0, "father", 0, similar_sound: ["paire","pers"])
phrase.add_token_translation("si", 1, "if", 1, similar_sound: ["six","ci"])
phrase.add_token_translation("tu", 0, "you", 1, similar_sound: ["tue"])
phrase.add_token_translation("l'aimes", 0, "love him", 0, similar_sound: ["l'hymne"])
phrase.add_token_translation("vraiment", 0, "really", 0, similar_sound: ["rarement","franchement"])

phrase = phrases[16]
phrase.add_token_translation("Sois", 0, "Be", 0, similar_sound: ["soie"])
phrase.add_token_translation("fatigué", 0, "tired", 0, similar_sound: ["fatiguant"])
phrase.add_token_translation("et", 0, "and", 0, similar_sound: ["est"])
phrase.add_token_translation("dors", 0, "sleep", 0, similar_sound: ["dos"])
phrase.add_token_translation("maintenant", 0, "now", 0, similar_sound: ["maintien"])

phrase = phrases[17]
phrase.add_token_translation("J'ai sauté", 0, "I jumped", 0, similar_sound: [])
phrase.add_token_translation("sur l'occase", 0, "at the chance", 0, similar_sound: ["sur la case"])
phrase.add_token_translation("t'avalais", 0, "you were drinking", 0, similar_sound: ["tu parlais"])
phrase.add_token_translation("ton", 0, "your", 0, similar_sound: ["son"])
phrase.add_token_translation("biberon", 0, "bottle", 0, similar_sound: ["bureau"])

phrase = phrases[18]
phrase.add_token_translation("Pour", 0, "For", 0, similar_sound: [])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: [])
phrase.add_token_translation("micro", 0, "micro", 0, similar_sound: [])
phrase.add_token_translation("sommeil", 0, "sleep", 0, similar_sound: ["soleil"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: [])
phrase.add_token_translation("dix", 0, "ten", 0, similar_sound: [])
phrase.add_token_translation("secondes", 0, "seconds", 0, similar_sound: [])
phrase.add_token_translation("environ", 0, "about", 0, similar_sound: ["environs"])

phrase = phrases[19]
phrase.add_token_translation("C'était", 0, "It was", 0, similar_sound: [])
phrase.add_token_translation("confort", 0, "comfortable", 0, similar_sound: [])
phrase.add_token_translation("j'ai", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("bien", 0, "well", 0, similar_sound: ["bain","rien"])
phrase.add_token_translation("récupéré", 0, "recovered", 0, similar_sound: [])

phrase = phrases[20]
phrase.add_token_translation("Maintenant", 0, "Now", 0, similar_sound: [])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("dors", 0, "sleep", 0, similar_sound: ["d'or"])
phrase.add_token_translation("t'arrêtes de", 0, "you stop", 0, similar_sound: [])
phrase.add_token_translation("nous", 0, "us", 0, similar_sound: [])
phrase.add_token_translation("faire chier", 0, "bothering", 0, similar_sound: [])

phrase = phrases[21]
phrase.add_token_translation("Fais", 0, "Go", 0, similar_sound: ["fée","fait"])
phrase.add_token_translation("dodo", 0, "to sleep", 0, similar_sound: ["dos","doux"])

phrase = phrases[22]
phrase.add_token_translation("Demain", 0, "Tomorrow", 0, similar_sound: ["des mains"])
phrase.add_token_translation("le", 0, "the", 0, similar_sound: ["lait"])
phrase.add_token_translation("jour", 0, "day", 0, similar_sound: ["court"])
phrase.add_token_translation("sera", 0, "will be", 0, similar_sound: ["serre"])
phrase.add_token_translation("là", 0, "here", 0, similar_sound: ["las"])

phrase = phrases[23]
phrase.add_token_translation("Et", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("les", 0, "the", 0, similar_sound: [])
phrase.add_token_translation("oiseaux", 0, "birds", 0, similar_sound: ["eaux"])
phrase.add_token_translation("chanteront", 0, "will sing", 0, similar_sound: ["chanterons"])
phrase.add_token_translation("leur", 0, "their", 0, similar_sound: ["l'heure"])
phrase.add_token_translation("joie", 0, "joy", 0, similar_sound: ["bois"])

phrase = phrases[24]
phrase.add_token_translation("Tes", 0, "Your", 0, similar_sound: ["ses","mes","les"])
phrase.add_token_translation("paupières", 0, "eyelids", 0, similar_sound: ["papiers"])
phrase.add_token_translation("d'or", 0, "golden", 0, similar_sound: ["dort","mort"])
phrase.add_token_translation("s'ouvriront", 0, "will open", 0, similar_sound: ["souviendront"])

phrase = phrases[25]
phrase.add_token_translation("Sur", 0, "On", 0, similar_sound: [])
phrase.add_token_translation("le", 0, "the", 0, similar_sound: [])
phrase.add_token_translation("soleil", 0, "sun", 0, similar_sound: ["sommeil"])
phrase.add_token_translation("et", 0, "and", 0, similar_sound: ["est"])
phrase.add_token_translation("sur", 1, "on", 1, similar_sound: [])
phrase.add_token_translation("sa", 0, "its", 0, similar_sound: ["ça"])
phrase.add_token_translation("chanson", 0, "song", 0, similar_sound: [])

phrase = phrases[26]
phrase.add_token_translation("Ferme", 0, "Close", 0, similar_sound: ["forme"])
phrase.add_token_translation("les yeux", 0, "your eyes", 0, similar_sound: ["lait","eux"])
phrase.add_token_translation("c'est", 0, "it's", 0, similar_sound: ["sait","ces"])
phrase.add_token_translation("merveilleux", 0, "wonderful", 0, similar_sound: ["curieux"])

phrase = phrases[27]
phrase.add_token_translation("Et", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("dans", 0, "in", 0, similar_sound: [])
phrase.add_token_translation("tes", 0, "your", 0, similar_sound: [])
phrase.add_token_translation("rêves", 0, "dreams", 0, similar_sound: ["grèves"])
phrase.add_token_translation("toutes", 0, "all", 0, similar_sound: ["routes"])
phrase.add_token_translation("les", 0, "the", 0, similar_sound: [])
phrase.add_token_translation("fées", 0, "fairies", 0, similar_sound: ["faits"])

phrase = phrases[28]
phrase.add_token_translation("Dors", 0, "Sleep", 0, similar_sound: [])
phrase.add_token_translation("dors", 1, "sleep", 0, similar_sound: [])
phrase.add_token_translation("dors", 2, "sleep", 0, similar_sound: [])

phrase = phrases[29]
phrase.add_token_translation("Bordel", 0, "Damn it", 0, similar_sound: [])
phrase.add_token_translation("pourquoi", 0, "why", 0, similar_sound: [])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("dors", 0, "sleep", 0, similar_sound: [])
phrase.add_token_translation("pas", 0, "not", 0, similar_sound: [])

phrase = phrases[30]
phrase.add_token_translation("Dors", 0, "Sleep", 0, similar_sound: ["d'or","dos"])
phrase.add_token_translation("dors", 1, "sleep", 0, similar_sound: ["d'or","dos"])
phrase.add_token_translation("dors", 2, "sleep", 0, similar_sound: ["d'or","dos"])

phrase = phrases[31]
phrase.add_token_translation("Laisse", 0, "Let", 0, similar_sound: ["les"])
phrase.add_token_translation("dormir", 0, "sleep", 0, similar_sound: ["d'or"])
phrase.add_token_translation("ton", 0, "your", 0, similar_sound: ["thon"])
phrase.add_token_translation("papa", 0, "dad", 0, similar_sound: ["pas"])

phrase = phrases[32]
phrase.add_token_translation("Ce que", 0, "What", 0, similar_sound: ["ceux que"])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: ["tout"])
phrase.add_token_translation("regardes", 0, "are looking at", 0, similar_sound: ["regarde"])
phrase.add_token_translation("en riant", 0, "while laughing", 0, similar_sound: ["en rien"])

phrase = phrases[33]
phrase.add_token_translation("Que", 0, "That", 0, similar_sound: [])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("prends", 0, "take", 0, similar_sound: ["prince"])
phrase.add_token_translation("pour", 0, "for", 0, similar_sound: ["peur"])
phrase.add_token_translation("des", 0, "parachutes", 0, similar_sound: ["deux"])
phrase.add_token_translation("parachutes", 0, "", -1, similar_sound: [])

phrase = phrases[34]
phrase.add_token_translation("Ce sont", 0, "These are", 0, similar_sound: ["Ses sont"])
phrase.add_token_translation("mes", 0, "my", 0, similar_sound: ["mais"])
phrase.add_token_translation("paupières", 0, "eyelids", 0, similar_sound: ["papiers"])
phrase.add_token_translation("mon", 0, "my", 1, similar_sound: ["mont"])
phrase.add_token_translation("enfant", 0, "child", 0, similar_sound: ["en faim"])

phrase = phrases[35]
phrase.add_token_translation("C'est", 0, "It's", 0, similar_sound: [])
phrase.add_token_translation("dur", 0, "hard", 0, similar_sound: [])
phrase.add_token_translation("d'être", 0, "to be", 0, similar_sound: [])
phrase.add_token_translation("un", 0, "an", 0, similar_sound: [])
phrase.add_token_translation("adulte", 0, "adult", 0, similar_sound: [])

phrase = phrases[36]
phrase.add_token_translation("Allez", 0, "Come on", 0, similar_sound: [])
phrase.add_token_translation("on", 0, "let's", 0, similar_sound: [])
phrase.add_token_translation("joue", 0, "be", 0, similar_sound: ["joug"])
phrase.add_token_translation("franc jeu", 0, "frank", 0, similar_sound: ["frangeux"])
phrase.add_token_translation("on", 1, "let's", 1, similar_sound: [])
phrase.add_token_translation("met", 0, "lay", 0, similar_sound: ["m'est"])
phrase.add_token_translation("cartes", 0, "cards", 0, similar_sound: ["carpe"])
phrase.add_token_translation("sur", 0, "on", 0, similar_sound: ["sueur"])
phrase.add_token_translation("table", 0, "table", 0, similar_sound: ["cable"])

phrase = phrases[37]
phrase.add_token_translation("Si", 0, "If", 0, similar_sound: [])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("t'endors", 0, "fall asleep", 0, similar_sound: [])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("t'achète", 0, "buy you", 0, similar_sound: [])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: [])
phrase.add_token_translation("portable", 0, "phone", 0, similar_sound: [])

phrase = phrases[38]
phrase.add_token_translation("Un", 0, "A", 0, similar_sound: ["une"])
phrase.add_token_translation("troupeau", 0, "herd", 0, similar_sound: ["trop haut"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: ["deux"])
phrase.add_token_translation("poneys", 0, "ponies", 0, similar_sound: ["donner"])
phrase.add_token_translation("un", 1, "a", 1, similar_sound: ["une"])
phrase.add_token_translation("bâton", 0, "stick", 0, similar_sound: ["bateau"])
phrase.add_token_translation("de", 1, "of", 1, similar_sound: ["deux"])
phrase.add_token_translation("dynamite", 0, "dynamite", 0, similar_sound: ["dynamique"])

phrase = phrases[39]
phrase.add_token_translation("J'ajoute", 0, "I add", 0, similar_sound: [])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: [])
phrase.add_token_translation("kangourou", 0, "kangaroo", 0, similar_sound: [])
phrase.add_token_translation("si", 0, "if", 0, similar_sound: [])
phrase.add_token_translation("tu t'endors", 0, "you fall asleep", 0, similar_sound: [])
phrase.add_token_translation("tout de suite", 0, "immediately", 0, similar_sound: [])

phrase = phrases[40]
phrase.add_token_translation("Tes", 0, "Your", 0, similar_sound: [])
phrase.add_token_translation("paupières", 0, "eyelids", 0, similar_sound: ["papiers"])
phrase.add_token_translation("sont", 0, "are", 0, similar_sound: ["son"])
phrase.add_token_translation("lourdes", 0, "heavy", 0, similar_sound: ["sourdes"])

phrase = phrases[41]
phrase.add_token_translation("Tu", 0, "You", 0, similar_sound: ["tout"])
phrase.add_token_translation("es", 0, "are", 0, similar_sound: ["et"])
phrase.add_token_translation("à", 0, "in", 0, similar_sound: ["as"])
phrase.add_token_translation("mon", 0, "my", 0, similar_sound: ["mont"])
phrase.add_token_translation("pouvoir", 0, "power", 0, similar_sound: ["pour voir"])

phrase = phrases[42]
phrase.add_token_translation("Une", 0, "A", 0, similar_sound: [])
phrase.add_token_translation("sensation", 0, "sensation", 0, similar_sound: [])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: [])
phrase.add_token_translation("chaleur", 0, "warmth", 0, similar_sound: ["valeur","malheur"])
phrase.add_token_translation("engourdit", 0, "numbs", 0, similar_sound: ["endormi","grandit"])
phrase.add_token_translation("ton", 0, "your", 0, similar_sound: ["son","mon"])
phrase.add_token_translation("corps", 0, "body", 0, similar_sound: ["port","sort"])

phrase = phrases[43]
phrase.add_token_translation("Tu", 0, "You", 0, similar_sound: [])
phrase.add_token_translation("es", 0, "are", 0, similar_sound: [])
phrase.add_token_translation("bien", 0, "well", 0, similar_sound: ["rien"])
phrase.add_token_translation("tu", 1, "you", 1, similar_sound: [])
phrase.add_token_translation("n'entends plus que", 0, "only hear", 0, similar_sound: [])
phrase.add_token_translation("ma", 0, "my", 0, similar_sound: ["pas"])
phrase.add_token_translation("voix", 0, "voice", 0, similar_sound: ["bois","moi"])

phrase = phrases[44]
phrase.add_token_translation("Je", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("compte", 0, "count", 0, similar_sound: ["conte"])
phrase.add_token_translation("jusqu'à", 0, "to", 0, similar_sound: [])
phrase.add_token_translation("trois", 0, "three", 0, similar_sound: ["croix"])
phrase.add_token_translation("et", 0, "and", 0, similar_sound: [])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: ["tout"])
phrase.add_token_translation("vas", 0, "are going", 0, similar_sound: ["bas"])
phrase.add_token_translation("t'endormir", 0, "to fall asleep", 0, similar_sound: ["t'endurcir"])

phrase = phrases[45]
phrase.add_token_translation("Pourquoi", 0, "Why", 0, similar_sound: ["pour quoi"])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("veux", 0, "want", 0, similar_sound: ["vieux"])
phrase.add_token_translation("pas", 0, "not", 0, similar_sound: ["papa","bas"])
phrase.add_token_translation("dormir", 0, "sleep", 0, similar_sound: ["dormi"])

phrase = phrases[46]
phrase.add_token_translation("Pourquoi", 0, "Why", 0, similar_sound: ["quoi"])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: ["tout","tue"])
phrase.add_token_translation("dors", 0, "sleeping", 0, similar_sound: ["d'or","dos"])
phrase.add_token_translation("pas", 0, "not", 0, similar_sound: ["papa","par"])

phrase = phrases[47]
phrase.add_token_translation("Je", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("te", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("donnerais", 0, "would give", 0, similar_sound: ["donnerai"])
phrase.add_token_translation("bien", 0, "gladly", 0, similar_sound: ["rien","bain"])
phrase.add_token_translation("un", 0, "a", 0, similar_sound: ["on"])
phrase.add_token_translation("somnifère", 0, "sleeping pill", 0, similar_sound: [])

phrase = phrases[48]
phrase.add_token_translation("Mais", 0, "But", 0, similar_sound: ["mes","met"])
phrase.add_token_translation("y'en a plus", 0, "there's no more", 0, similar_sound: [])
phrase.add_token_translation("demande", 0, "ask", 0, similar_sound: ["demain","dent"])
phrase.add_token_translation("à", 0, "to", 0, similar_sound: ["a","as"])
phrase.add_token_translation("ta", 0, "your", 0, similar_sound: ["t'as","tas"])
phrase.add_token_translation("mère", 0, "mother", 0, similar_sound: ["mer","maire"])

phrase = phrases[49]
phrase.add_token_translation("T'es", 0, "You are", 0, similar_sound: [])
phrase.add_token_translation("insomniaque", 0, "insomniac", 0, similar_sound: [])
phrase.add_token_translation("ou", 0, "or", 0, similar_sound: [])
phrase.add_token_translation("quoi", 0, "what", 0, similar_sound: [])

phrase = phrases[50]
phrase.add_token_translation("Puisque", 0, "Since", 0, similar_sound: [])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: ["tout"])
phrase.add_token_translation("me", 0, "me", 0, similar_sound: ["mes"])
phrase.add_token_translation("laisses pas", 0, "don't leave", 0, similar_sound: [])
phrase.add_token_translation("le", 0, "the", 0, similar_sound: ["les"])
phrase.add_token_translation("choix", 0, "choice", 0, similar_sound: ["bois"])

phrase = phrases[51]
phrase.add_token_translation("Voici", 0, "Here is", 0, similar_sound: ["voix"])
phrase.add_token_translation("le temps", 0, "the time", 0, similar_sound: ["le vent"])
phrase.add_token_translation("des", 0, "of the", 0, similar_sound: ["deux"])
phrase.add_token_translation("menaces", 0, "threats", 0, similar_sound: ["minces"])

phrase = phrases[52]
phrase.add_token_translation("Si", 0, "If", 0, similar_sound: ["six"])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: ["tout"])
phrase.add_token_translation("dors", 0, "sleep", 0, similar_sound: ["dos"])
phrase.add_token_translation("pas", 0, "not", 0, similar_sound: ["pain"])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: ["jeu"])
phrase.add_token_translation("te", 0, "you", 0, similar_sound: ["thé"])
phrase.add_token_translation("place", 0, "place", 0, similar_sound: ["plat"])

phrase = phrases[53]
phrase.add_token_translation("Dors", 0, "Sleep", 0, similar_sound: [])
phrase.add_token_translation("dors", 1, "sleep", 0, similar_sound: [])
phrase.add_token_translation("dors", 2, "sleep", 0, similar_sound: [])

phrase = phrases[54]
phrase.add_token_translation("Mais", 0, "But", 0, similar_sound: [])
phrase.add_token_translation("on dirait que", 0, "it looks like", 0, similar_sound: [])
phrase.add_token_translation("ça", 0, "it", 0, similar_sound: ["sa"])
phrase.add_token_translation("marche", 0, "working", 0, similar_sound: ["mâche"])

phrase = phrases[55]
phrase.add_token_translation("Tu", 0, "You", 0, similar_sound: ["tout"])
phrase.add_token_translation("fermes", 0, "close", 0, similar_sound: ["ferme","formes"])
phrase.add_token_translation("les yeux", 0, "your eyes", 0, similar_sound: ["les œufs"])
phrase.add_token_translation("tu", 1, "you", 1, similar_sound: ["tout"])
phrase.add_token_translation("es", 0, "are", 0, similar_sound: ["est","et"])
phrase.add_token_translation("si", 0, "so", 0, similar_sound: ["six"])
phrase.add_token_translation("sage", 0, "wise", 0, similar_sound: ["page"])

phrase = phrases[56]
phrase.add_token_translation("C'est", 0, "It's", 0, similar_sound: [])
phrase.add_token_translation("merveilleux", 0, "wonderful", 0, similar_sound: [])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: ["tout"])
phrase.add_token_translation("dors", 0, "sleep", 0, similar_sound: ["d'or"])
phrase.add_token_translation("comme", 0, "like", 0, similar_sound: ["homme"])
phrase.add_token_translation("un", 0, "an", 0, similar_sound: ["on"])
phrase.add_token_translation("ange", 0, "angel", 0, similar_sound: [])

phrase = phrases[57]
phrase.add_token_translation("Tu", 0, "You", 0, similar_sound: ["tout"])
phrase.add_token_translation("as", 0, "are", 0, similar_sound: ["à"])
phrase.add_token_translation("de la chance", 0, "lucky", 0, similar_sound: ["de la chante"])
phrase.add_token_translation("moi", 0, "I", 0, similar_sound: ["mois"])
phrase.add_token_translation("aussi", 0, "too", 0, similar_sound: ["où"])
phrase.add_token_translation("j'ai", 0, "I am", 0, similar_sound: ["j'y"])
phrase.add_token_translation("sommeil", 0, "sleepy", 0, similar_sound: ["soleil"])

phrase = phrases[58]
phrase.add_token_translation("Mais", 0, "But", 0, similar_sound: ["mes","met"])
phrase.add_token_translation("c'est", 0, "it's", 0, similar_sound: ["sait","ces"])
phrase.add_token_translation("le matin", 0, "morning", 0, similar_sound: ["le gamin","le chemin"])
phrase.add_token_translation("il faut que", 0, "I have to", 0, similar_sound: ["il fait que"])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: ["jeu"])
phrase.add_token_translation("m'habille", 0, "get dressed", 0, similar_sound: ["ma bille","ma ville"])

phrase = phrases[59]
phrase.add_token_translation("Je", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("me suis énervé", 0, "got annoyed", 0, similar_sound: [])
phrase.add_token_translation("mon amour", 0, "my love", 0, similar_sound: [])
phrase.add_token_translation("je", 1, "I", 1, similar_sound: [])
phrase.add_token_translation("le regrette", 0, "regret it", 0, similar_sound: [])

phrase = phrases[60]
phrase.add_token_translation("Pour", 0, "To", 0, similar_sound: ["Peur"])
phrase.add_token_translation("me faire pardonner", 0, "make it up to you", 0, similar_sound: [])

phrase = phrases[61]
phrase.add_token_translation("Je vais", 0, "I'm going to", 0, similar_sound: [])
phrase.add_token_translation("te", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("jouer", 0, "play", 0, similar_sound: [])
phrase.add_token_translation("un peu de", 0, "a little", 0, similar_sound: [])
phrase.add_token_translation("trompette", 0, "trumpet", 0, similar_sound: [])

l = Lesson.create!(medium: medium, slug: 'berceuse0', course: c, order: 0, name: 'Opening - The Sleepless Hour', user: admin_user)

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0, user: admin_user)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(0, 1, 2, 3)

      a.token_translations = [phrases[0].find_token_translation("plus d'une heure"),
phrases[0].find_token_translation("que"),
phrases[0].find_token_translation("tiens"),
phrases[0].find_token_translation("dans"),
phrases[1].find_token_translation("quelques"),
phrases[1].find_token_translation("jours"),
phrases[1].find_token_translation("suis"),
phrases[1].find_token_translation("tout à toi"),
phrases[2].find_token_translation("est"),
phrases[2].find_token_translation("très"),
phrases[2].find_token_translation("tu"),
phrases[2].find_token_translation("dors"),
phrases[3].find_token_translation("t'ai fait"),
phrases[3].find_token_translation("une berceuse")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(0, 1, 2, 3)

      a.token_translations = [phrases[0].find_token_translation("tiens"),
phrases[1].find_token_translation("quelques"),
phrases[2].find_token_translation("dors"),
phrases[3].find_token_translation("t'ai fait")]
      

l = Lesson.create!(medium: medium, slug: 'berceuse1', course: c, order: 1, name: 'Tomorrow\'s Promise')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(4, 5, 6, 7)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(4, 5, 6, 7)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(4, 5, 6, 7)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(4, 5, 6, 7)

      a.token_translations = [phrases[4].find_token_translation("Demain"),
phrases[4].find_token_translation("le jour"),
phrases[5].find_token_translation("oiseaux"),
phrases[5].find_token_translation("chanteront"),
phrases[6].find_token_translation("paupières"),
phrases[6].find_token_translation("s'ouvriront"),
phrases[7].find_token_translation("soleil"),
phrases[7].find_token_translation("et")].filter {|t| t.l2_start_index.present? }


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(4, 5, 6, 7)

a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(4, 5, 6, 7)

      a.token_translations = [phrases[4].find_token_translation("sera"),
phrases[5].find_token_translation("oiseaux"),
phrases[6].find_token_translation("d'or"),
phrases[7].find_token_translation("soleil"),
phrases[7].find_token_translation("chanson")]
      

l = Lesson.create!(medium: medium, slug: 'berceuse2', course: c, order: 2, name: 'Sweet Dreams and Fairies')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(8, 9, 10, 11, 12)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(8, 9, 10, 11)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(8, 9, 10, 11)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(8, 9, 10, 11)

      a.token_translations = [phrases[8].find_token_translation("les yeux"),
phrases[8].find_token_translation("merveilleux"),
phrases[9].find_token_translation("dans"),
phrases[9].find_token_translation("fées"),
phrases[10].find_token_translation("te"),
phrases[11].find_token_translation("dodo"),
phrases[12].find_token_translation("Pourquoi"),
phrases[12].find_token_translation("dors")].filter {|t| t.l2_start_index.present? }
      
a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(8, 9, 10, 11)

a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(8, 9, 10, 11, 12)

a.token_translations = [phrases[8].find_token_translation("les yeux"),
phrases[8].find_token_translation("c'est"),
phrases[9].find_token_translation("rêves"),
phrases[10].find_token_translation("te"),
phrases[10].find_token_translation("réveiller"),
phrases[11].find_token_translation("Fais"),
phrases[12].find_token_translation("dors")]
      

l = Lesson.create!(medium: medium, slug: 'berceuse3', course: c, order: 3, name: 'Father\'s Frustration')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(13, 14, 15, 16)

a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(13, 14, 15, 16)

a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(13, 14, 15, 16)

a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(13, 14, 15, 16)

      a.token_translations = [phrases[13].find_token_translation("Demain"),
phrases[13].find_token_translation("il faut que"),
phrases[14].find_token_translation("J'ai"),
phrases[14].find_token_translation("rendez-vous"),
phrases[15].find_token_translation("t'aimes"),
phrases[15].find_token_translation("ton"),
phrases[16].find_token_translation("Sois"),
phrases[16].find_token_translation("fatigué")].filter {|t| t.l2_start_index.present? }
      

a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(13, 14, 15, 16)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(13, 14, 15, 16)

      a.token_translations = [phrases[13].find_token_translation("me lève"),
phrases[13].find_token_translation("tôt"),
phrases[15].find_token_translation("t'aimes"),
phrases[15].find_token_translation("père"),
phrases[16].find_token_translation("fatigué"),
phrases[16].find_token_translation("dors"),
phrases[16].find_token_translation("maintenant")]
      

l = Lesson.create!(medium: medium, slug: 'berceuse4', course: c, order: 4, name: 'The Micro-Sleep Confession')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(17, 18, 19, 20, 21)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(17, 18, 19, 20, 21)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(17, 18, 19, 20, 21)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(17, 18, 19, 20, 21)

      a.token_translations = [
phrases[17].find_token_translation("sur l'occase"),
phrases[17].find_token_translation("t'avalais"),
phrases[18].find_token_translation("dix"),
phrases[18].find_token_translation("environ"),
phrases[19].find_token_translation("confort"),
phrases[19].find_token_translation("bien"),
phrases[19].find_token_translation("récupéré"),
phrases[20].find_token_translation("tu"),
phrases[20].find_token_translation("t'arrêtes de"),
phrases[20].find_token_translation("faire chier"),
phrases[21].find_token_translation("dodo")].filter {|t| t.l2_start_index.present? }
      
a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(17, 18, 19, 20, 21)

a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(17, 18, 19, 20, 21)

      a.token_translations = [phrases[17].find_token_translation("t'avalais"),
phrases[17].find_token_translation("biberon"),
phrases[18].find_token_translation("sommeil"),
phrases[19].find_token_translation("bien"),
phrases[20].find_token_translation("dors"),
phrases[21].find_token_translation("dodo")]
      

l = Lesson.create!(medium: medium, slug: 'berceuse5', course: c, order: 5, name: 'Escalating Desperation')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(28, 29, 30, 31)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(28, 29, 30, 31)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(28, 29, 30, 31)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(28, 29, 30, 31)

      a.token_translations = [phrases[28].find_token_translation("dors"),
phrases[29].find_token_translation("Bordel"),
phrases[29].find_token_translation("pourquoi"),
phrases[31].find_token_translation("Laisse"),
phrases[31].find_token_translation("dormir")].filter {|t| t.l2_start_index.present? }
      
a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(28, 29, 30, 31)

a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(28, 29, 30, 31)

a.token_translations = [phrases[30].find_token_translation("Dors"),
phrases[30].find_token_translation("dors"),
phrases[31].find_token_translation("Laisse"),
phrases[31].find_token_translation("ton")]

l = Lesson.create!(medium: medium, slug: 'berceuse6', course: c, order: 6, name: 'Adult Reality Check')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(32, 33, 34, 35)

a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(32, 33, 34, 35)

a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(32, 33, 34, 35)

a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(32, 33, 34, 35)

a.token_translations = [phrases[32].find_token_translation("regardes"),
phrases[32].find_token_translation("en riant"),
phrases[33].find_token_translation("prends"),
phrases[33].find_token_translation("parachutes"),
phrases[34].find_token_translation("paupières"),
phrases[34].find_token_translation("mon"),
phrases[35].find_token_translation("C'est"),
phrases[35].find_token_translation("d'être")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(32, 33, 34, 35)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(32, 33, 34, 35)

      a.token_translations = [phrases[32].find_token_translation("Ce que"),
phrases[32].find_token_translation("tu"),
phrases[32].find_token_translation("en riant"),
phrases[33].find_token_translation("pour"),
phrases[34].find_token_translation("Ce sont"),
phrases[34].find_token_translation("mes"),
phrases[34].find_token_translation("mon")]
      

l = Lesson.create!(medium: medium, slug: 'berceuse7', course: c, order: 7, name: 'Bargaining and Bribes')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(36, 37, 38, 39)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(36, 37, 38, 39)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(36, 37, 38, 39)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(36, 37, 38, 39)

      a.token_translations = [phrases[36].find_token_translation("Allez"),
phrases[36].find_token_translation("on"),
phrases[36].find_token_translation("joue"),
phrases[36].find_token_translation("met"),
phrases[36].find_token_translation("cartes"),
phrases[37].find_token_translation("t'endors"),
phrases[37].find_token_translation("je"),
phrases[37].find_token_translation("portable"),
phrases[38].find_token_translation("troupeau"),
phrases[38].find_token_translation("poneys"),
phrases[38].find_token_translation("bâton"),
phrases[39].find_token_translation("J'ajoute"),
phrases[39].find_token_translation("kangourou"),
phrases[39].find_token_translation("si"),
phrases[39].find_token_translation("tout de suite")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(36, 37, 38, 39)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(36, 37, 38, 39)

      a.token_translations = [phrases[36].find_token_translation("joue"),
phrases[38].find_token_translation("troupeau"),
phrases[38].find_token_translation("de")]
      

l = Lesson.create!(medium: medium, slug: 'berceuse8', course: c, order: 8, name: 'Hypnotic Attempt')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(40, 41, 42, 43, 44)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(40, 41, 42, 43, 44)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(40, 41, 42, 43, 44)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(40, 41, 42, 43, 44)

      a.token_translations = [phrases[40].find_token_translation("paupières"),
phrases[40].find_token_translation("lourdes"),
phrases[41].find_token_translation("mon"),
phrases[42].find_token_translation("sensation"),
phrases[42].find_token_translation("engourdit"),
phrases[42].find_token_translation("corps"),
phrases[43].find_token_translation("es"),
phrases[43].find_token_translation("n'entends plus que"),
phrases[43].find_token_translation("voix"),
phrases[44].find_token_translation("compte"),
phrases[44].find_token_translation("et"),
phrases[44].find_token_translation("vas"),
phrases[44].find_token_translation("t'endormir")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(40, 41, 42, 43, 44)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(40, 41, 42, 43, 44)

      a.token_translations = [phrases[40].find_token_translation("lourdes"),
phrases[41].find_token_translation("mon"),
phrases[42].find_token_translation("chaleur"),
phrases[42].find_token_translation("corps"),
phrases[43].find_token_translation("voix"),
phrases[44].find_token_translation("t'endormir")]
      

l = Lesson.create!(medium: medium, slug: 'berceuse9', course: c, order: 9, name: 'Last Resort - Threats')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(45, 46, 47, 48, 49, 50, 51)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(47, 48, 49, 50, 51)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(47, 48, 49, 50, 51)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(47, 48, 49, 50, 51)

      a.token_translations = [phrases[45].find_token_translation("veux"),
phrases[45].find_token_translation("pas"),
phrases[46].find_token_translation("Pourquoi"),
phrases[46].find_token_translation("dors"),
phrases[47].find_token_translation("donnerais"),
phrases[47].find_token_translation("somnifère"),
phrases[48].find_token_translation("Mais"),
phrases[48].find_token_translation("y'en a plus"),
phrases[48].find_token_translation("mère"),
phrases[49].find_token_translation("insomniaque"),
phrases[49].find_token_translation("quoi"),
phrases[50].find_token_translation("Puisque"),
phrases[50].find_token_translation("laisses pas"),
phrases[51].find_token_translation("le temps"),
phrases[51].find_token_translation("menaces")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(47, 48, 49, 50, 51)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(45, 46, 47, 48, 49, 50, 51)

      a.token_translations = [phrases[45].find_token_translation("veux"),
phrases[46].find_token_translation("dors"),
phrases[46].find_token_translation("pas"),
phrases[47].find_token_translation("donnerais"),
phrases[48].find_token_translation("demande"),
phrases[48].find_token_translation("mère"),
phrases[50].find_token_translation("choix"),
phrases[51].find_token_translation("menaces")]
      

l = Lesson.create!(medium: medium, slug: 'berceuse10', course: c, order: 10, name: 'Success and Morning Regret')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(52, 53, 54, 55, 56, 57, 58, 59)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(55, 56, 57, 58, 59)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(55, 56, 57, 58, 59)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(55, 56, 57, 58, 59)

      a.token_translations = [phrases[52].find_token_translation("dors"),
phrases[52].find_token_translation("pas"),
phrases[52].find_token_translation("place"),
phrases[54].find_token_translation("Mais"),
phrases[54].find_token_translation("on dirait que"),
phrases[55].find_token_translation("fermes"),
phrases[55].find_token_translation("les yeux"),
phrases[56].find_token_translation("merveilleux"),
phrases[56].find_token_translation("comme"),
phrases[56].find_token_translation("ange"),
phrases[57].find_token_translation("de la chance"),
phrases[58].find_token_translation("le matin"),
phrases[58].find_token_translation("il faut que"),
phrases[59].find_token_translation("me suis énervé"),
phrases[59].find_token_translation("le regrette")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(55, 56, 57, 58, 59)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(52, 53, 54, 55, 56, 57, 58, 59)

      a.token_translations = [phrases[52].find_token_translation("dors"),
phrases[54].find_token_translation("marche"),
phrases[55].find_token_translation("les yeux"),
phrases[55].find_token_translation("sage"),
phrases[57].find_token_translation("de la chance"),
phrases[57].find_token_translation("sommeil"),
phrases[58].find_token_translation("le matin"),
phrases[58].find_token_translation("il faut que")]
      
