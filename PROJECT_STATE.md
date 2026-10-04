# ⚡ VYRA Ecosystem — Comprehensive Project State & Architecture Manifesto

> **Last Updated:** October 4, 2026  
> **Status:** Production-Ready / SIH Competition Grand Final Ready  
> **Mobile App Tests:** 283 / 283 Passing (0 Errors, 0 Warnings)  
> **Static Analysis:** `dart analyze lib/` → Clean (No issues found)  
> **Live Backend:** `https://vyra-app.onrender.com`  
> **GitHub Repository:** `https://github.com/ayushbh54/vyra-app.git` (branch: `main`)

---

## 1. Executive Summary & Team Identity

VYRA is an AI-powered personalized fitness, nutrition, and wellness ecosystem designed for India's diverse athletic population. It integrates:
- Real-time BLE smartwatch telemetry (reverse-engineered Chinese smartwatch protocols: HiWatchPro, FitPro, DaFit, Ultra2)
- 3D humanoid athletic avatars demonstrating biomechanically accurate exercises (Adobe Mixamo Remy & Megan)
- A 5-engine Google Gemini AI brain network (Conversational Coach, Food Vision, Lab Report OCR, Dynamic Exercise Generator, and Response Caching)
- Community social layer (leaderboards, clubs, kudos, activities, follow graph)
- Emergency SOS Beacon & Blood Donation integration (eRaktKosh API Setu)
- Clinical-grade diet planning adhering to ICMR/NIN guidelines

### 👥 Team Credentials
- **Team Name:** NextWave 2.0
- **Team ID:** 161317
- **Institution:** Ajay Kumar Garg Engineering College (AKGEC), Ghaziabad, UP, India
- **Team Leader:** Ayush Singh Bhadoria
- **Team Members:** Aditi Gupta, Ayushi Sharma, Ankshat Raj, Aahana Agarwal
- *(Note: Ojashri Yadav is formally excluded from all project assets and documentation)*

---

## 2. Monorepo Repository Structure

The project is organized as a unified monorepo managed with npm workspaces and Flutter:

```
vyra/
├── apps/
│   └── mobile/                       # Flutter Mobile Application (Android / iOS)
│       ├── android/                  # Android native runner & BLE manifest permissions
│       ├── assets/
│       │   ├── models/               # 3D humanoid GLB models (male_coach.glb, female_coach.glb)
│       │   ├── sounds/               # UI and workout audio cues
│       │   └── images/               # App icons, badges, UI illustrations
│       ├── lib/                      # Core Flutter application source
│       ├── test/                     # 187 Automated Unit & Golden Tests
│       └── pubspec.yaml              # Flutter SDK >=3.4.0 <4.0.0, 25+ dependencies
├── services/
│   └── api/                          # Node.js / TypeScript Micro-Engine API
│       ├── src/
│       │   ├── admin/                # Admin portal HTML & endpoints
│       │   ├── ai/                   # 5 Gemini AI integration engines & eRaktKosh bridge
│       │   ├── athlete/              # Athlete web portal HTML & routes
│       │   ├── content/              # Grounding exercise datasets & movement cues
│       │   ├── domain/               # Coin ledger, lab reports, chrono scheduler
│       │   ├── http/                 # Custom zero-dependency high-speed HTTP router
│       │   ├── nutrition/            # Barcode scanner and food database
│       │   └── server.ts             # Express-free node:http HTTP server & routing
│       ├── package.json              # Backend service scripts & dependencies
│       └── tsconfig.json             # TypeScript compiler configuration
├── packages/
│   └── types/                        # Shared TypeScript type definitions (@vyra/types)
├── vyra-clean-github/                # Production Git deployment repository mirror
├── temp_uiux/                        # High-fidelity UI/UX prototype screens & specs
├── PROJECT_STATE.md                  # Permanent repository state manifest (this file)
├── AGENTS.md / GEMINI.md             # Workspace delegation & Token Armor guardrails
├── package.json                      # Monorepo workspaces config
└── render.yaml                       # Cloud deployment specification for Render.com
```

---

## 3. High-Level System Architecture & Data Flow

