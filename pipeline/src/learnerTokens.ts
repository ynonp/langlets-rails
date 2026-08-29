export function countLearnerTokens(text: string, _language = ""): number {
  return text.trim().split(/\s+/u).filter(Boolean).length;
}

export function capitalizeSentence(text: string): string {
  return text.replace(/\p{L}/u, (letter) => letter.toLocaleUpperCase());
}
