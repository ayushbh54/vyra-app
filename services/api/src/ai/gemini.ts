/**
 * =============================================================================
 * GEMINI CLIENT — Interactions API
 * =============================================================================
 * A thin, dependency-free wrapper over the Gemini REST API.
 *
 * Written by hand rather than pulled from an SDK for three reasons:
 *   - one fewer dependency to break during a demo,
 *   - precise control over timeouts, retries and schema enforcement,
 *   - every call is injectable, so the layers above are testable without a
 *     network or an API key (see `GeminiTransport`).
 *
 * -----------------------------------------------------------------------------
 * WHICH API, AND WHY BOTH
 * -----------------------------------------------------------------------------
 * Text and JSON go through the INTERACTIONS API (POST /v1beta/interactions).
 * As of June 2026 this is Google's default surface and `generateContent` is
 * documented as legacy.
 *
 * Image input still goes through generateContent. That is deliberate: the
 * Interactions API's `input` field accepts "Content or array", but the exact
 * shape for inline image bytes is not documented on any page we could verify.
 * Rather than guess a request body for the feature that reads someone's meal,
 * we use the legacy endpoint, whose `inline_data` part IS fully specified and
 * still live. When the multimodal `input` shape is published, `visionRequest`
 * below is the only method that needs to change.
 *
 * -----------------------------------------------------------------------------
 * THREE THINGS THAT SILENTLY BREAK, DOCUMENTED HERE SO THEY DO NOT
 * -----------------------------------------------------------------------------
 * 1. NEVER READ steps[0]. A response usually begins with a `thought` step which
 *    has no `content` array at all. `steps[0].content[0].text` throws. Always
 *    filter by the `type` discriminator.
 *
 * 2. `output_text` IS NOT A REST FIELD. It is a convenience property on the
 *    Python/JS SDKs. Reading it from a raw REST response yields undefined.
 *
 * 3. FIELD NAMES ARE snake_case (`system_instruction`, `response_format`,
 *    `max_output_tokens`) — unlike the camelCase generateContent surface.
 *    Mixing the two produces a request the server accepts and quietly ignores.
 *
 * SECURITY: this module runs ONLY on the server. The API key must never reach
 * the mobile app or a browser bundle — a key shipped to a client is extracted
 * within minutes and billed to you.
 * =============================================================================
 */

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------

export interface GeminiConfig {
  apiKey: string;
  textModel: string;
  visionModel: string;
  maxOutputTokens: number;
  timeoutMs: number;
  maxRetries: number;
  baseUrl: string;
}

export function loadGeminiConfig(
  env: NodeJS.ProcessEnv = process.env,
  /** Which env var holds this feature's key. Falls back to the base
   * GEMINI_API_KEY when the feature-specific one isn't set, so every new
   * Gemini feature can default to "just works" while still supporting an
   * isolated key/quota/billing the moment one is added — see
   * GEMINI_EVENTS_API_KEY for the first feature that uses this. */
  keyEnvVar: string = 'GEMINI_API_KEY',
): GeminiConfig {
  const apiKey = env[keyEnvVar] || env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error(
      `${keyEnvVar} (or GEMINI_API_KEY) is not set. AI features are disabled — ` +
      'set one in .env (server-side only).',
    );
  }
  return {
    apiKey,
    // Defaults are the current models. They live in env so a model rename never
    // requires a code change — verify at ai.google.dev/gemini-api/docs/models.
    textModel: env.GEMINI_TEXT_MODEL ?? 'gemini-3.7-flash',
    visionModel: env.GEMINI_VISION_MODEL ?? 'gemini-2.0-flash', // Upgraded: better Indian food recognition vs 3.6-flash
    maxOutputTokens: Number(env.GEMINI_MAX_OUTPUT_TOKENS ?? 2048),
    timeoutMs: Number(env.GEMINI_TIMEOUT_MS ?? 20_000),
    maxRetries: Number(env.GEMINI_MAX_RETRIES ?? 2),
    // v1beta, NOT v1beta2. The official migration page says v1beta2; that path
    // returns 404. Verified by probe, and the control paths confirm 404 there
    // means "no such route" rather than "needs auth".
    baseUrl: env.GEMINI_BASE_URL ?? 'https://generativelanguage.googleapis.com/v1beta',
  };
}

