// Ports of HasTimestamp / Phrase timestamp conversions so the pipeline emits
// exactly the same "MM:SS.ss" strings Rails stores and parses.

// Parse "MM:SS.ss" or "HH:MM:SS.ss" into float seconds. Returns null for blank
// or malformed input so callers can tell "no timestamp" apart from 0 seconds.
export function timestampToSeconds(value: string | null | undefined): number | null {
  if (!value || !value.includes(":")) return null;

  const parts = value.split(":").map((p) => parseFloat(p) || 0);
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  return null;
}

// Format float seconds into an "MM:SS.ss" timestamp string (%02d:%05.2f).
export function secondsToTimestamp(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const secs = seconds - minutes * 60;
  const mm = String(minutes).padStart(2, "0");
  const ss = secs.toFixed(2).padStart(5, "0");
  return `${mm}:${ss}`;
}

// Parse "HH:MM:SS,mmm" / "MM:SS,mmm" / "HH:MM:SS.mmm" (SRT comma decimal
// separator) into float seconds. Returns null for blank/malformed input.
export function srtToSeconds(srt: string | null | undefined): number | null {
  if (!srt) return null;
  return timestampToSeconds(srt.trim().replaceAll(",", "."));
}
