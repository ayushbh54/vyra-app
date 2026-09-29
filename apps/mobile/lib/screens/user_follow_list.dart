import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'athlete_chat.dart';
import 'friends.dart';

/// Stitch Pages 38g & 38h: Followers & Following Lists
class UserFollowListScreen extends StatefulWidget {
  const UserFollowListScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<UserFollowListScreen> createState() => _UserFollowListScreenState();
}

class _UserFollowListScreenState extends State<UserFollowListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<FollowUser> _followers = [];
  List<FollowUser> _following = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final api = context.read<VyraApi>();
    try {
      final results = await Future.wait([
        api.getFollowers(),
        api.getFollowing(),
      ]);
      if (mounted) {
        setState(() {
          _followers = results[0];
          _following = results[1];
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unfollowUser(FollowUser user) async {
    final api = context.read<VyraApi>();
    try {
      await api.unfollow(user.id);
      if (mounted) {
        setState(() {
          _following.removeWhere((u) => u.id == user.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unfollowed @${user.handle}')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  List<FollowUser> _filterList(List<FollowUser> list) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((u) => u.name.toLowerCase().contains(q) || u.handle.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surfaceRaised,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: VColor.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Athlete Network',
              style: TextStyle(color: VColor.text, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: VColor.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                const Text(
                  'SOCIAL TELEMETRY CONNECTIONS',
                  style: TextStyle(
                    color: VColor.accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: VColor.accent,
          labelColor: VColor.accent,
          unselectedLabelColor: VColor.textMid,
          tabs: [
            Tab(text: 'Followers (${_followers.length})'),
            Tab(text: 'Following (${_following.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Search in List ──
          Padding(
            padding: const EdgeInsets.all(VSpace.base),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: VColor.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Filter connections by name or handle...',
                hintStyle: const TextStyle(color: VColor.textLow, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: VColor.textLow, size: 20),
                fillColor: VColor.surfaceRaised,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VRadius.lg),
                  borderSide: const BorderSide(color: VColor.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VRadius.lg),
                  borderSide: const BorderSide(color: VColor.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VRadius.lg),
                  borderSide: const BorderSide(color: VColor.accent),
                ),
              ),
            ),
          ),

          // ── Tab Views ──
          Expanded(
            child: _loading
                ? const Center(child: VLoading(label: 'Syncing athlete connections...'))
                : _error != null
                    ? Center(child: VErrorView(message: _error!, onRetry: _loadData))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAthleteList(_filterList(_followers), isFollowersTab: true),
                          _buildAthleteList(_filterList(_following), isFollowersTab: false),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteList(List<FollowUser> list, {required bool isFollowersTab}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: VColor.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFollowersTab ? Icons.people_outline_rounded : Icons.person_add_alt_1_outlined,
                  color: VColor.accent,
                  size: 28,
                ),
              ),
              const SizedBox(height: VSpace.md),
              Text(
                isFollowersTab ? 'No followers found' : 'Not following any athletes yet',
                style: const TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isFollowersTab
                    ? 'Share your fitness profile and activities to grow your athlete circle.'
                    : 'Discover fellow runners, lifters, and cyclists across India.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: VSpace.lg),
              VGradientButton(
                label: 'Find Athletes',
                icon: Icons.person_search_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const Scaffold(backgroundColor: VColor.bg, body: FriendsScreen())),
                  ).then((_) { if (mounted) _loadData(); });
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.sm),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: VSpace.sm),
      itemBuilder: (context, index) {
        final user = list[index];
        return Container(
          padding: const EdgeInsets.all(VSpace.md),
          decoration: BoxDecoration(
            color: VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(color: VColor.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: VColor.bgLift,
                  shape: BoxShape.circle,
                  border: Border.all(color: VColor.accent.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A',
                    style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: VSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: VColor.accent, size: 14),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.handle}',
                      style: const TextStyle(color: VColor.textLow, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // ── Direct 1-on-1 Chat Action Button (Stitch Page 38b integration) ──
              IconButton(
                tooltip: 'Direct Message',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: VColor.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: VColor.accent, size: 18),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AthleteChatScreen(
                        athleteId: user.id,
                        athleteName: user.name,
                        athleteHandle: user.handle,
                      ),
                    ),
                  );
                },
              ),

              if (!isFollowersTab) ...[
                const SizedBox(width: 4),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: VColor.line),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                  ),
                  onPressed: () => _unfollowUser(user),
                  child: const Text('Following', style: TextStyle(color: VColor.textMid, fontSize: 11.5)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
