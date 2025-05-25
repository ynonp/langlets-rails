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

// Test data
const testPhrases: PhraseData[] = [
  ["Hola mundo", "Hello world", 1000],
  ["¿Cómo estás?", "How are you?", 2000],
  ["Muy bien, gracias", "Very well, thank you", 3000]
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
  }
];

// Mock Deno.args for command line arguments
const mockArgs = [
  "test_video_id",
  "test_phrases.json", 
  "Test Spanish Course",
  "test-spanish-course",
  "Test Song Name"
];

// Create mock AI models according to AI SDK testing patterns
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

// Create test configuration
function createTestConfiguration(): ScriptConfig {
  return {
    youtubeVideoId: mockArgs[0],
    phrasesFileName: mockArgs[1],
    courseName: mockArgs[2],
    slug: mockArgs[3],
    songName: mockArgs[4],
    outputFile: `test_output_${Date.now()}.rb`,
    systemPrompt: "Mock system prompt for testing",
    model: createMockModels()
  };
}

// Setup and cleanup functions
function setupTestFiles(config: ScriptConfig) {
  // Create test phrases file
  fs.writeFileSync(config.phrasesFileName, JSON.stringify(testPhrases), 'utf8');  
}

function cleanupTestFiles(config: ScriptConfig) {
  // Clean up test files
  try {
    if (fs.existsSync(config.outputFile)) {
      fs.unlinkSync(config.outputFile);
    }
    if (fs.existsSync(config.phrasesFileName)) {
      fs.unlinkSync(config.phrasesFileName);
    }
  } catch (error) {
    console.warn('Cleanup warning:', error);
  }
}

// ============================================================================
// TESTS
// ============================================================================

Deno.test("initializeConfiguration mock - basic functionality", () => {
  const config = createTestConfiguration();
  
  // Test that the configuration object has all required properties
  assertEquals(config.youtubeVideoId, "test_video_id");
  assertEquals(config.phrasesFileName, "test_phrases.json");
  assertEquals(config.courseName, "Test Spanish Course");
  assertEquals(config.slug, "test-spanish-course");
  assertEquals(config.songName, "Test Song Name");
  assertStringIncludes(config.outputFile, ".rb");
  assertEquals(config.systemPrompt, "Mock system prompt for testing");
  
  // Test that model configuration exists
  assertExists(config.model);
  assertExists(config.model.ds);
  assertExists(config.model.grok);
  assertExists(config.model.lessons);
  assertExists(config.model.tokenTranslations);
});

Deno.test("loadPhrasesData - loads test data correctly", () => {
  const config = createTestConfiguration();
  
  try {
    setupTestFiles(config);
    
    const phrases = loadPhrasesData(config.phrasesFileName);
    
    assertEquals(phrases.length, 3);
    assertEquals(phrases[0][0], "Hola mundo");
    assertEquals(phrases[0][1], "Hello world");
    assertEquals(phrases[0][2], 1000);
    assertEquals(phrases[1][0], "¿Cómo estás?");
    assertEquals(phrases[1][1], "How are you?");
    assertEquals(phrases[1][2], 2000);
    assertEquals(phrases[2][0], "Muy bien, gracias");
    assertEquals(phrases[2][1], "Very well, thank you");
    assertEquals(phrases[2][2], 3000);
  } finally {
    cleanupTestFiles(config);
  }
});

Deno.test("generateInitialRubyCode - creates valid Ruby script", () => {
  const config = createTestConfiguration();
  
  try {
    setupTestFiles(config);
    
    // Generate initial Ruby code
    generateInitialRubyCode(config, testPhrases);
    
    // Verify file was created
    assertExists(fs.existsSync(config.outputFile));
    
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
    assertStringIncludes(rubyContent, "¿Cómo estás?");
    assertStringIncludes(rubyContent, "How are you?");
    
    // Check for Ruby structure
    assertStringIncludes(rubyContent, "phrases_data = ");
    assertStringIncludes(rubyContent, "Phrase.create!");
    assertStringIncludes(rubyContent, "text_l1: text_l1");
    assertStringIncludes(rubyContent, "text_l2: text_l2");
    assertStringIncludes(rubyContent, "timestamp: timestamp");
    
    console.log("✅ Initial Ruby code generated successfully");
    console.log(`📄 Output file: ${config.outputFile}`);
    console.log(`📏 Content length: ${rubyContent.length} characters`);
  } finally {
    cleanupTestFiles(config);
  }
});

