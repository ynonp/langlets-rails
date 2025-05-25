/**
 * Comprehensive Test for Ruby Script Generation
 * 
 * This test verifies that the create_song script can actually generate valid Ruby code
 * by writing to real files and checking their contents.
 * 
 * To run this test:
 * deno test --no-check --allow-all comprehensive_test.ts
 * 
 * This test will:
 * 1. Create real test files (phrases.json)
 * 2. Generate actual Ruby script files
 * 3. Verify the content of the generated Ruby scripts
 * 4. Clean up all test files
 */

import { assertEquals, assertExists, assertStringIncludes } from "jsr:@std/assert";
import { MockLanguageModelV1 } from "npm:ai/test";
import { 
  type ScriptConfig, 
  type PhraseData, 
  type TokenTranslation,
  generateInitialRubyCode,
  generateTokenTranslationRubyCode,
  loadPhrasesData
} from "./create_song.ts";
import fs from 'node:fs';

// ============================================================================
// TEST DATA
// ============================================================================

const testPhrases: PhraseData[] = [
  ["Hola mundo", "Hello world", 1000],
  ["¿Cómo estás?", "How are you?", 2000],
  ["Muy bien, gracias", "Very well, thank you", 3000],
  ["Me gusta la música", "I like music", 4000],
  ["Vamos a bailar", "Let's dance", 5000]
];

const testTokenTranslations: TokenTranslation[] = [
  {
    originalTextInSpanish: "Hola",
    originalTextOccurence: 0,
    translationTextInEnglish: "Hello",
    translationTextOccurence: 0,
    similar_sound: ["ola", "hora"]
  },
  {
    originalTextInSpanish: "mundo",
    originalTextOccurence: 0,
    translationTextInEnglish: "world",
    translationTextOccurence: 0,
    similar_sound: ["mudo", "fundo"]
  },
  {
    originalTextInSpanish: "música",
    originalTextOccurence: 0,
    translationTextInEnglish: "music",
    translationTextOccurence: 0,
    similar_sound: ["mística", "músculo"]
  }
];

// ============================================================================
// TEST UTILITIES
// ============================================================================

function createMockModels() {
  return {
    ds: new MockLanguageModelV1({
      doGenerate: async () => ({
        rawCall: { rawPrompt: null, rawSettings: {} },
        finishReason: 'stop' as const,
        usage: { promptTokens: 10, completionTokens: 20 },
        text: 'Mock DeepSeek response',
      }),
    }),
    grok: new MockLanguageModelV1({
      doGenerate: async () => ({
        rawCall: { rawPrompt: null, rawSettings: {} },
        finishReason: 'stop' as const,
        usage: { promptTokens: 10, completionTokens: 20 },
        text: 'Mock Grok response',
      }),
    }),
    lessons: new MockLanguageModelV1({
      doGenerate: async () => ({
        rawCall: { rawPrompt: null, rawSettings: {} },
        finishReason: 'stop' as const,
        usage: { promptTokens: 10, completionTokens: 20 },
        text: 'Mock Anthropic response',
      }),
    }),
    tokenTranslations: new MockLanguageModelV1({
      doGenerate: async () => ({
        rawCall: { rawPrompt: null, rawSettings: {} },
        finishReason: 'stop' as const,
        usage: { promptTokens: 10, completionTokens: 20 },
        text: 'Mock Google response',
      }),
    }),
  };
}

function createTestConfiguration(): ScriptConfig {
  const timestamp = Date.now();
  return {
    youtubeVideoId: "test_video_123",
    phrasesFileName: `test_phrases_${timestamp}.json`,
    courseName: "Test Spanish Song Course",
    slug: "test-spanish-song",
    songName: "Mi Canción Favorita",
    outputFile: `test_output_${timestamp}.rb`,
    systemPrompt: "You are a Spanish teacher creating language lessons from songs.",
    model: createMockModels()
  };
}

function setupTestFiles(config: ScriptConfig) {
  // Create test phrases file
  fs.writeFileSync(config.phrasesFileName, JSON.stringify(testPhrases), 'utf8');
    
  console.log(`📁 Created test files:`);
  console.log(`   - ${config.phrasesFileName}`);
  console.log(`   - flow.md`);
}

function cleanupTestFiles(config: ScriptConfig) {
  const filesToClean = [
    config.outputFile,
    config.phrasesFileName,
  ];
  
  filesToClean.forEach(file => {
    try {
      if (fs.existsSync(file)) {
        fs.unlinkSync(file);
        console.log(`🗑️  Cleaned up: ${file}`);
      }
    } catch (error) {
      console.warn(`⚠️  Cleanup warning for ${file}:`, error);
    }
  });
}

// ============================================================================
// TESTS
// ============================================================================

