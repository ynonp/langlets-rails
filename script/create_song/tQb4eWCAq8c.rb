
en = Language.find_by(iso_name: 'en')
l1 = Language.find_by(iso_name: 'fr')

medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=tQb4eWCAq8c')
phrases_data = [
  [
    "Tu sais, je n'ai jamais été aussi heureux que ce matin-là",
    "You know, I've never been as happy as that morning",
    "00:08"
  ],
  [
    "Nous marchions sur une plage un peu comme celle-ci",
    "We were walking on a beach a bit like this one",
    "00:14"
  ],
  [
    "C'était l'automne, un automne où il faisait beau",
    "It was autumn, an autumn where the weather was beautiful",
    "00:19"
  ],
  [
    "Une saison qui n'existe que dans le Nord de l'Amérique",
    "A season that only exists in the North of America",
    "00:23"
  ],
  [
    "Là-bas on l'appelle l'été indien",
    "Over there, they call it Indian summer",
    "00:27"
  ],
  [
    "Mais c'était tout simplement le nôtre",
    "But it was simply ours",
    "00:30"
  ],
  [
    "Avec ta robe longue tu ressemblais",
    "With your long dress, you looked like",
    "00:33"
  ],
  [
    "A une aquarelle de Marie Laurencin",
    "A watercolor by Marie Laurencin",
    "00:36"
  ],
  [
    "Et je me souviens, je me souviens très bien",
    "And I remember, I remember very well",
    "00:38"
  ],
  [
    "De ce que je t'ai dit ce matin-là",
    "What I told you that morning",
    "00:41"
  ],
  [
    "Il y a un an, y a un siècle, y a une éternité",
    "A year ago, a century ago, an eternity ago",
    "00:43"
  ],
  [
    "On ira où tu voudras, quand tu voudras",
    "We'll go wherever you want, whenever you want",
    "00:49"
  ],
  [
    "Et on s'aimera encore, lorsque l'amour sera mort",
    "And we'll love each other still, when love is dead",
    "00:57"
  ],
  [
    "Toute la vie sera pareille à ce matin",
    "All life will be like this morning",
    "01:05"
  ],
  [
    "Aux couleurs de l'été indien",
    "With the colors of Indian summer",
    "01:13"
  ],
  [
    "Aujourd'hui je suis très loin de ce matin d'automne",
    "Today I am very far from that autumn morning",
    "01:22"
  ],
  [
    "Mais c'est comme si j'y étais. Je pense à toi.",
    "But it's as if I were there. I'm thinking of you.",
    "01:26"
  ],
  [
    "Où es-tu? Que fais-tu? Est-ce que j'existe encore pour toi?",
    "Where are you? What are you doing? Do I still exist for you?",
    "01:30"
  ],
  [
    "Je regarde cette vague qui n'atteindra jamais la dune",
    "I watch this wave that will never reach the dune",
    "01:36"
  ],
  [
    "Tu vois, comme elle je reviens en arrière",
    "You see, like it, I go back",
    "01:41"
  ],
  [
    "Comme elle je me couche sur le sable",
    "Like it, I lie down on the sand",
    "01:43"
  ],
  [
    "Et je me souviens, je me souviens des marées hautes",
    "And I remember, I remember the high tides",
    "01:45"
  ],
  [
    "Du soleil et du bonheur qui passaient sur la mer",
    "Of the sun and happiness that passed over the sea",
    "01:49"
  ],
  [
    "Il y a une éternité, un siècle, il y a un an",
    "An eternity ago, a century ago, a year ago",
    "01:52"
  ],
  [
    "On ira où tu voudras, quand tu voudras",
    "We'll go wherever you want, whenever you want",
    "02:00"
  ],
  [
    "Et on s'aimera encore lorsque l'amour sera mort",
    "And we'll love each other still when love is dead",
    "02:08"
  ],
  [
    "Toute la vie sera pareille à ce matin",
    "All life will be like this morning",
    "02:16"
  ],
  [
    "Aux couleurs de l'été indien",
    "With the colors of Indian summer",
    "02:23"
  ],
  [
    "On ira où tu voudras, quand tu voudras",
    "We'll go wherever you want, whenever you want",
    "03:04"
  ],
  [
    "Et on s'aimera encore lorsque l'amour sera mort",
    "And we'll love each other still when love is dead",
    "03:11"
  ],
  [
    "Toute la vie sera pareille à ce matin",
    "All life will be like this morning",
    "03:19"
  ],
  [
    "Aux couleurs de l'été indien",
    "With the colors of Indian summer",
    "03:27"
  ]
];

