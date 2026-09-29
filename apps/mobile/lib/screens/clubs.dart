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
  String _selectedCity = 'All Cities';

  static const List<String> _cities = [
    'All Cities',
    'New Delhi',
    'Mumbai',
    'Bengaluru',
    'Pune',
    'Hyderabad',
    'Kolkata',
    'Chennai',
  ];

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

  List<ClubItem> get _filteredClubs {
    if (_clubs == null) return [];
    if (_selectedCity == 'All Cities') return _clubs!;
    final query = _selectedCity.toLowerCase();
    final matches = _clubs!.where((c) {
      final text = '${c.name} ${c.description} ${c.interestTag}'.toLowerCase();
      return text.contains(query);
    }).toList();
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return VErrorView(message: _error!, onRetry: _load);
    if (_clubs == null) return const VLoading(label: 'Loading clubs');

    final displayClubs = _filteredClubs;

    return RefreshIndicator(
      onRefresh: _load,
      color: VColor.accent,
      backgroundColor: VColor.surface,
      child: ListView(
        padding: const EdgeInsets.all(VSpace.base),
        children: [
          // City Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final city in _cities) ...[
                  ChoiceChip(
                    label: Text(city),
                    selected: _selectedCity == city,
                    onSelected: (_) => setState(() => _selectedCity = city),
                    selectedColor: VColor.accentGlow,
                    labelStyle: TextStyle(
                      color: _selectedCity == city ? VColor.accent : VColor.textMid,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: VColor.surface,
                    side: BorderSide(
                      color: _selectedCity == city ? VColor.accent : VColor.line,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          if (displayClubs.isEmpty)
            VEmptyState(
              title: _selectedCity == 'All Cities' ? 'No clubs yet' : 'No clubs in $_selectedCity yet',
              body: _selectedCity == 'All Cities'
                  ? 'Check back soon.'
                  : 'Be the first athlete to start a running or training club in $_selectedCity!',
            )
          else
            for (final club in displayClubs) ...[
              VCard(
                tone: CardTone.raised,
                child: InkWell(
                  onTap: () async {
                    await pushScreen(context, club.name, _ClubDetail(club: club));
                    if (mounted) _load();
                  },
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
              ),
              const SizedBox(height: VSpace.sm),
            ],
        ],
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
  late bool _joined = widget.club.joined;
  late int _memberCount = widget.club.memberCount;
  bool _joining = false;

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

  Future<void> _toggleJoin() async {
    setState(() => _joining = true);
    final api = context.read<VyraApi>();
    try {
      if (_joined) {
        await api.leaveClub(widget.club.id);
        if (mounted) {
          setState(() {
            _joined = false;
            _memberCount = (_memberCount - 1).clamp(0, 999999);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Left ${widget.club.name}')),
          );
        }
      } else {
        await api.joinClub(widget.club.id);
        if (mounted) {
          setState(() {
            _joined = true;
            _memberCount += 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ You joined ${widget.club.name}! Welcome aboard.'),
              backgroundColor: VColor.accentGreen,
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _joining = false);
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
          // Club Header Card with Join Action
          VCard(
            tone: CardTone.raised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: VColor.accentGlow,
                        borderRadius: BorderRadius.circular(VRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.groups, color: VColor.accent, size: 26),
                    ),
                    const SizedBox(width: VSpace.base),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.club.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text('$_memberCount active members · ${widget.club.interestTag}',
                              style: const TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.sm),
                Text(widget.club.description, style: const TextStyle(color: VColor.textMid, fontSize: 13.5)),
                const SizedBox(height: VSpace.base),
                SizedBox(
                  width: double.infinity,
                  child: _joined
                      ? OutlinedButton.icon(
                          onPressed: _joining ? null : _toggleJoin,
                          icon: _joining
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accent))
                              : const Icon(Icons.check_circle_rounded, color: VColor.accentGreen, size: 18),
                          label: const Text('JOINED · TAP TO LEAVE', style: TextStyle(color: VColor.textMid, fontSize: 12, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: VColor.line),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _joining ? null : _toggleJoin,
                          icon: _joining
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent))
                              : const Icon(Icons.group_add_rounded, size: 18),
                          label: const Text('JOIN CLUB', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          style: FilledButton.styleFrom(
                            backgroundColor: VColor.accent,
                            foregroundColor: VColor.textOnAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                ),
              ],
            ),
          ),
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
