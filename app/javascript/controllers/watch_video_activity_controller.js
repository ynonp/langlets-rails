import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini";

export default class extends Controller {
  static targets = ['subtitles', 'container', 'phrasesList', 'translation', 'showTranslation', 'startActivityButton', 'completionMessage'];
  static classes = ['currentTextLine'];

  progress(ev) {
    const {at} = ev.detail
    this.updateSubtitles(at);
  }

  handleVideoStart() {  
    if (this.completionMessageTarget.classList.contains('hidden')) {
      this.startActivityButtonTarget.classList.remove('hidden');
    }    
  }

  handleVideoPause() {
    this.startActivityButtonTarget.classList.add('hidden');
  }

  handleVideoEnd() {
    if (this.completionMessageTarget.classList.contains('hidden')) {
      // Play completion sound
      this.element.dispatchEvent(new CustomEvent('audio:complete', { bubbles: true }));
      
      // Award XP for watching video (10 XP for single-stage activity)
      this.awardXp(10);
      
      this.completionMessageTarget.classList.remove('hidden');
      this.startActivityButtonTarget.classList.add('hidden');
      animate(this.completionMessageTarget, 
        { opacity: [0, 1], scale: [0.8, 1] }, 
        { duration: 0.3, easing: 'easeOut' }
      );
      this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
    }
  }

  toggleTranslation() {
    const showTranslations = this.showTranslationTarget.checked;
    this.translationTargets.forEach(translation => {
      if (showTranslations) {
        translation.classList.remove('hidden');
      } else {
        translation.classList.add('hidden');
      }
    });
  }

  updateSubtitles(currentTime) {
    const subtitlesLines = this.subtitlesTargets;
    const index = subtitlesLines.map(item => Number(item.dataset.timestamp)).findLastIndex(t => t < currentTime);

    if (index !== -1) {
      subtitlesLines[index].classList.add(this.currentTextLineClass);
      
      // Emit event when a phrase becomes active
      const event = new CustomEvent('video-player:phrase-activated', {
        detail: { phraseElement: subtitlesLines[index] }
      });
      this.element.dispatchEvent(event);
      
      const container = this.containerTarget;
      const lineHeight = subtitlesLines[index].offsetHeight;
      
      const containerTop = container.offsetTop;
      const targetScrollTop = subtitlesLines[index].offsetTop - lineHeight - containerTop;
  
      container.scrollTo({
        top: targetScrollTop,
        behavior: 'smooth'
      });          
    }

    for (let i=0; i < subtitlesLines.length; i++) {
      if (i !== index) {
        subtitlesLines[i].classList.remove(this.currentTextLineClass);
      }
    }
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
}