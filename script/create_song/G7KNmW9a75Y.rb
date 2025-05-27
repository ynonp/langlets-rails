
# Language Configuration
# Clip Language: English (en)
# Translation Language: Hebrew (he)

clip_language = Language.find_by(iso_name: 'en')
translation_language = Language.find_by(iso_name: 'he')

medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=G7KNmW9a75Y')
phrases_data = [
  [
    "We were good, we were gold",
    "היינו טובים, היינו זהב",
    "00:08"
  ],
  [
    "Kinda dream that can't be sold",
    "מין חלום כזה שאי אפשר למכור",
    "00:12"
  ],
  [
    "We were right 'til we weren't",
    "היה לנו נכון עד שכבר לא",
    "00:16"
  ],
  [
    "Built a home and watched it burn",
    "בנינו בית וראינו אותו נשרף",
    "00:19"
  ],
  [
    "Mmm, I didn't wanna leave you",
    "מממ, לא רציתי לעזוב אותך",
    "00:24"
  ],
  [
    "I didn't wanna lie",
    "לא רציתי לשקר",
    "00:26"
  ],
  [
    "Started to cry but then remembered I",
    "התחלתי לבכות אבל אז נזכרתי שאני",
    "00:28"
  ],
  [
    "I can buy myself flowers",
    "אני יכולה לקנות לעצמי פרחים",
    "00:33"
  ],
  [
    "Write my name in the sand",
    "לכתוב את השם שלי בחול",
    "00:37"
  ],
  [
    "Talk to myself for hours",
    "לדבר עם עצמי שעות",
    "00:41"
  ],
  [
    "Say things you don't understand",
    "לומר דברים שאתה לא מבין",
    "00:45"
  ],
  [
    "I can take myself dancing",
    "אני יכולה לקחת את עצמי לרקוד",
    "00:49"
  ],
  [
    "And I can hold my own hand",
    "ואני יכולה להחזיק לעצמי את היד",
    "00:53"
  ],
  [
    "Yeah, I can love me better than you can",
    "כן, אני יכולה לאהוב אותי טוב יותר ממה שאתה יכול",
    "00:57"
  ],
  [
    "Can love me better, I can love me better, baby",
    "יכולה לאהוב אותי טוב יותר, אני יכולה לאהוב אותי טוב יותר, מותק",
    "01:02"
  ],
  [
    "Can love me better, I can love me better, baby",
    "יכולה לאהוב אותי טוב יותר, אני יכולה לאהוב אותי טוב יותר, מותק",
    "01:06"
  ],
  [
    "Paint my nails, cherry red",
    "צובעת ציפורניים באדום דובדבן",
    "01:09"
  ],
  [
    "Match the roses that you left",
    "מתאימה אותם לוורדים שהשארת",
    "01:12"
  ],
  [
    "No remorse, no regret",
    "בלי ייסורי מצפון, בלי חרטה",
    "01:17"
  ],
  [
    "I forget every word you said",
    "אני שוכחת כל מילה שאמרת",
    "01:20"
  ],
  [
    "Ooh, I didn't wanna leave you, baby",
    "או, לא רציתי לעזוב אותך, מותק",
    "01:25"
  ],
  [
    "I didn't wanna fight",
    "לא רציתי לריב",
    "01:27"
  ],
  [
    "Started to cry but then remembered I",
    "התחלתי לבכות אבל אז נזכרתי שאני",
    "01:29"
  ],
  [
    "I can buy myself flowers",
    "אני יכולה לקנות לעצמי פרחים",
    "01:34"
  ],
  [
    "Write my name in the sand",
    "לכתוב את השם שלי בחול",
    "01:38"
  ],
  [
    "Talk to myself for hours, yeah",
    "לדבר עם עצמי שעות, כן",
    "01:42"
  ],
  [
    "Say things you don't understand",
    "לומר דברים שאתה לא מבין",
    "01:46"
  ],
  [
    "I can take myself dancing",
    "אני יכולה לקחת את עצמי לרקוד",
    "01:50"
  ],
  [
    "And I can hold my own hand",
    "ואני יכולה להחזיק לעצמי את היד",
    "01:54"
  ],
  [
    "Yeah, I can love me better than you can",
    "כן, אני יכולה לאהוב אותי טוב יותר ממה שאתה יכול",
    "01:58"
  ],
  [
    "Can love me better, I can love me better, baby",
    "יכולה לאהוב אותי טוב יותר, אני יכולה לאהוב אותי טוב יותר, מותק",
    "02:02"
  ],
  [
    "Can love me better, I can love me better, baby",
    "יכולה לאהוב אותי טוב יותר, אני יכולה לאהוב אותי טוב יותר, מותק",
    "02:06"
  ],
  [
    "Can love me better, I can love me better, baby",
    "יכולה לאהוב אותי טוב יותר, אני יכולה לאהוב אותי טוב יותר, מותק",
    "02:10"
  ],
  [
    "Can love me better, I...",
    "יכולה לאהוב אותי טוב יותר, אני...",
    "02:14"
  ],
  [
    "I didn't wanna leave you",
    "לא רציתי לעזוב אותך",
    "02:18"
  ],
  [
    "I didn't wanna fight",
    "לא רציתי לריב",
    "02:20"
  ],
  [
    "Started to cry but then remembered I",
    "התחלתי לבכות אבל אז נזכרתי שאני",
    "02:22"
  ],
  [
    "I can buy myself flowers, uh-huh",
    "אני יכולה לקנות לעצמי פרחים, אה-הא",
    "02:27"
  ],
  [
    "Write my name in the sand, ooh",
    "לכתוב את השם שלי בחול, אוו",
    "02:31"
  ],
  [
    "Talk to myself for hours, yeah",
    "לדבר עם עצמי שעות, כן",
    "02:35"
  ],
  [
    "Say things you don't understand",
    "לומר דברים שאתה לא מבין",
    "02:39"
  ],
  [
    "I can take myself dancing, yeah",
    "אני יכולה לקחת את עצמי לרקוד, כן",
    "02:43"
  ],
  [
    "And I can hold my own hand",
    "ואני יכולה להחזיק לעצמי את היד",
    "02:47"
  ],
  [
    "Yeah, I can love me better than",
    "כן, אני יכולה לאהוב אותי טוב יותר מ...",
    "02:50"
  ],
  [
    "Yeah, I can love me better than you can",
    "כן, אני יכולה לאהוב אותי טוב יותר ממה שאתה יכול",
    "02:53"
  ],
  [
    "Can love me better, I can love me better, baby, uh",
    "יכולה לאהוב אותי טוב יותר, אני יכולה לאהוב אותי טוב יותר, מותק, אה",
    "02:59"
  ],
  [
    "Can love me better, I can love me better, baby, ooh",
    "יכולה לאהוב אותי טוב יותר, אני יכולה לאהוב אותי טוב יותר, מותק, אוו",
    "03:02"
  ],
  [
    "Can love me better, I can love me better, baby",
    "יכולה לאהוב אותי טוב יותר, אני יכולה לאהוב אותי טוב יותר, מותק",
    "03:06"
  ],
  [
    "Can love me better, I...",
    "יכולה לאהוב אותי טוב יותר, אני...",
    "03:10"
  ]
];

