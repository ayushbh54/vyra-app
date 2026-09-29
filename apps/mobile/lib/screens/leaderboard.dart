import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/client.dart';
import '../theme.dart';
import '../models/models.dart';

/// LEADERBOARD — global and friends tier rankings.
///
/// Shows Bronze → Silver → Gold → Platinum → Diamond tiers based on
/// activity points earned. Real data from /v1/leaderboard.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _scopes = ['world', 'friends'];
  bool _loading = true;
  String? _error;

  // Loaded data per scope
  final Map<String, _BoardData> _data = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() { _load(_scopes[_tabs.index]); });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load('world');
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load(String scope) async {
    if (_data.containsKey(scope)) return; // already cached
    setState(() { _loading = true; _error = null; });
    try {
      final lb = await context.read<VyraApi>().leaderboard(scope: scope);
      if (!mounted) return;
      setState(() => _data[scope] = _BoardData.fromLeaderboard(lb));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shareToInstagramStory(String scope) {
    final data = _data[scope];
    final rankText = data?.self?.rank != null ? '#${data!.self!.rank}' : 'Top Athlete';
    final tier = data?.self?.tier.toUpperCase() ?? 'WARRIOR';
    final pts = data?.self?.activityPoints ?? 1250;
    final scopeLabel = scope == 'friends' ? 'Friends Leaderboard' : 'Global Leaderboard';
    final shareMsg = '''🔥 VYRA ATHLETE RANKING 🔥
🏆 Rank: $rankText
⚡ Tier: $tier
📊 Activity Score: $pts pts
🌐 Scope: $scopeLabel

Think you can beat my score? Challenge me on VYRA — the AI-Powered Biometric Fitness Network!
#VYRA #Fitness #Athlete''';
    // ignore: deprecated_member_use
    Share.share(shareMsg, subject: 'My VYRA Athlete Ranking');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        leading: const BackButton(color: VColor.text),
        title: const Text('Leaderboard',
            style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: VColor.accent),
            tooltip: 'Share to Instagram Story',
            onPressed: () => _shareToInstagramStory(_scopes[_tabs.index]),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: VColor.accent,
          labelColor: VColor.accent,
          unselectedLabelColor: VColor.textLow,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'GLOBAL'), Tab(text: 'FRIENDS')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _scopes.map((scope) => _BoardTab(
          scope: scope,
          loading: _loading && !_data.containsKey(scope),
          error: _error,
          data: _data[scope],
          onRetry: () => _load(scope),
        )).toList(),
      ),
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────────

class _BoardData {
  final List<_Row> rows;
  final _SelfRow? self;
  _BoardData({required this.rows, this.self});

  factory _BoardData.fromLeaderboard(Leaderboard lb) => _BoardData(
    rows: lb.rows.map((r) => _Row(
      rank: r.rank,
      handle: r.label,
      activityPoints: r.activityPoints,
      tier: r.tier,
      isSelf: r.isSelf,
    )).toList(),
    self: _SelfRow(
      rank: lb.selfRank,
      activityPoints: lb.selfPoints,
      tier: lb.selfTier,
      pointsToNextTier: lb.pointsToNextTier,
    ),
  );

}

class _Row {
  final int rank;
  final String handle;
  final int activityPoints;
  final String tier;
  final bool isSelf;

  const _Row({
    required this.rank,
    required this.handle,
    required this.activityPoints,
    required this.tier,
    required this.isSelf,
  });

}

class _SelfRow {
  final int? rank;
  final int activityPoints;
  final String tier;
  final int pointsToNextTier;

  const _SelfRow({
    required this.rank,
    required this.activityPoints,
    required this.tier,
    required this.pointsToNextTier,
  });
}

// ── Board tab ──────────────────────────────────────────────────────────────────

class _BoardTab extends StatelessWidget {
  const _BoardTab({required this.scope, required this.loading, this.error, this.data, required this.onRetry});
  final String scope;
  final bool loading;
  final String? error;
  final _BoardData? data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: VColor.accent));
    if (error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(error!, style: const TextStyle(color: VColor.textMid, fontSize: 14), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: VColor.accent))),
    ]));
    }

    final d = data;
    if (d == null || d.rows.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.emoji_events_rounded, color: VColor.textLow, size: 52),
      const SizedBox(height: 12),
      Text(scope == 'friends' ? 'Follow athletes to see them here.' : 'No data yet.',
          style: const TextStyle(color: VColor.textMid, fontSize: 14)),
    ]));
    }

    return CustomScrollView(slivers: [
      // ── Self card ────────────────────────────────────────────────────────
      if (d.self != null)
        SliverToBoxAdapter(child: _SelfCard(d.self!, scope: scope)),

      // ── Top 3 podium ─────────────────────────────────────────────────────
      if (d.rows.length >= 3)
        SliverToBoxAdapter(child: _Podium(d.rows.take(3).toList())),

      // ── Full list ────────────────────────────────────────────────────────
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final row = d.rows[i];
            return _RowCard(row);
          },
          childCount: d.rows.length,
        )),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }
}

// ── Self card ──────────────────────────────────────────────────────────────────

class _SelfCard extends StatelessWidget {
  const _SelfCard(this.self, {required this.scope});
  final _SelfRow self;
  final String scope;

