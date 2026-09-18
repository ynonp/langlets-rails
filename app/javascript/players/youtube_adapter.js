import YouTubePlayer from "youtube-player";
import { PlayerState } from "./player_states";

// Thin wrapper over the `youtube-player` library, exposing the adapter contract
// main-video-player talks to. Behaviour is deliberately identical to what the
// controller did inline before TikTok existed — this file is a move, not a
// rewrite.
export default class YoutubeAdapter {
  static provider = "youtube";

  constructor(element, { videoId, hl, controls }) {
    this.player = YouTubePlayer(element, {
      videoId,
      playerVars: {
        autoplay: 0,
        playsinline: 1,
        controls: controls ? 1 : 0,
        modestbranding: 1,
        rel: 0,
        hl,
      },
    });
  }

  onStateChange(callback) {
    this.player.on("stateChange", (event) => callback(event.data));
  }

  playVideo() {
    return this.player.playVideo();
  }

  pauseVideo() {
    return this.player.pauseVideo();
  }

  seekTo(seconds) {
    // This is always a committed seek, never an in-progress scrub gesture.
    // Allow YouTube to request an unbuffered target instead of snapping to the
    // nearest already-loaded position.
    return this.player.seekTo(seconds, true);
  }

  async getCurrentTime() {
    return await this.player.getCurrentTime();
  }

  async getPlayerState() {
    return await this.player.getPlayerState();
  }

  destroy() {
    return this.player.destroy();
  }
}

export { PlayerState };
