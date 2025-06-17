import { Controller } from "@hotwired/stimulus"
import YouTubePlayer from 'youtube-player';
import { animate } from "motion/mini";

export default class extends Controller {
  static values = {
    segmentStart: Number,
    segmentEnd: Number,
    miniPlayer: Boolean,
    videoId: String,
  }
  static targets = ['player', 'playButton', 'progressBar', 'progressBarContainer', 'subtitles', 'container', 'phrasesList', 'translation', 'showTranslation', 'startActivityButton', 'playVideoButton', 'thumbnail', 'completionMessage'];
  static classes = ['currentTextLine'];

  initialize() {
    this.player = null;
    this.playerInitialized = false;
    this.monitorPlaybackInterval = null;
  }

  connect() {
    // Setup event listeners for communication with listen activity controller
    this.element.addEventListener('listen-activity:pause-video', this.handlePauseVideo.bind(this));
    this.element.addEventListener('listen-activity:play-video', this.handlePlayVideo.bind(this));
  }

  initializePlayer() {
    if (this.playerInitialized) return;
    
    // Hide the thumbnail when initializing the player
    if (this.hasThumbnailTarget) {
      this.thumbnailTarget.style.display = 'none';
    }
    
    this.player = YouTubePlayer(this.playerTarget, {
      videoId: this.videoIdValue,
      playerVars: {
        autoplay: 1,
        controls: 0,
        start: this.segmentStartValue,
        modestbranding: 1,
      },
    });
    
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
    
    this.playerInitialized = true;
  }
  
  // Handler for the pause video event
  handlePauseVideo() {
    if (this.player) {
      this.player.pauseVideo();
    }
  }
  
  // Handler for the play video event
  async handlePlayVideo() {
    if (!this.player) return;
    
    const currentTime = await this.player.getCurrentTime();
    if (!currentTime || currentTime < this.segmentStartValue || currentTime >= this.segmentEndValue) {
      this.player.seekTo(this.segmentStartValue);
    }
    this.player.playVideo();
  }

  async togglePlayback() {
    const {segmentStartValue} = this;
    
    // Initialize player on first interaction
    if (!this.playerInitialized) {
      this.initializePlayer();
    }
    
    if (this.hasStartActivityButtonTarget) {
      if (this.hasCompletionMessageTarget) {
        if (this.completionMessageTarget.classList.contains('hidden')) {
          this.startActivityButtonTarget.classList.remove('hidden');  
        }
      } else {
        this.startActivityButtonTarget.classList.remove('hidden');  
      }      
    }

    if (this.hasPlayVideoButtonTarget) {
      this.playVideoButtonTarget.classList.add('hidden');
    }

    const state = await this.player.getPlayerState();
    if (state === YT.PlayerState.PLAYING) {
      this.player.pauseVideo();
      this.showPlayButton();
    } else {
      // Only seek to segment start if video hasn't started yet or is before the segment
      const currentTime = await this.player.getCurrentTime();
      if (currentTime < segmentStartValue || currentTime >= this.segmentEndValue) {
        this.player.seekTo(segmentStartValue);
      }
      this.player.playVideo();
      this.hidePlayButton();
    }
  }

  videoIdValueChanged() {
    if (this.player) {
      this.player.cueVideoById(this.videoIdValue);
    }
  }

  showPlayButton() {
    if (!this.hasPlayButtonTarget) {
      return;
    }

    if (this.miniPlayerValue) {
      this.playButtonTarget.textContent = '▶';
    } else {
      this.playButtonTarget.classList.remove('hidden');
    }
  }

  hidePlayButton() {
    if (!this.hasPlayButtonTarget) {
      return;
    }

    if (this.miniPlayerValue) {
      this.playButtonTarget.textContent = '❚❚';
    } else {
      this.playButtonTarget.classList.add('hidden');
    }
  }

  checkIfVideoEnded(currentTime) {
    if (currentTime >= this.segmentEndValue) {
      this.player.pauseVideo();
      this.showPlayButton();
      if (this.hasCompletionMessageTarget && this.completionMessageTarget.classList.contains('hidden')) {
        this.completionMessageTarget.classList.remove('hidden');
        animate(this.completionMessageTarget, 
          { opacity: [0, 1], scale: [0.8, 1] }, 
          { duration: 0.3, easing: 'easeOut' }
        );
        this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))

      }
      if (this.hasStartActivityButtonTarget) {
        this.startActivityButtonTarget.classList.add('hidden');
      }
    }
  }

  updateProgressBar(currentTime) {
    if (!this.hasProgressBarTarget) {
      return;
    }    

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

  seekToTimestamp(ev) {
    if (this.player) {
      const targetTime = ev.currentTarget.dataset.timestamp
      this.player.seekTo(targetTime);
    }
  }

  async seekToPosition(event) {
    if (!this.player) return;
    
    // Prevent the event from bubbling up to the YouTube player
    event.preventDefault();
    event.stopPropagation();
    
    const progressBarContainer = event.currentTarget;
    const rect = progressBarContainer.getBoundingClientRect();
    const clickX = event.clientX - rect.left;
    const containerWidth = rect.width;
    
    // Calculate the percentage of the click position
    const clickPercentage = Math.max(0, Math.min(100, (clickX / containerWidth) * 100));
    
    // Calculate the target time within the segment
    const segmentLength = this.segmentEndValue - this.segmentStartValue;
    const targetTime = this.segmentStartValue + (clickPercentage / 100) * segmentLength;
    
    // Seek to the calculated time
    await this.player.seekTo(targetTime);
    this.updateProgressBar();
    this.updateSubtitles();
  }
}