c = Course.find_or_create_by!(slug: 'flowers') do
  name = 'Flowers'
  main_media_url = 'https://www.youtube.com/watch?v=G7KNmW9a75Y'
end
c.lessons.destroy_all

Lesson.where("slug like 'flowers%'").destroy_all
medium.phrases.destroy_all

# Create phrases in DB
# Each phrase contains text in both clip language and translation language
phrases = phrases_data.map do |text_clip_language, text_translation_language, timestamp|
  Phrase.create!(
    l1: clip_language,
    l2: translation_language,
    text_l1: text_clip_language,
    text_l2: text_translation_language,
    timestamp: timestamp,
    medium: medium
  )
end
medium.phrases.reload

# Create Lessons in the DB

phrase = phrases[0]
phrase.add_token_translation("We were", 0, "היינו", 0, similar_sound: [])
phrase.add_token_translation("good", 0, "טובים", 0, similar_sound: ["wood","could"])
phrase.add_token_translation("we were", 1, "היינו", 1, similar_sound: [])
phrase.add_token_translation("gold", 0, "זהב", 0, similar_sound: ["cold","told"])

phrase = phrases[1]
phrase.add_token_translation("Kinda", 0, "סוג של", 0, similar_sound: [])
phrase.add_token_translation("dream", 0, "חלום", 0, similar_sound: ["cream","team"])
phrase.add_token_translation("that", 0, "ש", 0, similar_sound: ["bat","cat"])
phrase.add_token_translation("can't be", 0, "אי אפשר", 0, similar_sound: [])
phrase.add_token_translation("sold", 0, "למכור", 0, similar_sound: ["cold","told"])

