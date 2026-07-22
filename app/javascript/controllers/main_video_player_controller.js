import { Controller } from "@hotwired/stimulus"
import YouTubePlayer from 'youtube-player';

export default class extends Controller {
  static targets = ['playerContainer', 'player', 'progressBar', 'playButton', 'pauseButton', 'videoListener', 'videoSegment', 'timeElapsed', 'timeDuration'];

  static values = {
    videoId: String,
    hl: String,
    preloadPlayer: Boolean,
    interactive: Boolean,
  }

  connect() {
    this.initialize();
    this.initializeTimeDisplay();
    // Preload player if requested by activity
    if (this.hasPreloadPlayerValue && this.preloadPlayerValue) {
      this.initializePlayer();
    }
  }

  initializeTimeDisplay() {
    if (!this.hasVideoSegmentTarget) return;
    const start = Number(this.videoSegmentTarget.dataset.segmentStart);
    const end = Number(this.videoSegmentTarget.dataset.segmentEnd);
    if (Number.isFinite(start) && Number.isFinite(end)) {
      this.segmentStart = start;
      this.segmentEnd = end;
      this.updateTimeDisplay(0, end - start);
    }
  }

  disconnect() {
    this.stopPlaybackMonitoring();
    if (this.player) {
      // Defer YouTube API cleanup so it doesn't block Turbo navigation.
      // YT.Player.destroy() is synchronous and slow on mobile (video decoder
      // teardown, postMessage bridge cleanup, memory release).
      const player = this.player;
      this.player = null;
      setTimeout(() => player.destroy(), 0);
    }
  }

  handleBeforeRender() {
    this.playerContainerTarget.classList.add('hidden');
    this.segmentStart = null;
    this.segmentEnd = null;    
  }

  handleFrameRender() {
    if (this.hasVideoSegmentTarget && this.videoSegmentTarget.dataset.showPlayer) {      
      this.playerContainerTarget.classList.remove('hidden');
      this.playerContainerTarget.classList.add('order-2', 'px-4');
      if (this.player) {
        this.player.seekTo(this.videoSegmentTarget.dataset.segmentStart);
        this.player.pauseVideo();
      }
    }
  }

  initialize() {
    this.monitorPlaybackInterval = null;
    this.player = null;
    this.playerInitialized = false;    
    this.stopPlayback = this.stopPlayback.bind(this);
  }

  initializePlayer() {
    if (this.playerInitialized) return;

    this.player = YouTubePlayer(this.playerTarget, {
      videoId: this.videoIdValue,
      playerVars: {
        autoplay: 0,
        playsinline: 1,
        controls: this.interactiveValue ? 1 : 0,
        modestbranding: 1,
        rel: 0,
        hl: this.hlValue,
      },
    });

    this.player.on('stateChange', (event) => {
      if (event.data === YT.PlayerState.PAUSED || event.data === YT.PlayerState.ENDED) {
        this.stopPlaybackMonitoring();
        this.dispatchVideoEvent('stop');
      } else if (event.data === YT.PlayerState.PLAYING) {
        this.startPlaybackMonitoring();
        this.dispatchVideoEvent('play');
      }
    });

    this.playerInitialized = true;
  }

  dispatchVideoEvent(eventName, detail = {}) {
    const e = new CustomEvent(`video:${eventName}`, { detail });
    this.videoListenerTargets.forEach((el) => {
      el.dispatchEvent(e);
    })
  }

