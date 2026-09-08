/**
 * =============================================================================
 * BARCODE LOOKUP
 * =============================================================================
 * Resolves a scanned barcode to nutrition facts, per 100g, from open data.
 *
 * Provider order and why:
 *   1. OpenFoodFacts — free, keyless, no auth dance. Tried first, always.
 *   2. FatSecret — NOT implemented (see the header on tryFatSecret below).
 *   3. null — the route turns this into a 404. A missing product is an
 *      honest "we don't have this one," not a fabricated nutrition guess.
 *
 * Zero-dependency: uses Node 20's global `fetch`, nothing else.
 * =============================================================================
 */

export interface BarcodeResult {
  name: string;
  brand?: string;
  caloriesPer100g: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  allergens: string[];
  source: 'openfoodfacts' | 'fatsecret';
}

// -----------------------------------------------------------------------------
// OpenFoodFacts
// -----------------------------------------------------------------------------

interface OpenFoodFactsNutriments {
  'energy-kcal_100g'?: number;
  proteins_100g?: number;
  carbohydrates_100g?: number;
  fat_100g?: number;
}

interface OpenFoodFactsResponse {
  status?: number; // 1 = found, 0 = not found
  product?: {
    product_name?: string;
    brands?: string; // comma-separated; OFF's own convention
    allergens_tags?: string[]; // e.g. ["en:milk", "en:gluten"]
    nutriments?: OpenFoodFactsNutriments;
  };
}

/** Strips OpenFoodFacts' locale prefix, e.g. "en:milk" -> "milk". */
function cleanAllergenTag(tag: string): string {
  const idx = tag.indexOf(':');
  return idx >= 0 ? tag.slice(idx + 1) : tag;
}

async function tryOpenFoodFacts(
  barcode: string,
  env: NodeJS.ProcessEnv,
): Promise<BarcodeResult | null> {
  const baseUrl = (env.OPENFOODFACTS_BASE_URL ?? 'https://world.openfoodfacts.org').replace(/\/$/, '');
  const url = `${baseUrl}/api/v2/product/${encodeURIComponent(barcode)}.json`;

  let response: Response;
  try {
    response = await fetch(url, {
      headers: {
        // OFF asks integrators to identify themselves; an unset UA is one of
        // the more common reasons a working integration silently starts 403ing.
        'user-agent': 'VYRA/1.0 (+https://vyra.app)',
      },
    });
  } catch {
    // Network failure — treated as "no match", never thrown into the route.
    // A flaky lookup should degrade to "not found", not a 500.
    return null;
  }

  if (!response.ok) return null;

  let json: OpenFoodFactsResponse;
  try {
    json = (await response.json()) as OpenFoodFactsResponse;
  } catch {
    return null;
  }

  if (json.status !== 1 || !json.product) return null;
  const p = json.product;
  const n = p.nutriments ?? {};

  const name = p.product_name?.trim();
  if (!name) return null; // OFF sometimes has a barcode entry with no name filled in yet

  return {
    name,
    brand: p.brands?.split(',')[0]?.trim() || undefined,
    caloriesPer100g: n['energy-kcal_100g'] ?? 0,
    proteinG: n.proteins_100g ?? 0,
    carbsG: n.carbohydrates_100g ?? 0,
    fatG: n.fat_100g ?? 0,
    allergens: (p.allergens_tags ?? []).map(cleanAllergenTag),
    source: 'openfoodfacts',
  };
}

// -----------------------------------------------------------------------------
// FatSecret — INTENTIONALLY NOT IMPLEMENTED
// -----------------------------------------------------------------------------

/**
 * FatSecret's OAuth2 client-credentials token exchange (POST
 * https://oauth.fatsecret.com/connect/token, Basic auth, grant_type=
 * client_credentials) is well documented and would be safe to wire up.
 *
 * The barcode lookup itself is not: it needs a first call to resolve
 * barcode -> food_id (food/barcode/find-id, whose required `barcode_type`
 * and response shape vary by account tier and region) and a second call to
 * food.get for the actual nutrients — a two-call contract we cannot verify
 * without a live FatSecret account. gemini.ts's header explains why this
 * codebase refuses to guess an undocumented request shape rather than risk
 * silently returning wrong data (see gemini.ts, "WHICH API, AND WHY BOTH");
 * the same reasoning applies here, and is worse here — wrong nutrition
 * numbers land directly in a person's food diary.
 *
 * OpenFoodFacts alone covers the large majority of packaged-food barcodes,
 * so per the brief this provider is left as a documented no-op: it never
 * throws, and returns null (falling through to the 404 in the route)
 * whether or not FATSECRET_CLIENT_ID/SECRET are configured. Fill in the two
 * real calls here once you have a live key to verify the contract against.
 */
async function tryFatSecret(
  barcode: string,
  env: NodeJS.ProcessEnv,
): Promise<BarcodeResult | null> {
  if (!env.FATSECRET_CLIENT_ID || !env.FATSECRET_CLIENT_SECRET) {
    return null; // not configured — skip silently, never throw
  }
  void barcode;
  return null; // see header note above
}

// -----------------------------------------------------------------------------
// Public API
// -----------------------------------------------------------------------------

export async function lookupBarcode(
  barcode: string,
  env: NodeJS.ProcessEnv = process.env,
): Promise<BarcodeResult | null> {
  const code = barcode.trim();
  if (!code) return null;

  const fromOff = await tryOpenFoodFacts(code, env);
  if (fromOff) return fromOff;

  return tryFatSecret(code, env);
}
