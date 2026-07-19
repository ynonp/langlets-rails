// Instruction prompt, ported verbatim from app/views/prompts/extract_phrases_from_youtube_url.md.erb. Keep the
// wording in sync with the Rails template until the Ruby pipeline is
// retired — these strings ARE the pipeline's behavior.

export function extractLyricsPrompt(clipLanguage: string): string {
  return `You are an expert audio-visual transcriber for a language learning app. Your
task is to transcribe this video and provide exact, millisecond-accurate
timestamps for BOTH the full lines and every single word within those lines.

The video is in ${clipLanguage}, but may have an intro/outro in a different language.
Only transcribe the main ${clipLanguage} vocals. Do not translate.

CRITICAL INSTRUCTIONS FOR WORD-LEVEL SYNC:

1.  Listen closely to the phonemes. Pinpoint the exact millisecond a word leaves
    the singer's mouth and the exact millisecond they stop making the sound for
    that word.
2.  In fast singing or rap, DO NOT group words together. Isolate every single
    word.
3.  If there is a pause between words, the end timestamp of Word A must NOT
    touch the start timestamp of Word B. Leave the gap.
4.  Ensure the line_start matches the start of the first word, and the line_end
    matches the end of the last word.
5.  Max 42 characters per line.

COMPLETENESS REQUIREMENT
Transcription should cover the length of the video. Check the timestamps match the actual length of the video.
Always report the total running length of the whole video in the video_length field
(SRT format HH:MM:SS,mmm). This is the duration of the entire clip and must be the
same value in every response, even in continuation turns.

BATCHING
Return at most 40 lines per response. If the video contains more content than
fits in 40 lines, return the first 40 lines (from the start of the untranscribed
content) and set has_more to true. Set has_more to false only when the lines you
are returning reach the end of the video with nothing left to transcribe. When
asked to continue, resume from immediately after the last line you were given and
never repeat lines you already returned.

CONTENT TYPES
1. For music video clips include all the text of the song, including repeated chorus or intro speech.
2. For interview style videos transcribe all speakers. You can omit speaker recognition we only care about the text.
3. Some language learning videos include an intro or suffix in a different language. Transcribe only the ${clipLanguage} content and omit content in other languages.

Timestamps use the format "HH:MM:SS,mmm" (e.g. 00:00:06,500). Return one entry
per line, each with its line_start, line_end, line_text and a words array where
every word has word, start and end.`;
}

// Message that asks the model to resume transcription right after the last
// line we received, so the next call returns the following batch.
export function extractLyricsContinuationPrompt(lastPhrase: {
  timestamp: string;
  timestamp_end: string;
  text_l1: string;
}): string {
  return `Continue transcribing the SAME video from immediately after this line, and
return at most 30 more lines. Do not repeat any line you already returned,
and every line you return must start at or after ${lastPhrase.timestamp_end}
-- never return a line with an earlier timestamp.

Last line returned:
- timestamp: ${lastPhrase.timestamp} - ${lastPhrase.timestamp_end}
- text: ${lastPhrase.text_l1}

Set has_more to true if content still remains after your new lines, or false
once you have reached the end of the video.`;
}
