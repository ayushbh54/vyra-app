import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// MAPS — every route you have recorded, browsable on one map.
///
/// Deliberately scoped for now: it plots your own activities. A full
/// global heatmap needs real usage at scale to mean anything, so that stays
/// a later phase rather than a screen full of fake data today.
class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  List<ActivityItem>? _activities;
  String? _error;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<VyraApi>().myActivities();
      if (mounted) setState(() { _activities = items; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _centerOnMe() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _mapController.move(ll.LatLng(pos.latitude, pos.longitude), 14);
    } catch (_) {
      // Silent — the map still works without a centred location.
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = (_activities ?? []).where((a) => a.route.length > 1).toList();

    return SafeArea(
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: ll.LatLng(28.6139, 77.2090), // Delhi — re-centres once location resolves
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vyra.app',
              ),
              for (final activity in routes)
                PolylineLayer(polylines: [
                  Polyline(
                    points: activity.route.map((p) => ll.LatLng(p.lat, p.lng)).toList(),
                    color: VColor.accent,
                    strokeWidth: 3,
                  ),
                ]),
            ],
          ),
          Positioned(
            top: VSpace.base, left: VSpace.base, right: VSpace.base,
            child: Text('Maps', style: Theme.of(context).textTheme.headlineMedium),
          ),
          Positioned(
            right: VSpace.base, bottom: VSpace.base,
            child: FloatingActionButton(
              backgroundColor: VColor.surfaceRaised,
              foregroundColor: VColor.accent,
              onPressed: _centerOnMe,
              child: const Icon(Icons.my_location),
            ),
          ),
          if (_error != null)
            Positioned(
              left: VSpace.base, right: VSpace.base, bottom: VSpace.xxxl,
              child: VErrorView(message: _error!, onRetry: _load),
            ),
          if (_activities != null && routes.isEmpty && _error == null)
            const Positioned(
              left: VSpace.base, right: VSpace.base, bottom: VSpace.xxxl,
              child: VEmptyState(
                title: 'No routes yet',
                body: 'Record an activity on the Record tab and it will show up here.',
              ),
            ),
        ],
      ),
    );
  }
}
