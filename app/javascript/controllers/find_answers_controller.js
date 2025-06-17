import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"

// Connects to data-controller="language-alignment-activity.js"
export default class extends Controller {
  static targets = ['question', 'progressBar', 'completionMessage'];
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
      this.nextQuestion();
      this.updateProgress();
    }
  }

  nextQuestion() {
    this.currentQuestionValue++;
  }

  currentQuestionValueChanged() {
    console.log(this.currentQuestionValue);
    if (this.currentQuestionValue < this.questionsValue.length) {
      this.questionTarget.textContent = this.questionsValue[this.currentQuestionValue].question;
      this.questionTarget.dataset.answer = this.questionsValue[this.currentQuestionValue].answer_token_id;
    }
  }

  updateProgress() {
    const percentage = (this.currentQuestionValue / this.questionsValue.length) * 100;
    this.progressBarTarget.style.width = `${percentage}%`;

    if (this.currentQuestionValue === this.questionsValue.length) {
      this.completionMessageTarget.classList.remove('hidden');
      animate(this.completionMessageTarget, 
        { opacity: [0, 1], scale: [0.8, 1] }, 
        { duration: 0.3, easing: 'easeOut' }
      );
      this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
    }
  }
}


