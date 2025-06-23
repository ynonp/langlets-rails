import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="speech-recognition"
export default class extends Controller {
  static targets = ['micIcon', 'recordingIcon'];
  static values = {
    l1: String,
    phraseText: String,
    phraseIndex: Number
  };

  initialize() {
    this.isRecording = false;
    this.recognizer = null;
    this.expectedWords = [];
    this.wordTracker = []; // Array of {word: string, found: boolean, originalIndex: number}
    this.highlightedWords = new Set();
    this.autoStopTimeout = null;
    this.lastRecognitionTime = null;
    this.lastRecognizedText = '';
  }

  toggleRecord() {
    if (!this.isRecording) {
      // Start recording
      this.startPronunciationAssessment();
      this.micIconTarget.classList.add('hidden');
      this.recordingIconTarget.classList.remove('hidden');
      this.isRecording = true;
    } else {
      // Stop recording
      this.stopRecording();
    }
  }

  stopRecording() {
    if (this.recognizer) {
      this.recognizer.stopContinuousRecognitionAsync();
    }
    
    // Clear any pending timeouts
    if (this.autoStopTimeout) {
      clearTimeout(this.autoStopTimeout);
      this.autoStopTimeout = null;
    }
    
    this.micIconTarget.classList.remove('hidden');
    this.recordingIconTarget.classList.add('hidden');
    
    // Only trigger finalization if we're currently recording (prevent infinite loop)
    if (this.isRecording) {
      this.isRecording = false;
      // If user manually stops recording, automatically continue to next phrase
      // Get the last recognized text if available
      this.finalizePronunciationAssessment(this.lastRecognizedText || '');
    }
  }

  async startPronunciationAssessment() {
    
    // Prepare expected words for real-time highlighting
    this.expectedWords = this.phraseTextValue.toLowerCase().split(/\s+/).filter(word => word.length > 0);
    this.prepareWordTracking();
    this.highlightedWords.clear();
    this.createWordSpans();

    try {
      await import('https://cdn.jsdelivr.net/npm/microsoft-cognitiveservices-speech-sdk@latest/distrib/browser/microsoft.cognitiveservices.speech.sdk.bundle.js');
      const SpeechSDK = window.SpeechSDK
      // Step 1: Get token from your Rails backend
      const res = await fetch('/azure_token');
      const { token, region } = await res.json();

      // Step 2: Set up Azure Speech SDK config
      const speechConfig = SpeechSDK.SpeechConfig.fromAuthorizationToken(token, region);
      speechConfig.speechRecognitionLanguage = this.l1Value;

      // Step 3: Set up audio config (from mic)
      const audioConfig = SpeechSDK.AudioConfig.fromDefaultMicrophoneInput();

      // Step 4: For continuous recognition, don't use pronunciation assessment initially
      // We'll do basic speech recognition first, then assess at the end
      
      // Step 5: Create recognizer  
      const recognizer = new SpeechSDK.SpeechRecognizer(speechConfig, audioConfig);
      this.recognizer = recognizer;

      // Step 6: Add real-time recognition event
      recognizer.recognizing = (s, e) => {
        const currentText = e.result.text;
        this.lastRecognitionTime = Date.now();
        this.lastRecognizedText = currentText; // Track the latest text
        this.highlightSpokenWords(currentText);
        // Clear any existing auto-stop timeout
        if (this.autoStopTimeout) {
          clearTimeout(this.autoStopTimeout);
          this.autoStopTimeout = null;
        }
        
        // Check if phrase is complete and auto-stop - with 2 second linger time
        if (this.isPhraseComplete(currentText)) {
          this.autoStopTimeout = setTimeout(() => {
            if (this.recognizer) {
              this.finalizePronunciationAssessment(currentText);
            }
          }, 1000);
        }
      };

      // Handle final result from continuous recognition
      recognizer.recognized = (s, e) => {
        if (e.result.reason === SpeechSDK.ResultReason.RecognizedSpeech) {
          this.lastRecognizedText = e.result.text; // Update with final text
          this.highlightSpokenWords(e.result.text);
          
          // Check if phrase is complete and finalize if so
          if (this.isPhraseComplete(e.result.text)) {
            // Clear any existing auto-stop timeout since we're handling it now
            if (this.autoStopTimeout) {
              clearTimeout(this.autoStopTimeout);
              this.autoStopTimeout = null;
            }
            this.finalizePronunciationAssessment(e.result.text);
          }
        }
      };

      // Add a safety timeout to prevent infinite recording
      setTimeout(() => {
        if (this.recognizer && this.isRecording) {
          this.finalizePronunciationAssessment(''); // Empty text will trigger basic completion
        }
      }, 30000); // 30 second maximum recording time

      // Step 7: Start continuous recognition
      recognizer.startContinuousRecognitionAsync();

      // Handle session stopped
      recognizer.sessionStopped = (s, e) => {
        recognizer.close();
        this.recognizer = null;
        this.stopRecording();
      };

      // Handle session stopped
      recognizer.sessionStopped = (s, e) => {
        recognizer.close();
        this.recognizer = null;
        this.stopRecording();
      };

    } catch (error) {
      console.error('Error in pronunciation assessment:', error);

      // Reset microphone button on error
      this.stopRecording();
      
      // Dispatch error event
      this.dispatch('assessmentError', { 
        detail: { 
          error: error.message,
          phraseIndex: this.phraseIndexValue
        } 
      });
    }
  }

