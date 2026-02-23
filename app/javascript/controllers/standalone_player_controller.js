import { Controller } from "@hotwired/stimulus"
import YouTubePlayer from 'youtube-player';

// YouTube Player State constants as fallback
const PLAYER_STATE = {
  PAUSED: 2,
  ENDED: 0,
  PLAYING: 1
};

export default class extends Controller {
  static targets = ['player', 'progressBar', 'progressBarContainer', 'playButton', 
                    'lyricsTab', 'vocabularyTab', 'lyricsContent', 'vocabularyContent'];

  static values = {
    videoId: String,
  }

  connect() {
    this.player = null;
    this.playerInitialized = false;
    this.monitorPlaybackInterval = null;
    this.videoDuration = 0;
  }

  disconnect() {
    this.stopPlaybackMonitoring();
    if (this.player) {
      this.player.destroy();
    }
  }

  initializePlayer() {
    if (this.playerInitialized) return;

    this.player = YouTubePlayer(this.playerTarget, {
      videoId: this.videoIdValue,
      playerVars: {
        autoplay: 0,
        controls: 0,
        modestbranding: 1,
        rel: 0,
      },
    });

    this.player.on('stateChange', async (event) => {
      const paused = typeof YT !== 'undefined' ? YT.PlayerState.PAUSED : PLAYER_STATE.PAUSED;
      const ended = typeof YT !== 'undefined' ? YT.PlayerState.ENDED : PLAYER_STATE.ENDED;
      const playing = typeof YT !== 'undefined' ? YT.PlayerState.PLAYING : PLAYER_STATE.PLAYING;

      if (event.data === paused || event.data === ended) {
        this.stopPlaybackMonitoring();
        this.showPlayButton();
      } else if (event.data === playing) {
        this.videoDuration = await this.player.getDuration();
        this.startPlaybackMonitoring();
        this.hidePlayButton();
      }
    });

    this.playerInitialized = true;
  }

  async togglePlayPause() {
    if (!this.player) {
      this.initializePlayer();
      this.player.playVideo();
      return;
    }

    const state = await this.player.getPlayerState();
    if (state === 1) {
      this.player.pauseVideo();
    } else {
      this.player.playVideo();
    }
  }

  showPlayButton() {
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.classList.remove('hidden');
    }
  }

  hidePlayButton() {
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.classList.add('hidden');
    }
  }

  startPlaybackMonitoring() {
    if (this.monitorPlaybackInterval) {
      clearInterval(this.monitorPlaybackInterval);
    }

    this.monitorPlaybackInterval = setInterval(async () => {
      const currentTime = await this.player.getCurrentTime();
      this.updateProgressBar(currentTime);
    }, 250);
  }

  stopPlaybackMonitoring() {
    if (this.monitorPlaybackInterval) {
      clearInterval(this.monitorPlaybackInterval);
      this.monitorPlaybackInterval = null;
    }
  }

  updateProgressBar(currentTime) {
    if (this.videoDuration > 0) {
      const percentage = (currentTime / this.videoDuration) * 100;
      this.progressBarTarget.style.width = `${percentage}%`;
    }
  }

  async seekToPosition(event) {
    if (!this.player) {
      this.initializePlayer();
    }

    event.preventDefault();
    event.stopPropagation();

    const rect = this.progressBarContainerTarget.getBoundingClientRect();
    const clickX = event.clientX - rect.left;
    const containerWidth = rect.width;
    const clickPercentage = Math.max(0, Math.min(100, (clickX / containerWidth) * 100));
    
    if (this.videoDuration > 0) {
      const targetTime = (clickPercentage / 100) * this.videoDuration;
      await this.player.seekTo(targetTime);
    }
  }

  async seekToTimestamp(event) {
    if (!this.player) {
      this.initializePlayer();
    }

    const timestamp = parseFloat(event.currentTarget.dataset.timestamp);
    if (!isNaN(timestamp)) {
      await this.player.seekTo(timestamp);
      this.player.playVideo();
    }
  }

  // Tab switching
  showLyrics() {
    this.lyricsTabTarget.classList.add('border-blue-500', 'text-white');
    this.lyricsTabTarget.classList.remove('border-transparent', 'text-gray-400');
    
    this.vocabularyTabTarget.classList.remove('border-blue-500', 'text-white');
    this.vocabularyTabTarget.classList.add('border-transparent', 'text-gray-400');
    
    this.lyricsContentTarget.classList.remove('hidden');
    this.vocabularyContentTarget.classList.add('hidden');
  }

  showVocabulary() {
    this.vocabularyTabTarget.classList.add('border-blue-500', 'text-white');
    this.vocabularyTabTarget.classList.remove('border-transparent', 'text-gray-400');
    
    this.lyricsTabTarget.classList.remove('border-blue-500', 'text-white');
    this.lyricsTabTarget.classList.add('border-transparent', 'text-gray-400');
    
    this.vocabularyContentTarget.classList.remove('hidden');
    this.lyricsContentTarget.classList.add('hidden');
  }
}
