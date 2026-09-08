import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// TAB 4 — CHALLENGES & COINS
///
/// The ethical core of the product, made visible.
///
/// There is no shop on this screen because there is no shop in the system: the
/// database constraint on the coin ledger has no `purchase` value, so no code
/// path can create one. This screen states that plainly rather than leaving the
/// user to wonder when the paywall arrives.
///
/// The daily cap is shown honestly too. Once it is reached the app says so,
/// instead of quietly awarding nothing while still playing a reward animation.
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  WalletData? _wallet;
  List<CustomChallenge>? _challenges;
  String? _error;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (result == null) return;
    try {
      await context.read<VyraApi>().createCustomChallenge(
            title: result.title,
            rules: result.rules,
            durationDays: result.durationDays,
          );
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _checkIn(CustomChallenge challenge) async {
    setState(() => _checkingIn = true);
    try {
      final streak = await context.read<VyraApi>().checkinChallenge(challenge.id);
      if (mounted) {
        setState(() {
          _challenges = [
            for (final c in _challenges ?? [])
              if (c.id == challenge.id) c.copyWith(streak: streak, checkedInToday: true) else c,
          ];
        });
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: VColor.accent,
        backgroundColor: VColor.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
          children: [
            Text('Coins', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: VSpace.base),

            if (_error != null)
              VErrorView(message: _error!, onRetry: _load)
            else if (_wallet == null)
              const VLoading()
            else ...[
              _balanceCard(context, _wallet!),
              const SizedBox(height: VSpace.base),
              _capCard(context, _wallet!),
              const SizedBox(height: VSpace.base),

              VSectionHeader(
                'Your challenges',
                trailing: TextButton.icon(
                  onPressed: _createChallenge,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create your own'),
                ),
              ),
              if (_challenges != null && _challenges!.isEmpty)
                const VEmptyState(
                  title: 'No custom challenges yet',
                  body: 'Set your own rules and duration, then check in daily to build a streak.',
                ),
              for (final c in _challenges ?? [])
                Padding(
                  padding: const EdgeInsets.only(bottom: VSpace.sm),
                  child: _ChallengeCard(
                    challenge: c,
                    busy: _checkingIn,
                    onCheckIn: () => _checkIn(c),
                  ),
                ),
              const SizedBox(height: VSpace.base),

              const VSectionHeader('How coins are earned'),
              const _EarningRules(),
              const SizedBox(height: VSpace.base),
              const VSectionHeader('Recent'),
              if (_wallet!.recent.isEmpty)
                const VEmptyState(
                  title: 'Nothing yet',
                  body: 'Finish a session, log your metrics, or complete a zero-sugar day and '
                      'your first coins will appear here.',
                )
              else
                ..._wallet!.recent.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: VSpace.sm),
                      child: _LedgerTile(entry: e),
                    )),
            ],

            const SizedBox(height: VSpace.base),
            const VCard(
              tone: CardTone.raised,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VLabel('Coins cannot be bought'),
                  SizedBox(height: VSpace.sm),
                  Text(
                    'There is no shop, no advertising, and no way to convert money into coins. '
                    'This is enforced in the database itself — the ledger has no "purchase" '
                    'category, so no future version of this app can quietly add one without a '
                    'change anyone reviewing the code would see.',
                    style: TextStyle(color: VColor.textMid, fontSize: 13.5, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                const VLabel('Balance'),
                const SizedBox(height: VSpace.xs),
                Text(
                  '${b.balance}',
                  style: const TextStyle(
                      color: VColor.text, fontSize: 40, fontWeight: FontWeight.w700, height: 1),
                ),
                const SizedBox(height: VSpace.xs),
                Text(
                  b.isMaxLevel
                      ? 'Level ${b.level} — highest level'
                      : 'Level ${b.level} · ${b.coinsToNextLevel} to level ${b.level + 1}',
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

  /// Shown whether or not the cap is reached, so it never feels like a
  /// surprise punishment when it arrives.
  Widget _capCard(BuildContext context, WalletData wallet) {
    final reached = wallet.todayEarned >= wallet.dailyCap;
    return VCard(
      tone: reached ? CardTone.warn : CardTone.normal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const VLabel('Earned today'),
              const Spacer(),
              Text(
                '${wallet.todayEarned} / ${wallet.dailyCap}',
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
                ? 'You have reached today\'s limit. Your progress still counts towards streaks '
                  'and the leaderboard — coins reset tomorrow.'
                : 'There is a daily limit on coins. It exists so nobody has to grind, and so '
                  'cheating is not worth anyone\'s time.',
            style: const TextStyle(color: VColor.textMid, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
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
              VPill('${challenge.durationDays}d', tone: CardTone.normal),
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
                  size: 16, color: challenge.streak > 0 ? VColor.warn : VColor.textLow),
              const SizedBox(width: 4),
              Text('${challenge.streak}-day streak',
                  style: const TextStyle(color: VColor.textMid, fontSize: 12.5)),
              const Spacer(),
              OutlinedButton(
                onPressed: (busy || challenge.checkedInToday) ? null : onCheckIn,
                child: Text(challenge.checkedInToday ? 'Checked in' : 'Check in today'),
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
      title: const Text('Create your own challenge', style: TextStyle(color: VColor.text)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              style: const TextStyle(color: VColor.text),
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: VSpace.sm),
            TextField(
              controller: _rules,
              maxLines: 3,
              style: const TextStyle(color: VColor.text),
              decoration: const InputDecoration(labelText: 'Rules', hintText: 'What counts as a check-in?'),
            ),
            const SizedBox(height: VSpace.sm),
            Row(
              children: [
                const Text('Duration', style: TextStyle(color: VColor.textMid, fontSize: 13)),
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
          child: const Text('Create'),
        ),
      ],
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