c = Course.find_or_create_by!(slug: 'lete-indien') do
  name = 'Lété indien'
  main_media_url = 'https://www.youtube.com/watch?v=tQb4eWCAq8c'
end
c.lessons.destroy_all

Lesson.where("slug like 'lete-indien%'").destroy_all
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
phrase.add_token_translation("Tu sais", 0, "You know", 0, similar_sound: [])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("n'ai jamais été", 0, "have never been", 0, similar_sound: [])
phrase.add_token_translation("aussi", 0, "as", 0, similar_sound: [])
phrase.add_token_translation("heureux", 0, "happy", 0, similar_sound: ["peureux"])
phrase.add_token_translation("que", 0, "as", 1, similar_sound: [])
phrase.add_token_translation("ce matin-là", 0, "that morning", 0, similar_sound: [])

phrase = phrases[1]
phrase.add_token_translation("Nous", 0, "We", 0, similar_sound: ["nuit"])
phrase.add_token_translation("marchions", 0, "were walking", 0, similar_sound: ["portions"])
phrase.add_token_translation("sur", 0, "on", 0, similar_sound: ["sueur"])
phrase.add_token_translation("une", 0, "a", 0, similar_sound: ["lune"])
phrase.add_token_translation("plage", 0, "beach", 0, similar_sound: ["page"])
phrase.add_token_translation("un peu", 0, "a bit", 0, similar_sound: ["un jeu"])
phrase.add_token_translation("comme", 0, "like", 0, similar_sound: ["homme"])
phrase.add_token_translation("celle-ci", 0, "this one", 0, similar_sound: ["ceci"])

phrase = phrases[2]
phrase.add_token_translation("C'était", 0, "It was", 0, similar_sound: [])
phrase.add_token_translation("l'automne", 0, "the autumn", 0, similar_sound: [])
phrase.add_token_translation("un", 0, "an", 0, similar_sound: ["on"])
phrase.add_token_translation("automne", 1, "autumn", 0, similar_sound: [])
phrase.add_token_translation("où", 0, "where", 0, similar_sound: [])
phrase.add_token_translation("il faisait beau", 0, "the weather was nice", 0, similar_sound: [])