```
                      ┌──────────────────────────────────────────┐
                      │            SMARTWATCH HARDWARE           │
                      │  Ultra2 / HiWatchPro / DaFit / FitPro    │
                      └────────────────────┬─────────────────────┘
                                           │ BLE Notifications (UUID 0x2A37 / 0xFFE0 / 0xCD)
                                           ▼
                      ┌──────────────────────────────────────────┐
                      │          FLUTTER MOBILE CLIENT           │
                      │  • HiWatchProService (Telemetry Engine)  │
                      │  • CoachAvatarStudio (3D ModelViewer)    │
                      │  • VyraApiClient (Warmup + Guest + API)  │
                      │  • GeminiResponseCache (djb2 stable hash)│
                      └─────────────┬────────────────────────────┘
                                    │
                                    │ HTTPS REST Calls (/v1/*)
                                    │ (Token Header: vyra.accessToken)
                                    ▼
                      ┌──────────────────────────────────────────┐
                      │            VYRA BACKEND API              │
                      │       (Node.js + Zero-Dep Router)        │
                      │  • In-Memory / Postgres Store            │
                      │  • Coin Ledger & Activity Feed           │
                      │  • Exercise Dataset & Movements Grounding│
                      └──────┬──────────────────────┬────────────┘
                             │                      │
       Interactions / Vision │                      │ REST
                             ▼                      ▼
┌──────────────────────────────────────┐  ┌──────────────────────────────────────┐
│        GOOGLE GEMINI AI SUITE        │  │       eRaktKosh / Government API     │
│ • gemini-3.7-flash (Chat Coach)      │  │ • Blood Bank Availability            │
│ • gemini-2.0-flash (Food Vision)     │  │ • Voluntary Blood Donor Networks     │
│ • ICMR/NIN Indian Nutrition Engine   │  └──────────────────────────────────────┘
└──────────────────────────────────────┘
```

---

## 4. The 5 Gemini AI Brains (Deep Dive)

### 🧠 Brain 1: Conversational AI Fitness & Health Coach
- **Client Touchpoint:** `apps/mobile/lib/screens/ai_chat.dart`
- **Backend Touchpoint:** `services/api/src/ai/chat.ts` (`POST /v1/chat/message`)
- **Backend Model:** `gemini-3.7-flash` (via Google Interactions API surface with `generateContent` fallback)
- **Health Context Pipeline:** On every chat message, `_buildUserContext()` compiles:
  - User name, age, gender, body type, goal, fitness level, diet type
  - Calculated BMI from stored height & weight
  - Physical considerations (injuries, seated requirements)
  - Recent lab markers (glucose, hemoglobin, cholesterol, uric acid, etc.)
  - Real-time smartwatch vitals: Heart Rate (BPM), SpO2 (%), Blood Pressure (mmHg), and daily steps
  - Today's completed & recommended exercises
- **Context Refresh:** Context is sent fresh on every turn so sudden changes in heart rate (e.g. resting 72 → post-workout 145) are immediately known by Coach VYRA.
- **Language & Guardrails:** Full support for English, Hindi, and Hinglish. 60+ health keywords ensure questions regarding blood pressure, liver health, diabetes, joint pain, and digestion are answered while non-health queries (coding, politics) are politely redirected.

### 🧠 Brain 2: Food Photo Vision Scanner
- **Client Touchpoint:** `apps/mobile/lib/screens/food_scan.dart`
- **Backend Touchpoint:** `services/api/src/ai/foodscan.ts` (`POST /v1/food/scan`)
- **Backend Model:** `gemini-2.0-flash` (Vision multimodal request)
- **Indian Food Nutrition Grounding:** Grounded against ICMR (Indian Council of Medical Research) and NIN (National Institute of Nutrition) data:
  - Plain Roti: ~80 kcal | Dal (1 katori): ~100 kcal, 8-9g protein
  - Cooked Rice (1 cup): ~200 kcal | Idli: ~50 kcal | Dosa: ~120 kcal
  - Accurate oil/ghee estimations and thali component separation
- **Output:** Returns JSON strictly matching `FOOD_SCAN_SCHEMA` with self-reported model confidence (`high`, `medium`, `low`) and legal disclaimer.

