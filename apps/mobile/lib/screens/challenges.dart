import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';
import 'challenge_detail.dart';

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
  final Set<String> _joinedCommunityChallenges = {'comm_steps_50k', 'comm_nosugar_7d'};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  Future<void> _checkIn(CustomChallenge challenge) async {
    setState(() => _checkingIn = true);
    try {
      final streak = await context.read<VyraApi>().checkinChallenge(challenge.id);
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
            content: Text('🔥 Check-in complete! $streak-day streak!'),
            backgroundColor: VColor.accentGreen,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  void _toggleCommunityChallenge(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_joinedCommunityChallenges.contains(id)) {
        _joinedCommunityChallenges.remove(id);
      } else {
        _joinedCommunityChallenges.add(id);
      }
    });
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
        isJoined: _joinedCommunityChallenges.contains(item.id),
        onToggleJoin: () => _toggleCommunityChallenge(item.id),
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
                      Tab(text: 'Coins & Wallet'),
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
                  _buildCoinsAndWalletTab(),
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
              colors: [VColor.accent.withOpacity(0.18), VColor.surfaceRaised],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(color: VColor.accent.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: VColor.accent.withOpacity(0.2),
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
                  onCheckIn: () => _checkIn(c),
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
        participants: 1240,
        rewardCoins: 50,
        currentProgress: 0.68,
        progressLabel: '34,200 / 50,000 steps',
      ),
      _CommunityChallengeData(
        id: 'comm_nosugar_7d',
        title: '7-Day Zero Added Sugar Sprint',
        description: 'Skip all sweetened beverages, sodas & mithai for a clean digestive reset.',
        badge: 'Nutrition',
        participants: 890,
        rewardCoins: 40,
        currentProgress: 0.42,
        progressLabel: '3 / 7 days logged',
      ),
      _CommunityChallengeData(
        id: 'comm_squats_100',
        title: 'Desi Strength: 100 Daily Squats',
        description: 'Complete 100 bodyweight squats daily using the 3D Form Coach.',
        badge: 'Strength',
        participants: 615,
        rewardCoins: 60,
        currentProgress: 0.25,
        progressLabel: 'Day 2 of 7',
      ),
      _CommunityChallengeData(
        id: 'comm_morning_run',
        title: 'Early Bird 5K Morning Run',
        description: 'Record an outdoor 5K run between 5:00 AM and 8:00 AM on the map.',
        badge: 'Cardio',
        participants: 430,
        rewardCoins: 35,
        currentProgress: 0.0,
        progressLabel: 'Not started yet',
      ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.sm, VSpace.base, VSpace.xxxl),
      children: [
        VCard(
          tone: CardTone.accent,
          child: Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: VColor.accent, size: 28),
              const SizedBox(width: VSpace.md),
              const Expanded(
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
                onToggleJoin: () => _toggleCommunityChallenge(item.id),
              ),
            ),
          ),
      ],
    );
  }

  // ── TAB 3: COINS & WALLET ──────────────────────────────────────────────────
  Widget _buildCoinsAndWalletTab() {
    if (_wallet == null) {
      return const Center(child: VLoading());
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.sm, VSpace.base, VSpace.xxxl),
      children: [
        _balanceCard(context, _wallet!),
        const SizedBox(height: VSpace.base),
        _capCard(context, _wallet!),
        const SizedBox(height: VSpace.base),

        const VSectionHeader('How coins are earned'),
        const _EarningRules(),
        const SizedBox(height: VSpace.base),

        const VSectionHeader('Recent coin history'),
        if (_wallet!.recent.isEmpty)
          const VEmptyState(
            title: 'No transactions yet',
            body: 'Complete a workout, log metrics or hit a streak milestone to earn your first coins.',
          )
        else
          ..._wallet!.recent.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: VSpace.sm),
                child: _LedgerTile(entry: e),
              )),

        const SizedBox(height: VSpace.base),
        const VCard(
          tone: CardTone.raised,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VLabel('COINS CANNOT BE PURCHASED'),
              SizedBox(height: VSpace.sm),
              Text(
                'There is no pay-to-win shop or in-app payment for coins. '
                'Every coin in your balance is directly backed by verified physical effort '
                'and healthy habits.',
                style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _balanceCard(BuildContext context, WalletData wallet) {
    final b = wallet.balance;
    return VCard(
      tone: CardTone.accent,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VLabel('TOTAL BALANCE'),
                const SizedBox(height: VSpace.xs),
                Text(
                  '${b.balance}',
                  style: const TextStyle(
                      color: VColor.text, fontSize: 40, fontWeight: FontWeight.w700, height: 1),
                ),
                const SizedBox(height: VSpace.xs),
                Text(
                  b.isMaxLevel
                      ? 'Level ${b.level} — highest tier'
                      : 'Level ${b.level} · ${b.coinsToNextLevel} coins to Level ${b.level + 1}',
                  style: const TextStyle(color: VColor.textMid, fontSize: 13),
                ),
              ],
            ),
          ),
          VRing(
            progress: b.levelProgress,
            size: 76,
            child: Text(
              '${b.level}',
              style: const TextStyle(
                  color: VColor.accent, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _capCard(BuildContext context, WalletData wallet) {
    final reached = wallet.todayEarned >= wallet.dailyCap;
    return VCard(
      tone: reached ? CardTone.warn : CardTone.normal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const VLabel('EARNED TODAY'),
              const Spacer(),
              Text(
                '${wallet.todayEarned} / ${wallet.dailyCap} coins',
                style: TextStyle(
                  color: reached ? VColor.warn : VColor.textMid,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(VRadius.pill),
            child: LinearProgressIndicator(
              value: (wallet.todayEarned / wallet.dailyCap).clamp(0, 1),
              minHeight: 6,
              backgroundColor: VColor.steel,
              valueColor: AlwaysStoppedAnimation(reached ? VColor.warn : VColor.accent),
            ),
          ),
          const SizedBox(height: VSpace.sm),
          Text(
            reached
                ? 'You have reached today\'s coin cap. Your activity still tracks towards streaks and leaderboards!'
                : 'Fair-play daily limit prevents grinding and protects authentic healthy routines.',
            style: const TextStyle(color: VColor.textMid, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
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
                            color: VColor.accent.withOpacity(0.12),
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
              Text('${data.participants} athletes joined',
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

class _EarningRules extends StatelessWidget {
  const _EarningRules();

  static const _rules = [
    ('Complete your daily goal', '+20'),
    ('Partial session — showing up', '+5'),
    ('Log all your health metrics', '+10'),
    ('A zero-added-sugar day', '+15'),
    ('Hit your nutrition targets', '+10'),
    ('Streak milestones (3/7/14/30 days)', '+25 to +300'),
  ];

  @override
  Widget build(BuildContext context) {
    return VCard(
      child: Column(
        children: [
          for (final (label, amount) in _rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(color: VColor.textMid, fontSize: 13.5)),
                  ),
                  Text(
                    amount,
                    style: const TextStyle(
                        color: VColor.accent, fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final positive = entry.delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.md),
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
                Text(entry.reason,
                    style: const TextStyle(color: VColor.text, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  entry.createdAt.length >= 10 ? entry.createdAt.substring(0, 10) : entry.createdAt,
                  style: const TextStyle(color: VColor.textLow, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            positive ? '+${entry.delta}' : '${entry.delta}',
            style: TextStyle(
              color: positive ? VColor.accent : VColor.textLow,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