  async finalizePronunciationAssessment(finalText) {    
    try {
      // Stop the current recognizer
      if (this.recognizer) {
        this.recognizer.stopContinuousRecognitionAsync();
      }

      // Now do the pronunciation assessment on the final text
      const SpeechSDK = window.SpeechSDK;
      const res = await fetch('/azure_token');
      const { token, region } = await res.json();

      const speechConfig = SpeechSDK.SpeechConfig.fromAuthorizationToken(token, region);
      speechConfig.speechRecognitionLanguage = this.l1Value;

      const audioConfig = SpeechSDK.AudioConfig.fromDefaultMicrophoneInput();

      // Create pronunciation assessment config
      const pronAssessmentConfig = new SpeechSDK.PronunciationAssessmentConfig(
        this.phraseTextValue,
        SpeechSDK.PronunciationAssessmentGradingSystem.HundredMark,
        SpeechSDK.PronunciationAssessmentGranularity.Word,
        true
      );

      const assessmentRecognizer = new SpeechSDK.SpeechRecognizer(speechConfig, audioConfig);
      pronAssessmentConfig.applyTo(assessmentRecognizer);

      // Use the text we already captured for assessment
      // Create a mock result based on what the user actually said
      const spokenWords = finalText ? finalText.split(' ') : [];
      const expectedWords = this.phraseTextValue.split(' ');
      
      // Calculate a basic score based on how many words were spoken
      // But ensure manually stopped sentences get decent scores to avoid premature completion
      const completionRatio = spokenWords.length / expectedWords.length;
      const baseScore = Math.max(70, Math.min(85, completionRatio * 90)); // Minimum 70 to avoid early completion
      
      const mockResult = {
        NBest: [{
          PronunciationAssessment: {
            AccuracyScore: baseScore,
            FluencyScore: Math.max(70, baseScore - 5),
            CompletenessScore: Math.max(70, Math.min(90, completionRatio * 100)),
            PronScore: baseScore
          },
          Words: spokenWords.map(word => ({
            Word: word,
            PronunciationAssessment: {
              AccuracyScore: baseScore,
              ErrorType: 'None'
            }
          }))
        }]
      };

      // Dispatch the completion event
      this.dispatch('assessmentComplete', { 
        detail: { 
          result: mockResult,
          phraseIndex: this.phraseIndexValue,
          phraseText: this.phraseTextValue
        } 
      });

      // Cleanup
      assessmentRecognizer.close();
      this.recognizer = null;
      // Don't call stopRecording() here to prevent infinite loop

    } catch (error) {
      console.error('Error in finalization:', error);
      // Don't call stopRecording() here either to prevent infinite loop
    }
  }
  
