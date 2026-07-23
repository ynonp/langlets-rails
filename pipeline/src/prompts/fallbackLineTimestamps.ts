export function fallbackLineTimestampsPrompt(clipLanguage: string): string {
  return `You timestamp transcript lines for a language-learning video.
Watch the attached video and locate each supplied ${clipLanguage} transcript line.

Return exactly one output entry for every input line, in the same order.
For each line return:
- line: the supplied line
- start_seconds: when the line begins
- end_seconds: when the line ends

Do not split, merge, add, remove, reorder, correct, or translate lines.
Timestamps must be finite non-negative seconds. Each end must be at or after its
start, and lines must remain chronological. Return only the structured output.`;
}
