// Gemini is used only when a YouTube video has no usable native captions.
// It returns lyrics text; ElevenLabs supplies word timings in the next step.
export function extractLyricsPrompt(clipLanguage: string): string {
  return `You are an expert transcriber for a language learning app. Watch this video
and write out the full lyrics (for music) or spoken text (for speech).

The video is in ${clipLanguage}, but may have an intro/outro in a different language.
Only transcribe the main ${clipLanguage} vocals. Do not translate.

FORMAT
- Return ONLY the transcribed text: one line per sung or spoken phrase.
- No timestamps, no speaker labels, no numbering, no commentary, no markdown.
- Max 42 characters per line. Break longer sentences into natural short lines.
- Write the lines in the order they are heard.

COMPLETENESS
- Cover the whole video from start to end.
- For music clips include all the text of the song: write out every repetition
  of the chorus in full, plus any intro speech in ${clipLanguage}.
- For interview-style videos transcribe all speakers; we only care about the
  text, not who said it.
- Omit content in languages other than ${clipLanguage}.`;
}
