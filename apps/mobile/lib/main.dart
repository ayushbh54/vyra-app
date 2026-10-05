import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'api/client.dart';
import 'dart:math' as math;
import 'screens/ai_chat.dart';
import 'screens/auth.dart';
import 'screens/challenges_hub.dart';
import 'screens/food.dart';
import 'screens/global_search.dart';
import 'screens/messages_inbox.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/profile.dart';
import 'screens/social_hub.dart';
import 'screens/training_hub.dart';
import 'services/language_service.dart';
import 'theme.dart';
import 'theme_manager.dart';
import 'widgets/common.dart';
import 'widgets/vyra_drawer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ThemeManager.instance.init(),
    LanguageService.instance.init(),
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: VColor.bgLift,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const VyraApp());
}

class VyraApp extends StatelessWidget {
  const VyraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<VyraApi>(
      create: (_) => VyraApi(),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeManager.instance.themeModeNotifier,
        builder: (context, themeMode, _) {
          return AnimatedBuilder(
            animation: LanguageService.instance,
            builder: (context, _) {
              return MaterialApp(
                title: 'VYRA',
                debugShowCheckedModeBanner: false,
                theme: buildVyraLightTheme(),
                darkTheme: buildVyraDarkTheme(),
                themeMode: themeMode,
                // ── Locale ────────────────────────────────────────────
                locale: LanguageService.instance.locale,
                supportedLocales: kVyraLanguages.map((l) => l.locale).toList(),
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const _Bootstrap(),
              );
            },
          );
        },
      ),
    );
  }
}

/// Restores a saved session, or offers the demo presets.
///
/// The presets are not decoration: they are how the product's central claim is
/// demonstrated in ten seconds. Switching from "Student" to "Remote worker"
/// changes the goal from 12 minutes to 30, and the app explains why.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _checking = true;
  bool _signedIn = false;
  bool _onboardingDone = false;
  bool _showDemoPicker = false;
  String? _startingPreset;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<VyraApi>().warmUpServer());
    _restore();
  }

  Future<void> _restore() async {
    final api = context.read<VyraApi>();
    await api.loadToken();
    if (!mounted) return;

    if (!api.isSignedIn) {
      setState(() { _signedIn = false; _checking = false; });
      return;
    }

    // INSTANT FAST-BOOT: Token is already cached on device!
    // Immediately unlock the app in Frame 1 without blocking on cold cloud networks.
    setState(() {
      _signedIn = true;
      _onboardingDone = true;
      _checking = false;
    });

    // Revalidate session & onboarding status in the background silently
    api.getProfile().then((profile) {
      if (!mounted) return;
      if (profile.onboardingStep < 9) {
        setState(() => _onboardingDone = false);
      }
    }).catchError((e) {
      if (!mounted) return;
      if (e is ApiException && e.status == 401) {
        setState(() {
          _signedIn = false;
        });
      }
    });
  }

  Future<void> _start(String preset) async {
    setState(() {
      _startingPreset = preset;
      _error = null;
    });
    try {
      await context.read<VyraApi>().startDemoSession(preset);
      // Demo accounts are pre-onboarded — see server.ts's demo/session route.
      if (mounted) setState(() { _signedIn = true; _onboardingDone = true; });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.status == 0
            ? 'Could not reach the VYRA server. Make sure it is running, then try again.'
            : e.message);
      }
    } finally {
      if (mounted) setState(() => _startingPreset = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: VLoading(label: 'Starting VYRA')));
    }

    if (_signedIn && _onboardingDone) return const HomeShell();

    if (_signedIn && !_onboardingDone) {
      return OnboardingFlow(onComplete: () => setState(() => _onboardingDone = true));
    }

    if (_showDemoPicker) return _buildDemoPicker();

    return AuthScreen(
      onAuthenticated: _restore,
      onDemoRequested: () => setState(() => _showDemoPicker = true),
    );
  }

  Widget _buildDemoPicker() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: VColor.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: VColor.text, size: 20),
          onPressed: () => setState(() => _showDemoPicker = false),
        ),
        title: const Text('Try a live demo'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(VSpace.xl),
          children: [
            Text(
              'Fitness that fits the day you actually have.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: VSpace.base),
            const Text(
              'Ten thousand steps is the same target whether your calendar is empty or you are '
              'on a twelve-hour shift. VYRA reads your real day, finds the minutes inside it, '
              'and sets a goal that fits them.',
              style: TextStyle(color: VColor.textMid, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: VSpace.xxl),
            const VLabel('See it with a real schedule'),
            const SizedBox(height: VSpace.md),
            _preset('student', 'Class 12 student', 'School, commute, coaching — 17 usable minutes'),
            _preset('nurse', 'Hospital nurse', 'A twelve-hour shift and two commutes'),
            _preset('homemaker', 'Runs the household', 'A day cut into pieces'),
            _preset('open', 'Works from home', 'An open calendar'),
            if (_error != null) ...[
              const SizedBox(height: VSpace.base),
              VErrorView(message: _error!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _preset(String id, String title, String subtitle) {
    final busy = _startingPreset == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: VSpace.sm),
      child: InkWell(
        onTap: _startingPreset != null ? null : () => _start(id),
        borderRadius: BorderRadius.circular(VRadius.md),
        child: Container(
          padding: const EdgeInsets.all(VSpace.base),
          constraints: const BoxConstraints(minHeight: kMinTouchTarget + 12),
          decoration: BoxDecoration(
            color: VColor.surface,
            border: Border.all(color: VColor.line),
            borderRadius: BorderRadius.circular(VRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: VColor.text, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(color: VColor.textLow, fontSize: 12.5)),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accent))
              else
                const Icon(Icons.arrow_forward, size: 18, color: VColor.textLow),
            ],
          ),
        ),
      ),
    );
  }
}