phrase = phrases[2]
phrase.add_token_translation("We were right", 0, "צדקנו", 0, similar_sound: [])
phrase.add_token_translation("til", 0, "עד", 0, similar_sound: ["still","tell"])
phrase.add_token_translation("we weren't", 0, "שלא", 0, similar_sound: [])

phrase = phrases[3]
phrase.add_token_translation("Built", 0, "בניתי", 0, similar_sound: [])
phrase.add_token_translation("home", 0, "בית", 0, similar_sound: ["horn"])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("watched", 0, "ראיתי", 0, similar_sound: [])
phrase.add_token_translation("it", 0, "אותו", 0, similar_sound: [])
phrase.add_token_translation("burn", 0, "נשרף", 0, similar_sound: [])

phrase = phrases[4]
phrase.add_token_translation("Mmm", 0, "מממ", 0, similar_sound: [])
phrase.add_token_translation("I didn't wanna", 0, "לא רציתי", 0, similar_sound: [])
phrase.add_token_translation("leave", 0, "לעזוב", 0, similar_sound: ["live","leaf"])
phrase.add_token_translation("you", 0, "אותך", 0, similar_sound: ["ewe","yew"])

phrase = phrases[5]
phrase.add_token_translation("I didn't wanna", 0, "לא רציתי", 0, similar_sound: [])
phrase.add_token_translation("lie", 0, "לשקר", 0, similar_sound: ["buy","my"])

phrase = phrases[6]
phrase.add_token_translation("Started to", 0, "התחלתי", 0, similar_sound: [])
phrase.add_token_translation("cry", 0, "לבכות", 0, similar_sound: ["dry","try"])
phrase.add_token_translation("but", 0, "אבל", 0, similar_sound: ["bat","cut"])
phrase.add_token_translation("then", 0, "אז", 0, similar_sound: ["den","ten"])
phrase.add_token_translation("remembered", 0, "נזכרתי", 0, similar_sound: ["numbered"])
phrase.add_token_translation("I", 0, "שאני", 0, similar_sound: ["eye","high"])

phrase = phrases[7]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("buy", 0, "לקנות", 0, similar_sound: [])
phrase.add_token_translation("myself", 0, "לעצמי", 0, similar_sound: [])
phrase.add_token_translation("flowers", 0, "פרחים", 0, similar_sound: [])

phrase = phrases[8]
phrase.add_token_translation("Write", 0, "לכתוב", 0, similar_sound: ["right","light","white"])
phrase.add_token_translation("my name", 0, "את שמי", 0, similar_sound: [])
phrase.add_token_translation("in the sand", 0, "בחול", 0, similar_sound: [])

phrase = phrases[9]
phrase.add_token_translation("Talk to", 0, "לדבר עם", 0, similar_sound: ["walk to"])
phrase.add_token_translation("myself", 0, "עצמי", 0, similar_sound: ["my shelf"])
phrase.add_token_translation("for hours", 0, "שעות", 0, similar_sound: ["four hours","far hours"])

phrase = phrases[10]
phrase.add_token_translation("Say", 0, "אומרת", 0, similar_sound: [])
phrase.add_token_translation("things", 0, "דברים", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("don't understand", 0, "לא מבין", 0, similar_sound: [])

phrase = phrases[11]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","aye"])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: ["kin","khan"])
phrase.add_token_translation("take myself", 0, "לקחת את עצמי", 0, similar_sound: [])
phrase.add_token_translation("dancing", 0, "לריקודים", 0, similar_sound: ["prancing","glancing"])

phrase = phrases[12]
phrase.add_token_translation("And", 0, "ואני", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "ואני", 0, similar_sound: [])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: ["fan","man","ran"])
phrase.add_token_translation("hold", 0, "להחזיק", 0, similar_sound: ["cold","told","bold"])
phrase.add_token_translation("my", 0, "שלי", 0, similar_sound: ["buy","high","lie"])
phrase.add_token_translation("hand", 0, "היד", 0, similar_sound: ["sand","land","band"])

