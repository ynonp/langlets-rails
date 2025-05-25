import { anthropic } from 'npm:@ai-sdk/anthropic';
import { google } from 'npm:@ai-sdk/google';
import { deepseek } from 'npm:@ai-sdk/deepseek';
import { generateText, generateObject } from "npm:ai"
import { xai } from "npm:@ai-sdk/xai"
import { openai } from "npm:@ai-sdk/openai"
import { z } from 'npm:zod';
import fs from 'node:fs';

// ============================================================================
// INTERFACES AND TYPES
// ============================================================================

export interface PhraseData {
  0: string; // Spanish text
  1: string; // English text
  2: number; // timestamp
}

export interface TokenTranslation {
  originalTextInSpanish: string;
  originalTextOccurence: number;
  translationTextInEnglish: string;
  translationTextOccurence: number;
  similar_sound: string[];
  tokenId?: number;
}

interface LessonPhrase {
  id: number;
  text_l1: string;
  text_l2: string;
  tokens: TokenTranslation[];
}

interface Lesson {
  name: string;
  phrases: number[];
}

interface LessonWithTokens extends Omit<Lesson, 'phrases'> {
  phrases: LessonPhrase[];
}

interface Activity {
  activityType: 'WatchVideoActivity' | 'MatchPhrasesActivity' | 'SortPhrasesActivity' | 
                'LanguageAlignmentActivity' | 'SpeakActivity' | 'ListenActivity';
  phrases: number[];
}

interface TokenTranslationForActivity {
  phraseIndex: number;
  word: string;
}

interface ModelConfiguration {
  ds: any;
  grok: any;
  lessons: any;
  tokenTranslations: any;
}

interface ScriptConfig {
  youtubeVideoId: string;
  phrasesFileName: string;
  courseName: string;
  slug: string;
  songName: string;
  outputFile: string;
  systemPrompt: string;
  model: ModelConfiguration;
}

// ============================================================================
// CONFIGURATION AND SETUP
// ============================================================================

export function parseCommandLineArgs(): Omit<ScriptConfig, 'outputFile' | 'systemPrompt' | 'model'> {
  const [youtubeVideoId, phrasesFileName, courseName, slug, songName] = Deno.args;
  
  if (!youtubeVideoId || !phrasesFileName || !courseName || !slug || !songName) {
    throw new Error('Missing required arguments: youtubeVideoId, phrasesFileName, courseName, slug, songName');
  }

  return {
    youtubeVideoId,
    phrasesFileName,
    courseName,
    slug,
    songName
  };
}

export function initializeConfiguration(): ScriptConfig {
  const args = parseCommandLineArgs();
  const outputFile = `${args.youtubeVideoId}.rb`;
  const systemPrompt = fs.readFileSync('flow.md', 'utf8');
  
  if (fs.existsSync(outputFile)) {
    throw new Error(`Script exists. Can't continue.`);
  }

  const model: ModelConfiguration = {
    ds: deepseek('deepseek-chat'),
    grok: xai("grok-3-mini"),
    lessons: anthropic('claude-sonnet-4-0'),
    tokenTranslations: google('gemini-2.5-flash-preview-05-20'),
  };

  return {
    ...args,
    outputFile,
    systemPrompt,
    model
  };
}

export function loadPhrasesData(fileName: string): PhraseData[] {
  return JSON.parse(fs.readFileSync(fileName, 'utf8'));
}

// ============================================================================
// PROMPT GENERATION FUNCTIONS
// ============================================================================

function createLessonGenerationPrompt(songName: string, phrases: PhraseData[]): string {
  return `
  You are a Spanish teacher teaching English speaking students, and you're given access to a new course creation platform. Your task is to use the platform and create a language lesson on the song ${songName}.
  Start by outlining the lessons for the song, so each lesson corresponds to a subsequent part of the song (for example "intro", "verse 1", "chorus", "outro").
  Each lesson should include roughly between 4 and 8 phrases, in a division that makes sense educationally and semantically.
  
  Also as the lessons are part of a language course, if the same part of the song repeats itself for example if the chorus is sang twice you need to create just one lesson for it.

  Return a list of lesson names

  Below are the song lyrics arranged in phrases:
  ${JSON.stringify(phrases)}
  `;
}

