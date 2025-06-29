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

  connect() {
    // Set initial miniplayer segment for the first phrase
    this.updateMiniplayerSegment(0);
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
    this.completedPhrases = phraseIndex + 1;
    this.updateProgressBar();
    
    // Show the assessment results
    // this.showAssessmentResults(result, phraseText);
    
    // Show the next phrase if available
    this.showNextPhrase(phraseIndex);
    
    // Check if all phrases have been completed
    if (phraseIndex == this.totalPhrases - 1) {
      this.showCompletionMessage();
    }
  }
  
  resetWordHighlighting(phraseIndex) {
    // Reset highlighting for the completed phrase
    const completedContainer = document.querySelector(`.phrase-container[data-phrase-id="${phraseIndex}"]`);
    if (completedContainer) {
      const tokenSpans = completedContainer.querySelectorAll('.original-phrase span[data-start-index]');
      tokenSpans.forEach(span => {
        span.style.backgroundColor = '';
        span.style.color = '';
        span.style.borderRadius = '';
        span.style.padding = '';
        span.style.transition = '';
      });
    }
  }

  showNextPhrase(currentIndex) {
    const nextIndex = currentIndex + 1;
    
    // Reset highlighting for the current phrase before hiding it
    this.resetWordHighlighting(currentIndex);
    
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
      
      // Update miniplayer segment parameters for the next phrase
      this.updateMiniplayerSegment(nextIndex);
    }
  }
  
  handleAssessmentError(event) {
    const { error, phraseIndex } = event.detail;
    console.error(`Error with phrase ${phraseIndex}: ${error}`);
    // Handle error display if needed
  }
  
  showAssessmentResults(jsonResult, phraseText) {
    // With real-time word highlighting, we can simplify the final results
    // Just show a simple completion message instead of detailed error analysis
    
    const nbest = jsonResult.NBest && jsonResult.NBest.length > 0 ? jsonResult.NBest[0] : null;
    if (!nbest) {
      this.pronunciationTextTarget.innerHTML = '<span class="text-red-400">Could not assess pronunciation. Please try again.</span>';
      this.assessmentResultTarget.classList.remove('hidden');
      return;
    }

    // Extract scores
    const scores = nbest.PronunciationAssessment || {};

    // Set scores  
    this.accuracyScoreTarget.textContent = Math.round(scores.AccuracyScore || 0);
    this.fluencyScoreTarget.textContent = Math.round(scores.FluencyScore || 0);
    this.completenessScoreTarget.textContent = Math.round(scores.CompletenessScore || 0);

    // Show a simple success message since words were highlighted in real-time
    const averageScore = (scores.AccuracyScore + scores.FluencyScore + scores.CompletenessScore) / 3;
    if (averageScore >= 60) {
      this.pronunciationTextTarget.innerHTML = '<span class="text-green-400 text-center">✓ Great pronunciation!</span>';
    } else {
      this.pronunciationTextTarget.innerHTML = '<span class="text-yellow-400 text-center">Good effort! Keep practicing.</span>';
    }

    // Show the assessment result
    this.assessmentResultTarget.classList.remove('hidden');
    
    // Hide assessment after a short delay to keep the flow smooth
    setTimeout(() => {
      this.assessmentResultTarget.classList.add('hidden');
    }, 2000);
  }
  
  showCompletionMessage() {
    // Only show completion if we've actually completed all phrases
    if (this.completedPhrases < this.totalPhrases) {
      return;
    }

    if (!this.completionMessageTarget.classList.contains('hidden')) {
      // already visible
      return; 
    }
    
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
    
    // Award XP based on average score (1-10 XP based on performance)
    const xpAmount = Math.max(1, Math.round(averageScore / 10));
    this.awardXp(xpAmount);
    
    // Show completion message - all phrases have been attempted
    this.completionMessageTarget.classList.remove('hidden');
    animate(this.completionMessageTarget, 
      { opacity: [0, 1], scale: [0.8, 1] }, 
      { duration: 0.3, easing: 'easeOut' }
    );
    this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
  }

  // Award XP by calling the progress tracker controller
  awardXp(amount) {
    // Find the progress tracker controller on the gamification bar
    const gamificationBar = document.getElementById('gamification-bar');
    if (gamificationBar && gamificationBar.dataset.controller) {
      const controller = this.application.getControllerForElementAndIdentifier(gamificationBar, 'progress-tracker');
      if (controller) {
        controller.awardXp(amount);
      }
    }
  }

  updateMiniplayerSegment(phraseIndex) {
    const playButton = document.querySelector('[data-action*="main-video-player#playSegment"]');
    if (!playButton) return;
    
    // Get the phrase data from the phrases value
    if (phraseIndex < this.phrasesValue.length) {
      const phrase = this.phrasesValue[phraseIndex];
      
      // Convert timestamp to seconds
      const startSeconds = this.timestampToSeconds(phrase.timestamp);
      const endSeconds = phrase.calculated_end_timestamp ? 
        this.timestampToSeconds(phrase.calculated_end_timestamp) : 
        startSeconds + 5;
      
      // Update the play button's data attributes
      playButton.setAttribute('data-main-video-player-segment-start-param', startSeconds);
      playButton.setAttribute('data-main-video-player-segment-end-param', endSeconds);
    }
  }

  timestampToSeconds(timestamp) {
    if (typeof timestamp === 'number') return timestamp;
    
    // Handle MM:SS format
    const parts = timestamp.split(':');
    if (parts.length === 2) {
      return parseInt(parts[0]) * 60 + parseInt(parts[1]);
    }
    
    // Handle HH:MM:SS format  
    if (parts.length === 3) {
      return parseInt(parts[0]) * 3600 + parseInt(parts[1]) * 60 + parseInt(parts[2]);
    }
    
    return 0;
  }
}

