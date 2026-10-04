# VYRA Workspace Rules — Hardcoded Model Delegation & Token Armor

## 🛡️ STRICT TOKEN ARMOR & ROLE DELEGATION POLICY

### 1. Primary Architecture Source of Truth: PROJECT_STATE.md
- **First Stop for Context**: Always read `PROJECT_STATE.md` at the project root as the primary source of truth for project architecture, directory structure, data flows, AI brains, and recent changes instead of re-scanning or re-reading the entire codebase.
- **Keep Continuously Updated**: Whenever architectural changes, new endpoints, new screens, or model upgrades are made, update `PROJECT_STATE.md` immediately to reflect the new state.

### 2. Gemini's Role: The Map Maker & Code Fetcher ONLY ("Yahan ye hai, wahan wo hai")
- **Gemini's ONLY Responsibility**:
  - Hazaaron lines scan karke sirf exact locations dhoondna:
    *"File A ke line 50 par function X hai, File B ke line 120 par state Y hai."*
  - Relevant raw code snippets aur line ranges (`L50-L90`) Claude ki table par laakar rakhna.
  - **Gemini khud koi issue diagnose nahi karega, na hi koi decision lega.**
  - Heavy token consumption (reading large files, broad searches) Gemini (Google AI Pro 100% quota) par rahega.

### 3. Claude's Role: The Real Brain (Issue Finder, Decision Maker & Coder)
- **Claude's Core Responsibilities**:
  - Gemini ke laaye huye code chunks ko **Claude khud analyze karega**.
  - **Issue aur Root Cause 100% Claude khud pakdega**:
    *"Is code mein ye flaw hai, yahan logic break ho raha hai."*
  - Architectural faisla aur plan Claude banayega.
  - Final surgical code edits (`replace_file_content`) aur tests (`dart analyze lib/`, `flutter test`) Claude execute karega.
- **Strict Token Armor Rule for Claude**:
  - Claude kabhi bhi 150+ lines ki file direct context mein dump nahi karega.
  - Claude hamesha targeted `view_file(StartLine, EndLine)` use karega (only 20-50 lines).

### 4. Mandatory Deep Audit & Exhaustive Bug Hunting Protocol
Whenever the user asks to **"audit"**, **"find bugs"**, or **"deep test"** any subsystem (Bluetooth, Avatar, AI Brains, Food Scan, Auth, Backend APIs, or State):
1. **Zero Superficial Audits:** Never stop at shallow code-reading, syntax checks, or happy-path compilation. Always dig down to the lowest layer of raw data.
2. **Raw Input/Output & Packet Tracing:** Trace exact bytes, bits, schemas, and payload shapes entering and leaving the system. Inspect parsing logic for collision bugs where status codes, headers, or frame bytes masquerade as payload values.
3. **Boundary & Dead-Zone Verification:** Test minimum and maximum physiological/business boundaries, partial data states, zero values, and sensor disconnects to ensure fallback logic does not drop legitimate readings or emit phantom values.
4. **Multi-Turn Continuous Stream Simulation:** Simulate sustained real-time usage (e.g., 30–50 consecutive turns or seconds of data streams) to catch state leaks, stale cache issues, timing anomalies, and dropouts.
5. **Resilience & Fuzz Testing:** Inject corrupted, malformed, or noisy input bytes to guarantee that parsers and handlers never throw unhandled exceptions or crash.
6. **Root Cause Precision:** Pinpoint the exact file, exact line number, and exact logical condition causing failure before proposing surgical fixes.

### 5. Pragmatic Lateral Engineering & Proactive Testing Instinct ("Dimaag Lagao" Rule)
Whenever developing, testing, or debugging hardware, external APIs, sensors, or complex user flows:
1. **Lateral Hardware & Tool Utilization:**
   - Proactively think beyond the mobile screen or theoretical code inspection.
   - Proactively evaluate and leverage the developer laptop's native hardware and environment (macOS Bluetooth / CoreBluetooth, local USB interfaces, Python sniffers, ADB forward/reverse tunnels, local web/mock servers) to verify features directly with zero friction.
2. **Proactive Shortcut Generation (Never Wait for User to Suggest):**
   - Always ask: *"Is there a faster, cleverer, zero-friction way to test this right here on the developer's laptop before pushing or deploying to mobile?"*
   - If external hardware (smartwatches, sensors, beacons) or third-party APIs are involved, proactively propose and create local bridge scripts, hardware sniffer utilities, or direct protocol emulators so testing happens with minimal user effort.
3. **Frictionless Developer Experience:**
   - Always prioritize the path of least resistance for the user. Cut out tedious manual steps by automating local hardware/software bridges wherever possible.

---

## 🛠️ General Execution Guardrails
1. **Source of Truth**: Check `PROJECT_STATE.md` first before any broad codebase exploration.
2. **Never Read Without Range**: Every `view_file` call from Claude MUST include `StartLine` and `EndLine` with `EndLine - StartLine <= 150`.
3. **Grep Before View**: Always run `grep -n` to find exact lines before viewing.
4. **Preserve User Settings**: Never run `git push` without user explicitly saying "push kardo".
5. **Deep Audit Standard**: Whenever an audit or bug check is requested, execute the full protocol (raw data tracing, collision analysis, boundaries, stream simulation, fuzz testing).
6. **Lateral Engineering Standard:** Always proactively identify and propose local machine shortcuts (laptop Bluetooth, ADB bridges, local test harnesses, sniffer scripts) to make verification as simple and instant as possible.
