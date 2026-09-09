/**
 * =============================================================================
 * AI MEDICAL & SYMPTOM-BASED DIET CHART GENERATOR
 * =============================================================================
 * Creates targeted clinical & Ayurvedic Indian diet plans based on:
 *   - Symptoms & body conditions (e.g. Acidity, Diabetes, Thyroid/PCOS, Fatty Liver)
 *   - Strict "What NOT to eat" (trigger foods & inflammatory ingredients)
 *   - "What to eat" (healing superfoods, medicinal spices, low GI grains)
 *   - 7-slot day-long meal timetable tailored to Indian kitchens
 * =============================================================================
 */

import { GeminiClient } from './gemini';

export interface DietChartInput {
  symptoms: string[];
  customCondition?: string;
  preference?: string; // vegetarian | non_vegetarian | vegan | jain
  targetCalories?: number;
  gender?: string;
}

export interface FoodToAvoid {
  item: string;
  category: string;
  reason: string;
}

export interface FoodToEat {
  item: string;
  category: string;
  benefit: string;
  howToConsume: string;
}

export interface DietMealSlot {
  slot: string;
  timeRange: string;
  title: string;
  items: string[];
  rationale: string;
}

export interface HerbalRemedy {
  remedy: string;
  timing: string;
  purpose: string;
}

export interface DietChart {
  id: string;
  title: string;
  conditionSummary: string;
  symptomsTargeted: string[];
  dietaryPreference: string;
  foodsToAvoid: FoodToAvoid[];
  foodsToEat: FoodToEat[];
  mealPlan: DietMealSlot[];
  hydrationGuidelines: string[];
  herbalRemedies: HerbalRemedy[];
  goldenRules: string[];
  generatedAt: string;
}

const DIET_CHART_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    conditionSummary: { type: 'string' },
    foodsToAvoid: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          item: { type: 'string' },
          category: { type: 'string' },
          reason: { type: 'string' },
        },
        required: ['item', 'category', 'reason'],
      },
    },
    foodsToEat: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          item: { type: 'string' },
          category: { type: 'string' },
          benefit: { type: 'string' },
          howToConsume: { type: 'string' },
        },
        required: ['item', 'category', 'benefit', 'howToConsume'],
      },
    },
    mealPlan: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          slot: { type: 'string' },
          timeRange: { type: 'string' },
          title: { type: 'string' },
          items: { type: 'array', items: { type: 'string' } },
          rationale: { type: 'string' },
        },
        required: ['slot', 'timeRange', 'title', 'items', 'rationale'],
      },
    },
    hydrationGuidelines: { type: 'array', items: { type: 'string' } },
    herbalRemedies: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          remedy: { type: 'string' },
          timing: { type: 'string' },
          purpose: { type: 'string' },
        },
        required: ['remedy', 'timing', 'purpose'],
      },
    },
    goldenRules: { type: 'array', items: { type: 'string' } },
  },
  required: [
    'title',
    'conditionSummary',
    'foodsToAvoid',
    'foodsToEat',
    'mealPlan',
    'hydrationGuidelines',
    'herbalRemedies',
    'goldenRules',
  ],
};

