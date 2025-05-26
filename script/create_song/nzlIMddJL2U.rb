
# Language Configuration
# Clip Language: Arabic (ar-ps)
# Translation Language: Hebrew (he)

clip_language = Language.find_by(iso_name: 'ar-ps')
translation_language = Language.find_by(iso_name: 'he')

medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=nzlIMddJL2U')
phrases_data = [
  [
    "كل الناس خير وبركة",
    "כל האנשים טוב וברכה",
    "00:31"
  ],
  [
    "كل الناس خير وبركة",
    "כל האנשים טוב וברכה",
    "00:34"
  ],
  [
    "كل الناس خير وبركة",
    "כל האנשים טוב וברכה",
    "00:38"
  ],
  [
    "كل الناس خير وبركة",
    "כל האנשים טוב וברכה",
    "00:42"
  ],
  [
    "مش مهم شو دينك",
    "לא חשוב מה דתך",
    "00:46"
  ],
  [
    "مسلم ولا بوذي، مسيحي أو يهودي",
    "מוסלמי או בודהיסטי, נוצרי או יהודי",
    "00:48"
  ],
  [
    "مش مهم شو لونك",
    "לא חשוב מה צבעך",
    "00:50"
  ],
  [
    "أبيض ولا أسود، أصفر ولا أسمر",
    "לבן או שחור, צהוב או שחום",
    "00:52"
  ],
  [
    "مش مهم شو لغتك",
    "לא חשוב מה שפתך",
    "00:54"
  ],
  [
    "عربي، ألماني، إسباني أو ياباني",
    "ערבית, גרמנית, ספרדית או יפנית",
    "00:56"
  ],
  [
    "مش مهم شو جنسك",
    "לא חשוב מה מינך",
    "00:58"
  ],
  [
    "صبي ولا بنت، هومو ولا ليزبيان",
    "בן או בת, הומו או לסבית",
    "01:00"
  ],
  [
    "كل الناس بتخلق قلبها أبيض",
    "כל האנשים נולדים עם לב לבן",
    "01:02"
  ],
  [
    "ملاني بطاقة إيجابية",
    "מלא באנרגיה חיובית",
    "01:03"
  ],
  [
    "لو بس بيعلموك، بيفهموك",
    "אם רק ילמדו אותך, יבינו אותך",
    "01:05"
  ],
  [
    "الاختلاف بطريقة صحية",
    "את השונות בדרך בריאה",
    "01:07"
  ],
  [
    "ويكون في مساواة",
    "ושיהיה שוויון",
    "01:09"
  ],
  [
    "لكل حدا بالبيت، معلمة تصير حنية",
    "לכל אחד בבית, מורה שתהיה רחומה",
    "01:10"
  ],
  [
    "ونآمن ببعض، نستعمل الحب",
    "ונאמין אחד בשני, נשתמש באהבה",
    "01:13"
  ],
  [
    "اللي هو الخلطة السحرية",
    "שהיא התערובת הקסומה",
    "01:15"
  ],
  [
    "وكل الناس خير وبركة",
    "וכל האנשים טוב וברכה",
    "01:17"
  ],
  [
    "كل الناس خير وبركة",
    "כל האנשים טוב וברכה",
    "01:21"
  ],
  [
    "كل الناس خير وبركة",
    "כל האנשים טוב וברכה",
    "01:24"
  ],
  [
    "كل الناس خير وبركة",
    "כל האנשים טוב וברכה",
    "01:28"
  ],
  [
    "مش مهم شو شغلك",
    "לא חשוב מה עבודתך",
    "01:48"
  ],
  [
    "محامي أو فلاح، تبرجي أو أستاذ",
    "עורך דין או חקלאי, טכנאי או מורה",
    "01:50"
  ],
  [
    "مش مهم شو لابس",
    "לא חשוב מה אתה לובש",
    "01:52"
  ],
  [
    "جديد أو قديم، عالموضة ولا لأ",
    "חדש או ישן, באופנה או לא",
    "01:53"
  ],
  [
    "مش مهم وين ساكن",
    "לא חשוב איפה אתה גר",
    "01:56"
  ],
  [
    "قصر ولا كوخ، خيمة أو زقزوق",
    "ארמון או צריף, אוהל או סמטה",
    "01:57"
  ],
  [
    "مش مهم مين بيّك",
    "לא חשוב מי אביך",
    "02:00"
  ],
  [
    "مواطن ولا وزير، غني أو فقير",
    "אזרח או שר, עשיר או עני",
    "02:01"
  ],
  [
    "كل الناس بتخلق قلبها أبيض",
    "כל האנשים נולדים עם לב לבן",
    "02:03"
  ],
  [
    "ملاني بطاقة إيجابية",
    "מלא באנרגיה חיובית",
    "02:05"
  ],
  [
    "لو بس بيعلموك، بيفهموك",
    "אם רק ילמדו אותך, יבינו אותך",
    "02:07"
  ],
  [
    "الاختلاف بطريقة صحية",
    "את השונות בדרך בריאה",
    "02:09"
  ],
  [
    "ويكون في مساواة",
    "ושיהיה שוויון",
    "02:10"
  ],
  [
    "لكل حدا بالبيت، معلمة تصير حنية",
    "לכל אחד בבית, מורה שתהיה רחומה",
    "02:12"
  ],
  [
    "ونآمن ببعض، نستعمل الحب",
    "ונאמין אחד בשני, נשתמש באהבה",
    "02:15"
  ],
  [
    "اللي هو الخلطة السحرية",
    "שהיא התערובת הקסומה",
    "02:17"
  ],
  [
    "وكل الناس خير وبركة",
    "וכל האנשים טוב וברכה",
    "02:19"
  ],
  [
    "كل الناس خير وبركة",
    "כל האנשים טוב וברכה",
    "02:22"
  ],
  [
    "كل الناس خير وبركة",
    "כל האנשים טוב וברכה",
    "02:26"
  ],
  [
    "كل الناس خير وبركة",
    "כל האנשים טוב וברכה",
    "02:29"
  ]
];

