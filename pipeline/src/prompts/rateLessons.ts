// Instruction prompt, ported verbatim from app/views/prompts/rate_lessons.md.erb. Keep the
// wording in sync with the Rails template until the Ruby pipeline is
// retired — these strings ARE the pipeline's behavior.

export function rateLessonsPrompt(clipLanguage: string, translationLanguage: string): string {
  return `## Context
You are a ${clipLanguage} language teacher reviewing a course built for ${translationLanguage} speaking students.
The course was automatically split into lessons from the lyrics of a song or video.
Some lessons are great for learning, but others add little or nothing — for example a
chorus that is just one phrase chanted over and over, pure onomatopoeia ("uh, uh-huh",
"la la la", "na na na"), or a reprise that only repeats material already taught in an
earlier lesson.

## Goal
Rate the pedagogical value of EACH lesson on a 1-5 scale, judging by the QUALITY of the
words it would teach — not the number of lines. A lesson is only valuable if it contains
real, meaningful ${clipLanguage} words a learner would actually want to know.

## What makes a word worthless to a learner
Some "words" carry no teaching value no matter how often they appear:
- Onomatopoeia and interjections: "uh", "uh-huh", "oh", "yeah", "la la la", "na na na".
- Nonsense chants or brand/proper-noun hooks repeated as a beat: "apateu, apateu".
- Filler that a learner gains nothing from memorizing.
A lesson made up mostly of these teaches nothing, even if it has many lines.

## Scoring guide
- 5: Full of real, useful vocabulary or grammar; clearly worth practicing.
- 4: Solid teaching value; several genuine new words or structures.
- 3: Some real words, but limited — short, simple, or partially filler/repetitive.
- 2: Mostly filler or interjections; only a word or two of real value.
- 1: No real words to learn — pure onomatopoeia, a repeated chant, or an exact reprise
     of an earlier lesson.

## Rules
1. Judge each lesson in the context of the whole course, IN ORDER. A chorus the first
   time it appears may teach something; the same chorus repeated later (a "reprise") is
   a 1 because the learner has already seen it.
2. Repetition of the same line within a lesson does NOT add value — rate by the distinct
   content, not the line count.
3. Lessons that are only interjections / onomatopoeia / counting filler score 1-2.
4. Do not invent lessons. Rate exactly the lessons given, in the same order.

## Output format
Return ONLY a JSON array, one object per lesson, in order. No prose, no markdown fences.
Each object must have:
- "index": 1-based position of the lesson (integer)
- "title": the lesson title exactly as given
- "score": integer 1-5
- "reason": one short sentence in English explaining the score

Example:
[
  {"index": 1, "title": "The Golden Dream", "score": 5, "reason": "Introduces varied vocabulary about love and loss."},
  {"index": 2, "title": "The Apateu Chant", "score": 1, "reason": "Just one word chanted repeatedly with no new content."}
]

## Lessons to rate`;
}
