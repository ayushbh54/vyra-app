# VYRA — Adaptive Biometrics, Training & Nutrition Ecosystem

> **100% Free • No Paywall • Zero External NPM Runtime Dependencies • Indian Context**

VYRA is an AI-powered fitness and health ecosystem that adapts to the athlete's real day. It features real-time GPS telemetry, smartwatch & Health Connect synchronization, 3D biomechanics coaching, AI nutrition with Indian meal planning, lab blood report analysis, and social challenges.

---

## 🏛️ Project Architecture

```
vyra/
├── .github/
│   └── workflows/
│       └── build-apk.yml       # GitHub Actions CI: Auto-builds release APK on push
├── apps/
│   └── mobile/                 # Flutter application (28 screens, dark Stitch Kinetic theme)
│       ├── lib/                # UI, Models, API client, Health Connect service
│       └── build-apk.sh        # Local release APK build script
├── packages/
│   └── types/                  # Shared TypeScript models & domain validation rules
└── services/
    └── api/                    # Zero-dependency Node.js REST API
        ├── src/                # Endpoints, domain engines, auth, AES encryption
        ├── db/migrations/      # 12 PostgreSQL migrations
        └── render.yaml         # Render.com Blueprint definition
```

---

## 🚀 1-Click Deployment (Render.com)

1. Fork or push this repository to GitHub.
2. In [Render Dashboard](https://dashboard.render.com), click **New +** ➔ **Blueprint**.
3. Select your repository. Render will automatically read `render.yaml` and configure:
   * **Node.js Web Service** (`vyra-api`)
   * **PostgreSQL Database** (`vyra-db`)
4. Add your **Gemini AI Keys** in the Render Environment Variables:
   * `GEMINI_API_KEY` (Master fallback)
   * `GEMINI_RECIPE_API_KEY`
   * `GEMINI_FOOD_API_KEY`
   * `GEMINI_LAB_API_KEY`
   * `GEMINI_CHAT_API_KEY`
   * `GEMINI_EVENTS_API_KEY`

---

## 📱 Release APK (GitHub Actions)

This repository includes an automated GitHub Actions CI workflow (`.github/workflows/build-apk.yml`):

1. On push to `main` (or trigger via `Actions` tab), GitHub cloud compiles:
   * Universal Release APK (`app-release.apk`)
   * ARM64 Release APK (`app-arm64-v8a-release.apk`)
   * Pre-configured to point to `https://vyra-api.onrender.com`
2. Download the APK artifact directly from the **Actions** tab and install on any Android phone!

---

## 💻 Local Development

### 1. Backend
```bash
cp .env.example .env
# Edit .env with your keys
npm install
npm test            # Runs 168 domain tests
npm run test:e2e    # Runs 12 live HTTP end-to-end tests
npm run dev         # Starts API on http://localhost:4000
```

### 2. Flutter Mobile
```bash
cd apps/mobile
flutter pub get
flutter analyze     # 0 errors, 0 warnings
flutter run         # Launches on connected device or emulator
```

---

## 🔒 Privacy & Safety Guarantee
* Health telemetry is stored in India with AES-GCM encryption.
* AI lab report advice suppresses dietary guidance and generates immediate doctor referral when critical biomarkers are identified.
* Coins are earned exclusively through consistency and effort — no purchase or paywall exists.
