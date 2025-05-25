import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

// Import the types we need to test
import type { LessonWithTokens, Activity, ScriptConfig, TokenTranslationForActivity } from './create_song.ts';

// Mock the AI model calls since we're testing the logic, not the AI responses
const mockConfig: ScriptConfig = {
  youtubeVideoId: "test",
  phrasesFileName: "test.json",
  courseName: "Test Course",
  slug: "test",
  songName: "Test Song",
  outputFile: "test.rb",
  systemPrompt: "test prompt",
  model: {
    ds: null,
    grok: null,
    lessons: null,
    tokenTranslations: null
  }
};

// Create test helper functions that mimic the logic from the actual functions
// but without the AI calls
function simulateProcessLanguageAlignmentActivity(
  lesson: LessonWithTokens,
  activity: Activity,
  selectedTokenIds: number[]
): TokenTranslationForActivity[] {
  const selectedTokens = new Set(selectedTokenIds);
  const result: TokenTranslationForActivity[] = [];
  
  // This is the buggy logic from the original code
  for (let i = 0; i < lesson.phrases.length; i++) {
    for (let j = 0; j < lesson.phrases[i].tokens.length; j++) {
      if (selectedTokens.has(lesson.phrases[i].tokens[j].tokenId!)) {
        // BUG: Using `i` instead of `lesson.phrases[i].id`
        result.push({ phraseIndex: i, word: lesson.phrases[i].tokens[j].originalTextInSpanish });
      }
    }
  }
  
  return result;
}

function simulateProcessLanguageAlignmentActivityFixed(
  lesson: LessonWithTokens,
  activity: Activity,
  selectedTokenIds: number[]
): TokenTranslationForActivity[] {
  const selectedTokens = new Set(selectedTokenIds);
  const result: TokenTranslationForActivity[] = [];
  
  // This is the corrected logic
  for (let i = 0; i < lesson.phrases.length; i++) {
    for (let j = 0; j < lesson.phrases[i].tokens.length; j++) {
      if (selectedTokens.has(lesson.phrases[i].tokens[j].tokenId!)) {
        // FIX: Using `lesson.phrases[i].id` instead of `i`
        result.push({ phraseIndex: lesson.phrases[i].id, word: lesson.phrases[i].tokens[j].originalTextInSpanish });
      }
    }
  }
  
  return result;
}

Deno.test("demonstrates phrase index bug in LanguageAlignmentActivity", () => {
  // Setup test data that represents a lesson with phrases 4, 5, 6, 7
  // (like in the user's example)
  const lesson: LessonWithTokens = {
    name: "Test Lesson",
    phrases: [
      {
        id: 4, // Global phrase index 4
        text_l1: "no es tarde pero",
        text_l2: "it's not late but",
        tokens: [
          {
            originalTextInSpanish: "no es",
            originalTextOccurence: 0,
            translationTextInEnglish: "it's not",
            translationTextOccurence: 0,
            similar_sound: [],
            tokenId: 1
          },
          {
            originalTextInSpanish: "tarde",
            originalTextOccurence: 0,
            translationTextInEnglish: "late",
            translationTextOccurence: 0,
            similar_sound: [],
            tokenId: 2
          }
        ]
      },
      {
        id: 5, // Global phrase index 5
        text_l1: "aparecen tantos miedos",
        text_l2: "so many fears appear",
        tokens: [
          {
            originalTextInSpanish: "aparecen",
            originalTextOccurence: 0,
            translationTextInEnglish: "appear",
            translationTextOccurence: 0,
            similar_sound: [],
            tokenId: 3
          },
          {
            originalTextInSpanish: "miedos",
            originalTextOccurence: 0,
            translationTextInEnglish: "fears",
            translationTextOccurence: 0,
            similar_sound: [],
            tokenId: 4
          }
        ]
      },
      {
        id: 6, // Global phrase index 6
        text_l1: "tengo sueños de",
        text_l2: "I have dreams of",
        tokens: [
          {
            originalTextInSpanish: "tengo",
            originalTextOccurence: 0,
            translationTextInEnglish: "I have",
            translationTextOccurence: 0,
            similar_sound: [],
            tokenId: 5
          }
        ]
      },
      {
        id: 7, // Global phrase index 7
        text_l1: "me cuesta imaginar",
        text_l2: "it's hard for me to imagine",
        tokens: [
          {
            originalTextInSpanish: "me cuesta",
            originalTextOccurence: 0,
            translationTextInEnglish: "it's hard for me",
            translationTextOccurence: 0,
            similar_sound: [],
            tokenId: 6
          }
        ]
      }
    ]
  };

  const activity: Activity = {
    activityType: 'LanguageAlignmentActivity',
    phrases: [4, 5, 6, 7]
  };

  // Simulate selecting some tokens
  const selectedTokenIds = [1, 3, 5, 6]; // Select some tokens from different phrases

  // Test the buggy behavior
  const buggyResult = simulateProcessLanguageAlignmentActivity(lesson, activity, selectedTokenIds);
  
  // Test the fixed behavior
  const fixedResult = simulateProcessLanguageAlignmentActivityFixed(lesson, activity, selectedTokenIds);

  // The buggy result should have incorrect phrase indices (0, 1, 2, 3)
  console.log("Buggy result phrase indices:", buggyResult.map(r => r.phraseIndex));
  assertEquals(buggyResult.map(r => r.phraseIndex), [0, 1, 2, 3], "Buggy version should use lesson-relative indices");

  // The fixed result should have correct phrase indices (4, 5, 6, 7)
  console.log("Fixed result phrase indices:", fixedResult.map(r => r.phraseIndex));
  assertEquals(fixedResult.map(r => r.phraseIndex), [4, 5, 6, 7], "Fixed version should use global phrase indices");

  // Verify the words are the same in both cases
  assertEquals(buggyResult.map(r => r.word), fixedResult.map(r => r.word), "Words should be the same in both versions");

  // Show what the generated Ruby code would look like with the bug
  const buggyRubyTokenTranslations = buggyResult.map(t => 
    `phrases[${t.phraseIndex}].find_token_translation("${t.word}")`
  );
  
  const fixedRubyTokenTranslations = fixedResult.map(t => 
    `phrases[${t.phraseIndex}].find_token_translation("${t.word}")`
  );

  console.log("\nBuggy Ruby code would generate:");
  buggyRubyTokenTranslations.forEach(line => console.log(line));
  
  console.log("\nFixed Ruby code should generate:");
  fixedRubyTokenTranslations.forEach(line => console.log(line));

  // The bug is demonstrated: buggy version uses phrases[0], phrases[1], etc.
  // while it should use phrases[4], phrases[5], etc.
});