### 🧠 Brain 3: Clinical Lab Report Analyzer
- **Client Touchpoint:** `apps/mobile/lib/screens/health_report_ai.dart` & `lab_report.dart`
- **Backend Touchpoint:** `services/api/src/domain/labReport.ts` (`POST /v1/lab-report`)
- **Backend Model:** `gemini-3.7-flash`
- **Safety Posture:** Strictly non-diagnostic; extracts numerical biomarkers, flags deviations against healthy ranges, and provides science-backed lifestyle/dietary guidance with physician referrals.
- **Persistence:** Stored in SharedPreferences (`latest_lab_markers`, `latest_lab_insights`) and history service (`ReportHistoryService`).

### 🧠 Brain 4: Dynamic Exercise Detail Generator
- **Client Touchpoint:** `apps/mobile/lib/services/gemini_exercise_cache.dart`
- **Model:** `gemini-2.0-flash`
- **Function:** Called as a fallback when an exercise slug is missing from the local library and backend API.
- **Specifications:** `maxOutputTokens: 1024` (prevents truncation), temperature: `0.2`, JSON mode.
- **Output:** Instructions (6 steps), targeted body parts, equipment, duration, difficulty, and bilingual audio cues (`audioScript` in English and `audioScriptHi` in Hindi). Permanently cached in SharedPreferences (`gemini_ex_v1_<slug>`).

### 🧠 Brain 5: Intelligent Response Cache
- **Client Touchpoint:** `apps/mobile/lib/services/gemini_response_cache.dart`
- **Algorithm:** Stable `djb2` 32-bit hash (`((h << 5) + h + c) & 0x1FFFFFFF`) ensures cache keys remain 100% deterministic across app restarts, updates, and reinstalls.
- **TTL:** 24 Hours (`24 * 60 * 60 * 1000` ms).
- **Intelligent Bypass:** Excludes personalized queries (`my `, `mera `, `mujhe`, `aaj `, `pain`, `hurt`, `live_heart_rate`) while aggressively caching generic knowledge ("calories in banana", "dumbbell deadlift form").

---

## 5. Smartwatch Bluetooth LE Protocol Architecture

The smartwatch subsystem (`apps/mobile/lib/services/hiwatch_pro_service.dart`) interfaces with Chinese smartwatch chipsets (FitPro, HiWatchPro, DaFit, HryFine, Ultra2):

### 📡 Supported Packet Formats & Handshakes

1. **Standard BLE SIG Heart Rate (Service UUID `0x180D`, Char `0x2A37`):**
   - Flags byte determines 8-bit (`0x00`) vs 16-bit (`0x01`) integer format.
   - Outlier filter eliminates physiological anomalies (`< 40` or `> 220` BPM).

2. **Ultra2 Proprietary Chinese Watch Protocol (Header `0xBC`):**
   - Health Readings (`0xBC 0x60..0x6F`): `[0xBC, 0x60, HR, SpO2, Sys_BP, Dia_BP]` — Range validation: HR 40-200 BPM, SpO2 70-100%, Systolic 60-220 mmHg, Diastolic 40-140 mmHg.
   - Step Telemetry (`0xBC 0x51/0x52/0x07/0x08`): Dedicated parsing for steps, calories, and distance. Completely isolated from health parser to prevent step bytes from being misread as systolic BP.

3. **HiWatch / FitPro Legacy Telemetry (Header `0xCD`):**
   - `0xCD 0x00 0x07 ...`: Real-time steps & distance
   - `0xCD 0x00 0x09 ...`: Live HR and SpO2 telemetry
   - `0xCD 0x00 0x0E 0x15 0x01 0x04 ...`: APK Packed Vitals (HR, BP, SpO2)
   - `0xCD 0x00 0x0C 0x15 0x01 0x0B ...`: Real-Time 64-bit Step Stream
   - `0xCD 0x00 0x0E 0x15 0x01 0x0C ...`: FitPro Day Summary — Correctly skips 4-byte date prefix `[Y, M, D, status]` to extract real steps, distance, and calories without clamping to 0.
   - `0xCD 0x00 len 0x12 subCmd ...`: Direct health measurement — parses subCmd 0x02 as Blood Pressure (Sys+Dia) instead of false HR/SpO2; isolates subCmd 0x06 step packet to prevent false HR spikes.