phrase = phrases[13]
phrase.add_token_translation("Yeah", 0, "כן", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: ["man","ran"])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: ["glove","above"])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: ["see","tea"])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: ["letter","setter"])
phrase.add_token_translation("than you can", 0, "ממה שאתה יכול", 0, similar_sound: [])

phrase = phrases[14]
phrase.add_token_translation("Can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: [])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 1, "יכולה", 1, similar_sound: [])
phrase.add_token_translation("love", 1, "לאהוב", 1, similar_sound: [])
phrase.add_token_translation("me", 1, "את עצמי", 1, similar_sound: [])
phrase.add_token_translation("better", 1, "טוב יותר", 1, similar_sound: [])
phrase.add_token_translation("baby", 0, "בייבי", 0, similar_sound: [])

phrase = phrases[15]
phrase.add_token_translation("Can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: [])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 1, "יכולה", 1, similar_sound: [])
phrase.add_token_translation("love", 1, "לאהוב", 1, similar_sound: [])
phrase.add_token_translation("me", 1, "את עצמי", 1, similar_sound: [])
phrase.add_token_translation("better", 1, "טוב יותר", 1, similar_sound: [])
phrase.add_token_translation("baby", 0, "בייבי", 0, similar_sound: [])

phrase = phrases[16]
phrase.add_token_translation("Paint", 0, "אצבע", 0, similar_sound: [])
phrase.add_token_translation("my nails", 0, "ציפורניים", 0, similar_sound: [])
phrase.add_token_translation("cherry", 0, "דובדבן", 0, similar_sound: [])
phrase.add_token_translation("red", 0, "באדום", 0, similar_sound: [])

phrase = phrases[17]
phrase.add_token_translation("Match", 0, "להתאים", 0, similar_sound: [])
phrase.add_token_translation("the", 0, "ה", 0, similar_sound: [])
phrase.add_token_translation("roses", 0, "לוורדים", 0, similar_sound: [])
phrase.add_token_translation("that", 0, "ש", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("left", 0, "השארת", 0, similar_sound: ["lift"])

phrase = phrases[18]
phrase.add_token_translation("No", 0, "בלי", 0, similar_sound: ["know","go"])
phrase.add_token_translation("remorse", 0, "ייסורי מצפון", 0, similar_sound: ["resource","rehearsed"])
phrase.add_token_translation("no", 1, "בלי", 1, similar_sound: ["know","go"])
phrase.add_token_translation("regret", 0, "חרטה", 0, similar_sound: [])

phrase = phrases[19]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("forget", 0, "שוכחת", 0, similar_sound: ["forgive","regret"])
phrase.add_token_translation("every", 0, "כל", 0, similar_sound: ["ever","very"])
phrase.add_token_translation("word", 0, "מילה", 0, similar_sound: ["world","wore"])
phrase.add_token_translation("you said", 0, "שאמרת", 0, similar_sound: [])

phrase = phrases[20]
phrase.add_token_translation("Ooh", 0, "אוו,", 0, similar_sound: [])
phrase.add_token_translation("I didn't wanna", 0, "לא רציתי", 0, similar_sound: [])
phrase.add_token_translation("leave", 0, "לעזוב", 0, similar_sound: ["live","leaf"])
phrase.add_token_translation("you", 0, "אותך,", 0, similar_sound: ["ewe","yew"])
phrase.add_token_translation("baby", 0, "מותק", 0, similar_sound: ["maybe","babe"])

phrase = phrases[21]
phrase.add_token_translation("I didn't wanna", 0, "לא רציתי", 0, similar_sound: [])
phrase.add_token_translation("fight", 0, "לריב", 0, similar_sound: ["light","night","right"])

phrase = phrases[22]
phrase.add_token_translation("Started to", 0, "התחלתי", 0, similar_sound: [])
phrase.add_token_translation("cry", 0, "לבכות", 0, similar_sound: ["dry","try"])
phrase.add_token_translation("but", 0, "אבל", 0, similar_sound: ["bat","cut"])
phrase.add_token_translation("then", 0, "אז", 0, similar_sound: ["den","when"])
phrase.add_token_translation("remembered", 0, "נזכרתי", 0, similar_sound: ["numbered","reminded"])
phrase.add_token_translation("I", 0, "שאני", 0, similar_sound: ["eye","high"])

phrase = phrases[23]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("buy", 0, "לקנות", 0, similar_sound: [])
phrase.add_token_translation("myself", 0, "לעצמי", 0, similar_sound: [])
phrase.add_token_translation("flowers", 0, "פרחים", 0, similar_sound: [])

phrase = phrases[24]
phrase.add_token_translation("Write", 0, "לכתוב", 0, similar_sound: ["right","light","white"])
phrase.add_token_translation("my name", 0, "את שמי", 0, similar_sound: [])
phrase.add_token_translation("in the sand", 0, "בחול", 0, similar_sound: [])

phrase = phrases[25]
phrase.add_token_translation("Talk to myself", 0, "מדברת עם עצמי", 0, similar_sound: [])
phrase.add_token_translation("for hours", 0, "שעות", 0, similar_sound: ["flowers"])
phrase.add_token_translation("yeah", 0, "כן", 0, similar_sound: ["yay","yea"])

phrase = phrases[26]
phrase.add_token_translation("Say", 0, "אומרת", 0, similar_sound: [])
phrase.add_token_translation("things", 0, "דברים", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("don't", 0, "לא", 0, similar_sound: [])
phrase.add_token_translation("understand", 0, "מבין", 0, similar_sound: [])

phrase = phrases[27]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","aye"])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: ["kin","khan"])
phrase.add_token_translation("take myself", 0, "לקחת את עצמי", 0, similar_sound: [])
phrase.add_token_translation("dancing", 0, "לריקודים", 0, similar_sound: ["prancing","glancing"])

phrase = phrases[28]
phrase.add_token_translation("And", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("hold", 0, "להחזיק", 0, similar_sound: [])
phrase.add_token_translation("my own", 0, "שלי", 0, similar_sound: [])
phrase.add_token_translation("hand", 0, "היד", 0, similar_sound: [])

phrase = phrases[29]
phrase.add_token_translation("Yeah", 0, "כן", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: ["man","ran"])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: ["glove","above"])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: ["see","tea"])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: ["letter","setter"])
phrase.add_token_translation("than you can", 0, "ממה שאתה יכול", 0, similar_sound: [])

phrase = phrases[30]
phrase.add_token_translation("Can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: [])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 1, "יכולה", 1, similar_sound: [])
phrase.add_token_translation("love", 1, "לאהוב", 1, similar_sound: [])
phrase.add_token_translation("me", 1, "את עצמי", 1, similar_sound: [])
phrase.add_token_translation("better", 1, "טוב יותר", 1, similar_sound: [])
phrase.add_token_translation("baby", 0, "בייבי", 0, similar_sound: [])

phrase = phrases[31]
phrase.add_token_translation("Can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: [])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 1, "יכולה", 1, similar_sound: [])
phrase.add_token_translation("love", 1, "לאהוב", 1, similar_sound: [])
phrase.add_token_translation("me", 1, "את עצמי", 1, similar_sound: [])
phrase.add_token_translation("better", 1, "טוב יותר", 1, similar_sound: [])
phrase.add_token_translation("baby", 0, "בייבי", 0, similar_sound: [])

phrase = phrases[32]
phrase.add_token_translation("Can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: [])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 1, "יכולה", 1, similar_sound: [])
phrase.add_token_translation("love", 1, "לאהוב", 1, similar_sound: [])
phrase.add_token_translation("me", 1, "את עצמי", 1, similar_sound: [])
phrase.add_token_translation("better", 1, "טוב יותר", 1, similar_sound: [])
phrase.add_token_translation("baby", 0, "בייבי", 0, similar_sound: [])

phrase = phrases[33]
phrase.add_token_translation("Can", 0, "יכולה", 0, similar_sound: ["ran","man"])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: ["glove","above"])
phrase.add_token_translation("me", 0, "אותי", 0, similar_sound: ["see","tea"])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: ["letter","setter"])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])

phrase = phrases[34]
phrase.add_token_translation("I didn't wanna", 0, "לא רציתי", 0, similar_sound: [])
phrase.add_token_translation("leave", 0, "לעזוב", 0, similar_sound: ["live","leaf"])
phrase.add_token_translation("you", 0, "אותך", 0, similar_sound: ["ewe","yew"])

phrase = phrases[35]
phrase.add_token_translation("I didn't wanna", 0, "לא רציתי", 0, similar_sound: [])
phrase.add_token_translation("fight", 0, "להילחם", 0, similar_sound: [])

phrase = phrases[36]
phrase.add_token_translation("Started to", 0, "התחלתי", 0, similar_sound: [])
phrase.add_token_translation("cry", 0, "לבכות", 0, similar_sound: ["dry","try"])
phrase.add_token_translation("but", 0, "אבל", 0, similar_sound: ["bat","cut"])
phrase.add_token_translation("then", 0, "אז", 0, similar_sound: ["den","ten"])
phrase.add_token_translation("remembered", 0, "נזכרתי", 0, similar_sound: ["numbered"])
phrase.add_token_translation("I", 0, "שאני", 0, similar_sound: ["eye","high"])

phrase = phrases[37]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye"])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: ["fan","man"])
phrase.add_token_translation("buy", 0, "לקנות", 0, similar_sound: ["by","bye"])
phrase.add_token_translation("myself", 0, "לעצמי", 0, similar_sound: [])
phrase.add_token_translation("flowers", 0, "פרחים", 0, similar_sound: ["flour"])
phrase.add_token_translation("uh-huh", 0, "אה-הא", 0, similar_sound: [])

phrase = phrases[38]
phrase.add_token_translation("Write", 0, "אכתוב", 0, similar_sound: [])
phrase.add_token_translation("my name", 0, "שמי", 0, similar_sound: [])
phrase.add_token_translation("in the sand", 0, "בחול", 0, similar_sound: [])
phrase.add_token_translation("ooh", 0, "אוו", 0, similar_sound: [])

phrase = phrases[39]
phrase.add_token_translation("Talk to myself", 0, "מדברת עם עצמי", 0, similar_sound: [])
phrase.add_token_translation("for hours", 0, "שעות", 0, similar_sound: ["flowers"])
phrase.add_token_translation("yeah", 0, "כן", 0, similar_sound: ["yay","yea"])

phrase = phrases[40]
phrase.add_token_translation("Say", 0, "אומרת", 0, similar_sound: [])
phrase.add_token_translation("things", 0, "דברים", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("don't", 0, "לא", 0, similar_sound: [])
phrase.add_token_translation("understand", 0, "מבין", 0, similar_sound: [])

phrase = phrases[41]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: ["fan","man"])
phrase.add_token_translation("take", 0, "לקחת", 0, similar_sound: ["make","bake"])
phrase.add_token_translation("myself", 0, "את עצמי", 0, similar_sound: ["by self","my shelf"])
phrase.add_token_translation("dancing", 0, "לרקוד", 0, similar_sound: ["prancing","glancing"])
phrase.add_token_translation("yeah", 0, "כן", 0, similar_sound: ["yay","nay"])

phrase = phrases[42]
phrase.add_token_translation("And", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("hold", 0, "להחזיק", 0, similar_sound: [])
phrase.add_token_translation("my own", 0, "שלי", 0, similar_sound: [])
phrase.add_token_translation("hand", 0, "היד", 0, similar_sound: [])

phrase = phrases[43]
phrase.add_token_translation("Yeah", 0, "כן", 0, similar_sound: ["nay","yay"])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: ["man","ran"])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: ["glove","dove"])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: ["see","tea"])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: ["letter","setter"])
phrase.add_token_translation("than", 0, "מ", 0, similar_sound: ["fan","ran"])

