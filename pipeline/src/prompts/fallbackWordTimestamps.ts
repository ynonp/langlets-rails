export function fallbackWordTimestampsPrompt(clipLanguage: string): string {
  return `You timestamp individual words for a language-learning video.
Watch and LISTEN to the attached video, then locate every supplied
${clipLanguage} transcript word in the audio.

Return exactly one output entry for every input word, in the same order.
For each entry always return:
- word: the supplied word, copied exactly

When you can timestamp the word confidently, also return:
- start_seconds: when it starts being sung or spoken
- end_seconds: when it stops being sung or spoken

The first and last words of every supplied transcript line must include both
timestamps. Middle-word timestamps are strongly preferred, but when you cannot
locate a middle word confidently, still return its word entry and omit both
timestamp fields.

Do not split, merge, add, remove, reorder, correct, translate, or re-punctuate
words. Include repeats separately.

Your output is checked against the transcript and rejected when the words or
the ordering do not match, so timestamp what you actually hear. Do not
extrapolate from a plausible speaking rate or spread the words evenly across
the clip: this video's rhythm is unusual — held notes, repeats, sudden pauses,
instrumental gaps, and fast passages — and evenly spaced guesses will be wrong.
When a word is held or repeated, its entry must reflect that real duration.

Timestamps are finite non-negative seconds measured from the start of the
video. Each end must be at or after its start, and words must stay
chronological. Return only the structured output.`;
}
