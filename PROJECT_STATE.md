# ⚡ VYRA Ecosystem — System Architecture & Technical State Manifesto

> **Last Updated:** October 13, 2026  
> **Status:** Production-Ready • Smart India Hackathon (SIH 2026 — Problem ID: `26196`)  
> **Mobile Application:** `VYRA Fitness` (`com.ayush.vyra.fitness` • Version `2.0.0+6`)  
> **Static Analysis:** `flutter analyze` → Clean (`0` Errors, `0` Warnings)  
> **Live Web Portal:** `https://vyra-app-api-ten.vercel.app`  
> **Live Backend API:** `https://vyra-app.onrender.com`  
> **Repository:** `https://github.com/ayushbh54/vyra-app.git` (`main`)

---

## 1. Executive Summary & Team Identity

**VYRA** is an AI-powered personalized fitness, biomechanics, nutrition, and public-health ecosystem designed for India's diverse population. It unifies:
1. **4-Stage Closed-Loop 3D Avatar Biomechanical Engine (`v6.0`):** Pre-flight 3D Forward-Kinematics verification, floor-lock solver (`0.00 mm` ground drift), rig-calibrated quaternion similarity conjugation (`male_coach.glb` & `female_coach.glb`), and a **Persistent Verified Setup Cache** (`0ms` instant load).
2. **On-Device AI Camera Pose Tracker + AR Moving Target Aura (`v6.0`):** Real-time 33-landmark BlazePose tracking with Velocity-Adaptive One-Euro smoothing across **107 exercises** and **15 biomechanical archetypes**.
3. **Universal Multi-Protocol BLE Smartwatch Engine:** Direct hardware telemetry across HiWatchPro/Ultra2 (`0xCD`/`0xDC`), DaFit/Fire-Boltt/Noise/boAt (`0xAB`), Standard BLE SIG (`0x180D`/`0x2A37`), and Wear OS (`Galaxy Watch4`).
4. **5-Brain Google Gemini AI Suite:** Conversational Health Coach, ICMR-NIN Indian Food Vision Scanner, Clinical Lab Report OCR & Guardrails, Dynamic Exercise Generator, and Deterministic `djb2` Response Caching.
5. **Public Health & Emergency Safety:** MoHFW **e-RaktKosh** Blood Bank & Donor Network integration alongside a 1-Tap GPS **Beacon SOS** system.

### 👥 Team Credentials
- **Team Name:** NextWave 2.0
- **Team ID:** `161317`
- **Institution:** Ajay Kumar Garg Engineering College (AKGEC), Ghaziabad, Uttar Pradesh, India
- **Team Leader:** Ayush Singh Bhadoria
- **Team Members:** Aditi Gupta, Ayushi Sharma, Ankshat Raj, Aahana Agarwal

---

## 2. Clean Monorepo Structure

