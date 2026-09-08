/**
 * =============================================================================
 * AI EVENT DISCOVERY
 * =============================================================================
 * Uses Gemini to suggest real-world fitness events (races, rides, yoga
 * meetups...) for a city, so the Events tab isn't limited to the two
 * hand-seeded rows forever.
 *
 * Honesty constraint, and why it shapes this whole module: Gemini's text
 * generation has no live connection to an events calendar. It can name
 * plausible, well-known recurring events (a city's annual marathon, a
 * well-known cycling club ride) from its training data, but it CANNOT
 * guarantee a specific date is still correct, still happening, or even
 * still exists. Every suggestion this module returns is therefore marked
 * `source: 'ai_suggested'` end-to-end — the Store's real `events` table
 * (registrations, seed data) is never silently overwritten with unverified
 * AI output. A person can decide to register only after the app has been
 * honest that this needs a human check.
 * =============================================================================
 */

import { GeminiClient, GeminiError } from './gemini';

export interface SuggestedEvent {
  title: string;
  sport: string;
  approximateTiming: string; // e.g. "Late January, annually" — deliberately not a hard date
  location: string;
  description: string;
  verifyNote: string; // always populated — never let this look more certain than it is
}

interface RawEventSuggestions {
  events: SuggestedEvent[];
}

const EVENT_SCHEMA = {
  type: 'object',
  properties: {
    events: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          sport: { type: 'string' },
          approximateTiming: { type: 'string' },
          location: { type: 'string' },
          description: { type: 'string' },
        },
        required: ['title', 'sport', 'approximateTiming', 'location', 'description'],
      },
    },
  },
  required: ['events'],
} as const;

export class EventDiscoveryError extends Error {
  constructor(readonly kind: 'invalid_input' | 'ai_unavailable', message: string) {
    super(message);
    this.name = 'EventDiscoveryError';
  }
}

export async function discoverEvents(
  client: GeminiClient,
  params: { city: string; sport?: string },
): Promise<SuggestedEvent[]> {
  const city = params.city.trim();
  if (!city) {
    throw new EventDiscoveryError('invalid_input', 'Tell us a city to look for events near.');
  }
  const sportLine = params.sport ? ` Focus on ${params.sport} events specifically.` : '';

  try {
    const raw = await client.generateJson<RawEventSuggestions>({
      systemInstruction:
        'You suggest real, well-known recurring fitness events (marathons, rides, yoga ' +
        'meetups, etc.) for a given city, from general knowledge. You do not have live ' +
        'internet access and do not know today\'s date. Never invent an event that does not ' +
        'plausibly exist. Prefer events you are confident are real annual fixtures over ' +
        'obscure or uncertain ones — a shorter, honest list is better than a padded one.',
      prompt:
        `Suggest up to 5 real fitness events (races, rides, yoga meetups, community ` +
        `workouts) that plausibly happen in or near ${city}.${sportLine} For each, give an ` +
        `approximate timing description in words (e.g. "Late January, annually") — never a ` +
        `specific year or exact date, since you cannot verify either.`,
      responseSchema: EVENT_SCHEMA,
      temperature: 0.4,
    });

    return raw.events.slice(0, 5).map((e) => ({
      ...e,
      verifyNote: 'AI-suggested from general knowledge — confirm the date and that ' +
        'registration is open before making plans.',
    }));
  } catch (error) {
    if (error instanceof GeminiError) {
      throw new EventDiscoveryError('ai_unavailable', error.userMessage);
    }
    throw error;
  }
}
