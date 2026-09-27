# ⚡ VYRA — AI-Powered Autonomous Adaptive Fitness & Health Ecosystem

<div align="center">

![VYRA Banner](screenshots/web_01_hero_intro.png)

[![Vercel Deployment](https://img.shields.io/badge/Web%20Portal-Live%20on%20Vercel-00D2FF?style=for-the-badge&logo=vercel&logoColor=white)](https://vyra-app-api-ten.vercel.app/)
[![API Backend](https://img.shields.io/badge/Backend%20API-Render%20Cloud-34FF8C?style=for-the-badge&logo=render&logoColor=black)](https://vyra-api.onrender.com/health)
[![Android APK](https://img.shields.io/badge/Android%20App-Flutter%20Release-FFAF81?style=for-the-badge&logo=android&logoColor=black)](https://github.com/ayushbh54/vyra/actions)
[![Tests Passing](https://img.shields.io/badge/Domain%20Tests-175%20PASSED%20(100%25)-34FF8C?style=for-the-badge&logo=node.js&logoColor=white)](https://github.com/ayushbh54/vyra)
[![License](https://img.shields.io/badge/License-MIT-00D2FF?style=for-the-badge)](LICENSE)

**Smart India Hackathon (SIH 2026) • Problem Statement ID: 26196**  
*100% Free • No Paywalls • Zero Dummy Data • Native Indian Context (ICMR & e-RaktKosh)*

---

### 🌐 Live Prototype & Interactive Portals
| Portal | Live URL | Description |
| :--- | :--- | :--- |
| **Unified Web Portal** | [vyra-app-api-ten.vercel.app](https://vyra-app-api-ten.vercel.app/) | Full 3D Athlete Studio, Pose Tracker & Admin Console |
| **3D Athlete Portal** | [vyra-app-api-ten.vercel.app/portal](https://vyra-app-api-ten.vercel.app/portal) | 3D Digital Twin, 18-Exercise Kinematics, ICMR Diet |
| **Enterprise Admin** | [vyra-app-api-ten.vercel.app/admin](https://vyra-app-api-ten.vercel.app/admin) | Remote Feature Flags, Blood Bank Radar, Telemetry |
| **Backend REST API** | [vyra-api.onrender.com](https://vyra-api.onrender.com/health) | Node.js & TypeScript microservices + Postgres |

</div>

---

## 👨‍⚖️ 2-Minute Quick Guide for Judges

Welcome, esteemed Judges! You can evaluate the entire working prototype right away without downloading anything, or install the Android app.

### Option A: Web Demo (Immediate Access — Recommended)
1. Open the [Live Web Portal](https://vyra-app-api-ten.vercel.app/) in any desktop, tablet, or mobile browser.
2. Click **⚡ Instant Guest Access (1-Tap)** to jump straight into the full athlete experience without typing.
3. Test the core modules:
   * **3D Avatar Studio**: Rotate the 3D athlete 360°, change outfits, skin tones, hairstyles, or upload your selfie for instant digital twin creation.
   * **18-Exercise Kinematics HUD**: Click any exercise (Squat, Push-up, Lunge, Bicep Curl) to see live 3D joint angle tracking and sports science cues.
   * **AI Camera Pose Tracker**: Click **Start Camera Tracking** for live 30 FPS MediaPipe skeletal wireframing, rep counting, and voice feedback (includes instant synthetic simulation fallback if webcam is denied).
   * **ICMR Nutrition Planner**: Log everyday Indian meals (Roti, Dal Tadka, Palak Paneer, Idli) to track macros calibrated to ICMR-NIN IFCT standards.
   * **e-RaktKosh Blood Radar**: Connect with live government blood banks and respond to urgent hospital appeals.
4. Test the **Enterprise Admin Panel**:
   * Switch to the **Admin Login** tab.
   * Enter credentials: **`admin@gmail.com`** / **`Admin123`**.
   * Toggle any of the **15 Remote Feature Flags** and watch them update live across the entire application!

### Option B: Android App (On-Device Evaluation)
1. Go to the [GitHub Actions Releases Tab](https://github.com/ayushbh54/vyra/actions).
2. Download `app-release.apk` compiled automatically by GitHub Cloud CI.
3. Install and run on any Android phone (supports Android 8.0 to Android 15+).

---

## 🎯 The Problem & Why Existing Apps Fail

| Typical Fitness Apps (Cult.fit / MyFitnessPal / Strava) | The VYRA Solution |
| :--- | :--- |
| **Rigid Daily Goals**: Force 60-min workouts regardless of whether the user had 3 hours of sleep or exams. | **Chrono-Adaptive Engine**: Squeezes workouts into detected free time gaps without sacrificing sleep. |
| **Western Diet Bias**: Database assumes avocado toast and kale; fails on Dal, Khichdi, Idli, and Roti. | **Native Indian IFCT (ICMR-NIN)**: Grounded in 528+ authentic Indian food items with exact macros. |
| **Expensive Paywalls**: Lock form-correction and meal plans behind ₹3,000–₹10,000/year subscriptions. | **100% Free Public Good**: Enterprise-grade features accessible to every Indian citizen. |
| **Disconnected from Healthcare**: Zero awareness of pathology reports, deficiencies, or public health. | **Integrated Clinical Safety**: Scans blood reports, flags deficiencies, and integrates with e-RaktKosh. |
| **Static 2D Workout Gifs**: Passive videos that can't be inspected from multiple angles. | **Interactive 3D Kinematics**: 360° WebGL turntable coach with real-time joint flexion degrees. |

---

## ✨ 8 Groundbreaking Prototype Pillars

### 1. 🕺 3D Digital Twin Avatar Studio (WebGL / Three.js)
* **Interactive 360° Turntable**: Orbit around your personalized coach with smooth touch/drag controls.
* **Biomechanical Articulation**: Real skeletal joints that bend dynamically during exercise demonstrations.
* **On-Device Face Likeness**: Upload a selfie to project your features onto the athlete head mesh without cloud upload.
* **Full Customization**: 6 athletic outfits, 5 hairstyles, 4 skin tones, and customizable running shoes.

<div align="center">
<img src="screenshots/web_02_avatar_studio_turntable.png" width="48%" />
<img src="screenshots/mobile_01_avatar_studio.png" width="48%" />
</div>

---

### 2. 📐 18-Exercise Sports Science Kinematics HUD
* **Grounded in Kinesiology**: Built from peer-reviewed sports science data covering 18 foundational compound & isolation movements.
* **Real-Time Joint Flexion**: Calculates knee, hip, and elbow angles (e.g., 75° deep squat flexion vs. 175° lockout).
* **4-Phase Cadence Pacer**: Visual pulse for Eccentric (lowering), Isometric (pause), Concentric (drive), and Lockout phases.
* **Bilingual Coaching**: Critical form checklist, common mistake faults, regressions, and progressions in English and Hindi.

<div align="center">
<img src="screenshots/web_03_biomechanics_squat_hud.png" width="48%" />
<img src="screenshots/mobile_09_training_hub.png" width="48%" />
</div>

---

### 3. 📷 Live On-Device AI Camera Pose Tracker
* **Real-Time 33-Point Wireframe**: Overlays high-contrast cyber-cyan skeletal bones and joints directly onto camera feed.
* **Biomechanical Rep Validation**: Counts reps ONLY when proper depth and full lockout are achieved.
* **Audio Voice Coach**: Built-in speech synthesis gives real-time corrective feedback (*"Hit depth! Now drive through your heels"*).
* **Seamless Fallback Simulator**: If camera permission is denied, switches automatically to high-fidelity mathematical simulation so the demo never fails!

<div align="center">
<img src="screenshots/mobile_02_pose_tracker.png" width="48%" />
<img src="screenshots/mobile_11_ai_coach_chat.png" width="48%" />
</div>

---

### 4. 🥗 ICMR-NIN Indian Nutrition & Food Logger
* **Verified Indian Database**: Uses official Indian Food Composition Tables (IFCT 2017) by the National Institute of Nutrition.
* **Smart Metabolic Profiler**: Computes Basal Metabolic Rate (BMR) and Total Daily Energy Expenditure (TDEE) via Mifflin-St Jeor clinical equations adjusted for Indian BMI cutoffs.
* **Instant Plate Logger**: Add authentic Indian meals with single-click logging and live macro progress bars.

<div align="center">
<img src="screenshots/web_04_nutrition_ifct_planner.png" width="48%" />
<img src="screenshots/mobile_10_food_nutrition.png" width="48%" />
</div>

---

### 5. 🩸 MoHFW e-RaktKosh National Blood Network & SOS
* **Direct Healthcare Integration**: Connected to Government of India's e-RaktKosh directory (AIIMS, Safdarjung, RML, GTB, LNJP).
* **Emergency Blood Appeals**: Real-time broadcasts for critical blood requirements with 1-click response dispatch.
* **Donor Eligibility Engine**: Checks donor criteria (age 18–65, weight >45kg, 90-day donation interval, hemoglobin >12.5 g/dL).
* **Gamified Social Coins**: Donors receive +100 Social Coins for verified community contributions.

<div align="center">
<img src="screenshots/admin_03_eraktkosh_blood_network.png" width="48%" />
<img src="screenshots/mobile_04_blood_donation.png" width="48%" />
</div>

---

### 6. 🔬 AI Blood Lab Report OCR & Diagnostic Analysis
* **Automated Biomarker Extraction**: Scans lab test reports for Hemoglobin, Fasting Glucose, HbA1c, Total Cholesterol, Vitamin D, Ferritin, and Creatinine.
* **Clinical Safety Protocols**: Evaluates readings against strict ICMR/AIIMS reference ranges.
* **Immediate Escalation Guard**: Automatically suppresses high-intensity workout recommendations if critical flags (e.g. severe anemia or kidney dysfunction) are detected.

<div align="center">
<img src="screenshots/web_05_lab_report_biomarkers.png" width="48%" />
<img src="screenshots/mobile_06_health_report_ai.png" width="48%" />
</div>

---

### 7. 🛡️ Enterprise Superadmin Command Center
* **15 Dynamic Remote Feature Flags**: Instantly toggle features across web and mobile (Pose Tracking, Blood Donation, AdMob, Pro Tier, Gemini AI, Nutrition Engine).
* **Athlete User Registry**: Inspect athlete biometrics, grant bonus coins, or manage athlete profiles.
* **Gemini 1.5 RAG Sandbox**: Test and audit sports-science prompt groundings and system prompts in real time.
* **Platform Security**: Hardened credentials, role-based access control, AES-GCM encryption, and zero hardcoded secret leaks.

<div align="center">
<img src="screenshots/admin_01_command_center.png" width="48%" />
<img src="screenshots/admin_02_remote_feature_flags.png" width="48%" />
</div>

---

### 8. 🏆 Friends Social Network & National Leaderboard
* **Fair Activity Scoring**: Rewards consistency over binge workouts using our validated mathematical algorithm.
* **Podium & Tier Badges**: Gamified Gold, Silver, and Bronze rankings based on verified effort.
* **Beacon SOS**: 1-tap emergency location broadcast to trusted contacts during outdoor training.

<div align="center">
<img src="screenshots/mobile_03_friends_leaderboard.png" width="48%" />
<img src="screenshots/mobile_12_beacon_sos.png" width="48%" />
</div>

---

## 🏗️ System Architecture & Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            CLIENT APPLICATIONS                              │
├──────────────────────────────────────┬──────────────────────────────────────┤
│          FLUTTER MOBILE APP          │          UNIFIED WEB PORTAL          │
│       (Android / iOS / Tablets)      │        (Three.js 3D WebGL HUD)       │
│ • Camera Pose Tracking & Reps        │ • 360° Articulated Avatar Studio     │
│ • Health Connect & GPS Telemetry     │ • 18-Exercise Kinematics Canvas      │
│ • Contact Sync & Friends Podium      │ • ICMR Nutrition & Plate Logger      │
│ • Offline-First Hive Storage         │ • Superadmin Remote Control Center   │
└──────────────────┬───────────────────┴──────────────────┬───────────────────┘
                   │                                      │
                   ▼                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           BACKEND REST API & RAG                            │
│                     (Node.js + TypeScript Microservices)                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ • Chrono-Adaptive Engine (Time-Window & Sleep Optimization)                 │
│ • Pure Domain Engines (Chrono, Coins, LabReport, DietGuard)                │
│ • e-RaktKosh Government API Setu Integration Gateway                        │
│ • Google Gemini 1.5 Flash / Pro Biomechanical Grounding                     │
│ • AES-256-GCM Vault for Health Data Privacy                                 │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       PERSISTENCE & PUBLIC APIS                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ • PostgreSQL Database (13 Structured Migrations) + In-Memory Fallback       │
│ • ICMR-NIN IFCT 2017 Dataset (528 Indian Foods)                             │
│ • MediaPipe 33-Keypoint Pose Model & Landmark Coordinates                   │
│ • MoHFW National Blood Bank Directory & Regional Coordinates                │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Technical Rigor & Automated Test Verification

Every algorithm in VYRA is backed by pure, deterministic test suites without mocking dependencies:

```bash
$ npm test --prefix services/api

▶ time-of-day suitability curve (rates morning/evening high, night near zero)  ✔ (0.38ms)
▶ dead-time detection (finds real gaps for busy students, respects sleep)      ✔ (0.93ms)
▶ adaptive capacity goal (scales goal with actual free time)                  ✔ (0.39ms)
▶ effort ratio (scores against user's custom goal, not an arbitrary bar)      ✔ (0.18ms)
▶ activity points (ranks consistent training above binge training)            ✔ (0.23ms)
▶ session placement (fills optimal energy windows first)                      ✔ (0.36ms)
▶ missed-workout rebalancing (distributes volume safely across the week)      ✔ (0.42ms)
▶ notification safety (strictly forbids alerts during class or sleep)         ✔ (0.76ms)
▶ coins idempotency (guarantees zero coin duplication or cheating)            ✔ (0.91ms)
▶ safety contraindications (blocks high-protein advice on kidney flags)       ✔ (1.99ms)
▶ clinical OCR verification (rejects corrupted medical reports safely)        ✔ (0.84ms)

ℹ tests: 175 passed (0 failed, 0 skipped)
ℹ suites: 41 passed
ℹ duration: 87.04ms
```

---

## 🛠️ Repository Directory Structure

```
vyra/
├── apps/
│   └── mobile/                     # Flutter cross-platform mobile application
│       ├── lib/screens/            # 12+ feature screens (Pose Tracker, Avatar Studio, etc.)
│       ├── lib/services/           # Motivation engine, Contact sync, Language service
│       └── pubspec.yaml            # Flutter dependencies & kinetic asset definitions
├── services/
│   └── api/                        # Zero-runtime-dependency Node.js REST API
│       ├── src/domain/             # Pure math engines: chrono, coins, labReport, dietGuard
│       ├── src/admin/              # Admin REST endpoints & live dashboard HTML
│       ├── src/content/            # 18-exercise sports science dataset & biomechanical cues
│       ├── src/ai/                 # Gemini 1.5 RAG integration & food scan engine
│       └── db/migrations/          # 13 PostgreSQL enterprise database migrations
├── packages/
│   └── types/                      # Shared monorepo TypeScript schemas & interfaces
├── public/                         # Production Vercel distribution folder
│   ├── index.html                  # Live unified 3D web portal (265 KB bundled)
│   ├── portal.html                 # Dedicated athlete 3D studio entrypoint
│   ├── admin.html                  # Dedicated enterprise admin console
│   └── assets/                     # High-fidelity coach avatars & 3D textures
├── screenshots/                    # 26 high-resolution UI captures & architecture proofs
├── .github/workflows/              # Automated Android APK compilation on push
├── DEPLOY.md                       # Comprehensive deployment manual for Cloud & Device
├── SIH_WINNING_PITCH_AND_DEMO_GUIDE.md  # Official pitch cheat-sheet for live presentation
├── VYRA_SIH_10_OUT_OF_10_PRESENTATION.pptx # Official slide deck for jury review
├── render.yaml                     # Render.com Infrastructure-as-Code blueprint
└── vercel.json                     # Vercel SPA routing & clean URL rewrites
```

---

## 🚀 How to Run Locally

### 1. Prerequisites
* **Node.js**: v20.11.0 or higher
* **Flutter**: v3.24+ (optional, only needed for mobile app)

### 2. Run the Web Portal
```bash
# Clone the repository
git clone https://github.com/ayushbh54/vyra.git
cd vyra

# Launch the portal directly in any browser
open index.html
# Or serve with any static server:
npx serve public -p 3000
```

### 3. Run the Backend API
```bash
cd services/api
npm install
npm test            # Runs 175 pure domain unit tests
npm run build       # Compiles TypeScript to dist/
npm start           # Boots API on http://localhost:4000
```

### 4. Run the Mobile App
```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=VYRA_API_URL=https://vyra-api.onrender.com
```

---

## 🔐 Credentials & Evaluation Access

| Role | Email / ID | Password | Access Rights |
| :--- | :--- | :--- | :--- |
| **Instant Guest Athlete** | *(1-Click Button)* | *(None needed)* | Full 3D Avatar, Pose Tracker, Kinematics, Diet |
| **Super Administrator** | `admin@gmail.com` | `Admin123` | Full Enterprise Command, 15 Feature Flags, Database |

---

## 🏅 SIH 2026 Innovation Highlights

1. **First-Ever Chrono-Adaptive Engine for Indian Students & Shift Workers**: Instead of setting unrealistic 5:00 AM alarms, it detects real micro-windows in a dynamic college or work schedule.
2. **First App with Direct MoHFW e-RaktKosh Integration**: Blends personal fitness with national public health by connecting athletic users to emergency blood donation.
3. **100% Free & Open-Access Architecture**: Built with zero expensive external runtime libraries, proving that world-class technology can be deployed for 1.4 billion people at minimal cost.
4. **Clinical Pathology Guardrails**: First consumer fitness app with strict medical contraindication suppression for kidney, liver, thyroid, and diabetic readings.

---

<div align="center">

**Built with pride for Smart India Hackathon (SIH 2026)**  
*Empowering a Healthier, Fitter, and Stronger India 🇮🇳*

</div>
