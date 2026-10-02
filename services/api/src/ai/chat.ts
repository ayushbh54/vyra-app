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
- Language: If the athlete speaks in Hindi or Hinglish, reply warmly in natural, relatable Hinglish (e.g. "Badiya progress hai!", "Aapka workout plan bilkul customized hai"). Otherwise reply in clear, inspiring English.
- 3D Virtual Coach: You are synchronized with the athlete's 3D AI Coach (Remy/Megan). When recommending exercises, reference the 3D animated demonstration in the app.
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

export interface UserHealthContext {
  name?: string;
  age?: number;
  gender?: string;
  bodyType?: string;           // 'athletic'|'lean'|'muscular'
  bmi?: number | string;
  goal?: string;               // 'lose_weight'|'gain_weight'|'general_wellness'
  physicalConsiderations?: string; // injuries, disabilities
  labMarkers?: Record<string, number>; // e.g. {hemoglobin: 11.2, glucose: 95}
  labInsights?: string[];      // key lab findings
  currentDiet?: string;        // vegetarian/vegan/non-veg
  preferredCuisine?: string;   // indian/continental etc
  watchHeartRate?: number;     // current HR from smartwatch
  watchSteps?: number;         // today's steps
  watchSpo2?: number;          // current SpO2
  todayExercises?: string[];   // exercises done today
  recommendedExercises?: string[]; // today's plan exercises
  fitnessLevel?: string;       // beginner/intermediate/advanced
}

function buildPersonalContextBlock(ctx: UserHealthContext): string {
  const lines: string[] = ['=== ATHLETE PERSONAL PROFILE ==='];
  
  if (ctx.name) lines.push(`Name: ${ctx.name}`);
  if (ctx.age) lines.push(`Age: ${ctx.age} years`);
  if (ctx.gender) lines.push(`Gender: ${ctx.gender}`);
  if (ctx.bodyType) lines.push(`Body Type: ${ctx.bodyType}`);
  if (ctx.bmi !== undefined && ctx.bmi !== null) {
    const formattedBmi = typeof ctx.bmi === 'number' ? ctx.bmi.toFixed(1) : String(ctx.bmi);
    lines.push(`BMI: ${formattedBmi}`);
  }
  if (ctx.goal) lines.push(`Goal: ${ctx.goal.replace(/_/g,' ')}`);
  if (ctx.fitnessLevel) lines.push(`Fitness Level: ${ctx.fitnessLevel}`);
  if (ctx.physicalConsiderations) lines.push(`Physical Considerations: ${ctx.physicalConsiderations}`);
  if (ctx.currentDiet) lines.push(`Diet Type: ${ctx.currentDiet}`);
  
  if (ctx.watchHeartRate || ctx.watchSteps || ctx.watchSpo2) {
    lines.push('\n=== LIVE SMARTWATCH DATA ===');
    if (ctx.watchHeartRate) lines.push(`Heart Rate: ${ctx.watchHeartRate} bpm`);
    if (ctx.watchSpo2) lines.push(`SpO2: ${ctx.watchSpo2}%`);
    if (ctx.watchSteps) lines.push(`Steps Today: ${ctx.watchSteps}`);
  }
  
  if (ctx.labMarkers && Object.keys(ctx.labMarkers).length > 0) {
    lines.push('\n=== RECENT LAB MARKERS ===');
    for (const [k, v] of Object.entries(ctx.labMarkers)) {
      lines.push(`${k}: ${v}`);
    }
  }
  if (ctx.labInsights?.length) {
    lines.push('Lab Insights: ' + ctx.labInsights.join('; '));
  }
  
  if (ctx.todayExercises?.length) {
    lines.push('\n=== TODAY\'S ACTIVITY ===');
    lines.push(`Completed: ${ctx.todayExercises.join(', ')}`);
  }
  if (ctx.recommendedExercises?.length) {
    lines.push(`Planned: ${ctx.recommendedExercises.join(', ')}`);
  }
  
  lines.push('\n=== INSTRUCTIONS ===');
  lines.push('Use ALL the above athlete data to give hyper-personalized, specific advice.');
  lines.push('Reference their actual numbers (HR, BMI, lab values) in responses.');
  lines.push('Contraindicate exercises that conflict with their physical considerations.');
  lines.push('Align diet advice with their diet type and lab markers.');
  lines.push('If watch HR > 100 at rest, suggest recovery. If SpO2 < 95, flag it.');
  
  return lines.join('\n');
}

/** Renders saved history + the new message as the single transcript Gemini sees. */
function buildPrompt(userMessage: string, history: ChatMessage[], userContext?: UserHealthContext): string {
  const recent = history.slice(-MAX_HISTORY_TURNS);
  const lines = recent.map((m) => `${m.role === 'user' ? 'User' : 'Assistant'}: ${m.body}`);
  
  // Grounding from verified exercise dataset
  const grounding = buildGeminiExerciseGrounding(userMessage);
  if (grounding) {
    lines.push(`[System Grounding Context]:\n${grounding}`);
  }

  if (userContext) {
    lines.push(buildPersonalContextBlock(userContext));
  }

  lines.push(`User: ${userMessage}`, 'Assistant:');
  return lines.join('\n');
}

export async function sendChatMessage(
  client: GeminiClient,
  message: string,
  history: ChatMessage[],
  userContext?: UserHealthContext
): Promise<string> {
  const userMessage = message.trim();
  if (!userMessage) {
    throw new ChatError('invalid_input', 'Message cannot be empty.');
  }

  try {
    const reply = await client.generateText({
      prompt: buildPrompt(userMessage, history, userContext),
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
