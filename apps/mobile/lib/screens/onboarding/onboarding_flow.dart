import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../services/language_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// ONBOARDING — runs right after signup (or on login, if a previous session
/// never finished it). Collects body info, fitness goal, diet preference,
/// and primary sport, then calls [VyraApi.completeOnboarding] once at the
/// end — every step just holds local state until then.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  int _step = 0;
  // Step 0 = Language, Steps 1-6 = original steps
  static const _totalSteps = 7;

  // ── Collected state ──────────────────────────────────────────────────────
  VyraLanguage? _selectedLanguage; // step 0
  DateTime? _dob;
  String? _gender;
  final _cityController = TextEditingController();
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '65');
  String? _disabilityAnswer; // 'no' | 'yes' | 'other'
  final _physicalConsiderationsController = TextEditingController();
  String? _fitnessGoal;
  String? _dietPreference;
  bool _dietToggle = true;
  String? _primarySport;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    _cityController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _physicalConsiderationsController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    switch (_step) {
      case 0: return _selectedLanguage != null;
      case 1: return _dob != null && _gender != null;
      case 2: return _heightController.text.isNotEmpty && _weightController.text.isNotEmpty;
      case 3: return _disabilityAnswer != null;
      case 4: return _fitnessGoal != null;
      case 5: return _dietPreference != null;
      case 6: return _primarySport != null;
      default: return true;
    }
  }

  Future<void> _next() async {
    // Apply selected language to the app immediately when leaving step 0.
    if (_step == 0 && _selectedLanguage != null) {
      await LanguageService.instance.setLanguage(_selectedLanguage!);
      if (!mounted) return;
    }
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      return;
    }
    await _finish();
  }

  void _back() {
    if (_step == 0) return; // first step — nothing to go back to, since this
    // screen isn't pushed on top of anything (it's shown directly by the
    // app's root state once an account exists but onboarding isn't done).
    setState(() => _step--);
    _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    setState(() { _saving = true; _error = null; });
    try {
      await context.read<VyraApi>().completeOnboarding(
        dob: _dob!.toIso8601String().split('T').first,
        gender: _gender,
        heightCm: double.tryParse(_heightController.text),
        weightKg: double.tryParse(_weightController.text),
        disabilityFlag: _disabilityAnswer != 'no',
        fitnessGoal: _fitnessGoal,
        dietToggle: _dietToggle,
        dietPreference: _dietPreference,
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        primarySport: _primarySport,
        hasPhysicalConsideration: _disabilityAnswer == 'yes',
        physicalConsiderationDetails: _disabilityAnswer == 'yes' && _physicalConsiderationsController.text.trim().isNotEmpty
            ? _physicalConsiderationsController.text.trim()
            : null,
      );
      if (!mounted) return;
      widget.onComplete();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.bg,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(VRadius.pill),
            child: LinearProgressIndicator(
              value: (_step + 1) / _totalSteps,
              backgroundColor: VColor.surfaceRaised,
              color: VColor.accent,
              minHeight: 6,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stepLanguage(),
                  _stepBasicInfo(),
                  _stepBodyInfo(),
                  _stepAccessibility(),
                  _stepGoal(),
                  _stepDiet(),
                  _stepSportAndReady(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(VSpace.base),
              child: Column(
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: VColor.crit, fontSize: 13)),
                    const SizedBox(height: VSpace.sm),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(VRadius.pill),
                        gradient: (_canContinue && !_saving)
                            ? const LinearGradient(colors: [VColor.accent, VColor.accentGreen])
                            : null,
                        color: (_canContinue && !_saving) ? null : VColor.surfaceRaised,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(VRadius.pill),
                          onTap: (_canContinue && !_saving) ? _next : null,
                          child: Center(
                            child: _saving
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent))
                                : Text(_step == _totalSteps - 1 ? 'Build my plan' : 'Continue',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w700,
                                        color: (_canContinue) ? VColor.textOnAccent : VColor.textLow)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Steps
  // ---------------------------------------------------------------------------

  Widget _stepShell({required String title, required String subtitle, required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSpace.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: VColor.text, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: VSpace.xs),
          Text(subtitle, style: const TextStyle(color: VColor.textMid, fontSize: 14)),
          const SizedBox(height: VSpace.xl),
          child,
        ],
      ),
    );
  }

  // ── Step 0 — Language Selection ───────────────────────────────────────────
  Widget _stepLanguage() {
    return _stepShell(
      title: 'Choose your language',
      subtitle: 'VYRA speaks your language — pick one to personalise every screen.',
      child: Column(
        children: [
          // Search / quick-pick the 4 most common at top
          Row(
            children: [
              for (final code in ['hi', 'en_IN', 'ta', 'te'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _langQuickChip(code),
                  ),
                ),
            ],
          ),
          const SizedBox(height: VSpace.base),
          const Divider(color: VColor.line),
          const SizedBox(height: VSpace.sm),
          // Full list
          ...kVyraLanguages.map((lang) => _langTile(lang)),
        ],
      ),
    );
  }

  Widget _langQuickChip(String prefsKey) {
    final lang = kVyraLanguages.firstWhere(
      (l) => l.prefsKey == prefsKey,
      orElse: () => kVyraLanguages.first,
    );
    final selected = _selectedLanguage?.prefsKey == lang.prefsKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedLanguage = lang),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? VColor.accentGlow : VColor.surface,
          borderRadius: BorderRadius.circular(VRadius.md),
          border: Border.all(
            color: selected ? VColor.accent : VColor.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(lang.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              lang.languageCode == 'en'
                  ? (lang.countryCode == 'IN' ? 'EN' : lang.countryCode ?? 'EN')
                  : lang.languageCode.toUpperCase(),
              style: TextStyle(
                color: selected ? VColor.accent : VColor.textMid,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langTile(VyraLanguage lang) {
    final selected = _selectedLanguage?.prefsKey == lang.prefsKey;
    return Padding(
      padding: const EdgeInsets.only(bottom: VSpace.sm),
      child: InkWell(
        onTap: () => setState(() => _selectedLanguage = lang),
        borderRadius: BorderRadius.circular(VRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? VColor.accentGlow : VColor.surface,
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(
              color: selected ? VColor.accent : VColor.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Flag
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? VColor.accent.withValues(alpha: 0.15) : VColor.surfaceRaised,
                  borderRadius: BorderRadius.circular(VRadius.sm),
                ),
                child: Center(
                  child: Text(lang.flag, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: VSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.nativeName,
                      style: TextStyle(
                        color: selected ? VColor.text : VColor.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      lang.displayName,
                      style: const TextStyle(color: VColor.textLow, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: VColor.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: VColor.textOnAccent, size: 14),
                )
              else
                const Icon(Icons.radio_button_unchecked, color: VColor.line, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceCard({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSpace.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(VSpace.base),
          decoration: BoxDecoration(
            color: selected ? VColor.accentGlow : VColor.surface,
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(color: selected ? VColor.accent : VColor.line),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? VColor.accent : VColor.textMid),
              const SizedBox(width: VSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(
                        color: selected ? VColor.text : VColor.textMid,
                        fontWeight: FontWeight.w600, fontSize: 15)),
                    if (subtitle != null)
                      Text(subtitle, style: const TextStyle(color: VColor.textLow, fontSize: 12)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: VColor.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBasicInfo() {
    return _stepShell(
      title: 'About you',
      subtitle: 'Used to personalize your plan — never shown on your public profile.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DATE OF BIRTH', style: TextStyle(color: VColor.textMid, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: VSpace.xs),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(2000, 1, 1),
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) setState(() => _dob = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(VSpace.base),
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(VRadius.lg),
                border: Border.all(color: VColor.line),
              ),
              child: Row(children: [
                const Icon(Icons.cake_outlined, color: VColor.textLow, size: 20),
                const SizedBox(width: VSpace.sm),
                Text(_dob == null ? 'Select date' : _dob!.toIso8601String().split('T').first,
                    style: TextStyle(color: _dob == null ? VColor.textLow : VColor.text)),
              ]),
            ),
          ),
          const SizedBox(height: VSpace.lg),
          const Text('GENDER', style: TextStyle(color: VColor.textMid, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: VSpace.xs),
          for (final g in const [
            ('male', 'Male'), ('female', 'Female'),
            ('other', 'Other'), ('prefer_not_to_say', 'Prefer not to say'),
          ])
            _choiceCard(label: g.$2, icon: Icons.person_outline,
                selected: _gender == g.$1, onTap: () => setState(() => _gender = g.$1)),
          const SizedBox(height: VSpace.lg),
          const Text('CITY (OPTIONAL)', style: TextStyle(color: VColor.textMid, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: VSpace.xs),
          TextField(
            controller: _cityController,
            style: const TextStyle(color: VColor.text),
            decoration: const InputDecoration(hintText: 'e.g. Ghaziabad'),
          ),
        ],
      ),
    );
  }

  Widget _stepBodyInfo() {
    return _stepShell(
      title: 'Body basics',
      subtitle: 'Powers your calorie targets and workout intensity.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HEIGHT (CM)', style: TextStyle(color: VColor.textMid, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: VSpace.xs),
          TextField(
            controller: _heightController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: VColor.text),
            decoration: const InputDecoration(suffixText: 'cm'),
          ),
          const SizedBox(height: VSpace.lg),
          const Text('WEIGHT (KG)', style: TextStyle(color: VColor.textMid, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: VSpace.xs),
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: VColor.text),
            decoration: const InputDecoration(suffixText: 'kg'),
          ),
        ],
      ),
    );
  }

  Widget _stepAccessibility() {
    return _stepShell(
      title: 'Any physical considerations or injuries?',
      subtitle: 'VYRA AI will adapt your daily workout routines and strictly avoid contraindicated exercises.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _choiceCard(label: 'No, full mobility', icon: Icons.check_circle_outline,
              selected: _disabilityAnswer == 'no', onTap: () => setState(() => _disabilityAnswer = 'no')),
          _choiceCard(label: 'Yes, I have an injury or physical condition', icon: Icons.accessible_forward_rounded,
              selected: _disabilityAnswer == 'yes', onTap: () => setState(() => _disabilityAnswer = 'yes')),
          _choiceCard(label: 'Prefer not to say', icon: Icons.remove_red_eye_outlined,
              selected: _disabilityAnswer == 'other', onTap: () => setState(() => _disabilityAnswer = 'other')),
          if (_disabilityAnswer == 'yes') ...[
            const SizedBox(height: VSpace.sm),
            Container(
              padding: const EdgeInsets.all(VSpace.base),
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(VRadius.lg),
                border: Border.all(color: VColor.accent.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.healing_rounded, color: VColor.accent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Describe your physical condition or injury',
                        style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'e.g. Knee pain, ACL recovery, lower back disc issue, rotator cuff strain, asthma. AI will filter out contraindicated movements and prescribe safe alternatives.',
                    style: TextStyle(color: VColor.textLow, fontSize: 12),
                  ),
                  const SizedBox(height: VSpace.sm),
                  TextField(
                    controller: _physicalConsiderationsController,
                    maxLines: 3,
                    style: const TextStyle(color: VColor.text, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'e.g. Left knee meniscus injury, avoid deep squats or jumping...',
                      hintStyle: const TextStyle(color: VColor.textLow, fontSize: 12.5),
                      filled: true,
                      fillColor: VColor.surfaceRaised,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.md),
                        borderSide: const BorderSide(color: VColor.line),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepGoal() {
    const goals = [
      ('lose_weight', 'Lose weight', Icons.trending_down),
      ('gain_weight', 'Gain weight', Icons.trending_up),
      ('maintain', 'Maintain fitness', Icons.balance),
      ('general_wellness', 'General wellness', Icons.favorite_outline),
    ];
    return _stepShell(
      title: "What's your goal?",
      subtitle: 'We\'ll shape your daily plan around this.',
      child: Column(
        children: [
          for (final g in goals)
            _choiceCard(label: g.$2, icon: g.$3,
                selected: _fitnessGoal == g.$1, onTap: () => setState(() => _fitnessGoal = g.$1)),
        ],
      ),
    );
  }

  Widget _stepDiet() {
    const prefs = [
      ('veg_no_egg', 'Vegetarian (no egg)', Icons.eco_outlined),
      ('veg_with_egg', 'Vegetarian (with egg)', Icons.egg_outlined),
      ('non_veg', 'Non-vegetarian', Icons.set_meal_outlined),
    ];
    return _stepShell(
      title: 'Dietary preference',
      subtitle: 'Every recipe and meal suggestion respects this — always.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in prefs)
            _choiceCard(label: p.$2, icon: p.$3,
                selected: _dietPreference == p.$1, onTap: () => setState(() => _dietPreference = p.$1)),
          const SizedBox(height: VSpace.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: VColor.accent,
            title: const Text('Enable diet planning', style: TextStyle(color: VColor.text)),
            subtitle: const Text('Turn off to hide meal plans app-wide.',
                style: TextStyle(color: VColor.textLow, fontSize: 12)),
            value: _dietToggle,
            onChanged: (v) => setState(() => _dietToggle = v),
          ),
        ],
      ),
    );
  }

  Widget _stepSportAndReady() {
    const sports = [
      ('run', 'Running', Icons.directions_run),
      ('ride', 'Cycling', Icons.directions_bike),
      ('walk', 'Walking', Icons.directions_walk),
      ('yoga', 'Yoga', Icons.self_improvement),
      ('other', 'Something else', Icons.sports_gymnastics),
    ];
    return _stepShell(
      title: 'Primary sport',
      subtitle: 'You can change this any time from your profile.',
      child: Column(
        children: [
          for (final s in sports)
            _choiceCard(label: s.$2, icon: s.$3,
                selected: _primarySport == s.$1, onTap: () => setState(() => _primarySport = s.$1)),
          const SizedBox(height: VSpace.lg),
          const VDisclaimer(
            'Your plan is generated the moment you tap "Build my plan" — workouts, '
            'diet targets, and your first challenges will all be waiting on Home.',
          ),
        ],
      ),
    );
  }
}
