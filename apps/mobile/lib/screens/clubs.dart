import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'club_detail.dart';

/// CLUBS — interest-based groups with a request-to-join workflow.
///
/// Tapping a club card navigates to [ClubDetailScreen]. Status is displayed
/// inline: 'Member ✓', 'Pending ⏳', or 'View →'.
class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  List<ClubItem>? _clubs;
  String? _error;
  String _selectedCity = 'All Cities';

  /// Locally tracked pending join requests (by club id).
  final Set<String> _pendingRequests = {};

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
      if (!mounted) return;
      setState(() { _clubs = clubs; _error = null; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
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

  /// Returns the inline status widget for a club card.
  Widget _statusChip(ClubItem club) {
    if (club.joined) {
      return const Text(
        'Member ✓',
        style: TextStyle(color: VColor.accentGreen, fontSize: 12, fontWeight: FontWeight.w700),
      );
    }
    if (_pendingRequests.contains(club.id) || club.requestPending) {
      return const Text(
        'Pending ⏳',
        style: TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w700),
      );
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'View',
          style: TextStyle(color: VColor.textMid, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        SizedBox(width: 2),
        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: VColor.textMid),
      ],
    );
  }

  Future<void> _openDetail(ClubItem club) async {
    final approvedId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ClubDetailScreen(
          club: club,
          isPending: _pendingRequests.contains(club.id),
        ),
      ),
    );

    if (!mounted) return;

    if (approvedId != null) {
      // The detail screen approved the request — refresh from API.
      await _load();
    }
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
                  borderRadius: BorderRadius.circular(VRadius.lg),
                  onTap: () => _openDetail(club),
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
                      _statusChip(club),
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
