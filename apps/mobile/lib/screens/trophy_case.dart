import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _milestones = [1, 3, 5, 10, 20, 30, 40, 50, 75, 100];

/// TROPHY CASE — activity-count milestones. Computed client-side from the
/// athlete's own activity count; no backend endpoint needed for something
/// this simple to derive.
class TrophyCaseScreen extends StatefulWidget {
  const TrophyCaseScreen({super.key});

  @override
  State<TrophyCaseScreen> createState() => _TrophyCaseScreenState();
}

class _TrophyCaseScreenState extends State<TrophyCaseScreen> {
  int? _count;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final activities = await context.read<VyraApi>().myActivities(limit: 200);
      if (mounted) setState(() { _count = activities.length; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return VErrorView(message: _error!, onRetry: _load);
    if (_count == null) return const VLoading(label: 'Loading trophies');

    return GridView.builder(
      padding: const EdgeInsets.all(VSpace.base),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: VSpace.base,
        crossAxisSpacing: VSpace.base,
        childAspectRatio: 0.85,
      ),
      itemCount: _milestones.length,
      itemBuilder: (context, i) {
        final threshold = _milestones[i];
        final unlocked = _count! >= threshold;
        return Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: unlocked ? VColor.accentGlow : VColor.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: unlocked ? VColor.accent : VColor.line),
              ),
              alignment: Alignment.center,
              child: Icon(
                unlocked ? Icons.emoji_events : Icons.lock_outline,
                color: unlocked ? VColor.accent : VColor.textLow,
                size: 28,
              ),
            ),
            const SizedBox(height: VSpace.sm),
            Text(
              '$threshold${threshold == 1 ? 'st' : threshold == 3 ? 'rd' : 'th'} Activity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: unlocked ? VColor.text : VColor.textLow,
                fontWeight: unlocked ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        );
      },
    );
  }
}
