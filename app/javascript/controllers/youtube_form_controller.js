import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["urlField", "nameField", "slugField"]
  
  connect() {
    console.log("YouTube form controller connected")
  }

  urlChanged() {
    const url = this.urlFieldTarget.value.trim()
    
    if (this.isValidYouTubeUrl(url)) {
      this.extractVideoDetails(url)
    }
  }

  isValidYouTubeUrl(url) {
    const youtubeRegex = /^(https?:\/\/)?(www\.)?(youtube\.com\/(watch\?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/
    return youtubeRegex.test(url)
  }

  extractVideoId(url) {
    const match = url.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/)
    return match ? match[1] : null
  }

  extractVideoDetails(url) {
    const videoId = this.extractVideoId(url)
    
    if (!videoId) {
      console.error("Could not extract video ID from URL")
      return
    }

    // Use oEmbed API to get video details
    const oembedUrl = `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`
    
    fetch(oembedUrl)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        return response.json()
      })
      .then(data => {
        this.populateFields(data, videoId)
      })
      .catch(error => {
        console.error("Error fetching video details:", error)
        // Still populate the slug with video ID even if title fetch fails
        this.populateSlug(videoId)
      })
  }

  populateFields(videoData, videoId) {
    // Populate course name with video title (only if field is empty)
    if (this.nameFieldTarget.value.trim() === "") {
      this.nameFieldTarget.value = videoData.title
    }

    // Populate slug with video ID
    this.populateSlug(videoId)
  }

  populateSlug(videoId) {
    // Only populate slug if it's empty
    if (this.slugFieldTarget.value.trim() === "") {
      this.slugFieldTarget.value = videoId
    }
  }
}
