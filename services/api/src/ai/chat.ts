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
import { buildGeminiExerciseGrounding } from '../content/exercise_dataset';

export type ChatRole = StoredChatMessage['role'];
export type ChatMessage = Pick<StoredChatMessage, 'role' | 'body'>;

// How many past turns are folded into the prompt. Bounds prompt size/cost; a
// fitness chat rarely needs more than this to stay coherent turn-to-turn.
const MAX_HISTORY_TURNS = 20;

const SYSTEM_INSTRUCTION = `You are VYRA Coach — an intelligent, empathetic AI fitness and nutrition coach inside India's premier fitness app.

You help athletes with:
- Workout doubts, exercise form guidance, and adaptive/seated exercise modifications for differently-abled athletes.
- Diet and nutrition advice tailored to Indian cuisines (millets, lentils, spices, regional staples).
- Supportive, science-backed and Ayurvedic dietary guidance when users mention symptoms or conditions (e.g. liver health/fatty liver, diabetes/blood sugar, acidity/GERD, thyroid, high uric acid, joint pain):
  * Always provide practical:
    1. "Foods to Eat / Include" (e.g. for liver: amla, turmeric water, green leafy vegetables, papayas, walnuts, garlic, oats).
    2. "Foods to Strictly Avoid" (e.g. deep-fried pakoras, alcohol, high-fructose syrups, trans fats, refined maida).
    3. "Daily Habit / Hydration Tip" (warm water, light walking after meals, circadian meal timing).
  * Always conclude condition-related diet answers with a supportive wellness reminder: "These dietary tips support natural wellness. Always keep your treating physician or gastroenterologist informed about your routine."
- Recovery, sleep, hydration, and explaining logged workouts and streaks.

Rules:
- Never diagnose a medical condition or prescribe pharmaceutical drugs/dosages.
- Do not refuse nutritional coaching when a user asks what to eat or avoid for liver, diabetes, acidity, etc. Provide wholesome, evidence-based food dos and don'ts.
- For acute red-flag medical emergencies (severe acute chest pain, uncontrolled bleeding, sudden fainting, severe acute trauma), advise immediate emergency clinical care.
- Keep answers practical, cleanly structured with bullet points, and encouraging.
- OUT-OF-FIELD RULE: If the question asked is completely unrelated to health, fitness, workouts, sports, exercises, nutrition, diet, physiology, human anatomy, wellness, or medical queries (e.g. asking about coding, politics, pop culture, stocks, history, homework, entertainment, etc.), you MUST reply with ONLY this EXACT string and nothing else:
"THE QUESTION ASKED IS OUT OF MY FIELD, KINDLY ASK ME QUESTIONS RELATED TO HEALTH , FITNESS , SPORTS AND MEDICAL QUERIES. THANK YOU !"`;

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
  
  // Grounding from verified exercise dataset
  const grounding = buildGeminiExerciseGrounding(userMessage);
  if (grounding) {
    lines.push(`[System Grounding Context]:\n${grounding}`);
  }

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