```
vyra/
├── apps/
│   └── mobile/                       # Flutter Cross-Platform Mobile App (Android & iOS)
│       ├── android/                  # Android native configuration (com.ayush.vyra.fitness)
│       ├── ios/                      # iOS native configuration (com.ayush.vyra.fitness)
│       ├── assets/
│       │   ├── js/                   # exercise_poses.js (v6.0 4-Stage Closed-Loop 3D Engine)
│       │   ├── models/               # male_coach.glb & female_coach.glb (Mixamo 3D Rigs)
│       │   └── images/               # App icons & visual assets
│       ├── lib/
│       │   ├── api/                  # REST client (VyraApiClient)
│       │   ├── models/               # Typed domain models
│       │   ├── screens/              # 30+ feature screens
│       │   ├── services/             # BLE Smartwatch, Avatar, Pose & Gemini Cache services
│       │   └── widgets/              # Reusable Material 3 widgets
│       ├── test/                     # Unit, widget, BLE telemetry & 3D biomechanics tests
│       └── pubspec.yaml              # Version 2.0.0+6 dependencies & assets
├── services/
│   └── api/                          # Node.js + TypeScript Zero-Dependency Backend API
│       ├── db/migrations/            # 13 PostgreSQL database migrations
│       └── src/
│           ├── admin/                # Superadmin dashboard & feature flag routes
│           ├── ai/                   # 5 Gemini AI engines, DietGuard & e-RaktKosh bridge
│           ├── athlete/              # Athlete web portal routes
│           ├── content/              # Grounded exercises (107 total) & movement cues
│           ├── domain/               # Pure math engines (chrono, coins, labReport)
│           ├── http/                 # Custom zero-dependency HTTP router
│           ├── nutrition/            # Barcode & ICMR-NIN IFCT food database
│           └── server.ts             # HTTP server & API route registration
├── packages/
│   └── types/                        # Shared TypeScript interfaces (@vyra/types)
├── public/                           # Production Vercel Web Portal bundle (index, portal, admin)
├── scripts/                          # Python desktop AI pose tracker (vyra_pose_tracker.py)
├── screenshots/                      # Product UI & architecture screenshots
├── DEPLOY.md                         # Step-by-step Android, iOS, Render & Vercel deployment guide
├── PROJECT_STATE.md                  # System architecture & technical state reference (this file)
├── README.md                         # Project overview & quick-start documentation
├── build-apk.sh                      # 1-command Android release APK builder
├── render.yaml                       # Render.com cloud infrastructure blueprint
└── vercel.json                       # Vercel static hosting & clean URL configuration
```

---

## 3. High-Level System Architecture & Data Flow

```
                      ┌──────────────────────────────────────────┐
                      │            SMARTWATCH HARDWARE           │
                      │  Ultra2 / HiWatchPro / DaFit / Wear OS   │
                      └────────────────────┬─────────────────────┘
                                           │ BLE GATT Notifications (0xCD / 0xAB / 0x2A37)
                                           ▼
                      ┌──────────────────────────────────────────┐
                      │       VYRA FITNESS MOBILE CLIENT         │
                      │   com.ayush.vyra.fitness (v2.0.0+6)      │
                      │  • HiWatchProService (Universal BLE)     │
                      │  • 4-Stage 3D Avatar Engine (v6.0)       │
                      │  • 15-Archetype MLKit Pose Tracker (v6.0)│
                      │  • Persistent Setup & Gemini Cache       │
                      └─────────────┬────────────────────────────┘
                                    │
                                    │ HTTPS REST API (/v1/*)
                                    ▼
                      ┌──────────────────────────────────────────┐
                      │            VYRA BACKEND API              │
                      │       (Node.js + Zero-Dep Router)        │
                      │  • PostgreSQL (13 Migrations) / Memory   │
                      │  • Chrono-Adaptive Scheduler & Coin Vault│
                      │  • 107 Grounded Exercises & Movements    │
                      └──────┬──────────────────────┬────────────┘
                             │                      │
       Interactions / Vision │                      │ REST / Setu Gateway
                             ▼                      ▼
┌──────────────────────────────────────┐  ┌──────────────────────────────────────┐
│        GOOGLE GEMINI AI SUITE        │  │       e-RaktKosh / Government API    │
│ • Conversational Health Coach        │  │ • Real-Time Blood Bank Availability  │
│ • ICMR-NIN Indian Food Vision        │  │ • Voluntary Donor Eligibility Engine │
│ • Clinical Lab Report OCR & Guardrail│  └──────────────────────────────────────┘
└──────────────────────────────────────┘
```

---

## 4. 4-Stage Closed-Loop 3D Avatar Biomechanical Engine (`v6.0`)

**Files:** `apps/mobile/assets/js/exercise_poses.js`, `apps/mobile/lib/screens/exercise_detail.dart`, `apps/mobile/lib/services/avatar_customization_service.dart`, `apps/mobile/lib/services/exercise_animation_registry.dart`

### Why Direct Euler Overwrites Failed on Mixamo GLB Rigs
In `male_coach.glb` (`mixamorig5`) and `female_coach.glb` (`mixamorig`), every bone carries a non-identity T-Pose bind quaternion ($q_{\text{bind}}$, e.g., `LeftArm` roll $\approx 91^\circ$, `LeftUpLeg` $\approx 180^\circ$ inverted, `Character` root $-90^\circ$ X vs. `Armature` $+90^\circ$ X). Directly calling `bone.rotation.set(rx, ry, rz)` wiped $q_{\text{bind}}$, twisting limbs sideways and leaving `Hips.position` floating or sinking through the floor.