// -----------------------------------------------------------------------------
// Errors
// -----------------------------------------------------------------------------

export type GeminiFailureKind =
  | 'timeout'
  | 'rate_limited'
  | 'invalid_key'
  | 'blocked_by_safety'
  | 'invalid_json'
  | 'empty_response'
  | 'upstream_error'
  | 'misconfigured';

export class GeminiError extends Error {
  constructor(
    readonly kind: GeminiFailureKind,
    message: string,
    readonly retryable: boolean,
    readonly status?: number,
  ) {
    super(message);
    this.name = 'GeminiError';
  }

  /** What the user sees. Never leaks a model name, prompt, key or stack trace. */
  get userMessage(): string {
    switch (this.kind) {
      case 'timeout':
      case 'upstream_error':
        return 'The AI assistant is not responding right now. Please try again in a moment.';
      case 'rate_limited':
        return 'Too many AI requests just now. Please wait a minute and try again.';
      case 'blocked_by_safety':
        return 'That request could not be processed. Try rephrasing it.';
      case 'invalid_key':
      case 'misconfigured':
        return 'AI features are unavailable right now.';
      default:
        return 'The AI assistant returned something we could not read. Please try again.';
    }
  }
}

// -----------------------------------------------------------------------------
// Transport — injectable so tests never touch the network
// -----------------------------------------------------------------------------

export interface GeminiTransport {
  (url: string, init: RequestInit & { signal: AbortSignal }): Promise<Response>;
}

export interface InlineImage {
  mimeType: string; // 'image/jpeg' | 'image/png'
  dataBase64: string;
}

export interface GenerateOptions {
  prompt: string;
  systemInstruction?: string;
  image?: InlineImage;
  /** A JSON Schema. When present, the model is constrained to emit matching JSON. */
  responseSchema?: Record<string, unknown>;
  /** 0 for deterministic extraction, higher for creative generation. */
  temperature?: number;
}

// -----------------------------------------------------------------------------
// Response shapes (only the fields we read)
// -----------------------------------------------------------------------------

interface InteractionStep {
  type: string; // 'thought' | 'model_output' | 'function_call' | ...
  content?: Array<{ type: string; text?: string }>;
}

interface InteractionResponse {
  id?: string;
  status?: string;
  steps?: InteractionStep[];
  error?: { message?: string; status?: string };
}

interface GenerateContentResponse {
  candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  promptFeedback?: { blockReason?: string };
}

// -----------------------------------------------------------------------------
// Client
// -----------------------------------------------------------------------------

export class GeminiClient {
  constructor(
    private readonly config: GeminiConfig,
    private readonly transport: GeminiTransport = fetch as unknown as GeminiTransport,
  ) {}

  /**
   * Generates a JSON object matching `responseSchema`.
   *
   * The schema is enforced at the API level via `response_format`, not by asking
   * the model politely in the prompt. "Reply only with JSON" fails often enough
   * to matter; a schema constraint does not. We still parse defensively, because
   * trusting any single layer completely is how production breaks.
   */
  async generateJson<T>(options: GenerateOptions): Promise<T> {
    const raw = await this.generateText({ ...options, temperature: options.temperature ?? 0.4 });

    // The JSON arrives as a string in the text field, not pre-parsed. Strip a
    // markdown fence if one slips through despite the schema constraint.
    const cleaned = raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');

    try {
      return JSON.parse(cleaned) as T;
    } catch {
      throw new GeminiError(
        'invalid_json',
        `Model returned unparseable JSON (${cleaned.slice(0, 200)})`,
        true,
      );
    }
  }

