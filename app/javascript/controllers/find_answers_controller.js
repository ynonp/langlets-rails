import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"
import { reportActivityProgress } from "../utils/activity_progress"

// Connects to data-controller="language-alignment-activity.js"
export default class extends Controller {
  static targets = ['activityContent', 'question', 'completionMessage'];
  static values = {
    questions: Array,
    currentQuestion: Number,
  };

  initialize() {
    this.checkAnswer = this.checkAnswer.bind(this);
  }

  checkAnswer(ev) {
    const token = ev.target;
    if (Number(token.dataset.tokenId) === this.questionsValue[this.currentQuestionValue].answer_token_id) {
      token.dataset.found = true;
      token.classList.add('bg-green-400', 'text-gray-900', 'px-1', 'rounded')
      
      // Award XP for correct answer (3 XP per correct answer)
      this.awardXp(3);
      
      this.nextQuestion();
      this.updateProgress();
    }
  }

  nextQuestion() {
    this.currentQuestionValue++;
  }

  currentQuestionValueChanged() {
    if (this.currentQuestionValue < this.questionsValue.length) {
      this.questionTarget.textContent = this.questionsValue[this.currentQuestionValue].question;
      this.questionTarget.dataset.answer = this.questionsValue[this.currentQuestionValue].answer_token_id;
    }
  }

  updateProgress() {
    reportActivityProgress(this.element, this.currentQuestionValue / this.questionsValue.length);

    if (this.currentQuestionValue === this.questionsValue.length) {
      this.activityContentTarget.classList.add('hidden');
      this.completionMessageTarget.classList.remove('hidden');
      animate(this.completionMessageTarget, 
        { opacity: [0, 1], scale: [0.8, 1] }, 
        { duration: 0.3, easing: 'easeOut' }
      );
      this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
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

