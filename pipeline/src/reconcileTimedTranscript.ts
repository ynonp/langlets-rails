import type { AlignedWord } from "./alignment.ts";

const MAX_LOCAL_REPLACEMENT_WORDS = 4;

export interface TimedTranscriptReconciliation {
  words: AlignedWord[];
  replacedSpans: number;
  fallbackSpans: number;
}

// Treat Scribe's timed words as the backbone and apply only local, anchored
// transcript corrections. Every returned word is timed. If a correction would
// add/remove speech or rewrite a broad span, retain Scribe's original wording
// for that span instead of creating untimed words.
export function reconcileTimedTranscript(
  correctedText: string,
  scribeWords: AlignedWord[],
): TimedTranscriptReconciliation {
  const correctedWords = wordsOf(correctedText);
  if (scribeWords.length === 0 || correctedWords.length === 0) {
    return { words: scribeWords, replacedSpans: 0, fallbackSpans: 0 };
  }

  const matches = matchingPairs(
    scribeWords.map((word) => wordKey(word.text)),
    correctedWords.map(wordKey),
  );
  const output: AlignedWord[] = [];
  let oldCursor = 0;
  let newCursor = 0;
  let replacedSpans = 0;
  let fallbackSpans = 0;

  for (
    const match of [...matches, { oldIndex: scribeWords.length, newIndex: correctedWords.length }]
  ) {
    const oldSpan = scribeWords.slice(oldCursor, match.oldIndex);
    const newSpan = correctedWords.slice(newCursor, match.newIndex);
    if (oldSpan.length > 0 || newSpan.length > 0) {
      if (isSafeLocalReplacement(oldSpan, newSpan, matches.length > 0)) {
        output.push(...timestampReplacement(newSpan, oldSpan));
        replacedSpans++;
      } else {
        output.push(...oldSpan);
        fallbackSpans++;
      }
    }

    if (match.oldIndex < scribeWords.length) {
      const source = scribeWords[match.oldIndex];
      output.push({ ...source, text: correctedWords[match.newIndex] });
    }
    oldCursor = match.oldIndex + 1;
    newCursor = match.newIndex + 1;
  }

  return { words: output, replacedSpans, fallbackSpans };
}

function isSafeLocalReplacement(
  oldSpan: AlignedWord[],
  newSpan: string[],
  hasAnchor: boolean,
): boolean {
  return hasAnchor && oldSpan.length > 0 && newSpan.length > 0 &&
    oldSpan.length <= MAX_LOCAL_REPLACEMENT_WORDS &&
    newSpan.length <= MAX_LOCAL_REPLACEMENT_WORDS;
}

function timestampReplacement(words: string[], replaced: AlignedWord[]): AlignedWord[] {
  if (words.length === replaced.length) {
    return words.map((text, index) => ({ ...replaced[index], text }));
  }

  const start = replaced[0].start;
  const end = replaced.at(-1)!.end;
  const weights = words.map((word) => Math.max(1, [...wordKey(word)].length));
  const totalWeight = weights.reduce((sum, weight) => sum + weight, 0);
  let elapsedWeight = 0;
  return words.map((text, index) => {
    const wordStart = start + (end - start) * elapsedWeight / totalWeight;
    elapsedWeight += weights[index];
    return {
      text,
      start: wordStart,
      end: start + (end - start) * elapsedWeight / totalWeight,
    };
  });
}

function wordsOf(text: string): string[] {
  return text.split(/\s+/u).filter(Boolean);
}

function wordKey(text: string): string {
  return text
    .normalize("NFC")
    .replace(/[‘’ʼ]/gu, "'")
    .replace(/[\p{P}\p{S}\p{M}]+/gu, "")
    .toLocaleLowerCase();
}

interface Match {
  oldIndex: number;
  newIndex: number;
}

// Myers' diff finds stable in-order anchors without allocating an N*M table.
// Broadly different transcripts are deliberately cut off: no anchors means the
// caller gets the complete original timed transcript, which is our safe mode.
function matchingPairs(oldWords: string[], newWords: string[]): Match[] {
  const oldLength = oldWords.length;
  const newLength = newWords.length;
  const maximum = oldLength + newLength;
  const distanceLimit = Math.min(maximum, Math.max(32, Math.ceil(maximum * 0.25)));
  let frontier = new Map<number, number>([[1, 0]]);
  const trace: Map<number, number>[] = [];

  for (let distance = 0; distance <= distanceLimit; distance++) {
    const next = new Map<number, number>();
    for (let diagonal = -distance; diagonal <= distance; diagonal += 2) {
      const down = frontier.get(diagonal + 1) ?? -1;
      const right = (frontier.get(diagonal - 1) ?? -1) + 1;
      let oldIndex = diagonal === -distance || (diagonal !== distance && right < down)
        ? down
        : right;
      let newIndex = oldIndex - diagonal;
      while (
        oldIndex < oldLength && newIndex < newLength &&
        oldWords[oldIndex] === newWords[newIndex]
      ) {
        oldIndex++;
        newIndex++;
      }
      next.set(diagonal, oldIndex);
      if (oldIndex >= oldLength && newIndex >= newLength) {
        trace.push(next);
        return backtrackMatches(trace, oldWords, newWords);
      }
    }
    trace.push(next);
    frontier = next;
  }

  return [];
}

function backtrackMatches(
  trace: Map<number, number>[],
  oldWords: string[],
  newWords: string[],
): Match[] {
  let oldIndex = oldWords.length;
  let newIndex = newWords.length;
  const matches: Match[] = [];

  for (let distance = trace.length - 1; distance > 0; distance--) {
    const previous = trace[distance - 1];
    const diagonal = oldIndex - newIndex;
    const down = previous.get(diagonal + 1) ?? -1;
    const right = (previous.get(diagonal - 1) ?? -1) + 1;
    const previousDiagonal = diagonal === -distance ||
        (diagonal !== distance && right < down)
      ? diagonal + 1
      : diagonal - 1;
    const previousOldIndex = previous.get(previousDiagonal) ?? 0;
    const previousNewIndex = previousOldIndex - previousDiagonal;

    while (oldIndex > previousOldIndex && newIndex > previousNewIndex) {
      matches.push({ oldIndex: oldIndex - 1, newIndex: newIndex - 1 });
      oldIndex--;
      newIndex--;
    }
    oldIndex = previousOldIndex;
    newIndex = previousNewIndex;
  }

  while (oldIndex > 0 && newIndex > 0) {
    matches.push({ oldIndex: oldIndex - 1, newIndex: newIndex - 1 });
    oldIndex--;
    newIndex--;
  }
  return matches.reverse();
}
