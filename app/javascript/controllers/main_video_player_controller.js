import { Controller } from "@hotwired/stimulus"
import YouTubePlayer from 'youtube-player';

export default class extends Controller {
  static targets = ['player', 'progressBar', 'playButton', 'pauseButton'];

  static values = {
    videoId: String,
  }

  disconnect() {
    this.stopPlaybackMonitoring();
    if (this.player) {
      this.player.destroy();
    }
  }

  initialize() {
    this.monitorPlaybackInterval = null;
    this.player = null;
    this.playerInitialized = false;
  }

  initializePlayer() {
    if (this.playerInitialized) return;
    
    this.player = YouTubePlayer(this.playerTarget, {
      videoId: this.videoIdValue,
      playerVars: {
        autoplay: 1,
        controls: 0,
        modestbranding: 1,
      },
    });   

    this.player.on('stateChange', (event) => {
      if (event.data === YT.PlayerState.PAUSED || event.data === YT.PlayerState.ENDED) {
        this.showPlayButton();
        this.stopPlaybackMonitoring();
      } else if (event.data === YT.PlayerState.PLAYING) {
        this.hidePlayButton();
        this.startPlaybackMonitoring();
      }
    });
    
    this.playerInitialized = true;
  }

  showPlayButton() {
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.classList.remove('hidden');
    }
    if (this.hasPauseButtonTarget) {
      this.pauseButtonTarget.classList.add('hidden');
    }
  }

  hidePlayButton() {
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.classList.add('hidden');
    }
    if (this.hasPauseButtonTarget) {
      this.pauseButtonTarget.classList.remove('hidden');
    }
  }

  async stopPlayback() {
    if (this.player) {
      this.player.pauseVideo();
    }
  }  

  async playSegment(event) {    
    // Initialize player on first playSegment call
    if (!this.playerInitialized) {
      this.initializePlayer();
    }
    
    const {segmentStart, segmentEnd} = event.params;
    this.segmentStart = segmentStart;
    this.segmentEnd = segmentEnd;
    await this.player.seekTo(segmentStart)
    this.player.playVideo()
    if (this.monitorPlaybackInterval) {
      clearInterval(this.monitorPlaybackInterval)
    }
  }

  startPlaybackMonitoring() {
    this.monitorPlaybackInterval = setInterval(async () => {
      const at = await this.player.getCurrentTime();
      if (at >= this.segmentEnd) {
        this.player.pauseVideo();
      }
      this.updateProgressBar(at, this.segmentStart, this.segmentEnd);
    }, 100);
  }

  stopPlaybackMonitoring() {
    if (this.monitorPlaybackInterval) {
      clearInterval(this.monitorPlaybackInterval);
      this.monitorPlaybackInterval = null;
    }
  }

  updateProgressBar(currentTime, segmentStart, segmentEnd) {
    if (!this.hasProgressBarTarget) {
      return;
    }    
    // console.log(currentTime, segmentStart, segmentEnd);

    const segmentLength = segmentEnd - segmentStart;
    console.log(segmentLength);
    const elapsed = Math.max(0, currentTime - segmentStart);
    const percentage = Math.min(100, (elapsed / segmentLength) * 100);
    console.log(percentage);
    this.progressBarTarget.style.width = `${percentage}%`;
  }
}
