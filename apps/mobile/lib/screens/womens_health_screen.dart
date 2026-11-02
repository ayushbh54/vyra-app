import 'dart:async';
import 'package:flutter/material.dart';
import '../services/womens_health_service.dart';

/// VYRA FeminaHealth™ — Women's Health, Period Sanctuary & 9-Month Maternal Care
class WomensHealthScreen extends StatefulWidget {
  const WomensHealthScreen({super.key});

  @override
  State<WomensHealthScreen> createState() => _WomensHealthScreenState();
}

class _WomensHealthScreenState extends State<WomensHealthScreen> {
  final WomensHealthService _service = WomensHealthService.instance;

  bool _isPregnancyMode = false;
  bool _isLoading = true;
  String _selectedCategory = 'All';

  // Selected date for Femina logging
  final DateTime _selectedDate = DateTime.now();
  FeminaFlow _selectedFlow = FeminaFlow.medium;
  int _crampSeverity = 2;
  final Set<String> _activeSymptoms = {'cramps', 'fatigue'};
  String _selectedMood = 'calm';
  final TextEditingController _notesController = TextEditingController();

  // Kick Counter state
  int _currentKickCount = 0;
  bool _isKickTimerActive = false;
  int _kickSecondsElapsed = 0;
  Timer? _kickTimer;

  // Analytics cache
  Map<String, dynamic> _cycleAnalytics = {};
  Map<String, dynamic> _pregnancyAnalytics = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _kickTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _service.init();
    if (!mounted) return;

