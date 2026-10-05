# ⚡ VYRA Ecosystem — Comprehensive Project State & Architecture Manifesto

> **Last Updated:** October 4, 2026  
> **Status:** Production-Ready / SIH Competition Grand Final Ready  
> **Mobile App Tests:** 309 / 309 Passing (0 Errors, 0 Warnings)  
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
   - `0xCD 0x00 0x11 0x15 0x01 0x02 ...`: **Ultra2 Hardware Verified Record Stream** — 8-byte bucketed sport history detail (`[steps_hi, steps_lo, kcal_hi, kcal_lo, hour, min, dist_hi, dist_lo]`). Verified live: streams 5,839+ steps with matching calories and distance. Requires ACK `[0xDC, 0x00, 0x05, 0x15, 0x01, 0x00, 0x10, 0x01]`.
   - `0xCD 0x00 0x0E 0x15 0x01 0x0C ...`: FitPro Day Summary — Correctly skips 4-byte date prefix `[Y, M, D, status]` to extract real steps, distance, and calories without clamping to 0.
   - `0xCD 0x00 len 0x12 subCmd ...`: Direct health measurement — parses subCmd 0x02 as Blood Pressure (Sys+Dia) instead of false HR/SpO2; isolates subCmd 0x06 step packet to prevent false HR spikes.

4. **Physical Ultra2 Watch Profile (Field Verified via Mac Terminal CoreBluetooth):**
   - Device Name: `Ultra2` | MAC: `71:7E:FB:00:03:CB`
   - Primary UART Service: `6e400801-b5a3-f393-e0a9-e50e24dcca9d`
   - Write Characteristic: `6e400002-b5a3-f393-e0a9-e50e24dcca9d`
   - Notify Characteristic: `6e400003-b5a3-f393-e0a9-e50e24dcca9d`
   - Secondary Services: `ffff` (`ff22` write, `ff11` notify), `3802` (`4a02`)
   - **Verified Live Telemetry (October 2026):**
     * Steps: 21,917 steps (dynamically increasing in real time while walking)
     * Calories: 431 kcal
     * Distance: 15,341 m
     * Heart Rate: 78 BPM | Blood Pressure: 115/80 mmHg | SpO2: 97% | Battery: 9%
   - **65,000+ Phantom Steps Elimination & 0xDC Hardware ACK Guard:**
     * Root Cause: Periodic Sport Poll ACKs (`0xDC 0x00 0x05 0x15 0x01 0x00 0x09 0x01`) were falling through to fallback step parsers, treating status bytes `(0x01 << 16) | 0x09` as 65,545 steps, locking the step counter.
     * Architectural Fix: Enforced strict `0xDC` ReturnAck guard to drop non-battery ACK payloads; shifted 4.0s keepalive polling to Day Summary (`0x15`, `0x0D`), which continuously streams live cumulative steps without packet collision.

5. **DaFit / Shenzhen Protocol (Header `0xAB` / `0xAA`):**
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
9. **1-Second Instant Bluetooth Auto-Reconnect:** Automatically caches paired watch remote ID / MAC (`vyra_ble_watch_remote_id`) in SharedPreferences and attempts instant 1-second background reconnection upon app launch without requiring manual scans.
10. **Peak Step Count Memory Lock:** Guarded incoming parsed step, calorie, and distance telemetry with `max()` peak retention, preventing older 20-minute historical packet dumps from regressing the daily aggregate.
11. **Live Battery Level Monitoring (GATT 0x180F / 0x2A19):** Real-time battery percentage badge integrated directly into the live watch status card.
12. **1-Tap Manual Pulse & BP Measurement Triggers:** Added interactive "Measure HR" and "Measure BP" action buttons with active countdown banners, optical sensor wake commands, and haptic feedback upon reading capture.

---

## 10. Multi-Agent Delegation & Token Armor Protocol