function createTokenTranslationPrompt(phraseText: string, fullLyrics: string): string {
  return `
  Create the list of token translations for the phrase:
      ${phraseText}

    For context the full lyrics of the song are:
      ${fullLyrics}
    `;
}

function createLessonActivityPrompt(lesson: LessonWithTokens, fullLyrics: string): string {
  return `
  Create a lesson activity template from the lesson data. The order of the output array is the order of activities. Use the default template:
      ${JSON.stringify(lesson)}

    For context the full lyrics of the song are:
      ${fullLyrics}
    `;
}

function createListenActivityTokenSelectionPrompt(phrases: LessonPhrase[]): string {
  return `
  Select the token translations for a ListenActivity from the following list of phrases:
      ${JSON.stringify(phrases)}

  We need about 1 token per 1-2 phrases.
    `;
}

function createLanguageAlignmentTokenSelectionPrompt(phrases: LessonPhrase[]): string {
  return `
  Select the token translations for a LanguageAlignment from the following list of phrases:
      ${JSON.stringify(phrases)}

  We need about 1-2 tokens per phrase.
    `;
}

// ============================================================================
// RUBY CODE GENERATION
// ============================================================================

export function generateInitialRubyCode(config: ScriptConfig, phrases: PhraseData[]): void {
  const initialCode = `
en = Language.find_by(iso_name: 'en')
l1 = Language.find_by(iso_name: 'fr')

medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=${config.youtubeVideoId}')
phrases_data = ${JSON.stringify(phrases, null, 2)};

c = Course.find_or_create_by!(slug: '${config.slug}') do
  name = '${config.courseName}'
  main_media_url = 'https://www.youtube.com/watch?v=${config.youtubeVideoId}'
end
c.lessons.destroy_all

Lesson.where("slug like '${config.slug}%'").destroy_all
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
`;

  fs.appendFileSync(config.outputFile, initialCode, 'utf8');
}

export function generateTokenTranslationRubyCode(
  outputFile: string, 
  phraseIndex: number, 
  tokenTranslations: TokenTranslation[]
): void {
  const rubyCode = `
phrase = phrases[${phraseIndex}]
${tokenTranslations.map(t => 
  `phrase.add_token_translation("${t.originalTextInSpanish}", ${t.originalTextOccurence}, "${t.translationTextInEnglish}", ${t.translationTextOccurence}, similar_sound: ${JSON.stringify(t.similar_sound)})`
).join('\n')}
`;

  fs.appendFileSync(outputFile, rubyCode, 'utf8');
}

async function generateLessonActivityRubyCode(
  config: ScriptConfig,
  lesson: LessonWithTokens,
  lessonIndex: number,
  activities: Activity[]
): Promise<void> {
  const activityPromises = activities.map(async (activity, activityIndex) => {
    const tokenTranslations = await getTokenTranslationsForActivity(lesson, activity, config);
    let tokenTranslationsCode = '';
    if (activity.activityType === 'ListenActivity') {
      tokenTranslationsCode = `
      a.token_translations = [${tokenTranslations.map(t => 
        `phrases[${t.phraseIndex}].find_token_translation("${t.word}")`
      ).join(',\n')}]
      `;
    } else if (activity.activityType === 'LanguageAlignmentActivity') {
      tokenTranslationsCode = `
      a.token_translations = [${tokenTranslations.map(t => 
        `phrases[${t.phraseIndex}].find_token_translation("${t.word}")`
      ).join(',\n')}].filter {|t| t.l2_start_index.present? }
      `;
    }

    return `
a = Activities::${activity.activityType}.create!(lesson: l, order: ${activityIndex})
a.phrases = phrases.values_at(${activity.phrases.join(', ')})
${tokenTranslationsCode}
`;
  });

  const activityCode = await Promise.all(activityPromises);
  
  const lessonCode = `
l = Lesson.create!(medium: medium, slug: '${config.slug}${lessonIndex}', course: c, order: ${lessonIndex}, name: '${lesson.name}')
${activityCode.join('\n')}`;

  fs.appendFileSync(config.outputFile, lessonCode, 'utf8');
}

// ============================================================================
// AI-POWERED CONTENT GENERATION
// ============================================================================

