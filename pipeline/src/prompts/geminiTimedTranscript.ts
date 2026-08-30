export function geminiTimedTranscriptPrompt(clipLanguage: string): string {
  return `You are an expert transcriber for a language-learning app. Watch and LISTEN to the
attached video, then transcribe its complete spoken or sung ${clipLanguage} content with exact
word-level timestamps.

Return one output entry for every word, in the order heard. For every entry return:
- word: exactly one written word, with adjacent punctuation if appropriate
- start_seconds: when that word starts being spoken or sung
- end_seconds: when that word stops being spoken or sung

Transcribe the whole video from start to end. Include every repetition in full. For interviews,
include every speaker. The main content is in ${clipLanguage}; omit intros, outros, or passages in
other languages. Do not translate, summarize, correct, split, merge, add, or reorder words. Omit
music, applause, speaker labels, and other non-speech annotations.

Timestamps are finite non-negative seconds from the start of the video. Every end must be at or
after its start, and entries must be chronological. Use the real audio timing: preserve pauses,
held syllables, repeats, and changes of pace rather than extrapolating from a speaking rate.
Return only the structured output.`;
}
