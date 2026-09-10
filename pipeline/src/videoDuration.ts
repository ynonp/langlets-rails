// Supadata metadata reports media.duration in seconds for both supported providers.
export const MAX_VIDEO_MINUTES = 20;
export const MAX_VIDEO_SECONDS = MAX_VIDEO_MINUTES * 60;
export const DURATION_ERROR_PREFIX = "Video duration limit: ";

export async function validateVideoDuration(
  videoUrl: string,
  options: { apiKey?: string; fetch?: typeof globalThis.fetch } = {},
): Promise<void> {
  let duration: unknown;
  try {
    const apiKey = options.apiKey ?? Deno.env.get("SUPADATA_KEY") ??
      Deno.env.get("SUPADATA_API_KEY");
    if (!apiKey) throw new Error("Supadata key is missing");
    const url = new URL("https://api.supadata.ai/v1/metadata");
    url.searchParams.set("url", videoUrl);
    const response = await (options.fetch ?? globalThis.fetch)(url, {
      headers: { "x-api-key": apiKey },
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) throw new Error(`Metadata request failed (${response.status})`);
    const metadata = await response.json();
    // Supadata's unified endpoint currently returns duration at the top level;
    // older responses nested it below media. Accept both during the transition.
    duration = metadata?.duration ?? metadata?.media?.duration;
    if (typeof duration !== "number" || !Number.isFinite(duration) || duration <= 0) {
      throw new Error("Missing or invalid duration");
    }
  } catch (error) {
    console.warn("Video duration lookup failed", error);
    return;
  }
  if ((duration as number) > MAX_VIDEO_SECONDS) {
    throw new Error(
      `${DURATION_ERROR_PREFIX}Please choose a video that is ${MAX_VIDEO_MINUTES} minutes or shorter.`,
    );
  }
}
