import { anthropic } from 'npm:@ai-sdk/anthropic';
import { google } from 'npm:@ai-sdk/google';
import { deepseek } from 'npm:@ai-sdk/deepseek';
import { generateText, generateObject } from "npm:ai"
import { xai } from "npm:@ai-sdk/xai"
import { openai } from "npm:@ai-sdk/openai"
import { z } from 'npm:zod';
import fs from 'node:fs';
import { parseArgs } from "jsr:@std/cli/parse-args";
import { getPromptsForLanguages } from './prompts/index.ts';

// ============================================================================
// LANGUAGE CONFIGURATION
// ============================================================================

/**
 * Language configuration for the course generation script.
 * This defines the source language (clip language) and target language (translation language)
 * for the language learning course being created.
 */
interface LanguageConfiguration {
  /** The language of the video/audio content (source language) */
  clipLanguage: {
    name: string;
    isoCode: string;
  };
  /** The language students speak (target language for translations) */
  translationLanguage: {
    name: string;
    isoCode: string;
  };
}

/**
 * Default language configuration - Spanish content for English speakers
 * This can be modified to support other language pairs
 */
const LanguageConfig: LanguageConfiguration = {
  clipLanguage: {
    name: 'English',
    isoCode: 'en'
  },
  translationLanguage: {
    name: 'Hebrew', 
    isoCode: 'he'
  }
};

// ============================================================================
// INTERFACES AND TYPES
// ============================================================================

export interface PhraseData {
  0: string; // Clip language text
  1: string; // Translation language text
  2: number; // timestamp
}

export interface TokenTranslation {
  l1_start_index: number;
  l1_end_index: number;
  translation: string;
  l2_start_index: number;
  l2_end_index: number;
  similar_sound: string[];
}

export interface LessonPhrase {
  id: number;
  text_clip_language: string;
  text_translation_language: string;
  tokens: TokenTranslation[];
}

interface Lesson {
  name: string;
  phrases: number[];
}

export interface LessonWithTokens extends Omit<Lesson, 'phrases'> {
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

export interface ScriptConfig {
  youtubeVideoId: string;
  phrasesFileName: string;
  courseName: string;
  slug: string;
  songName: string;
  outputFile: string;
  systemPrompt: string;
  model: ModelConfiguration;
  languageConfig: LanguageConfiguration;
}

// ============================================================================
// CONFIGURATION AND SETUP
// ============================================================================

/**
 * Parses command line arguments for the script
 * Expected arguments: --video-id, --phrases-file, --course-name, --slug, --song-name
 */
export function parseCommandLineArgs(): Omit<ScriptConfig, 'outputFile' | 'systemPrompt' | 'model' | 'languageConfig'> {
  const args = parseArgs(Deno.args, {
    string: ['video-id', 'phrases-file', 'course-name', 'slug', 'song-name'],
    alias: {
      v: 'video-id',
      p: 'phrases-file',
      c: 'course-name',
      s: 'slug',
      n: 'song-name'
    },
    stopEarly: false,
    collect: ['_']
  });
  
  const youtubeVideoId = args['video-id'];
  const phrasesFileName = args['phrases-file'];
  const courseName = args['course-name'];
  const slug = args['slug'];
  const songName = args['song-name'];
  
  if (!youtubeVideoId || !phrasesFileName || !courseName || !slug || !songName) {
    console.error('Usage: deno run create_song.ts --video-id <id> --phrases-file <file> --course-name <name> --slug <slug> --song-name <name>');
    console.error('Aliases: -v, -p, -c, -s, -n');
    throw new Error('Missing required arguments: video-id, phrases-file, course-name, slug, song-name');
  }

  return {
    youtubeVideoId,
    phrasesFileName,
    courseName,
    slug,
    songName
  };
}

/**
 * Initializes the complete script configuration including AI models and file paths
 */
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
    claude: anthropic('claude-sonnet-4-0'),
    lessons: google('gemini-2.5-flash-preview-05-20'),
    tokenTranslations: google('gemini-2.5-flash-preview-05-20'),
  };

  return {
    ...args,
    outputFile,
    systemPrompt,
    model,
    languageConfig: LanguageConfig
  };
}

/**
 * Loads phrase data from a JSON file
 * Each phrase contains: [clip_language_text, translation_language_text, timestamp]
 */
export function loadPhrasesData(fileName: string): PhraseData[] {
  return JSON.parse(fs.readFileSync(fileName, 'utf8'));
}

// ============================================================================
// RUBY CODE GENERATION
// ============================================================================

/**
 * Generates the initial Ruby code for setting up languages, medium, course, and phrases
 */
