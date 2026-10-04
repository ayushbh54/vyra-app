# VYRA Mobile Rules — Hardcoded Model Delegation & Token Armor

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

---

## 🛠️ General Execution Guardrails
1. **Source of Truth**: Check `PROJECT_STATE.md` first before any broad codebase exploration.
2. **Never Read Without Range**: Every `view_file` call from Claude MUST include `StartLine` and `EndLine` with `EndLine - StartLine <= 150`.
3. **Grep Before View**: Always run `grep -n` to find exact lines before viewing.
4. **Preserve User Settings**: Never run `git push` without user explicitly saying "push kardo".
