export function reconcileTranscriptsPrompt(clipLanguage: string): string {
  return `Reconcile two independent, noisy speech-to-text transcripts of the same video into one coherent ${clipLanguage} transcript.

Neither transcript is authoritative. Use agreement, context, grammar, and proper names to resolve errors. Preserve everything actually spoken, including repetitions and discourse markers. Do not summarize, translate, add commentary, or invent speech. Return one continuous transcript in the original language.`;
}