export function generateInitialRubyCode(config: ScriptConfig, phrases: PhraseData[]): void {
  const initialCode = `
# Language Configuration
# Clip Language: ${config.languageConfig.clipLanguage.name} (${config.languageConfig.clipLanguage.isoCode})
# Translation Language: ${config.languageConfig.translationLanguage.name} (${config.languageConfig.translationLanguage.isoCode})

clip_language = Language.find_by(iso_name: '${config.languageConfig.clipLanguage.isoCode}')
translation_language = Language.find_by(iso_name: '${config.languageConfig.translationLanguage.isoCode}')

medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=${config.youtubeVideoId}')
phrases_data = ${JSON.stringify(phrases, null, 2)};

c = Course.find_or_create_by!(slug: '${config.slug}')
c.name = '${config.courseName}'
c.main_media_url = 'https://www.youtube.com/watch?v=${config.youtubeVideoId}'
c.save!
c.reload
c.lessons.destroy_all

Lesson.where("slug like '${config.slug}%'").destroy_all
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
`;

  fs.appendFileSync(config.outputFile, initialCode, 'utf8');
}

/**
 * Generates Ruby code for adding token translations to a specific phrase
 */
export function generateTokenTranslationRubyCode(
  outputFile: string, 
  phraseIndex: number, 
  tokenTranslations: TokenTranslation[]
): void {  
  const rubyCode = `
phrase = phrases[${phraseIndex}]
${tokenTranslations.map(t => 
  `TokenTranslation.create!(phrase: phrase, l1_start_index: ${t.l1_start_index}, l1_end_index: ${t.l1_end_index}, translation: "${t.translation}", l2_start_index: ${t.l2_start_index}, l2_end_index: ${t.l2_end_index}, similar_sound: ${JSON.stringify(t.similar_sound)})`
).join('\n')}
`;
  fs.appendFileSync(outputFile, rubyCode, 'utf8');
}

/**
 * Generates Ruby code for creating a lesson and its activities
 */
