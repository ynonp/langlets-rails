interface LessonExample {
  input: string;
  lessons: Array<{ title: string; lines: string[] }>;
}

export function addLessonsPrompt(clipLanguage: string, translationLanguage: string): string {
  const example = exampleFor(clipLanguage);
  return `## Context
You are a ${clipLanguage} language teacher creating lessons for ${translationLanguage} speaking students.
You will be given the complete transcript of a video or song as continuous text.

## Goal
Reformat the transcript so it is easy for a language student to study. Divide the continuous text into short, easy-to-translate lines, and group those lines into logical, bite-sized lessons.


## Rules

### 1. Text Integrity
- Keep every word exactly as written, exactly once, in strict chronological order.
- You may only insert lesson titles and line breaks. Never repeat, omit, correct, or rewrite transcript text.

### 2. Line Splitting
- A line must be a complete comprehension and translation unit. 
- Speech Pauses vs. Semantic Units: The punctuation in the transcript marks audio breaths and pauses, not grammatical sentences. A single translation unit might span across a period. Base your line breaks purely on grammar and vocabulary. Ignore punctuation when deciding where a complete thought begins and ends.
- NEVER split an article from its noun, a preposition from its object, an auxiliary from its verb, or a fixed expression.
- Aim for roughly 3–12 words. Concise lines are preferred, but semantic completeness is more important than length.

### 3. Lesson Grouping
- Aim for 4–8 lines per lesson. Group lines by topic, scene, or lyrical idea.
- Create a short, descriptive lesson title in ${clipLanguage} for each group.
- If a logical lesson or chorus is too long, split it and append "(Part 1)", "(Part 2)" to the titles.
- Treat stage banter, intros, or spoken outros as their own distinct lessons.

## Example Input
${example.input}

## Example Output
${JSON.stringify({ lessons: example.lessons }, null, 2)}

## Target Input`;
}

export function exampleFor(language: string): LessonExample {
  const key = language.toLowerCase().split(/[-_]/)[0];
  const iso = LANGUAGE_CODES[key] ?? key;
  return EXAMPLES[iso] ?? EXAMPLES.en;
}

const LANGUAGE_CODES: Record<string, string> = {
  english: "en",
  french: "fr",
  german: "de",
  hebrew: "he",
  russian: "ru",
  spanish: "es",
  arabic: "ar",
};

function lessonExample(
  input: string,
  firstTitle: string,
  firstLines: string[],
  secondTitle: string,
  secondLines: string[],
): LessonExample {
  return {
    input,
    lessons: [
      { title: firstTitle, lines: firstLines },
      { title: secondTitle, lines: secondLines },
    ],
  };
}

