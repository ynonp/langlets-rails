// Shape contract shared with the Rails side. This mirrors
// CreateSongProgress#data in its version-2 (multilanguage) format — see
// app/models/create_song_progress/data_format.rb. The pipeline never invents a
// new shape: everything it writes must load back into Rails unchanged.

// CreateSongProgress::DataFormat::VERSION — the multilanguage blob shape.
export const DATA_FORMAT_VERSION = 2;

export interface Word {
  text: string;
  timestamp: string;
  timestamp_end: string;
  l1_start_index?: number;
  l1_end_index?: number;
}

export interface Phrase {
  id: string;
  text_l1: string;
  timestamp: string;
  timestamp_end: string;
  words: Word[];
}

export interface LessonRating {
  index: number;
  title: string;
  score: number;
  reason: string;
}

// One language's payload under data.translations[iso]. `phrases` is aligned
// by index with the neutral data.phrases; words holds one translation string
// per word (null when the word has no translation yet / couldn't be located).
export interface TranslationPayload {
  language_id: number | null;
  language_name: string;
  phrases: TranslationPhrase[];
  lessons: string | null;
}

export interface TranslationPhrase {
  text: string | null;
  words: (string | null)[];
}

// Matches the failure entries add_token_translations already writes today, so
// existing debugging habits (and any UI reading data.errors) keep working.
export interface PipelineError {
  step: string;
  occurred_at: string;
  attempts?: number;
  error_class?: string;
  error_message: string;
  input_lines?: string[] | null;
  agent_response?: string | null;
}

export interface ProgressData {
  format_version?: number;
  phrases?: Phrase[];
  // The transcription extract_lyrics produced, one entry per sung/spoken
  // line, before force_alignment times it into `phrases`.
  lyric_lines?: string[];
  extract_lyrics_in_progress?: boolean;
  force_alignment_in_progress?: boolean;
  video_length_seconds?: number | null;
  lessons?: string;
  lesson_ratings?: LessonRating[];
  similar_sounds?: string;
  translations?: Record<string, TranslationPayload>;
  errors?: PipelineError[];
  // Rails may carry extra keys we don't know about; keep them intact.
  [key: string]: unknown;
}

export interface LanguageRef {
  id: number | null;
  iso_name: string;
  english_name: string;
}

// The POST body Rails sends to trigger a run (and what the CLI assembles from
// its arguments). `data` is the exported CreateSongProgress.data — passing it
// in is what makes runs resumable: guards below skip whatever is already done.
export interface TriggerPayload {
  youtubeurl: string;
  clip_language: string;
  // Optional iso override for the similar-sound dictionary; without it the
  // clip_language English name is mapped against the built-in catalog.
  clip_language_iso?: string | null;
  translation_language: LanguageRef | null;
  callback_url: string;
  data?: ProgressData;
}

// A single mutation of CreateSongProgress.data, addressed by dot-separated key
// path ("translations.he.phrases.3.text"). Numeric segments index arrays.
// "append" pushes onto an array (creating it when missing) — used for errors.
// "clear_errors" atomically removes every error whose step matches `value`.
export interface PatchOp {
  op: "set" | "append" | "clear_errors";
  path: string;
  value: unknown;
}

// Wherever patches go: over HTTP to the Rails callback in production, into an
// in-memory list in tests.
export interface ProgressSink {
  patch(ops: PatchOp[]): Promise<void>;
}