async function generateLessons(
  config: ScriptConfig, 
  phrases: PhraseData[]
): Promise<Lesson[]> {
  const lessonsResult = await generateObject({
    model: config.model.lessons,
    maxRetries: 5,
    output: 'array',
    schema: z.object({
      name: z.string(),
      phrases: z.array(z.number()).describe("The indexes of the phrases for this lesson"),
    }),
    system: config.systemPrompt,
    prompt: createLessonGenerationPrompt(config.songName, phrases)
  });

  return lessonsResult.object;
}

async function generateTokenTranslationsForPhrase(
  config: ScriptConfig,
  phrase: PhraseData,
  phraseIndex: number,
  fullLyrics: string
): Promise<TokenTranslation[]> {
  const tokenTranslationsResponse = await generateObject({
    model: config.model.tokenTranslations,
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
    system: config.systemPrompt,
    prompt: createTokenTranslationPrompt(phrase[0], fullLyrics)
  });

  return tokenTranslationsResponse.object;
}

async function generateLessonActivities(
  config: ScriptConfig,
  lesson: LessonWithTokens,
  fullLyrics: string
): Promise<Activity[]> {
  const lessonActivitiesResponse = await generateObject({
    model: config.model.tokenTranslations,
    maxRetries: 5,
    output: 'array',
    schema: z.object({
      activityType: z.enum(['WatchVideoActivity', 'MatchPhrasesActivity', 'SortPhrasesActivity', 'LanguageAlignmentActivity', 'SpeakActivity', 'ListenActivity']),
      phrases: z.array(z.number()).describe('ids of the phrases for this activity'),
    }),
    system: config.systemPrompt,
    prompt: createLessonActivityPrompt(lesson, fullLyrics)
  });

  return lessonActivitiesResponse.object;
}

async function getTokenTranslationsForActivity(
  lesson: LessonWithTokens, 
  activity: Activity, 
  config: ScriptConfig
): Promise<TokenTranslationForActivity[]> {
  console.log(activity.activityType);
  
  if (activity.activityType === 'ListenActivity') {
    return await processListenActivity(lesson, activity, config);
  } else if (activity.activityType === 'LanguageAlignmentActivity') {
    return await processLanguageAlignmentActivity(lesson, activity, config);
  } else {
    return [];
  }
}

async function processListenActivity(
  lesson: LessonWithTokens,
  activity: Activity,
  config: ScriptConfig
): Promise<TokenTranslationForActivity[]> {
  const relevantPhrases = new Set(activity.phrases);
  const phrases = lesson.phrases.filter(p => relevantPhrases.has(p.id));

  // Filter phrases to only include tokens with non-empty similar_sound arrays
  const phrasesWithValidTokens = phrases.map(phrase => ({
    ...phrase,
    tokens: phrase.tokens.filter(token => 
      token.similar_sound && 
      Array.isArray(token.similar_sound) && 
      token.similar_sound.length > 0
    )
  })).filter(phrase => phrase.tokens.length > 0); // Only include phrases that have at least one valid token

  const selectedTokensResponse = await generateObject({
    model: config.model.tokenTranslations,
    maxRetries: 5,
    output: 'array',
    schema: z.number().describe('tokenId of the selected tokens'),
    system: config.systemPrompt,
    prompt: createListenActivityTokenSelectionPrompt(phrasesWithValidTokens)
  });

  const selectedTokens = new Set(selectedTokensResponse.object);
  console.log(Array.from(selectedTokens));
  console.log(JSON.stringify(lesson, null, 2));

  const result: TokenTranslationForActivity[] = [];
  for (let i = 0; i < lesson.phrases.length; i++) {
    for (let j = 0; j < lesson.phrases[i].tokens.length; j++) {
      if (selectedTokens.has(lesson.phrases[i].tokens[j].tokenId!)) {
        const token = lesson.phrases[i].tokens[j];
        if (token.similar_sound && Array.isArray(token.similar_sound) && token.similar_sound.length > 0) {
          result.push({ phraseIndex: lesson.phrases[i].id, word: token.originalTextInSpanish });
        }
      }
    }
  }

  console.log(result);
  return result;
}

