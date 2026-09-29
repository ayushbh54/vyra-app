import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'pose_tracker.dart';

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({
    super.key,
    this.customChallenge,
    this.communityId,
    this.title,
    this.description,
    this.badge,
    this.participants,
    this.rewardCoins,
    this.currentProgress,
    this.progressLabel,
    this.isJoined = false,
    this.onToggleJoin,
    this.onCheckedIn,
  });

  final CustomChallenge? customChallenge;
  final String? communityId;
  final String? title;
  final String? description;
  final String? badge;
  final int? participants;
  final int? rewardCoins;
  final double? currentProgress;
  final String? progressLabel;
  final bool isJoined;
  final VoidCallback? onToggleJoin;
  final ValueChanged<int>? onCheckedIn;

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  late bool _isJoined;
  late int _streak;
  late bool _checkedInToday;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isJoined = widget.isJoined;
    _streak = widget.customChallenge?.streak ?? 0;
    _checkedInToday = widget.customChallenge?.checkedInToday ?? false;
  }

  String _detectExerciseForChallenge(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('push')) return 'pushup';
    if (lower.contains('squat')) return 'squat';
    if (lower.contains('curl') || lower.contains('arm') || lower.contains('bicep')) return 'bicep_curl';
    if (lower.contains('bridge') || lower.contains('glute') || lower.contains('hip')) return 'glute_bridge';
    if (lower.contains('jump') || lower.contains('cardio') || lower.contains('jack')) return 'jumping_jacks';
    return 'squat';
  }

  Future<void> _checkIn() async {
    final custom = widget.customChallenge;
    if (custom == null) return;

    final detectedEx = _detectExerciseForChallenge(custom.title);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VColor.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
        side: BorderSide(color: VColor.line),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(VSpace.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: VColor.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: VColor.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Workout Verification',
                        style: TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Verify daily proof for "${custom.title}"',
                        style: const TextStyle(color: VColor.textLow, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSpace.base),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [VColor.accent.withValues(alpha: 0.15), VColor.surfaceRaised],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(VRadius.lg),
                border: Border.all(color: VColor.accent.withValues(alpha: 0.4)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: VColor.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded, color: VColor.accent),
                ),
                title: Row(
                  children: [
                    const Text('Live AI Camera Form Verification',
                        style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: VColor.accentGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(VRadius.pill),
                      ),
                      child: const Text('RECOMMENDED',
                          style: TextStyle(color: VColor.accentGreen, fontSize: 8.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'AI monitors joint angles, requires full range of motion & detects shallow form with "Do it better!" warnings.',
                  style: TextStyle(color: VColor.textMid, fontSize: 11.5),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: VColor.accent),
                onTap: () => Navigator.pop(ctx, 'live_camera'),
              ),
            ),
            const SizedBox(height: VSpace.sm),
            ListTile(
              leading: const Icon(Icons.flash_on_rounded, color: VColor.accentGreen),
              title: const Text('Quick Pass Verification', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600)),
              subtitle: const Text('Check in without camera', style: TextStyle(color: VColor.textMid, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'direct'),
            ),
            const SizedBox(height: VSpace.sm),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'live_camera') {
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PoseTrackerScreen(
            exerciseName: detectedEx,
            targetReps: 10,
            isChallengeVerification: true,
            challengeTitle: custom.title,
          ),
        ),
      );

      if (verified != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final newStreak = await context.read<VyraApi>().checkinChallenge(custom.id);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _streak = newStreak;
        _checkedInToday = true;
      });
      widget.onCheckedIn?.call(newStreak);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 AI Verified & Checked in! $newStreak-day streak active! +10 Coins!'),
            backgroundColor: VColor.accentGreen,
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

  void _toggleCommunityJoin() {
    HapticFeedback.selectionClick();
    setState(() => _isJoined = !_isJoined);
    widget.onToggleJoin?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isJoined ? '🌟 Joined Community Challenge!' : 'Left challenge.'),
        backgroundColor: _isJoined ? VColor.accentGreen : VColor.surfaceRaised,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = widget.customChallenge != null;
    final displayTitle = isCustom ? widget.customChallenge!.title : (widget.title ?? 'Challenge');
    final displayDesc = isCustom
        ? (widget.customChallenge!.rules.isNotEmpty ? widget.customChallenge!.rules : 'Daily consistency habit challenge.')
        : (widget.description ?? '');
    final reward = widget.rewardCoins ?? (isCustom ? 15 : 40);
    final daysTotal = isCustom ? widget.customChallenge!.durationDays : 7;
    final badgeLabel = widget.badge ?? (isCustom ? '$daysTotal Days' : 'Community');

    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        leading: const BackButton(color: VColor.text),
        title: Text(
          displayTitle,
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
                    const Text('REWARD', style: TextStyle(color: VColor.textLow, fontSize: 11, fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: VColor.accent, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '+$reward Coins',
                          style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: VSpace.base),
              if (isCustom)
                FilledButton.icon(
                  onPressed: (_checkedInToday || _busy) ? null : _checkIn,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_checkedInToday ? Icons.check_circle_rounded : Icons.bolt_rounded),
                  label: Text(_checkedInToday ? 'Checked in Today' : 'Daily Check-In'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _checkedInToday ? VColor.accentGreen : VColor.accent,
                    foregroundColor: VColor.textOnAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.md)),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _toggleCommunityJoin,
                  icon: Icon(_isJoined ? Icons.check_circle_rounded : Icons.group_add_rounded),
                  label: Text(_isJoined ? 'Participating' : 'Join League'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isJoined ? VColor.accentGreen : VColor.accent,
                    foregroundColor: VColor.textOnAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.md)),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VSpace.base),
        children: [
          // ── Hero Header ──
          Container(
            padding: const EdgeInsets.all(VSpace.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [VColor.accent.withValues(alpha: 0.2), VColor.surfaceRaised],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VRadius.lg),
              border: Border.all(color: VColor.accent.withValues(alpha: 0.35)),
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
                        color: VColor.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(VRadius.pill),
                      ),
                      child: Text(
                        badgeLabel.toUpperCase(),
                        style: const TextStyle(color: VColor.accent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (widget.participants != null)
                      Text(
                        '${widget.participants} athletes competing',
                        style: const TextStyle(color: VColor.textMid, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: VSpace.md),
                Text(
                  displayTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: VColor.text,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: VSpace.sm),
                Text(
                  displayDesc,
                  style: const TextStyle(color: VColor.textMid, fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Streak & Progress Section ──
          if (isCustom) ...[
            VCard(
              tone: CardTone.raised,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const VLabel('CURRENT STREAK'),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text('🔥 ', style: TextStyle(fontSize: 22)),
                              Text(
                                '$_streak Days',
                                style: const TextStyle(color: VColor.text, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      VRing(
                        progress: daysTotal > 0 ? (_streak / daysTotal).clamp(0.0, 1.0) : 0,
                        size: 64,
                        child: Text(
                          '${((_streak / (daysTotal > 0 ? daysTotal : 1)) * 100).round()}%',
                          style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSpace.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(VRadius.pill),
                    child: LinearProgressIndicator(
                      value: daysTotal > 0 ? (_streak / daysTotal).clamp(0.0, 1.0) : 0,
                      minHeight: 8,
                      backgroundColor: VColor.steel,
                      valueColor: const AlwaysStoppedAnimation(VColor.accent),
                    ),
                  ),
                  const SizedBox(height: VSpace.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Day 1', style: TextStyle(color: VColor.textLow, fontSize: 11)),
                      Text('Goal: $daysTotal Days', style: const TextStyle(color: VColor.textLow, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            VCard(
              tone: CardTone.raised,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const VLabel('LEAGUE PROGRESS'),
                  const SizedBox(height: VSpace.xs),
                  Text(
                    widget.progressLabel ?? 'Community goal in progress',
                    style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: VSpace.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(VRadius.pill),
                    child: LinearProgressIndicator(
                      value: widget.currentProgress ?? 0.5,
                      minHeight: 8,
                      backgroundColor: VColor.steel,
                      valueColor: const AlwaysStoppedAnimation(VColor.accentGreen),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: VSpace.base),

          // ── Rules & Consistency Guide ──
          const VLabel('RULES & VERIFICATION'),
          const SizedBox(height: VSpace.xs),
          VCard(
            tone: CardTone.normal,
            child: Column(
              children: [
                _ruleTile(
                  Icons.verified_user_outlined,
                  'Proof of Effort',
                  'Activity is automatically validated via GPS sensors, workout log completion, or daily check-in.',
                ),
                const Divider(color: VColor.line, height: 20),
                _ruleTile(
                  Icons.timelapse_rounded,
                  'Daily Window',
                  'Check-in is available once every 24 hours between 00:00 and 23:59 local time.',
                ),
                const Divider(color: VColor.line, height: 20),
                _ruleTile(
                  Icons.emoji_events_outlined,
                  'Milestone Badges & Coins',
                  'Earn coins immediately upon daily check-in, plus an exclusive profile badge upon completion.',
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.xxl),
        ],
      ),
    );
  }

  Widget _ruleTile(IconData icon, String title, String desc) {
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