phrase = phrases[3]
phrase.add_token_translation("Une", 0, "A", 0, similar_sound: ["lune"])
phrase.add_token_translation("saison", 0, "season", 0, similar_sound: ["maison"])
phrase.add_token_translation("qui", 0, "that", 0, similar_sound: ["lit"])
phrase.add_token_translation("n'existe que", 0, "only exists", 0, similar_sound: ["excite"])
phrase.add_token_translation("dans", 0, "in", 0, similar_sound: ["dent"])
phrase.add_token_translation("le Nord", 0, "the North", 0, similar_sound: ["le mort"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: ["deux"])
phrase.add_token_translation("l'Amérique", 0, "America", 0, similar_sound: ["la mer"])

phrase = phrases[4]
phrase.add_token_translation("Là-bas", 0, "Over there", 0, similar_sound: ["le bas"])
phrase.add_token_translation("on l'appelle", 0, "it's called", 0, similar_sound: ["on la pelle"])
phrase.add_token_translation("l'été", 0, "the summer", 0, similar_sound: ["les thés"])
phrase.add_token_translation("indien", 0, "Indian", 0, similar_sound: ["ancien"])

phrase = phrases[5]
phrase.add_token_translation("Mais", 0, "But", 0, similar_sound: ["mes","mets"])
phrase.add_token_translation("c'était", 0, "it was", 0, similar_sound: ["s'était"])
phrase.add_token_translation("tout simplement", 0, "simply", 0, similar_sound: [])
phrase.add_token_translation("le nôtre", 0, "ours", 0, similar_sound: ["autre"])

phrase = phrases[6]
phrase.add_token_translation("Avec", 0, "With", 0, similar_sound: [])
phrase.add_token_translation("ta", 0, "your", 0, similar_sound: [])
phrase.add_token_translation("robe", 0, "dress", 0, similar_sound: ["rôde"])
phrase.add_token_translation("longue", 0, "long", 0, similar_sound: ["langue"])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("ressemblais", 0, "resembled", 0, similar_sound: ["rassemblais"])

phrase = phrases[7]
phrase.add_token_translation("A", 0, "To", 0, similar_sound: ["Ah"])
phrase.add_token_translation("une", 0, "a", 0, similar_sound: ["un"])
phrase.add_token_translation("aquarelle", 0, "watercolor", 0, similar_sound: [])
phrase.add_token_translation("de", 0, "by", 0, similar_sound: ["deux"])
phrase.add_token_translation("Marie Laurencin", 0, "Marie Laurencin", 0, similar_sound: [])

phrase = phrases[8]
phrase.add_token_translation("Et", 0, "And", 0, similar_sound: ["est","ai"])
phrase.add_token_translation("je me souviens", 0, "I remember", 0, similar_sound: ["je me tiens","je me maintiens"])
phrase.add_token_translation("je me souviens", 1, "I remember", 1, similar_sound: ["je me tiens","je me maintiens"])
phrase.add_token_translation("très bien", 0, "very well", 0, similar_sound: ["très faim","très loin"])

phrase = phrases[9]
phrase.add_token_translation("De", 0, "Of", 0, similar_sound: [])
phrase.add_token_translation("ce que", 0, "what", 0, similar_sound: [])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("t'ai dit", 0, "told you", 0, similar_sound: [])
phrase.add_token_translation("ce matin-là", 0, "that morning", 0, similar_sound: [])

phrase = phrases[10]
phrase.add_token_translation("Il y a", 0, "ago", 0, similar_sound: ["il y va"])
phrase.add_token_translation("un an", 0, "a year", 0, similar_sound: ["un banc","un rang"])
phrase.add_token_translation("y a", 0, "ago", 1, similar_sound: ["il y va"])
phrase.add_token_translation("un siècle", 0, "a century", 0, similar_sound: ["un cycle"])
phrase.add_token_translation("y a", 1, "ago", 2, similar_sound: ["il y va"])
phrase.add_token_translation("une éternité", 0, "an eternity", 0, similar_sound: ["une éternue"])

phrase = phrases[11]
phrase.add_token_translation("On", 0, "We", 0, similar_sound: [])
phrase.add_token_translation("ira", 0, "will go", 0, similar_sound: [])
phrase.add_token_translation("où", 0, "where", 0, similar_sound: [])
phrase.add_token_translation("tu", 0, "you", 0, similar_sound: [])
phrase.add_token_translation("voudras", 0, "want", 0, similar_sound: [])
phrase.add_token_translation("quand", 0, "when", 0, similar_sound: [])
phrase.add_token_translation("tu", 1, "you", 1, similar_sound: [])
phrase.add_token_translation("voudras", 1, "want", 1, similar_sound: [])

phrase = phrases[12]
phrase.add_token_translation("Et", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("on", 0, "we", 0, similar_sound: [])
phrase.add_token_translation("s'aimera", 0, "will love each other", 0, similar_sound: [])
phrase.add_token_translation("encore", 0, "still", 0, similar_sound: ["en corps"])
phrase.add_token_translation("lorsque", 0, "when", 0, similar_sound: [])
phrase.add_token_translation("l'amour", 0, "love", 0, similar_sound: [])
phrase.add_token_translation("sera", 0, "will be", 0, similar_sound: [])
phrase.add_token_translation("mort", 0, "dead", 0, similar_sound: ["mord"])

phrase = phrases[13]
phrase.add_token_translation("Toute la vie", 0, "All life", 0, similar_sound: ["toute la nuit","toute la ville"])
phrase.add_token_translation("sera", 0, "will be", 0, similar_sound: ["saura","serre"])
phrase.add_token_translation("pareille à", 0, "like", 0, similar_sound: ["pareil","oreille"])
phrase.add_token_translation("ce", 0, "this", 0, similar_sound: ["ses","ces"])
phrase.add_token_translation("matin", 0, "morning", 0, similar_sound: ["mains","chemin"])

phrase = phrases[14]
phrase.add_token_translation("Aux", 0, "In the", 0, similar_sound: ["os"])
phrase.add_token_translation("couleurs", 0, "colors", 0, similar_sound: ["douleurs"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: ["deux"])
phrase.add_token_translation("l'été", 0, "the summer", 0, similar_sound: ["les"])
phrase.add_token_translation("indien", 0, "Indian", 0, similar_sound: ["ancien"])

phrase = phrases[15]
phrase.add_token_translation("Aujourd'hui", 0, "Today", 0, similar_sound: [])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: [])
phrase.add_token_translation("suis", 0, "am", 0, similar_sound: ["suie"])
phrase.add_token_translation("très", 0, "very", 0, similar_sound: ["trois"])
phrase.add_token_translation("loin", 0, "far", 0, similar_sound: ["moins"])
phrase.add_token_translation("de", 0, "from", 0, similar_sound: ["deux"])
phrase.add_token_translation("ce", 0, "that", 0, similar_sound: ["ses"])
phrase.add_token_translation("matin", 0, "morning", 0, similar_sound: ["mains"])
phrase.add_token_translation("d'automne", 0, "autumn", 0, similar_sound: ["d'homme"])

phrase = phrases[16]
phrase.add_token_translation("Mais", 0, "But", 0, similar_sound: [])
phrase.add_token_translation("c'est comme si", 0, "it's as if", 0, similar_sound: [])
phrase.add_token_translation("j'y étais", 0, "I were there", 0, similar_sound: [])
phrase.add_token_translation("Je pense à", 0, "I think of", 0, similar_sound: [])
phrase.add_token_translation("toi", 0, "you", 0, similar_sound: [])

phrase = phrases[17]
phrase.add_token_translation("Où", 0, "Where", 0, similar_sound: [])
phrase.add_token_translation("es-tu", 0, "are you", 0, similar_sound: [])
phrase.add_token_translation("Que", 0, "What", 0, similar_sound: [])
phrase.add_token_translation("fais-tu", 0, "are you doing", 0, similar_sound: [])
phrase.add_token_translation("Est-ce que", 0, "Do I", 0, similar_sound: [])
phrase.add_token_translation("j'existe", 0, "exist", 0, similar_sound: [])
phrase.add_token_translation("encore", 0, "still", 0, similar_sound: [])
phrase.add_token_translation("pour", 0, "for", 0, similar_sound: [])
phrase.add_token_translation("toi", 0, "you", 0, similar_sound: [])

phrase = phrases[18]
phrase.add_token_translation("Je", 0, "I", 0, similar_sound: ["jeu"])
phrase.add_token_translation("regarde", 0, "look at", 0, similar_sound: [])
phrase.add_token_translation("cette", 0, "this", 0, similar_sound: ["sept","saute"])
phrase.add_token_translation("vague", 0, "wave", 0, similar_sound: ["bagues"])
phrase.add_token_translation("qui", 0, "that", 0, similar_sound: ["quille"])
phrase.add_token_translation("n'atteindra jamais", 0, "will never reach", 0, similar_sound: ["éteindra"])
phrase.add_token_translation("la", 0, "the", 0, similar_sound: ["las"])
phrase.add_token_translation("dune", 0, "dune", 0, similar_sound: ["dûment"])

phrase = phrases[19]
phrase.add_token_translation("Tu", 0, "You", 0, similar_sound: [])
phrase.add_token_translation("vois", 0, "see", 0, similar_sound: ["voix"])
phrase.add_token_translation("comme", 0, "like", 0, similar_sound: ["gomme"])
phrase.add_token_translation("elle", 0, "her", 0, similar_sound: ["aile"])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: ["jeu"])
phrase.add_token_translation("reviens", 0, "go back", 0, similar_sound: ["retiens"])
phrase.add_token_translation("en arrière", 0, "back", 0, similar_sound: [])

phrase = phrases[20]
phrase.add_token_translation("Comme", 0, "Like", 0, similar_sound: ["homme"])
phrase.add_token_translation("elle", 0, "her", 0, similar_sound: ["aile"])
phrase.add_token_translation("je", 0, "I", 0, similar_sound: ["jeu"])
phrase.add_token_translation("me couche", 0, "lie down", 0, similar_sound: ["douche"])
phrase.add_token_translation("sur", 0, "on", 0, similar_sound: [])
phrase.add_token_translation("le", 0, "the", 0, similar_sound: [])
phrase.add_token_translation("sable", 0, "sand", 0, similar_sound: ["table"])

phrase = phrases[21]
phrase.add_token_translation("Et", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("je me souviens", 0, "I remember", 0, similar_sound: [])
phrase.add_token_translation("je me souviens", 1, "I remember", 1, similar_sound: [])
phrase.add_token_translation("des", 0, "the", 0, similar_sound: ["dès","ses"])
phrase.add_token_translation("marées", 0, "tides", 0, similar_sound: ["mariés","marais"])
phrase.add_token_translation("hautes", 0, "high", 0, similar_sound: ["autres","hôtes"])

phrase = phrases[22]
phrase.add_token_translation("Du", 0, "Of the", 0, similar_sound: [])
phrase.add_token_translation("soleil", 0, "sun", 0, similar_sound: ["sommeil"])
phrase.add_token_translation("et", 0, "and", 0, similar_sound: [])
phrase.add_token_translation("du", 1, "of the", 1, similar_sound: [])
phrase.add_token_translation("bonheur", 0, "happiness", 0, similar_sound: ["malheur"])
phrase.add_token_translation("qui", 0, "that", 0, similar_sound: [])
phrase.add_token_translation("passaient", 0, "passed", 0, similar_sound: ["pensaient"])
phrase.add_token_translation("sur", 0, "over", 0, similar_sound: ["sœur"])
phrase.add_token_translation("la", 0, "the", 2, similar_sound: [])
phrase.add_token_translation("mer", 0, "sea", 0, similar_sound: ["mère"])

phrase = phrases[23]
phrase.add_token_translation("Il y a", 0, "ago", 0, similar_sound: [])
phrase.add_token_translation("une éternité", 0, "An eternity", 0, similar_sound: [])
phrase.add_token_translation("un siècle", 0, "a century", 0, similar_sound: [])
phrase.add_token_translation("il y a", 1, "ago", 1, similar_sound: [])
phrase.add_token_translation("un an", 0, "a year", 0, similar_sound: [])

phrase = phrases[25]
phrase.add_token_translation("Et", 0, "And", 0, similar_sound: ["est"])
phrase.add_token_translation("on", 0, "we", 0, similar_sound: ["ont"])
phrase.add_token_translation("s'aimera", 0, "will love each other", 0, similar_sound: ["sa mère"])
phrase.add_token_translation("encore", 0, "still", 0, similar_sound: ["en corps"])
phrase.add_token_translation("lorsque", 0, "when", 0, similar_sound: [])
phrase.add_token_translation("l'amour", 0, "love", 0, similar_sound: ["la mort"])
phrase.add_token_translation("sera", 0, "will be", 0, similar_sound: ["serre"])
phrase.add_token_translation("mort", 0, "dead", 0, similar_sound: ["mord"])

phrase = phrases[26]
phrase.add_token_translation("Toute", 0, "All", 0, similar_sound: [])
phrase.add_token_translation("la vie", 0, "life", 0, similar_sound: [])
phrase.add_token_translation("sera", 0, "will be", 0, similar_sound: [])
phrase.add_token_translation("pareille à", 0, "like", 0, similar_sound: [])
phrase.add_token_translation("ce", 0, "this", 0, similar_sound: [])
phrase.add_token_translation("matin", 0, "morning", 0, similar_sound: [])

phrase = phrases[27]
phrase.add_token_translation("Aux", 0, "In the", 0, similar_sound: ["os"])
phrase.add_token_translation("couleurs", 0, "colors", 0, similar_sound: ["douleurs"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: ["deux"])
phrase.add_token_translation("l'été", 0, "the summer", 0, similar_sound: ["les"])
phrase.add_token_translation("indien", 0, "Indian", 0, similar_sound: ["ancien"])

phrase = phrases[29]
phrase.add_token_translation("Et", 0, "And", 0, similar_sound: [])
phrase.add_token_translation("on", 0, "we", 0, similar_sound: ["ont"])
phrase.add_token_translation("s'aimera", 0, "will love each other", 0, similar_sound: [])
phrase.add_token_translation("encore", 0, "still", 0, similar_sound: ["en corps"])
phrase.add_token_translation("lorsque", 0, "when", 0, similar_sound: [])
phrase.add_token_translation("l'amour", 0, "love", 0, similar_sound: [])
phrase.add_token_translation("sera", 0, "will be", 0, similar_sound: ["serre"])
phrase.add_token_translation("mort", 0, "dead", 0, similar_sound: ["mord"])

phrase = phrases[30]
phrase.add_token_translation("Toute la vie", 0, "All life", 0, similar_sound: ["toute la nuit","toute la ville"])
phrase.add_token_translation("sera", 0, "will be", 0, similar_sound: ["saura","serre"])
phrase.add_token_translation("pareille à", 0, "like", 0, similar_sound: ["pareil","oreille"])
phrase.add_token_translation("ce", 0, "this", 0, similar_sound: ["ses","ces"])
phrase.add_token_translation("matin", 0, "morning", 0, similar_sound: ["mains","chemin"])

phrase = phrases[31]
phrase.add_token_translation("Aux", 0, "In the", 0, similar_sound: ["os"])
phrase.add_token_translation("couleurs", 0, "colors", 0, similar_sound: ["douleurs"])
phrase.add_token_translation("de", 0, "of", 0, similar_sound: ["deux"])
phrase.add_token_translation("l'été", 0, "the summer", 0, similar_sound: ["les"])
phrase.add_token_translation("indien", 0, "Indian", 0, similar_sound: ["ancien"])

l = Lesson.create!(medium: medium, slug: 'lete-indien0', course: c, order: 0, name: 'Opening Memory')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(0, 1, 2, 3, 4, 5)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(2, 3, 4, 5)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(2, 3, 4, 5)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(2, 3, 4, 5)
a.token_translations = [phrases[0].find_token_translation("Tu sais"),
phrases[0].find_token_translation("je"),
phrases[0].find_token_translation("aussi"),
phrases[1].find_token_translation("sur"),
phrases[2].find_token_translation("C'était"),
phrases[3].find_token_translation("saison"),
phrases[3].find_token_translation("n'existe que"),
phrases[3].find_token_translation("le Nord"),
phrases[4].find_token_translation("Là-bas"),
phrases[4].find_token_translation("on l'appelle"),
phrases[5].find_token_translation("Mais"),
phrases[5].find_token_translation("tout simplement"),
phrases[5].find_token_translation("le nôtre")].filter {|t| t.l2_start_index.present? }



a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(2, 3, 4, 5)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(0, 1, 2, 3, 4, 5)
a.token_translations = [phrases[0].find_token_translation("heureux"),
phrases[1].find_token_translation("marchions"),
phrases[3].find_token_translation("saison"),
phrases[3].find_token_translation("dans"),
phrases[4].find_token_translation("indien"),
phrases[5].find_token_translation("le nôtre")]

l = Lesson.create!(medium: medium, slug: 'lete-indien1', course: c, order: 1, name: 'The Portrait')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(6, 7, 8, 9, 10)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(6, 7, 8, 9)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(6, 7, 8, 9)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(6, 7, 8, 9)
a.token_translations = [phrases[6].find_token_translation("ta"),
phrases[6].find_token_translation("robe"),
phrases[7].find_token_translation("aquarelle"),
phrases[8].find_token_translation("je me souviens"),
phrases[8].find_token_translation("très bien"),
phrases[9].find_token_translation("je"),
phrases[9].find_token_translation("t'ai dit"),
phrases[10].find_token_translation("y a"),
phrases[10].find_token_translation("un siècle"),
phrases[10].find_token_translation("une éternité")].filter {|t| t.l2_start_index.present? }



a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(6, 7, 8, 9)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(6, 7, 8, 9, 10)
a.token_translations = [phrases[6].find_token_translation("robe"),
phrases[6].find_token_translation("longue"),
phrases[8].find_token_translation("je me souviens"),
phrases[8].find_token_translation("très bien"),
phrases[10].find_token_translation("un an"),
phrases[10].find_token_translation("un siècle")]

l = Lesson.create!(medium: medium, slug: 'lete-indien2', course: c, order: 2, name: 'Promises of Love (Chorus)')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(11, 12, 13, 14)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(11, 12, 13, 14)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(11, 12, 13, 14)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(11, 12, 13, 14)
a.token_translations = [phrases[11].find_token_translation("On"),
phrases[11].find_token_translation("tu"),
phrases[11].find_token_translation("voudras"),
phrases[12].find_token_translation("Et"),
phrases[12].find_token_translation("s'aimera"),
phrases[12].find_token_translation("lorsque"),
phrases[13].find_token_translation("sera"),
phrases[13].find_token_translation("pareille à"),
phrases[14].find_token_translation("couleurs"),
phrases[14].find_token_translation("l'été")].filter {|t| t.l2_start_index.present? }



a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(11, 12, 13, 14)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(11, 12, 13, 14)
a.token_translations = [phrases[12].find_token_translation("mort"),
phrases[13].find_token_translation("matin"),
phrases[14].find_token_translation("indien")]

l = Lesson.create!(medium: medium, slug: 'lete-indien3', course: c, order: 3, name: 'Present Reflection')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(15, 16, 17)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(15, 16, 17)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(15, 16, 17)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(15, 16, 17)
a.token_translations = [phrases[15].find_token_translation("Aujourd'hui"),
phrases[15].find_token_translation("je"),
phrases[15].find_token_translation("loin"),
phrases[16].find_token_translation("Je pense à"),
phrases[16].find_token_translation("toi"),
phrases[17].find_token_translation("Où"),
phrases[17].find_token_translation("es-tu")].filter {|t| t.l2_start_index.present? }



a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(15, 16, 17)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(15, 16, 17)
a.token_translations = [phrases[15].find_token_translation("suis")]

l = Lesson.create!(medium: medium, slug: 'lete-indien4', course: c, order: 4, name: 'The Wave Metaphor')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(18, 19, 20, 21, 22, 23)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(19, 20, 21, 22)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(19, 20, 21, 22)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(19, 20, 21, 22)
a.token_translations = [phrases[18].find_token_translation("vague"),
phrases[18].find_token_translation("n'atteindra jamais"),
phrases[19].find_token_translation("elle"),
phrases[19].find_token_translation("en arrière"),
phrases[20].find_token_translation("me couche"),
phrases[20].find_token_translation("sable"),
phrases[21].find_token_translation("je me souviens"),
phrases[21].find_token_translation("marées"),
phrases[22].find_token_translation("bonheur"),
phrases[22].find_token_translation("passaient"),
phrases[23].find_token_translation("il y a")].filter {|t| t.l2_start_index.present? }



a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(19, 20, 21, 22)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(18, 19, 20, 21, 22, 23)
a.token_translations = [phrases[18].find_token_translation("vague"),
phrases[19].find_token_translation("je"),
phrases[20].find_token_translation("elle"),
phrases[20].find_token_translation("sable"),
phrases[21].find_token_translation("marées"),
phrases[22].find_token_translation("soleil"),
phrases[22].find_token_translation("passaient")]

l = Lesson.create!(medium: medium, slug: 'lete-indien5', course: c, order: 5, name: 'Final Chorus')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(24, 25, 26, 27, 28, 29, 30, 31)
a.token_translations = []


a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(25, 26, 27, 28)
a.token_translations = []


a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(25, 26, 27, 28)
a.token_translations = []


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(25, 26, 27, 28)
a.token_translations = [phrases[25].find_token_translation("s'aimera"),
phrases[25].find_token_translation("encore"),
phrases[26].find_token_translation("sera"),
phrases[26].find_token_translation("pareille à"),
phrases[27].find_token_translation("de"),
phrases[29].find_token_translation("s'aimera"),
phrases[29].find_token_translation("encore"),
phrases[30].find_token_translation("Toute la vie"),
phrases[30].find_token_translation("ce"),
phrases[31].find_token_translation("l'été")].filter {|t| t.l2_start_index.present? }



a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(25, 26, 27, 28)
a.token_translations = []


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(24, 25, 26, 27, 28, 29, 30, 31)
a.token_translations = [phrases[25].find_token_translation("s'aimera"),
phrases[27].find_token_translation("couleurs"),
phrases[29].find_token_translation("encore"),
phrases[30].find_token_translation("sera"),
phrases[30].find_token_translation("matin"),
phrases[31].find_token_translation("couleurs"),
phrases[31].find_token_translation("indien")]
