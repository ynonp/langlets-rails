import { Controller } from "@hotwired/stimulus"
import YouTubePlayer from 'youtube-player';

export default class extends Controller {
  static values = {
    segmentStart: Number,
    segmentEnd: Number,
    miniPlayer: Boolean,
    videoId: String,
  }
  static targets = ['player', 'playButton', 'progressBar', 'subtitles'];
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

    const subtitlesLines = this.subtitlesTargets;
    for (let i=0; i < subtitlesLines.length; i++) {
      subtitlesLines[i].classList.remove(this.currentTextLineClass);
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
    if (currentTime >= this.segmentEndValue) {
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
    }

    for (let i=0; i < subtitlesLines.length; i++) {
      if (i !== index) {
        subtitlesLines[i].classList.remove(this.currentTextLineClass);
      }
    }
  }
}