### The 4-Stage Closed-Loop Architecture
1. **Stage 0 — Persistent Verified Setup Cache (`0ms` Instant Execution):**
   - Checks `localStorage['vyra_verified_setup_v6_<rigId>_<poseName>']` and Flutter `SharedPreferences` (`vyra_verified_avatar_setups_v6`).
   - If the exercise setup has already been verified for that rig (`male` or `female`), it loads directly from cache in `0ms` (`fromCache: true`, UI badge: `3D COACH • ⚡ CACHED SETUP`) without re-running the solver.
   - Only uncached exercises execute Stages 1–3 once and persist their verified setup.
2. **Stage 1 — Canonical Biomechanical Blueprint (`POSE_BIOMECHANICS` — 65 Poses, 150+ Slugs):**
   - Resolves any exercise slug or title into its anatomical `posture` (`standing`, `prone`, `supine`, `quadruped`, `kneeling`, `downward_dog`), `groundContacts`, `symmetry` (`bilateral`, `alternating`, `circular`), and character-space `(pitch, yaw, roll)` joint targets (`start` & `peak`).
3. **Stage 2 — Rig-Calibrated Quaternion Similarity Conjugation (`solveCharacterPoseToRig`):**
   - Uses embedded ground-truth T-Pose bind metadata (`GLB_BIND_META.male` & `GLB_BIND_META.female`) extracted from `male_coach.glb` and `female_coach.glb`:
     $$q_{\text{delta}} = W_{\text{bind}}^{-1} \cdot Q_{\text{char}} \cdot W_{\text{bind}}, \quad q_{\text{bone}} = q_{\text{bind}} \cdot q_{\text{delta}}$$
4. **Stage 3 — Pre-Flight 3D Forward-Kinematics Verification & Floor-Lock Gate (`verifyAndBuildSetup`):**
   - Computes 3D world coordinates for all 62 bones (`computeForwardKinematics`), solves `hipsLocalPosStart` and `hipsLocalPosPeak` in `Hips.parent` local space so ground-contact joints (`LeftToeBase`, `RightToeBase`, `LeftHand`, `RightHand`, `Hips`, `Spine2`) remain locked to `floorY` (`0.00 mm` drift), and verifies unit quaternion norms (`1.0 ± 1e-4`), upright/horizontal posture, and active joint excursion (`65/65 PASS` on both rigs).
5. **Stage 4 — 60 FPS Quaternion SLERP, Alternation, Circular Orbits & WebGL Repaint:**
   - Shortest-path `qSlerp`, bilateral Left↔Right alternating reps (`mirrorCharacterPose` for `reverse_lunge`, `dead_bug`, `bird_dog`, `hip_flexor_stretch`, `ankle_circles`), 4-quadrant 360° circular trajectories (`qCircle90` / `qCircle270` for `arm_circles`, `shoulder_pendulum`, `scalp_massage`), and `requestModelViewerRender(mv, root)` for 60 FPS WebGL rendering alongside full 360° touch camera orbit.

---

## 5. On-Device AI Selfie Camera Pose Tracker + AR Target Aura (`v6.0`)

**Files:** `apps/mobile/lib/screens/pose_tracker.dart`, `scripts/vyra_pose_tracker.py`

1. **1:1 Camera Viewport & Mirror Lock:**
   - Handles iOS `camera_avfoundation` vs. Android front-camera mirror differences (`_mirrorLandmarksX = Platform.isAndroid && isFront` with 1-tap `Flip` toggle) and `BoxFit.cover` scaling (`_toCanvas`).
2. **BlazePose Accurate + Velocity-Adaptive One-Euro Filter:**
   - Uses `PoseDetectionModel.accurate` + `ResolutionPreset.high` (`720x1280`), Velocity-Adaptive One-Euro landmark smoothing, active-limb excursion selection, and 3D depth foreshortening compensation (`_compute3DCompensatedAngle`).