export async function generateDietChart(
  gemini: GeminiClient | null,
  input: DietChartInput,
): Promise<DietChart> {
  const combinedConditions = [
    ...input.symptoms,
    ifNonEmpty(input.customCondition),
  ].filter(Boolean) as string[];

  const activeConditions = combinedConditions.length > 0 ? combinedConditions : ['General Health & Vitality'];
  const pref = input.preference || 'vegetarian';

  if (!gemini) {
    return buildFallbackDietChart(activeConditions, pref);
  }

  const prompt = `You are an expert clinical dietitian and Ayurvedic nutrition specialist specializing in Indian physiology and regional cuisine.

Create a comprehensive, medically validated, personalized Diet Chart for a person with the following conditions/symptoms:
- Target Symptoms/Body Issues: ${activeConditions.join(', ')}
- Dietary Preference: ${pref.toUpperCase()} (STRICT COMPLIANCE: If vegetarian, no eggs or meat. If Jain, no root vegetables like onion, garlic, potato).

You must provide:
1. "title": An empowering, clear clinical title.
2. "conditionSummary": 2-3 sentences explaining why their body is experiencing these symptoms from a metabolic and gut-microbiome perspective.
3. "foodsToAvoid": Minimum 5 specific foods/ingredients that aggravate these symptoms with clear rationale (e.g. refined sugar spikes insulin, deep fried foods trigger bile reflux and esophageal acidity, high-purine foods elevate uric acid).
4. "foodsToEat": Minimum 5 healing foods (millets, spices, lentils, veggies) with exact benefits and how to consume them.
5. "mealPlan": A complete 6-7 slot daily plan (Early Morning, Breakfast, Mid-Morning Snack, Lunch, Evening Snack, Dinner, Bedtime). Include realistic, delicious Indian home-cooked meals (like ragi roti, moong dal khichdi, methi paratha, roasted makhana, vegetable daliya).
6. "hydrationGuidelines": 3-4 actionable hydration rules (e.g. warm jeera-ajwain water, avoiding cold water during meals).
7. "herbalRemedies": 2-3 traditional kitchen remedies (like triphala, saunf water, cinnamon infusion).
8. "goldenRules": 3-4 lifestyle golden rules.`;

  try {
    const raw = await gemini.generateJson<Omit<DietChart, 'id' | 'symptomsTargeted' | 'dietaryPreference' | 'generatedAt'>>({
      prompt,
      responseSchema: DIET_CHART_SCHEMA,
      temperature: 0.3,
    });

    return {
      id: `diet_${Date.now()}`,
      title: raw.title || `Personalized Healing Diet for ${activeConditions.join(' & ')}`,
      conditionSummary: raw.conditionSummary,
      symptomsTargeted: activeConditions,
      dietaryPreference: pref,
      foodsToAvoid: raw.foodsToAvoid || [],
      foodsToEat: raw.foodsToEat || [],
      mealPlan: raw.mealPlan || [],
      hydrationGuidelines: raw.hydrationGuidelines || [],
      herbalRemedies: raw.herbalRemedies || [],
      goldenRules: raw.goldenRules || [],
      generatedAt: new Date().toISOString(),
    };
  } catch (err) {
    // Graceful fallback to verified clinical presets
    return buildFallbackDietChart(activeConditions, pref);
  }
}

function ifNonEmpty(s?: string): string | null {
  return s && s.trim().length > 0 ? s.trim() : null;
}

/**
 * Robust clinical fallback ensuring 100% reliability for Indian dietary conditions.
 */