const EXAMPLES: Record<string, LessonExample> = {
  en: lessonExample(
    "We were good, we were gold. Kind of dream that can't be sold. We were right until we weren't. Built a home and watched it burn. I didn't want to leave you. I didn't want to lie. Started to cry in the kitchen. Then I remembered who I was. I can buy myself flowers. I can love me better than you can.",
    "The Golden Dream",
    [
      "We were good, we were gold.",
      "Kind of dream that can't be sold.",
      "We were right until we weren't.",
      "Built a home and watched it burn.",
    ],
    "Finding My Strength",
    [
      "I didn't want to leave you.",
      "I didn't want to lie.",
      "Started to cry in the kitchen.",
      "Then I remembered who I was.",
      "I can buy myself flowers.",
      "I can love me better than you can.",
    ],
  ),
  es: lessonExample(
    "Soy vulnerable a tu lado más amable. Soy carcelero de tu lado más grosero. Soy el soldado de tu lado más malvado. Soy propietario de tu lado más caliente. A tu lado estoy, mi vida. Mañana será un nuevo punto de partida. Busco un lugar donde descansar. Alguien me espera cerca del río. Quiero volver a mi casa. Allí comienza una nueva historia.",
    "Los diferentes lados",
    [
      "Soy vulnerable a tu lado más amable.",
      "Soy carcelero de tu lado más grosero.",
      "Soy el soldado de tu lado más malvado.",
      "Soy propietario de tu lado más caliente.",
    ],
    "Un nuevo camino",
    [
      "A tu lado estoy, mi vida.",
      "Mañana será un nuevo punto de partida.",
      "Busco un lugar donde descansar.",
      "Alguien me espera cerca del río.",
      "Quiero volver a mi casa.",
      "Allí comienza una nueva historia.",
    ],
  ),
  fr: lessonExample(
    "Salut, tu vas bien ? Ça va, mais je suis fatigué. Pourquoi, tu as fait quoi hier ? J'ai commencé à raconter ma soirée. J'ai regardé une nouvelle série. Je voulais voir un seul épisode. Finalement, j'ai regardé toute la saison. Mon ami m'a regardé en silence. Le bus est arrivé devant nous. Nous sommes montés pour rentrer chez nous.",
    "Une longue soirée",
    [
      "Salut, tu vas bien ?",
      "Ça va, mais je suis fatigué.",
      "Pourquoi, tu as fait quoi hier ?",
      "J'ai commencé à raconter ma soirée.",
    ],
    "La série et le retour",
    [
      "J'ai regardé une nouvelle série.",
      "Je voulais voir un seul épisode.",
      "Finalement, j'ai regardé toute la saison.",
      "Mon ami m'a regardé en silence.",
      "Le bus est arrivé devant nous.",
      "Nous sommes montés pour rentrer chez nous.",
    ],
  ),
  de: lessonExample(
    "Heute Morgen war der Himmel ganz klar. Ich öffnete das Fenster und hörte die Vögel. Auf der Straße wartete schon mein Nachbar. Wir gingen gemeinsam zum kleinen Bahnhof. Der Zug kam wenige Minuten später. Im Abteil fanden wir zwei freie Plätze. Eine Frau las leise ihre Zeitung. Draußen zogen grüne Felder vorbei. Bald erreichten wir die große Stadt. Dort begann unser gemeinsamer Arbeitstag.",
    "Der Weg zum Bahnhof",
    [
      "Heute Morgen war der Himmel ganz klar.",
      "Ich öffnete das Fenster und hörte die Vögel.",
      "Auf der Straße wartete schon mein Nachbar.",
      "Wir gingen gemeinsam zum kleinen Bahnhof.",
    ],
    "Die Fahrt in die Stadt",
    [
      "Der Zug kam wenige Minuten später.",
      "Im Abteil fanden wir zwei freie Plätze.",
      "Eine Frau las leise ihre Zeitung.",
      "Draußen zogen grüne Felder vorbei.",
      "Bald erreichten wir die große Stadt.",
      "Dort begann unser gemeinsamer Arbeitstag.",
    ],
  ),
  he: lessonExample(
    "הבוקר השמש זרחה מעל העיר. פתחתי את החלון ושמעתי ציפורים. ברחוב חיכה לי חבר ותיק. הלכנו יחד אל התחנה הקרובה. האוטובוס הגיע בדיוק בזמן. מצאנו שני מקומות ליד החלון. בדרך סיפרתי לו על העבודה החדשה. הוא הקשיב ושאל הרבה שאלות. ירדנו ליד השוק הגדול. משם המשכנו ברגל אל המשרד.",
    "בוקר בעיר",
    [
      "הבוקר השמש זרחה מעל העיר.",
      "פתחתי את החלון ושמעתי ציפורים.",
      "ברחוב חיכה לי חבר ותיק.",
      "הלכנו יחד אל התחנה הקרובה.",
    ],
    "הדרך לעבודה",
    [
      "האוטובוס הגיע בדיוק בזמן.",
      "מצאנו שני מקומות ליד החלון.",
      "בדרך סיפרתי לו על העבודה החדשה.",
      "הוא הקשיב ושאל הרבה שאלות.",
      "ירדנו ליד השוק הגדול.",
      "משם המשכנו ברגל אל המשרד.",
    ],
  ),
  ru: lessonExample(
    "Сегодня утром город был очень тихим. Я открыл окно и почувствовал свежий воздух. Во дворе меня ждал старый друг. Мы вместе пошли к ближайшей остановке. Автобус приехал точно по расписанию. Мы нашли два места у окна. По дороге я рассказал о новой работе. Друг внимательно слушал и задавал вопросы. Мы вышли рядом с большим рынком. Оттуда мы пешком дошли до офиса.",
    "Тихое утро",
    [
      "Сегодня утром город был очень тихим.",
      "Я открыл окно и почувствовал свежий воздух.",
      "Во дворе меня ждал старый друг.",
      "Мы вместе пошли к ближайшей остановке.",
    ],
    "Дорога на работу",
    [
      "Автобус приехал точно по расписанию.",
      "Мы нашли два места у окна.",
      "По дороге я рассказал о новой работе.",
      "Друг внимательно слушал и задавал вопросы.",
      "Мы вышли рядом с большим рынком.",
      "Оттуда мы пешком дошли до офиса.",
    ],
  ),
  ar: lessonExample(
    "أشرقت الشمس فوق المدينة هذا الصباح. فتحت النافذة وسمعت أصوات الطيور. كان صديقي القديم ينتظر في الشارع. مشينا معًا نحو المحطة القريبة. وصلت الحافلة في موعدها تمامًا. وجدنا مقعدين بجانب النافذة. حدثته في الطريق عن عملي الجديد. استمع إلي وطرح أسئلة كثيرة. نزلنا بالقرب من السوق الكبير. ومن هناك مشينا حتى وصلنا إلى المكتب.",
    "صباح في المدينة",
    [
      "أشرقت الشمس فوق المدينة هذا الصباح.",
      "فتحت النافذة وسمعت أصوات الطيور.",
      "كان صديقي القديم ينتظر في الشارع.",
      "مشينا معًا نحو المحطة القريبة.",
    ],
    "الطريق إلى العمل",
    [
      "وصلت الحافلة في موعدها تمامًا.",
      "وجدنا مقعدين بجانب النافذة.",
      "حدثته في الطريق عن عملي الجديد.",
      "استمع إلي وطرح أسئلة كثيرة.",
      "نزلنا بالقرب من السوق الكبير.",
      "ومن هناك مشينا حتى وصلنا إلى المكتب.",
    ],
  ),
};
