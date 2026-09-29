import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'athlete_chat.dart';

/// Search for athletes and follow them — the graph the Home feed and the
/// Friends leaderboard both read from.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SearchUser>? _results;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await context.read<VyraApi>().searchUsers(query);
      if (mounted) setState(() { _results = results; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(SearchUser user) async {
    final api = context.read<VyraApi>();
    try {
      if (user.following) {
        await api.unfollow(user.id);
      } else {
        await api.follow(user.id);
      }
      if (!mounted) return;
      await _search(_controller.text);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _showUserProfileSheet(SearchUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VColor.surfaceRaised,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
        side: BorderSide(color: VColor.line),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VColor.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: VSpace.base),
              CircleAvatar(
                radius: 36,
                backgroundColor: VColor.accentGlow,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: VColor.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: VSpace.sm),
              Text(
                user.name,
                style: const TextStyle(
                  color: VColor.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '@${user.handle}',
                style: const TextStyle(
                  color: VColor.textMid,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: VSpace.base),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: VColor.surface,
                  borderRadius: BorderRadius.circular(VRadius.md),
                  border: Border.all(color: VColor.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Status', user.following ? 'Following' : 'Athlete'),
                    Container(width: 1, height: 28, color: VColor.line),
                    _buildStatCol('Network', 'VYRA Global'),
                    Container(width: 1, height: 28, color: VColor.line),
                    _buildStatCol('Chat', 'Active'),
                  ],
                ),
              ),
              const SizedBox(height: VSpace.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Send Direct Message', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: VColor.accent,
                    foregroundColor: VColor.textOnAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
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
              ),
              const SizedBox(height: VSpace.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: VColor.line),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _toggleFollow(user);
                  },
                  child: Text(user.following ? 'Unfollow Athlete' : 'Follow Athlete'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: VColor.accent, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: VColor.textLow, fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(VSpace.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Find athletes', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: VSpace.base),
            TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: const TextStyle(color: VColor.text),
              decoration: const InputDecoration(
                hintText: 'Search for people on VYRA',
                prefixIcon: Icon(Icons.search, color: VColor.textLow),
              ),
            ),
            const SizedBox(height: VSpace.base),
            if (_error != null) VErrorView(message: _error!, onRetry: () => _search(_controller.text)),
            if (_loading) const VLoading(label: 'Searching'),
            if (!_loading && _results != null && _results!.isEmpty)
              const VEmptyState(
                title: 'No one found',
                body: 'Try a different name or handle.',
              ),
            Expanded(
              child: ListView.separated(
                itemCount: _results?.length ?? 0,
                separatorBuilder: (_, __) => const SizedBox(height: VSpace.sm),
                itemBuilder: (context, i) {
                  final user = _results![i];
                  return VCard(
                    tone: CardTone.raised,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(VRadius.md),
                      onTap: () => _showUserProfileSheet(user),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: VColor.accentGlow,
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: VSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('@${user.handle}',
                                      style: const TextStyle(color: VColor.textLow, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Direct Message',
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: VColor.accent, size: 20),
                              onPressed: () {
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
                            OutlinedButton(
                              onPressed: () => _toggleFollow(user),
                              child: Text(user.following ? 'Following' : 'Follow'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
