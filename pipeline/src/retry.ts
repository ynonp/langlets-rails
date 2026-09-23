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

const MAX_DIAGNOSTIC_CHARS = 4_000;

export interface ErrorDiagnostic {
  error_class: string;
  error_message: string;
  provider_status?: number;
  provider_response?: string;
  provider_cause?: string;
}

// AI SDK provider errors carry the useful part of a failed HTTP exchange on
// enumerable properties, but Error#toString only prints the generic message.
// Keep the response/cause for diagnosis without logging the request URL (the
// Google URL can contain the API key) or the submitted prompt.
export function errorDiagnostics(error: unknown): ErrorDiagnostic {
  const diagnostic: ErrorDiagnostic = {
    error_class: errorClass(error),
    error_message: message(error),
  };

  if (!error || typeof error !== "object") return diagnostic;

  const providerError = error as Record<string, unknown>;
  if (typeof providerError.statusCode === "number") {
    diagnostic.provider_status = providerError.statusCode;
  }
  if (typeof providerError.responseBody === "string") {
    diagnostic.provider_response = truncate(providerError.responseBody);
  }
  if (providerError.cause !== undefined) {
    diagnostic.provider_cause = truncate(message(providerError.cause));
  }

  return diagnostic;
}

export function formatErrorDiagnostics(error: unknown): string {
  return JSON.stringify(errorDiagnostics(error));
}

function truncate(value: string): string {
  return value.length <= MAX_DIAGNOSTIC_CHARS
    ? value
    : `${value.slice(0, MAX_DIAGNOSTIC_CHARS)}...[truncated]`;
}