  fullPlayerStartPlayback() {    
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.classList.add('hidden');
    }
  }

  async seekToSegmentStartIfBefore(event) {
    if (!this.player) return;

    const segmentStart = Number(event.currentTarget.dataset.segmentStart);
    if (!Number.isFinite(segmentStart)) return;

    const currentTime = await this.player.getCurrentTime();
    if (currentTime < segmentStart) {
      await this.player.seekTo(segmentStart);
    }
  }

  fullPlayerStopPlayback() {
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.classList.remove('hidden');
    }
  }

  async togglePlayPause(ev) {    
    if (!this.player) {
      this.playSegment(ev);
      return;
    }
    const state = await this.player.getPlayerState();
    if (state === 1) {
      // playing
      await this.stopPlayback();
    } else {
      await this.playSegment(ev);
    }
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

  async resume() {
    if ((this.segmentEnd != null) && (this.segmentStart != null)) {      
      const at = await this.player.getCurrentTime();
      if (at <= this.segmentEnd) {
        this.player.playVideo();
      }      
    }
  }

  async playSegment(event) {
    // Initialize player on first playSegment call
    if (!this.playerInitialized) {
      this.initializePlayer();
    }

    let segmentStart = null, segmentEnd = null, restartSegment = true;
    
    if ((event.params.segmentStart != null) && (event.params.segmentEnd != null)) {      
      segmentStart = Number(event.params.segmentStart);
      segmentEnd = Number(event.params.segmentEnd);
    } else {
      segmentStart = Number(this.videoSegmentTarget.dataset.segmentStart);
      segmentEnd = Number(this.videoSegmentTarget.dataset.segmentEnd);
    }

    if (segmentEnd === this.segmentEnd && segmentStart === this.segmentStart && this.segmentStart != null) {
      const at = await this.player.getCurrentTime();
      if ((at < segmentEnd) && (at > segmentStart)) {
        restartSegment = false;
      }
    }

    this.segmentStart = segmentStart;
    this.segmentEnd = segmentEnd;

    if (restartSegment) {
      await this.player.seekTo(this.segmentStart)
    }
    
    this.player.playVideo()

    if (this.monitorPlaybackInterval) {
      clearInterval(this.monitorPlaybackInterval)
    }
  }

  startPlaybackMonitoring() {
    if (this.monitorPlaybackInterval) {
      clearInterval(this.monitorPlaybackInterval);
      this.monitorPlaybackInterval = null;
    }

    this.monitorPlaybackInterval = setInterval(async () => {
      const at = await this.player.getCurrentTime();
      if (at >= this.segmentEnd) {
        this.stopPlaybackMonitoring();
        this.dispatchVideoEvent('end');
        await this.player.pauseVideo();
        await this.player.seekTo(this.segmentStart);
        this.dispatchVideoEvent('progress', { at: this.segmentStart });
        this.updateProgressBar(this.segmentStart, this.segmentStart, this.segmentEnd);
        return;
      }
      this.dispatchVideoEvent('progress', { at })
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
    const segmentLength = segmentEnd - segmentStart;
    const elapsed = Math.max(0, currentTime - segmentStart);
    const percentage = Math.min(100, (elapsed / segmentLength) * 100);

    this.progressBarTargets.forEach((el) => {
      el.style.width = `${percentage}%`;
    })

    this.updateTimeDisplay(elapsed, segmentLength);
  }

  updateTimeDisplay(elapsed, segmentLength) {
    if (this.hasTimeElapsedTarget) {
      this.timeElapsedTargets.forEach((el) => {
        el.textContent = this.formatTime(Math.min(elapsed, segmentLength));
      });
    }
    if (this.hasTimeDurationTarget) {
      this.timeDurationTargets.forEach((el) => {
        el.textContent = this.formatTime(segmentLength);
      });
    }
  }

  formatTime(seconds) {
    const total = Math.max(0, Math.floor(seconds || 0));
    const mins = Math.floor(total / 60);
    const secs = total % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }


  seekToTimestamp(ev) {
    if (!this.player) return;
    // Delegated: the action lives on the phrases container, so resolve the
    // clicked phrase (or any ancestor carrying a timestamp).
    const el = ev.target.closest('[data-timestamp]');
    if (!el) return;
    this.player.seekTo(el.dataset.timestamp);
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
    const segmentLength = this.segmentEnd - this.segmentStart;
    const targetTime = this.segmentStart + (clickPercentage / 100) * segmentLength;

    // Seek to the calculated time
    await this.player.seekTo(targetTime);
    this.updateProgressBar(targetTime, this.segmentStart, this.segmentEnd);
    this.dispatchVideoEvent('progress', { at: targetTime })
  }
}
