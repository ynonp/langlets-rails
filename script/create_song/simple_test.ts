import { assertEquals } from "jsr:@std/assert";
import { 
  type PhraseData, 
  loadPhrasesData
} from "./create_song.ts";
import fs from 'node:fs';

// Test data
const testPhrases: PhraseData[] = [
  ["Hola mundo", "Hello world", 1000],
  ["¿Cómo estás?", "How are you?", 2000],
  ["Muy bien, gracias", "Very well, thank you", 3000]
];

Deno.test("simple test - loadPhrasesData works", () => {
  const testFileName = "simple_test_phrases.json";
  
  try {
    // Create test file
    fs.writeFileSync(testFileName, JSON.stringify(testPhrases), 'utf8');
    
    // Load and test
    const phrases = loadPhrasesData(testFileName);
    
    assertEquals(phrases.length, 3);
    assertEquals(phrases[0][0], "Hola mundo");
    assertEquals(phrases[0][1], "Hello world");
    assertEquals(phrases[0][2], 1000);
    
    console.log("✅ Simple test passed!");
  } finally {
    // Cleanup
    if (fs.existsSync(testFileName)) {
      fs.unlinkSync(testFileName);
    }
  }
}); 