async function generateLessonActivityRubyCode(
  config: ScriptConfig,
  lesson: LessonWithTokens,
  lessonIndex: number,
  activities: Activity[],
  prompts: ReturnType<typeof getPromptsForLanguages>
): Promise<void> {
  const activityPromises = activities.map(async (activity, activityIndex) => {
    const tokenTranslations = await getTokenTranslationsForActivity(lesson, activity, config, prompts);
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
a = Activities::${activity.activityType}.create!(lesson: l, order: ${activityIndex + 1})
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

/**
 * Uses AI to generate lesson structure from phrases
 */
async function generateLessons(
  config: ScriptConfig, 
  phrases: PhraseData[],
  prompts: ReturnType<typeof getPromptsForLanguages>
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
    prompt: prompts.getLessonGenerationPrompt(config, config.songName, phrases)
  });

  return lessonsResult.object;
}

function parseLLMTokenTranslationResponse(
  config: ScriptConfig,
  phraseText: string,
  translationText: string,
  response: {
    clip_indices: Array<number>,
    translation_indices: Array<number>,
    clip_tokens: Array<string>,
    translation_tokens: Array<string>,
    clip_similar_sound: Array<string>,
  }
): Array<TokenTranslation> {
  // Tokenize both texts using the same pattern as in the prompt
  const clipTokens = phraseText.split(/\P{L}/u).filter(l => l.length > 0);
  const translationTokens = translationText.split(/\P{L}/u).filter(l => l.length > 0);

  // Validate LLM response - check that indices match the provided tokens
  const clipTokensFromIndices = response.clip_indices.map(i => clipTokens[i]);
  const translationTokensFromIndices = response.translation_indices.map(i => translationTokens[i]);
  
  if (JSON.stringify(clipTokensFromIndices) !== JSON.stringify(response.clip_tokens)) {
    throw new Error('Clip tokens mismatch:', clipTokensFromIndices, 'vs', response.clip_tokens);
  }
  
  if (JSON.stringify(translationTokensFromIndices) !== JSON.stringify(response.translation_tokens)) {
    throw new Error('Translation tokens mismatch:', translationTokensFromIndices, 'vs', response.translation_tokens);
  }

  // Helper function to find character indices for a sequence of tokens
  function findCharacterIndices(text: string, tokens: string[], tokenIndices: number[]): { start: number, end: number } {
    if (tokens.length === 0 || tokenIndices.length === 0) {
      return { start: -1, end: -1 };
    }

    // Count occurrences of each token up to its position to find the correct occurrence
    const tokenOccurrences: number[] = [];
    const allTokens = text.split(/\P{L}/u).filter(l => l.length > 0);
    
    for (let i = 0; i < tokenIndices.length; i++) {
      const tokenIndex = tokenIndices[i];
      const token = tokens[i];
      
      // Count how many times this token appears before this index
      let occurrenceCount = 0;
      for (let j = 0; j <= tokenIndex; j++) {
        if (allTokens[j] === token) {
          occurrenceCount++;
        }
      }
      tokenOccurrences.push(occurrenceCount);
    }

    // Find character positions for the first and last tokens
    const firstToken = tokens[0];
    const lastToken = tokens[tokens.length - 1];
    const firstOccurrence = tokenOccurrences[0];
    const lastOccurrence = tokenOccurrences[tokenOccurrences.length - 1];

    // Find start position of first token
    let currentOccurrence = 0;
    let startIndex = -1;
    let searchIndex = 0;
    
    while (currentOccurrence < firstOccurrence && searchIndex < text.length) {
      const match = text.slice(searchIndex).match(new RegExp(`\\b${firstToken.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i'));
      if (match) {
        currentOccurrence++;
        if (currentOccurrence === firstOccurrence) {
          startIndex = searchIndex + match.index!;
          break;
        }
        searchIndex += match.index! + match[0].length;
      } else {
        break;
      }
    }

    // Find end position of last token
    currentOccurrence = 0;
    let endIndex = -1;
    searchIndex = 0;
    
    while (currentOccurrence < lastOccurrence && searchIndex < text.length) {
      const match = text.slice(searchIndex).match(new RegExp(`\\b${lastToken.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i'));
      if (match) {
        currentOccurrence++;
        if (currentOccurrence === lastOccurrence) {
          endIndex = searchIndex + match.index! + match[0].length;
          break;
        }
        searchIndex += match.index! + match[0].length;
      } else {
        break;
      }
    }

    return { start: startIndex, end: endIndex };
  }

  // Calculate character indices for clip language (l1)
  const l1Indices = findCharacterIndices(phraseText, response.clip_tokens, response.clip_indices);
  
  // Calculate character indices for translation language (l2)
  const l2Indices = findCharacterIndices(translationText, response.translation_tokens, response.translation_indices);

  // Create the TokenTranslation object
  const result: TokenTranslation = {
    l1_start_index: l1Indices.start,
    l1_end_index: l1Indices.end,
    translation: response.translation_tokens.join(' '),
    l2_start_index: l2Indices.start,
    l2_end_index: l2Indices.end,
    similar_sound: response.clip_similar_sound || []
  };

  return [result];
}

/**
 * Uses AI to generate token translations for a single phrase
 * Includes fallback to secondary model if primary fails
 */
async function generateTokenTranslationsForPhrase(
  config: ScriptConfig,
  phrase: PhraseData,
  phraseIndex: number,
  fullLyrics: string,
  prompts: ReturnType<typeof getPromptsForLanguages>
): Promise<TokenTranslation[]> {
  const schema = z.object({
    clip_indices: z.array(z.number()),
    translation_indices: z.array(z.number()),
    clip_tokens: z.array(z.string()),
    translation_tokens: z.array(z.string()),
    clip_similar_sound: z.array(z.string()).describe(`Word or phrase in ${config.languageConfig.clipLanguage.name} that sounds similar but has different meaning. Difference must be in actual letters and not in accent marks. If unsure specify empty array here. Some good examples for similar sounds are:
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
  `)})

  try {
    const tokenTranslationsResponse = await generateObject({
      model: config.model.tokenTranslations,
      maxRetries: 2,
      output: 'array',
      schema,
      system: config.systemPrompt,
      prompt: prompts.getTokenTranslationPrompt(config, phrase[0], fullLyrics)
    });

    return tokenTranslationsResponse.object;
  } catch (error) {
    console.log(`Primary model failed for phrase ${phraseIndex}, trying fallback model...`);
    
    try {
      const tokenTranslationsResponse = await generateObject({
        model: config.model.lessons,
        maxRetries: 2,
        output: 'array',
        schema,
        system: config.systemPrompt,
        prompt: prompts.getTokenTranslationPrompt(config, phrase[0], fullLyrics)
      });

      return tokenTranslationsResponse.object;
    } catch (fallbackError) {
      console.error(`Both models failed for phrase ${phraseIndex}`);
      throw fallbackError;
    }
  }
}

/**
 * Uses AI to generate activities for a lesson
 */
async function generateLessonActivities(
  config: ScriptConfig,
  lesson: LessonWithTokens,
  fullLyrics: string,
  prompts: ReturnType<typeof getPromptsForLanguages>
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
    prompt: prompts.getLessonActivityPrompt(config, lesson, fullLyrics)
  });

  return lessonActivitiesResponse.object;
}

/**
 * Gets appropriate token translations for different activity types
 */
async function getTokenTranslationsForActivity(
  lesson: LessonWithTokens, 
  activity: Activity, 
  config: ScriptConfig,
  prompts: ReturnType<typeof getPromptsForLanguages>
): Promise<TokenTranslationForActivity[]> {
  console.log(activity.activityType);
  
  if (activity.activityType === 'ListenActivity') {
    return await processListenActivity(lesson, activity, config, prompts);
  } else if (activity.activityType === 'LanguageAlignmentActivity') {
    return await processLanguageAlignmentActivity(lesson, activity, config, prompts);
  } else {
    return [];
  }
}

/**
 * Processes listen activities by selecting tokens with similar sounds
 */
async function processListenActivity(
  lesson: LessonWithTokens,
  activity: Activity,
  config: ScriptConfig,
  prompts: ReturnType<typeof getPromptsForLanguages>
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
    prompt: prompts.getListenActivityTokenSelectionPrompt(config, phrasesWithValidTokens)
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
          result.push({ phraseIndex: lesson.phrases[i].id, word: token.originalTextInClipLanguage });
        }
      }
    }
  }

  console.log(result);
  return result;
}

