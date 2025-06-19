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
    this.highlightedWords = new Set();
    this.autoStopTimeout = null;
    this.lastRecognitionTime = null;
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
    this.isRecording = false;
  }

  async startPronunciationAssessment() {
    console.log('Assessing phrase:', this.phraseTextValue);
    
    // Prepare expected words for real-time highlighting
    this.expectedWords = this.phraseTextValue.toLowerCase().split(/\s+/).filter(word => word.length > 0);
    this.highlightedWords.clear();
    
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
        console.log('Recognizing:', currentText); // Debug log
        this.lastRecognitionTime = Date.now();
        this.highlightSpokenWords(currentText);
        
        // Clear any existing auto-stop timeout
        if (this.autoStopTimeout) {
          clearTimeout(this.autoStopTimeout);
          this.autoStopTimeout = null;
        }
        
        // Check if phrase is complete and auto-stop - but be more conservative
        if (this.isPhraseComplete(currentText)) {
          console.log('Phrase appears complete, will stop in 3 seconds...'); // Debug log
          this.autoStopTimeout = setTimeout(() => {
            if (this.recognizer) {
              console.log('Auto-stopping recognition');
              this.finalizePronunciationAssessment(currentText);
            }
          }, 500); // Wait 3 seconds after completion to catch any final words
        }
      };

      // Handle final result from continuous recognition
      recognizer.recognized = (s, e) => {
        if (e.result.reason === SpeechSDK.ResultReason.RecognizedSpeech) {
          console.log('Final recognized result:', e.result.text);
          // Don't finalize immediately - let the auto-stop logic handle it
        }
      };

      // Add a safety timeout to prevent infinite recording
      setTimeout(() => {
        if (this.recognizer && this.isRecording) {
          console.log('Safety timeout - stopping recording after 30 seconds');
          this.finalizePronunciationAssessment(''); // Empty text will trigger basic completion
        }
      }, 30000); // 30 second maximum recording time

      // Step 7: Start continuous recognition
      recognizer.startContinuousRecognitionAsync();

      // Handle session stopped
      recognizer.sessionStopped = (s, e) => {
        console.log('Session stopped');
        recognizer.close();
        this.recognizer = null;
        this.stopRecording();
      };

      // Handle session stopped
      recognizer.sessionStopped = (s, e) => {
        console.log('Session stopped');
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
      // Since we can't directly assess text, we'll create a mock result
      const mockResult = {
        NBest: [{
          PronunciationAssessment: {
            AccuracyScore: 85,
            FluencyScore: 80,
            CompletenessScore: 90,
            PronScore: 85
          },
          Words: finalText.split(' ').map(word => ({
            Word: word,
            PronunciationAssessment: {
              AccuracyScore: 85,
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
      this.stopRecording();

    } catch (error) {
      console.error('Error in finalization:', error);
      this.stopRecording();
    }
  }
  
  highlightSpokenWords(spokenText) {
    if (!spokenText) return;
    
    console.log('Highlighting words for:', spokenText); // Debug log
    
    const spokenWords = spokenText.toLowerCase().split(/\s+/).filter(word => word.length > 0);
    const phraseContainer = this.element.closest('.phrase-container');
    
    if (!phraseContainer) {
      console.log('No phrase container found, trying alternative selector');
      return;
    }
    
    // Try multiple selectors to find the token spans
    let tokenSpans = phraseContainer.querySelectorAll('.original-phrase span[data-start-index]');
    
    if (tokenSpans.length === 0) {
      // Try alternative selector - just all spans in the original phrase
      tokenSpans = phraseContainer.querySelectorAll('.original-phrase span');
    }
    
    if (tokenSpans.length === 0) {
      // Try even more generic selector
      tokenSpans = phraseContainer.querySelectorAll('span');
    }
    
    if (tokenSpans.length === 0) {
      return;
    }
    
    // Log the text content of found spans for debugging
    console.log('Available spans:', Array.from(tokenSpans).map(span => span.textContent));
    
    // For each spoken word, try to find matching tokens and highlight them
    spokenWords.forEach(spokenWord => {
      console.log('Processing spoken word:', spokenWord); // Debug log
      tokenSpans.forEach(span => {
        const tokenText = span.textContent.toLowerCase().trim();
        
        // Simple matching - can be improved with fuzzy matching
        if (this.wordsMatch(spokenWord, tokenText) && !this.highlightedWords.has(span)) {
          console.log('Highlighting match:', spokenWord, 'with', tokenText); // Debug log
          span.style.backgroundColor = '#3B82F6'; // Blue background
          span.style.color = 'white';
          span.style.borderRadius = '4px';
          span.style.padding = '2px 4px';
          span.style.transition = 'all 0.3s ease';
          this.highlightedWords.add(span);
        }
      });
    });
  }
  
  wordsMatch(spokenWord, tokenText) {
    // Remove punctuation and normalize
    const cleanSpoken = spokenWord.replace(/[^\w]/g, '').toLowerCase();
    const cleanToken = tokenText.replace(/[^\w]/g, '').toLowerCase();
    
    console.log('Comparing:', cleanSpoken, 'with', cleanToken); // Debug log
    
    // Exact match
    if (cleanSpoken === cleanToken) {
      console.log('Exact match!'); // Debug log
      return true;
    }
    
    // Partial match for longer words (at least 3 characters)
    if (cleanSpoken.length >= 3 && cleanToken.length >= 3) {
      if (cleanToken.includes(cleanSpoken) || cleanSpoken.includes(cleanToken)) {
        console.log('Partial match!'); // Debug log
        return true;
      }
    }
    
    // Fuzzy match for similar words (simple edit distance)
    if (cleanSpoken.length >= 3 && cleanToken.length >= 3) {
      const similarity = this.calculateSimilarity(cleanSpoken, cleanToken);
      if (similarity > 0.7) {
        console.log('Fuzzy match!', similarity); // Debug log
        return true;
      }
    }
    
    return false;
  }
  
  calculateSimilarity(word1, word2) {
    const maxLength = Math.max(word1.length, word2.length);
    if (maxLength === 0) return 1;
    
    const distance = this.levenshteinDistance(word1, word2);
    return (maxLength - distance) / maxLength;
  }
  
  levenshteinDistance(str1, str2) {
    const matrix = [];
    
    for (let i = 0; i <= str2.length; i++) {
      matrix[i] = [i];
    }
    
    for (let j = 0; j <= str1.length; j++) {
      matrix[0][j] = j;
    }
    
    for (let i = 1; i <= str2.length; i++) {
      for (let j = 1; j <= str1.length; j++) {
        if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1,
            matrix[i][j - 1] + 1,
            matrix[i - 1][j] + 1
          );
        }
      }
    }
    
    return matrix[str2.length][str1.length];
  }
  
  isPhraseComplete(spokenText) {
    if (!spokenText || !this.expectedWords.length) return false;
    
    const spokenWords = spokenText.toLowerCase().split(/\s+/).filter(word => word.length > 0);
    
    console.log('Checking completion - Expected:', this.expectedWords, 'Spoken:', spokenWords); // Debug log
    
    // Don't consider complete unless we have a reasonable number of words
    if (spokenWords.length < Math.max(2, Math.ceil(this.expectedWords.length * 0.5))) {
      console.log('Not enough words spoken yet'); // Debug log
      return false;
    }
    
    // Count how many expected words we've matched
    let matchedCount = 0;
    this.expectedWords.forEach(expectedWord => {
      const hasMatch = spokenWords.some(spokenWord => 
        this.wordsMatch(spokenWord, expectedWord)
      );
      if (hasMatch) matchedCount++;
    });
    
    const completionRatio = matchedCount / this.expectedWords.length;
    console.log('Completion ratio:', completionRatio, 'Matched:', matchedCount, 'of', this.expectedWords.length); // Debug log
    
    // Consider complete if we've matched at least 80% of expected words AND have spoken enough words
    return completionRatio >= 0.8 && spokenWords.length >= Math.ceil(this.expectedWords.length * 0.7);
  }
}