Deno.test("generateTokenTranslationRubyCode - appends token translations", () => {
  const config = createTestConfiguration();
  
  try {
    setupTestFiles(config);
    
    // First generate initial code
    generateInitialRubyCode(config, testPhrases);
    
    // Then add token translations
    generateTokenTranslationRubyCode(config.outputFile, 0, testTokenTranslations);
    
    // Read and verify content
    const rubyContent = fs.readFileSync(config.outputFile, 'utf8');
    
    // Check for token translation code
    assertStringIncludes(rubyContent, "phrase = phrases[0]");
    assertStringIncludes(rubyContent, 'phrase.add_token_translation("Hola"');
    assertStringIncludes(rubyContent, 'phrase.add_token_translation("mundo"');
    assertStringIncludes(rubyContent, '"Hello"');
    assertStringIncludes(rubyContent, '"world"');
    assertStringIncludes(rubyContent, 'similar_sound: ["ola","hora"]');
    assertStringIncludes(rubyContent, 'similar_sound: ["mudo","fundo"]');
    
    console.log("✅ Token translation Ruby code appended successfully");
  } finally {
    cleanupTestFiles(config);
  }
});

Deno.test("complete Ruby script structure verification", () => {
  const config = createTestConfiguration();
  
  try {
    setupTestFiles(config);
    
    // Generate initial Ruby code
    generateInitialRubyCode(config, testPhrases);
    
    // Add token translations for each phrase
    for (let i = 0; i < testPhrases.length; i++) {
      generateTokenTranslationRubyCode(config.outputFile, i, testTokenTranslations);
    }
    
    // Read final content
    const rubyContent = fs.readFileSync(config.outputFile, 'utf8');
    
    // Verify complete structure
    assertStringIncludes(rubyContent, "# Create phrases in DB");
    assertStringIncludes(rubyContent, "# Create Lessons in the DB");
    
    // Verify multiple phrase token translations
    assertStringIncludes(rubyContent, "phrase = phrases[0]");
    assertStringIncludes(rubyContent, "phrase = phrases[1]");
    assertStringIncludes(rubyContent, "phrase = phrases[2]");
    
    // Count occurrences of add_token_translation calls
    const tokenTranslationCalls = (rubyContent.match(/add_token_translation/g) || []).length;
    assertEquals(tokenTranslationCalls, testPhrases.length * testTokenTranslations.length);
    
    // Verify Ruby syntax elements
    assertStringIncludes(rubyContent, "Course.find_or_create_by!");
    assertStringIncludes(rubyContent, "Medium.find_or_create_by!");
    assertStringIncludes(rubyContent, "c.lessons.destroy_all");
    assertStringIncludes(rubyContent, "medium.phrases.destroy_all");
    assertStringIncludes(rubyContent, "medium.phrases.reload");
    
    console.log("✅ Complete Ruby script structure verified");
    console.log(`📊 Token translation calls: ${tokenTranslationCalls}`);
    console.log(`📏 Total script length: ${rubyContent.length} characters`);
    
    // Optional: Print first few lines for manual inspection
    const lines = rubyContent.split('\n').slice(0, 10);
    console.log("📋 First 10 lines of generated script:");
    lines.forEach((line, index) => {
      console.log(`${index + 1}: ${line}`);
    });
  } finally {
    cleanupTestFiles(config);
  }
});