Deno.test("demonstrates phrase index bug in ListenActivity", () => {
  // Similar test for ListenActivity
  const lesson: LessonWithTokens = {
    name: "Test Lesson",
    phrases: [
      {
        id: 4, // Global phrase index 4
        text_l1: "hola mundo",
        text_l2: "hello world",
        tokens: [
          {
            originalTextInSpanish: "hola",
            originalTextOccurence: 0,
            translationTextInEnglish: "hello",
            translationTextOccurence: 0,
            similar_sound: ["cola"], // Non-empty similar_sound for ListenActivity
            tokenId: 1
          }
        ]
      },
      {
        id: 5, // Global phrase index 5
        text_l1: "buenos días",
        text_l2: "good morning",
        tokens: [
          {
            originalTextInSpanish: "buenos",
            originalTextOccurence: 0,
            translationTextInEnglish: "good",
            translationTextOccurence: 0,
            similar_sound: ["huevos"], // Non-empty similar_sound for ListenActivity
            tokenId: 2
          }
        ]
      }
    ]
  };

  const activity: Activity = {
    activityType: 'ListenActivity',
    phrases: [4, 5]
  };

  // Simulate the ListenActivity logic (simplified)
  function simulateProcessListenActivity(
    lesson: LessonWithTokens,
    selectedTokenIds: number[],
    useBuggyLogic: boolean = true
  ): TokenTranslationForActivity[] {
    const selectedTokens = new Set(selectedTokenIds);
    const result: TokenTranslationForActivity[] = [];
    
    for (let i = 0; i < lesson.phrases.length; i++) {
      for (let j = 0; j < lesson.phrases[i].tokens.length; j++) {
        if (selectedTokens.has(lesson.phrases[i].tokens[j].tokenId!)) {
          const token = lesson.phrases[i].tokens[j];
          if (token.similar_sound && Array.isArray(token.similar_sound) && token.similar_sound.length > 0) {
            const phraseIndex = useBuggyLogic ? i : lesson.phrases[i].id;
            result.push({ phraseIndex, word: token.originalTextInSpanish });
          }
        }
      }
    }
    
    return result;
  }

  const selectedTokenIds = [1, 2]; // Select both tokens

  // Test the buggy behavior
  const buggyResult = simulateProcessListenActivity(lesson, selectedTokenIds, true);
  
  // Test the fixed behavior
  const fixedResult = simulateProcessListenActivity(lesson, selectedTokenIds, false);

  // The buggy result should have incorrect phrase indices (0, 1)
  assertEquals(buggyResult.map(r => r.phraseIndex), [0, 1], "Buggy ListenActivity should use lesson-relative indices");

  // The fixed result should have correct phrase indices (4, 5)
  assertEquals(fixedResult.map(r => r.phraseIndex), [4, 5], "Fixed ListenActivity should use global phrase indices");

  console.log("\nListenActivity - Buggy result phrase indices:", buggyResult.map(r => r.phraseIndex));
  console.log("ListenActivity - Fixed result phrase indices:", fixedResult.map(r => r.phraseIndex));
}); 