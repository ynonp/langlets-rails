import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"

// Connects to data-controller="speak-activity"
export default class extends Controller {
  static targets = ['pronunciationText', 'assessmentResult', 'completionMessage', 
                    'accuracyScore', 'fluencyScore', 'completenessScore', 'progressBar',
                    'originalPhrase', 'translationPhrase', 'phrasesContainer', 'phraseContainer'];
  static values = {
    phrases: Array,
    l1: String
  };

  initialize() {
    this.assessedPhrases = [];
    this.currentPhraseIndex = 0;
    // Set up progress tracking
    this.totalPhrases = document.querySelectorAll('.original-phrase').length;
    this.completedPhrases = 0;
    this.setupEventListeners();
  }

  setupEventListeners() {
    // Listen for assessment complete events from speech recognition controllers
    this.element.addEventListener('speech-recognition:assessmentComplete', this.handleAssessmentComplete.bind(this));
    this.element.addEventListener('speech-recognition:assessmentError', this.handleAssessmentError.bind(this));
  }
  
  updateProgressBar() {
    if (this.hasProgressBarTarget) {
      const progressPercentage = (this.completedPhrases / this.totalPhrases) * 100;
      this.progressBarTarget.style.width = `${progressPercentage}%`;
    }
  }

  handleAssessmentComplete(event) {
    const { result, phraseIndex, phraseText } = event.detail;
    
    // Store assessment result for this phrase
    this.assessedPhrases[phraseIndex] = { result, phraseText };
    this.completedPhrases++;
    this.updateProgressBar();
    
    // Show the assessment results
    this.showAssessmentResults(result, phraseText);
    
    // Show the next phrase if available
    this.showNextPhrase(phraseIndex);
    
    // Check if all phrases have been completed
    if (this.completedPhrases >= this.totalPhrases) {
      this.showCompletionMessage();
    }
  }
  
  showNextPhrase(currentIndex) {
    const nextIndex = currentIndex + 1;
    
    // Hide the entire current phrase container
    const currentContainer = document.querySelector(`.phrase-container[data-phrase-id="${currentIndex}"]`);
    if (currentContainer) {
      currentContainer.classList.add('hidden');
    }
    
    // Show the next phrase if it exists
    if (nextIndex < this.totalPhrases) {
      // Show the next phrase container
      const nextContainer = document.querySelector(`.phrase-container[data-phrase-id="${nextIndex}"]`);
      if (nextContainer) {
        nextContainer.classList.remove('hidden');
      }
    }
  }
  
  handleAssessmentError(event) {
    const { error, phraseIndex } = event.detail;
    console.error(`Error with phrase ${phraseIndex}: ${error}`);
    // Handle error display if needed
  }
  
  showAssessmentResults(jsonResult, phraseText) {
    // Get pronunciation details
    const nbest = jsonResult.NBest && jsonResult.NBest.length > 0 ? jsonResult.NBest[0] : null;

    if (!nbest) {
      this.pronunciationTextTarget.innerHTML = '<span class="text-red-400">Could not assess pronunciation. Please try again.</span>';
      return;
    }

    // Extract scores
    const scores = nbest.PronunciationAssessment || {};

    // Set scores
    this.accuracyScoreTarget.textContent = Math.round(scores.AccuracyScore || 0);
    this.fluencyScoreTarget.textContent = Math.round(scores.FluencyScore || 0);
    this.completenessScoreTarget.textContent = Math.round(scores.CompletenessScore || 0);

    // Format the text with error highlighting
    const words = nbest.Words || [];
    let formattedText = '';

    // Determine which original words were pronounced, omitted, or mispronounced
    const wordStatusMap = {};
    const originalWords = phraseText.split(/[\p{P}\p{Z}]+/u).filter(Boolean)

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
  }
  
  showCompletionMessage() {
    // Calculate overall score based on all assessed phrases
    let totalAccuracy = 0;
    let totalFluency = 0;
    let totalCompleteness = 0;
    let count = 0;
    
    this.assessedPhrases.forEach(phrase => {
      if (phrase && phrase.result.NBest && phrase.result.NBest.length > 0) {
        const scores = phrase.result.NBest[0].PronunciationAssessment || {};
        totalAccuracy += scores.AccuracyScore || 0;
        totalFluency += scores.FluencyScore || 0;
        totalCompleteness += scores.CompletenessScore || 0;
        count++;
      }
    });
    
    const averageScore = count > 0 ? 
      (totalAccuracy + totalFluency + totalCompleteness) / (3 * count) : 0;
    
    // Show completion message if score is good enough or all phrases attempted
    if (averageScore >= 60 || this.completedPhrases >= this.totalPhrases) {
      this.completionMessageTarget.classList.remove('hidden');
      animate(this.completionMessageTarget, 
        { opacity: [0, 1], scale: [0.8, 1] }, 
        { duration: 0.3, easing: 'easeOut' }
      );
      this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
    }
  }
}