Deno.test("Ruby script content validation", () => {
  const config = createTestConfiguration();
  
  try {
    setupTestFiles(config);
    
    // Generate complete script
    generateInitialRubyCode(config, testPhrases);
    generateTokenTranslationRubyCode(config.outputFile, 0, testTokenTranslations);
    
    const rubyContent = fs.readFileSync(config.outputFile, 'utf8');
    
    // Validate specific content requirements
    
    // 1. Check YouTube URL format
    const youtubeUrlPattern = new RegExp(`https://www\\.youtube\\.com/watch\\?v=${config.youtubeVideoId}`);
    assertEquals(youtubeUrlPattern.test(rubyContent), true);
    
    // 2. Check course slug format
    assertStringIncludes(rubyContent, `slug: '${config.slug}'`);
    
    // 3. Check phrase data structure
    assertStringIncludes(rubyContent, 'phrases_data = [');
    assertStringIncludes(rubyContent, '"Hola mundo"');
    assertStringIncludes(rubyContent, '"Hello world"');
    assertStringIncludes(rubyContent, '1000');
    
    // 4. Check language assignments
    assertStringIncludes(rubyContent, "l1: es");
    assertStringIncludes(rubyContent, "l2: en");
    
    // 5. Check token translation parameters
    assertStringIncludes(rubyContent, ', 0, '); // occurrence parameters
    
    // 6. Check similar_sound arrays
    assertStringIncludes(rubyContent, 'similar_sound: [');
    
    console.log("✅ Ruby script content validation passed");
  } finally {
    cleanupTestFiles(config);
  }
});

Deno.test("mock models can generate responses", async () => {
  const config = createTestConfiguration();
  
  // Test DeepSeek mock model
  const dsResult = await config.model.ds.doGenerate({
    prompt: [{ role: 'user' as const, content: [{ type: 'text' as const, text: 'test' }] }],
    mode: { type: 'regular' as const }
  });
  assertEquals(dsResult.text, 'Mock DeepSeek response');
  assertEquals(dsResult.finishReason, 'stop');
  assertEquals(dsResult.usage.promptTokens, 10);
  assertEquals(dsResult.usage.completionTokens, 20);
  
  // Test Grok mock model
  const grokResult = await config.model.grok.doGenerate({
    prompt: [{ role: 'user' as const, content: [{ type: 'text' as const, text: 'test' }] }],
    mode: { type: 'regular' as const }
  });
  assertEquals(grokResult.text, 'Mock Grok response');
  assertEquals(grokResult.finishReason, 'stop');
  
  // Test Anthropic mock model
  const lessonsResult = await config.model.lessons.doGenerate({
    prompt: [{ role: 'user' as const, content: [{ type: 'text' as const, text: 'test' }] }],
    mode: { type: 'regular' as const }
  });
  assertEquals(lessonsResult.text, 'Mock Anthropic response');
  assertEquals(lessonsResult.finishReason, 'stop');
  
  // Test Google mock model
  const tokenResult = await config.model.tokenTranslations.doGenerate({
    prompt: [{ role: 'user' as const, content: [{ type: 'text' as const, text: 'test' }] }],
    mode: { type: 'regular' as const }
  });
  assertEquals(tokenResult.text, 'Mock Google response');
  assertEquals(tokenResult.finishReason, 'stop');
});

Deno.test("smoke test - configuration is valid for script execution", () => {
  const config = createTestConfiguration();
  
  // Verify configuration meets basic requirements for script execution
  assertExists(config.youtubeVideoId);
  assertExists(config.phrasesFileName);
  assertExists(config.courseName);
  assertExists(config.slug);
  assertExists(config.songName);
  assertExists(config.outputFile);
  assertExists(config.systemPrompt);
  
  // Verify all AI models are properly configured
  const models = ['ds', 'grok', 'lessons', 'tokenTranslations'] as const;
  models.forEach(modelName => {
    assertExists(config.model[modelName]);
    // Verify mock models have the doGenerate method
    assertEquals(typeof config.model[modelName].doGenerate, 'function');
  });
  
  console.log("✅ Mock configuration is valid and ready for testing");
  console.log(`📹 Video ID: ${config.youtubeVideoId}`);
  console.log(`🎵 Song: ${config.songName}`);
  console.log(`📚 Course: ${config.courseName}`);
  console.log(`🔧 All ${models.length} AI models mocked successfully`);
}); 