async function processLanguageAlignmentActivity(
  lesson: LessonWithTokens,
  activity: Activity,
  config: ScriptConfig
): Promise<TokenTranslationForActivity[]> {
  const relevantPhrases = new Set(activity.phrases);
  const phrases = lesson.phrases.filter(p => relevantPhrases.has(p.id));

  const selectedTokensResponse = await generateObject({
    model: config.model.tokenTranslations,
    maxRetries: 5,
    output: 'array',
    schema: z.number().describe('tokenId of the selected tokens'),
    system: config.systemPrompt,
    prompt: createLanguageAlignmentTokenSelectionPrompt(phrases)
  });

  const selectedTokens = new Set(selectedTokensResponse.object);

  const result: TokenTranslationForActivity[] = [];
  for (let i = 0; i < lesson.phrases.length; i++) {
    for (let j = 0; j < lesson.phrases[i].tokens.length; j++) {
      if (selectedTokens.has(lesson.phrases[i].tokens[j].tokenId!)) {
        result.push({ phraseIndex: lesson.phrases[i].id, word: lesson.phrases[i].tokens[j].originalTextInSpanish });
      }
    }
  }

  return result;
}

// ============================================================================
// PROCESSING FUNCTIONS
// ============================================================================

async function processTokenTranslations(
  config: ScriptConfig,
  phrases: PhraseData[]
): Promise<TokenTranslation[][]> {
  const fullOriginalLyrics = phrases.map(p => p[0]).join('\n');
  const createdTokenTranslations: TokenTranslation[][] = [];

  for (let i = 0; i < phrases.length; i++) {
    const phrase = phrases[i];
    try {
      console.log(`Generating token translations for phrase: ${i} - ${phrase}`);
      const tokenTranslations = await generateTokenTranslationsForPhrase(
        config, 
        phrase, 
        i, 
        fullOriginalLyrics
      );
      createdTokenTranslations.push(tokenTranslations);
      generateTokenTranslationRubyCode(config.outputFile, i, tokenTranslations);
      console.log(`done`);
    } catch (err) {
      console.error(err);
      console.error(`Failed to create token translations for phrase: ${i} - ${phrase}`);
      createdTokenTranslations.push([]);
    }
  }

  return createdTokenTranslations;
}

function createLessonsWithTokenTranslations(
  lessons: Lesson[],
  phrases: PhraseData[],
  createdTokenTranslations: TokenTranslation[][]
): LessonWithTokens[] {
  return lessons.map(lesson => ({
    name: lesson.name,
    phrases: lesson.phrases.map(phraseIndex => ({
      id: phraseIndex,
      text_l1: phrases[phraseIndex][0],
      text_l2: phrases[phraseIndex][1],
      tokens: createdTokenTranslations[phraseIndex].map((t, i) => ({
        ...t,
        tokenId: i,
      }))
    }))
  }));
}

async function processLessonsAndActivities(
  config: ScriptConfig,
  lessonsWithTokenTranslations: LessonWithTokens[],
  fullLyrics: string
): Promise<void> {
  for (let i = 0; i < lessonsWithTokenTranslations.length; i++) {
    const lesson = lessonsWithTokenTranslations[i];
    try {
      const lessonActivities = await generateLessonActivities(config, lesson, fullLyrics);
      await generateLessonActivityRubyCode(config, lesson, i, lessonActivities);
    } catch (err) {
      console.error(err);
      console.error(`Failed to create activities for lesson: ${i} - ${lesson.name}`);
    }
  }
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

async function main(): Promise<void> {
  try {
    // Initialize configuration
    const config = initializeConfiguration();
    console.log(`Generating script for: ${config.songName}`);

    // Load phrases data
    const phrases = loadPhrasesData(config.phrasesFileName);
    const fullOriginalLyrics = phrases.map(p => p[0]).join('\n');

    // Generate initial Ruby code
    generateInitialRubyCode(config, phrases);

    // Generate lessons structure
    console.log('Generating lessons...');
    const lessons = await generateLessons(config, phrases);

    // Generate token translations for all phrases
    console.log('Generating token translations...');
    const createdTokenTranslations = await processTokenTranslations(config, phrases);

    // Create lessons with token translations
    const lessonsWithTokenTranslations = createLessonsWithTokenTranslations(
      lessons, 
      phrases, 
      createdTokenTranslations
    );

    // Generate lesson activities and Ruby code
    console.log('Generating lesson activities...');
    await processLessonsAndActivities(config, lessonsWithTokenTranslations, fullOriginalLyrics);

    console.log(`Script generation completed: ${config.outputFile}`);
  } catch (error) {
    console.error('Error generating script:', error);
    throw error;
  }
}

// ============================================================================
// SCRIPT EXECUTION
// ============================================================================

if (import.meta.main) {
  await main();
}