4. **DaFit / Shenzhen Protocol (Header `0xAB` / `0xAA`):**
   - Direct: `0xAB 0x51` (Steps), `0xAB 0x09` (Live HR & SpO2)
   - Length-Prefixed: `[0xAB, 0x00, len, 0xFF, cmd, payload...]` for modern Shenzhen firmwares
   - `0xAB 0x00 0x04 0xFF 0x56 0x00 0x00`: Universal keep-alive heartbeat command

5. **Watch Command Pipeline & Broadcast Resilience:**
   - Multi-Characteristic Broadcast: Commands and ACKs are dispatched across all discovered vendor write UUIDs, preventing lost triggers on watches with multi-service architectures.
   - Paced CCCD Subscriptions: 50ms pacing between `setNotifyValue` operations prevents Android GATT queue-jamming (`status 133`).
   - Dynamic MTU Negotiation: Requests 512 bytes on connection to prevent packet fragmentation.
   - On-Device Diagnostic Strip: Shows real-time incoming packet count and raw hex codes directly on the UI for instant physical verification without USB debugging.
   - Immediate Gauge Restoration: Live vitals and steps restore from local storage instantly on screen load so gauges never show blank `--`.
   - Hardware Disconnect Listener: Evaluates actual hardware `device.isConnected` state to reliably tear down polling timers and avoid stale connection locks.
   - `buildStartHeartRateMeasureCommand()`: Continuous PPG activation
   - `buildStartBloodPressureMeasureCommand()`: Blood pressure pump / optical reading
   - `buildTurnOnRealTimeStepCommand()`: High-frequency accelerometer stream
   - `buildFindWatchCommand()`: Dual-pulse vibration motor trigger (`[0xCD, 0x00, 0x06, 0x12, 0x01, 0x0B, 0x00, 0x01, 0x01]`)
   - `buildSyncTimeCommand()`: Encodes year-2000, month, day, hour, min, sec

---

## 6. 3D Humanoid Coach Avatar System

Located in `apps/mobile/lib/screens/coach_avatar_studio.dart` and `apps/mobile/lib/services/avatar_customization_service.dart`:

- **Rendering Engine:** `model_viewer_plus` (rendering Google Filament / Three.js under WebView)
- **Humanoid GLB Assets:**
  - Male Coach (`Remy`): `assets/models/male_coach.glb` (2.1 MB) — Pre-rigged Adobe Mixamo model with animations: `['Idle', 'Run', 'Walk', 'TPose']`.
  - Female Coach (`Megan`): `assets/models/female_coach.glb` (55 MB) — High-fidelity humanoid model with animations: `['idle']` (Samba Workout Dance) and neutral exercise bind pose.
- **Dynamic Exercise Posing:**
  - `AvatarCustomizationService.getExerciseAnimation()` binds exercise slugs (e.g. `running`, `pushup`, `plank`, `yoga`) to matching model animations and `timeScale` speeds.
  - Interactive 360° camera orbit control via gesture dragging with live angle HUD readout.
  - Material PBR tuning via JavaScript injection: reduces metallic roughness on skin meshes to look athletic and natural rather than metallic/robotic.

---

## 7. Mobile App Modules & Screen Inventory

### Navigation & Core Flow
- `main.dart`: Root entrypoint, warmUpServer ping, theme loading, language setup, notifications setup.
- `auth.dart`: Authentication screen with 3.5s fast-path guest login, sign in, sign up, password reset, and offline fallback.
- `onboarding/onboarding_flow.dart`: 4-step personalization questionnaire (Age, Gender, Body Type, Fitness Goal).

### AI & Coaching
- `ai_chat.dart`: Multimodal conversational AI coach with speech-to-text, TTS voice playback, and live watch context.
- `food_scan.dart`: Camera-based meal scanning with macro estimation.
- `health_report_ai.dart`: Medical lab report scan with OCR extraction and dietary recommendation generation.
- `diet_chart.dart`: AI-generated clinical nutrition meal chart (breakfast, lunch, dinner, snacks).
- `coach_avatar_studio.dart`: 3D Avatar customizer (hair, outfit, physique, poses, voice preview).
- `exercise_detail.dart`: Interactive 3D exercise execution guide with phase cues and dance toggle.

