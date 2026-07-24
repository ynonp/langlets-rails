import { PlayerState } from "./player_states";

// TikTok Embed Player, wrapped in the same contract as YoutubeAdapter so
// main-video-player never branches on provider.
// https://developers.tiktok.com/doc/embed-player
//
// Two differences from YouTube shape the whole file:
//
// 1. **There is no getCurrentTime().** The YouTube API answers a query; TikTok
//    only *pushes* `onCurrentTime` while playing. So this adapter keeps the last
//    reported position and answers from it. The controller polls every 100ms and
//    TikTok reports less often than that, which means the progress bar advances
//    in slightly coarser steps — but every segment boundary is still enforced,
//    because it's compared against the same clock.
//
// 2. **Commands are fire-and-forget postMessages** with no acknowledgement, and
//    anything sent before `onPlayerReady` is dropped on the floor. Commands are
//    therefore queued until ready and flushed in order.
const ORIGIN = "https://www.tiktok.com";
const MARKER = "x-tiktok-player";

export default class TiktokAdapter {
  static provider = "tiktok";

  constructor(element, { videoId, controls }) {
    this.ready = false;
    this.pending = [];
    this.stateCallbacks = [];
    this.currentTime = 0;
    this.duration = null;
    // Mirrors YouTube's initial state so getPlayerState() is answerable before
    // the iframe has said anything.
    this.state = PlayerState.UNSTARTED;

    this.iframe = document.createElement("iframe");
    this.iframe.src = this.buildSrc(videoId, controls);
    this.iframe.allow = "autoplay; fullscreen; encrypted-media; picture-in-picture";
    this.iframe.setAttribute("allowfullscreen", "");
    this.iframe.style.border = "0";
    this.iframe.title = "TikTok video player";

    this.handleMessage = this.handleMessage.bind(this);
    window.addEventListener("message", this.handleMessage);

    element.appendChild(this.iframe);
  }

  buildSrc(videoId, controls) {
    const params = new URLSearchParams({
      // The hidden audio-only player and the custom-chrome layouts pass
      // controls: false; the full player and watch-video activity pass true and
      // use TikTok's native chrome, exactly as they use YouTube's.
      controls: controls ? "1" : "0",
      progress_bar: controls ? "1" : "0",
      play_button: controls ? "1" : "0",
      volume_control: controls ? "1" : "0",
      fullscreen_button: controls ? "1" : "0",
      timestamp: controls ? "1" : "0",
      // Never autoplay: playback is always started by the app, from a user
      // gesture, so browser autoplay policy doesn't silently swallow it.
      autoplay: "0",
      loop: "0",
      // No "watch next" recommendations and no description/music chrome — this
      // is a lesson, not a feed.
      rel: "0",
      description: "0",
      music_info: "0",
      native_context_menu: "0",
    });
    return `${ORIGIN}/player/v1/${videoId}?${params}`;
  }

  handleMessage(event) {
    if (event.origin !== ORIGIN) return;
    const data = event.data;
    if (!data || data[MARKER] !== true) return;
    // Several players can be mounted on one page (mini buttons, hidden audio).
    // Without this check they'd all consume each other's events.
    if (this.iframe.contentWindow && event.source !== this.iframe.contentWindow) return;

    switch (data.type) {
      case "onPlayerReady":
        this.ready = true;
        this.flush();
        break;
      case "onStateChange":
        this.state = data.value;
        this.stateCallbacks.forEach((callback) => callback(data.value));
        break;
      case "onCurrentTime":
        if (data.value && Number.isFinite(data.value.currentTime)) {
          this.currentTime = data.value.currentTime;
          if (Number.isFinite(data.value.duration)) this.duration = data.value.duration;
        }
        break;
      case "onPlayerError":
        console.error("TikTok player error", data.value);
        break;
    }
  }

  send(type, value) {
    if (!this.ready) {
      this.pending.push([type, value]);
      return;
    }
    if (!this.iframe.contentWindow) return;
    this.iframe.contentWindow.postMessage({ type, value, [MARKER]: true }, ORIGIN);
  }

  flush() {
    const queued = this.pending;
    this.pending = [];
    queued.forEach(([type, value]) => this.send(type, value));
  }

  onStateChange(callback) {
    this.stateCallbacks.push(callback);
  }

  playVideo() {
    this.send("play");
  }

  pauseVideo() {
    this.send("pause");
  }

  seekTo(seconds) {
    const target = Number(seconds);
    if (!Number.isFinite(target)) return;
    // Answer getCurrentTime() from the target straight away rather than waiting
    // for the next onCurrentTime. The controller seeks and then immediately
    // compares the position against the segment bounds; reporting the stale
    // pre-seek time there would end the segment the instant it started.
    this.currentTime = target;
    this.send("seekTo", target);
  }

  async getCurrentTime() {
    return this.currentTime;
  }

  async getPlayerState() {
    return this.state;
  }

  destroy() {
    window.removeEventListener("message", this.handleMessage);
    this.iframe.remove();
  }
}

export { PlayerState };
