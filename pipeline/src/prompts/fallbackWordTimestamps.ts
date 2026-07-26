export function fallbackWordTimestampsPrompt(clipLanguage: string): string {
  return `You timestamp individual words for a language-learning video.
Watch and LISTEN to the attached video, then locate every supplied
${clipLanguage} transcript word in the audio.

Return exactly one output entry for every input word, in the same order.
For each word return:
- word: the supplied word, copied exactly
- start_seconds: when that word starts being sung or spoken
- end_seconds: when that word stops being sung or spoken

Do not split, merge, add, remove, reorder, correct, translate, or re-punctuate
words. Return an entry for every word, including repeats — never summarize,
group, or truncate the list.

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
