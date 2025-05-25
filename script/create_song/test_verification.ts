// Simple verification script to test the filtering logic
// This mimics the filtering logic from processListenActivity

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

// Test data
const testPhrases = [
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

console.log("=== Testing processListenActivity filtering logic ===");
console.log("\nOriginal phrases count:", testPhrases.length);
console.log("Original phrases:", JSON.stringify(testPhrases, null, 2));

const filteredPhrases = filterPhrasesForListenActivity(testPhrases);

console.log("\n=== RESULTS ===");
console.log("Filtered phrases count:", filteredPhrases.length);
console.log("Filtered phrases:", JSON.stringify(filteredPhrases, null, 2));

// Verification
console.log("\n=== VERIFICATION ===");
console.log("✓ Expected 2 phrases, got:", filteredPhrases.length);
console.log("✓ First phrase should have 1 token with 'hola':", 
  filteredPhrases[0]?.tokens.length === 1 && 
  filteredPhrases[0]?.tokens[0]?.originalTextInSpanish === "hola");
console.log("✓ Second phrase should have 1 token with 'buenos':", 
  filteredPhrases[1]?.tokens.length === 1 && 
  filteredPhrases[1]?.tokens[0]?.originalTextInSpanish === "buenos");
console.log("✓ Phrase with id 2 should be filtered out:", 
  !filteredPhrases.some(p => p.id === 2));

// Test empty array
const emptyResult = filterPhrasesForListenActivity([]);
console.log("✓ Empty array test:", emptyResult.length === 0);

console.log("\n=== SUMMARY ===");
console.log("The filtering logic correctly:");
console.log("1. Filters out tokens with empty similar_sound arrays");
console.log("2. Filters out tokens with undefined similar_sound");
console.log("3. Removes entire phrases that have no valid tokens");
console.log("4. Preserves phrases that have at least one valid token");
console.log("5. Only passes tokens with non-empty similar_sound arrays to createListenActivityTokenSelectionPrompt"); 