/// The five tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    TrainingHubScreen(),
    FoodScreen(),
    SocialHubScreen(),
    ChallengesHubScreen(),
    ProfileScreen(),
  ];

  static const _titles = [
    'Training',
    'Food & Nutrition',
    'Athlete Social',
    'Challenges & Cups',
    'My Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const VyraDrawer(),
      appBar: _index == 0
          ? null
          : AppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? VColor.surface : Colors.white,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(
                    Icons.menu_rounded,
                    color: Theme.of(context).brightness == Brightness.dark ? VColor.text : const Color(0xFF0F172A),
                    size: 24,
                  ),
                  tooltip: 'Open Profile Menu',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              titleSpacing: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF00D2FF)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'VYRA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _titles[_index],
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.dark ? VColor.text : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              actions: [
                // Global Search action
                IconButton(
                  tooltip: 'Global Search',
                  icon: Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).brightness == Brightness.dark ? VColor.textMid : const Color(0xFF64748B),
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                  ),
                ),
                // Instagram-style direct message button on Social tab only
                if (_index == 2)
                  IconButton(
                    tooltip: 'Direct Messages & Athlete Chat',
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.near_me_outlined,
                          color: Theme.of(context).brightness == Brightness.dark ? VColor.text : const Color(0xFF0F172A),
                          size: 23,
                        ),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D2FF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark ? VColor.surface : Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MessagesInboxScreen()),
                      );
                    },
                  ),
                const SizedBox(width: 4),
              ],
            ),

      // IndexedStack keeps each tab's state alive, so switching away from a
      // half-finished GPS recording and back does not lose it.
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Training'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant),
              label: 'Food'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Social'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events),
              label: 'Challenges'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _index == 0 ? const _FloatingAnimatedCoachBot() : null,
    );
  }
}


/// ALL-TIME FLOATING ANIMATED ROBOT COACH (Voice Talk & AI Assistant)
class _FloatingAnimatedCoachBot extends StatefulWidget {
  const _FloatingAnimatedCoachBot();

  @override
  State<_FloatingAnimatedCoachBot> createState() => _FloatingAnimatedCoachBotState();
}

class _FloatingAnimatedCoachBotState extends State<_FloatingAnimatedCoachBot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final floatOffset = math.sin(_ctrl.value * 2 * math.pi) * 3.5;
        final pulseAlpha = 0.35 + (math.sin(_ctrl.value * 2 * math.pi) * 0.18);

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiChatScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFF00D2FF).withValues(alpha: 0.75),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withValues(alpha: pulseAlpha),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34FF8C).withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF34FF8C),
                        width: 1.4,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.smart_toy_rounded,
                        color: Color(0xFF34FF8C),
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'COACH VYRA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text('🎙️', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                      Text(
                        'Tap for Voice Talk',
                        style: TextStyle(
                          color: Color(0xFF00D2FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