  /** Text generation with timeout, standard generateContent fallback, and bounded retry. */
  async generateText(options: GenerateOptions): Promise<string> {
    let req = options.image
      ? this.visionRequest(options)
      : this.interactionsRequest(options);

    let lastError: GeminiError | null = null;

    for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
      if (attempt > 0) await sleep(400 * 2 ** (attempt - 1)); // exponential backoff

      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), this.config.timeoutMs);

      try {
        const response = await this.transport(req.url, {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            // Header form, not ?key= — keys in URLs leak into logs, proxies
            // and referrer headers.
            'x-goog-api-key': this.config.apiKey,
          },
          body: JSON.stringify(req.body),
          signal: controller.signal,
        });

        if (!response.ok) {
          // Standard AI Studio API keys use the /models/{model}:generateContent endpoint.
          // If /interactions returns 404 or 400, fall back seamlessly to generateContent.
          if ((response.status === 404 || response.status === 400) && !options.image && req.url.endsWith('/interactions')) {
            clearTimeout(timer);
            req = this.textContentRequest(options);
            continue;
          }
          const retryable = response.status === 429 || response.status >= 500;
          const kind: GeminiFailureKind =
            response.status === 429 ? 'rate_limited'
            : response.status === 400 || response.status === 403 ? 'invalid_key'
            : 'upstream_error';

          lastError = new GeminiError(
            kind,
            kind === 'invalid_key'
              ? `Gemini rejected the API key (HTTP ${response.status}). Check GEMINI_API_KEY.`
              : `Gemini responded ${response.status}`,
            retryable,
            response.status,
          );
          if (!retryable) throw lastError;
          continue;
        }

        const text = req.parse(await response.json());
        if (!text) {
          lastError = new GeminiError('empty_response', 'Gemini returned no content', true);
          continue;
        }
        return text;
      } catch (error) {
        if (error instanceof GeminiError) {
          if (!error.retryable) throw error;
          lastError = error;
          continue;
        }
        if ((error as Error)?.name === 'AbortError') {
          lastError = new GeminiError('timeout', `Timed out after ${this.config.timeoutMs}ms`, true);
          continue;
        }
        lastError = new GeminiError('upstream_error', (error as Error).message, true);
      } finally {
        clearTimeout(timer);
      }
    }

    throw lastError ?? new GeminiError('upstream_error', 'Gemini call failed', false);
  }

  // ---------------------------------------------------------------------------
  // Request builders
  // ---------------------------------------------------------------------------

  /** The current surface. All field names are snake_case. */
  private interactionsRequest(options: GenerateOptions) {
    const body: Record<string, unknown> = {
      model: this.config.textModel,
      input: options.prompt,
      generation_config: {
        temperature: options.temperature ?? 0.4,
        max_output_tokens: this.config.maxOutputTokens,
      },
      // `store` defaults to TRUE, which would retain every interaction on
      // Google's side for weeks. VYRA sends recipes built from a person's
      // dietary profile, so we opt out explicitly on every call.
      store: false,
    };

    if (options.systemInstruction) body.system_instruction = options.systemInstruction;

    if (options.responseSchema) {
      // A single object, not an array. The array form exists only for requesting
      // several output modalities at once.
      body.response_format = {
        type: 'text',
        mime_type: 'application/json',
        schema: options.responseSchema,
      };
    }

    return {
      url: `${this.config.baseUrl}/interactions`,
      body,
      parse: (json: unknown) => extractInteractionText(json as InteractionResponse),
    };
  }

  /**
   * Legacy generateContent, used only for image input.
   * See the header note: the Interactions API's multimodal `input` shape is not
   * documented, and guessing it for the meal-scanning feature is not acceptable.
   */
  private visionRequest(options: GenerateOptions) {
    const parts: Array<Record<string, unknown>> = [{ text: options.prompt }];
    if (options.image) {
      parts.push({
        inline_data: { mime_type: options.image.mimeType, data: options.image.dataBase64 },
      });
    }

    const body: Record<string, unknown> = {
      contents: [{ role: 'user', parts }],
      generationConfig: {
        temperature: options.temperature ?? 0.4,
        maxOutputTokens: this.config.maxOutputTokens,
        ...(options.responseSchema
          ? { responseMimeType: 'application/json', responseSchema: options.responseSchema }
          : {}),
      },
    };
    if (options.systemInstruction) {
      body.systemInstruction = { parts: [{ text: options.systemInstruction }] };
    }

    return {
      url: `${this.config.baseUrl}/models/${this.config.visionModel}:generateContent`,
      body,
      parse: (json: unknown) => {
        const r = json as GenerateContentResponse;
        if (r.promptFeedback?.blockReason) {
          throw new GeminiError('blocked_by_safety', `Blocked: ${r.promptFeedback.blockReason}`, false);
        }
        return r.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('').trim() ?? '';
      },
    };
  }

  /**
   * Standard generateContent for text-only input — used as a fallback when the
   * Interactions API returns 404 (standard AI Studio keys don't expose it).
   * Same response shape as visionRequest but without image data.
   */
  private textContentRequest(options: GenerateOptions) {
    const body: Record<string, unknown> = {
      contents: [{ role: 'user', parts: [{ text: options.prompt }] }],
      generationConfig: {
        temperature: options.temperature ?? 0.4,
        maxOutputTokens: this.config.maxOutputTokens,
        ...(options.responseSchema
          ? { responseMimeType: 'application/json', responseSchema: options.responseSchema }
          : {}),
      },
    };
    if (options.systemInstruction) {
      body.systemInstruction = { parts: [{ text: options.systemInstruction }] };
    }

    return {
      url: `${this.config.baseUrl}/models/${this.config.textModel}:generateContent`,
      body,
      parse: (json: unknown) => {
        const r = json as GenerateContentResponse;
        if (r.promptFeedback?.blockReason) {
          throw new GeminiError('blocked_by_safety', `Blocked: ${r.promptFeedback.blockReason}`, false);
        }
        return r.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('').trim() ?? '';
      },
    };
  }
}

