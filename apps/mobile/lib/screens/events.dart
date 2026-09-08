import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _sportIcons = <String, IconData>{
  'run': Icons.directions_run,
  'ride': Icons.directions_bike,
  'walk': Icons.directions_walk,
};

/// EVENTS — the third Groups pillar: local club meetups and races to
/// register for, the way Strava surfaces "Local Club Events" and "Races".
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<EventItem>? _events;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await context.read<VyraApi>().events();
      if (mounted) setState(() { _events = events; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleRegister(EventItem event) async {
    final api = context.read<VyraApi>();
    try {
      if (event.registered) {
        await api.unregisterFromEvent(event.id);
      } else {
        await api.registerForEvent(event.id);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return VErrorView(message: _error!, onRetry: _load);
    if (_events == null) return const VLoading(label: 'Loading events');
    if (_events!.isEmpty) {
      return const VEmptyState(title: 'No events yet', body: 'Check back soon.');
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: VColor.accent,
      backgroundColor: VColor.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(VSpace.base),
        itemCount: _events!.length,
        separatorBuilder: (_, __) => const SizedBox(height: VSpace.sm),
        itemBuilder: (context, i) {
          final event = _events![i];
          final date = DateTime.tryParse(event.startsAt);
          return VCard(
            tone: CardTone.raised,
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: VColor.accentGlow,
                    borderRadius: BorderRadius.circular(VRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_sportIcons[event.sport] ?? Icons.event, color: VColor.accent),
                ),
                const SizedBox(width: VSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        date != null
                            ? '${DateFormat('MMM d, h:mm a').format(date.toLocal())} · ${event.location}'
                            : event.location,
                        style: const TextStyle(color: VColor.textLow, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _toggleRegister(event),
                  child: Text(event.registered ? 'Going' : 'Join'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