c = Course.find_or_create_by!(slug: 'kl-el-nas')
c.name = 'kl-el-nas'
c.main_media_url = 'https://www.youtube.com/watch?v=nzlIMddJL2U'
c.save!
c.reload
c.lessons.destroy_all

Lesson.where("slug like 'kl-el-nas%'").destroy_all
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
phrase.add_token_translation("كل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "מבורכים", 0, similar_sound: [])

phrase = phrases[1]
phrase.add_token_translation("كل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "מבורכים", 0, similar_sound: [])

phrase = phrases[2]
phrase.add_token_translation("كل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "מבורכים", 0, similar_sound: [])

phrase = phrases[3]
phrase.add_token_translation("كل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "מבורכים", 0, similar_sound: [])

phrase = phrases[4]
phrase.add_token_translation("مش مهم", 0, "לא משנה", 0, similar_sound: [])
phrase.add_token_translation("شو", 0, "מה", 0, similar_sound: [])
phrase.add_token_translation("دينك", 0, "הדת שלך", 0, similar_sound: [])

phrase = phrases[5]
phrase.add_token_translation("مسلم", 0, "מוסלמי", 0, similar_sound: [])
phrase.add_token_translation("ولا", 0, "או", 0, similar_sound: [])
phrase.add_token_translation("بوذي", 0, "בודהיסטי", 0, similar_sound: [])
phrase.add_token_translation("مسيحي", 0, "נוצרי", 0, similar_sound: [])
phrase.add_token_translation("أو", 0, "או", 1, similar_sound: [])
phrase.add_token_translation("يهودي", 0, "יהודי", 0, similar_sound: [])

phrase = phrases[6]
phrase.add_token_translation("مش", 0, "לא", 0, similar_sound: ["مشى","مشي"])
phrase.add_token_translation("مهم", 0, "משנה", 0, similar_sound: ["مهما","هم"])
phrase.add_token_translation("شو", 0, "מה", 0, similar_sound: ["شوق","شوي"])
phrase.add_token_translation("لونك", 0, "צבעך", 0, similar_sound: ["كونك","عونك"])

phrase = phrases[7]
phrase.add_token_translation("أبيض", 0, "לבן", 0, similar_sound: ["أرض"])
phrase.add_token_translation("ولا", 0, "או", 0, similar_sound: ["على"])
phrase.add_token_translation("أسود", 0, "שחור", 0, similar_sound: ["أسد"])
phrase.add_token_translation("أصفر", 0, "צהוב", 0, similar_sound: ["أصغر"])
phrase.add_token_translation("ولا", 1, "או", 1, similar_sound: ["على"])
phrase.add_token_translation("أسمر", 0, "שחום", 0, similar_sound: ["أكثر"])

phrase = phrases[8]
phrase.add_token_translation("مش", 0, "לא", 0, similar_sound: [])
phrase.add_token_translation("مهم", 0, "משנה", 0, similar_sound: [])
phrase.add_token_translation("شو", 0, "מה", 0, similar_sound: [])
phrase.add_token_translation("لغتك", 0, "השפה שלך", 0, similar_sound: [])

phrase = phrases[9]
phrase.add_token_translation("عربي", 0, "ערבית", 0, similar_sound: ["عربة"])
phrase.add_token_translation("ألماني", 0, "גרמנית", 0, similar_sound: ["أماني"])
phrase.add_token_translation("إسباني", 0, "ספרדית", 0, similar_sound: ["إنساني"])
phrase.add_token_translation("أو", 0, "או", 0, similar_sound: ["هو"])
phrase.add_token_translation("ياباني", 0, "יפנית", 0, similar_sound: [])

phrase = phrases[10]
phrase.add_token_translation("مش", 0, "לא", 0, similar_sound: [])
phrase.add_token_translation("مهم", 0, "משנה", 0, similar_sound: [])
phrase.add_token_translation("شو", 0, "מה", 0, similar_sound: [])
phrase.add_token_translation("جنسك", 0, "המגדר שלך", 0, similar_sound: [])

phrase = phrases[11]
phrase.add_token_translation("صبي", 0, "בן", 0, similar_sound: [])
phrase.add_token_translation("ولا", 0, "או", 0, similar_sound: [])
phrase.add_token_translation("بنت", 0, "בת", 0, similar_sound: [])
phrase.add_token_translation("هومو", 0, "הומו", 0, similar_sound: [])
phrase.add_token_translation("ولا", 1, "או", 1, similar_sound: [])
phrase.add_token_translation("ليزبيان", 0, "לסבית", 0, similar_sound: [])

phrase = phrases[12]
phrase.add_token_translation("كل الناس", 0, "כל האנשים", 0, similar_sound: [])
phrase.add_token_translation("بتخلق", 0, "נולדים", 0, similar_sound: ["بتخنق"])
phrase.add_token_translation("قلبها", 0, "עם לב", 0, similar_sound: ["كلبها"])
phrase.add_token_translation("أبيض", 0, "לבן", 0, similar_sound: ["أخضر"])

phrase = phrases[13]
phrase.add_token_translation("ملاني", 0, "מלאה", 0, similar_sound: [])
phrase.add_token_translation("بطاقة", 0, "באנרגיה", 0, similar_sound: [])
phrase.add_token_translation("إيجابية", 0, "חיובית", 0, similar_sound: [])

phrase = phrases[14]
phrase.add_token_translation("لو", 0, "אם", 0, similar_sound: [])
phrase.add_token_translation("بس", 0, "רק", 0, similar_sound: [])
phrase.add_token_translation("بيعلموك", 0, "היו מלמדים אתכם", 0, similar_sound: [])
phrase.add_token_translation("بيفهموك", 0, "היו מבינים אתכם", 0, similar_sound: [])

phrase = phrases[15]
phrase.add_token_translation("الاختلاف", 0, "השוני", 0, similar_sound: [])
phrase.add_token_translation("بطريقة", 0, "בצורה", 0, similar_sound: ["بصديقة"])
phrase.add_token_translation("صحية", 0, "בריאה", 0, similar_sound: ["ضحية"])

phrase = phrases[16]
phrase.add_token_translation("ويكون في", 0, "ושתהיה", 0, similar_sound: ["ويكونوا في"])
phrase.add_token_translation("مساواة", 0, "שוויון", 0, similar_sound: ["مساومة"])

phrase = phrases[17]
phrase.add_token_translation("لكل", 0, "לכל", 0, similar_sound: [])
phrase.add_token_translation("حدا", 0, "אחד", 0, similar_sound: [])
phrase.add_token_translation("بالبيت", 0, "בבית", 0, similar_sound: [])
phrase.add_token_translation("معلمة", 0, "מורה", 0, similar_sound: [])
phrase.add_token_translation("تصير", 0, "שתהפוך", 0, similar_sound: [])
phrase.add_token_translation("حنية", 0, "לרוך", 0, similar_sound: [])

phrase = phrases[18]
phrase.add_token_translation("ونآمن", 0, "ונאמין", 0, similar_sound: [])
phrase.add_token_translation("ببعض", 0, "אחד בשני", 0, similar_sound: [])
phrase.add_token_translation("نستعمل", 0, "נשתמש", 0, similar_sound: [])
phrase.add_token_translation("الحب", 0, "באהבה", 0, similar_sound: [])

phrase = phrases[19]
phrase.add_token_translation("اللي هو", 0, "שהוא", 0, similar_sound: [])
phrase.add_token_translation("الخلطة", 0, "תערובת", 0, similar_sound: ["الخطة"])
phrase.add_token_translation("السحرية", 0, "הקסם", 0, similar_sound: ["السرية"])

phrase = phrases[20]
phrase.add_token_translation("وكل", 0, "וכל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: ["خيار"])
phrase.add_token_translation("وبركة", 0, "ומבורכים", 0, similar_sound: ["بركة"])

phrase = phrases[21]
phrase.add_token_translation("كل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "מבורכים", 0, similar_sound: [])

phrase = phrases[22]
phrase.add_token_translation("كل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "מבורכים", 0, similar_sound: [])

phrase = phrases[23]
phrase.add_token_translation("كل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "מבורכים", 0, similar_sound: [])

phrase = phrases[24]
phrase.add_token_translation("مش", 0, "לא", 0, similar_sound: [])
phrase.add_token_translation("مهم", 0, "משנה", 0, similar_sound: [])
phrase.add_token_translation("شو", 0, "מה", 0, similar_sound: [])
phrase.add_token_translation("شغلك", 0, "העבודה שלך", 0, similar_sound: [])

phrase = phrases[25]
phrase.add_token_translation("محامي", 0, "עורך דין", 0, similar_sound: [])
phrase.add_token_translation("أو", 0, "או", 0, similar_sound: [])
phrase.add_token_translation("فلاح", 0, "חקלאי", 0, similar_sound: [])
phrase.add_token_translation("تبرجي", 0, "מגדלן", 0, similar_sound: [])
phrase.add_token_translation("أو", 1, "או", 1, similar_sound: [])
phrase.add_token_translation("أستاذ", 0, "מורה", 0, similar_sound: [])

phrase = phrases[26]
phrase.add_token_translation("مش", 0, "לא", 0, similar_sound: [])
phrase.add_token_translation("مهم", 0, "משנה", 0, similar_sound: [])
phrase.add_token_translation("شو", 0, "מה", 0, similar_sound: [])
phrase.add_token_translation("لابس", 0, "לובש", 0, similar_sound: [])

phrase = phrases[27]
phrase.add_token_translation("جديد", 0, "חדש", 0, similar_sound: [])
phrase.add_token_translation("أو", 0, "או", 0, similar_sound: [])
phrase.add_token_translation("قديم", 0, "ישן", 0, similar_sound: [])
phrase.add_token_translation("عالموضة", 0, "באופנה", 0, similar_sound: [])
phrase.add_token_translation("ولا لأ", 0, "או לא", 0, similar_sound: [])

phrase = phrases[28]
phrase.add_token_translation("مش", 0, "לא", 0, similar_sound: [])
phrase.add_token_translation("مهم", 0, "משנה", 0, similar_sound: [])
phrase.add_token_translation("وين", 0, "איפה", 0, similar_sound: [])
phrase.add_token_translation("ساكن", 0, "גר", 0, similar_sound: [])

phrase = phrases[29]
phrase.add_token_translation("قصر", 0, "ארמון", 0, similar_sound: ["كسر"])
phrase.add_token_translation("ولا", 0, "או", 0, similar_sound: ["ولاء"])
phrase.add_token_translation("كوخ", 0, "בקתה", 0, similar_sound: ["روح"])
phrase.add_token_translation("خيمة", 0, "אוהל", 0, similar_sound: ["قيمة"])
phrase.add_token_translation("أو", 0, "או", 1, similar_sound: ["هو"])
phrase.add_token_translation("زقزوق", 0, "צריף", 0, similar_sound: ["صندوق"])

phrase = phrases[30]
phrase.add_token_translation("مش", 0, "לא", 0, similar_sound: [])
phrase.add_token_translation("مهم", 0, "משנה", 0, similar_sound: [])
phrase.add_token_translation("مين", 0, "מי", 0, similar_sound: [])
phrase.add_token_translation("بيّك", 0, "אבא שלך", 0, similar_sound: [])

phrase = phrases[31]
phrase.add_token_translation("مواطن", 0, "אזרח", 0, similar_sound: [])
phrase.add_token_translation("ولا", 0, "או", 0, similar_sound: [])
phrase.add_token_translation("وزير", 0, "שר", 0, similar_sound: [])
phrase.add_token_translation("غني", 0, "עשיר", 0, similar_sound: [])
phrase.add_token_translation("أو", 0, "או", 1, similar_sound: [])
phrase.add_token_translation("فقير", 0, "עני", 0, similar_sound: [])

phrase = phrases[32]
phrase.add_token_translation("كل الناس", 0, "כל האנשים", 0, similar_sound: [])
phrase.add_token_translation("بتخلق", 0, "נולדים", 0, similar_sound: ["بتخنق"])
phrase.add_token_translation("قلبها", 0, "עם לב", 0, similar_sound: ["كلبها"])
phrase.add_token_translation("أبيض", 0, "לבן", 0, similar_sound: ["أخضر"])

phrase = phrases[33]
phrase.add_token_translation("ملاني", 0, "מלאה", 0, similar_sound: [])
phrase.add_token_translation("بطاقة", 0, "באנרגיה", 0, similar_sound: [])
phrase.add_token_translation("إيجابية", 0, "חיובית", 0, similar_sound: [])

phrase = phrases[34]
phrase.add_token_translation("لو", 0, "אם", 0, similar_sound: [])
phrase.add_token_translation("بس", 0, "רק", 0, similar_sound: [])
phrase.add_token_translation("بيعلموك", 0, "היו מלמדים אתכם", 0, similar_sound: [])
phrase.add_token_translation("بيفهموك", 0, "היו מבינים אתכם", 0, similar_sound: [])

phrase = phrases[35]
phrase.add_token_translation("الاختلاف", 0, "השוני", 0, similar_sound: [])
phrase.add_token_translation("بطريقة", 0, "בצורה", 0, similar_sound: ["بصديقة"])
phrase.add_token_translation("صحية", 0, "בריאה", 0, similar_sound: ["ضحية"])

phrase = phrases[36]
phrase.add_token_translation("ويكون", 0, "ויהיה", 0, similar_sound: [])
phrase.add_token_translation("في مساواة", 0, "שוויון", 0, similar_sound: [])

phrase = phrases[37]
phrase.add_token_translation("لكل", 0, "לכל", 0, similar_sound: [])
phrase.add_token_translation("حدا", 0, "אחד", 0, similar_sound: [])
phrase.add_token_translation("بالبيت", 0, "בבית", 0, similar_sound: [])
phrase.add_token_translation("معلمة", 0, "למורה", 0, similar_sound: [])
phrase.add_token_translation("تصير", 0, "שתהפוך", 0, similar_sound: [])
phrase.add_token_translation("حنية", 0, "החמלה", 0, similar_sound: [])

phrase = phrases[38]
phrase.add_token_translation("ونآمن", 0, "ונאמין", 0, similar_sound: ["ونأمن"])
phrase.add_token_translation("ببعض", 0, "אחד בשני", 0, similar_sound: ["ببعد"])
phrase.add_token_translation("نستعمل", 0, "נשתמש", 0, similar_sound: ["نستقبل"])
phrase.add_token_translation("الحب", 0, "באהבה", 0, similar_sound: ["الحرب"])

phrase = phrases[39]
phrase.add_token_translation("اللي هو", 0, "שהוא", 0, similar_sound: [])
phrase.add_token_translation("الخلطة", 0, "תערובת", 0, similar_sound: ["الخطة"])
phrase.add_token_translation("السحرية", 0, "הקסם", 0, similar_sound: ["السرية"])

phrase = phrases[40]
phrase.add_token_translation("وكل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "ומבורכים", 0, similar_sound: [])

phrase = phrases[41]
phrase.add_token_translation("كل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "מבורכים", 0, similar_sound: [])

phrase = phrases[42]
phrase.add_token_translation("كل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "מבורכים", 0, similar_sound: [])

phrase = phrases[43]
phrase.add_token_translation("كل", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("الناس", 0, "האנשים", 0, similar_sound: [])
phrase.add_token_translation("خير", 0, "טובים", 0, similar_sound: [])
phrase.add_token_translation("وبركة", 0, "מבורכים", 0, similar_sound: [])

l = Lesson.create!(medium: medium, slug: 'kl-el-nas0', course: c, order: 0, name: 'Intro & Chorus')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(0, 1, 2, 3)

      a.token_translations = [phrases[0].find_token_translation("كل"),
phrases[0].find_token_translation("بركة"),
phrases[1].find_token_translation("كل"),
phrases[1].find_token_translation("بركة"),
phrases[2].find_token_translation("كل"),
phrases[2].find_token_translation("بركة")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(0, 1, 2, 3)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(0, 1, 2, 3)

      a.token_translations = []
      

l = Lesson.create!(medium: medium, slug: 'kl-el-nas1', course: c, order: 1, name: 'Verse 1: What Doesn\'t Matter')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(4, 5, 6, 7, 8, 9, 10, 11)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(6, 7, 8, 9)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(6, 7, 8, 9)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(6, 7, 8, 9)

      a.token_translations = [phrases[4].find_token_translation("مش مهم"),
phrases[4].find_token_translation("شو"),
phrases[4].find_token_translation("دينك"),
phrases[5].find_token_translation("مسلم"),
phrases[5].find_token_translation("ولا"),
phrases[5].find_token_translation("بوذي"),
phrases[5].find_token_translation("مسيحي"),
phrases[5].find_token_translation("يهودي"),
phrases[6].find_token_translation("مش"),
phrases[6].find_token_translation("مهم"),
phrases[6].find_token_translation("شو"),
phrases[6].find_token_translation("لونك"),
phrases[7].find_token_translation("أبيض"),
phrases[7].find_token_translation("ولا"),
phrases[7].find_token_translation("أسود"),
phrases[7].find_token_translation("أصفر"),
phrases[7].find_token_translation("أسمر"),
phrases[8].find_token_translation("مش"),
phrases[8].find_token_translation("مهم"),
phrases[8].find_token_translation("شو"),
phrases[8].find_token_translation("لغتك"),
phrases[9].find_token_translation("عربي"),
phrases[9].find_token_translation("ألماني"),
phrases[9].find_token_translation("إسباني"),
phrases[9].find_token_translation("أو"),
phrases[10].find_token_translation("مش"),
phrases[10].find_token_translation("مهم"),
phrases[10].find_token_translation("شو"),
phrases[10].find_token_translation("جنسك"),
phrases[11].find_token_translation("صبي"),
phrases[11].find_token_translation("ولا"),
phrases[11].find_token_translation("بنت"),
phrases[11].find_token_translation("هومو"),
phrases[11].find_token_translation("ليزبيان")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(6, 7, 8, 9)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(4, 5, 6, 7, 8, 9, 10, 11)

      a.token_translations = [phrases[6].find_token_translation("مش"),
phrases[6].find_token_translation("مهم"),
phrases[6].find_token_translation("شو"),
phrases[6].find_token_translation("لونك"),
phrases[7].find_token_translation("أبيض"),
phrases[7].find_token_translation("ولا"),
phrases[7].find_token_translation("أسود"),
phrases[7].find_token_translation("أصفر"),
phrases[7].find_token_translation("أسمر"),
phrases[9].find_token_translation("عربي"),
phrases[9].find_token_translation("ألماني"),
phrases[9].find_token_translation("إسباني"),
phrases[9].find_token_translation("أو")]
      

l = Lesson.create!(medium: medium, slug: 'kl-el-nas2', course: c, order: 2, name: 'Bridge: The Positive Message')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(12, 13, 14, 15, 16, 17, 18, 19)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(12, 13, 14, 15)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(12, 13, 14, 15)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(12, 13, 14, 15)

      a.token_translations = [phrases[12].find_token_translation("كل الناس"),
phrases[12].find_token_translation("بتخلق"),
phrases[12].find_token_translation("قلبها"),
phrases[12].find_token_translation("أبيض"),
phrases[13].find_token_translation("ملاني"),
phrases[13].find_token_translation("بطاقة"),
phrases[13].find_token_translation("إيجابية"),
phrases[14].find_token_translation("لو"),
phrases[14].find_token_translation("بس"),
phrases[14].find_token_translation("بيعلموك"),
phrases[14].find_token_translation("بيفهموك"),
phrases[15].find_token_translation("الاختلاف"),
phrases[15].find_token_translation("بطريقة"),
phrases[15].find_token_translation("صحية"),
phrases[16].find_token_translation("ويكون في"),
phrases[16].find_token_translation("مساواة"),
phrases[17].find_token_translation("لكل"),
phrases[17].find_token_translation("حدا"),
phrases[17].find_token_translation("بالبيت"),
phrases[17].find_token_translation("معلمة"),
phrases[18].find_token_translation("ونآمن"),
phrases[18].find_token_translation("ببعض"),
phrases[18].find_token_translation("نستعمل"),
phrases[18].find_token_translation("الحب"),
phrases[19].find_token_translation("اللي هو"),
phrases[19].find_token_translation("الخلطة"),
phrases[19].find_token_translation("السحرية")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(16, 17, 18, 19)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(12, 13, 14, 15, 16, 17, 18, 19)

      a.token_translations = [phrases[12].find_token_translation("بتخلق"),
phrases[12].find_token_translation("قلبها"),
phrases[12].find_token_translation("أبيض"),
phrases[15].find_token_translation("بطريقة"),
phrases[15].find_token_translation("صحية"),
phrases[16].find_token_translation("ويكون في"),
phrases[16].find_token_translation("مساواة"),
phrases[19].find_token_translation("الخلطة"),
phrases[19].find_token_translation("السحرية")]
      

l = Lesson.create!(medium: medium, slug: 'kl-el-nas3', course: c, order: 3, name: 'Verse 2: More Things That Don\'t Matter')

a = Activities::WatchVideoActivity.create!(lesson: l, order: 0)
a.phrases = phrases.values_at(24, 25, 26, 27, 28, 29, 30, 31)



a = Activities::MatchPhrasesActivity.create!(lesson: l, order: 1)
a.phrases = phrases.values_at(28, 29, 30, 31)



a = Activities::SortPhrasesActivity.create!(lesson: l, order: 2)
a.phrases = phrases.values_at(28, 29, 30, 31)



a = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 3)
a.phrases = phrases.values_at(28, 29, 30, 31)

      a.token_translations = [phrases[24].find_token_translation("مش"),
phrases[24].find_token_translation("شو"),
phrases[24].find_token_translation("شغلك"),
phrases[25].find_token_translation("محامي"),
phrases[25].find_token_translation("فلاح"),
phrases[25].find_token_translation("تبرجي"),
phrases[25].find_token_translation("أستاذ"),
phrases[26].find_token_translation("مش"),
phrases[26].find_token_translation("شو"),
phrases[26].find_token_translation("لابس"),
phrases[27].find_token_translation("جديد"),
phrases[27].find_token_translation("قديم"),
phrases[27].find_token_translation("عالموضة"),
phrases[28].find_token_translation("مش"),
phrases[28].find_token_translation("وين"),
phrases[28].find_token_translation("ساكن"),
phrases[29].find_token_translation("قصر"),
phrases[29].find_token_translation("كوخ"),
phrases[29].find_token_translation("خيمة"),
phrases[29].find_token_translation("زقزوق"),
phrases[30].find_token_translation("مش"),
phrases[30].find_token_translation("مين"),
phrases[30].find_token_translation("بيّك"),
phrases[31].find_token_translation("مواطن"),
phrases[31].find_token_translation("وزير"),
phrases[31].find_token_translation("غني"),
phrases[31].find_token_translation("فقير")].filter {|t| t.l2_start_index.present? }
      


a = Activities::SpeakActivity.create!(lesson: l, order: 4)
a.phrases = phrases.values_at(28, 29, 30, 31)



a = Activities::ListenActivity.create!(lesson: l, order: 5)
a.phrases = phrases.values_at(24, 25, 26, 27, 28, 29, 30, 31)

      a.token_translations = [phrases[29].find_token_translation("قصر"),
phrases[29].find_token_translation("زقزوق")]
      
