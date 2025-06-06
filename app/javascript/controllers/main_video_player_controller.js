import { Controller } from "@hotwired/stimulus"
import YouTubePlayer from 'youtube-player';

export default class extends Controller {
  static targets = ['player'];

  static values = {
    videoId: String,
  }

  initialize() {
    this.monitorPlaybackInterval = null;      
  }

  connect() {
    this.player = YouTubePlayer(this.playerTarget, {
      videoId: this.videoIdValue,
      playerVars: {
        autoplay: 0,
        controls: 0,
        modestbranding: 1,
      },
    });    
  }

  async stopPlayback() {
    console.log('stop');
    if (this.monitorPlaybackInterval) {
      clearInterval(this.monitorPlaybackInterval);
      this.monitorPlaybackInterval = null;
    }
    this.player.pauseVideo();
  }

  async playSegment(event) {
    console.log(event.params);
    const {segmentStart, segmentEnd} = event.params;
    await this.player.seekTo(segmentStart)
    this.player.playVideo()
    if (this.monitorPlaybackInterval) {
      clearInterval(this.monitorPlaybackInterval)
    }
    this.monitorPlaybackInterval = setInterval(async () => {
      const at = await this.player.getCurrentTime();
      if (at >= segmentEnd) {
        clearInterval(this.monitorPlaybackInterval);
        this.monitorPlaybackInterval = null;
        this.player.pauseVideo();
      }
    }, 1000);
  }
}
