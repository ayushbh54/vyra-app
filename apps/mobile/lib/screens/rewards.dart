import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// REWARDS — the Perks Catalog. Lives in the Challenges tab (Coins earned →
/// Coins spent, kept together), separate from Posts, which lives in Social.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  WalletData? _wallet;
  List<RewardItem>? _rewards;
  List<RewardRedemption>? _redemptions;
  String? _error;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        context.read<VyraApi>().wallet(),
        context.read<VyraApi>().rewards(),
        context.read<VyraApi>().myRedemptions(),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as WalletData;
          _rewards = results[1] as List<RewardItem>;
          _redemptions = results[2] as List<RewardRedemption>;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _redeem(RewardItem reward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surface,
        title: Text('Redeem "${reward.title}"?', style: const TextStyle(color: VColor.text)),
        content: Text(
          'This uses ${reward.coinCost} coins from your balance.',
          style: const TextStyle(color: VColor.textMid, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Redeem', style: TextStyle(color: VColor.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _redeeming = true);
    try {
      await context.read<VyraApi>().redeemReward(reward.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Redeemed "${reward.title}".')),
        );
      }
      if (mounted) await _load();
    } on ApiException catch (e) {
      // Covers the "not enough coins" case and any other redeem failure —
      // e.message is already a clear, user-facing string from the server.
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, 0),
              child: _error != null && _wallet == null
                  ? VErrorView(message: _error!, onRetry: _load)
                  : _balanceHeader(context),
            ),
            const TabBar(
              labelColor: VColor.accent,
              unselectedLabelColor: VColor.textMid,
              indicatorColor: VColor.accent,
              tabs: [
                Tab(text: 'Catalog'),
                Tab(text: 'My Redemptions'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _catalogTab(context),
                  _redemptionsTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceHeader(BuildContext context) {
    if (_wallet == null) return const SizedBox(height: VSpace.xxl, child: VLoading(label: 'Loading balance'));
    return VCard(
      tone: CardTone.accent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          VStat(label: 'Coin balance', value: '${_wallet!.balance.balance}'),
          VStat(label: 'Level', value: '${_wallet!.balance.level}'),
        ],
      ),
    );
  }

  Widget _catalogTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: VColor.accent,
      backgroundColor: VColor.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
        children: [
          if (_error != null && _rewards == null) VErrorView(message: _error!, onRetry: _load),
          if (_error == null && _rewards == null) const VLoading(label: 'Loading perks'),
          if (_rewards != null && _rewards!.isEmpty)
            const VEmptyState(title: 'Nothing in the catalog yet', body: 'Check back soon for perks.'),
          for (final r in _rewards ?? []) ...[
            _RewardCard(
              reward: r,
              canAfford: (_wallet?.balance.balance ?? 0) >= r.coinCost,
              busy: _redeeming,
              onRedeem: () => _redeem(r),
            ),
            const SizedBox(height: VSpace.base),
          ],
        ],
      ),
    );
  }

  Widget _redemptionsTab(BuildContext context) {
    final rewardsByid = {for (final r in _rewards ?? <RewardItem>[]) r.id: r};
    return RefreshIndicator(
      onRefresh: _load,
      color: VColor.accent,
      backgroundColor: VColor.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
        children: [
          if (_error != null && _redemptions == null) VErrorView(message: _error!, onRetry: _load),
          if (_error == null && _redemptions == null) const VLoading(),
          if (_redemptions != null && _redemptions!.isEmpty)
            const VEmptyState(title: 'No redemptions yet', body: 'Perks you redeem will show up here.'),
          for (final r in _redemptions ?? []) ...[
            VCard(
              tone: CardTone.raised,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rewardsByid[r.rewardId]?.title ?? 'Reward',
                          style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.redeemedAt.length >= 10 ? r.redeemedAt.substring(0, 10) : r.redeemedAt,
                          style: const TextStyle(color: VColor.textLow, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  VPill('${r.coinCost} coins', tone: CardTone.accent),
                ],
              ),
            ),
            const SizedBox(height: VSpace.sm),
          ],
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.canAfford,
    required this.busy,
    required this.onRedeem,
  });

  final RewardItem reward;
  final bool canAfford;
  final bool busy;
  final VoidCallback onRedeem;

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
                child: Text(reward.title,
                    style: const TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              VPill('${reward.coinCost} coins', tone: CardTone.accent),
            ],
          ),
          if (reward.description.isNotEmpty) ...[
            const SizedBox(height: VSpace.xs),
            Text(reward.description, style: const TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4)),
          ],
          const SizedBox(height: VSpace.md),
          Row(
            children: [
              if (!reward.inStock)
                const VPill('Out of stock', tone: CardTone.warn)
              else
                VPill(reward.category, tone: CardTone.normal),
              const Spacer(),
              FilledButton(
                onPressed: (busy || !canAfford || !reward.inStock) ? null : onRedeem,
                child: Text(!reward.inStock ? 'Unavailable' : (canAfford ? 'Redeem' : 'Not enough coins')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