Defined in `AGENTS.md` and `GEMINI.md`:
1. **Gemini's Role:** Map Maker & Code Fetcher ONLY ("Yahan ye hai, wahan wo hai"). Scans thousands of lines, broad searches, and heavy file reads using Google AI 100% quota. Does not diagnose or take architectural decisions.
2. **Claude's Role:** Lead Architect, Decision Maker & Coder. Inspects only targeted 20-50 line slices fetched by Gemini. Identifies flaws, decides fixes, executes surgical edits (`replace_file_content`), and validates tests.
3. **Execution Guardrails:** Never read without range (`EndLine - StartLine <= 150`), grep before view, and no `git push` without explicit user permission.
4. **Pragmatic Lateral Engineering ("Dimaag Lagao" Principle):** Proactively identify and leverage local machine hardware and developer shortcuts (laptop Bluetooth BLE sniffing, ADB port tunnels, local mock bridges) to make testing and verification effortless without waiting for manual smartphone compilation.
5. **Zero-Guesswork Empirical Diagnostic Tooling Protocol ("Bina Tukke Lagaye Proactive Tool Banao"):** Strictly ban speculative guessing on unknown hardware/APIs. Proactively architect standalone diagnostic test harnesses, probe apps, and micro-modules with multi-preset libraries, raw packet logging, auto-winning signature detection, and self-contained forensic reports to verify ground truth before modifying production code.

---

## 11. Standalone Smartwatch Diagnostic Studio (`apps/watch_tester`)

- **Artifact Path:** `vyra_watch_studio_prober.apk` (Root directory, standalone build: 48MB)
- **Purpose:** Independent empirical hardware prober and live telemetry verification app built outside Vyra main codebase.
- **Hardware Ground Truth Verified (`Ultra2` [`71:7E:FB:00:03:CB`]):**
  - **Chipset Family:** Jerry / JieLi (JL7012 / AC695X) FitPro MCU.
  - **UART Write Char:** `6e400002-b5a3-f393-e0a9-e50e24dcca9d` (write/writeWithoutResponse).
  - **UART Notify Char:** `6e400003-b5a3-f393-e0a9-e50e24dcca9d` (notify).
  - **Live Ground Truth Extracted (Direct Mac BLE Verification):** Steps: 17,487 steps, Calories: 344 kcal (Authentic MCU hardware value), Distance: 12,240 m (12.24 km), Battery: 9%.
  - **Frame Structure:** Master command header `0xCD`, Slave response/notification header `0xDC`.
