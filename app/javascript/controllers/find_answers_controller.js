import { Controller } from "@hotwired/stimulus"

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
      this.completionMessageTarget.classList.add('animate-fade-in');
    }
  }
}


