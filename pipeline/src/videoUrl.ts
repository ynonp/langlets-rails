export function isYoutubeUrl(value: string): boolean {
  return hostnameOf(
    value,
    (hostname) =>
      hostname === "youtube.com" || hostname.endsWith(".youtube.com") ||
      hostname === "youtu.be",
  );
}

// Covers the post form (www.tiktok.com/@user/video/123) and the share forms
// (vt./vm.tiktok.com).
export function isTiktokUrl(value: string): boolean {
  return hostnameOf(
    value,
    (hostname) => hostname === "tiktok.com" || hostname.endsWith(".tiktok.com"),
  );
}

function hostnameOf(value: string, predicate: (hostname: string) => boolean): boolean {
  try {
    return predicate(new URL(value).hostname.toLowerCase().replace(/^www\./, ""));
  } catch {
    return false;
  }
}