- **Eradicated Root Causes of Watch Reboots, Missing Vitals & False Battery:**
  1. **MCU Watchdog Reset / Command Blasting Bug:** Blasting 4 concurrent flash history queries on connect caused Jerry JL7012 SPI flash buffer overflow and instant MCU reset -> **Fixed:** Startup sanitized to a paced 5-step sequence (Pair Handshake, RTC Clock Sync, Authentic Battery Query, Real-Time Steps Enable, Day Summary Query) with 300ms inter-command spacing.
  2. **Parser Key Indexing Collision Bug:** In `0xDC` MCU responses (`DC 00 05 15 04 00 09 01`), `bytes[5]` is status `0x00` and `bytes[4]` is the metric Key (`0x04` HR, `0x14` SpO2, `0x05` BP, `0x0D` Pulse). The parser was mistakenly assigning `key = bytes[6] = 0x09`, ignoring all vitals -> **Fixed:** Clean discriminator between TLV (`bytes[4] == 0x01 && bytes[5] != 0x00`) and Direct MCU frames (`key = bytes[4]`).
  3. **Fake/Static Battery Display Bug:** GATT characteristic `0x2A19` returns a frozen 54% from ROM -> **Fixed:** Authentic battery level is actively queried via `[0xCD, 0x00, 0x06, 0x12, 0x01, 0x02, 0x00, 0x01, 0x01]` and parsed from Key `0x02` payload (`1..100%`).
  4. **Active Optical Stream Collision:** Background sport keepalives collided with live PPG sensor packets during user measurements -> **Fixed:** Background polling pauses during active measurement, and manual measurement triggers send single, un-flooded native commands.
  5. **Auto-Reconnect Scan Delay Race:** Reconnect routine triggered a 3-second BLE scan before connecting, causing timer re-entry and duplicate connection attempts -> **Fixed:** Directly connects to `BluetoothDevice.fromId(cleanMac)` with instant auto-connect fallback.
  6. **Zero Fake Calories Enforced:** Removed all remaining `steps * 0.04` fallback estimations from `hiwatch_pro_service.dart`. Only genuine hardware calories are processed.
  7. **Auto-ACK Protocol Engine:** Watch watchdog rebooted after 3-4 seconds when sending master sync frames (`0xCD`) because no Return ACK arrived -> **Fixed:** Return ACK `[0xDC, 0x00, 0x05, cmd, 0x01, seq0, seq1, 0x01]` is automatically returned and broadcast via writable UART.
  8. **Candidate Offset 10 Ground Truth & 0x0E Collision Fix:** Packet `CD 00 11 15 01 0C 00 0C 35 45 00 00 44 4F 00 00 2F D0 01 58` decoded with exact byte offsets: Steps `bytes[10..13]` = 17,487 steps, Distance `bytes[14..17]` = 12,240 m, Calories `bytes[18..19]` = 344 kcal. Restricted Day Summary parsing to Key `0x0C` exclusively to prevent Goal packet `0x0E` (containing 65,536) from corrupting the step count.
  9. **Dual-Opcode Optical Sensor Ignition:** Jerry JL7012 optical PPG sensor sleeps by default (especially under 10% battery) -> **Fixed:** Dispatches dual opcodes (classic `0x0D`/`0x0E`/`0x14` + modern `0x24` and combined `0x18`) with proactive 1.5s post-connection auto-start.
  11. **Master Multi-Vitals Stream Ground Truth (`Cmd 0x15, Key 0x0E`):** Reverse-engineered from official `BaseReceiveData.java` lines 1740-1789. Optical measurement triggers stream the final PPG vector in packet `CD 00 11 15 01 0E 00 0C 32 21 00 01 00 00 CB F4 63 56 79 47`:
      - `bytes[16]`: SpO2 % (`0x63` = 99%)
      - `bytes[17]`: Diastolic BP in mmHg (`0x56` = 86 mmHg)
      - `bytes[18]`: Systolic BP in mmHg (`0x79` = 121 mmHg)
      - `bytes[19]`: Heart Rate / Pulse in BPM (`0x47` = 71 BPM)
      - *Root Cause of 65536:* In this same packet, `bytes[10..13]` contains `00 01 00 00` (= 65,536). Misidentifying `0x0E` as Day Summary steps corrupted authentic steps (17,487) to 65536. Dedicating `0x0E` strictly to Multi-Vitals and guarding steps (`val != 65536`) eliminated step corruption and unlocked full optical vitals extraction.
  12. **Direct MCU 0x12 Vitals & Battery Collision Fix:** Prevented direct MCU vitals frames (`[0xCD, 0, 3, 0x12, 0x01, 75]`) from being misclassified as TLV by requiring `length >= 8 && keyId <= 0x30`. Gated battery responses to `0xDC` or single-byte payloads, preventing diastolic blood pressure from being swallowed as battery.
  13. **Main Vyra Mobile App Full Integration (`apps/mobile`):**
      - **Paced 6-Step Startup:** Pair Handshake (`0x12 0x0A`) -> RTC Time Sync (`0x12 0x01`) -> Authentic Battery Query (`0x12 0x02`) -> Real-Time Steps (`0x15 0x06`) -> Day Summary (`0x15 0x0C`) -> Multi-Vitals stream ignition (`0x18 0x01 0x01`).
      - **3.5s Hardware Watchdog Refresh:** Paced sport poll (`[0xCD, 0x00, 0x06, 0x15, 0x01, 0x01, 0x00, 0x01, 0x01]`) every 3500ms prevents the Jerry JL7012 4-5s watchdog disconnect.
      - **Continuous Connection & Auto-Reconnect:** Automatic seamless reconnect with backoff retry on transient RF/range drops. Disconnection occurs ONLY when user explicitly taps "Disconnect Watch".
      - **Complete UI Setup for All 6 Required Metrics:**
        - ❤️ **Pulse:** Live BPM with real-time pulsing heart animation and HR intensity zones.
        - 💧 **Blood Oxygen:** Live SpO2 % with physiological range bounds.
        - 🚶 **Live Steps:** Live step counter with 65,536 goal bitmask protection.
        - 🩺 **Blood Pressure:** Real-time systolic/diastolic reading (e.g. 119/84 mmHg).
        - 🔥 **Calories:** Authentic hardware calories (e.g. 353 kcal) without fake math multipliers.
        - 📏 **Distance:** Authentic hardware distance (e.g. 12.59 km).
        - 🔋 **Battery:** Authentic hardware battery status (e.g. 9%).
        - ⚡ **Continuous Sync Badge:** "Continuous Sync Active • Auto-Reconnect Enabled (3.5s Watchdog)".
        - 🛑 **Explicit Disconnect:** Dedicated high-visibility "Disconnect Watch" button with confirmation dialog.
  14. **Comprehensive Test Suite & Verification:**
      - `apps/mobile`: 260 / 260 smartwatch tests passing (`flutter test`), including exact physical Ultra2 ground-truth telemetry verification (`smartwatch_ui_and_telemetry_test.dart`).
      - Static Analysis: `flutter analyze` 100% clean with 0 warnings on `lib/`.

---
*End of Manifest — VYRA System Architecture Documented & Verified.*

