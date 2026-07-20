// Instruction prompt for the backup alignment call: when yt-dlp can't fetch
// the audio or ElevenLabs forced alignment fails, Gemini watches the YouTube
// clip and times the already-transcribed lyrics itself.
//
// The words are ground truth — this call must not re-transcribe, reword or
// reorder them, only say when each one is heard. Output is the same
// line/word JSON shape parseWordTimings() reads from the ElevenLabs path.

export function forceAlignmentPrompt(clipLanguage: string): string {
  return `You are an expert audio alignment tool for a language learning app. Watch this
video and find when each line of the supplied ${clipLanguage} lyrics is heard.

The lyrics are already transcribed and are CORRECT. Your only job is timing.

RULES
- Return every supplied line, in the order given, exactly once.
- Never change, translate, reorder, merge, split, add or drop a line.
- Split each line into words on whitespace: the "word" values concatenated
  with spaces must reproduce "line_text" character for character, punctuation
  included.
- Timestamps are "HH:MM:SS,mmm" measured from the start of the video.
- Within a line, and from one line to the next, timestamps must increase.
- Each word's "end" must be greater than its "start"; "line_start" is the first
  word's start and "line_end" is the last word's end.
- Cover the whole video: the last line should land near the end of the clip.

FORMAT
Return ONLY a JSON array, no markdown fences and no commentary:
[
  {
    "line_start": "00:00:06,500",
    "line_end": "00:00:07,800",
    "line_text": "the line exactly as supplied",
    "words": [
      { "word": "the", "start": "00:00:06,500", "end": "00:00:06,700" },
      { "word": "line", "start": "00:00:06,700", "end": "00:00:07,800" }
    ]
  }
]`;
}
