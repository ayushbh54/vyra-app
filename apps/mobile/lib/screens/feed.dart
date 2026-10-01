import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';
import 'friends.dart';

/// HOME — the activity feed.
///
/// Every saved Record shows up here for the athlete and everyone following
/// them, newest first. This is the screen that makes VYRA feel alive rather
/// than like a private tracker — the same reason Strava opens on this tab.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const _feedCacheKey = 'vyra_cached_feed_v1';
  List<ActivityItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedFeed();
    _load();
  }

  Future<void> _loadCachedFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_feedCacheKey);
      if (raw != null && raw.isNotEmpty && _items == null) {
        final decoded = jsonDecode(raw) as List;
        final cached = decoded
            .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (cached.isNotEmpty && mounted && _items == null) {
          setState(() => _items = cached);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCachedFeed(List<ActivityItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(items.map((i) => i.toJson()).toList());
      await prefs.setString(_feedCacheKey, raw);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final items = await context.read<VyraApi>().feed();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
        _saveCachedFeed(items);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleKudos(ActivityItem item) async {
    try {
      await context.read<VyraApi>().toggleKudos(item.id);
      await _load();
    } on ApiException catch (_) {
      // A failed kudos tap is not worth interrupting the feed for.
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('VYRA', style: Theme.of(context).textTheme.headlineMedium),
                IconButton(
                  icon: const Icon(Icons.person_search_outlined, color: VColor.text),
                  tooltip: 'Find athletes',
                  onPressed: () => pushScreen(context, 'Find athletes', const FriendsScreen()),
                ),
              ],
            ),
            const SizedBox(height: VSpace.base),

            if (_error != null) VErrorView(message: _error!, onRetry: _load),
            if (_error == null && _items == null) const VLoading(label: 'Loading your feed'),

            if (_items != null && _items!.isEmpty)
              VEmptyState(
                title: 'No posts yet. Start your first workout!',
                body: 'Record your first activity, or follow other athletes to see theirs here.',
                action: FilledButton(
                  onPressed: () => pushScreen(context, 'Find athletes', const FriendsScreen()),
                  child: const Text('Find athletes to follow'),
                ),
              ),

            for (final item in _items ?? []) ...[
              const SizedBox(height: VSpace.base),
              _ActivityCard(item: item, onKudos: () => _toggleKudos(item)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item, required this.onKudos});

  final ActivityItem item;
  final VoidCallback onKudos;

  @override
  Widget build(BuildContext context) {
    final points = item.route.map((p) => ll.LatLng(p.lat, p.lng)).toList();

    return VCard(
      tone: CardTone.raised,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.sm),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: VColor.accentGlow,
                  child: Text(
                    item.authorName.isNotEmpty ? item.authorName[0].toUpperCase() : '?',
                    style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: VSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.authorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('@${item.authorHandle}',
                          style: const TextStyle(color: VColor.textLow, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSpace.base),
            child: Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: VSpace.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSpace.base),
            child: Row(
              children: [
                VStat(label: 'Distance', value: item.distanceKm.toStringAsFixed(2), unit: 'km',
                    tint: VColor.accentGreen),
                const SizedBox(width: VSpace.lg),
                VStat(label: 'Pace', value: item.pacePerKm, unit: '/km', tint: VColor.accentOrange),
                const SizedBox(width: VSpace.lg),
                VStat(label: 'Time', value: item.durationLabel, tint: VColor.accent),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),
          if (points.length > 1)
            ClipRRect(
              child: SizedBox(
                height: 160,
                child: IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(24)),
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.vyra.app',
                      ),
                      PolylineLayer(polylines: [
                        Polyline(points: points, color: VColor.accent, strokeWidth: 4),
                      ]),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              height: 60,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: VSpace.base),
              child: const Text('No GPS route recorded for this one.',
                  style: TextStyle(color: VColor.textLow, fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.all(VSpace.base),
            child: Row(
              children: [
                InkWell(
                  onTap: onKudos,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          item.kudosGiven ? Icons.bolt : Icons.bolt_outlined,
                          size: 18,
                          color: item.kudosGiven ? VColor.accent : VColor.textMid,
                        ),
                        const SizedBox(width: 4),
                        Text('Kudos', style: TextStyle(
                            color: item.kudosGiven ? VColor.accent : VColor.textMid, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: VSpace.lg),
                const Icon(Icons.mode_comment_outlined, size: 16, color: VColor.textMid),
                const SizedBox(width: 4),
                Text('${item.commentCount}',
                    style: const TextStyle(color: VColor.textMid, fontSize: 12)),
                const Spacer(),
                InkWell(
                  onTap: () {
                    final shareText = '''🏃 VYRA ATHLETE ACTIVITY 🏃
📌 ${item.title}
⚡ Type: ${item.type.toUpperCase()}
📍 Distance: ${item.distanceKm.toStringAsFixed(2)} km
⏱️ Time: ${item.durationLabel}
🔥 Pace: ${item.pacePerKm} /km

Tracked on VYRA — Next-Gen AI Biometric Fitness Platform! #StravaStyle #VYRA''';
                    // ignore: deprecated_member_use
                    Share.share(shareText, subject: item.title);
                  },
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, size: 15, color: VColor.accent),
                        SizedBox(width: 4),
                        Text('Share', style: TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
