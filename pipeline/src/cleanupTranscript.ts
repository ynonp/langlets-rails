// Remove caption/transcription conventions that describe non-speech audio
// rather than words a learner can hear and study.
const NON_SPEECH_SYMBOLS = /[♪♫♬♩𝅗𝅥𝅘𝅥𝅮]/gu;

export function cleanupTranscript(text: string): string {
  return text
    .replace(/\[[^\]\r\n]*\]/gu, " ")
    .replace(/\([^)\r\n]*\)/gu, " ")
    .replace(NON_SPEECH_SYMBOLS, " ")
    .replace(/\s+/gu, " ")
    .trim();
}