/**
 * Processes language alignment activities by selecting appropriate tokens
 */
async function processLanguageAlignmentActivity(
  lesson: LessonWithTokens,
  activity: Activity,
  config: ScriptConfig,
  prompts: ReturnType<typeof getPromptsForLanguages>
): Promise<TokenTranslationForActivity[]> {
  const relevantPhrases = new Set(activity.phrases);
  const phrases = lesson.phrases.filter(p => relevantPhrases.has(p.id));

  const selectedTokensResponse = await generateObject({
    model: config.model.tokenTranslations,
    maxRetries: 5,
    output: 'array',
    schema: z.number().describe('tokenId of the selected tokens'),
    system: config.systemPrompt,
    prompt: prompts.getLanguageAlignmentTokenSelectionPrompt(config, phrases)
  });

  const selectedTokens = new Set(selectedTokensResponse.object);

  const result: TokenTranslationForActivity[] = [];
  for (let i = 0; i < lesson.phrases.length; i++) {
    for (let j = 0; j < lesson.phrases[i].tokens.length; j++) {
      if (selectedTokens.has(lesson.phrases[i].tokens[j].tokenId!)) {
        result.push({ phraseIndex: lesson.phrases[i].id, word: lesson.phrases[i].tokens[j].originalTextInClipLanguage });
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
  phrases: PhraseData[],
  prompts: ReturnType<typeof getPromptsForLanguages>
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
        fullOriginalLyrics,
        prompts
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
      text_clip_language: phrases[phraseIndex][0],
      text_translation_language: phrases[phraseIndex][1],
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
  fullLyrics: string,
  prompts: ReturnType<typeof getPromptsForLanguages>
): Promise<void> {
  for (let i = 0; i < lessonsWithTokenTranslations.length; i++) {
    const lesson = lessonsWithTokenTranslations[i];
    try {
      const lessonActivities = await generateLessonActivities(config, lesson, fullLyrics, prompts);
      await generateLessonActivityRubyCode(config, lesson, i, lessonActivities, prompts);
    } catch (err) {
      console.error(err);
      console.error(`Failed to create activities for lesson: ${i} - ${lesson.name}`);
    }
  }
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

/**
 * Main function that orchestrates the entire course generation process
 * 1. Initializes configuration and loads phrase data
 * 2. Generates lesson structure using AI
 * 3. Creates token translations for each phrase
 * 4. Generates activities for each lesson
 * 5. Outputs Ruby code for course creation
 */
async function main(): Promise<void> {
  try {
    // Initialize configuration
    const config = initializeConfiguration();
    console.log(`Generating script for: ${config.songName}`);

    // Initialize prompt system
    const prompts = getPromptsForLanguages(
      config.languageConfig.clipLanguage.name,
      config.languageConfig.translationLanguage.name
    );

    // Load phrases data
    const phrases = loadPhrasesData(config.phrasesFileName);
    const fullOriginalLyrics = phrases.map(p => p[0]).join('\n');

    // Generate initial Ruby code
    generateInitialRubyCode(config, phrases);

    // Generate lessons structure
    console.log('Generating lessons...');
    const lessons = await generateLessons(config, phrases, prompts);

    // Generate token translations for all phrases
    console.log('Generating token translations...');
    const createdTokenTranslations = await processTokenTranslations(config, phrases, prompts);

    // Create lessons with token translations
    const lessonsWithTokenTranslations = createLessonsWithTokenTranslations(
      lessons, 
      phrases, 
      createdTokenTranslations
    );

    // Generate lesson activities and Ruby code
    console.log('Generating lesson activities...');
    await processLessonsAndActivities(config, lessonsWithTokenTranslations, fullOriginalLyrics, prompts);

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