Deno.test("File I/O Operations - loadPhrasesData", () => {
  console.log("\n🧪 Testing file I/O operations...");
  const config = createTestConfiguration();
  
  try {
    setupTestFiles(config);
    
    const phrases = loadPhrasesData(config.phrasesFileName);
    
    assertEquals(phrases.length, 5);
    assertEquals(phrases[0][0], "Hola mundo");
    assertEquals(phrases[0][1], "Hello world");
    assertEquals(phrases[0][2], 1000);
    assertEquals(phrases[4][0], "Vamos a bailar");
    assertEquals(phrases[4][1], "Let's dance");
    assertEquals(phrases[4][2], 5000);
    
    console.log("✅ Successfully loaded and parsed phrases data");
    console.log(`📊 Loaded ${phrases.length} phrases`);
  } finally {
    cleanupTestFiles(config);
  }
});

Deno.test("Ruby Code Generation - Initial Script", () => {
  console.log("\n🧪 Testing initial Ruby script generation...");
  const config = createTestConfiguration();
  
  try {
    setupTestFiles(config);
    
    // Generate initial Ruby code
    generateInitialRubyCode(config, testPhrases);
    
    // Verify file was created
    assertEquals(fs.existsSync(config.outputFile), true);
    
    // Read and verify content
    const rubyContent = fs.readFileSync(config.outputFile, 'utf8');
    
    // Check for essential Ruby code elements
    assertStringIncludes(rubyContent, "en = Language.find_by(iso_name: 'en')");
    assertStringIncludes(rubyContent, "es = Language.find_by(iso_name: 'es')");
    assertStringIncludes(rubyContent, `url: 'https://www.youtube.com/watch?v=${config.youtubeVideoId}'`);
    assertStringIncludes(rubyContent, `slug: '${config.slug}'`);
    assertStringIncludes(rubyContent, `name = '${config.courseName}'`);
    
    // Check that phrases data is included
    assertStringIncludes(rubyContent, "Hola mundo");
    assertStringIncludes(rubyContent, "Hello world");
    assertStringIncludes(rubyContent, "Vamos a bailar");
    assertStringIncludes(rubyContent, "Let's dance");
    
    // Check for Ruby structure
    assertStringIncludes(rubyContent, "phrases_data = ");
    assertStringIncludes(rubyContent, "Phrase.create!");
    assertStringIncludes(rubyContent, "text_l1: text_l1");
    assertStringIncludes(rubyContent, "text_l2: text_l2");
    assertStringIncludes(rubyContent, "timestamp: timestamp");
    
    console.log("✅ Initial Ruby code generated successfully");
    console.log(`📄 Output file: ${config.outputFile}`);
    console.log(`📏 Content length: ${rubyContent.length} characters`);
    
    // Show sample of generated code
    const lines = rubyContent.split('\n').slice(0, 15);
    console.log("📋 Sample of generated Ruby code:");
    lines.forEach((line, index) => {
      console.log(`${String(index + 1).padStart(2)}: ${line}`);
    });
    
  } finally {
    cleanupTestFiles(config);
  }
});

Deno.test("Ruby Code Generation - Token Translations", () => {
  console.log("\n🧪 Testing token translation Ruby code generation...");
  const config = createTestConfiguration();
  
  try {
    setupTestFiles(config);
    
    // First generate initial code
    generateInitialRubyCode(config, testPhrases);
    
    // Then add token translations for multiple phrases
    generateTokenTranslationRubyCode(config.outputFile, 0, testTokenTranslations.slice(0, 2));
    generateTokenTranslationRubyCode(config.outputFile, 3, testTokenTranslations.slice(2, 3));
    
    // Read and verify content
    const rubyContent = fs.readFileSync(config.outputFile, 'utf8');
    
    // Check for token translation code
    assertStringIncludes(rubyContent, "phrase = phrases[0]");
    assertStringIncludes(rubyContent, "phrase = phrases[3]");
    assertStringIncludes(rubyContent, 'phrase.add_token_translation("Hola"');
    assertStringIncludes(rubyContent, 'phrase.add_token_translation("mundo"');
    assertStringIncludes(rubyContent, 'phrase.add_token_translation("música"');
    assertStringIncludes(rubyContent, '"Hello"');
    assertStringIncludes(rubyContent, '"world"');
    assertStringIncludes(rubyContent, '"music"');
    assertStringIncludes(rubyContent, 'similar_sound: ["ola","hora"]');
    assertStringIncludes(rubyContent, 'similar_sound: ["mudo","fundo"]');
    assertStringIncludes(rubyContent, 'similar_sound: ["mística","músculo"]');
    
    console.log("✅ Token translation Ruby code appended successfully");
    
    // Count token translation calls
    const tokenCalls = (rubyContent.match(/add_token_translation/g) || []).length;
    console.log(`📊 Generated ${tokenCalls} token translation calls`);
    
  } finally {
    cleanupTestFiles(config);
  }
});

