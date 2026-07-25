// Some iframe players publish their current position only a few times per
// second. Between authoritative updates, advance the position using elapsed
// monotonic time while playback is active.
export default class InterpolatedPlaybackClock {
  constructor(now = () => performance.now()) {
    this.now = now;
    this.position = 0;
    this.updatedAt = this.now();
    this.playing = false;
  }

  setPosition(position) {
    if (!Number.isFinite(position)) return;

    this.position = position;
    this.updatedAt = this.now();
  }

  setPlaying(playing) {
    if (this.playing === playing) return;

    if (this.playing) this.position = this.currentPosition();
    this.updatedAt = this.now();
    this.playing = playing;
  }

  currentPosition() {
    if (!this.playing) return this.position;

    return this.position + ((this.now() - this.updatedAt) / 1000);
  }
}