phrase = phrases[44]
phrase.add_token_translation("Yeah", 0, "כן", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])
phrase.add_token_translation("can", 0, "יכולה", 0, similar_sound: ["man","ran"])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: ["glove","above"])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: ["see","tea"])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: ["letter","setter"])
phrase.add_token_translation("than you can", 0, "ממה שאתה יכול", 0, similar_sound: [])

phrase = phrases[45]
phrase.add_token_translation("Can", 0, "יכולה", 0, similar_sound: ["fan","man"])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: ["glove","dove"])
phrase.add_token_translation("me", 0, "אותי", 0, similar_sound: ["see","tea"])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: ["letter","setter"])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])
phrase.add_token_translation("can", 1, "יכולה", 1, similar_sound: ["fan","man"])
phrase.add_token_translation("love", 1, "לאהוב", 1, similar_sound: ["glove","dove"])
phrase.add_token_translation("me", 1, "אותי", 1, similar_sound: ["see","tea"])
phrase.add_token_translation("better", 1, "טוב יותר", 1, similar_sound: ["letter","setter"])
phrase.add_token_translation("baby", 0, "מותק", 0, similar_sound: ["maybe","lady"])
phrase.add_token_translation("uh", 0, "אה", 0, similar_sound: [])

phrase = phrases[46]
phrase.add_token_translation("Can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: ["dove"])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: [])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["pie"])
phrase.add_token_translation("can", 1, "יכולה", 1, similar_sound: [])
phrase.add_token_translation("love", 1, "לאהוב", 1, similar_sound: ["have"])
phrase.add_token_translation("me", 1, "את עצמי", 1, similar_sound: [])
phrase.add_token_translation("better", 1, "טוב יותר", 1, similar_sound: [])
phrase.add_token_translation("baby", 0, "מותק", 0, similar_sound: [])
phrase.add_token_translation("ooh", 0, "אוו", 0, similar_sound: [])

phrase = phrases[47]
phrase.add_token_translation("Can", 0, "יכולה", 0, similar_sound: [])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: ["globe"])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: [])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["bye"])
phrase.add_token_translation("can", 1, "יכולה", 1, similar_sound: [])
phrase.add_token_translation("love", 1, "לאהוב", 1, similar_sound: [])
phrase.add_token_translation("me", 1, "את עצמי", 1, similar_sound: [])
phrase.add_token_translation("better", 1, "טוב יותר", 1, similar_sound: [])
phrase.add_token_translation("baby", 0, "בייבי", 0, similar_sound: [])

