import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = {
    id: Number
  }

  connect() {
    this.channel = createConsumer().subscriptions.create(
      {
        channel: "CreateSongProgressChannel",
        id: this.idValue
      },
      {
        received: (data) => {
          this.updateProgress(data)
        }
      }
    )
  }

  disconnect() {
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  updateProgress(data) {
    // Update progress steps if provided
    if (data.progress_html) {
      const progressSteps = document.getElementById('progress-steps')
      if (progressSteps) {
        progressSteps.innerHTML = data.progress_html
      }
    }

    // Update content area if provided
    if (data.content_html) {
      const contentArea = document.getElementById('content-area')
      if (contentArea) {
        contentArea.innerHTML = data.content_html
      }
    }

    // Handle completion
    if (data.completed && data.course_url) {
      this.showCompletionMessage(data.course_url)
    }
  }

  showCompletionMessage(courseUrl) {
    // This could show a toast or modal, for now we'll just log
    console.log('Course creation completed!', courseUrl)
  }
}