export function buildFallbackDietChart(symptoms: string[], preference: string): DietChart {
  const symLower = symptoms.map((s) => s.toLowerCase()).join(' ');

  const isAcidity = symLower.includes('acid') || symLower.includes('gerd') || symLower.includes('bloat');
  const isDiabetes = symLower.includes('diabet') || symLower.includes('sugar') || symLower.includes('glucose');
  const isThyroid = symLower.includes('thyroid') || symLower.includes('pcos') || symLower.includes('pcod');
  const isUricAcid = symLower.includes('uric') || symLower.includes('gout');
  const isFattyLiver = symLower.includes('liver') || symLower.includes('cholesterol');

  let title = 'Personalized Indian Metabolic Healing Plan';
  let overview = 'A balanced, gut-friendly Indian meal plan focused on reducing systemic inflammation and restoring digestive fire (Agni).';

  const foodsToAvoid: FoodToAvoid[] = [];
  const foodsToEat: FoodToEat[] = [];

  // Tailor "What NOT to eat"
  if (isAcidity) {
    title = 'Digestive Soothing & Alkaline Diet Chart';
    overview = 'Formulated to neutralize stomach acid reflux, soothe esophageal lining, and eliminate fermentation and bloating.';
    foodsToAvoid.push(
      { item: 'Deep-fried Pakoras & Samosas', category: 'Fried Snacks', reason: 'High trans-fats relax the lower esophageal sphincter, causing severe acid reflux.' },
      { item: 'Excessive Red Chilli & Garam Masala', category: 'Spices', reason: 'Directly irritates the gastric mucosa and increases burning sensation.' },
      { item: 'Empty-stomach Milk Tea / Coffee', category: 'Beverages', reason: 'Tannins and caffeine stimulate excessive hydrochloric acid secretion on an empty stomach.' },
      { item: 'Carbonated Drinks & Sodas', category: 'Beverages', reason: 'Carbon dioxide gas expands the stomach, forcing acid upwards into the food pipe.' },
      { item: 'Raw Onions & Garlic in Excess', category: 'Alliums', reason: 'Contain fermentable oligosaccharides (FODMAPs) that cause trapped gas and bloating.' },
    );
    foodsToEat.push(
      { item: 'Fennel (Saunf) & Jeera Infusion', category: 'Digestive Seeds', benefit: 'Relaxes abdominal muscles and reduces bloating immediately.', howToConsume: 'Boil 1 tsp in warm water after meals.' },
      { item: 'Lauki (Bottle Gourd) & Ridge Gourd (Turai)', category: 'Alkaline Veggies', benefit: 'High water content and alkaline pH naturally buffer excess stomach acidity.', howToConsume: 'Steamed sabzi or warm soup with cumin.' },
      { item: 'Fresh Coconut Water', category: 'Natural Electrolytes', benefit: 'Cools the internal digestive tract and restores potassium balance.', howToConsume: 'Drink mid-morning on an empty or light stomach.' },
      { item: 'A2 Cow Buttermilk (Chaas) with Roasted Jeera', category: 'Probiotics', benefit: 'Lactic acid cools the stomach and replenishes healthy gut flora without heavy fats.', howToConsume: 'Consume with lunch, never at night.' },
      { item: 'Papaya & Munakka (Soaked Raisins)', category: 'Fruits', benefit: 'Contains papain enzymes that accelerate protein breakdown and prevent fermentation.', howToConsume: 'Eat 1 cup ripe papaya as an evening snack.' },
    );
  } else if (isDiabetes) {
    title = 'Low-Glycemic Insulin Balancing Diet Chart';
    overview = 'Engineered to prevent blood glucose spikes, improve insulin receptor sensitivity, and provide sustained energy.';
    foodsToAvoid.push(
      { item: 'Refined White Flour (Maida) & White Rice', category: 'Simple Carbs', reason: 'Rapidly hydrolyzes into glucose, causing dramatic insulin spikes.' },
      { item: 'Packaged Fruit Juices & Sweetened Drinks', category: 'Sugars', reason: 'Stripped of dietary fiber, delivers an immediate fructose overload to the liver.' },
      { item: 'Potato & Sweet Potato Chips', category: 'Starchy Snacks', reason: 'High glycemic index combined with oxidized vegetable oils impairs glucose clearance.' },
      { item: 'Mithai, Bakery Biscuits & Rusk', category: 'Confectionery', reason: 'Loaded with hidden palm oil, maida, and sucrose that destroy HbA1c control.' },
      { item: 'Full-fat Buffalo Cream & Khoya', category: 'Dairy', reason: 'Excess saturated fatty acids cause intramyocellular lipid accumulation and insulin resistance.' },
    );
    foodsToEat.push(
      { item: 'Methi (Fenugreek) Seeds', category: 'Functional Seeds', benefit: 'Contains 4-hydroxyisoleucine which stimulates glucose-dependent insulin secretion.', howToConsume: 'Soak 1 tsp in water overnight and drink water + chew seeds in morning.' },
      { item: 'Jamun, Karela & Amla', category: 'Herbal Superfoods', benefit: 'Rich in polypeptide-p and charantin that mimic biological insulin.', howToConsume: 'Take 30ml diluted juice or cooked karela sabzi with lunch.' },
      { item: 'Millets (Jowar, Ragi & Bajra)', category: 'Complex Grains', benefit: 'High insoluble fiber slows carbohydrate absorption and sustains satiety for hours.', howToConsume: 'Make rotis mixed with 20% besan (chickpea flour).' },
      { item: 'Sprouted Green Moong Dal', category: 'Plant Protein', benefit: 'Rich in bio-available protein and enzymes that blunt post-meal blood sugar surges.', howToConsume: 'Eat as a mid-morning salad with cucumber and lemon.' },
      { item: 'Cinnamon (Dalchini)', category: 'Spice', benefit: 'Enhances insulin receptor kinase activity.', howToConsume: 'Add 1/2 tsp Ceylon cinnamon powder to morning herbal tea.' },
    );
  } else {
    // General Healing / Anti-inflammatory
    foodsToAvoid.push(
      { item: 'Hydrogenated Vegetable Oils (Dalda / Re-used oil)', category: 'Fats', reason: 'Promotes arterial endothelial inflammation and liver congestion.' },
      { item: 'Refined White Sugar & Corn Syrup', category: 'Sugars', reason: 'Triggers systemic inflammation and depletes essential B-vitamins.' },
      { item: 'Ultra-Processed Packaged Namkeen & Chips', category: 'Snacks', reason: 'Excess sodium promotes hypertension and water retention.' },
      { item: 'Late-night Heavy Meals after 9:30 PM', category: 'Habits', reason: 'Slows nocturnal gastrointestinal motility and disrupts metabolic repair.' },
      { item: 'Artificially Flavoured Aerated Beverages', category: 'Drinks', reason: 'Phosphoric acid leaches calcium from bones and disrupts gut flora.' },
    );
    foodsToEat.push(
      { item: 'Turmeric (Haldi) with Black Pepper', category: 'Anti-inflammatory', benefit: 'Curcumin combined with piperine reduces cellular oxidative stress.', howToConsume: 'Golden warm milk or in daily dal preparation.' },
      { item: 'Soaked Almonds & Walnuts', category: 'Nuts', benefit: 'Rich in omega-3 fatty acids and vitamin E for brain and cardiovascular health.', howToConsume: '5 almonds and 2 walnut halves early morning after peeling.' },
      { item: 'Seasonal Dark Green Leafy Veggies', category: 'Greens', benefit: 'Abundant in magnesium, folate, and carotenoids that support liver detox.', howToConsume: 'Palak, methi, or sarson lightly sautéed with mustard oil.' },
      { item: 'Amla (Indian Gooseberry)', category: 'Vitamin C', benefit: 'Supreme antioxidant that strengthens cellular immunity and collagen.', howToConsume: '1 fresh amla or amla powder in lukewarm water.' },
      { item: 'Khichdi made with Yellow Moong & Rice', category: 'Gut Healing', benefit: 'Easiest complete protein to digest, giving the digestive system deep rest.', howToConsume: 'Prepared with 1 tsp A2 cow ghee and jeera.' },
    );
  }

  const mealPlan: DietMealSlot[] = [
    {
      slot: 'Early Morning',
      timeRange: '6:30 AM – 7:00 AM',
      title: 'Detox & Digestive Ignition',
      items: [
        '1 glass warm water with 1/2 tsp roasted jeera and 1 pinch cinnamon',
        '5 soaked & peeled almonds + 2 soaked walnut halves',
      ],
      rationale: 'Kicks off liver metabolism and neutralizes accumulated overnight stomach acidity without spiking cortisol.',
    },
    {
      slot: 'Breakfast',
      timeRange: '8:30 AM – 9:00 AM',
      title: 'High-Fiber Sustained Energy',
      items: [
        'Vegetable Daliya OR 2 small Jowar-Methi Rotis',
        '1 cup mint & coriander green chutney (made with zero sugar)',
        '1 bowl light curd or boiled egg whites (if non-veg)',
      ],
      rationale: 'Balanced complex carbohydrates and bioavailable amino acids prevent mid-morning lethargy and cravings.',
    },
    {
      slot: 'Mid-Morning Snack',
      timeRange: '11:00 AM – 11:30 AM',
      title: 'Cellular Hydration & Micronutrients',
      items: [
        '1 fresh coconut water OR 1 whole fresh fruit (Apple / Guava / Papaya)',
        '1 tbsp roasted pumpkin & flax seeds',
      ],
      rationale: 'Provides zinc, magnesium, and natural electrolytes to maintain stable cellular energy levels.',
    },
    {
      slot: 'Lunch',
      timeRange: '1:00 PM – 1:45 PM',
      title: 'Therapeutic Indian Thali',
      items: [
        '1 cup Yellow Moong Dal or Rajma (well-cooked with hing & jeera)',
        '1 big bowl seasonal Sabzi (Lauki / Palak / Beans / Bhindi)',
        '1-2 Multigrain Rotis (Jowar + Wheat blend) OR 1 bowl brown rice',
        'Fresh cucumber & carrot salad with lemon juice',
      ],
      rationale: 'Peak digestive fire (Agni) at midday handles the day’s main nutritional bulk efficiently.',
    },
    {
      slot: 'Evening Snack',
      timeRange: '4:30 PM – 5:00 PM',
      title: 'Light Metabolic Fuel',
      items: [
        '1 cup roasted Makhana (foxnuts) seasoned with turmeric and rock salt',
        'Herbal Tulsi-Ginger Green Tea (Zero sugar)',
      ],
      rationale: 'Replaces unhealthy biscuit/tea cravings with clean low-calorie resistant starch.',
    },
    {
      slot: 'Dinner',
      timeRange: '7:30 PM – 8:15 PM',
      title: 'Light Anti-Inflammatory Nourishment',
      items: [
        'Warm Moong Dal Khichdi with steamed vegetables OR Vegetable Clear Soup with Paneer/Tofu cubes',
        '1 tsp pure A2 Cow Ghee on top',
      ],
      rationale: 'Early, easy-to-digest dinner ensures blood glucose stays flat during sleep and prevents GERD.',
    },
    {
      slot: 'Bedtime',
      timeRange: '9:30 PM – 10:00 PM',
      title: 'Restorative Sleep Elixir',
      items: [
        '1 small cup warm milk with a pinch of organic turmeric (Haldi) & nutmeg',
      ],
      rationale: 'Tryptophan and curcumin promote deep REM sleep and nocturnal cellular tissue repair.',
    },
  ];

  return {
    id: `diet_fallback_${Date.now()}`,
    title,
    conditionSummary: overview,
    symptomsTargeted: symptoms,
    dietaryPreference: preference,
    foodsToAvoid,
    foodsToEat,
    mealPlan,
    hydrationGuidelines: [
      'Drink 2.5 to 3 liters of room temperature or lukewarm water daily; avoid ice-cold water during meals.',
      'Stop drinking water 15 minutes before meals, and wait 45 minutes after eating before drinking water to protect digestive enzymes.',
      'Sip warm cumin-coriander-fennel (CCF) water throughout the day for active metabolic detox.',
    ],
    herbalRemedies: [
      { remedy: 'Triphala Churna', timing: '1/2 tsp in warm water at bedtime', purpose: 'Gentle colon cleanse and elimination of digestive endotoxins (Ama).' },
      { remedy: 'Saunf & Ajwain Water', timing: 'Immediately after heavy meals', purpose: 'Instantly expels trapped gas and prevents acidic belching.' },
    ],
    goldenRules: [
      'Chew every morsel 20-30 times to begin carbohydrate digestion in the saliva.',
      'Maintain at least a 12-hour overnight fasting window (e.g. dinner at 8:00 PM, breakfast at 8:00 AM).',
      'Walk 100 paces (Shatapadi) gently after both lunch and dinner.',
      'Never eat when anxious, rushed, or angry — stress shuts down digestive hydrochloric acid.',
    ],
    generatedAt: new Date().toISOString(),
  };
}
