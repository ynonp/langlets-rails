import { Controller } from "@hotwired/stimulus"
import * as SpeechSDK from "microsoft-cognitiveservices-speech-sdk";

// Connects to data-controller="speak-activity"
export default class extends Controller {
  static targets = ['revealL1Text', 'l1Text', 'micIcon', 'recordingIcon', 'pronunciationText', 'assessmentResult', 'completionMessage'];
  static values = {
    l1: String,
    fulltext: String,
  };

  initialize() {
    this.isRecording = false;
    this.recognizer = null;
  }

  revealL1Text() {
    this.revealL1TextTarget.classList.add('hidden');
    this.l1TextTarget.classList.remove('hidden');
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
      if (this.recognizer) {
        this.recognizer.stopContinuousRecognitionAsync();
      }
      this.micIconTarget.classList.remove('hidden');
      this.recordingIconTarget.classList.add('hidden');
      this.isRecording = false;
    }
  }

  async startPronunciationAssessment() {
    console.log(this.fulltextValue);
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
        this.fulltextValue,
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

        // Display results
        this.showAssessmentResults(jsonResult);

        // Cleanup
        recognizer.close();
        this.recognizer = null;

        // Reset microphone button
        this.micIconTarget.classList.remove('hidden');
        this.recordingIconTarget.classList.add('hidden');
        this.isRecording = false;
      });
    } catch (error) {
      console.error('Error in pronunciation assessment:', error);

      // Reset microphone button on error
      this.micIconTarget.classList.remove('hidden');
      this.recordingIconTarget.classList.add('hidden');
      this.isRecording = false;
    }
  }
  
  showAssessmentResults(jsonResult) {
    // Get pronunciation details
    const nbest = jsonResult.NBest && jsonResult.NBest.length > 0 ? jsonResult.NBest[0] : null;

    if (!nbest) {
      this.pronunciationTextTarget.innerHTML = '<span class="text-red-400">Could not assess pronunciation. Please try again.</span>';
      return;
    }

    // Extract scores
    const scores = nbest.PronunciationAssessment || {};

    // Set scores
    accuracyScore.textContent = Math.round(scores.AccuracyScore || 0);
    fluencyScore.textContent = Math.round(scores.FluencyScore || 0);
    completenessScore.textContent = Math.round(scores.CompletenessScore || 0);

    // Format the text with error highlighting
    const words = nbest.Words || [];
    let formattedText = '';

    // Determine which original words were pronounced, omitted, or mispronounced
    const wordStatusMap = {};
    const originalWords = this.fulltextValue.split(/\s+/);

    originalWords.forEach((word, i) => {
      const matchingWord = words.find(w => w.Word.toLowerCase() === word.toLowerCase());

      if (matchingWord) {
        const errorType = matchingWord.PronunciationAssessment?.ErrorType || 'None';
        wordStatusMap[i] = { word, errorType, assessedWord: matchingWord };
      } else {
        wordStatusMap[i] = { word, errorType: 'Omission', assessedWord: null };
      }
    });

    // Look for insertions (words in the assessment that aren't in the original)
    words.forEach(assessedWord => {
      const wordLower = assessedWord.Word.toLowerCase();
      const isInOriginal = originalWords.some(w => w.toLowerCase() === wordLower);

      if (!isInOriginal && assessedWord.PronunciationAssessment) {
        // This is an inserted word
        // Find the closest position to insert it
        const insertAfter = words.indexOf(assessedWord) > 0 ? 
          words.indexOf(assessedWord) - 1 : 0;

        // Add to the map with special insertion marker
        wordStatusMap[`insertion_${insertAfter}`] = { 
          word: assessedWord.Word, 
          errorType: 'Insertion', 
          assessedWord 
        };
      }
    });

    // Build formatted text
    Object.keys(wordStatusMap)
      .sort((a, b) => {
        // Sort keys, with numeric keys first in numeric order, 
        // then insertion keys based on their numeric component
        if (!isNaN(a) && !isNaN(b)) return Number(a) - Number(b);
        if (!isNaN(a)) return -1;
        if (!isNaN(b)) return 1;

        // Extract numeric parts of insertion keys
        const aNum = Number(a.replace('insertion_', ''));
        const bNum = Number(b.replace('insertion_', ''));
        return aNum - bNum;
      })
      .forEach(key => {
        const { word, errorType } = wordStatusMap[key];

        if (errorType === 'None') {
          formattedText += `<span class="mr-1">${word}</span>`;
        } else if (errorType === 'Mispronunciation') {
          formattedText += `<span class="mr-1 bg-yellow-300 text-black px-1 rounded">${word}</span>`;
        } else if (errorType === 'Omission') {
          formattedText += `<span class="mr-1 text-gray-500">[${word}]</span>`;
        } else if (errorType === 'Insertion') {
          formattedText += `<span class="mr-1 line-through bg-red-300 text-red-800 px-1 rounded">${word}</span>`;
        }
      });

    // Set the formatted text
    this.pronunciationTextTarget.innerHTML = formattedText;

    // Show the assessment result
    this.assessmentResultTarget.classList.remove('hidden');

    // Show completion message if score is good enough
    const overallScore = (scores.AccuracyScore + scores.FluencyScore + scores.CompletenessScore) / 3;
    if (overallScore >= 60) {
      this.completionMessageTarget.classList.remove('hidden');
      this.completionMessageTarget.classList.add('animate-fade-in');
    }
  }
}
