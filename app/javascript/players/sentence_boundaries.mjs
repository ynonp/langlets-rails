const SEEK_JUMP_SECONDS = 1.5;

export function nextSentenceBoundaryIndex(boundaries, at) {
  const index = boundaries.findIndex((boundary) => boundary > at);
  return index === -1 ? boundaries.length : index;
}

export function crossedSentenceBoundary(previousAt, at, boundary) {
  if (![previousAt, at, boundary].every(Number.isFinite)) return false;
  if (Math.abs(at - previousAt) > SEEK_JUMP_SECONDS) return false;

  return previousAt < boundary && at >= boundary;
}

export function playbackJumped(previousAt, at) {
  return Number.isFinite(previousAt) && Number.isFinite(at) && Math.abs(at - previousAt) > SEEK_JUMP_SECONDS;
}
