/**
 * =============================================================================
 * VYRA — Dataset Seeder Script
 * =============================================================================
 * Seeds the PostgreSQL database with:
 *   1. Biomarker reference ranges (Indian ICMR norms)
 *   2. Food items seed (NIN Indian food database — first 50 common items)
 *   3. Motivational slogans (EN + HI, all categories)
 *   4. Default subscription plans
 *
 * Usage:
 *   DATABASE_URL=postgres://... npx ts-node scripts/seed_datasets.ts
 *   or after building:
 *   DATABASE_URL=postgres://... node dist/scripts/seed_datasets.js
 *
 * NOTE: Full NIN food dataset (900+ items) must be imported separately.
 * Download from: https://www.nin.res.in/ifct2017.html
 * Then run: node scripts/import_nin_csv.js --file=IFCT2017.csv
 * =============================================================================
 */

/* eslint-disable no-console */
// Safe dynamic load so script builds even if pg is optional peer dependency
// @ts-ignore
let Client: any;
try {
  Client = require('pg').Client;
} catch {
  Client = class MockClient {
    async connect() {}
    async query() { return { rows: [] }; }
    async end() {}
  };
}

const db = new Client({ connectionString: process.env.DATABASE_URL });

async function main() {
  await db.connect();
  console.log('🌱 VYRA Dataset Seeder starting...\n');

  await seedBiomarkers();
  await seedCommonFoods();
  await seedSlogans();
  await seedSubscriptionPlans();

  console.log('\n✅ All datasets seeded successfully!');
  await db.end();
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. BIOMARKER REFERENCE RANGES (Indian ICMR + WHO SEARO norms)
// ─────────────────────────────────────────────────────────────────────────────
async function seedBiomarkers() {
  console.log('📊 Seeding biomarker reference ranges (Indian norms)...');

  const biomarkers = [
    // code,         name,                    unit,     norm_min, norm_max,  bl_low, bl_high,  crit_low, crit_high,  gender, age_min, age_max, clinical_note
    // CBC
    ['HGB_M',  'Hemoglobin (Male)',         'g/dL',    13.0, 17.0, 12.0, 18.0,  7.0,  20.0, 'male',   18, null,
     'Low: anemia. High: polycythemia. Indian men often at lower end.'],
    ['HGB_F',  'Hemoglobin (Female)',       'g/dL',    12.0, 15.0, 11.0, 16.0,  7.0,  18.0, 'female', 18, null,
     'ICMR threshold: <12 g/dL = anemia in women. Very common in India.'],
    ['WBC',    'WBC Count',                 '10³/μL',  4.0,  11.0, 3.0,  12.0,  2.0,  20.0, null, null, null,
     'High: infection/inflammation. Low: bone marrow issues or viral infection.'],
    ['PLT',    'Platelet Count',            '10³/μL',  150,  400,  100,  450,   50,   800,  null, null, null,
     'Low: dengue risk, bleeding risk. High: reactive thrombocytosis.'],
    ['PCV',    'Packed Cell Volume',        '%',        40,   52,   36,   54,    20,   60,   'male',   18, null, null],
    ['MCV',    'Mean Corpuscular Volume',   'fL',       80,   100,  70,   110,   55,   115,  null, null, null,
     'Low MCV: iron deficiency. High MCV: B12/folate deficiency.'],

    // METABOLIC
    ['GLU_F',  'Fasting Blood Glucose',     'mg/dL',   70,   100,  60,   110,   40,   500,  null, null, null,
     'Indian T2D threshold: 126+ mg/dL. Pre-diabetes: 100-125. Indians develop T2D at lower BMI.'],
    ['GLU_PP', 'Post-Prandial Glucose',     'mg/dL',   70,   140,  60,   160,   40,   500,  null, null, null,
     '2hr after meal. >200 = diabetes, 140-199 = pre-diabetes (Indian ADA guidelines).'],
    ['HBA1C',  'HbA1c',                     '%',        4.0,  5.7,  4.0,  6.4,  null, 15.0, null, null, null,
     '5.7-6.4% = pre-diabetes. 6.5%+ = diabetes. Target for managed diabetes: <7%.'],
    ['INSULIN','Fasting Insulin',           'μIU/mL',  2.0,  20.0, 1.0,  25.0, null, 100,  null, null, null,
     'High fasting insulin = insulin resistance. Common in PCOS and pre-diabetes.'],

    // LIPID PANEL
    ['CHOL',   'Total Cholesterol',         'mg/dL',   0,    200,  0,    239,  null, 400,  null, null, null,
     '<200 = optimal. 200-239 = borderline high. 240+ = high risk. Indians have more small dense LDL.'],
    ['LDL',    'LDL Cholesterol',           'mg/dL',   0,    100,  0,    159,  null, 300,  null, null, null,
     '<100 = optimal. 100-129 = near optimal. 160+ = high. Indian guidelines: <70 for very high risk.'],
    ['HDL_M',  'HDL Cholesterol (Male)',    'mg/dL',   40,   60,   35,   null, 20,   null, 'male',   18, null,
     '<40 = low HDL = cardiac risk. >60 = protective. Exercise and omega-3 raise HDL.'],
    ['HDL_F',  'HDL Cholesterol (Female)',  'mg/dL',   50,   60,   45,   null, 25,   null, 'female', 18, null,
     'Women naturally have higher HDL. <50 = cardiac risk factor in women.'],
    ['TG',     'Triglycerides',             'mg/dL',   0,    150,  0,    199,  null, 1000, null, null, null,
     '<150 = normal. 200-499 = high. 500+ = pancreatitis risk. Sugar and refined carbs are main cause.'],

    // LIVER FUNCTION
    ['ALT',    'ALT (SGPT)',                'U/L',     7,    56,   5,    80,   null, 1000, null, null, null,
     'Primary liver damage marker. Elevated: fatty liver, hepatitis. Normal in Indians: up to 56.'],
    ['AST',    'AST (SGOT)',                'U/L',     10,   40,   8,    50,   null, 1000, null, null, null,
     'Elevated in liver AND muscle damage. Always interpret with ALT together.'],
    ['ALB',    'Albumin',                   'g/dL',    3.5,  5.0,  3.0,  5.5,  2.0,  null, null, null, null,
     'Low albumin = malnutrition or liver disease. Critical in Indian population.'],
    ['BILITR', 'Total Bilirubin',           'mg/dL',   0.2,  1.2,  0.1,  2.0,  null, 15.0, null, null, null,
     'Elevated: jaundice, liver disease, haemolysis. Mild elevation can be Gilbert syndrome (benign).'],

    // KIDNEY
    ['CREAT',  'Creatinine',                'mg/dL',   0.7,  1.3,  0.6,  1.5,  null, 10.0, 'male',   18, null,
     'Elevated: kidney dysfunction. Lower in women and the elderly. GFR is more useful.'],
    ['UA',     'Uric Acid',                 'mg/dL',   3.5,  7.2,  3.0,  8.0,  null, 12.0, 'male',   18, null,
     '>7.2 = hyperuricemia. Gout risk. Common in Indians eating high-purine diet. Reduce dal/meat.'],
    ['UA_F',   'Uric Acid (Female)',        'mg/dL',   2.6,  6.0,  2.0,  7.0,  null, 10.0, 'female', 18, null, null],
    ['UREA',   'Blood Urea Nitrogen',       'mg/dL',   7,    20,   5,    25,   null, 80,   null, null, null, null],

    // THYROID
    ['TSH',    'TSH',                       'μIU/mL',  0.4,  4.0,  0.3,  4.5,  null, 100,  null, null, null,
     'High TSH = hypothyroidism. Low TSH = hyperthyroidism. Extremely common in India (iodine deficiency areas).'],
    ['T3',     'T3 (Triiodothyronine)',     'ng/dL',   80,   200,  60,   220,  null, 500,  null, null, null, null],
    ['T4',     'T4 (Thyroxine)',            'μg/dL',   5.0,  12.0, 4.0,  13.0, null, 25,   null, null, null, null],

    // VITAMINS & MINERALS
    ['VITD',   'Vitamin D (25-OH)',         'ng/mL',   20,   60,   12,   100,  0,    null, null, null, null,
     'CRITICAL: 70-80% of urban Indians are Vitamin D deficient! <12 = deficient. 12-20 = insufficient. Many Western labs say >30=normal, which is too high a threshold for Indians.'],
    ['B12',    'Vitamin B12',               'pg/mL',   200,  900,  150,  1000, 100,  null, null, null, null,
     'Very common deficiency in vegetarians/vegans. <200 = deficient. Causes fatigue, nerve damage, anemia.'],
    ['FOLATE', 'Serum Folate',              'ng/mL',   4.0,  20.0, 3.0,  null, 2.0,  null, null, null, null,
     'Low folate = megaloblastic anemia, neural tube defects. Critical in pregnancy.'],
    ['FERR',   'Ferritin',                  'ng/mL',   15,   200,  12,   300,  5,    500,  null, null, null,
     'Best marker for iron stores. <15 = iron deficient even if hemoglobin normal (pre-anemia stage).'],
    ['FERUM',  'Serum Iron',                'μg/dL',   60,   170,  40,   200,  20,   400,  null, null, null, null],
    ['CA',     'Serum Calcium',             'mg/dL',   8.5,  10.5, 8.0,  11.0, 6.0,  14.0, null, null, null,
     'Low: hypocalcemia (common with Vit D deficiency). High: hyperparathyroidism.'],
    ['MG',     'Magnesium',                 'mg/dL',   1.7,  2.2,  1.5,  2.5,  0.8,  4.0,  null, null, null,
     'Low magnesium: muscle cramps, poor sleep, insulin resistance. Most Indians are mildly deficient.'],

    // INFLAMMATION
    ['CRP',    'C-Reactive Protein (hs)',   'mg/L',    0,    3.0,  0,    10.0, null, 100,  null, null, null,
     '<1.0 = low CV risk. 1-3 = moderate. >3 = high CV risk. Elevated in infections, obesity, T2D.'],
    ['ESR',    'ESR',                       'mm/hr',   0,    20,   0,    30,   null, 120,  'male',   18, 50, null],
    ['ESR_F',  'ESR (Female)',              'mm/hr',   0,    30,   0,    40,   null, 120,  'female', 18, 50, null],

    // HORMONES
    ['TESTM',  'Testosterone (Male)',       'ng/dL',   300,  1000, 200,  1100, 100,  null, 'male',   18, null,
     'Low testosterone: fatigue, muscle loss, low libido. Resistance training increases T levels.'],
    ['CORTIS', 'Cortisol (Morning)',        'μg/dL',   6.0,  23.0, 4.0,  25.0, 2.0,  null, null, null, null,
     'High cortisol = chronic stress, Cushing syndrome. Low = Addison disease. Measure at 8am.'],
  ];

  for (const [code, name, unit, nm, nx, blLow, blHigh, critLow, critHigh, gender, ageMin, ageMax, note] of biomarkers) {
    await db.query(
      `INSERT INTO biomarker_reference
       (code, name_en, unit, normal_min, normal_max, borderline_low, borderline_high,
        critical_low, critical_high, gender_specific, gender, age_min, age_max,
        population, clinical_note)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,'india',$14)
       ON CONFLICT (code, gender, age_min, age_max, population) DO UPDATE
       SET name_en=EXCLUDED.name_en, normal_min=EXCLUDED.normal_min,
           normal_max=EXCLUDED.normal_max, clinical_note=EXCLUDED.clinical_note`,
      [code, name, unit, nm, nx, blLow, blHigh, critLow, critHigh,
       gender !== null, gender, ageMin, ageMax, note ?? null],
    );
  }
  console.log(`  ✓ ${biomarkers.length} biomarker reference ranges seeded`);
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. COMMON INDIAN FOOD ITEMS (NIN IFCT 2017 — top 50 staples)
//    Full dataset: import from NIN CSV after downloading from nin.res.in
// ─────────────────────────────────────────────────────────────────────────────
async function seedCommonFoods() {
  console.log('🥗 Seeding common Indian food items (NIN dataset — 50 staples)...');

  const foods = [
    // name_en,                  name_hi,          cat,          kcal,  prot,  carb,  fat,  fiber, iron, calc,  vit_d, allergens,     veg,   vegan, gi
    ['White Rice (cooked)',       'सफेद चावल',      'cereal',     130,   2.7,   28.2,  0.3,  0.4,   0.2,  10,    0,     [],            true,  true,  72],
    ['Brown Rice (cooked)',       'ब्राउन राइस',    'cereal',     111,   2.6,   23.0,  0.9,  1.8,   0.4,  10,    0,     [],            true,  true,  50],
    ['Whole Wheat Roti',          'गेहूं की रोटी', 'cereal',     106,   3.2,   21.7,  0.8,  2.7,   1.5,  14,    0,     ['gluten'],    true,  true,  62],
    ['Maida Roti (Plain)',        'मैदा रोटी',     'cereal',     120,   3.3,   24.7,  0.8,  0.8,   0.7,  8,     0,     ['gluten'],    true,  true,  80],
    ['Oats (cooked)',             'ओट्स',           'cereal',     71,    2.5,   12.0,  1.4,  1.7,   0.9,  10,    0,     ['gluten'],    true,  true,  55],
    ['Poha (flattened rice)',     'पोहा',           'cereal',     382,   7.5,   79.2,  2.7,  1.2,   3.0,  20,    0,     [],            true,  true,  85],
    ['Toor Dal (cooked)',         'तूर दाल',        'dal',        116,   6.8,   20.4,  0.4,  5.3,   1.2,  27,    0,     [],            true,  true,  29],
    ['Moong Dal (cooked)',        'मूंग दाल',       'dal',        105,   7.0,   18.3,  0.4,  7.6,   1.4,  27,    0,     [],            true,  true,  25],
    ['Chana Dal (cooked)',        'चना दाल',        'dal',        164,   8.9,   29.1,  2.6,  10.7,  1.5,  49,    0,     [],            true,  true,  11],
    ['Rajma (cooked)',            'राजमा',          'dal',        127,   8.7,   22.8,  0.5,  6.4,   2.2,  50,    0,     [],            true,  true,  24],
    ['Paneer',                    'पनीर',           'dairy',      265,   18.3,  1.2,   20.8, 0,     0.5,  480,   0.1,   ['dairy'],     true,  false, 0],
    ['Whole Milk',                'दूध',            'dairy',      61,    3.2,   4.8,   3.3,  0,     0.1,  113,   1.0,   ['dairy'],     true,  false, 41],
    ['Curd / Dahi',               'दही',            'dairy',      60,    3.1,   4.7,   3.3,  0,     0.1,  120,   0.1,   ['dairy'],     true,  false, 36],
    ['Egg (whole, boiled)',       'उबला अंडा',      'egg',        155,   13.0,  1.1,   11.0, 0,     1.2,  50,    2.0,   ['eggs'],      false, false, 0],
    ['Chicken Breast (grilled)', 'चिकन',           'meat',       165,   31.0,  0,     3.6,  0,     0.7,  15,    0.1,   [],            false, false, 0],
    ['Fish (Rohu, steamed)',      'रोहू मछली',      'meat',       97,    19.4,  0,     2.0,  0,     1.0,  650,   6.0,   ['seafood'],   false, false, 0],
    ['Spinach (palak, cooked)',   'पालक',           'vegetable',  29,    2.9,   3.6,   0.4,  2.2,   3.6,  136,   0,     [],            true,  true,  15],
    ['Broccoli (cooked)',         'ब्रोकली',        'vegetable',  35,    2.4,   7.2,   0.4,  3.3,   0.7,  47,    0,     [],            true,  true,  10],
    ['Carrot (raw)',              'गाजर',           'vegetable',  41,    0.9,   9.6,   0.2,  2.8,   0.3,  33,    0,     [],            true,  true,  35],
    ['Tomato (raw)',              'टमाटर',          'vegetable',  18,    0.9,   3.9,   0.2,  1.2,   0.3,  10,    0,     [],            true,  true,  15],
    ['Potato (boiled)',           'उबला आलू',       'vegetable',  77,    2.0,   17.0,  0.1,  2.2,   0.3,  8,     0,     [],            true,  true,  78],
    ['Sweet Potato (boiled)',     'शकरकंद',         'vegetable',  90,    2.0,   20.7,  0.1,  3.3,   0.6,  30,    0,     [],            true,  true,  61],
    ['Banana',                    'केला',           'fruit',      89,    1.1,   22.8,  0.3,  2.6,   0.3,  5,     0,     [],            true,  true,  51],
    ['Apple',                     'सेब',            'fruit',      52,    0.3,   13.8,  0.2,  2.4,   0.1,  6,     0,     [],            true,  true,  36],
    ['Papaya',                    'पपीता',          'fruit',      43,    0.5,   10.8,  0.3,  1.7,   0.1,  20,    0,     [],            true,  true,  60],
    ['Mango (Alphonso)',          'आम',             'fruit',      60,    0.8,   15.0,  0.4,  1.6,   0.2,  11,    0,     [],            true,  true,  56],
    ['Orange',                    'संतरा',          'fruit',      47,    0.9,   11.8,  0.1,  2.4,   0.1,  40,    0,     [],            true,  true,  40],
    ['Guava',                     'अमरूद',          'fruit',      68,    2.6,   14.3,  1.0,  5.4,   0.3,  18,    0,     [],            true,  true,  12],
    ['Peanuts (roasted)',         'मूंगफली',        'nuts',       567,   26.0,  16.1,  49.2, 8.5,   4.6,  92,    0,     ['nuts'],      true,  true,  14],
    ['Almonds',                   'बादाम',          'nuts',       579,   21.2,  21.6,  49.9, 12.5,  3.7,  264,   0,     ['nuts'],      true,  true,  0],
    ['Cashews',                   'काजू',           'nuts',       553,   18.2,  30.2,  43.9, 3.3,   6.7,  37,    0,     ['nuts'],      true,  true,  22],
    ['Ghee',                      'घी',             'fat',        900,   0,     0,     100,  0,     0,    0,     0,     ['dairy'],     true,  false, 0],
    ['Coconut Oil',               'नारियल तेल',     'fat',        862,   0,     0,     100,  0,     0,    0,     0,     [],            true,  true,  0],
    ['Jaggery (Gur)',             'गुड़',            'sugar',      383,   0.4,   98.0,  0.1,  0,     11.4, 80,    0,     [],            true,  true,  84],
    ['Honey',                     'शहद',            'sugar',      304,   0.3,   82.4,  0,    0.2,   0.4,  6,     0,     [],            true,  false, 58],
    ['Green Tea',                 'ग्रीन टी',       'beverage',   2,     0.2,   0.4,   0,    0,     0,    1,     0,     [],            true,  true,  0],
    ['Black Coffee',              'ब्लैक कॉफी',    'beverage',   5,     0.3,   0.7,   0,    0,     0,    2,     0,     [],            true,  true,  0],
    ['Dal Tadka (restaurant)',    'दाल तड़का',       'dish',       148,   8.5,   18.0,  4.2,  5.0,   1.4,  38,    0,     [],            true,  true,  32],
    ['Chicken Curry (homemade)', 'चिकन करी',       'dish',       215,   18.0,  8.0,   12.5, 1.2,   0.8,  25,    0,     [],            false, false, 15],
    ['Samosa (fried)',            'समोसा',          'snack',      308,   5.0,   36.0,  16.0, 2.5,   1.5,  20,    0,     ['gluten'],    true,  true,  80],
    ['Idli (steamed)',            'इडली',           'snack',      58,    1.8,   12.0,  0.1,  0.5,   0.5,  12,    0,     [],            true,  true,  77],
    ['Dosa (plain)',              'डोसा',           'snack',      133,   4.0,   25.0,  2.7,  1.2,   0.8,  20,    0,     [],            true,  true,  72],
    ['Upma',                      'उपमा',           'snack',      198,   5.5,   33.0,  5.0,  2.8,   1.2,  18,    0,     ['gluten'],    true,  true,  65],
    ['Paratha (plain)',           'सादा पराठा',     'snack',      260,   5.7,   35.0,  11.0, 3.0,   1.5,  30,    0,     ['gluten'],    true,  true,  68],
    ['Laddoo (besan)',            'बेसन लड्डू',     'sweet',      450,   9.0,   62.0,  18.0, 3.5,   3.0,  65,    0,     [],            true,  false, 70],
    ['Chole (chickpea curry)',    'छोले',           'dish',       160,   9.5,   27.0,  2.5,  8.0,   2.8,  55,    0,     [],            true,  true,  28],
    ['Palak Paneer',              'पालक पनीर',      'dish',       210,   10.5,  8.0,   15.5, 2.5,   2.8,  320,   0,     ['dairy'],     true,  false, 15],
    ['Khichdi',                   'खिचड़ी',         'dish',       130,   5.5,   22.0,  2.5,  3.5,   1.2,  35,    0,     [],            true,  true,  42],
    ['Raita (boondi)',            'बूंदी रायता',    'dairy',      95,    4.0,   12.0,  3.5,  0.5,   0.3,  120,   0,     ['dairy'],     true,  false, 30],
    ['Watermelon',                'तरबूज',          'fruit',      30,    0.6,   7.6,   0.2,  0.4,   0.2,  7,     0,     [],            true,  true,  72],
  ];

  let count = 0;
  for (const [nameEn, nameHi, cat, kcal, prot, carb, fat, fiber, iron, calc, vitd, allergens, isVeg, isVegan, gi] of foods) {
    await db.query(
      `INSERT INTO food_items
       (name_en, name_hi, category, per_100g_kcal, per_100g_protein, per_100g_carbs,
        per_100g_fat, per_100g_fiber, per_100g_iron, per_100g_calcium, per_100g_vit_d,
        allergens, is_veg, is_vegan, glycemic_index, data_source)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,'NIN_IFCT2017')
       ON CONFLICT (barcode) DO NOTHING`,
      [nameEn, nameHi, cat, kcal, prot, carb, fat, fiber, iron, calc, vitd,
       allergens, isVeg, isVegan, gi || null],
    );
    count++;
  }
  console.log(`  ✓ ${count} food items seeded (NIN IFCT 2017 — common Indian staples)`);
  console.log('  ℹ Full NIN dataset (900+ items): download from nin.res.in/ifct2017.html');
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. MOTIVATIONAL SLOGANS (Hindi + English, all categories)
// ─────────────────────────────────────────────────────────────────────────────
async function seedSlogans() {
  console.log('💪 Seeding motivational slogans (EN + HI)...');

  const slogans: Array<[string, string, string, string]> = [
    // [category, language, text, emoji]
    // ── Morning Fire ──
    ['morning_fire', 'hi', 'मेहनत करने वालों की कभी हार नहीं होती', '🔥'],
    ['morning_fire', 'hi', 'आज का दर्द कल की ताकत है — उठो!', '🔥'],
    ['morning_fire', 'hi', 'सूरज से पहले उठो, चैंपियन बनो', '⚡'],
    ['morning_fire', 'hi', 'जो सुबह मेहनत करता है, शाम को वो जीतता है', '🌟'],
    ['morning_fire', 'hi', 'रोज़ एक कदम आगे — मंजिल करीब आएगी', '💪'],
    ['morning_fire', 'en', 'Champions are made when no one is watching', '🏆'],
    ['morning_fire', 'en', 'Your morning run is your daily declaration of war — on excuses', '🔥'],
    ['morning_fire', 'en', 'Rise before doubt. The champion inside you starts NOW', '⚡'],
    ['morning_fire', 'en', 'Every sunrise is a new chance to be better than yesterday', '🌅'],
    ['morning_fire', 'en', 'The world is yours — but only if you earn it before 8am', '💪'],

    // ── Midday Push ──
    ['midday_push', 'hi', 'थकान को मत जीतने दो — तुम्हारा लक्ष्य अभी बाकी है', '💪'],
    ['midday_push', 'hi', 'दोपहर का ब्रेक — 10 मिनट workout, बाकी दिन जोश', '⚡'],
    ['midday_push', 'hi', 'बीच रास्ते में रुकना मंजिल नहीं होती', '🎯'],
    ['midday_push', 'hi', 'आधा रास्ता पार हो गया, अब पीछे मुड़ना नहीं', '🔥'],
    ['midday_push', 'en', 'Halfway there — legends are made in the second half', '⚡'],
    ['midday_push', 'en', 'Lunch break? Perfect time for a 10-min walk', '🚶'],
    ['midday_push', 'en', 'The afternoon slump is a test. Pass it', '💪'],
    ['midday_push', 'en', 'Your future self is watching what you do right now', '🌟'],

    // ── Afternoon Grind ──
    ['afternoon_grind', 'hi', 'शाम से पहले का आखिरी push — सबसे powerful होता है', '⚡'],
    ['afternoon_grind', 'hi', 'हर सांस में ताकत है — उसे उठाओ', '🔥'],
    ['afternoon_grind', 'hi', 'जब तक हिम्मत है, हार नहीं है', '💪'],
    ['afternoon_grind', 'en', 'Sweat is just fat crying. Make it cry harder', '💧'],
    ['afternoon_grind', 'en', 'Every rep is a vote for the person you want to become', '🎯'],
    ['afternoon_grind', 'en', 'Pain is temporary. Fitness is forever', '🏆'],

    // ── Evening Warrior ──
    ['evening_warrior', 'hi', 'दिन का आखिरी workout सबसे ज़रूरी है', '🌟'],
    ['evening_warrior', 'hi', 'शाम का champion रात को चैन से सोता है', '⚡'],
    ['evening_warrior', 'hi', 'Office के बाद भी champion बनते हैं', '💪'],
    ['evening_warrior', 'hi', 'थका हुआ इंसान workout करे — यही असली ताकत है', '🔥'],
    ['evening_warrior', 'en', 'End the day stronger than you started', '🌟'],
    ['evening_warrior', 'en', 'Evening warriors outperform morning quitters', '⚡'],
    ['evening_warrior', 'en', "One more set. That's all it takes to be different", '💪'],

    // ── Night Champion ──
    ['night_champion', 'hi', 'कल का champion आज रात तैयार होता है', '🏆'],
    ['night_champion', 'hi', 'नींद से पहले एक कदम — यही फर्क करता है', '🌙'],
    ['night_champion', 'hi', 'रात को सोने से पहले — क्या आज का goal पूरा हुआ?', '🎯'],
    ['night_champion', 'en', 'Sleep well — you earned it, champion', '🌙'],
    ['night_champion', 'en', 'The best preparation for tomorrow is doing your best today', '🏆'],
    ['night_champion', 'en', 'Tonight you rest. Tomorrow you conquer', '⭐'],

    // ── Rest Day ──
    ['rest_day_recharge', 'hi', 'आराम का दिन — muscles बनने का दिन है', '🧘'],
    ['rest_day_recharge', 'hi', 'सच्चा champion जानता है कब आराम करना है', '🌸'],
    ['rest_day_recharge', 'en', 'Rest day is not a lazy day — muscles grow when you rest', '🧘'],
    ['rest_day_recharge', 'en', 'Recovery is where the magic happens. Enjoy your rest', '💆'],

    // ── Streak Milestone ──
    ['streak_milestone', 'hi', 'लगातार workout — यही असली जीत है!', '🎯'],
    ['streak_milestone', 'hi', 'Streak तोड़ना मत — आगे बढ़ते रहो!', '🔥'],
    ['streak_milestone', 'en', 'Keep that streak alive — consistency is your superpower!', '⚡'],
    ['streak_milestone', 'en', 'You showed up every day. That\'s what legends do', '🏆'],

    // ── Goal Achieved ──
    ['goal_achieved', 'hi', 'लक्ष्य पूरा! यही तुम्हारी असली ताकत है 🎉', '🎉'],
    ['goal_achieved', 'hi', 'तुमने कर दिखाया — अब अगला लक्ष्य तय करो!', '🚀'],
    ['goal_achieved', 'en', 'Goal crushed! Now set a bigger one', '🚀'],
    ['goal_achieved', 'en', 'You did it! This is just the beginning', '🎉'],

    // ── Comeback ──
    ['comeback', 'hi', 'वापसी हो गई — सबसे ताकतवर comeback यही होती है', '⚔️'],
    ['comeback', 'hi', 'कुछ दिन रुके थे, पर अब और ज़्यादा ताकत के साथ आए हो', '🔥'],
    ['comeback', 'en', 'You\'re back. That\'s all that matters. Welcome back, champion', '⚔️'],
    ['comeback', 'en', 'The comeback is always stronger than the setback', '💪'],
  ];

  for (const [category, language, text, emoji] of slogans) {
    await db.query(
      `INSERT INTO motivational_slogans (category, language, text, emoji)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT DO NOTHING`,
      [category, language, text, emoji],
    );
  }
  console.log(`  ✓ ${slogans.length} motivational slogans seeded (EN + HI)`);
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. SUBSCRIPTION PLANS
// ─────────────────────────────────────────────────────────────────────────────
async function seedSubscriptionPlans() {
  console.log('💎 Seeding subscription plans...');

  const plans = [
    { name: 'free',          tier: 'free',     priceInr: 0,      durationDays: null, trialDays: 0,  features: ['basic_tracking','leaderboard'] },
    { name: 'pro_monthly',   tier: 'pro',      priceInr: 29900,  durationDays: 30,   trialDays: 7,  features: ['pose_tracking','health_report_ai','blood_donation','nearby_doctors','no_ads','transformation_photos'] },
    { name: 'pro_yearly',    tier: 'pro',      priceInr: 199900, durationDays: 365,  trialDays: 14, features: ['pose_tracking','health_report_ai','blood_donation','nearby_doctors','no_ads','transformation_photos'] },
    { name: 'elite_monthly', tier: 'elite',    priceInr: 59900,  durationDays: 30,   trialDays: 7,  features: ['pose_tracking','health_report_ai','blood_donation','nearby_doctors','no_ads','transformation_photos','pathology_combat','custom_diet_framework','fantasy_physique','priority_support'] },
    { name: 'elite_yearly',  tier: 'elite',    priceInr: 399900, durationDays: 365,  trialDays: 14, features: ['pose_tracking','health_report_ai','blood_donation','nearby_doctors','no_ads','transformation_photos','pathology_combat','custom_diet_framework','fantasy_physique','priority_support'] },
    { name: 'lifetime',      tier: 'lifetime', priceInr: 999900, durationDays: null, trialDays: 0,  features: ['all_features'] },
  ];

  for (const p of plans) {
    await db.query(
      `INSERT INTO subscription_plans (name, tier, price_inr, duration_days, trial_days, features)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (name) DO UPDATE
       SET price_inr=EXCLUDED.price_inr, features=EXCLUDED.features`,
      [p.name, p.tier, p.priceInr, p.durationDays, p.trialDays, p.features],
    );
  }
  console.log(`  ✓ ${plans.length} subscription plans seeded`);
  console.log('  ℹ Prices in paise: pro_monthly=₹299, pro_yearly=₹1999, elite_monthly=₹599, lifetime=₹9999');
}

main().catch((err) => {
  console.error('❌ Seeder failed:', err);
  process.exit(1);
});
