import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';

/// CLUBS — interest-based groups with a simple member feed, the second
/// pillar of Strava's Groups pattern alongside Challenges.
class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  List<ClubItem>? _clubs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final clubs = await context.read<VyraApi>().clubs();
      if (mounted) setState(() { _clubs = clubs; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleJoin(ClubItem club) async {
    final api = context.read<VyraApi>();
    try {
      if (club.joined) {
        await api.leaveClub(club.id);
      } else {
        await api.joinClub(club.id);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return VErrorView(message: _error!, onRetry: _load);
    if (_clubs == null) return const VLoading(label: 'Loading clubs');
    if (_clubs!.isEmpty) {
      return const VEmptyState(title: 'No clubs yet', body: 'Check back soon.');
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: VColor.accent,
      backgroundColor: VColor.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(VSpace.base),
        itemCount: _clubs!.length,
        separatorBuilder: (_, __) => const SizedBox(height: VSpace.sm),
        itemBuilder: (context, i) {
          final club = _clubs![i];
          return VCard(
            tone: CardTone.raised,
            child: InkWell(
              onTap: () => pushScreen(context, club.name, _ClubDetail(club: club)),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: VColor.accentGlow,
                      borderRadius: BorderRadius.circular(VRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.groups, color: VColor.accent),
                  ),
                  const SizedBox(width: VSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(club.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${club.memberCount} members · ${club.interestTag}',
                            style: const TextStyle(color: VColor.textLow, fontSize: 12)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _toggleJoin(club),
                    child: Text(club.joined ? 'Joined' : 'Join'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClubDetail extends StatefulWidget {
  const _ClubDetail({required this.club});
  final ClubItem club;

  @override
  State<_ClubDetail> createState() => _ClubDetailState();
}

class _ClubDetailState extends State<_ClubDetail> {
  List<ClubPost>? _posts;
  String? _error;
  final _controller = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final posts = await context.read<VyraApi>().clubPosts(widget.club.id);
      if (mounted) setState(() { _posts = posts; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await context.read<VyraApi>().addClubPost(widget.club.id, text);
      _controller.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VSpace.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.club.description, style: const TextStyle(color: VColor.textMid)),
          const SizedBox(height: VSpace.base),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: VColor.text),
                  decoration: const InputDecoration(hintText: 'Post to the club'),
                ),
              ),
              IconButton(
                icon: _posting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accent))
                    : const Icon(Icons.send, color: VColor.accent),
                onPressed: _posting ? null : _post,
              ),
            ],
          ),
          const SizedBox(height: VSpace.base),
          if (_error != null) VErrorView(message: _error!, onRetry: _load),
          if (_posts != null && _posts!.isEmpty)
            const VEmptyState(title: 'No posts yet', body: 'Be the first to post in this club.'),
          Expanded(
            child: ListView.separated(
              itemCount: _posts?.length ?? 0,
              separatorBuilder: (_, __) => const SizedBox(height: VSpace.sm),
              itemBuilder: (context, i) {
                final post = _posts![i];
                return VCard(
                  tone: CardTone.raised,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@${post.authorHandle}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(post.body, style: const TextStyle(color: VColor.text)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
