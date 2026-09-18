const DEFAULT_MARGIN = 8;
const DEFAULT_GAP = 6;

const clamp = (value, min, max) => Math.max(min, Math.min(value, max));

// Returns viewport coordinates for a popup adjacent to an anchor. Prefer the
// space below the anchor, but flip above it when the popup would cross the
// viewport's bottom edge.
export function adjacentPopoverPosition({
  anchorRect,
  popupWidth,
  popupHeight,
  viewportWidth,
  viewportHeight,
  margin = DEFAULT_MARGIN,
  gap = DEFAULT_GAP,
}) {
  const maxLeft = Math.max(margin, viewportWidth - popupWidth - margin);
  const left = clamp(
    anchorRect.left + (anchorRect.width / 2) - (popupWidth / 2),
    margin,
    maxLeft,
  );

  const below = anchorRect.bottom + gap;
  const above = anchorRect.top - popupHeight - gap;
  const maxTop = Math.max(margin, viewportHeight - popupHeight - margin);
  const top = below + popupHeight <= viewportHeight - margin
    ? below
    : (above >= margin ? above : clamp(below, margin, maxTop));

  return { left, top };
}
