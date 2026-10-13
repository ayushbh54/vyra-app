# 📱 VYRA Fitness — Cross-Platform Mobile Application (`apps/mobile`)

> **Application Name:** `VYRA Fitness`  
> **Bundle / Application ID:** `com.ayush.vyra.fitness`  
> **Version:** `2.0.0+6`  
> **Platforms:** Android (`API 26–35+`) & iOS (`iOS 15.0+`)

The **VYRA Fitness** Flutter application delivers real-time 3D biomechanical exercise coaching, on-device AI camera pose tracking, universal Bluetooth Low Energy (BLE) smartwatch telemetry, ICMR-NIN Indian nutrition tracking, clinical lab report analysis, and emergency public-health features.

---

## ✨ Key Subsystems

1. **4-Stage Closed-Loop 3D Avatar Biomechanical Engine (`v6.0`):**
   - **Files:** `assets/js/exercise_poses.js`, `lib/screens/exercise_detail.dart`, `lib/services/avatar_customization_service.dart`, `lib/services/exercise_animation_registry.dart`
   - **Persistent Verified Setup Cache (`0ms` Load):** Caches verified bone quaternion setups in `localStorage` and `SharedPreferences` (`vyra_verified_avatar_setups_v6`) so previously verified exercises execute immediately without repeating forward-kinematics verification.
   - **Rig-Calibrated Quaternion Similarity Conjugation:** Preserves authentic Mixamo GLB T-Pose bind quaternions (`GLB_BIND_META`) across `male_coach.glb` and `female_coach.glb` with automatic floor-lock solving (`0.00 mm` ground drift) and 360° touch camera orbit.

2. **On-Device AI Camera Pose Tracker + AR Target Aura (`v6.0`):**
   - **File:** `lib/screens/pose_tracker.dart`
   - **Coverage:** All **107 VYRA exercises** mapped across **15 biomechanical archetypes** with BlazePose Accurate 33-landmark tracking, Velocity-Adaptive One-Euro smoothing, 3D depth compensation, live AR Moving Target Aura (joint points + bone lines), and real-time voice coaching.

3. **Universal Multi-Protocol BLE Smartwatch Engine:**
   - **Files:** `lib/services/hiwatch_pro_service.dart`, `lib/services/watch_hardware_profile.dart`, `lib/screens/health_sync.dart`, `lib/screens/smartwatch_diagnostic_screen.dart`
   - **Protocols:** Supports HiWatchPro/Ultra2 (`0xCD`/`0xDC`), DaFit/Fire-Boltt/Noise/boAt (`0xAB`), Standard BLE SIG Heart Rate (`0x180D`/`0x2A37`), and Wear OS (`Galaxy Watch4`) with live Heart Rate, SpO2, Blood Pressure, Steps, Calories, Distance, and Battery.

4. **5-Engine Gemini AI Client & Offline Cache:**
   - **Files:** `lib/screens/ai_chat.dart`, `lib/screens/food_scan.dart`, `lib/screens/lab_report.dart`, `lib/services/gemini_response_cache.dart`, `lib/services/gemini_exercise_cache.dart`

---

## 🚀 Quick Commands

```bash
# Install dependencies
flutter pub get

# Run static analysis
flutter analyze lib/

# Run automated unit & widget test suites
flutter test

# Run on connected device
flutter run --dart-define=VYRA_API_URL=https://vyra-app.onrender.com

# Build Android Release APK
flutter build apk --release --dart-define=VYRA_API_URL=https://vyra-app.onrender.com

# Build iOS Release App (macOS)
flutter build ios --release --dart-define=VYRA_API_URL=https://vyra-app.onrender.com
```
