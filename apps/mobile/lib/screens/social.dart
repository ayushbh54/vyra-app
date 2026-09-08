import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// TAB 3 — SOCIAL
///
/// Two boards, deliberately different in character:
///
///   Friends — real names, people you know, low stakes.
///   World   — handles only, never real names, ranked by tier.
///
/// Both rank on effort against your own available time, not raw volume. That is
/// what lets a nurse on a twelve-hour shift outrank someone with a free
/// afternoon, and it is the reason a leaderboard here is motivating rather than
/// demoralising.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  String _scope = 'world';
  Leaderboard? _board;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final board = await context.read<VyraApi>().leaderboard(scope: _scope);
      if (mounted) setState(() { _board = board; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
            Text('Leaderboard', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: VSpace.base),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'world', label: Text('World'), icon: Icon(Icons.public, size: 17)),
                ButtonSegment(value: 'friends', label: Text('Friends'), icon: Icon(Icons.group_outlined, size: 17)),
              ],
              selected: {_scope},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                setState(() { _scope = s.first; _board = null; });
                _load();
              },
              style: SegmentedButton.styleFrom(
                backgroundColor: VColor.surface,
                foregroundColor: VColor.textMid,
                selectedBackgroundColor: VColor.accentGlow,
                selectedForegroundColor: VColor.accent,
                side: const BorderSide(color: VColor.line),
              ),
            ),
            const SizedBox(height: VSpace.base),

            if (_error != null)
              VErrorView(message: _error!, onRetry: _load)
            else if (_board == null)
              const VLoading()
            else ...[
              _selfCard(context, _board!),
              const SizedBox(height: VSpace.base),
              if (_board!.rows.isEmpty)
                const VEmptyState(
                  title: 'Nobody here yet',
                  body: 'This board fills up as people finish their sessions this week. '
                      'Complete today\'s and you will appear on it.',
                )
              else
                ..._board!.rows.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: VSpace.sm),
                      child: _LeaderTile(row: r, anonymous: _scope == 'world'),
                    )),
            ],

            const SizedBox(height: VSpace.base),
            const VCard(
              tone: CardTone.raised,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VLabel('How ranking works'),
                  SizedBox(height: VSpace.sm),
                  Text(
                    'You are ranked on how much of your own available time you used, then '
                    'multiplied by how many days you showed up. Seven short sessions beat one '
                    'long one. Someone with a packed schedule can finish above someone with a '
                    'free day — that is the point.',
                    style: TextStyle(color: VColor.textMid, fontSize: 13.5, height: 1.5),
                  ),
                ],
              ),
            ),

            if (_scope == 'world') ...[
              const SizedBox(height: VSpace.md),
              const VDisclaimer(
                'The world board shows handles only. Your real name, city and health data are '
                'never visible to other people.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selfCard(BuildContext context, Leaderboard board) {
    return VCard(
      tone: CardTone.accent,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VLabel('Your position'),
                const SizedBox(height: VSpace.xs),
                Text(
                  board.selfRank == null ? 'Unranked' : '#${board.selfRank}',
                  style: const TextStyle(
                      color: VColor.text, fontSize: 34, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${board.selfPoints} points this week',
                  style: const TextStyle(color: VColor.textMid, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: 6),
                decoration: BoxDecoration(
                  color: VColor.tier(board.selfTier).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(VRadius.pill),
                ),
                child: Text(
                  board.selfTier.toUpperCase(),
                  style: TextStyle(
                    color: VColor.tier(board.selfTier),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: VSpace.sm),
              if (board.pointsToNextTier > 0)
                Text(
                  '${board.pointsToNextTier} to next tier',
                  style: const TextStyle(color: VColor.textLow, fontSize: 11.5),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderTile extends StatelessWidget {
  const _LeaderTile({required this.row, required this.anonymous});

  final LeaderRow row;
  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.md),
      decoration: BoxDecoration(
        color: row.isSelf ? VColor.accentGlow : VColor.surface,
        border: Border.all(color: row.isSelf ? VColor.accent : VColor.line),
        borderRadius: BorderRadius.circular(VRadius.md),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${row.rank}',
              style: TextStyle(
                color: row.isSelf ? VColor.accent : VColor.textLow,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(right: VSpace.md),
            decoration: BoxDecoration(color: VColor.tier(row.tier), shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              row.isSelf ? 'You' : row.label,
              style: TextStyle(
                color: row.isSelf ? VColor.accent : VColor.text,
                fontSize: 14.5,
                fontWeight: row.isSelf ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '${row.activityPoints}',
            style: TextStyle(
              color: row.isSelf ? VColor.accent : VColor.textMid,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
