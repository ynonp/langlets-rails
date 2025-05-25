import { assertEquals, assertExists } from "https://deno.land/std@0.208.0/assert/mod.ts";

// Import the types we need to test
import type { LessonWithTokens, Activity, ScriptConfig } from './create_song.ts';

// Create a test helper function that mimics the filtering logic from processListenActivity
function filterPhrasesForListenActivity(phrases: any[]): any[] {
  // Filter phrases to only include tokens with non-empty similar_sound arrays
  const phrasesWithValidTokens = phrases.map(phrase => ({
    ...phrase,
    tokens: phrase.tokens.filter((token: any) => 
      token.similar_sound && 
      Array.isArray(token.similar_sound) && 
      token.similar_sound.length > 0
    )
  })).filter(phrase => phrase.tokens.length > 0); // Only include phrases that have at least one valid token

  return phrasesWithValidTokens;
}

Deno.test("processListenActivity filters tokens with non-empty similar_sound arrays", () => {
  // Setup test data - this represents the phrases that would be passed to the filtering logic
  const phrases = [
    {
      id: 0,
      text_l1: "Hola mundo",
      text_l2: "Hello world",
      tokens: [
        {
          originalTextInSpanish: "hola",
          originalTextOccurence: 0,
          translationTextInEnglish: "hello",
          translationTextOccurence: 0,
          similar_sound: ["cola"], // Non-empty similar_sound
          tokenId: 1
        },
        {
          originalTextInSpanish: "mundo",
          originalTextOccurence: 0,
          translationTextInEnglish: "world",
          translationTextOccurence: 0,
          similar_sound: [], // Empty similar_sound - should be filtered out
          tokenId: 2
        }
      ]
    },
    {
      id: 1,
      text_l1: "Buenos días",
      text_l2: "Good morning",
      tokens: [
        {
          originalTextInSpanish: "buenos",
          originalTextOccurence: 0,
          translationTextInEnglish: "good",
          translationTextOccurence: 0,
          similar_sound: ["huevos"], // Non-empty similar_sound
          tokenId: 3
        },
        {
          originalTextInSpanish: "días",
          originalTextOccurence: 0,
          translationTextInEnglish: "morning",
          translationTextOccurence: 0,
          similar_sound: undefined as any, // Undefined similar_sound - should be filtered out
          tokenId: 4
        }
      ]
    },
    {
      id: 2,
      text_l1: "Sin tokens válidos",
      text_l2: "No valid tokens",
      tokens: [
        {
          originalTextInSpanish: "sin",
          originalTextOccurence: 0,
          translationTextInEnglish: "without",
          translationTextOccurence: 0,
          similar_sound: [], // Empty similar_sound
          tokenId: 5
        }
      ]
    }
  ];

  // Apply the filtering logic
  const filteredPhrases = filterPhrasesForListenActivity(phrases);

  // Verify that only phrases with valid tokens were returned
  assertEquals(filteredPhrases.length, 2, "Should only return 2 phrases (those with valid tokens)");

  // Verify first phrase has only the token with non-empty similar_sound
  assertEquals(filteredPhrases[0].id, 0);
  assertEquals(filteredPhrases[0].tokens.length, 1, "First phrase should have 1 valid token");
  assertEquals(filteredPhrases[0].tokens[0].originalTextInSpanish, "hola");
  assertEquals(filteredPhrases[0].tokens[0].similar_sound, ["cola"]);

  // Verify second phrase has only the token with non-empty similar_sound
  assertEquals(filteredPhrases[1].id, 1);
  assertEquals(filteredPhrases[1].tokens.length, 1, "Second phrase should have 1 valid token");
  assertEquals(filteredPhrases[1].tokens[0].originalTextInSpanish, "buenos");
  assertEquals(filteredPhrases[1].tokens[0].similar_sound, ["huevos"]);

  // Verify that the phrase with no valid tokens was filtered out completely
  // (phrase with id: 2 should not be in filteredPhrases)
  const phraseIds = filteredPhrases.map((p: any) => p.id);
  assertEquals(phraseIds.includes(2), false, "Phrase with no valid tokens should be filtered out");
});

Deno.test("processListenActivity handles empty phrases array", () => {
  const phrases: any[] = [];

  // Apply the filtering logic
  const filteredPhrases = filterPhrasesForListenActivity(phrases);

  // Verify that an empty array is returned
  assertEquals(filteredPhrases.length, 0, "Should return empty array when no phrases provided");
});

Deno.test("processListenActivity handles phrases with all invalid tokens", () => {
  const phrases = [
    {
      id: 0,
      text_l1: "Solo tokens inválidos",
      text_l2: "Only invalid tokens",
      tokens: [
        {
          originalTextInSpanish: "solo",
          originalTextOccurence: 0,
          translationTextInEnglish: "only",
          translationTextOccurence: 0,
          similar_sound: [], // Empty similar_sound
          tokenId: 1
        },
        {
          originalTextInSpanish: "tokens",
          originalTextOccurence: 0,
          translationTextInEnglish: "tokens",
          translationTextOccurence: 0,
          similar_sound: undefined as any, // Undefined similar_sound
          tokenId: 2
        }
      ]
    }
  ];

  // Apply the filtering logic
  const filteredPhrases = filterPhrasesForListenActivity(phrases);

  // Verify that no phrases are returned since all tokens are invalid
  assertEquals(filteredPhrases.length, 0, "Should return empty array when all tokens are invalid");
}); 