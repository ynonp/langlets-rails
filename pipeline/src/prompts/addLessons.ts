// Instruction prompt, ported verbatim from app/views/prompts/add_lessons.md.erb. Keep the
// wording in sync with the Rails template until the Ruby pipeline is
// retired — these strings ARE the pipeline's behavior.

export function addLessonsPrompt(clipLanguage: string, translationLanguage: string): string {
  return `## Context
You are a ${clipLanguage} language teacher creating lessons for ${translationLanguage} speaking students.
You will be given a list of timestamped phrases from a video or song.

## Goal
Arrange the phrases into short, logical learning units (lessons) that students can practice.

## Rules:
1. Group phrases that belong together logically (by scene, dialogue, or pauses).
2. Maintain strict chronological order.
3. Length Limit: Aim for 4 to 8 phrases per lesson.
4. If a scene is too long, split it and append "(Part 1)", "(Part 2)" to the titles.
5. Create a descriptive title for each lesson in ${clipLanguage}.
6. Output format: The title must start with \`#\`. Put a blank line between lessons. Do not output any conversational filler or introductory text.

## Example Input 1
We were good
we were gold
Kind of dream
that can't be sold
We were right
'til we weren't
Built a home
and watched it burn
I didn't wanna leave you
I didn't wanna lie
Started to cry
but then remembered I

## Expected Output 1
# The Golden Dream
We were good
we were gold
Kind of dream
that can't be sold
We were right
'til we weren't
Built a home
and watched it burn

# The Turning Point
I didn't wanna leave you
I didn't wanna lie
Started to cry
but then remembered I

## Example Input 2
- Salut, tu vas bien ?
- Ça va, mais je suis fatigué.
- Pourquoi ? T'as fait quoi hier ?
J'ai commencé à lui raconter ma soirée.
- J'ai regardé une série.
- Juste un épisode ?
- Non, toute la saison.
Il m'a regardé en jugeant.
- T'es vraiment pas possible.
- Je sais, mais c'était trop bien.
Et là, le bus est arrivé.
- Bon, on y va ?
- Allez, monte.

## Expected Output 2
# La Soirée Série (Part 1)
- Salut, tu vas bien ?
- Ça va, mais je suis fatigué.
- Pourquoi ? T'as fait quoi hier ?
J'ai commencé à lui raconter ma soirée.
- J'ai regardé une série.
- Juste un épisode ?
- Non, toute la saison.

# La Soirée Série (Part 2)
Il m'a regardé en jugeant.
- T'es vraiment pas possible.
- Je sais, mais c'était trop bien.
Et là, le bus est arrivé.
- Bon, on y va ?
- Allez, monte.

## Target Input`;
}