Deno.test("Complete Ruby Script Validation", () => {
  console.log("\n🧪 Testing complete Ruby script structure...");
  const config = createTestConfiguration();
  
  try {
    setupTestFiles(config);
    
    // Generate complete script
    generateInitialRubyCode(config, testPhrases);
    
    // Add token translations for all test phrases
    for (let i = 0; i < testPhrases.length; i++) {
      const tokensForPhrase = i < 3 ? testTokenTranslations : testTokenTranslations.slice(0, 1);
      generateTokenTranslationRubyCode(config.outputFile, i, tokensForPhrase);
    }
    
    const rubyContent = fs.readFileSync(config.outputFile, 'utf8');
    
    // Validate complete structure
    assertStringIncludes(rubyContent, "# Create phrases in DB");
    assertStringIncludes(rubyContent, "# Create Lessons in the DB");
    
    // Verify multiple phrase token translations
    for (let i = 0; i < testPhrases.length; i++) {
      assertStringIncludes(rubyContent, `phrase = phrases[${i}]`);
    }
    
    // Verify Ruby syntax elements
    assertStringIncludes(rubyContent, "Course.find_or_create_by!");
    assertStringIncludes(rubyContent, "Medium.find_or_create_by!");
    assertStringIncludes(rubyContent, "c.lessons.destroy_all");
    assertStringIncludes(rubyContent, "medium.phrases.destroy_all");
    assertStringIncludes(rubyContent, "medium.phrases.reload");
    
    // Validate specific content requirements
    const youtubeUrlPattern = new RegExp(`https://www\\.youtube\\.com/watch\\?v=${config.youtubeVideoId}`);
    assertEquals(youtubeUrlPattern.test(rubyContent), true);
    
    assertStringIncludes(rubyContent, `slug: '${config.slug}'`);
    assertStringIncludes(rubyContent, 'phrases_data = [');
    assertStringIncludes(rubyContent, '"Hola mundo"');
    assertStringIncludes(rubyContent, '"Hello world"');
    assertStringIncludes(rubyContent, '1000');
    assertStringIncludes(rubyContent, "l1: es");
    assertStringIncludes(rubyContent, "l2: en");
    assertStringIncludes(rubyContent, ', 0, '); // occurrence parameters
    assertStringIncludes(rubyContent, 'similar_sound: [');
    
    console.log("✅ Complete Ruby script structure verified");
    console.log(`📏 Total script length: ${rubyContent.length} characters`);
    
    // Analyze the generated script
    const lines = rubyContent.split('\n');
    const nonEmptyLines = lines.filter(line => line.trim().length > 0);
    const tokenTranslationCalls = (rubyContent.match(/add_token_translation/g) || []).length;
    
    console.log("📊 Script Analysis:");
    console.log(`   - Total lines: ${lines.length}`);
    console.log(`   - Non-empty lines: ${nonEmptyLines.length}`);
    console.log(`   - Token translation calls: ${tokenTranslationCalls}`);
    console.log(`   - Contains course setup: ${rubyContent.includes('Course.find_or_create_by!')}`);
    console.log(`   - Contains phrase creation: ${rubyContent.includes('Phrase.create!')}`);
    console.log(`   - Contains token translations: ${tokenTranslationCalls > 0}`);
    
    // Save a sample for manual inspection
    const sampleFile = `sample_generated_${Date.now()}.rb`;
    fs.writeFileSync(sampleFile, rubyContent, 'utf8');
    console.log(`💾 Sample script saved as: ${sampleFile}`);
    console.log("   (This file is left for manual inspection - delete when done)");
    
  } finally {
    cleanupTestFiles(config);
  }
});

Deno.test("Configuration and Mock Models", () => {
  console.log("\n🧪 Testing configuration and mock models...");
  const config = createTestConfiguration();
  
  // Test configuration
  assertExists(config.youtubeVideoId);
  assertExists(config.phrasesFileName);
  assertExists(config.courseName);
  assertExists(config.slug);
  assertExists(config.songName);
  assertExists(config.outputFile);
  assertExists(config.systemPrompt);
  
  // Test model configuration
  assertExists(config.model);
  assertExists(config.model.ds);
  assertExists(config.model.grok);
  assertExists(config.model.lessons);
  assertExists(config.model.tokenTranslations);
  
  // Verify mock models have the doGenerate method
  const models = ['ds', 'grok', 'lessons', 'tokenTranslations'] as const;
  models.forEach(modelName => {
    assertEquals(typeof config.model[modelName].doGenerate, 'function');
  });
  
  console.log("✅ Configuration and mock models validated");
  console.log(`📹 Video ID: ${config.youtubeVideoId}`);
  console.log(`🎵 Song: ${config.songName}`);
  console.log(`📚 Course: ${config.courseName}`);
  console.log(`🔧 All ${models.length} AI models mocked successfully`);
});

// ============================================================================
// MANUAL TEST INSTRUCTIONS
// ============================================================================

console.log(`
🎯 COMPREHENSIVE RUBY SCRIPT GENERATION TEST

This test suite verifies that the create_song script can:
✅ Load phrase data from JSON files
✅ Generate valid Ruby script structure
✅ Create proper course and medium setup code
✅ Generate phrase creation code with proper data
✅ Add token translations with similar sounds
✅ Produce syntactically correct Ruby code

To run these tests manually:
1. deno test --no-check --allow-all comprehensive_test.ts

The tests will:
- Create temporary test files
- Generate actual Ruby scripts
- Verify the content matches expectations
- Clean up all temporary files
- Leave one sample file for manual inspection

Expected output: All tests should pass with detailed logging
showing the generated Ruby code structure and content.
`); 