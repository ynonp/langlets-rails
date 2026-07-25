// Shared retry-with-backoff, matching the Ruby concerns' pattern:
// wait (2 ** attempt) + rand(1..3) seconds between attempts. `baseDelayMs`
// scales the whole schedule so tests can run it at zero delay.

export interface RetryOptions {
  maxRetries: number;
  label: string;
  baseDelayMs?: number;
  onFailedAttempt?: (error: unknown, attempt: number) => void;
  // Failures that a retry cannot fix (a rejected request, not a flaky one).
  // Reported through onFailedAttempt like any other failure, then rethrown
  // immediately instead of burning the rest of the schedule.
  isFatal?: (error: unknown) => boolean;
}

export async function withRetries<T>(fn: () => Promise<T>, options: RetryOptions): Promise<T> {
  const baseDelayMs = options.baseDelayMs ?? 1000;
  let attempt = 0;

  while (true) {
    try {
      return await fn();
    } catch (error) {
      attempt += 1;
      options.onFailedAttempt?.(error, attempt);
      if (options.isFatal?.(error) || attempt > options.maxRetries) throw error;

      const waitSeconds = 2 ** attempt + (1 + Math.random() * 2);
      console.warn(
        `${options.label} attempt ${attempt} failed: ${message(error)}. ` +
          `Retrying in ${waitSeconds.toFixed(1)}s...`,
      );
      await new Promise((r) => setTimeout(r, waitSeconds * baseDelayMs));
    }
  }
}

export function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function errorClass(error: unknown): string {
  return error instanceof Error ? error.constructor.name : typeof error;
}
