import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    this.onRegisteredChanged,
  });

  final EventItem event;
  final ValueChanged<bool>? onRegisteredChanged;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late bool _registered;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _registered = widget.event.registered;
  }

  Future<void> _toggleRegister() async {
    setState(() => _busy = true);
    final api = context.read<VyraApi>();
    try {
      if (_registered) {
        await api.unregisterFromEvent(widget.event.id);
        setState(() => _registered = false);
      } else {
        await api.registerForEvent(widget.event.id);
        setState(() => _registered = true);
      }
      widget.onRegisteredChanged?.call(_registered);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _registered
                  ? '🎉 You are registered for ${widget.event.title}!'
                  : 'You have cancelled your registration.',
            ),
            backgroundColor: _registered ? VColor.accentGreen : VColor.surfaceRaised,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final date = DateTime.tryParse(event.startsAt);
    final formattedDate = date != null
        ? DateFormat('EEEE, MMMM d, y · h:mm a').format(date.toLocal())
        : event.startsAt;

    final sportIcon = switch (event.sport.toLowerCase()) {
      'run' => Icons.directions_run_rounded,
      'ride' || 'cycling' => Icons.directions_bike_rounded,
      'walk' => Icons.directions_walk_rounded,
      _ => Icons.fitness_center_rounded,
    };

    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        leading: const BackButton(color: VColor.text),
        title: Text(
          event.title,
          style: const TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(VSpace.base),
          decoration: const BoxDecoration(
            color: VColor.surface,
            border: Border(top: BorderSide(color: VColor.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _registered ? 'Status: Confirmed' : 'Registration Open',
                      style: TextStyle(
                        color: _registered ? VColor.accentGreen : VColor.textMid,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _registered ? 'Spot Reserved' : 'Free Entry',
                      style: const TextStyle(
                        color: VColor.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: VSpace.base),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _toggleRegister,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_registered ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded),
                  label: Text(_registered ? 'Going (Cancel)' : 'RSVP / Join'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _registered ? VColor.accentGreen : VColor.accent,
                    foregroundColor: VColor.textOnAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.md)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VSpace.base),
        children: [
          // ── Hero Banner Card ──
          Container(
            padding: const EdgeInsets.all(VSpace.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  VColor.accent.withOpacity(0.22),
                  VColor.surfaceRaised,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VRadius.lg),
              border: Border.all(color: VColor.accent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: VColor.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(VRadius.pill),
                        border: Border.all(color: VColor.accent.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(sportIcon, size: 14, color: VColor.accent),
                          const SizedBox(width: 6),
                          Text(
                            event.sport.toUpperCase(),
                            style: const TextStyle(
                              color: VColor.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_registered)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: VColor.accentGreenGlow,
                          borderRadius: BorderRadius.circular(VRadius.pill),
                          border: Border.all(color: VColor.accentGreen.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check, size: 14, color: VColor.accentGreen),
                            SizedBox(width: 4),
                            Text(
                              'REGISTERED',
                              style: TextStyle(
                                color: VColor.accentGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: VSpace.md),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: VColor.text,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: VSpace.sm),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: VColor.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.location,
                        style: const TextStyle(color: VColor.textMid, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Date & Time Section ──
          VCard(
            tone: CardTone.normal,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: VColor.accentGlow,
                    borderRadius: BorderRadius.circular(VRadius.md),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: VColor.accent, size: 22),
                ),
                const SizedBox(width: VSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const VLabel('DATE & TIME'),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.sm),

          // ── Venue & Route Overview ──
          VCard(
            tone: CardTone.normal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: VColor.accentGreenGlow,
                        borderRadius: BorderRadius.circular(VRadius.md),
                      ),
                      child: const Icon(Icons.map_outlined, color: VColor.accentGreen, size: 22),
                    ),
                    const SizedBox(width: VSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const VLabel('MEETUP POINT'),
                          const SizedBox(height: 2),
                          Text(
                            event.location,
                            style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.md),
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: VColor.surfaceRaised,
                    borderRadius: BorderRadius.circular(VRadius.md),
                    border: Border.all(color: VColor.line),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pin_drop_rounded, color: VColor.accent, size: 32),
                        const SizedBox(height: 6),
                        Text(
                          'Route & GPS Waypoint: ${event.location}',
                          style: const TextStyle(color: VColor.textMid, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Event Guidelines & Rules ──
          const VLabel('GUIDELINES & GEAR'),
          const SizedBox(height: VSpace.xs),
          VCard(
            tone: CardTone.raised,
            child: Column(
              children: [
                _guidelineRow(
                  Icons.water_drop_outlined,
                  'Hydration & Fuel',
                  'Carry personal water bottle and light electrolytes. Refill stations provided.',
                ),
                const Divider(color: VColor.line, height: 20),
                _guidelineRow(
                  Icons.watch_outlined,
                  'Wearable & GPS Tracking',
                  'Turn on VYRA Record tab before flag-off to auto-sync your activity and earn coins.',
                ),
                const Divider(color: VColor.line, height: 20),
                _guidelineRow(
                  Icons.accessible_forward_rounded,
                  'Accessibility & Pace Groups',
                  'Inclusive pacing: Beginners, Walkers, Adaptive athletes and Pacers available.',
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Community Athletes Attending ──
          const VLabel('COMMUNITY ATHLETES'),
          const SizedBox(height: VSpace.xs),
          VCard(
            tone: CardTone.normal,
            child: const Row(
              children: [
                SizedBox(
                  width: 90,
                  height: 36,
                  child: Stack(
                    children: [
                      CircleAvatar(radius: 16, backgroundColor: VColor.accent, child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12))),
                      Positioned(left: 20, child: CircleAvatar(radius: 16, backgroundColor: VColor.accentGreen, child: Text('P', style: TextStyle(color: Colors.black, fontSize: 12)))),
                      Positioned(left: 40, child: CircleAvatar(radius: 16, backgroundColor: Colors.amber, child: Text('R', style: TextStyle(color: Colors.black, fontSize: 12)))),
                      Positioned(left: 60, child: CircleAvatar(radius: 16, backgroundColor: Colors.cyan, child: Text('V', style: TextStyle(color: Colors.black, fontSize: 12)))),
                    ],
                  ),
                ),
                SizedBox(width: VSpace.sm),
                Expanded(
                  child: Text(
                    'Join 30+ runners and athletes from the VYRA community.',
                    style: TextStyle(color: VColor.textMid, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.xxl),
        ],
      ),
    );
  }

  Widget _guidelineRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: VColor.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: VColor.textMid, fontSize: 12, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}
