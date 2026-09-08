import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
      await _search(_controller.text);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
                        OutlinedButton(
                          onPressed: () => _toggleFollow(user),
                          child: Text(user.following ? 'Following' : 'Follow'),
                        ),
                      ],
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
