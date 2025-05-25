import { anthropic } from 'npm:@ai-sdk/anthropic';
import { google } from 'npm:@ai-sdk/google';
import { deepseek } from 'npm:@ai-sdk/deepseek';
import { generateText, generateObject } from "npm:ai"
import { xai } from "npm:@ai-sdk/xai"
import { openai } from "npm:@ai-sdk/openai"
import { z } from 'npm:zod';
import fs from 'node:fs';

const youtubeVideoId = Deno.args[0];
const phrasesFileName = Deno.args[1];
const courseName = Deno.args[2];
const slug = Deno.args[3];
const songName = Deno.args[4];

const phrases = JSON.parse(fs.readFileSync(phrasesFileName, 'utf8'));
const out = `${youtubeVideoId}.rb`;
const systemPrompt = fs.readFileSync('flow.md', 'utf8');
const model = {
  ds: deepseek('deepseek-chat'),
  grok: xai("grok-3-mini"),
  lessons: anthropic('claude-sonnet-4-0'),
  tokenTranslations: google('gemini-2.5-flash-preview-05-20'),
}
 //const model = google('gemini-2.5-flash-preview-05-20');
 //const modelLessons = anthropic('claude-sonnet-4-0');
 //const model = google('gemini-2.5-pro-preview-05-06');
//const modelTokenTransl = google('gemini-2.0-flash');
//const model = openai('o4-mini');

if (fs.existsSync(out)) {
  throw new Error(`Script exists. Can't continue.`);
}

async function getTokenTranslationsForActivity(lesson: any, activity: any) {
  console.log(activity.activityType);
  if (activity.activityType === 'ListenActivity') {
    console.log(`listen activity`);
    const relevantPhrases = new Set(activity.phrases);
    const phrases = lesson.phrases.filter(p =>  relevantPhrases.has(p.id));

    const selectedTokensResponse = await generateObject({
      model: model.tokenTranslations,
      maxRetries: 5,
      output: 'array',
      schema: z.number().describe('tokenId of the selected tokens'),
      system: systemPrompt,
      prompt: `
      Select the token translations for a ListenActivity from the following list of phrases:
          ${JSON.stringify(phrases)}

      We need about 1 token per 1-2 phrases.
        `
    });
    const selectedTokens = new Set(selectedTokensResponse.object);
    console.log(Array.from(selectedTokens));
    console.log(JSON.stringify(lesson, null, 2));
    const result = [];
    for (let i=0; i < lesson.phrases.length; i++) {
      for (let j=0; j < lesson.phrases[i].tokens.length; j++) {
        if (selectedTokens.has(lesson.phrases[i].tokens[j].tokenId)) {
          const token = lesson.phrases[i].tokens[j].similar_sound;
          if (token.similar_sound && Array.isArray(token.similar_sound) && token.similar_sound.length > 0) {
            result.push({phraseIndex: i, word: token.originalTextInSpanish})
          }
        }
      }
    }
    console.log(result);
    return result;
  } else if (activity.activityType === 'LanguageAlignmentActivity') {
    console.log(`language alignment activity`);
    const relevantPhrases = new Set(activity.phrases);
    const phrases = lesson.phrases.filter(p =>  relevantPhrases.has(p.id));

    const selectedTokensResponse = await generateObject({
      model: model.tokenTranslations,
      maxRetries: 5,
      output: 'array',
      schema: z.number().describe('tokenId of the selected tokens'),
      system: systemPrompt,
      prompt: `
      Select the token translations for a LanguageAlignment from the following list of phrases:
          ${JSON.stringify(phrases)}

      We need about 1-2 tokens per phrase.
        `
    });
    const selectedTokens = new Set(selectedTokensResponse.object);
    console.log(Array.from(selectedTokens ));
    console.log(JSON.stringify(lesson, null, 2));
    const result = [];
    for (let i=0; i < lesson.phrases.length; i++) {
      for (let j=0; j < lesson.phrases[i].tokens.length; j++) {
        if (selectedTokens.has(lesson.phrases[i].tokens[j].tokenId)) {
          result.push({phraseIndex: i, word: lesson.phrases[i].tokens[j].originalTextInSpanish})
        }
      }
    }
    console.log(result);
    return result;
  } else {
    return [];
  }
}

fs.appendFileSync(out, `
en = Language.find_by(iso_name: 'en')
es = Language.find_by(iso_name: 'es')
medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=${youtubeVideoId}')
phrases_data = ${JSON.stringify(phrases)};

c = Course.find_or_create_by!(slug: '${slug}') do
  name = '${courseName}'
  main_media_url = 'https://www.youtube.com/watch?v=${youtubeVideoId}'
end
c.lessons.destroy_all

Lesson.where("slug like '${slug}%'").destroy_all
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
`, 'utf8');

const fullOriginalLyrics = phrases.map(p => p[0]).join('\n');

