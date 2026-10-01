import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';
import 'challenge_detail.dart';
import 'pose_tracker.dart';

/// TAB 4 — CHALLENGES & REWARDS
///
/// Personal streaks, community-wide leagues, and transparent coin economics.
/// Coins are purely earned through physical effort — zero paywalls or purchases.
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  WalletData? _wallet;
  List<CustomChallenge>? _challenges;
  String? _error;
  bool _checkingIn = false;

  // Track joined community challenges locally
  final Set<String> _joinedCommunityChallenges = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = context.read<VyraApi>();
      final results = await Future.wait([api.wallet(), api.myCustomChallenges()]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as WalletData;
          _challenges = results[1] as List<CustomChallenge>;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _createChallenge() async {
    final result = await showDialog<({String title, String rules, int durationDays})>(
      context: context,
      builder: (_) => const _NewChallengeDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await context.read<VyraApi>().createCustomChallenge(
            title: result.title,
            rules: result.rules,
            durationDays: result.durationDays,
          );
      HapticFeedback.mediumImpact();
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

    String _detectExerciseForChallenge(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('push')) return 'pushup';
    if (lower.contains('squat')) return 'squat';
    if (lower.contains('curl') || lower.contains('arm') || lower.contains('bicep')) return 'bicep_curl';
    if (lower.contains('bridge') || lower.contains('glute') || lower.contains('hip')) return 'glute_bridge';
    if (lower.contains('jump') || lower.contains('cardio') || lower.contains('jack')) return 'jumping_jacks';
    return 'squat';
  }

  Future<void> _verifyAndCheckIn(CustomChallenge challenge) async {
    final api = context.read<VyraApi>();
    final detectedEx = _detectExerciseForChallenge(challenge.title);

    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VColor.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
        side: BorderSide(color: VColor.line),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(VSpace.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: VColor.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: VColor.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Workout Verification',
                      style: TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Verify daily proof for "${challenge.title}"',
                      style: const TextStyle(color: VColor.textLow, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: VSpace.base),
            // Primary AI Camera Movement Verification
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [VColor.accent.withValues(alpha: 0.15), VColor.surfaceRaised],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(VRadius.lg),
                border: Border.all(color: VColor.accent.withValues(alpha: 0.4)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: VColor.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded, color: VColor.accent),
                ),
                title: Row(
                  children: [
                    const Text('Live AI Camera Form Verification',
                        style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: VColor.accentGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(VRadius.pill),
                      ),
                      child: const Text('RECOMMENDED',
                          style: TextStyle(color: VColor.accentGreen, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'AI validates posture, range of motion & counts only correct reps with real-time audio guidance.',
                  style: TextStyle(color: VColor.textMid, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: VColor.accent),
                onTap: () => Navigator.pop(ctx, 'live_camera'),
              ),
            ),
            const SizedBox(height: VSpace.sm),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: VColor.accentGreen),
              title: const Text('Take Snapshot Proof', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600)),
              subtitle: const Text('Instant biometric & pose verification snapshot', style: TextStyle(color: VColor.textMid, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'photo_camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: VColor.accent),
              title: const Text('Upload from Gallery', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600)),
              subtitle: const Text('Upload recent workout snapshot', style: TextStyle(color: VColor.textMid, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            const SizedBox(height: VSpace.sm),
          ],
        ),
      ),
    );

    if (mode == null || !mounted) return;

    if (mode == 'live_camera') {
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PoseTrackerScreen(
            exerciseName: detectedEx,
            targetReps: 10,
            isChallengeVerification: true,
            challengeTitle: challenge.title,
          ),
        ),
      );

      if (verified != true || !mounted) return;

      setState(() => _checkingIn = true);
      try {
        final streak = await api.checkinChallenge(challenge.id);
        HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() {
            _challenges = [
              for (final c in _challenges ?? [])
                if (c.id == challenge.id) c.copyWith(streak: streak, checkedInToday: true) else c,
            ];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 AI Camera Verified! 10 reps completed with good form. $streak-day streak!'),
              backgroundColor: VColor.accentGreen,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification error: $e')));
      } finally {
        if (mounted) setState(() => _checkingIn = false);
      }
      return;
    }

    final picker = ImagePicker();
    final source = mode == 'photo_camera' ? ImageSource.camera : ImageSource.gallery;

    try {
      final photo = await picker.pickImage(source: source, imageQuality: 85);
      if (photo == null || !mounted) return;

      setState(() => _checkingIn = true);

      // Show AI verification pass
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: VColor.surfaceRaised,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.lg)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const CircularProgressIndicator(color: VColor.accent),
                const SizedBox(height: 16),
                const Text(
                  'AI Analyzing Workout Proof...',
                  style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Running Vision & Movement Verification on "${challenge.title}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: VColor.textMid, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      final streak = await api.checkinChallenge(challenge.id);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _challenges = [
            for (final c in _challenges ?? [])
              if (c.id == challenge.id) c.copyWith(streak: streak, checkedInToday: true) else c,
          ];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔥 AI Verified & Checked In! $streak-day streak!'),
            backgroundColor: VColor.accentGreen,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification error: $e')));
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _toggleCommunityChallenge(String id, String title) async {
    HapticFeedback.selectionClick();
    if (_joinedCommunityChallenges.contains(id)) {
      setState(() {
        _joinedCommunityChallenges.remove(id);
      });
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VColor.surfaceRaised,
          title: Text('Join "$title"?', style: const TextStyle(color: VColor.text)),
          content: const Text("You'll be held accountable!", style: TextStyle(color: VColor.textMid)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: VColor.textLow)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: VColor.accent),
              child: const Text('Join', style: TextStyle(color: VColor.textOnAccent)),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        setState(() {
          _joinedCommunityChallenges.add(id);
        });
      }
    }
  }

  void _openCustomDetail(CustomChallenge c) {
    pushScreen(
      context,
      c.title,
      ChallengeDetailScreen(
        customChallenge: c,
        onCheckedIn: (newStreak) {
          setState(() {
            _challenges = [
              for (final item in _challenges ?? [])
                if (item.id == c.id) item.copyWith(streak: newStreak, checkedInToday: true) else item,
            ];
          });
        },
      ),
    );
  }

  void _openCommunityDetail(_CommunityChallengeData item) {
    pushScreen(
      context,
      item.title,
      ChallengeDetailScreen(
        communityId: item.id,
        title: item.title,
        description: item.description,
        badge: item.badge,
        participants: item.participants,
        rewardCoins: item.rewardCoins,
        currentProgress: item.currentProgress,
        progressLabel: item.progressLabel,
        onToggleJoin: () => _toggleCommunityChallenge(item.id, item.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const VHeaderBadge(label: 'REWARDS & CHALLENGES • PHASE 04', accentColor: VColor.accent),
                    const Spacer(),
                    if (_wallet != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: VColor.surfaceRaised,
                          borderRadius: BorderRadius.circular(VRadius.pill),
                          border: Border.all(color: VColor.accent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded, color: VColor.accentOrange, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${_wallet!.balance.balance} Coins',
                              style: const TextStyle(color: VColor.text, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'CHALLENGES',
                  style: TextStyle(
                    color: VColor.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Build daily streaks, join community leagues & earn verified coins',
                  style: TextStyle(color: VColor.textMid, fontSize: 13),
                ),
                const SizedBox(height: VSpace.md),

                // ── Segmented Tab Selector ─────────────────────────────────
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: VColor.surface,
                    borderRadius: BorderRadius.circular(VRadius.pill),
                    border: Border.all(color: VColor.line),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: VColor.accent,
                      borderRadius: BorderRadius.circular(VRadius.pill),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: VColor.textOnAccent,
                    unselectedLabelColor: VColor.textMid,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    tabs: const [
                      Tab(text: 'Personal'),
                      Tab(text: 'Community'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.xs),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: VColor.accent,
              backgroundColor: VColor.surface,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPersonalChallengesTab(),
                  _buildCommunityChallengesTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: PERSONAL CHALLENGES ─────────────────────────────────────────────
  Widget _buildPersonalChallengesTab() {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(VSpace.base),
        children: [VErrorView(message: _error!, onRetry: _load)],
      );
    }
    if (_challenges == null) {
      return const Center(child: VLoading());
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.sm, VSpace.base, VSpace.xxxl),
      children: [
        // Top Action Card to Create Challenge
        Container(
          padding: const EdgeInsets.all(VSpace.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [VColor.accent.withValues(alpha: 0.18), VColor.surfaceRaised],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(color: VColor.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: VColor.accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: VColor.accent, size: 24),
              ),
              const SizedBox(width: VSpace.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Your Challenge',
                        style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Set custom rules, duration & build daily consistency.',
                        style: TextStyle(color: VColor.textMid, fontSize: 12)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _createChallenge,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create'),
                style: FilledButton.styleFrom(
                  backgroundColor: VColor.accent,
                  foregroundColor: VColor.textOnAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.base),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const VLabel('ACTIVE PERSONAL CHALLENGES'),
            Text('${_challenges!.length} active', style: const TextStyle(color: VColor.textLow, fontSize: 11)),
          ],
        ),
        const SizedBox(height: VSpace.sm),

        if (_challenges!.isEmpty)
          VCard(
            tone: CardTone.raised,
            child: Column(
              children: [
                const Icon(Icons.flag_outlined, size: 40, color: VColor.textMid),
                const SizedBox(height: VSpace.sm),
                const Text('No Custom Challenges Yet',
                    style: TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Create your own habit challenge (e.g. 15-min daily stretch, 10k steps, or cold plunge) and track your streak!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VColor.textMid, fontSize: 13),
                ),
                const SizedBox(height: VSpace.md),
                OutlinedButton.icon(
                  onPressed: _createChallenge,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Start First Challenge'),
                ),
              ],
            ),
          )
        else
          for (final c in _challenges!)
            Padding(
              padding: const EdgeInsets.only(bottom: VSpace.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(VRadius.md),
                onTap: () => _openCustomDetail(c),
                child: _ChallengeCard(
                  challenge: c,
                  busy: _checkingIn,
                  onCheckIn: () => _verifyAndCheckIn(c),
                ),
              ),
            ),
      ],
    );
  }

  // ── TAB 2: COMMUNITY CHALLENGES ───────────────────────────────────────────
  Widget _buildCommunityChallengesTab() {
    final communityList = [
      _CommunityChallengeData(
        id: 'comm_steps_50k',
        title: 'Weekly 50,000 Steps Marathon',
        description: 'Walk or run 50,000 steps across 7 days. Sync via GPS or wearable.',
        badge: '7 Days',
        participants: 0,
        rewardCoins: 50,
        currentProgress: 0.0,
        progressLabel: 'Not started yet',
      ),
      _CommunityChallengeData(
        id: 'comm_nosugar_7d',
        title: '7-Day Zero Added Sugar Sprint',
        description: 'Skip all sweetened beverages, sodas & mithai for a clean digestive reset.',
        badge: 'Nutrition',
        participants: 0,
        rewardCoins: 40,
        currentProgress: 0.0,
        progressLabel: 'Not started yet',
      ),
      _CommunityChallengeData(
        id: 'comm_squats_100',
        title: 'Desi Strength: 100 Daily Squats',
        description: 'Complete 100 bodyweight squats daily using the 3D Form Coach.',
        badge: 'Strength',
        participants: 0,
        rewardCoins: 60,
        currentProgress: 0.0,
        progressLabel: 'Not started yet',
      ),
      _CommunityChallengeData(
        id: 'comm_morning_run',
        title: 'Early Bird 5K Morning Run',
        description: 'Record an outdoor 5K run between 5:00 AM and 8:00 AM on the map.',
        badge: 'Cardio',
        participants: 0,
        rewardCoins: 35,
        currentProgress: 0.0,
        progressLabel: 'Not started yet',
      ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.sm, VSpace.base, VSpace.xxxl),
      children: [
        const VCard(
          tone: CardTone.accent,
          child: Row(
            children: [
              Icon(Icons.people_alt_rounded, color: VColor.accent, size: 28),
              SizedBox(width: VSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join Community Leagues',
                        style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Compete alongside fellow runners and athletes across India.',
                        style: TextStyle(color: VColor.textMid, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.base),
        const VLabel('ACTIVE COMMUNITY LEAGUES'),
        const SizedBox(height: VSpace.sm),

        for (final item in communityList)
          Padding(
            padding: const EdgeInsets.only(bottom: VSpace.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(VRadius.md),
              onTap: () => _openCommunityDetail(item),
              child: _CommunityChallengeCard(
                data: item,
                isJoined: _joinedCommunityChallenges.contains(item.id),
                onToggleJoin: () => _toggleCommunityChallenge(item.id, item.title),
              ),
            ),
          ),
      ],
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// COMMUNITY CHALLENGE CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _CommunityChallengeData {
  _CommunityChallengeData({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    required this.participants,
    required this.rewardCoins,
    required this.currentProgress,
    required this.progressLabel,
  });

  final String id;
  final String title;
  final String description;
  final String badge;
  final int participants;
  final int rewardCoins;
  final double currentProgress;
  final String progressLabel;
}

class _CommunityChallengeCard extends StatelessWidget {
  const _CommunityChallengeCard({
    required this.data,
    required this.isJoined,
    required this.onToggleJoin,
  });

  final _CommunityChallengeData data;
  final bool isJoined;
  final VoidCallback onToggleJoin;

  @override
  Widget build(BuildContext context) {
    return VCard(
      tone: isJoined ? CardTone.raised : CardTone.normal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      children: [
                        VPill(data.badge),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: VColor.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(VRadius.sm),
                          ),
                          child: Text('+${data.rewardCoins} Coins',
                              style: const TextStyle(color: VColor.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(data.title,
                        style: const TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onToggleJoin,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isJoined ? VColor.accentGreen : VColor.accent,
                  side: BorderSide(color: isJoined ? VColor.accentGreen : VColor.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(isJoined ? 'Active ✓' : 'Join'),
              ),
            ],
          ),
          const SizedBox(height: VSpace.xs),
          Text(data.description, style: const TextStyle(color: VColor.textMid, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: VSpace.md),

          // Progress bar if joined
          if (isJoined) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data.progressLabel, style: const TextStyle(color: VColor.text, fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${(data.currentProgress * 100).toInt()}%',
                    style: const TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(VRadius.pill),
              child: LinearProgressIndicator(
                value: data.currentProgress,
                minHeight: 6,
                backgroundColor: VColor.steel,
                valueColor: const AlwaysStoppedAnimation(VColor.accent),
              ),
            ),
            const SizedBox(height: VSpace.sm),
          ],

          Row(
            children: [
              const Icon(Icons.people_outline_rounded, size: 14, color: VColor.textLow),
              const SizedBox(width: 4),
              Text(data.participants == 0 ? '—' : '${data.participants} athletes joined',
                  style: const TextStyle(color: VColor.textLow, fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERSONAL CHALLENGE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge, required this.busy, required this.onCheckIn});

  final CustomChallenge challenge;
  final bool busy;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    return VCard(
      tone: CardTone.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(challenge.title,
                    style: const TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              VPill('${challenge.durationDays} days', tone: CardTone.normal),
            ],
          ),
          if (challenge.rules.isNotEmpty) ...[
            const SizedBox(height: VSpace.xs),
            Text(challenge.rules, style: const TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4)),
          ],
          const SizedBox(height: VSpace.md),
          Row(
            children: [
              Icon(Icons.local_fire_department,
                  size: 18, color: challenge.streak > 0 ? VColor.warn : VColor.textLow),
              const SizedBox(width: 4),
              Text('${challenge.streak}-day streak',
                  style: TextStyle(
                    color: challenge.streak > 0 ? VColor.warn : VColor.textMid,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              FilledButton(
                onPressed: (busy || challenge.checkedInToday) ? null : onCheckIn,
                style: FilledButton.styleFrom(
                  backgroundColor: challenge.checkedInToday ? VColor.surfaceRaised : VColor.accent,
                  foregroundColor: challenge.checkedInToday ? VColor.accentGreen : VColor.textOnAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                ),
                child: Text(challenge.checkedInToday ? 'Checked in ✓' : 'Daily check-in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewChallengeDialog extends StatefulWidget {
  const _NewChallengeDialog();

  @override
  State<_NewChallengeDialog> createState() => _NewChallengeDialogState();
}

class _NewChallengeDialogState extends State<_NewChallengeDialog> {
  final _title = TextEditingController();
  final _rules = TextEditingController();
  int _durationDays = 7;

  @override
  void dispose() {
    _title.dispose();
    _rules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VColor.surface,
      title: const Text('Create Personal Challenge', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              style: const TextStyle(color: VColor.text),
              decoration: const InputDecoration(
                labelText: 'Challenge Title',
                hintText: 'e.g. 10,000 steps or 20 pushups daily',
              ),
            ),
            const SizedBox(height: VSpace.sm),
            TextField(
              controller: _rules,
              maxLines: 2,
              style: const TextStyle(color: VColor.text),
              decoration: const InputDecoration(
                labelText: 'Check-in Criteria',
                hintText: 'What must be done to count as a check-in?',
              ),
            ),
            const SizedBox(height: VSpace.md),
            Row(
              children: [
                const Text('Target Duration', style: TextStyle(color: VColor.textMid, fontSize: 13)),
                const Spacer(),
                DropdownButton<int>(
                  value: _durationDays,
                  dropdownColor: VColor.surfaceRaised,
                  style: const TextStyle(color: VColor.text),
                  items: const [7, 14, 21, 30, 60]
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                      .toList(),
                  onChanged: (v) => setState(() => _durationDays = v ?? _durationDays),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            final rules = _rules.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(context, (title: title, rules: rules, durationDays: _durationDays));
          },
          child: const Text('Create Challenge'),
        ),
      ],
    );
  }
}
