import { Controller } from "@hotwired/stimulus"
import YoutubeAdapter from "../players/youtube_adapter";
import TiktokAdapter from "../players/tiktok_adapter";
import { PlayerState } from "../players/player_states";

// One controller, one event contract, two playback engines. Everything below
// the adapter boundary (segments, video:* events, the 100ms monitor, the
// scrubber) is provider-agnostic and shared by all four player layouts — see
// docs/video-player.md. Adding a provider means adding an adapter, not touching
// this file.
const ADAPTERS = {
  youtube: YoutubeAdapter,
  tiktok: TiktokAdapter,
};

export default class extends Controller {
  static targets = ['playerContainer', 'media', 'player', 'progressBar', 'videoListener', 'videoSegment'];

  static values = {
    videoId: String,
    hl: String,
    preloadPlayer: Boolean,
    interactive: Boolean,
    // Defaults to youtube so any view that hasn't been given the value — and
    // every course imported before TikTok support — behaves exactly as before.
    provider: { type: String, default: 'youtube' },
  }

  connect() {
    this.initialize();
    this.initializeSegmentBounds();
    // Preload player if requested by activity
    if (this.hasPreloadPlayerValue && this.preloadPlayerValue) {
      this.initializePlayer();
    }
  }

  // Seeds the segment bounds the playback monitor compares against. Without
  // this the monitor would run with segmentEnd == null and end every segment on
  // its first tick.
  initializeSegmentBounds() {
    if (!this.hasVideoSegmentTarget) return;
    const start = Number(this.videoSegmentTarget.dataset.segmentStart);
    const end = Number(this.videoSegmentTarget.dataset.segmentEnd);
    if (Number.isFinite(start) && Number.isFinite(end)) {
      this.segmentStart = start;
      this.segmentEnd = end;
    }
  }

  disconnect() {
    this.stopPlaybackMonitoring();
    if (this.player) {
      // Defer player teardown so it doesn't block Turbo navigation. destroy()
      // is synchronous and slow on mobile (video decoder teardown, postMessage
      // bridge cleanup, memory release).
      const player = this.player;
      this.player = null;
      this.playerInitialized = false;
      this.hasPlayed = false;
      setTimeout(() => player.destroy(), 0);
    }
  }

  handleBeforeRender() {
    this.stopPlaybackMonitoring();
    if (this.player) {
      this.player.pauseVideo();
    }
    this.playerContainerTarget.classList.add('hidden');
    this.segmentStart = null;
    this.segmentEnd = null;
  }

  handleFrameRender() {
    if (!this.hasVideoSegmentTarget) return;

    const segmentStart = Number(this.videoSegmentTarget.dataset.segmentStart);
    const segmentEnd = Number(this.videoSegmentTarget.dataset.segmentEnd);
    this.segmentStart = Number.isFinite(segmentStart) ? segmentStart : null;
    this.segmentEnd = Number.isFinite(segmentEnd) ? segmentEnd : null;

    if (this.videoSegmentTarget.dataset.showPlayer) {
      this.playerContainerTarget.classList.remove('hidden');
      this.playerContainerTarget.classList.add('order-2');

      // preloadPlayerValue/interactiveValue are baked into this element once,
      // from whichever activity the page happened to load on. A Turbo-Frame
      // navigation into a later activity that wants the player (e.g. from a
      // non-video activity that preceded it) never re-runs connect(), so
      // without this the iframe would stay uncreated until a full reload.
      if (!this.playerInitialized) {
        this.interactiveValue = true;
        this.initializePlayer();
      }

      // Only reposition a player that has actually played. Seeking a player
      // that has never played knocks YouTube back to UNSTARTED and clears its
      // poster and play button, leaving a dead black rectangle — a player that
      // has never played is already cued and needs no repositioning.
      //
      // This must key off playback, not off `justCreated`: when the lesson
      // opens directly on the watch-video activity, `preloadPlayer` makes
      // connect() build the iframe, so navigating to another activity and back
      // returns here with the player already initialized but never played.
      // `video:play -> seekToSegmentStartIfBefore` positions it on first play.
      if (this.player && this.hasPlayed) {
        if (this.segmentStart != null) {
          this.player.seekTo(this.segmentStart);
        }
        this.player.pauseVideo();
      }
    }
  }

  initialize() {
    this.monitorPlaybackInterval = null;
    this.player = null;
    this.playerInitialized = false;
    // Whether the current player has ever entered PLAYING. Guards the seeks
    // that would knock a never-played YouTube player back to UNSTARTED.
    this.hasPlayed = false;
    this.stopPlayback = this.stopPlayback.bind(this);
  }

  setMediaRatio(event) {
    const { videoWidth, videoHeight } = event.target;
    if (!videoWidth || !videoHeight) return;

    if (this.hasMediaTarget) {
      this.mediaTarget.dataset.ratio = videoWidth / videoHeight >= 1 ? "landscape" : "portrait";
    }
  }

  initializePlayer() {
    if (this.playerInitialized) return;

    const Adapter = ADAPTERS[this.providerValue] || ADAPTERS.youtube;

    this.player = new Adapter(this.playerTarget, {
      videoId: this.videoIdValue,
      hl: this.hlValue,
      controls: this.interactiveValue,
    });

    // Adapters normalize to PlayerState, so this reads the same for every
    // provider and keeps dispatching the video:* contract activities rely on.
    this.player.onStateChange((state) => {
      if (state === PlayerState.PAUSED || state === PlayerState.ENDED) {
        this.stopPlaybackMonitoring();
        this.dispatchVideoEvent('stop');
      } else if (state === PlayerState.PLAYING) {
        this.hasPlayed = true;
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

  async seekToSegmentStartIfBefore(event) {
    if (!this.player) return;

    const segmentStart = Number(event.currentTarget.dataset.segmentStart);
    if (!Number.isFinite(segmentStart)) return;

    const currentTime = await this.player.getCurrentTime();
    if (currentTime < segmentStart) {
      await this.player.seekTo(segmentStart);
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
      if (!Number.isFinite(this.segmentStart) || !Number.isFinite(this.segmentEnd)) return;

      const at = await this.player.getCurrentTime();
      if (!Number.isFinite(this.segmentStart) || !Number.isFinite(this.segmentEnd)) return;

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
  }

  seekToTimestamp(ev) {
    if (!this.player) return;
    // Translation-token clicks belong to the popup interaction. Seeking here
    // would move the video just before watch-video pauses it, which makes
    // checking a word's meaning unexpectedly change the learner's position.
    if (ev.target.closest('[data-translation]')) return;

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
