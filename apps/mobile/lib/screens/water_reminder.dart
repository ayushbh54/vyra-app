import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Stitch Page 34b: Hydration Engine & Water Reminder Settings
class WaterReminderScreen extends StatefulWidget {
  const WaterReminderScreen({super.key});

  @override
  State<WaterReminderScreen> createState() => _WaterReminderScreenState();
}

class _WaterReminderScreenState extends State<WaterReminderScreen> {
  bool _enabled = true;
  int _targetMl = 3200;
  int _currentIntakeMl = 1750;
  int _intervalMinutes = 60;
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);
  bool _soundEnabled = true;

  void _logCup(int ml) {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentIntakeMl = (_currentIntakeMl + ml).clamp(0, 10000);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💧 Logged +$ml ml of pure water! ($_currentIntakeMl / $_targetMl ml)'),
        backgroundColor: VColor.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIntakeMl / _targetMl).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surfaceRaised,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: VColor.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Hydration Schedule', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VSpace.base),
        children: [
          // ── Hero Banner (Stitch Page 34b) ──
          Container(
            padding: const EdgeInsets.all(VSpace.base),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  VColor.accent.withValues(alpha: 0.15),
                  VColor.surfaceRaised,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VRadius.xl),
              border: Border.all(color: VColor.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.water_drop_rounded, color: VColor.accent, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'ACTIVE PROTOCOL',
                            style: TextStyle(color: VColor.accent, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Hydration Engine v4.2',
                        style: TextStyle(color: VColor.text, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Calibrated for cellular recovery and athletic endurance.',
                        style: TextStyle(color: VColor.textMid, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: VColor.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: VColor.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Center(child: Icon(Icons.water, color: VColor.accent, size: 26)),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Today's Intake Progress Card ──
          Container(
            padding: const EdgeInsets.all(VSpace.base),
            decoration: BoxDecoration(
              color: VColor.surfaceRaised,
              borderRadius: BorderRadius.circular(VRadius.lg),
              border: Border.all(color: VColor.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Today\'s Water Intake', style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      '$_currentIntakeMl / $_targetMl ml',
                      style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: VColor.bg,
                    valueColor: const AlwaysStoppedAnimation(VColor.accent),
                  ),
                ),
                const SizedBox(height: VSpace.base),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: VColor.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                      ),
                      onPressed: () => _logCup(250),
                      icon: const Icon(Icons.local_drink_rounded, size: 16, color: VColor.accent),
                      label: const Text('+250 ml Glass', style: TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: VColor.accentGreen),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                      ),
                      onPressed: () => _logCup(500),
                      icon: const Icon(Icons.water_drop_rounded, size: 16, color: VColor.accentGreen),
                      label: const Text('+500 ml Bottle', style: TextStyle(color: VColor.accentGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Main Toggle Switch Card (Stitch Page 34b) ──
          Container(
            padding: const EdgeInsets.all(VSpace.base),
            decoration: BoxDecoration(
              color: VColor.surfaceRaised,
              borderRadius: BorderRadius.circular(VRadius.lg),
              border: Border.all(color: VColor.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: VColor.bgLift,
                    borderRadius: BorderRadius.circular(VRadius.md),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: VColor.accent, size: 22),
                ),
                const SizedBox(width: VSpace.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Water Reminders', style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Intelligent alerts during active daylight hours', style: TextStyle(color: VColor.textMid, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  activeThumbColor: VColor.accent,
                  activeTrackColor: VColor.accent.withValues(alpha: 0.3),
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _enabled = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Daily Target Selector ──
          const VLabel('DAILY TARGET VOLUME'),
          const SizedBox(height: VSpace.xs),
          Row(
            children: [2500, 3000, 3200, 3500, 4000].map((val) {
              final isSel = _targetMl == val;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(VRadius.md),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _targetMl = val);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? VColor.accent.withValues(alpha: 0.15) : VColor.surfaceRaised,
                        borderRadius: BorderRadius.circular(VRadius.md),
                        border: Border.all(color: isSel ? VColor.accent : VColor.line),
                      ),
                      child: Center(
                        child: Text(
                          '${(val / 1000).toStringAsFixed(1)}L',
                          style: TextStyle(
                            color: isSel ? VColor.accent : VColor.textMid,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: VSpace.base),

          // ── Frequency Interval Selector ──
          const VLabel('REMINDER FREQUENCY'),
          const SizedBox(height: VSpace.xs),
          Row(
            children: [30, 45, 60, 90].map((mins) {
              final isSel = _intervalMinutes == mins;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(VRadius.md),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _intervalMinutes = mins);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? VColor.accentGreen.withValues(alpha: 0.15) : VColor.surfaceRaised,
                        borderRadius: BorderRadius.circular(VRadius.md),
                        border: Border.all(color: isSel ? VColor.accentGreen : VColor.line),
                      ),
                      child: Center(
                        child: Text(
                          '$mins min',
                          style: TextStyle(
                            color: isSel ? VColor.accentGreen : VColor.textMid,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: VSpace.base),

          // ── Active Hours Window ──
          const VLabel('ACTIVE HOURS WINDOW'),
          const SizedBox(height: VSpace.xs),
          Container(
            padding: const EdgeInsets.all(VSpace.md),
            decoration: BoxDecoration(
              color: VColor.surfaceRaised,
              borderRadius: BorderRadius.circular(VRadius.lg),
              border: Border.all(color: VColor.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _timePickerColumn('Start (Wake Up)', _startTime, (t) => setState(() => _startTime = t)),
                Container(width: 1, height: 32, color: VColor.line),
                _timePickerColumn('End (Bedtime)', _endTime, (t) => setState(() => _endTime = t)),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Sound & Haptics Toggle ──
          SwitchListTile(
            title: const Text('Sound & Haptic Chime', style: TextStyle(color: VColor.text, fontSize: 14)),
            subtitle: const Text('Gentle sonic chime to keep focus during workouts', style: TextStyle(color: VColor.textLow, fontSize: 11.5)),
            value: _soundEnabled,
            activeThumbColor: VColor.accent,
            tileColor: VColor.surfaceRaised,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.lg)),
            onChanged: (val) => setState(() => _soundEnabled = val),
          ),
          const SizedBox(height: VSpace.xl),

          // Save button
          VGradientButton(
            label: 'Save Hydration Schedule',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('💧 Hydration schedule calibrated successfully!'),
                  backgroundColor: VColor.accentGreen,
                ),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _timePickerColumn(String label, TimeOfDay time, Function(TimeOfDay) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPicked(picked);
      },
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: VColor.textLow, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: VColor.accent),
              const SizedBox(width: 6),
              Text(
                time.format(context),
                style: const TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
