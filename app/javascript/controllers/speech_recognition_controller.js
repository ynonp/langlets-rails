import { Controller } from "@hotwired/stimulus"
import * as SpeechSDK from "microsoft-cognitiveservices-speech-sdk";

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
    this.micIconTarget.classList.remove('hidden');
    this.recordingIconTarget.classList.add('hidden');
    this.isRecording = false;
  }

  async startPronunciationAssessment() {
    console.log('Assessing phrase:', this.phraseTextValue);
    try {
      // Step 1: Get token from your Rails backend
      const res = await fetch('/azure_token');
      const { token, region } = await res.json();

      // Step 2: Set up Azure Speech SDK config
      const speechConfig = SpeechSDK.SpeechConfig.fromAuthorizationToken(token, region);
      speechConfig.speechRecognitionLanguage = this.l1Value;

      // Step 3: Set up audio config (from mic)
      const audioConfig = SpeechSDK.AudioConfig.fromDefaultMicrophoneInput();

      // Step 4: Define pronunciation assessment config
      const pronAssessmentConfig = new SpeechSDK.PronunciationAssessmentConfig(
        this.phraseTextValue,
        SpeechSDK.PronunciationAssessmentGradingSystem.HundredMark,
        SpeechSDK.PronunciationAssessmentGranularity.Word,
        true // Enable miscue detection
      );

      // Step 5: Create recognizer
      const recognizer = new SpeechSDK.SpeechRecognizer(speechConfig, audioConfig);
      this.recognizer = recognizer;

      // Attach assessment config to recognizer
      pronAssessmentConfig.applyTo(recognizer);

      // Step 6: Start recognition
      recognizer.recognizeOnceAsync(result => {
        const jsonResult = JSON.parse(result.privJson); // Raw JSON with detailed scores
        console.log('Pronunciation assessment:', jsonResult);

        // Dispatch custom event with result data
        this.dispatch('assessmentComplete', { 
          detail: { 
            result: jsonResult,
            phraseIndex: this.phraseIndexValue,
            phraseText: this.phraseTextValue
          } 
        });

        // Cleanup
        recognizer.close();
        this.recognizer = null;

        // Reset microphone button
        this.stopRecording();
      });
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
} 