    setState(() {
      _isPregnancyMode = _service.isPregnancyMode;
      _refreshAnalytics();
      _isLoading = false;
    });
  }

  void _refreshAnalytics() {
    _cycleAnalytics = _service.computeCycleAnalytics(referenceDate: _selectedDate);
    _pregnancyAnalytics = _service.computePregnancyAnalytics();
  }

  Future<void> _toggleMode(bool pregnancyMode) async {
    setState(() {
      _isPregnancyMode = pregnancyMode;
      _selectedCategory = 'All';
    });
    await _service.setPregnancyMode(pregnancyMode);
    if (!mounted) return;
    setState(() {
      _refreshAnalytics();
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Kick Counter Actions
  // ---------------------------------------------------------------------------

  void _toggleKickTimer() {
    if (_isKickTimerActive) {
      _kickTimer?.cancel();
      setState(() => _isKickTimerActive = false);
    } else {
      setState(() => _isKickTimerActive = true);
      _kickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _kickSecondsElapsed++);
      });
    }
  }

  void _incrementKick() {
    if (!_isKickTimerActive) {
      _toggleKickTimer();
    }
    setState(() => _currentKickCount++);
  }

  Future<void> _saveKickSession() async {
    if (_currentKickCount == 0) return;
    await _service.recordKickSession(_currentKickCount, _kickSecondsElapsed);
    _kickTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isKickTimerActive = false;
      _currentKickCount = 0;
      _kickSecondsElapsed = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fetal kick session recorded successfully! 👶✨'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Symptom Logging Actions
  // ---------------------------------------------------------------------------

  Future<void> _saveDayLog() async {
    final log = FeminaDayLog(
      date: _formatDate(_selectedDate),
      flow: _selectedFlow,
      crampSeverity: _crampSeverity,
      symptoms: _activeSymptoms.toList(),
      mood: _selectedMood,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    await _service.saveDayLog(log);
    if (_selectedFlow != FeminaFlow.none) {
      await _service.logPeriodStartDate(_selectedDate);
    }

    if (!mounted) return;
    setState(() {
      _refreshAnalytics();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cycle day log saved! Care plan adapted. 🌸'),
        backgroundColor: Color(0xFFEC4899),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Modals & Bottom Sheets (Partner, Reminders, Watch Sync, LMP)
  // ---------------------------------------------------------------------------

  void _openPartnerGuideSheet() {
    PartnerEmpathyGuide guide;
    if (_isPregnancyMode) {
      final week = _pregnancyAnalytics['currentWeek'] as int? ?? 20;
      final trimester = _pregnancyAnalytics['trimester'] as MaternalTrimester? ?? MaternalTrimester.second;
      guide = _service.getMaternalPartnerGuide(week, trimester);
    } else {
      final phase = _cycleAnalytics['phase'] as FeminaPhase? ?? FeminaPhase.menstrual;
      final cycleDay = _cycleAnalytics['currentCycleDay'] as int? ?? 1;
      guide = _service.getFeminaPartnerGuide(phase, cycleDay);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.favorite_rounded, color: Color(0xFFF43F5E), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Partner Sync™ Empathy Companion',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              guide.phaseOrTrimester,
                              style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2433),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2E384D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🧠 What She Is Biologically Experiencing:',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          guide.emotionalContext,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '💖 What She Needs Most Right Now:',
                          style: TextStyle(color: Color(0xFFF43F5E), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          guide.whatSheNeedsMost,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('✅ What TO Do (Loving Support):', style: TextStyle(color: Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...guide.dosList.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(d, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 14),
                  const Text('❌ What NOT To Do (Avoid Friction):', style: TextStyle(color: Color(0xFFEF4444), fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...guide.dontsList.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(d, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 20),
                  const Text('🎁 Suggested Care Basket & Gifts:', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...guide.suggestedGiftsAndCare.map((g) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2A344A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.card_giftcard_rounded, color: Color(0xFFF59E0B), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g['item'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(g['whyItHelps'] ?? '', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _service.sharePartnerUpdate(guide.readyToShareMessage);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF43F5E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: const Text('Share Update to Partner (WhatsApp / SMS)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  void _openRemindersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final reminders = _service.customReminders;
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.alarm_rounded, color: Color(0xFF38BDF8), size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Care & Health Reminders',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF10B981), size: 26),
                        onPressed: () => _showAddReminderDialog(setSheetState),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Automatic notifications for medications, hydration, and doctor visits.', style: TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: reminders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, idx) {
                        final r = reminders[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F2C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: r.isEnabled ? const Color(0xFF38BDF8).withValues(alpha: 0.3) : const Color(0xFF262F40)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(r.timeSlot, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.title, style: TextStyle(color: r.isEnabled ? Colors.white : Colors.white38, fontWeight: FontWeight.w600, fontSize: 14)),
                                    if (r.notes != null)
                                      Text(r.notes!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Switch(
                                value: r.isEnabled,
                                activeThumbColor: const Color(0xFF38BDF8),
                                onChanged: (v) async {
                                  await _service.toggleCareReminder(r.id);
                                  setSheetState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                                onPressed: () async {
                                  await _service.deleteCareReminder(r.id);
                                  setSheetState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  void _showAddReminderDialog(void Function(void Function()) setSheetState) {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '09:00 AM');
    final notesCtrl = TextEditingController();
    String category = 'medication';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2433),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Custom Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Reminder Title (e.g. Folic Acid / Sonography)',
                        labelStyle: TextStyle(color: Colors.white60),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: timeCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Time (e.g. 08:30 AM)',
                        labelStyle: TextStyle(color: Colors.white60),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      dropdownColor: const Color(0xFF1E2433),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: Colors.white60),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'medication', child: Text('💊 Medication')),
                        DropdownMenuItem(value: 'meal', child: Text('🍲 Meal / Nutrition')),
                        DropdownMenuItem(value: 'hydration', child: Text('💧 Hydration')),
                        DropdownMenuItem(value: 'doctor_visit', child: Text('🩺 Doctor Visit / Scan')),
                        DropdownMenuItem(value: 'rest', child: Text('🛏️ Rest / Sleep Posture')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDlgState(() => category = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Instructions / Notes',
                        labelStyle: TextStyle(color: Colors.white60),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final newItem = CareReminderItem(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      category: category,
                      title: titleCtrl.text.trim(),
                      timeSlot: timeCtrl.text.trim(),
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                    await _service.addCareReminder(newItem);
                    setSheetState(() {});
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _openWatchSyncSheet() {
    SmartWatchBiometricSync syncData;
    if (_isPregnancyMode) {
      final week = _pregnancyAnalytics['currentWeek'] as int? ?? 20;
      final trimester = _pregnancyAnalytics['trimester'] as MaternalTrimester? ?? MaternalTrimester.second;
      syncData = _service.getMaternalSmartWatchSync(week, trimester);
    } else {
      final phase = _cycleAnalytics['phase'] as FeminaPhase? ?? FeminaPhase.menstrual;
      syncData = _service.getFeminaSmartWatchSync(phase);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.watch_rounded, color: Color(0xFF38BDF8), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SmartWatch Vitals & Telemetry', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        Text('Real-time sensor sync • Basal Body Temperature', style: TextStyle(color: Colors.white60, fontSize: 11), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text('LIVE SYNC', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Skin Temp / BBT',
                      '${syncData.skinTemperatureOffsetCelsius >= 0 ? '+' : ''}${syncData.skinTemperatureOffsetCelsius.toStringAsFixed(2)}°C',
                      'Biphasic shift',
                      const Color(0xFFF43F5E),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      'Resting HR',
                      '${syncData.restingHeartRateBpm} bpm',
                      'Plasma adapted',
                      const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Heart Rate Var.',
                      '${syncData.heartRateVariabilityMs} ms',
                      'Autonomic balance',
                      const Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      'Blood Oxygen',
                      '${syncData.bloodOxygenSpo2}%',
                      'Optimal SpO2',
                      const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2234),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C3955)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        syncData.biometricInsight,
                        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildMetricTile(String label, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }


  void _openPregnancySettingsDialog() {
    DateTime selectedDate = _service.pregnancyLmp ?? DateTime.now().subtract(const Duration(days: 140));

    showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 300)),
      lastDate: DateTime.now(),
      helpText: 'Select Last Menstrual Period (LMP) Date',
    ).then((picked) async {
      if (picked != null) {
        await _service.setPregnancyLmp(picked);
        if (!mounted) return;
        setState(() {
          _refreshAnalytics();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pregnancy timeline updated successfully! 🤰'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Build Main UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0D14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF43F5E))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 14),
              _buildModeSwitcher(),
              const SizedBox(height: 14),
              _buildQuickActionButtons(),
              const SizedBox(height: 14),
              _buildCategoryTabBar(),
              const SizedBox(height: 16),
              if (!_isPregnancyMode) ...[
                if (_selectedCategory == 'All' || _selectedCategory == 'Overview') ...[
                  _buildFeminaHeroDial(),
                  const SizedBox(height: 16),
                  _buildSymptomLoggerCard(),
                  const SizedBox(height: 16),
                  _buildCycleRegularityAdvisor(),
                  const SizedBox(height: 16),
                ],
                if (_selectedCategory == 'All' || _selectedCategory == 'Routine') ...[
                  _buildChronoCareTimeline(),
                  const SizedBox(height: 16),
                  _buildSleepSanctuaryCard(),
                  const SizedBox(height: 16),
                ],
                if (_selectedCategory == 'All' || _selectedCategory == 'Diet & Meds') ...[
                  _buildFruitTherapyCard(),
                  const SizedBox(height: 16),
                  _buildMedicationScheduleCard(),
                  const SizedBox(height: 16),
                  _buildHomeRemediesCard(),
                  const SizedBox(height: 16),
                ],
                if (_selectedCategory == 'All' || _selectedCategory == 'Yoga Poses') ...[
                  _buildRestorativeAsanasCard(),
                  const SizedBox(height: 16),
                ],
              ] else ...[
                if (_selectedCategory == 'All' || _selectedCategory == 'Milestones') ...[
                  _buildMaternalProgressCard(),
                  const SizedBox(height: 16),
                  _buildDoctorChecklistCard(),
                  const SizedBox(height: 16),
                ],
                if (_selectedCategory == 'All' || _selectedCategory == 'Routine') ...[
                  _buildChronoCareTimeline(),
                  const SizedBox(height: 16),
                  _buildMaternalSleepSanctuaryCard(),
                  const SizedBox(height: 16),
                ],
                if (_selectedCategory == 'All' || _selectedCategory == 'Diet & Meds') ...[
                  _buildMaternalFruitSafetyCard(),
                  const SizedBox(height: 16),
                  _buildMedicationScheduleCard(),
                  const SizedBox(height: 16),
                  _buildMaternalHomeRemediesCard(),
                  const SizedBox(height: 16),
                ],
                if (_selectedCategory == 'All' || _selectedCategory == 'Scans & Kicks') ...[
                  _buildKickCounterCard(),
                  const SizedBox(height: 16),
                  _buildClinicalScansRoadmap(),
                  const SizedBox(height: 16),
                ],
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isPregnancyMode
                        ? [const Color(0xFF38BDF8), const Color(0xFF818CF8)]
                        : [const Color(0xFFF43F5E), const Color(0xFFEC4899)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPregnancyMode ? Icons.pregnant_woman_rounded : Icons.spa_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _isPregnancyMode ? 'MaternalCare™' : 'FeminaCycle™',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white70),
          onPressed: _isPregnancyMode ? _openPregnancySettingsDialog : null,
          tooltip: _isPregnancyMode ? 'Configure Pregnancy (LMP/EDD)' : null,
        ),
      ],
    );
  }


  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleMode(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: !_isPregnancyMode
                      ? const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFEC4899)])
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '🌸 Periods & Cycles',
                      style: TextStyle(
                        color: !_isPregnancyMode ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleMode(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  gradient: _isPregnancyMode
                      ? const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF6366F1)])
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '🤰 9-Month Pregnancy',
                      style: TextStyle(
                        color: _isPregnancyMode ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildQuickActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionChip(
            icon: Icons.favorite_rounded,
            color: const Color(0xFFF43F5E),
            label: 'Partner Sync',
            onTap: _openPartnerGuideSheet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionChip(
            icon: Icons.alarm_rounded,
            color: const Color(0xFF38BDF8),
            label: 'Reminders',
            onTap: _openRemindersSheet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionChip(
            icon: Icons.watch_rounded,
            color: const Color(0xFF10B981),
            label: 'Watch Sync',
            onTap: _openWatchSyncSheet,
          ),
        ),
      ],
    );
  }


  Widget _buildActionChip({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabBar() {
    final categories = _isPregnancyMode
        ? const [
            {'id': 'All', 'label': 'All Sections', 'icon': Icons.grid_view_rounded},
            {'id': 'Milestones', 'label': 'Baby Milestones', 'icon': Icons.child_care_rounded},
            {'id': 'Routine', 'label': '24h Care Routine', 'icon': Icons.schedule_rounded},
            {'id': 'Diet & Meds', 'label': 'Diet & Safety', 'icon': Icons.restaurant_rounded},
            {'id': 'Scans & Kicks', 'label': 'Scans & Kick Counter', 'icon': Icons.medical_services_rounded},
          ]
        : const [
            {'id': 'All', 'label': 'All Sections', 'icon': Icons.grid_view_rounded},
            {'id': 'Overview', 'label': 'Cycle Status', 'icon': Icons.auto_awesome_rounded},
            {'id': 'Routine', 'label': '24h Routine', 'icon': Icons.schedule_rounded},
            {'id': 'Diet & Meds', 'label': 'Diet & Care', 'icon': Icons.eco_rounded},
            {'id': 'Yoga Poses', 'label': 'Restorative Yoga', 'icon': Icons.self_improvement_rounded},
          ];

    final activeColor = _isPregnancyMode ? const Color(0xFF38BDF8) : const Color(0xFFF43F5E);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final id = cat['id'] as String;
          final label = cat['label'] as String;
          final icon = cat['icon'] as IconData;
          final isSelected = _selectedCategory == id;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: 0.2) : const Color(0xFF131722),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? activeColor : const Color(0xFF22293D),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: isSelected ? activeColor : Colors.white60),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Femina Hero Dial
  // ---------------------------------------------------------------------------

  Widget _buildFeminaHeroDial() {
    final cycleDay = _cycleAnalytics['currentCycleDay'] as int? ?? 1;
    final phaseName = _cycleAnalytics['phaseName'] as String? ?? 'Menstrual Phase';
    final daysUntilNext = _cycleAnalytics['daysUntilNext'] as int? ?? 28;
    final fertility = _cycleAnalytics['fertilityChance'] as String? ?? 'Low';
    final avgLength = _cycleAnalytics['avgLength'] as int? ?? 28;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF43F5E).withValues(alpha: 0.15),
            const Color(0xFF8B5CF6).withValues(alpha: 0.15),
            const Color(0xFF131722),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CYCLE DAY $cycleDay OF $avgLength',
                      style: const TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phaseName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Fertility: $fertility',
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    value: (cycleDay / avgLength).clamp(0.05, 1.0),
                    strokeWidth: 10,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF43F5E)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$daysUntilNext',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const Text('days to period', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // 24-Hour Chrono Care Routine Deck
  // ---------------------------------------------------------------------------

  Widget _buildChronoCareTimeline() {
    List<DailyChronoRoutineStep> routine;
    if (_isPregnancyMode) {
      final week = _pregnancyAnalytics['currentWeek'] as int? ?? 20;
      final trimester = _pregnancyAnalytics['trimester'] as MaternalTrimester? ?? MaternalTrimester.second;
      routine = _service.getMaternalChronoRoutine(week, trimester);
    } else {
      final phase = _cycleAnalytics['phase'] as FeminaPhase? ?? FeminaPhase.menstrual;
      routine = _service.getFeminaChronoRoutine(phase);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '24-Hour Circadian Care Chrono-Rhythm',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Personalized hour-by-hour protocol from wakeup hydration to bedtime sleep.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ...routine.map((step) => _buildChronoStepCard(step)),
        ],
      ),
    );
  }


  Widget _buildChronoStepCard(DailyChronoRoutineStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF283247)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  step.timeSlot,
                  style: const TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            step.guidance,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🥗 Action: ', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  step.nutritionOrAction,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          if (step.medicineOrSupplements.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💊 Medicine: ', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    step.medicineOrSupplements.join(' • '),
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Fruit Therapy & Superfoods
  // ---------------------------------------------------------------------------

  Widget _buildFruitTherapyCard() {
    final phase = _cycleAnalytics['phase'] as FeminaPhase? ?? FeminaPhase.menstrual;
    final guide = _service.getFeminaFruitTherapy(phase);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.apple_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Fruit Therapy & Seed Cycling', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(guide.dailyFruitRule, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          ...guide.recommendedFruits.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${f.name} (${f.hindiName})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        Text(f.timing, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(f.benefits, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              )),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Sleep Sanctuary
  // ---------------------------------------------------------------------------

  Widget _buildSleepSanctuaryCard() {
    final phase = _cycleAnalytics['phase'] as FeminaPhase? ?? FeminaPhase.menstrual;
    final protocol = _service.getFeminaSleepProtocol(phase);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime_rounded, color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Sleep Sanctuary Protocol', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Target: ${protocol.targetSleepHours}', style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('🛌 Posture: ${protocol.optimalPosture}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text('🛋️ Pillow Setup: ${protocol.pillowSetup}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('💡 Circadian Tip: ${protocol.circadianTip}', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
          ),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Home Remedies & Cramp Relief
  // ---------------------------------------------------------------------------

  Widget _buildHomeRemediesCard() {
    final phase = _cycleAnalytics['phase'] as FeminaPhase? ?? FeminaPhase.menstrual;
    final remedies = _service.getFeminaHomeRemedies(phase, _activeSymptoms.toList(), _crampSeverity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_pharmacy_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Natural Clinical Home Remedies', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...remedies.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF283247)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Ingredients: ${r.ingredients.join(', ')}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(r.clinicalRationale, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              )),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Restorative Asanas
  // ---------------------------------------------------------------------------

  Widget _buildRestorativeAsanasCard() {
    final phase = _cycleAnalytics['phase'] as FeminaPhase? ?? FeminaPhase.menstrual;
    final asanas = _service.getReliefAsanas(
      phase: phase,
      crampSeverity: _crampSeverity,
      symptoms: _activeSymptoms.toList(),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.self_improvement_rounded, color: Color(0xFFEC4899), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Restorative Asanas for Pain Relief', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...asanas.map((a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${a.name} (${a.sanskritName})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        Text('${a.durationMinutes} mins', style: const TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(a.benefits, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              )),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Symptom Logger Card
  // ---------------------------------------------------------------------------

  Widget _buildSymptomLoggerCard() {
    final symptoms = ['cramps', 'bloating', 'fatigue', 'mood_swings', 'headache', 'backache'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: Color(0xFFF43F5E), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('1-Tap Daily Symptom & Flow Logger', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Flow Intensity:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: FeminaFlow.values.map((flow) {
                final isSelected = _selectedFlow == flow;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFlow = flow),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF43F5E) : const Color(0xFF1A1F2C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? const Color(0xFFF43F5E) : const Color(0xFF2E384D)),
                    ),
                    child: Text(
                      flow.name.toUpperCase(),
                      style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('Cramp Severity (0 - 5):', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Text('$_crampSeverity / 5', style: const TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          Slider(
            value: _crampSeverity.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            activeColor: const Color(0xFFF43F5E),
            inactiveColor: Colors.white24,
            onChanged: (v) => setState(() => _crampSeverity = v.toInt()),
          ),
          const SizedBox(height: 10),
          const Text('Active Symptoms:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: symptoms.map((sym) {
              final isSelected = _activeSymptoms.contains(sym);
              return FilterChip(
                label: Text(sym.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                selected: isSelected,
                selectedColor: const Color(0xFFF43F5E),
                backgroundColor: const Color(0xFF1A1F2C),
                checkmarkColor: Colors.white,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _activeSymptoms.add(sym);
                    } else {
                      _activeSymptoms.remove(sym);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text('Current Mood & Mental State:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: ['calm', 'happy', 'irritable', 'anxious', 'low_energy'].map((m) {
              final isSel = _selectedMood == m;
              return ChoiceChip(
                label: Text(m.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: isSel ? Colors.white : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                selected: isSel,
                selectedColor: const Color(0xFFF43F5E),
                backgroundColor: const Color(0xFF1A1F2C),
                onSelected: (val) {
                  if (val) setState(() => _selectedMood = m);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _saveDayLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Daily Log & Refresh Care Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Cycle Regularity Advisor
  // ---------------------------------------------------------------------------

  Widget _buildCycleRegularityAdvisor() {
    final diagnosis = _cycleAnalytics['regularityDiagnosis'] as String? ?? 'Regular Rhythm';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Cycle Regularity & Hormone Advisor', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(diagnosis, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
          const SizedBox(height: 6),
          const Text('• Seed Cycling Phase 1 (Flax + Pumpkin) balances estrogen in days 1-14.', style: TextStyle(color: Colors.white60, fontSize: 11)),
          const Text('• Seed Cycling Phase 2 (Sesame + Sunflower) boosts progesterone in days 15-28.', style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Mode 2: MaternalCare Progress Card
  // ---------------------------------------------------------------------------

  Widget _buildMaternalProgressCard() {
    final week = _pregnancyAnalytics['currentWeek'] as int? ?? 20;
    final dayInWeek = _pregnancyAnalytics['dayInWeek'] as int? ?? 3;
    final daysToDelivery = _pregnancyAnalytics['daysUntilDelivery'] as int? ?? 140;
    final trimesterName = _pregnancyAnalytics['trimesterName'] as String? ?? '2nd Trimester';
    final milestone = _pregnancyAnalytics['milestone'] as MaternalFetalMilestone?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0284C7).withValues(alpha: 0.2),
            const Color(0xFF6366F1).withValues(alpha: 0.15),
            const Color(0xFF131722),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WEEK $week • DAY $dayInWeek', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1)),
                    const SizedBox(height: 2),
                    Text(trimesterName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$daysToDelivery Days Left', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (milestone != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2234),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A3A5A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.child_care_rounded, color: Color(0xFF38BDF8), size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Baby size: ${milestone.fruitAnalogy}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('Weight: ~${milestone.approximateWeightGrams}g • Length: ~${milestone.approximateLengthMm}mm', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Development Highlights:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            ...milestone.developmentHighlights.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                      Expanded(child: Text(h, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Maternal Fruit Safety & Contraindications Card
  // ---------------------------------------------------------------------------

  Widget _buildMaternalFruitSafetyCard() {
    final trimester = _pregnancyAnalytics['trimester'] as MaternalTrimester? ?? MaternalTrimester.second;
    final guide = _service.getMaternalFruitTherapy(trimester);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.apple_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Pregnancy Fruit Safety & Superfoods', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(guide.dailyFruitRule, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          const Text('⚠️ STRICT CONTRAINDICATIONS & AVOID:', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...guide.avoidOrCautionFruits.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF261818),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🚫 ${c.name} (${c.hindiName})', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(c.clinicalReason, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              )),
          const SizedBox(height: 10),
          const Text('🌟 Recommended Superfruits:', style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...guide.recommendedFruits.take(3).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${f.name} (${f.hindiName}): ${f.benefits}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              )),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Maternal Sleep Sanctuary & Posture
  // ---------------------------------------------------------------------------

  Widget _buildMaternalSleepSanctuaryCard() {
    final week = _pregnancyAnalytics['currentWeek'] as int? ?? 20;
    final trimester = _pregnancyAnalytics['trimester'] as MaternalTrimester? ?? MaternalTrimester.second;
    final protocol = _service.getMaternalSleepProtocol(week, trimester);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Maternal Sleep Sanctuary (SOS)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Target: ${protocol.targetSleepHours}', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('🛌 Posture: ${protocol.optimalPosture}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text('🛋️ Pillow Setup: ${protocol.pillowSetup}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E283D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('🚨 Critical: ${protocol.circadianTip}', style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 12)),
          ),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Maternal Home Remedies Card
  // ---------------------------------------------------------------------------

  Widget _buildMaternalHomeRemediesCard() {
    final trimester = _pregnancyAnalytics['trimester'] as MaternalTrimester? ?? MaternalTrimester.second;
    final remedies = _service.getMaternalHomeRemedies(trimester);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.healing_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Pregnancy Discomfort Home Remedies', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...remedies.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ${r.symptom}: ${r.title}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(r.clinicalRationale, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              )),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Doctor's Orders Compliance Checklist
  // ---------------------------------------------------------------------------

  Widget _buildDoctorChecklistCard() {
    final instructions = _service.doctorInstructions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: Color(0xFF38BDF8), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Daily Doctor\'s Orders & Compliance', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...instructions.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: item.isCompletedToday ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF283247)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: item.isCompletedToday,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (_) async {
                            await _service.toggleDoctorInstruction(item.id);
                            if (!mounted) return;
                            setState(() {});
                          },
                        ),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: item.isCompletedToday ? const Color(0xFF10B981) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('👶 Positive Impact: ${item.positiveImpact}', style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 11)),
                          const SizedBox(height: 2),
                          Text('⚠️ Risk if Skipped: ${item.skippedRisk}', style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11)),
                          if (item.timingTip != null) ...[
                            const SizedBox(height: 2),
                            Text('⏰ Timing: ${item.timingTip}', style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Fetal Kick Counter Tool
  // ---------------------------------------------------------------------------

  Widget _buildKickCounterCard() {
    final min = _kickSecondsElapsed ~/ 60;
    final sec = _kickSecondsElapsed % 60;
    final timeStr = '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Fetal Kick Counter', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E283D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Timer: $timeStr', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _incrementKick,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF6366F1)]),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.child_care_rounded, color: Colors.white, size: 28),
                  Text('$_currentKickCount', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const Text('TAP KICK', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Target: 10 kicks in 2 hours after meals.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _toggleKickTimer,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(_isKickTimerActive ? 'Pause Timer' : 'Start Timer', style: const TextStyle(color: Color(0xFF38BDF8))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentKickCount > 0 ? _saveKickSession : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Clinical Scans Roadmap
  // ---------------------------------------------------------------------------

  Widget _buildClinicalScansRoadmap() {
    final week = _pregnancyAnalytics['currentWeek'] as int? ?? 20;

    final scans = [
      {'name': 'NT Scan & Dual Marker', 'weeks': 'Weeks 11 - 14', 'purpose': 'Chromosomal screen'},
      {'name': 'Level II Anomaly Ultrasound', 'weeks': 'Weeks 18 - 22', 'purpose': 'Complete organ anatomy audit'},
      {'name': 'Glucose Challenge (OGTT)', 'weeks': 'Weeks 24 - 28', 'purpose': 'Gestational diabetes check'},
      {'name': 'Growth & Umbilical Doppler', 'weeks': 'Weeks 32 - 36', 'purpose': 'Placental blood flow & weight'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22293D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_services_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sonography & Clinical Scans Roadmap',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                ),
                child: Text('Week $week', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...scans.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(s['purpose']!, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(s['weeks']!, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Medication & Supplement Schedule Card
  // ---------------------------------------------------------------------------

  Widget _buildMedicationScheduleCard() {
    List<MedicationTimingRule> schedule;
    if (_isPregnancyMode) {
      final week = _pregnancyAnalytics['currentWeek'] as int? ?? 20;
      final trimester = _pregnancyAnalytics['trimester'] as MaternalTrimester? ?? MaternalTrimester.second;
      schedule = _service.getMaternalMedicationSchedule(week, trimester);
    } else {
      final phase = _cycleAnalytics['phase'] as FeminaPhase? ?? FeminaPhase.menstrual;
      schedule = _service.getFeminaMedicationSchedule(phase);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.medication_rounded, color: Color(0xFF38BDF8), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Clinical Medication & Supplement Schedule',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Doctor-backed timing rules, food interactions, and safety alerts.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...schedule.map((med) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF283247)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            med.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            med.idealTime.split('(').first.trim(),
                            style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '⏰ ${med.idealTime}',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '🎯 Purpose: ${med.clinicalPurpose}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1C1C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              med.interactionWarning,
                              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '💡 Timing Tip: ${med.timingTip}',
                      style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 11),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

}