// -----------------------------------------------------------------------------
// Response parsing
// -----------------------------------------------------------------------------

/**
 * Pulls the generated text out of an Interactions response.
 *
 * Exported so it can be tested directly — this is the single most breakage-prone
 * piece of the integration, because the step list is heterogeneous and its first
 * entry is usually a `thought` with no content at all.
 */
export function extractInteractionText(response: InteractionResponse): string {
  if (response.error?.message) {
    throw new GeminiError('upstream_error', response.error.message, true);
  }

  const steps = response.steps ?? [];
  const chunks: string[] = [];

  for (const step of steps) {
    // Filter by the type discriminator, never by position.
    if (step.type !== 'model_output') continue;
    for (const item of step.content ?? []) {
      if (item.type === 'text' && item.text) chunks.push(item.text);
    }
  }

  return chunks.join('').trim();
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// -----------------------------------------------------------------------------
// Graceful degradation
// -----------------------------------------------------------------------------

/**
 * Returns a client, or null when no API key is configured.
 *
 * VYRA must run without Gemini. Recipes and food scanning degrade to "AI
 * features unavailable"; workouts, tracking, coins, scheduling and leaderboards
 * all keep working, because none of them depend on a model. An app that dies
 * without its LLM is a demo, not a product — and this is also what saves you if
 * the API quota runs out mid-presentation.
 */
export function tryCreateGeminiClient(
  env: NodeJS.ProcessEnv = process.env,
  transport?: GeminiTransport,
  keyEnvVar?: string,
): GeminiClient | null {
  try {
    return new GeminiClient(loadGeminiConfig(env, keyEnvVar), transport);
  } catch {
    return null;
  }
}