3. **15 Biomechanical Archetypes & AR Moving Target Aura (107 Verified Exercises):**
   - Covers all **107 exercises** across `services/api/src/content/exercises.ts` (47), `services/api/src/content/exercise_dataset.ts` (18), `apps/mobile/lib/screens/training_hub.dart` (84), and dynamic Gemini AI prescriptions:
     1. `bodyweight-squat` (`auraPattern: 'squat'`, Knee `176.8° → 98.8°`)
     2. `reverse-lunge` (`auraPattern: 'lunge'`, Front Knee `176.8° → 96.5°`)
     3. `glute-bridge` (`auraPattern: 'bridge'`, Hip Extension `103.8° → 178.0°`)
     4. `seated-forward-fold` (`auraPattern: 'hinge_fold'`, Hip Hinge `170.0° → 74.0°`)
     5. `push-up` (`auraPattern: 'push_up'`, Elbow Flexion `177.6° → 62.0°`)
     6. `dumbbell-bicep-curl` (`auraPattern: 'curl_row'`, Elbow Flexion `176.2° → 29.5°`)
     7. `seated-shoulder-press` (`auraPattern: 'overhead_press'`, Shoulder Elevation `41.5° → 178.0°`)
     8. `lateral-raise` (`auraPattern: 'lateral_raise'`, Shoulder Abduction `12.6° → 104.0°`)
     9. `seated-torso-twist` (`auraPattern: 'torso_twist'`, Thoracic Rotation `13.0° → 101.5°`)
     10. `jumping-jacks` (`auraPattern: 'jumping_jack'`, Shoulder Arc `13.8° → 167.0°`)
     11. `high-knees` (`auraPattern: 'knee_drive'`, Alternating Hip Flexion `170.0° → 68.7°`)
     12. `calf-raise` (`auraPattern: 'calf_raise'`, Ankle Plantarflexion `94.1° → 161.6°`)
     13. `plank` (`auraPattern: 'plank_hold'`, Core Alignment Hold `~176.5°`)
     14. `wall-sit` (`auraPattern: 'lower_hold'`, Isometric Knee Hold `~104.5°`)
     15. `box-breathing` (`auraPattern: 'breath_hold'`, Meditative Breath Hold `~97.8°`)
4. **ARTIFIT-Grade Camera AR Workout Verification (Zero False Rep Counting):**
   - **5-Gate Strict Biomechanical Form Verification (`ExerciseConfig.verifyBiomechanicalForm`):**
     - *Gate 1: Active-Triplet Joint Visibility* (`bestTripletConf >= 0.36`, leg/shoulder visibility checks).
     - *Gate 2: Anatomical Body-Posture Orientation* (rejects standing upright during floor planks/bridges; enforces vertical spine limit `<= 26°` for upper-body isolation and `<= 38°` for squats/lunges; detects Knee Valgus / Cave).
     - *Gate 3: Secondary Joint Cheating Prevention* (rejects elbow/shoulder swinging during bicep curls, drops wrists below shoulders in overhead presses).
     - *Gate 4: Bilateral Symmetry Enforcer* (requires symmetric movement `<= 34°` difference across bilateral exercises).
     - *Gate 5: Biomechanical Angular Corridor & 2-Frame Peak Hold* (rejects shallow half-reps `< 62% ROM` and requires 2 consecutive valid frames at true peak).
   - **Ultra-Clean ARTIFIT AR Visuals (Dynamic Red vs. Green Points):**
     - **Normal Green (`#22C55E` / `#34FF8C`)**: AR points and bone lines stay crisp green when user's form and posture are valid.
     - **Crimson Red (`#FF3B30`)**: AR points and bone lines immediately flash red with glowing warning rings on `faultJoints` whenever user cheats or performs wrong form, with real-time audio guidance (`"⚠️ Please do it correctly: ..."`), and completely blocks the rep from counting until proper posture is restored.

---

## 6. The 5 Google Gemini AI Brains