const lessonsResult = await generateObject({
  model: model.lessons,
  maxRetries: 5,
  output: 'array',
  schema: z.object({
    name: z.string(),
    phrases: z.array(z.number()).describe("The indexes of the phrases for this lesson"),
  }),
  system: systemPrompt,
  prompt: `
  You are a Spanish teacher teaching English speaking students, and you're given access to a new course creation platform. Your task is to use the platform and create a language lesson on the song ${songName}.
  Start by outlining the lessons for the song, so each lesson corresponds to a subsequent part of the song (for example "intro", "verse 1", "chorus", "outro").
  Each lesson should include roughly between 4 and 8 phrases, in a division that makes sense educationally and semantically.
  
  Also as the lessons are part of a language course, if the same part of the song repeats itself for example if the chorus is sang twice you need to create just one lesson for it.

  Return a list of lesson names

  Below are the song lyrics arranged in phrases:
  ${JSON.stringify(phrases)}
  `
})
const lessons = lessonsResult.object;

const createdTokenTranslations = [];

for (let i=0; i < phrases.length; i++) {
  const phrase = phrases[i];
  try {
    const tokenTranslationsResponse = await generateObject({
      model: model.tokenTranslations,
      maxRetries: 5,
      output: 'array',
      schema: z.object({
        originalTextInSpanish: z.string().describe('A word or expression from the original Spanish text'),
        originalTextOccurence: z.number().describe('If the word appears multiple times in the original text, specify which occurence we are referring to. Default is 0 (for disambiguity)'),
        translationTextInEnglish: z.string().describe('The translation word or expression.'),
        translationTextOccurence: z.number().describe('If the word translation appears multiple times in the English text (l2) specify which occurence we are referring to (for disambiguity). Default is 0'),
        similar_sound: z.array(z.string()).describe(`Word or phrase in Spanish that sounds similar but has different meaning. Difference must be in actual letters and not in accent marks. If unsure specify empty array here. Some good examples for similar sounds are:
        un rato -> un gato
        llevo -> llaves
        quiero -> pero
        azul -> arroz
        hombre -> hombro
        cabe -> sabe
        mitad -> mirada

        Bad examples that shouldn't be used include:
        que -> qué  # Do not use, as this is the same spelling except for an accent mark
        sé  -> se   # Do not use, as this is the same spelling except for an accent mark
          `)
      }),
      system: systemPrompt,
      prompt: `
      Create the list of token translations for the phrase:
          ${phrase[0]}

        For context the full lyrics of the song are:
          ${fullOriginalLyrics}
        `
    });

    const tokenTranslations = tokenTranslationsResponse.object;
    createdTokenTranslations.push(tokenTranslations);

    fs.appendFileSync(out, `
phrase = phrases[${i}]
${tokenTranslations.map(t => `phrase.add_token_translation("${t.originalTextInSpanish}", ${t.originalTextOccurence}, "${t.translationTextInEnglish}", ${t.translationTextOccurence}, similar_sound: ${JSON.stringify(t.similar_sound)})`).join('\n')}
`, 'utf8')
  } catch (err) {
    console.error(err);
    console.error(`Failed to create token translations for phrase: ${i} - ${phrase}`);
  }
}

const lessonsWithTokenTranslations = lessons.map(l => ({
  name: l.name,
  phrases: l.phrases.map(phraseIndex => ({
    id: phraseIndex,
    text_l1: phrases[phraseIndex][0],
    text_l2: phrases[phraseIndex][1],
    tokens: createdTokenTranslations[phraseIndex].map((t, i) => ({
      ...t,
      tokenId: i,
    }))
  }))
}));


for (let i=0; i < lessonsWithTokenTranslations.length; i++) {
  const lesson = lessonsWithTokenTranslations[i];
  try {
    const lessonActivitiesResponse = await generateObject({
      model: model.tokenTranslations,
      maxRetries: 5,
      output: 'array',
      schema: z.object({
        activityType: z.enum(['WatchVideoActivity', 'MatchPhrasesActivity', 'SortPhrasesActivity', 'LanguageAlignmentActivity', 'SpeakActivity', 'ListenActivity']),
        phrases: z.array(z.number()).describe('ids of the phrases for this activity'),
      }),
      system: systemPrompt,
      prompt: `
      Create a lesson activity template from the lesson data. The order of the output array is the order of activities. Use the default template:
          ${JSON.stringify(lesson)}

        For context the full lyrics of the song are:
          ${fullOriginalLyrics}
        `
    });
    const lessonActivities = lessonActivitiesResponse.object;

    fs.appendFileSync(out, `
l = Lesson.create!(medium: medium, slug: '${slug}${i}', course: c, order: ${i}, name: '${lesson.name}')
${(await Promise.all(lessonActivities.map(async (a, ai) => `
a = Activities::${a.activityType}.create!(lesson: l, order: ${ai})
a.phrases = phrases.values_at(${a.phrases.join(', ')})
a.token_translations = [${(await getTokenTranslationsForActivity(lesson, a)).map(t => `phrases[${t.phraseIndex}].find_token_translation("${t.word}")`).join(',\n')}]
`))).join('\n')}`, 'utf8')
  } catch (err) {
    console.error(err);
    console.error(`Failed to create token translations for phrase: ${i} - ${lesson}`);
  }

}