phrase = phrases[48]
phrase.add_token_translation("Can", 0, "יכולה", 0, similar_sound: ["tan","fan","man"])
phrase.add_token_translation("love", 0, "לאהוב", 0, similar_sound: ["glove","dove","above"])
phrase.add_token_translation("me", 0, "את עצמי", 0, similar_sound: ["see","bee","tree"])
phrase.add_token_translation("better", 0, "טוב יותר", 0, similar_sound: ["letter","setter","fetter"])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","buy","high"])

l = Lesson.create!(medium: medium, slug: 'flowers0', course: c, order: 0, name: 'The Past - We Were Good')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(0, 1, 2, 3)

      a.token_translations = [phrases[0].find_token_translation("We were"),
phrases[0].find_token_translation("gold"),
phrases[1].find_token_translation("dream"),
phrases[1].find_token_translation("sold"),
phrases[2].find_token_translation("We were right"),
phrases[3].find_token_translation("home"),
phrases[3].find_token_translation("it")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(0, 1, 2, 3)

      a.token_translations = [phrases[0].find_token_translation("gold"),
phrases[1].find_token_translation("sold"),
phrases[2].find_token_translation("til"),
phrases[3].find_token_translation("home")]
      

l = Lesson.create!(medium: medium, slug: 'flowers1', course: c, order: 1, name: 'Emotional Transition')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(4, 5, 6)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(4, 5, 6)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(4, 5, 6)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(4, 5, 6)

a.token_translations = [phrases[4].find_token_translation("leave"),
phrases[5].find_token_translation("lie"),
phrases[6].find_token_translation("cry"),
phrases[6].find_token_translation("but")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(4, 5, 6)



a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(4, 5, 6)

      a.token_translations = [phrases[4].find_token_translation("leave"),
phrases[5].find_token_translation("lie"),
phrases[6].find_token_translation("cry"),
phrases[6].find_token_translation("but")]
      

l = Lesson.create!(medium: medium, slug: 'flowers2', course: c, order: 2, name: 'Self-Empowerment Chorus')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(7, 8, 9, 10, 11, 12, 13)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(7, 8, 9, 10)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(7, 8, 9, 10)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(7, 8, 9, 10)

      a.token_translations = [phrases[7].find_token_translation("I"),
phrases[7].find_token_translation("flowers"),
phrases[8].find_token_translation("in the sand"),
phrases[10].find_token_translation("things"),
phrases[10].find_token_translation("don't understand"),
phrases[11].find_token_translation("can"),
phrases[11].find_token_translation("dancing"),
phrases[12].find_token_translation("can"),
phrases[12].find_token_translation("my"),
phrases[13].find_token_translation("I"),
phrases[13].find_token_translation("love")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(7, 8, 9, 10)



a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(7, 8, 9, 10, 11, 12, 13)

      a.token_translations = [phrases[8].find_token_translation("Write"),
phrases[9].find_token_translation("for hours"),
phrases[11].find_token_translation("dancing"),
phrases[12].find_token_translation("can"),
phrases[12].find_token_translation("hand"),
phrases[13].find_token_translation("better")]
      
l = Lesson.create!(medium: medium, slug: 'flowers4', course: c, order: 4, name: 'Moving Forward - New Beginnings')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(16, 17, 18, 19)

a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(16, 17, 18, 19)

a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(16, 17, 18, 19)


a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(16, 17, 18, 19)

a.token_translations = [phrases[16].find_token_translation("red"),
phrases[16].find_token_translation("my nails"),
phrases[17].find_token_translation("roses"),
phrases[18].find_token_translation("regret"),
phrases[19].find_token_translation("I")].filter {|t| t.l2_start_index.present? }

a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(16, 17, 18, 19)

a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(16, 17, 18, 19)

a.token_translations = [
  phrases[16].find_token_translation("cherry"),
  phrases[17].find_token_translation("left"),
  phrases[18].find_token_translation("regret"),
phrases[19].find_token_translation("word")]
      

l = Lesson.create!(medium: medium, slug: 'flowers5', course: c, order: 5, name: 'Second Emotional Transition')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(20, 21, 22)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(20, 21, 22)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(20, 21, 22)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(20, 21, 22)

      a.token_translations = [phrases[20].find_token_translation("leave"),
phrases[21].find_token_translation("fight"),
phrases[22].find_token_translation("cry"),
phrases[22].find_token_translation("remembered")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(20, 21, 22)



a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(20, 21, 22)

      a.token_translations = [phrases[20].find_token_translation("baby"),
phrases[22].find_token_translation("remembered"),
phrases[22].find_token_translation("I")]
      

l = Lesson.create!(medium: medium, slug: 'flowers7', course: c, order: 7, name: 'Final Emotional Release')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(33, 34, 35)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(33, 34, 35)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(33, 34, 35)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(33, 34, 35)

      a.token_translations = [phrases[33].find_token_translation("love"),
phrases[33].find_token_translation("better"),
phrases[34].find_token_translation("leave"),
phrases[35].find_token_translation("I didn't wanna"),
phrases[35].find_token_translation("fight")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(33, 34, 35)



a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(33, 34, 35)

      a.token_translations = [phrases[33].find_token_translation("love"),
phrases[33].find_token_translation("better"),
phrases[34].find_token_translation("leave")]
      

l = Lesson.create!(medium: medium, slug: 'flowers8', course: c, order: 8, name: 'Outro - Lasting Self-Love')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(44, 45, 46, 47)


a = Activities::ListenActivity.create!(lesson: l, order: 6)
a.phrases = phrases.values_at(44, 45, 46, 47)

a.token_translations = [phrases[44].find_token_translation("love"),
phrases[45].find_token_translation("better"),
phrases[45].find_token_translation("baby"),
phrases[46].find_token_translation("love"),
phrases[47].find_token_translation("love"),
]
      