1. **Brain 1 — Conversational Health & Fitness Coach (`apps/mobile/lib/screens/ai_chat.dart` & `services/api/src/ai/chat.ts`):**
   - Compiles live smartwatch vitals (HR, SpO2, BP, steps), BMI, injuries, lab markers, and daily workouts into every turn. Supports English, Hindi, and Hinglish.
2. **Brain 2 — Indian Food Photo Vision Scanner (`apps/mobile/lib/screens/food_scan.dart` & `services/api/src/ai/foodscan.ts`):**
   - Multimodal vision analysis grounded against ICMR-NIN Indian Food Composition Tables (IFCT) with oil/ghee estimation and thali component breakdown.
3. **Brain 3 — Clinical Lab Report Analyzer (`apps/mobile/lib/screens/lab_report.dart` & `services/api/src/domain/labReport.ts`):**
   - Extracts numerical biomarkers, flags out-of-range readings, enforces dietary safety guardrails (`dietGuard.ts`), and persists results to `ReportHistoryService`.
4. **Brain 4 — Dynamic Exercise Generator (`apps/mobile/lib/services/gemini_exercise_cache.dart`):**
   - Generates structured 6-step instructions, target muscles, equipment, and bilingual English/Hindi audio coaching cues cached under `gemini_ex_v1_<slug>`.
5. **Brain 5 — Deterministic `djb2` Response Cache (`apps/mobile/lib/services/gemini_response_cache.dart`):**
   - Uses a deterministic 32-bit `djb2` hash with a 24-hour TTL for instant offline replay while bypassing cache for live biometric queries.

---

## 7. Universal Multi-Protocol BLE Smartwatch Architecture

**Files:** `apps/mobile/lib/services/hiwatch_pro_service.dart`, `apps/mobile/lib/services/watch_hardware_profile.dart`, `apps/mobile/lib/screens/health_sync.dart`, `apps/mobile/lib/screens/smartwatch_diagnostic_screen.dart`

### Supported Hardware Protocol Families
1. **Family A (`WatchProtocolType.hiwatchCd` — Primary Default for `Ultra2`):**
   - **Chipset:** Jerry / JieLi (`JL7012` / `AC695X`) FitPro / HiWatchPro / HryFine (`6e400001` / `6e400002` write / `6e400003` notify).
   - **Paced 6-Step Startup:** Pair Handshake (`0x12 0x0A`) → RTC Clock Sync (`0x12 0x01`) → Authentic Battery Query (`0x12 0x02`) → Real-Time Steps (`0x15 0x06`) → Day Summary (`0x15 0x0C`) → Multi-Vitals Stream Ignition (`0x18 0x01 0x01`).
   - **Master Multi-Vitals Stream (`Cmd 0x15, Key 0x0E`):** Extracts `bytes[16]` SpO2 %, `bytes[17]` Diastolic BP, `bytes[18]` Systolic BP, and `bytes[19]` Heart Rate BPM while guarding `bytes[10..13]` (`65,536` goal bitmask) from corrupting step counts.
   - **Day Summary (`Cmd 0x15, Key 0x0C`):** Extracts authentic hardware steps (`bytes[10..13]`), distance (`bytes[14..17]`), and calories (`bytes[18..19]`) with `3.5s` watchdog keepalive and automatic `0xDC` Return-ACK responses.
   - **Hardware Watchdog & Link Resilience:** Dedicated 4s keepalive ping (`[0xCD, 0x00, 0x06, 0x15, 0x01, 0x0D, 0x00, 0x01, 0x01]`) prevents Jerry JL7012 4.5s watchdog timeout during active measurements; single-route GATT write buffer avoids ring buffer overruns; Android BLE 250ms discovery stabilization delay prevents status 133 GATT errors.
2. **Family B (`WatchProtocolType.dafitAb`):**
   - Supports Fire-Boltt, Noise ColorFit, boAt, Fastrack, Titan, DaFit/MoYoung (`0xAB` protocol: `0x51 0x08` steps/kcal/dist, `0x31` vitals, `0x32 0x80` Measure All, `0x91` battery) and FitCloudPro (`0xFE`/`0xEA`).
