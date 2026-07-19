// The pipeline's working copy of CreateSongProgress.data. Every mutation goes
// through set/append/patch, which apply the change locally AND forward the
// same PatchOps to the sink (the Rails callback), so postgres always holds
// what the pipeline holds. The step guards mirror create_data's — a rerun with
// the saved data resumes exactly where the previous run stopped.

import type { PatchOp, ProgressData, ProgressSink, TranslationPayload } from "./types.ts";

export class ProgressStore {
  data: ProgressData;
  #sink: ProgressSink;

  constructor(data: ProgressData | undefined, sink: ProgressSink) {
    this.data = data ?? {};
    this.#sink = sink;
  }

  async set(path: string, value: unknown): Promise<void> {
    await this.patch([{ op: "set", path, value }]);
  }

  async append(path: string, value: unknown): Promise<void> {
    await this.patch([{ op: "append", path, value }]);
  }

  async clearErrors(step: string): Promise<void> {
    await this.patch([{ op: "clear_errors", path: "errors", value: step }]);
  }

  async patch(ops: PatchOp[]): Promise<void> {
    for (const op of ops) applyOp(this.data, op);
    await this.#sink.patch(ops);
  }

  // ---- step guards (mirror CreateSongProgress#create_data and
  // ProgressReporting#step_done? — if you change one, change the other) ----

  extractLyricsDone(): boolean {
    return (this.data.phrases?.length ?? 0) > 0 && !this.data.extract_lyrics_in_progress;
  }

  lessonsDone(): boolean {
    return present(this.data.lessons);
  }

  lessonsRated(): boolean {
    return (this.data.lesson_ratings?.length ?? 0) > 0;
  }

  similarSoundsDone(): boolean {
    return present(this.data.similar_sounds);
  }

  translationPayload(iso: string): TranslationPayload | undefined {
    return this.data.translations?.[iso];
  }

  // Every phrase has its translated text.
  translateDone(iso: string): boolean {
    const payload = this.translationPayload(iso);
    if (!payload || payload.phrases.length === 0) return false;
    return payload.phrases.every((p) => present(p.text));
  }

  // A phrase's token translations are done when its words array is fully
  // populated (chunk saves are per whole phrase, so partial phrases only occur
  // for legacy data — those rerun).
  tokenTranslationsDoneFor(iso: string, phraseIndex: number): boolean {
    const payload = this.translationPayload(iso);
    const words = payload?.phrases?.[phraseIndex]?.words;
    const expected = this.data.phrases?.[phraseIndex]?.words?.length ?? 0;
    if (expected === 0) return true;
    if (!words || words.length !== expected) return false;
    return words.every((w) => w !== null && w !== undefined);
  }

  tokenTranslationsDone(iso: string): boolean {
    const phrases = this.data.phrases ?? [];
    if (phrases.length === 0) return false;
    if (!this.translationPayload(iso)) return false;
    return phrases.every((_, i) => this.tokenTranslationsDoneFor(iso, i));
  }

  translationFinalized(iso: string): boolean {
    const payload = this.translationPayload(iso);
    return payload != null && present(payload.lessons);
  }
}

function present(value: unknown): boolean {
  if (value === null || value === undefined) return false;
  if (typeof value === "string") return value.trim() !== "";
  return true;
}

// Apply one op to the local data. Paths are dot-separated; numeric segments
// index arrays. Intermediate containers are created on demand (an array when
// the next segment is numeric, an object otherwise) — the Rails callback
// applies the identical semantics.
export function applyOp(data: ProgressData, op: PatchOp): void {
  const segments = op.path.split(".");
  if (segments.some((s) => s === "")) throw new Error(`invalid patch path: ${op.path}`);

  // deno-lint-ignore no-explicit-any
  let node: any = data;
  for (let i = 0; i < segments.length - 1; i++) {
    const key = containerKey(segments[i]);
    if (node[key] == null) {
      node[key] = /^\d+$/.test(segments[i + 1]) ? [] : {};
    }
    node = node[key];
  }

  const last = containerKey(segments[segments.length - 1]);
  if (op.op === "set") {
    node[last] = op.value;
  } else if (op.op === "append") {
    if (node[last] == null) node[last] = [];
    if (!Array.isArray(node[last])) throw new Error(`append target is not an array: ${op.path}`);
    node[last].push(op.value);
  } else {
    if (op.path !== "errors" || typeof op.value !== "string") {
      throw new Error("clear_errors requires the errors path and a string step");
    }
    if (node[last] == null) return;
    if (!Array.isArray(node[last])) throw new Error("clear_errors target is not an array: errors");
    node[last] = node[last].filter((entry: unknown) => {
      return typeof entry !== "object" || entry === null ||
        (entry as { step?: unknown }).step !== op.value;
    });
  }
}

function containerKey(segment: string): string | number {
  return /^\d+$/.test(segment) ? Number(segment) : segment;
}
