import { Controller } from "@hotwired/stimulus"
import YouTubePlayer from 'youtube-player';

export default class extends Controller {
  static values = {
    segmentStart: Number,
    segmentEnd: Number,
    miniPlayer: Boolean,
    videoId: String,
  }
  static targets = ['player', 'playButton', 'progressBar', 'subtitles', 'container', 'phrasesList'];
  static classes = ['currentTextLine'];

  initialize() {
    this.player = YouTubePlayer(this.playerTarget, {
      videoId: this.videoIdValue,
      playerVars: {
        autoplay: 0,
        controls: 0,
        start: this.segmentStartValue,
        modestbranding: 1,
      },
    });
    this.monitorPlaybackInterval = null;
  }

  connect() {
    // Setup event listeners for communication with listen activity controller
    this.element.addEventListener('listen-activity:pause-video', this.handlePauseVideo.bind(this));
    this.element.addEventListener('listen-activity:play-video', this.handlePlayVideo.bind(this));
    
    this.player.on('stateChange', (event) => {
      if (event.data === YT.PlayerState.PAUSED || event.data === YT.PlayerState.ENDED) {
        this.showPlayButton();
        clearInterval(this.monitorPlaybackInterval);
      } else if (event.data === YT.PlayerState.PLAYING) {

        this.monitorPlaybackInterval = setInterval(async () => {
          const currentTime = await this.player.getCurrentTime();

          this.updateSubtitles(currentTime);
          this.updateProgressBar(currentTime);
          this.checkIfVideoEnded(currentTime);
        }, 100);
        this.hidePlayButton();
      }
    });
  }
  
  // Handler for the pause video event
  handlePauseVideo() {
    this.player.pauseVideo();
  }
  
  // Handler for the play video event
  handlePlayVideo() {
    this.player.playVideo();
  }

  async togglePlayback() {
    const {player, segmentStartValue} = this;

    const state = await player.getPlayerState();
    if (state === YT.PlayerState.PLAYING) {
      player.pauseVideo();
      this.showPlayButton();
    } else {
      player.seekTo(segmentStartValue);
      player.playVideo();
      this.hidePlayButton();
    }
  }

  videoIdValueChanged() {
    this.player.cueVideoById(this.videoIdValue);
  }

  showPlayButton() {
    if (this.miniPlayerValue) {
      this.playButtonTarget.textContent = '▶';
    } else {
      this.playButtonTarget.classList.remove('hidden');
    }
  }

  hidePlayButton() {
    if (this.miniPlayerValue) {
      this.playButtonTarget.textContent = '❚❚';
    } else {
      this.playButtonTarget.classList.add('hidden');
    }
  }

  checkIfVideoEnded(currentTime) {
    if (currentTime >= this.segmentEndValue + 3) {
      this.player.pauseVideo();
      this.showPlayButton();
    }
  }

  updateProgressBar(currentTime) {
    const segmentLength = this.segmentEndValue - this.segmentStartValue;
    const elapsed = Math.max(0, currentTime - this.segmentStartValue);
    const percentage = Math.min(100, (elapsed / segmentLength) * 100);
    this.progressBarTarget.style.width = `${percentage}%`;
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
  
  disconnect() {
    // Clean up event listeners
    this.element.removeEventListener('listen-activity:pause-video', this.handlePauseVideo);
    this.element.removeEventListener('listen-activity:play-video', this.handlePlayVideo);
    
    if (this.monitorPlaybackInterval) {
      clearInterval(this.monitorPlaybackInterval);
    }
  }
}