3. **Family C (`WatchProtocolType.bleSig`):**
   - Standard Bluetooth SIG Heart Rate Service (`0x180D` / `0x2A37`, 8-bit & 16-bit integer formats) and Battery Service (`0x180F` / `0x2A19`).
4. **Family D (`WatchProtocolType.wearOsCompanion`):**
   - Supports Samsung Galaxy Watch4 Classic, Pixel Watch, and Wear OS companion devices with live GATT link verification and biometric syncing.

---

## 8. Backend Micro-Engine API & Database Schema

**Files:** `services/api/src/server.ts`, `services/api/src/store.ts`, `services/api/src/store.pg.ts`, `services/api/db/migrations/001_init.sql` – `013_datasets_and_ai_engine.sql`

- **Zero-Dependency HTTP Router (`services/api/src/http/router.ts`):** Built directly on Node.js `node:http` for sub-millisecond cold starts on cloud containers.
- **Security (`crypto.ts`, `auth.ts`, `rateLimit.ts`):** Constant-time token comparison (`timingSafeEqual`), `scrypt` password hashing, AES-256-GCM health payload encryption, and sliding-window rate limiting.
- **13 PostgreSQL Migrations:** Cover users, sessions, social graph, clubs, messaging, moderation, movement biomechanics, posts, challenges, coin ledger, emergency contacts, AI chat logs, and grounded datasets.

---

## 9. Verification & Automated Test Suite Summary

```bash
# 1. Backend Domain & API Unit Tests (175 Passing Tests)
npm test --prefix services/api

# 2. Mobile App Static Analysis (0 Issues)
cd apps/mobile && flutter analyze

# 3. Mobile Unit, Widget, BLE & 3D Avatar Tests
cd apps/mobile && flutter test
```

| Verification Suite | Scope | Status |
| :--- | :--- | :--- |
| **Backend Domain & API Suite** | Chrono-Adaptive Scheduler, Idempotent Coins, Lab Report OCR, DietGuard, Crypto, Admin Routes | **175 / 175 PASS** |
| **3D Avatar Biomechanical Engine (`v6.0`)** | 65 Canonical Exercises × 2 Rigs (`male_coach.glb` & `female_coach.glb`) + 7,930 SLERP Frames + 130 Cache Hits | **130 / 130 PASS** (`0.00 mm` floor drift) |
| **AI Camera Pose Tracker (`v6.0`)** | All 107 Exercises across 15 Biomechanical Archetypes + 15 AR Moving Target Aura Patterns | **107 / 107 PASS** |
| **Smartwatch Telemetry & Fuzz Suite** | 260+ BLE unit tests + 3,000 malformed RF fuzz packets + physical `Ultra2` & `iPhone` verification | **PASS** |
| **Flutter Static Analysis** | `flutter analyze` across modified mobile screens, services, and tests | **No issues found** |
| **iOS Release Build & UI Auto-Fit** | Built & installed native Release bundle (`com.ayush.vyra.fitness`) on physical iPhone 15; universal `FittedBox`/`Expanded` responsive UI; iOS portrait camera AR coordinate normalization | **VERIFIED & INSTALLED** |
| **Female 3D Avatar Optimization & WebGL Stability** | Repacked `female_coach.glb` from 55MB to 3.8MB with 100% bone/mesh parity; stabilized `ModelViewer` key lifecycle and null animation handling; resolved Android WebView green error page & context loss | **VERIFIED & PASS** |
| **Culinary Intelligence Recipe Engine (`v2.0`)** | Replaced hardcoded "chop raw egg" boilerplate with `AiRecipeService` 3-tier cascade (Backend -> On-Device Gemini -> Intelligent Culinary Rules for Eggs, Meat, Paneer, Oats, Dal, Rice & Sabzi) | **9 / 9 PASS** |
| **Android Cleartext Whitelist & Deterministic Keystore** | Whitelisted 127.0.0.1 loopback HTTP in AndroidManifest & network_security_config.xml; bundled deterministic keystore for 1-tap in-place updates; upgraded to version 2.0.0+7 | **VERIFIED & PASS** |