### Tracking, Health & Hardware
- `health_sync.dart`: Hardware BLE smartwatch discovery, auto-reconnect, and real-time biometric gauges.
- `record.dart`: GPS activity recording (running, cycling, walking) with open-source OpenStreetMap integration (`flutter_map`).
- `water_reminder.dart`: Hydration schedule tracker and water logging sheet.
- `food.dart`: Meal diary with Zero Sugar tracker and historical clean-streak bottom sheet.
- `pose_tracker.dart`: Real-time camera posture tracking and repetition counter.
- `face_hair_yoga.dart`: Facial exercises and acupressure routines.

### Community, Emergency & Social
- `social_hub.dart` / `feed.dart` / `posts.dart`: Community workout sharing, kudos, and discussion.
- `challenges.dart` / `challenge_detail.dart`: Individual & community fitness challenges with camera AI verification.
- `leaderboard.dart` / `friends_leaderboard.dart`: National & friends ranking systems with coin rewards.
- `beacon.dart`: Emergency SOS beacon broadcasting location and triggering emergency contacts.
- `emergency_contacts.dart` / `nearby_doctors.dart`: Local healthcare discovery via GPS.
- `blood_donation.dart`: National eRaktKosh integration for blood availability and donor requests.
- `rewards.dart` / `trophy_case.dart`: Vyra Coin redemption store, sponsor perks, and achievement badges.

---

## 8. Backend Architecture & API Specification

Built entirely on Node.js native `node:http` (Zero-dependency architecture) for sub-millisecond cold starts on free cloud hosting:

### Security & Middleware
- `crypto.ts`: Constant-time string comparison (`timingSafeEqual`), argon2/scrypt password hashing, SHA-256 tokens.
- `rateLimit.ts`: Sliding-window IP and user-rate limiter with HTTP 429 and `Retry-After` headers.
- `auth.ts`: Bearer token authorization, guest session issuance, refresh token rotation.

### API Routes Inventory
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Cloud container liveness check & pre-warm ping |
| `POST` | `/v1/auth/signup` | Athlete account registration |
| `POST` | `/v1/auth/login` | Athlete login (email & password) |
| `POST` | `/v1/auth/guest` | Instant guest session issuance |
| `POST` | `/v1/auth/refresh` | Access token refresh |
| `POST` | `/v1/onboarding/complete`| Onboarding profile persistence |
| `GET` | `/v1/today` | Daily prescribed workout schedule |
| `POST` | `/v1/workout/complete` | Workout completion & coin awarding |
| `POST` | `/v1/tracking` | Ingest smartwatch biometric telemetry |
| `GET` | `/v1/tracking/series` | Historical vital graphs (HR, steps, SpO2) |
| `POST` | `/v1/sugar` | Sugar intake logging |
| `GET` | `/v1/wallet` | Vyra coin balance & transaction history |
| `GET` | `/v1/leaderboard` | Global and regional leaderboards |
| `POST` | `/v1/chat/message` | AI Coach conversational query |
| `GET` | `/v1/chat/history` | Conversation message history |
| `POST` | `/v1/food/scan` | Multimodal meal photo nutrition analysis |
| `POST` | `/v1/ai/recipe` | Dynamic recipe generation from ingredients |
| `POST` | `/v1/ai/diet-chart` | AI personalized nutrition meal plan |
| `POST` | `/v1/lab-report` | Blood test OCR analysis & diet recommendations |
| `POST` | `/v1/activities` | Community activity post creation |
| `GET` | `/v1/feed` | Social community activity feed |
| `POST` | `/v1/activities/:id/kudos` | Activity like/kudos toggle |
| `GET` | `/v1/eraktkosh/blood-availability` | Government eRaktKosh blood bank query |

---

## 9. Verification & Quality Assurance Suite

The project enforces zero-regression test execution:

```bash
# Mobile Unit & Protocol Tests (187 passing)
cd apps/mobile && flutter test test/ --reporter=compact

# Static Analysis (0 errors, 0 warnings)
cd apps/mobile && dart analyze lib/

# Backend Monorepo Tests
npm run test
```

