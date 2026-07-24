// Playback states, shared by every provider adapter.
//
// The numbers are YouTube's (YT.PlayerState), kept as-is so the migration to
// multiple providers didn't have to touch any comparison in the app — and,
// conveniently, TikTok's onStateChange happens to use the same values for the
// four states that matter. Adapters normalize to these, so main-video-player
// never asks who is playing.
//
// Written as literals rather than read from the global `YT` object, which only
// exists once the YouTube iframe API has loaded — a TikTok-only page never
// loads it, and the old `YT.PlayerState.PAUSED` reference would have thrown.
export const PlayerState = {
  UNSTARTED: -1,
  ENDED: 0,
  PLAYING: 1,
  PAUSED: 2,
  BUFFERING: 3,
};
