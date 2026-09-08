/**
 * =============================================================================
 * AI FITNESS CHAT
 * =============================================================================
 * Multi-turn conversational assistant for workout doubts, exercise form
 * guidance, diet suggestions, calorie questions, recovery advice, and
 * explaining a user's own logged progress.
 *
 * SCOPE BOUNDARY (same posture as domain/labReport.ts — read that file's header
 * first if you haven't): this assistant gives general fitness/diet guidance
 * only. It never diagnoses, never names a condition, never suggests a medicine,
 * supplement or dose. Anything that reads like a medical symptom gets
 * redirected to a doctor instead of answered. labReport.ts enforces its
 * equivalent rule with deterministic code because its output is structured and
 * can be checked. Chat has no structured output to check against — a reply is
 * free text — so the guardrail here is the system instruction itself. That is
 * weaker than a hard filter, which is exactly why the instruction below is
 * blunt and repeated rather than a single polite sentence.
 *
 * MULTI-TURN, WITHOUT A MULTI-TURN API — the design decision:
 * GeminiClient's Interactions request (ai/gemini.ts) sends a single
 * `input: string`. There is no `contents`/messages array on that surface —
 * that shape only exists on the legacy generateContent path, and that path is
 * reserved for image input (see the big comment at the top of gemini.ts on why).
 * So conversation history is folded into ONE prompt string, formatted as
 * plain "User: ...\nAssistant: ..." turns, immediately before the new message.
 * This is the simplest option that works with the client as it exists today;
 * if GeminiClient later grows a real multi-turn `contents` request, only
 * buildPrompt() below needs to change — sendChatMessage's signature does not.
 * =============================================================================
 */

import { GeminiClient, GeminiError } from './gemini';
import type { StoredChatMessage } from '../store';

export type ChatRole = StoredChatMessage['role'];
export type ChatMessage = Pick<StoredChatMessage, 'role' | 'body'>;

// How many past turns are folded into the prompt. Bounds prompt size/cost; a
// fitness chat rarely needs more than this to stay coherent turn-to-turn.
const MAX_HISTORY_TURNS = 20;

const SYSTEM_INSTRUCTION = `You are the VYRA fitness assistant — a friendly, encouraging coach inside an Indian fitness app.

You help with:
- Workout doubts and exercise form guidance
- Diet and nutrition suggestions, calorie questions
- Recovery advice, and explaining a user's own logged progress

Hard rules, no exceptions:
- You are not a doctor. Never diagnose a condition, never name a disease, never suggest a medicine, a supplement, or a dose.
- If the user describes anything that sounds like a medical symptom — pain that doesn't fit ordinary soreness, dizziness, chest discomfort, an injury, a missed period, or anything else a clinician should look at — do not explain it or guess what it might be. Say plainly that this needs a doctor's opinion and encourage them to see one soon, the same way you would send a critical lab value to a doctor rather than a diet plan.
- Keep answers practical, short and encouraging — a few sentences or a short list, not an essay. This is a chat, not an article.
- If a question is outside fitness, diet or recovery, or you are genuinely unsure, say so honestly rather than guessing.`;

/** Mirrors RecipeGenerationError/EventDiscoveryError's shape for a consistent catch site. */
export class ChatError extends Error {
  constructor(
    readonly reason: 'invalid_input' | 'ai_unavailable',
    readonly userMessage: string,
  ) {
    super(userMessage);
    this.name = 'ChatError';
  }
}

/** Renders saved history + the new message as the single transcript Gemini sees. */
function buildPrompt(userMessage: string, history: ChatMessage[]): string {
  const recent = history.slice(-MAX_HISTORY_TURNS);
  const lines = recent.map((m) => `${m.role === 'user' ? 'User' : 'Assistant'}: ${m.body}`);
  lines.push(`User: ${userMessage}`, 'Assistant:');
  return lines.join('\n');
}

export async function sendChatMessage(
  client: GeminiClient,
  params: { userMessage: string; history: ChatMessage[] },
): Promise<string> {
  const userMessage = params.userMessage.trim();
  if (!userMessage) {
    throw new ChatError('invalid_input', 'Message cannot be empty.');
  }

  try {
    const reply = await client.generateText({
      prompt: buildPrompt(userMessage, params.history),
      systemInstruction: SYSTEM_INSTRUCTION,
      temperature: 0.6,
    });
    return reply || "Sorry, I couldn't come up with a reply there — try asking again.";
  } catch (error) {
    if (error instanceof GeminiError) {
      throw new ChatError('ai_unavailable', error.userMessage);
    }
    throw error;
  }
}