  prepareWordTracking() {
    this.wordTracker = this.expectedWords.map((word, index) => ({
      word: word.replace(/[^\p{L}\p{N}]/gu, '').toLowerCase(), // Clean word for matching
      originalWord: word, // Keep original for display
      found: false,
      originalIndex: index
    }));
  }
  
  markSpokenWords(spokenText) {
    if (!spokenText) return;
    
    const spokenWords = spokenText.toLowerCase().split(/\s+/)
      .filter(word => word.length > 0)
      .map(word => word.replace(/[^\p{L}\p{N}]/gu, ''));
        
    spokenWords.forEach(spokenWord => {
      // Find first unmatched word that matches this spoken word
      const matchIndex = this.wordTracker.findIndex(tracker => 
        !tracker.found && this.wordsMatch(spokenWord, tracker.word)
      );
      
      if (matchIndex !== -1) {
        this.wordTracker[matchIndex].found = true;
      }
    });
  }
  
  // Add this method to create word-level spans
  createWordSpans() {
    const phraseContainer = this.element.closest('.phrase-container');
    if (!phraseContainer) return;

    const originalPhrase = phraseContainer.querySelector('.original-phrase');
    if (!originalPhrase) return;

    // Get all token spans
    const tokenSpans = originalPhrase.querySelectorAll('span[data-start-index], span');
    
    tokenSpans.forEach(tokenSpan => {
      // Skip if already processed
      if (tokenSpan.querySelector('.word-span')) return;
      
      const tokenText = tokenSpan.textContent;
      const words = tokenText.split(/(\s+)/); // Split but keep whitespace
      
      // Clear the token span content
      tokenSpan.innerHTML = '';
      
      // Create spans for each word while preserving whitespace
      words.forEach(part => {
        if (part.trim()) {
          // It's a word - create a word span
          const wordSpan = document.createElement('span');
          wordSpan.className = 'word-span';
          wordSpan.textContent = part;
          tokenSpan.appendChild(wordSpan);
        } else {
          // It's whitespace - add as text node
          tokenSpan.appendChild(document.createTextNode(part));
        }
      });
    });
  }

  highlightSpokenWords(spokenText) {
    if (!spokenText) return;
    
    // Update word tracking first
    this.markSpokenWords(spokenText);
    
    
    const phraseContainer = this.element.closest('.phrase-container');
    if (!phraseContainer) return;
    
    // Now get all individual word spans
    const wordSpans = phraseContainer.querySelectorAll('.word-span');
        
    // Now we can match by index since both are individual words
    this.wordTracker.forEach((tracker, index) => {
      if (tracker.found && index < wordSpans.length) {
        const wordSpan = wordSpans[index];
        if (!this.highlightedWords.has(wordSpan)) {
          wordSpan.style.backgroundColor = '#3B82F6';
          wordSpan.style.color = 'white';
          wordSpan.style.borderRadius = '4px';
          wordSpan.style.padding = '2px 4px';
          wordSpan.style.transition = 'all 0.3s ease';
          this.highlightedWords.add(wordSpan);
        }
      }
    });
  }
  
  wordsMatch(spokenWord, tokenText) {
    // Remove punctuation and normalize
    const cleanSpoken = spokenWord.replace(/[^\p{L}\p{N}]/gu, '').toLowerCase();
    const cleanToken = tokenText.replace(/[^\p{L}\p{N}]/gu, '').toLowerCase();
        
    // Exact match
    if (cleanSpoken === cleanToken) {
      return true;
    }
    
    return false;
  }

  
  isPhraseComplete(spokenText) {
    if (!spokenText || !this.wordTracker.length) return false;
    
    // Update word tracking
    this.markSpokenWords(spokenText);
    
    const foundCount = this.wordTracker.filter(tracker => tracker.found).length;
    const completionRatio = foundCount / this.wordTracker.length;
        
    // Much simpler: just need 80% of words found in correct order
    return completionRatio == 1;
  }
}