  @override
  Widget build(BuildContext context) {
    final tierColor = VColor.tier(self.tier);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor.withValues(alpha: 0.15), VColor.surface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tierColor.withValues(alpha: 0.4)),
      ),
      child: Column(children: [
        Row(children: [
          Text(_tierIcon(self.tier), style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your Rank${self.rank != null ? " · #${self.rank}" : ""}',
                style: const TextStyle(color: VColor.textMid, fontSize: 12)),
            Text(self.tier.toUpperCase(),
                style: TextStyle(color: tierColor, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${self.activityPoints}', style: const TextStyle(color: VColor.accent, fontSize: 20, fontWeight: FontWeight.w800)),
            const Text('pts', style: TextStyle(color: VColor.textLow, fontSize: 11)),
          ]),
        ]),
        if (self.pointsToNextTier > 0) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Text('Next tier', style: TextStyle(color: VColor.textLow, fontSize: 12))),
            Text('${self.pointsToNextTier} pts to go',
                style: const TextStyle(color: VColor.textMid, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progressToNext(self),
              minHeight: 6,
              backgroundColor: VColor.surfaceHighest,
              valueColor: AlwaysStoppedAnimation(tierColor),
            ),
          ),
        ],
        const SizedBox(height: 14),
        InkWell(
          onTap: () {
            final rankText = self.rank != null ? '#${self.rank}' : 'Ranked Athlete';
            final tier = self.tier.toUpperCase();
            final scopeLabel = scope == 'friends' ? 'Friends Leaderboard' : 'Global Leaderboard';
            final shareMsg = '''🔥 VYRA ATHLETE RANKING 🔥
🏆 Rank: $rankText
⚡ Tier: $tier
📊 Activity Score: ${self.activityPoints} pts
🌐 Scope: $scopeLabel

Think you can beat my score? Challenge me on VYRA — the AI-Powered Biometric Fitness Network!
#VYRA #Fitness #Athlete''';
            // ignore: deprecated_member_use
    Share.share(shareMsg, subject: 'My VYRA Athlete Ranking');
          },
          borderRadius: BorderRadius.circular(VRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VRadius.md),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Share Rank to Instagram Story',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  double _progressToNext(_SelfRow s) {
    // Rough approximation: show % toward earning `pointsToNextTier`
    if (s.pointsToNextTier <= 0) return 1.0;
    return (s.activityPoints % 500) / 500;
  }
}

// ── Podium ─────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium(this.top3);
  final List<_Row> top3;

  @override
  Widget build(BuildContext context) {
    // Arrange 2nd, 1st, 3rd
    final order = [top3[1], top3[0], top3[2]];
    final heights = [90.0, 120.0, 70.0];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(child: _PodiumSlot(order[i], heights[i], [2, 1, 3][i])),
          if (i < 2) const SizedBox(width: 8),
        ],
      ]),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot(this.row, this.podiumH, this.position);
  final _Row row;
  final double podiumH;
  final int position;

  @override
  Widget build(BuildContext context) {
    final isFirst = position == 1;
    final tierColor = VColor.tier(row.tier);
    return Column(children: [
      if (isFirst)
        const Text('👑', style: TextStyle(fontSize: 22)),
      Text(_tierIcon(row.tier), style: TextStyle(fontSize: isFirst ? 30 : 22)),
      const SizedBox(height: 4),
      Text(row.handle.length > 10 ? '${row.handle.substring(0, 9)}…' : row.handle,
          style: TextStyle(
            color: row.isSelf ? VColor.accent : VColor.text,
            fontSize: isFirst ? 13 : 11,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center),
      Text('${row.activityPoints} pts',
          style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Container(
        height: podiumH,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [tierColor.withValues(alpha: 0.5), tierColor.withValues(alpha: 0.2)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 10),
        child: Text('#$position',
            style: TextStyle(color: tierColor, fontSize: 20, fontWeight: FontWeight.w800)),
      ),
    ]);
  }
}

// ── Row card ───────────────────────────────────────────────────────────────────

class _RowCard extends StatelessWidget {
  const _RowCard(this.row);
  final _Row row;

  @override
  Widget build(BuildContext context) {
    final tierColor = VColor.tier(row.tier);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: row.isSelf ? VColor.accentGlow : VColor.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: row.isSelf ? VColor.accent.withValues(alpha: 0.5) : VColor.line,
        ),
      ),
      child: Row(children: [
        SizedBox(width: 32, child: Text('#${row.rank}',
            style: TextStyle(
              color: row.rank <= 3 ? tierColor : VColor.textLow,
              fontSize: 13, fontWeight: FontWeight.w700,
            ))),
        Text(_tierIcon(row.tier), style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Text(row.handle,
            style: TextStyle(
              color: row.isSelf ? VColor.accent : VColor.text,
              fontSize: 14, fontWeight: FontWeight.w600,
            ))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${row.activityPoints}',
              style: TextStyle(color: tierColor, fontSize: 15, fontWeight: FontWeight.w700)),
          Text(row.tier,
              style: TextStyle(color: tierColor.withValues(alpha: 0.7), fontSize: 10)),
        ]),
      ]),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _tierIcon(String tier) => switch (tier.toLowerCase()) {
  'diamond'  => '💎',
  'platinum' => '🔷',
  'gold'     => '🥇',
  'silver'   => '🥈',
  _          => '🥉',
};