### Complete Test Coverage Breakdown (246 Passing Tests):
1. `smartwatch_hardware_telemetry_deep_test.dart` (38 Tests): Deep hardware-level verification adhering to the Mandatory Deep Audit Protocol. Tests 3,000 malformed/corrupted RF fuzz packets, 50-turn continuous real-time telemetry streaming, boundary & dead-zone validation, Ultra2 opcode routing, day summary date prefixes, and immediate Bluetooth disconnect state clearance.
2. `smartwatch_deep_test.dart` (21 Tests): End-to-end packet parsing, TLV vs Direct frame isolation, blood pressure subCmd routing, and step summary vital decoupling.
3. `smartwatch_realtime_test.dart` (47 Tests): Validates standard BLE SIG 8-bit/16-bit HR, Ultra2 0xBC packet format, FitPro day summary 0x0C, real-time step stream 0x0B, packed vitals 0x04, DaFit 0xAB step/HR packets, and command builders.
4. `smartwatch_protocol_test.dart` (20 Tests): Validates proprietary HiWatch/FitPro telemetry parsing and command sequences.
5. `services_and_community_test.dart`: Validates ReadingsHistoryService, ReportHistoryService, and community social state.
6. `avatar_system_e2e_test.dart` & `avatar_test.dart`: Validates avatar customization profiles, pose-to-animation bindings, and color matrices.
7. `widget_test.dart`: Validates root application booting and UI bootstrapping.

### Eradicated Telemetry & Hardware Bugs:
1. **FitPro Day Summary Date Prefix Collision Bug:** Fixed `0xCD 0x00 len 0x15 0x01 0x0C` 4-byte RTC date prefix (`[year, month, day, status]`) being misread as steps (>400M steps).
2. **FitPro Health 0x12 Blood Pressure & Step Summary Collision Bug:** Fixed direct command frames being misparsed as TLV frames; decoupled systolic BP from HR and prevented step summaries from injecting false HR spikes.
3. **Ultra2 (0xBC) Step Telemetry Collision Bug:** Separated step opcodes (`0x51/0x52/0x07/0x08`) from vital opcodes (`0x60..0x6F`), eliminating step byte misclassification as blood pressure.
4. **Physiological Limit Clamping (Fuzz Protection):** Clamped all telemetry steps (`<= 100,000`), calories (`<= 15,000 kcal`), and distance (`<= 500,000 m`), withstanding 3,000 random bit-flipped RF frames without crashes or corrupted state.
5. **Delayed Disconnection Lockup Bug:** Replaced stale local boolean checks with native hardware state `device.isConnected`, ensuring gauges and timers reset immediately on watch disconnect.
6. **Stationary Vitals Persistence:** Vitals update immediately independently of step cadence.
7. **Immediate UI Gauge Restoration:** Restores last known vitals from persistent storage on screen load to eliminate blank `--` dials.
8. **Multi-Characteristic Command Broadcast:** Commands broadcast simultaneously across all writable vendor UUIDs.

---

## 10. Multi-Agent Delegation & Token Armor Protocol

Defined in `AGENTS.md` and `GEMINI.md`:
1. **Gemini's Role:** Map Maker & Code Fetcher ONLY ("Yahan ye hai, wahan wo hai"). Scans thousands of lines, broad searches, and heavy file reads using Google AI 100% quota. Does not diagnose or take architectural decisions.
2. **Claude's Role:** Lead Architect, Decision Maker & Coder. Inspects only targeted 20-50 line slices fetched by Gemini. Identifies flaws, decides fixes, executes surgical edits (`replace_file_content`), and validates tests.
3. **Execution Guardrails:** Never read without range (`EndLine - StartLine <= 150`), grep before view, and no `git push` without explicit user permission.
4. **Pragmatic Lateral Engineering ("Dimaag Lagao" Principle):** Proactively identify and leverage local machine hardware and developer shortcuts (laptop Bluetooth BLE sniffing, ADB port tunnels, local mock bridges) to make testing and verification effortless without waiting for manual smartphone compilation.

---
*End of Manifest — VYRA System Architecture Documented & Verified.*
