import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported Menstrual Cycle Phases
enum FeminaPhase {
  menstrual,
  follicular,
  ovulatory,
  luteal,
}

/// Menstrual Flow Intensity
enum FeminaFlow {
  none,
  spotting,
  light,
  medium,
  heavy,
}

/// Pregnancy Trimester
enum MaternalTrimester {
  first,
  second,
  third,
  postpartum,
}

/// A logged day of menstrual symptoms and flow
class FeminaDayLog {
  final String date; // YYYY-MM-DD
  final FeminaFlow flow;
  final int crampSeverity; // 0 to 5
  final List<String> symptoms;
  final String mood;
  final String? notes;

  const FeminaDayLog({
    required this.date,
    required this.flow,
    required this.crampSeverity,
    required this.symptoms,
    required this.mood,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'flow': flow.name,
        'crampSeverity': crampSeverity,
        'symptoms': symptoms,
        'mood': mood,
        'notes': notes,
      };

  factory FeminaDayLog.fromJson(Map<String, dynamic> json) {
    return FeminaDayLog(
      date: json['date'] as String? ?? '',
      flow: FeminaFlow.values.firstWhere(
        (f) => f.name == json['flow'],
        orElse: () => FeminaFlow.none,
      ),
      crampSeverity: (json['crampSeverity'] as num?)?.toInt() ?? 0,
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      mood: json['mood'] as String? ?? 'calm',
      notes: json['notes'] as String?,
    );
  }
}

/// Restorative Yoga Asana for Pain Relief
class FeminaReliefAsana {
  final String name;
  final String sanskritName;
  final int durationMinutes;
  final String benefits;
  final List<String> steps;
  final String caution;

  const FeminaReliefAsana({
    required this.name,
    required this.sanskritName,
    required this.durationMinutes,
    required this.benefits,
    required this.steps,
    required this.caution,
  });
}

/// Cycle Nutrition Prescription
class FeminaNutritionPlan {
  final String focus;
  final List<String> keyNutrients;
  final List<String> recommendedFoods;
  final List<String> avoidFoods;
  final String? seedCyclingTip;
  final String rationale;

  const FeminaNutritionPlan({
    required this.focus,
    required this.keyNutrients,
    required this.recommendedFoods,
    required this.avoidFoods,
    this.seedCyclingTip,
    required this.rationale,
  });
}

/// Fetal Development Milestone
class MaternalFetalMilestone {
  final int week;
  final String fruitAnalogy;
  final int approximateWeightGrams;
  final int approximateLengthMm;
  final List<String> developmentHighlights;
  final List<String> motherBodyChanges;

  const MaternalFetalMilestone({
    required this.week,
    required this.fruitAnalogy,
    required this.approximateWeightGrams,
    required this.approximateLengthMm,
    required this.developmentHighlights,
    required this.motherBodyChanges,
  });
}

/// Doctor's Prescribed Instruction with Impact Analysis
class MaternalDoctorInstruction {
  final String id;
  final String category; // 'medication' | 'diet' | 'activity' | 'caution'
  final String title;
  final String details;
  final String frequency;
  final bool isCompletedToday;
  final String positiveImpact;
  final String skippedRisk;
  final String? timingTip;

  const MaternalDoctorInstruction({
    required this.id,
    required this.category,
    required this.title,
    required this.details,
    required this.frequency,
    this.isCompletedToday = false,
    required this.positiveImpact,
    required this.skippedRisk,
    this.timingTip,
  });

  MaternalDoctorInstruction copyWith({bool? isCompletedToday}) {
    return MaternalDoctorInstruction(
      id: id,
      category: category,
      title: title,
      details: details,
      frequency: frequency,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      positiveImpact: positiveImpact,
      skippedRisk: skippedRisk,
      timingTip: timingTip,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'details': details,
        'frequency': frequency,
        'isCompletedToday': isCompletedToday,
        'positiveImpact': positiveImpact,
        'skippedRisk': skippedRisk,
        'timingTip': timingTip,
      };

  factory MaternalDoctorInstruction.fromJson(Map<String, dynamic> json) {
    return MaternalDoctorInstruction(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'medication',
      title: json['title'] as String? ?? '',
      details: json['details'] as String? ?? '',
      frequency: json['frequency'] as String? ?? 'daily',
      isCompletedToday: json['isCompletedToday'] as bool? ?? false,
      positiveImpact: json['positiveImpact'] as String? ?? '',
      skippedRisk: json['skippedRisk'] as String? ?? '',
      timingTip: json['timingTip'] as String?,
    );
  }
}

/// Fetal Kick Count Record
class MaternalKickSession {
  final DateTime timestamp;
  final int kickCount;
  final int durationSeconds;

  const MaternalKickSession({
    required this.timestamp,
    required this.kickCount,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'kickCount': kickCount,
        'durationSeconds': durationSeconds,
      };

  factory MaternalKickSession.fromJson(Map<String, dynamic> json) {
    return MaternalKickSession(
      timestamp: DateTime.parse(
          json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      kickCount: (json['kickCount'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Daily Chrono-Routine Step (Morning to Bedtime)
class DailyChronoRoutineStep {
  final String id;
  final String timeSlot;
  final String periodOfDay;
  final String title;
  final String guidance;
  final String nutritionOrAction;
  final String sleepPostureOrTip;
  final List<String> medicineOrSupplements;

  const DailyChronoRoutineStep({
    required this.id,
    required this.timeSlot,
    required this.periodOfDay,
    required this.title,
    required this.guidance,
    required this.nutritionOrAction,
    required this.sleepPostureOrTip,
    this.medicineOrSupplements = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timeSlot': timeSlot,
        'periodOfDay': periodOfDay,
        'title': title,
        'guidance': guidance,
        'nutritionOrAction': nutritionOrAction,
        'sleepPostureOrTip': sleepPostureOrTip,
        'medicineOrSupplements': medicineOrSupplements,
      };

  factory DailyChronoRoutineStep.fromJson(Map<String, dynamic> json) =>
      DailyChronoRoutineStep(
        id: json['id'] as String? ?? '',
        timeSlot: json['timeSlot'] as String? ?? '',
        periodOfDay: json['periodOfDay'] as String? ?? 'morning_wake',
        title: json['title'] as String? ?? '',
        guidance: json['guidance'] as String? ?? '',
        nutritionOrAction: json['nutritionOrAction'] as String? ?? '',
        sleepPostureOrTip: json['sleepPostureOrTip'] as String? ?? '',
        medicineOrSupplements: (json['medicineOrSupplements'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

/// Fruit Detail
class FruitDetail {
  final String name;
  final String hindiName;
  final String benefits;
  final String nutrientKey;
  final String timing;
  final String bestConsumedWith;

  const FruitDetail({
    required this.name,
    required this.hindiName,
    required this.benefits,
    required this.nutrientKey,
    required this.timing,
    required this.bestConsumedWith,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'hindiName': hindiName,
        'benefits': benefits,
        'nutrientKey': nutrientKey,
        'timing': timing,
        'bestConsumedWith': bestConsumedWith,
      };

  factory FruitDetail.fromJson(Map<String, dynamic> json) => FruitDetail(
        name: json['name'] as String? ?? '',
        hindiName: json['hindiName'] as String? ?? '',
        benefits: json['benefits'] as String? ?? '',
        nutrientKey: json['nutrientKey'] as String? ?? '',
        timing: json['timing'] as String? ?? '',
        bestConsumedWith: json['bestConsumedWith'] as String? ?? '',
      );
}

/// Fruit Contraindication
class FruitContraindication {
  final String name;
  final String hindiName;
  final String riskLevel; // 'strict_avoid' | 'caution'
  final String clinicalReason;
  final String scientificMechanism;

  const FruitContraindication({
    required this.name,
    required this.hindiName,
    required this.riskLevel,
    required this.clinicalReason,
    required this.scientificMechanism,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'hindiName': hindiName,
        'riskLevel': riskLevel,
        'clinicalReason': clinicalReason,
        'scientificMechanism': scientificMechanism,
      };

  factory FruitContraindication.fromJson(Map<String, dynamic> json) =>
      FruitContraindication(
        name: json['name'] as String? ?? '',
        hindiName: json['hindiName'] as String? ?? '',
        riskLevel: json['riskLevel'] as String? ?? 'caution',
        clinicalReason: json['clinicalReason'] as String? ?? '',
        scientificMechanism: json['scientificMechanism'] as String? ?? '',
      );
}

/// Fruit Therapy Guide
class FruitTherapyGuide {
  final List<FruitDetail> recommendedFruits;
  final List<FruitContraindication> avoidOrCautionFruits;
  final String dailyFruitRule;

  const FruitTherapyGuide({
    required this.recommendedFruits,
    required this.avoidOrCautionFruits,
    required this.dailyFruitRule,
  });
}

/// Symptom Home Remedy
class SymptomHomeRemedy {
  final String symptom;
  final String title;
  final List<String> ingredients;
  final String preparation;
  final String clinicalRationale;
  final String timing;
  final String cautions;

  const SymptomHomeRemedy({
    required this.symptom,
    required this.title,
    required this.ingredients,
    required this.preparation,
    required this.clinicalRationale,
    required this.timing,
    required this.cautions,
  });

  Map<String, dynamic> toJson() => {
        'symptom': symptom,
        'title': title,
        'ingredients': ingredients,
        'preparation': preparation,
        'clinicalRationale': clinicalRationale,
        'timing': timing,
        'cautions': cautions,
      };

  factory SymptomHomeRemedy.fromJson(Map<String, dynamic> json) =>
      SymptomHomeRemedy(
        symptom: json['symptom'] as String? ?? '',
        title: json['title'] as String? ?? '',
        ingredients: (json['ingredients'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        preparation: json['preparation'] as String? ?? '',
        clinicalRationale: json['clinicalRationale'] as String? ?? '',
        timing: json['timing'] as String? ?? '',
        cautions: json['cautions'] as String? ?? '',
      );
}

/// Sleep Sanctuary Protocol
class SleepSanctuaryProtocol {
  final String targetSleepHours;
  final String optimalPosture;
  final String pillowSetup;
  final String circadianTip;
  final List<String> windDownRitual;
  final String hormonalContext;

  const SleepSanctuaryProtocol({
    required this.targetSleepHours,
    required this.optimalPosture,
    required this.pillowSetup,
    required this.circadianTip,
    required this.windDownRitual,
    required this.hormonalContext,
  });
}

/// Medication Timing Rule
class MedicationTimingRule {
  final String name;
  final String dosageExample;
  final String idealTime;
  final String clinicalPurpose;
  final String interactionWarning;
  final String timingTip;
  final bool isPregnancySafe;

  const MedicationTimingRule({
    required this.name,
    required this.dosageExample,
    required this.idealTime,
    required this.clinicalPurpose,
    required this.interactionWarning,
    required this.timingTip,
    required this.isPregnancySafe,
  });
}

/// Partner Empathy & Guidance Card
class PartnerEmpathyGuide {
  final String phaseOrTrimester;
  final String emotionalContext;
  final String whatSheNeedsMost;
  final List<String> dosList;
  final List<String> dontsList;
  final List<Map<String, String>> suggestedGiftsAndCare;
  final String readyToShareMessage;

  const PartnerEmpathyGuide({
    required this.phaseOrTrimester,
    required this.emotionalContext,
    required this.whatSheNeedsMost,
    required this.dosList,
    required this.dontsList,
    required this.suggestedGiftsAndCare,
    required this.readyToShareMessage,
  });
}

/// Care Reminder Item
class CareReminderItem {
  final String id;
  final String category; // 'medication' | 'meal' | 'hydration' | 'checkup' | 'doctor_visit' | 'rest'
  final String title;
  final String timeSlot;
  final bool isEnabled;
  final bool repeatDaily;
  final String? notes;

  const CareReminderItem({
    required this.id,
    required this.category,
    required this.title,
    required this.timeSlot,
    this.isEnabled = true,
    this.repeatDaily = true,
    this.notes,
  });

  CareReminderItem copyWith({
    String? id,
    String? category,
    String? title,
    String? timeSlot,
    bool? isEnabled,
    bool? repeatDaily,
    String? notes,
  }) {
    return CareReminderItem(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      timeSlot: timeSlot ?? this.timeSlot,
      isEnabled: isEnabled ?? this.isEnabled,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'timeSlot': timeSlot,
        'isEnabled': isEnabled,
        'repeatDaily': repeatDaily,
        'notes': notes,
      };

  factory CareReminderItem.fromJson(Map<String, dynamic> json) =>
      CareReminderItem(
        id: json['id'] as String? ?? '',
        category: json['category'] as String? ?? 'medication',
        title: json['title'] as String? ?? '',
        timeSlot: json['timeSlot'] as String? ?? '',
        isEnabled: json['isEnabled'] as bool? ?? true,
        repeatDaily: json['repeatDaily'] as bool? ?? true,
        notes: json['notes'] as String?,
      );
}

/// Smart Watch Biometric Telemetry & Sync
class SmartWatchBiometricSync {
  final int restingHeartRateBpm;
  final double skinTemperatureOffsetCelsius;
  final int heartRateVariabilityMs;
  final int bloodOxygenSpo2;
  final double sleepDurationHours;
  final int deepSleepMinutes;
  final bool biphasicOvulationConfirmed;
  final String biometricInsight;

  const SmartWatchBiometricSync({
    required this.restingHeartRateBpm,
    required this.skinTemperatureOffsetCelsius,
    required this.heartRateVariabilityMs,
    required this.bloodOxygenSpo2,
    required this.sleepDurationHours,
    required this.deepSleepMinutes,
    required this.biphasicOvulationConfirmed,
    required this.biometricInsight,
  });
}

/// Singleton Service for Women's Health & Maternal Care
class WomensHealthService {
  WomensHealthService._();
  static final WomensHealthService instance = WomensHealthService._();

  static const _kCycleHistoryKey = 'vyra_femina_cycle_history';
  static const _kDayLogsKey = 'vyra_femina_day_logs';
  static const _kPregnancyLmpKey = 'vyra_maternal_lmp';
  static const _kPregnancyEddKey = 'vyra_maternal_edd';
  static const _kDoctorChecklistKey = 'vyra_maternal_doctor_checklist';
  static const _kKickSessionsKey = 'vyra_maternal_kick_sessions';
  static const _kIsPregnancyModeKey = 'vyra_womens_health_is_pregnancy_mode';
  static const _kRemindersKey = 'vyra_womens_health_reminders';

  List<String> _cycleStartDates = [];
  Map<String, FeminaDayLog> _dayLogs = {};
  DateTime? _pregnancyLmp;
  DateTime? _pregnancyEdd;
  List<MaternalDoctorInstruction> _doctorInstructions = [];
  List<MaternalKickSession> _kickSessions = [];
  List<CareReminderItem> _customReminders = [];
  bool _isPregnancyMode = false;
  bool _isLoaded = false;

  bool get isPregnancyMode => _isPregnancyMode;
  DateTime? get pregnancyLmp => _pregnancyLmp;
  DateTime? get pregnancyEdd => _pregnancyEdd;
  List<MaternalDoctorInstruction> get doctorInstructions => _doctorInstructions;
  List<MaternalKickSession> get kickSessions => _kickSessions;
  List<CareReminderItem> get customReminders => _customReminders;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPregnancyMode = prefs.getBool(_kIsPregnancyModeKey) ?? false;
      _cycleStartDates = prefs.getStringList(_kCycleHistoryKey) ?? [];

      final rawLogs = prefs.getString(_kDayLogsKey);
      if (rawLogs != null) {
        final decoded = jsonDecode(rawLogs) as Map<String, dynamic>;
        _dayLogs = decoded.map(
          (k, v) => MapEntry(k, FeminaDayLog.fromJson(v as Map<String, dynamic>)),
        );
      }

      final lmpStr = prefs.getString(_kPregnancyLmpKey);
      if (lmpStr != null) {
        _pregnancyLmp = DateTime.tryParse(lmpStr);
      }

      final eddStr = prefs.getString(_kPregnancyEddKey);
      if (eddStr != null) {
        _pregnancyEdd = DateTime.tryParse(eddStr);
      }

      final rawChecklist = prefs.getString(_kDoctorChecklistKey);
      if (rawChecklist != null) {
        final decoded = jsonDecode(rawChecklist) as List<dynamic>;
        _doctorInstructions = decoded
            .map((e) => MaternalDoctorInstruction.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _doctorInstructions = _buildDefaultDoctorInstructions();
      }

      final rawKicks = prefs.getString(_kKickSessionsKey);
      if (rawKicks != null) {
        final decoded = jsonDecode(rawKicks) as List<dynamic>;
        _kickSessions = decoded
            .map((e) => MaternalKickSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final rawReminders = prefs.getString(_kRemindersKey);
      if (rawReminders != null) {
        final decoded = jsonDecode(rawReminders) as List<dynamic>;
        _customReminders = decoded
            .map((e) => CareReminderItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _customReminders = getDefaultReminders(_isPregnancyMode);
      }

      _isLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[WomensHealthService] init failed: $e');
    }
  }

  Future<void> addCareReminder(CareReminderItem item) async {
    _customReminders.add(item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRemindersKey,
      jsonEncode(_customReminders.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> toggleCareReminder(String id) async {
    _customReminders = _customReminders.map((item) {
      if (item.id == id) {
        return item.copyWith(isEnabled: !item.isEnabled);
      }
      return item;
    }).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRemindersKey,
      jsonEncode(_customReminders.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteCareReminder(String id) async {
    _customReminders.removeWhere((item) => item.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRemindersKey,
      jsonEncode(_customReminders.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> sharePartnerUpdate(String message) async {
    try {
      // ignore: deprecated_member_use
      await Share.share(message, subject: 'VYRA Care Partner Update');
    } catch (e) {
      if (kDebugMode) debugPrint('[WomensHealthService] share error: $e');
    }
  }

  Future<void> setPregnancyMode(bool isPregnancy) async {
    _isPregnancyMode = isPregnancy;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPregnancyModeKey, isPregnancy);
  }

  Future<void> logPeriodStartDate(DateTime date) async {
    final dateStr = _formatDate(date);
    if (!_cycleStartDates.contains(dateStr)) {
      _cycleStartDates.add(dateStr);
      _cycleStartDates.sort((a, b) => b.compareTo(a)); // Descending
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kCycleHistoryKey, _cycleStartDates);
    }
  }

  Future<void> saveDayLog(FeminaDayLog log) async {
    _dayLogs[log.date] = log;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kDayLogsKey,
      jsonEncode(_dayLogs.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  FeminaDayLog? getDayLog(String dateStr) => _dayLogs[dateStr];

  Future<void> setPregnancyLmp(DateTime lmp) async {
    _pregnancyLmp = lmp;
    _pregnancyEdd = lmp.add(const Duration(days: 280));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPregnancyLmpKey, lmp.toIso8601String());
    await prefs.setString(_kPregnancyEddKey, _pregnancyEdd!.toIso8601String());
  }

  Future<void> toggleDoctorInstruction(String id) async {
    _doctorInstructions = _doctorInstructions.map((item) {
      if (item.id == id) {
        return item.copyWith(isCompletedToday: !item.isCompletedToday);
      }
      return item;
    }).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kDoctorChecklistKey,
      jsonEncode(_doctorInstructions.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> recordKickSession(int kicks, int durationSec) async {
    final session = MaternalKickSession(
      timestamp: DateTime.now(),
      kickCount: kicks,
      durationSeconds: durationSec,
    );
    _kickSessions.insert(0, session);
    if (_kickSessions.length > 50) {
      _kickSessions = _kickSessions.sublist(0, 50);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKickSessionsKey,
      jsonEncode(_kickSessions.map((e) => e.toJson()).toList()),
    );
  }

  // ---------------------------------------------------------------------------
  // Calculations: Cycle Analytics
  // ---------------------------------------------------------------------------

  /// Calculates cycle day, phase, and predictions.
  Map<String, dynamic> computeCycleAnalytics({DateTime? referenceDate}) {
    final today = referenceDate ?? DateTime.now();

    DateTime latestStart;
    int avgLength = 28;

    if (_cycleStartDates.isEmpty) {
      latestStart = today.subtract(const Duration(days: 14));
    } else {
      latestStart = DateTime.tryParse(_cycleStartDates.first) ??
          today.subtract(const Duration(days: 14));

      if (_cycleStartDates.length >= 2) {
        final diffs = <int>[];
        for (int i = 0; i < _cycleStartDates.length - 1; i++) {
          final d1 = DateTime.tryParse(_cycleStartDates[i]);
          final d2 = DateTime.tryParse(_cycleStartDates[i + 1]);
          if (d1 != null && d2 != null) {
            final days = d1.difference(d2).inDays;
            if (days >= 20 && days <= 55) {
              diffs.add(days);
            }
          }
        }
        if (diffs.isNotEmpty) {
          avgLength = (diffs.reduce((a, b) => a + b) / diffs.length).round();
        }
      }
    }

    final elapsed = today.difference(latestStart).inDays;
    final currentCycleDay = (elapsed % avgLength) + 1;
    final daysUntilNext = math.max(1, avgLength - currentCycleDay + 1);

    final completedPeriods = elapsed ~/ avgLength;
    final nextPeriodDate = latestStart.add(Duration(days: (completedPeriods + 1) * avgLength));
    final ovulationDate = nextPeriodDate.subtract(const Duration(days: 14));
    final fertileStart = ovulationDate.subtract(const Duration(days: 5));
    final fertileEnd = ovulationDate.add(const Duration(days: 1));

    FeminaPhase phase;
    String phaseName;
    String fertilityChance;

    if (currentCycleDay <= 5) {
      phase = FeminaPhase.menstrual;
      phaseName = 'Menstrual Phase';
      fertilityChance = 'Low (Menstrual)';
    } else if (currentCycleDay <= 12) {
      phase = FeminaPhase.follicular;
      phaseName = 'Follicular Phase';
      fertilityChance = currentCycleDay >= 10 ? 'Medium' : 'Low';
    } else if (currentCycleDay <= 16) {
      phase = FeminaPhase.ovulatory;
      phaseName = 'Ovulatory Phase';
      fertilityChance = currentCycleDay == 14 ? 'Peak Ovulation' : 'High';
    } else {
      phase = FeminaPhase.luteal;
      phaseName = 'Luteal Phase';
      fertilityChance = 'Low (Post-Ovulation)';
    }

    String regularityDiagnosis = 'Regular Healthy Rhythm (25-35 Days)';
    if (avgLength > 35) {
      regularityDiagnosis = 'Extended Cycle (>35 Days) • Delayed Ovulation Risk';
    } else if (avgLength < 21) {
      regularityDiagnosis = 'Short Cycle (<21 Days) • Short Luteal Phase Signal';
    }

    return {
      'currentCycleDay': currentCycleDay,
      'phase': phase,
      'phaseName': phaseName,
      'daysUntilNext': daysUntilNext,
      'nextPeriodDate': nextPeriodDate,
      'ovulationDate': ovulationDate,
      'fertileStart': fertileStart,
      'fertileEnd': fertileEnd,
      'fertilityChance': fertilityChance,
      'avgLength': avgLength,
      'regularityDiagnosis': regularityDiagnosis,
    };
  }

  // ---------------------------------------------------------------------------
  // Calculations: Pregnancy Analytics
  // ---------------------------------------------------------------------------

  Map<String, dynamic> computePregnancyAnalytics({DateTime? referenceDate}) {
    final today = referenceDate ?? DateTime.now();
    final lmp = _pregnancyLmp ?? today.subtract(const Duration(days: 140));
    final edd = _pregnancyEdd ?? lmp.add(const Duration(days: 280));

    final totalDays = today.difference(lmp).inDays.clamp(1, 294);
    final currentWeek = ((totalDays / 7) + 1).floor().clamp(1, 42);
    final dayInWeek = (totalDays % 7) + 1;
    final daysUntilDelivery = math.max(0, edd.difference(today).inDays);

    MaternalTrimester trimester;
    String trimesterName;

    if (currentWeek <= 12) {
      trimester = MaternalTrimester.first;
      trimesterName = '1st Trimester • Organogenesis';
    } else if (currentWeek <= 27) {
      trimester = MaternalTrimester.second;
      trimesterName = '2nd Trimester • Golden Growth';
    } else if (currentWeek <= 40) {
      trimester = MaternalTrimester.third;
      trimesterName = '3rd Trimester • Final Maturation';
    } else {
      trimester = MaternalTrimester.postpartum;
      trimesterName = 'Full Term • Ready for Birth';
    }

    final milestone = _getMilestoneForWeek(currentWeek);

    return {
      'currentWeek': currentWeek,
      'dayInWeek': dayInWeek,
      'totalDays': totalDays,
      'trimester': trimester,
      'trimesterName': trimesterName,
      'estimatedDueDate': edd,
      'daysUntilDelivery': daysUntilDelivery,
      'milestone': milestone,
    };
  }

  // ---------------------------------------------------------------------------
  // Relief Asanas & Dietary Prescriptions
  // ---------------------------------------------------------------------------

  List<FeminaReliefAsana> getReliefAsanas({
    required FeminaPhase phase,
    required int crampSeverity,
    required List<String> symptoms,
  }) {
    final asanas = <FeminaReliefAsana>[];

    if (crampSeverity >= 3 || symptoms.contains('cramps')) {
      asanas.add(const FeminaReliefAsana(
        name: "Child's Pose",
        sanskritName: 'Balasana',
        durationMinutes: 5,
        benefits: 'Pelvic floor tightness release karta hai aur uterine spasm pain kam karta hai.',
        steps: [
          'Ghutno ke bal baith kar wide knees karein.',
          'Hips ko peeche heels par rest karein aur aage forehead zameen par lagayein.',
          'Arms aage extend karein aur deep breathing karein.',
        ],
        caution: 'Pet par bilkul pressure na dalein; knees wide rakhein.',
      ));

      asanas.add(const FeminaReliefAsana(
        name: 'Reclined Bound Angle Pose',
        sanskritName: 'Supta Baddha Konasana',
        durationMinutes: 7,
        benefits: 'Lower belly ko stretch aur relax karta hai, pelvic blood flow improve karta hai.',
        steps: [
          'Peeth ke bal let kar dono feet ke soles touch karein.',
          'Ghutno ko butterfly ki tarah dono taraf open karein.',
          'Ek haath heart aur ek belly par rakh kar slow deep breaths lein.',
        ],
        caution: 'Agar inner thighs me strain ho toh knees ke neeche pillow rakhein.',
      ));
    }

    if (symptoms.contains('backache') || phase == FeminaPhase.menstrual) {
      asanas.add(const FeminaReliefAsana(
        name: 'Cat-Cow Pose',
        sanskritName: 'Marjaryasana-Bitilasana',
        durationMinutes: 4,
        benefits: 'Spine aur sacrum bone ko gently mobilize karke lower back pain door karta hai.',
        steps: [
          'Hands aur knees par table-top position me aayein.',
          'Inhale karte hue chest open karein aur gentle arch banayein (Cow).',
          'Exhale karte hue spine ko round karke chin chest ki taraf layein (Cat).',
        ],
        caution: 'Jhatka na dein; saans ke sath slow rhythm me move karein.',
      ));
    }

    if (symptoms.contains('bloating') || symptoms.contains('fatigue') || phase == FeminaPhase.luteal) {
      asanas.add(const FeminaReliefAsana(
        name: 'Legs Up The Wall',
        sanskritName: 'Viparita Karani',
        durationMinutes: 8,
        benefits: 'Legs aur pelvic area se excess fluid drain karta hai, bloating aur thakan khatam karta hai.',
        steps: [
          'Deewar ke paas hips ko satayein aur legs seedha deewar par upar rest karein.',
          'Hands ko sides me relax karein aur deep breathing karein.',
        ],
        caution: 'High BP me sar ke neeche pillow support zaroor lein.',
      ));
    }

    if (asanas.isEmpty) {
      asanas.add(const FeminaReliefAsana(
        name: 'Restorative Savasana',
        sanskritName: 'Supported Savasana',
        durationMinutes: 10,
        benefits: 'Body aur mind ko parasympathetic deep healing mode me lata hai.',
        steps: [
          'Peeth ke bal let kar knees ke neeche pillow support rakhein.',
          'Eyes band karke har body part ko conscious relax karein.',
        ],
        caution: 'Room ka temperature normal rakhein.',
      ));
    }

    return asanas;
  }

  FeminaNutritionPlan getNutritionPlan(FeminaPhase phase) {
    switch (phase) {
      case FeminaPhase.menstrual:
        return const FeminaNutritionPlan(
          focus: 'Iron & Magnesium Replenishment + Anti-Spasm',
          keyNutrients: ['Iron', 'Magnesium', 'Zinc', 'Vitamin C'],
          recommendedFoods: [
            'Palak, Methi aur Bathua saag',
            'Roasted Chana aur Gud (Jaggery) — Natural Iron source',
            'Pomegranate (Anaar) aur Kishmish',
            'Pumpkin Seeds (Magnesium cramp relief)',
            'Warm Ginger-Cinnamon water',
          ],
          avoidFoods: ['Chilled iced drinks', 'Excess coffee', 'Salty chips'],
          seedCyclingTip: 'Phase 1: 1 tbsp ground Flax seeds daily for estrogen clearance.',
          rationale: 'Ferritin loss se fatigue aati hai; warm iron-rich Indian diet energy restore karti hai.',
        );
      case FeminaPhase.follicular:
        return const FeminaNutritionPlan(
          focus: 'Lean Protein, Gut Microbiome & High Energy',
          keyNutrients: ['Protein', 'Probiotics', 'Complex Carbs'],
          recommendedFoods: [
            'Sprouted Moong & Kala Chana',
            'Fresh Curd / Dahi aur Chaas with Jeera',
            'Oats, Brown Rice aur Multigrain Roti',
            'Seasonal fresh fruits (Apple, Papaya)',
          ],
          avoidFoods: ['Bakery maida items', 'Deep fried junk'],
          seedCyclingTip: 'Phase 1: 1 tbsp Pumpkin seeds daily for zinc & estrogen receptors.',
          rationale: 'Estrogen badhne se stamina aur metabolism peak hota hai; high protein muscle tone support karta hai.',
        );
      case FeminaPhase.ovulatory:
        return const FeminaNutritionPlan(
          focus: 'Antioxidant Defense & Liver Hormone Clearance',
          keyNutrients: ['Glutathione', 'Vitamin E', 'Fiber'],
          recommendedFoods: [
            'Cauliflower, Cabbage, Broccoli (Cruciferous veggies)',
            'Almonds aur Soaked Walnuts',
            'Coconut water aur Nimbu Paani with Chia Seeds',
            'Fresh colorful salads',
          ],
          avoidFoods: ['Heavy oily gravies', 'Excess sugar'],
          seedCyclingTip: 'Phase 2 Transition: Sesame seeds shuru karein.',
          rationale: 'Peak estrogen ko liver safely break down kare islie fiber aur cruciferous sabzi zaroori hai.',
        );
      case FeminaPhase.luteal:
        return const FeminaNutritionPlan(
          focus: 'Progesterone Support, PMS Mood & Bloating Control',
          keyNutrients: ['Vitamin B6', 'Potassium', 'Omega-3', 'Fiber'],
          recommendedFoods: [
            'Banana (Kela) — High in B6 & potassium to beat bloating',
            'Sesame (Til) & Sunflower seeds',
            'Dark Chocolate (70%+ cocoa) for endorphins',
            'Warm Ajwain / Chamomile herbal tea',
            'Moong dal Khichdi with Ghee',
          ],
          avoidFoods: ['High-sodium pickles, papad', 'Refined table sugar'],
          seedCyclingTip: 'Phase 2: 1 tbsp Sesame (Til) + 1 tbsp Sunflower seeds daily for progesterone synthesis.',
          rationale: 'Digestion slow hota hai; Vitamin B6 mood stabilize karta hai aur potassium bloating khatam karta hai.',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  List<MaternalDoctorInstruction> _buildDefaultDoctorInstructions() {
    return const [
      MaternalDoctorInstruction(
        id: 'folic_acid_supplement',
        category: 'medication',
        title: 'Folic Acid (400-500 mcg) Daily',
        details: 'Doctor ki prescribed prenatal tablet breakfast ke baad lein.',
        frequency: 'daily',
        positiveImpact: 'Baby ke brain aur spinal cord ke neural tube defects (Spina Bifida) ko 70% prevent karta hai.',
        skippedRisk: 'Neural tube formation me irreversible development anomalies ka risk.',
        timingTip: 'Subah breakfast ke sath lein taaki acidity na ho.',
      ),
      MaternalDoctorInstruction(
        id: 'elemental_iron_supplement',
        category: 'medication',
        title: 'Elemental Iron (Ferrous Ascorbate)',
        details: 'Dopahar ke meal ke baad Orange juice ya Nimbu Paani ke sath lein.',
        frequency: 'daily',
        positiveImpact: 'Blood volume expand karta hai jisse baby tak oxygen aur hemoglobin seamless flow hota hai.',
        skippedRisk: 'Maternal severe anemia aur baby ka low birth weight.',
        timingTip: 'Doodh ya calcium ke sath kabhi na lein (2 ghante ka gap rakhein).',
      ),
      MaternalDoctorInstruction(
        id: 'calcium_vit_d3_supplement',
        category: 'medication',
        title: 'Calcium (500mg) + Vitamin D3',
        details: 'Raat ko dinner ke baad lein.',
        frequency: 'daily',
        positiveImpact: 'Baby ke skeletal bones aur teeth structure build karta hai bina mother ki bones ko weak kiye.',
        skippedRisk: 'Mother me post-pregnancy severe bone weakness aur nocturnal leg cramps.',
        timingTip: 'Iron tablet se kam se kam 3 ghante ka gap zaroor rakhein.',
      ),
      MaternalDoctorInstruction(
        id: 'maternal_hydration',
        category: 'diet',
        title: 'Maternal Hydration (2.5 - 3.0 Litres)',
        details: 'Saaf paani, Nariyal Paani, Chaas aur vegetable soups.',
        frequency: 'daily',
        positiveImpact: 'Amniotic fluid level (AFI) ko healthy range me maintain rakhta hai aur circulation boost karta hai.',
        skippedRisk: 'Oligohydramnios (low amniotic fluid) aur painful UTI infections.',
      ),
      MaternalDoctorInstruction(
        id: 'side_sleeping_guideline',
        category: 'caution',
        title: 'Left-Side Sleeping Posture',
        details: 'Knees ke beech me pillow rakh kar left side par soyein.',
        frequency: 'daily',
        positiveImpact: 'Inferior Vena Cava par pressure zero karta hai; baby tak maximum oxygen supply hoti hai.',
        skippedRisk: 'Peeth ke bal flat sone se mother ka BP drop hota hai aur placenta blood flow 30% ruk sakta hai.',
      ),
    ];
  }

  MaternalFetalMilestone _getMilestoneForWeek(int week) {
    if (week <= 6) {
      return const MaternalFetalMilestone(
        week: 4,
        fruitAnalogy: 'Poppy Seed (Khashkhash)',
        approximateWeightGrams: 1,
        approximateLengthMm: 2,
        developmentHighlights: [
          'Blastocyst uterus lining me safely implant ho chuka hai.',
          'Amniotic sac aur placenta form hona shuru ho gaye hain.',
        ],
        motherBodyChanges: [
          'Mild spotting ya fatigue mehsus ho sakti hai.',
          'Progesterone surge se breast tenderness badhti hai.',
        ],
      );
    } else if (week <= 10) {
      return const MaternalFetalMilestone(
        week: 8,
        fruitAnalogy: 'Kidney Bean (Rajma)',
        approximateWeightGrams: 2,
        approximateLengthMm: 16,
        developmentHighlights: [
          'Baby ka heart 150-160 BPM par beat kar raha hai.',
          'Arms, legs, fingers aur tiny eyelids shape le rahe hain.',
        ],
        motherBodyChanges: [
          'Morning sickness aur nausea peak par ho sakta hai.',
          'Frequent washroom visits due to expanding uterus.',
        ],
      );
    } else if (week <= 14) {
      return const MaternalFetalMilestone(
        week: 12,
        fruitAnalogy: 'Nimbu (Lime)',
        approximateWeightGrams: 14,
        approximateLengthMm: 54,
        developmentHighlights: [
          'Saare essential organs ban chuke hain; reflex motions start ho gaye hain.',
          'Baby hiccup aur fingers close kar sakta hai.',
        ],
        motherBodyChanges: [
          'Nausea kam hona shuru hota hai; energy rebound shuru hoti hai.',
        ],
      );
    } else if (week <= 18) {
      return const MaternalFetalMilestone(
        week: 16,
        fruitAnalogy: 'Avocado (Makhanphal)',
        approximateWeightGrams: 100,
        approximateLengthMm: 116,
        developmentHighlights: [
          'Baby mother ki voice sun sakta hai; eyes light sense karti hain.',
          'Skeleton cartilage se solid bone me convert ho raha hai.',
        ],
        motherBodyChanges: [
          'Golden Second Trimester: energy high rehti hai.',
          'Baby bump slightly visible hona shuru hota hai.',
        ],
      );
    } else if (week <= 22) {
      return const MaternalFetalMilestone(
        week: 20,
        fruitAnalogy: 'Banana (Kela)',
        approximateWeightGrams: 300,
        approximateLengthMm: 256,
        developmentHighlights: [
          'Halfway mark! Baby active kicks aur somersaults karta hai.',
          'Vernix cream layer baby ki skin ko protect karti hai.',
        ],
        motherBodyChanges: [
          'Quickening kicks clearly feel hoti hain.',
          'Level II Targeted Anomaly Scan ka optimal week.',
        ],
      );
    } else if (week <= 26) {
      return const MaternalFetalMilestone(
        week: 24,
        fruitAnalogy: 'Corn Ear (Bhutta)',
        approximateWeightGrams: 600,
        approximateLengthMm: 300,
        developmentHighlights: [
          'Lungs me surfactant banna shuru hota hai jo breathing me essential hai.',
          'Hearing fully active hai; music par react karta hai.',
        ],
        motherBodyChanges: [
          'Braxton Hicks practice contractions feel ho sakte hain.',
          'Glucose tolerance test (OGTT) ka time.',
        ],
      );
    } else if (week <= 30) {
      return const MaternalFetalMilestone(
        week: 28,
        fruitAnalogy: 'Eggplant (Baingan)',
        approximateWeightGrams: 1000,
        approximateLengthMm: 376,
        developmentHighlights: [
          'Third trimester shuru! Baby eyes open kar sakta hai with eyelashes.',
          'Regular sleep-wake patterns establish hote hain.',
        ],
        motherBodyChanges: [
          'Shortness of breath as uterus pushes upwards.',
          'Daily kick counter audit zaroori hota hai (10 kicks in 2 hours).',
        ],
      );
    } else if (week <= 34) {
      return const MaternalFetalMilestone(
        week: 32,
        fruitAnalogy: 'Squash (Kaddu)',
        approximateWeightGrams: 1700,
        approximateLengthMm: 424,
        developmentHighlights: [
          'Bones completely hard ho chuki hain (skull bone flexible rehti hai delivery ke lie).',
          'Practice breathing motions continuously chalti hain.',
        ],
        motherBodyChanges: [
          'Pelvic pressure aur frequent urination.',
          'Acidity se bachne ke lie small frequent meals lein.',
        ],
      );
    } else if (week <= 38) {
      return const MaternalFetalMilestone(
        week: 36,
        fruitAnalogy: 'Papaya / Honeydew Melon',
        approximateWeightGrams: 2600,
        approximateLengthMm: 474,
        developmentHighlights: [
          'Lungs mature ho chuki hain; baby head-down cephalic position leta hai.',
          'Mother se natural antibodies transfer ho rahi hain.',
        ],
        motherBodyChanges: [
          'Baby pelvis me drop hota hai (Lightening). Breathing thodi easy hoti hai.',
        ],
      );
    } else {
      return const MaternalFetalMilestone(
        week: 40,
        fruitAnalogy: 'Watermelon (Tarbooz)',
        approximateWeightGrams: 3400,
        approximateLengthMm: 512,
        developmentHighlights: [
          'Full term baby! Ready for the outer world.',
          'Firm grasp, clear reflexes, mature fat layers.',
        ],
        motherBodyChanges: [
          'Cervix softening aur dilation.',
          'Hospital bag ready rakhein; regular contractions monitor karein.',
        ],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 24-Hour Chrono Routines (Femina & Maternal)
  // ---------------------------------------------------------------------------

  List<DailyChronoRoutineStep> getFeminaChronoRoutine(FeminaPhase phase) {
    switch (phase) {
      case FeminaPhase.menstrual:
        return const [
          DailyChronoRoutineStep(
            id: 'm_wake',
            timeSlot: '06:30 AM - 07:30 AM',
            periodOfDay: 'morning_wake',
            title: 'Warm Ginger-Ajwain Gentle Awakening',
            guidance: 'Uterine contractions ko sooth karne ke lie warm water infusion lein.',
            nutritionOrAction: '1 glass lukewarm water + fresh ginger slices + pinch of ajwain & jaggery.',
            sleepPostureOrTip: 'Bedsheet se uthne se pehle gentle knees-to-chest stretch karein.',
            medicineOrSupplements: ['Warm digestive herbal infusion'],
          ),
          DailyChronoRoutineStep(
            id: 'm_breakfast',
            timeSlot: '08:00 AM - 09:00 AM',
            periodOfDay: 'breakfast',
            title: 'Iron & Bioavailable Protein Nourishment',
            guidance: 'Blood loss se hone wale ferritin drop ko counteract karein.',
            nutritionOrAction: 'Warm Besan/Moong Dal Cheela stuffed with Palak & Paneer + 5 soaked Black Raisins.',
            sleepPostureOrTip: 'Upright mindful eating; walk 5 mins after eating.',
            medicineOrSupplements: ['Iron Supplement (with fresh lemon water, NEVER with tea/milk)'],
          ),
          DailyChronoRoutineStep(
            id: 'm_mid_morning',
            timeSlot: '10:30 AM - 11:30 AM',
            periodOfDay: 'mid_morning',
            title: 'Fruit Therapy & Seed Cycling Phase 1',
            guidance: 'Vitamin C se non-heme iron absorption 300% badhti hai.',
            nutritionOrAction: '1 bowl fresh Pomegranate (Anaar) arils + 1 tbsp ground Flax Seeds.',
            sleepPostureOrTip: 'Stay hydrated with warm water sips.',
          ),
          DailyChronoRoutineStep(
            id: 'm_lunch',
            timeSlot: '01:00 PM - 02:00 PM',
            periodOfDay: 'lunch',
            title: 'Warm Comfort Indian Healing Lunch',
            guidance: 'Pelvic circulation promote karta hai aur bloating prevent karta hai.',
            nutritionOrAction: 'Steamed Rice + Methi Dal + Beetroot Salad + 1 tsp A2 Desi Cow Ghee.',
            sleepPostureOrTip: 'Vajrasana me 5 minutes baith kar digestion settle karein.',
          ),
          DailyChronoRoutineStep(
            id: 'm_afternoon_rest',
            timeSlot: '03:30 PM - 04:30 PM',
            periodOfDay: 'afternoon_rest',
            title: 'Lymphatic Drainage & Feet Elevation',
            guidance: 'Pelvic area se pooling blood aur fatigue release karein.',
            nutritionOrAction: '1 cup warm Cinnamon water or Fennel tea.',
            sleepPostureOrTip: '15-min Legs-Up-The-Wall (Viparita Karani) deewar par legs rest karke.',
          ),
          DailyChronoRoutineStep(
            id: 'm_evening_movement',
            timeSlot: '05:30 PM - 06:30 PM',
            periodOfDay: 'evening_movement',
            title: 'Restorative Asana Sanctuary (Zero Inversions)',
            guidance: 'Uterine smooth muscle tone relax karein. Heavy weights aur HIIT avoid karein.',
            nutritionOrAction: 'Balasana (Child\'s Pose) + Supta Baddha Konasana + Cat-Cow.',
            sleepPostureOrTip: 'Ground mat par soft pillow aur blanket use karein.',
          ),
          DailyChronoRoutineStep(
            id: 'm_dinner',
            timeSlot: '07:30 PM - 08:30 PM',
            periodOfDay: 'dinner',
            title: 'Anti-Inflammatory Light Dinner',
            guidance: 'Sone se kam se kam 2 ghante pehle dinner khatam karein.',
            nutritionOrAction: 'Warm Palak-Paneer Soup ya 2 soft Phulkas with Lauki/Tori and Moong dal.',
            sleepPostureOrTip: 'Walk 100 paces gently post dinner.',
          ),
          DailyChronoRoutineStep(
            id: 'm_bedtime',
            timeSlot: '09:45 PM - 10:30 PM',
            periodOfDay: 'bedtime',
            title: 'Golden Haldi Milk & Deep Sleep Sanctuary',
            guidance: 'Cramps block karke deep REM sleep spindles induce karein. Target: 8.5-9.5 hrs.',
            nutritionOrAction: 'Warm Milk + Turmeric (Haldi) + Cardamom + pinch of black pepper + 1/2 tsp Ghee.',
            sleepPostureOrTip: 'Fetal position me soyein ya knees ke beech supportive pillow rakhein.',
            medicineOrSupplements: ['Magnesium Glycinate (300mg) for cramp relief & deep sleep'],
          ),
        ];

      case FeminaPhase.follicular:
        return const [
          DailyChronoRoutineStep(
            id: 'f_wake',
            timeSlot: '06:30 AM - 07:30 AM',
            periodOfDay: 'morning_wake',
            title: 'Metabolic Fire Morning Awakening',
            guidance: 'Estrogen rising phase me gut fire aur energy ignite karein.',
            nutritionOrAction: '1 glass lukewarm water + half lemon squeeze + 1 tsp soaked Chia seeds.',
            sleepPostureOrTip: '10 mins natural morning sunlight exposure.',
          ),
          DailyChronoRoutineStep(
            id: 'f_breakfast',
            timeSlot: '08:00 AM - 09:00 AM',
            periodOfDay: 'breakfast',
            title: 'High-Protein & Probiotic Stamina Bowl',
            guidance: 'Follicular growth aur lean muscle building ko support karein.',
            nutritionOrAction: 'Sprouted Moong Salad + Fresh Dahi (Curd) with roasted cumin + 4 Almonds.',
            sleepPostureOrTip: 'Active upright posture, full energetic breathing.',
            medicineOrSupplements: ['Zinc (15-30mg) for follicle maturation'],
          ),
          DailyChronoRoutineStep(
            id: 'f_mid_morning',
            timeSlot: '10:30 AM - 11:30 AM',
            periodOfDay: 'mid_morning',
            title: 'Prebiotic Fruit & Pumpkin Seed Cycling',
            guidance: 'Zinc follicle rupture aur estrogen receptor sensitivity enhance karta hai.',
            nutritionOrAction: '1 Crisp Green Apple or Ripe Papaya bowl + 1 tbsp raw Pumpkin Seeds.',
            sleepPostureOrTip: 'Maintain optimal hydration (min 2.5L daily).',
          ),
          DailyChronoRoutineStep(
            id: 'f_lunch',
            timeSlot: '01:00 PM - 02:00 PM',
            periodOfDay: 'lunch',
            title: 'Lean Protein & Complex Fuel Lunch',
            guidance: 'High metabolic rate supports steady sustained energy.',
            nutritionOrAction: 'Multigrain Roti + Rajma / Grilled Paneer + Crunchy Cucumber-Carrot Salad.',
            sleepPostureOrTip: 'Short 5-min walk after lunch.',
          ),
          DailyChronoRoutineStep(
            id: 'f_afternoon_rest',
            timeSlot: '03:30 PM - 04:30 PM',
            periodOfDay: 'afternoon_rest',
            title: 'Cognitive Reset & Hydration',
            guidance: 'Brain alertness peak par hoti hai; sustain with green tea.',
            nutritionOrAction: 'Green tea or Matcha + 4 soaked Walnuts.',
            sleepPostureOrTip: 'Posture check: shoulders rolled back, spine straight.',
          ),
          DailyChronoRoutineStep(
            id: 'f_evening_movement',
            timeSlot: '05:30 PM - 06:30 PM',
            periodOfDay: 'evening_movement',
            title: 'Peak Strength & Athletic Conditioning',
            guidance: 'Estrogen ke karan pain tolerance highest hai — optimal time for heavy lifts or cardio.',
            nutritionOrAction: 'Gym Strength Training, Power Vinyasa Yoga, or 5km brisk run.',
            sleepPostureOrTip: 'Dynamic warmup followed by thorough cool-down stretches.',
          ),
          DailyChronoRoutineStep(
            id: 'f_dinner',
            timeSlot: '07:30 PM - 08:30 PM',
            periodOfDay: 'dinner',
            title: 'Cellular Repair Protein Dinner',
            guidance: 'Muscle recovery and overnight glycogen replenishment.',
            nutritionOrAction: 'Steamed vegetables with Grilled Tofu / Paneer and Yellow Moong Dal soup.',
            sleepPostureOrTip: 'Gentle post-dinner stroll.',
          ),
          DailyChronoRoutineStep(
            id: 'f_bedtime',
            timeSlot: '09:45 PM - 10:30 PM',
            periodOfDay: 'bedtime',
            title: 'Circadian Wind-Down & Deep Rest',
            guidance: 'High sleep efficiency phase. Target: 7.5 - 8.0 hours.',
            nutritionOrAction: 'Chamomile tea or warm water with soaked raisins.',
            sleepPostureOrTip: 'Room temperature cool (20-22°C), complete dark room.',
          ),
        ];

      case FeminaPhase.ovulatory:
        return const [
          DailyChronoRoutineStep(
            id: 'o_wake',
            timeSlot: '06:30 AM - 07:30 AM',
            periodOfDay: 'morning_wake',
            title: 'Hydration & Cervical Fluid Nourishment',
            guidance: 'Fertile cervical mucus aur luteinizing hormone (LH) surge ko support karein.',
            nutritionOrAction: '1 glass fresh Tender Coconut Water or Aloe Vera juice.',
            sleepPostureOrTip: 'Gentle morning spine twists and deep ocean breathing.',
          ),
          DailyChronoRoutineStep(
            id: 'o_breakfast',
            timeSlot: '08:00 AM - 09:00 AM',
            periodOfDay: 'breakfast',
            title: 'Antioxidant Defense & Energy Breakfast',
            guidance: 'Follicular rupture ke oxidative stress se cells ko protect karein.',
            nutritionOrAction: 'Berry Smoothie Bowl with Chia Seeds & Walnuts, or Boiled Eggs / Tofu Bhurji.',
            sleepPostureOrTip: 'Mindful peaceful eating.',
          ),
          DailyChronoRoutineStep(
            id: 'o_mid_morning',
            timeSlot: '10:30 AM - 11:30 AM',
            periodOfDay: 'mid_morning',
            title: 'Glutathione Fruit Therapy & Sunflower Seeds',
            guidance: 'Liver detoxification of peak estrogen.',
            nutritionOrAction: 'Fresh Watermelon slices or Sweet Lime (Mosambi) + 1 tbsp Sunflower Seeds.',
            sleepPostureOrTip: 'Stay active; move every 45 minutes.',
          ),
          DailyChronoRoutineStep(
            id: 'o_lunch',
            timeSlot: '01:00 PM - 02:00 PM',
            periodOfDay: 'lunch',
            title: 'Cruciferous Liver-Clearing Feast',
            guidance: 'Indole-3-carbinol liver me excess estrogen clearance boost karta hai.',
            nutritionOrAction: 'Steamed Broccoli, Cauliflower, and Carrots + Dal + Quinoa or Roti.',
            sleepPostureOrTip: 'Sit upright, avoid screen during eating.',
          ),
          DailyChronoRoutineStep(
            id: 'o_afternoon_rest',
            timeSlot: '03:30 PM - 04:30 PM',
            periodOfDay: 'afternoon_rest',
            title: 'Cellular Cooling Refresh',
            guidance: 'Body temperature post-ovulation 0.3°C badhne lagti hai.',
            nutritionOrAction: 'Fresh Chaas (Buttermilk) with crushed mint and roasted jeera.',
            sleepPostureOrTip: 'Step outside for fresh oxygen breathwork.',
          ),
          DailyChronoRoutineStep(
            id: 'o_evening_movement',
            timeSlot: '05:30 PM - 06:30 PM',
            periodOfDay: 'evening_movement',
            title: 'High Intensity Intervals & Social Workouts',
            guidance: 'Peak testosterone & estrogen drive maximum stamina and social confidence.',
            nutritionOrAction: 'HIIT training, group fitness dance, or competitive sports.',
            sleepPostureOrTip: 'Full body cool-down and pelvic stretches.',
          ),
          DailyChronoRoutineStep(
            id: 'o_dinner',
            timeSlot: '07:30 PM - 08:30 PM',
            periodOfDay: 'dinner',
            title: 'Light Antioxidant Quinoa & Lentils',
            guidance: 'Easy digestion prevents night discomfort.',
            nutritionOrAction: 'Warm Quinoa Bowl with Sautéed Bell Peppers, Spinach, and Moong Dal.',
            sleepPostureOrTip: '10 mins leisurely walk.',
          ),
          DailyChronoRoutineStep(
            id: 'o_bedtime',
            timeSlot: '09:45 PM - 10:30 PM',
            periodOfDay: 'bedtime',
            title: 'Cool Bedroom Sanctuary Rest',
            guidance: 'Maintain deep sleep architecture. Target: 7.5 - 8.0 hours.',
            nutritionOrAction: 'Sip cold/room-temp water with fresh mint.',
            sleepPostureOrTip: 'Use breathable organic cotton sheets and cool ventilation.',
          ),
        ];

      case FeminaPhase.luteal:
        return const [
          DailyChronoRoutineStep(
            id: 'l_wake',
            timeSlot: '06:30 AM - 07:30 AM',
            periodOfDay: 'morning_wake',
            title: 'Warm CCF Bloating-Shield Awakening',
            guidance: 'Progesterone digestively slow karta hai; CCF tea gut ko activate karti hai.',
            nutritionOrAction: 'Warm Cumin-Coriander-Fennel (CCF) boiled tea.',
            sleepPostureOrTip: 'Gentle Cat-Cow stretches on bed before standing.',
          ),
          DailyChronoRoutineStep(
            id: 'l_breakfast',
            timeSlot: '08:00 AM - 09:00 AM',
            periodOfDay: 'breakfast',
            title: 'Serotonin-Boosting Complex Carb Breakfast',
            guidance: 'Pre-menstrual serotonin drop ko complex carbs aur Vitamin B6 se prevent karein.',
            nutritionOrAction: 'Warm Oatmeal or Multigrain Dalia with sliced banana, walnuts & cinnamon.',
            sleepPostureOrTip: 'Upright calm posture, avoid caffeinated coffee spikes.',
            medicineOrSupplements: ['Vitamin B6 (50mg) / Evening Primrose Oil'],
          ),
          DailyChronoRoutineStep(
            id: 'l_mid_morning',
            timeSlot: '10:30 AM - 11:30 AM',
            periodOfDay: 'mid_morning',
            title: 'Potassium Fruit Therapy & Sesame Seed Cycling',
            guidance: 'Potassium excess sodium flush karta hai; sesame seeds progesterone build karte hain.',
            nutritionOrAction: '1 Ripe Robusta Banana or 2 fresh Figs (Anjeer) + 1 tbsp roasted Sesame seeds.',
            sleepPostureOrTip: 'Continuous steady water intake.',
          ),
          DailyChronoRoutineStep(
            id: 'l_lunch',
            timeSlot: '01:00 PM - 02:00 PM',
            periodOfDay: 'lunch',
            title: 'Digestive Comfort Khichdi & Light Gourds',
            guidance: 'Slow motility me heavy foods constipation aur gas karte hain.',
            nutritionOrAction: 'Moong Dal Khichdi + Ghee + Lauki/Turai subzi + Fresh Pudina curd.',
            sleepPostureOrTip: 'Vajrasana for 5 mins post-meal.',
          ),
          DailyChronoRoutineStep(
            id: 'l_afternoon_rest',
            timeSlot: '03:30 PM - 04:30 PM',
            periodOfDay: 'afternoon_rest',
            title: 'PMS Mood Reset & Endorphin Boost',
            guidance: 'Magnesium suppresses cortisol and curbs sweet cravings.',
            nutritionOrAction: '1 cup Chamomile tea + 2 squares of 70%+ Dark Chocolate.',
            sleepPostureOrTip: '10-min mindfulness or box breathing (4-4-4-4).',
          ),
          DailyChronoRoutineStep(
            id: 'l_evening_movement',
            timeSlot: '05:30 PM - 06:30 PM',
            periodOfDay: 'evening_movement',
            title: 'Low-Impact Pilates & Nature Walking',
            guidance: 'High intensity HIIT increases cortisol during luteal phase; switch to gentle movement.',
            nutritionOrAction: '30-min brisk walk in nature, Mat Pilates, or Yin Yoga.',
            sleepPostureOrTip: 'Deep hip opening stretches (Pigeon pose, Butterfly pose).',
          ),
          DailyChronoRoutineStep(
            id: 'l_dinner',
            timeSlot: '07:30 PM - 08:30 PM',
            periodOfDay: 'dinner',
            title: 'Early Low-Sodium Soothing Dinner',
            guidance: 'Pickles, papad aur high salt strictly avoid karein to prevent puffy face/hands.',
            nutritionOrAction: 'Lauki Kofta Curry (light gravy) with 2 Phulkas or Pumpkin-Ginger Soup.',
            sleepPostureOrTip: 'No food within 2.5 hours of bedtime to prevent GERD.',
          ),
          DailyChronoRoutineStep(
            id: 'l_bedtime',
            timeSlot: '09:45 PM - 10:30 PM',
            periodOfDay: 'bedtime',
            title: 'Progesterone Sleep Sanctuary Rest',
            guidance: 'Higher body temperature can fragment sleep. Keep bedroom cool. Target: 8.5-9.0 hrs.',
            nutritionOrAction: 'Warm Ashwagandha or Chamomile infusion.',
            sleepPostureOrTip: 'Side sleeping with pillow between knees; blackout curtains.',
            medicineOrSupplements: ['Magnesium Glycinate (300mg) at bedtime'],
          ),
        ];
    }
  }

  List<DailyChronoRoutineStep> getMaternalChronoRoutine(
    int week,
    MaternalTrimester trimester,
  ) {
    return [
      const DailyChronoRoutineStep(
        id: 'mat_wake',
        timeSlot: '06:30 AM - 07:30 AM',
        periodOfDay: 'morning_wake',
        title: 'Bedside Nausea & Acidity Shield (Eat Before Standing)',
        guidance: 'Raat bhar stomach acid jama hota hai; bina khaye bed se khade hone par severe morning sickness trigger hoti hai.',
        nutritionOrAction: 'Bed ke paas rakhe sukhe roasted chana ya whole-wheat crackers ke 2-3 bites bina sar uthaye chabayen. 15 minute baad halke gungune cardamom-ginger water ke chote sips lein.',
        sleepPostureOrTip: 'Head ko 30° elevated rakhein; jhatke se bed se bahar na niklein.',
        medicineOrSupplements: [
          'Thyroid (Levothyroxine, agar prescribed ho) — Khali pet 1 glass paani ke sath; chai/nashte se 45 min pehle',
        ],
      ),
      DailyChronoRoutineStep(
        id: 'mat_breakfast',
        timeSlot: '08:00 AM - 09:00 AM',
        periodOfDay: 'breakfast',
        title: 'Prenatal Protein & Choline Power Breakfast',
        guidance: 'Choline aur bioavailable protein baby ke brain neural connections aur placenta vascularity banate hain.',
        nutritionOrAction: 'Besan Cheela with grated fresh Paneer & Mint chutney, ya 2 boiled eggs / tofu avocado toast + 5 soaked almonds aur 2 soaked walnuts.',
        sleepPostureOrTip: 'Khana khate waqt spine seedhi rakhein; nashte ke turant baad letna mana hai.',
        medicineOrSupplements: trimester == MaternalTrimester.first
            ? const ['Folic Acid (5mg / 400-800mcg) with breakfast — Neural tube defect shield']
            : const ['Calcium + Vitamin D3 (500mg) — take with breakfast meal'],
      ),
      const DailyChronoRoutineStep(
        id: 'mat_mid_morning',
        timeSlot: '10:30 AM - 11:30 AM',
        periodOfDay: 'mid_morning',
        title: 'Maternal Fruit Therapy & Amniotic Hydration',
        guidance: 'Amniotic fluid index (AFI) maintain karta hai aur placental blood flow optimize karta hai.',
        nutritionOrAction: '1 bowl fresh Pomegranate (Anaar) arils ya Crisp Apple + 1 glass fresh Tender Coconut Water.',
        sleepPostureOrTip: 'Khade hokar 5 minute gentle arm stretches karein.',
      ),
      DailyChronoRoutineStep(
        id: 'mat_lunch',
        timeSlot: '01:00 PM - 02:00 PM',
        periodOfDay: 'lunch',
        title: 'Nourishing Indian Maternal Thali',
        guidance: 'Iron, plant calcium, complex fibers aur probiotics ka perfect balance.',
        nutritionOrAction: 'Palak-Moong Dal + 2 Phulkas smeared with A2 Desi Ghee + Fresh Curd / Dahi + Carrot-Cucumber Salad with fresh lemon juice squeeze.',
        sleepPostureOrTip: 'Mindful chewing; chew each bite 25-30 times to prevent gastric gas.',
        medicineOrSupplements: trimester != MaternalTrimester.first
            ? const ['Calcium + Vitamin D3 (second dose if twice daily prescribed)']
            : const [],
      ),
      const DailyChronoRoutineStep(
        id: 'mat_afternoon_rest',
        timeSlot: '02:30 PM - 03:30 PM',
        periodOfDay: 'afternoon_rest',
        title: 'SOS Circulation Power Nap (Left-Side Recumbent)',
        guidance: 'Inferior Vena Cava (IVC) par heavy uterus ka pressure hatata hai, jisse baby ko maximum oxygen milti hai aur pairo ki swelling kam hoti hai.',
        nutritionOrAction: 'Left side par let kar dono ghutno aur takhno ke beech firm pillow lagayein.',
        sleepPostureOrTip: 'Left-Lateral Recumbent (SOS). Peeth ke bal (supine) letna strictly mana hai.',
      ),
      const DailyChronoRoutineStep(
        id: 'mat_evening_movement',
        timeSlot: '05:00 PM - 06:00 PM',
        periodOfDay: 'evening_movement',
        title: 'Prenatal Pelvic Mobility & Kegel Strengthening',
        guidance: 'Pelvic floor muscles ko tone karta hai aur birth canal flexibility improve karta hai.',
        nutritionOrAction: '20-25 mins gentle outdoor walk + Baddha Konasana (Butterfly) + Cat-Cow stretches + 10 reps Kegels (contract 5s, release 5s).',
        sleepPostureOrTip: 'Wear supportive shoes and keep water bottle handy.',
        medicineOrSupplements: [
          'Iron Supplement (Ferrous Ascorbate) — Taaza Nimbu paani ke sath lein. Chai, coffee ya doodh se 2 ghante door rakhein!',
        ],
      ),
      const DailyChronoRoutineStep(
        id: 'mat_dinner',
        timeSlot: '07:30 PM - 08:15 PM',
        periodOfDay: 'dinner',
        title: 'Early Anti-Reflux Digestible Dinner',
        guidance: 'Progesterone stomach valve ko relax karta hai. Sone se 2 ghante pehle khana finish karna nocturnal heartburn se bachata hai.',
        nutritionOrAction: 'Vegetable Moong Dal Khichdi with 1 tsp Ghee, ya Vegetable Dalia with Lauki/Tori curry.',
        sleepPostureOrTip: 'Khane ke baad 100 kadam gentle walk karein; seedhe bed par na jayein.',
      ),
      const DailyChronoRoutineStep(
        id: 'mat_bedtime',
        timeSlot: '09:45 PM - 10:30 PM',
        periodOfDay: 'bedtime',
        title: 'Sleep Sanctuary & 3-Pillow Left-SOS Setup',
        guidance: 'Deep 8.5 - 9.5 hours continuous sleep. Fetal human growth hormone night deep sleep me peak release hota hai.',
        nutritionOrAction: 'Gunguna milk with pinch of Kesar (Saffron) & Cardamom (ya warm almond milk).',
        sleepPostureOrTip: 'Left lateral sleep: 1 pillow between knees, 1 wedge pillow supporting belly bump, 1 pillow behind spine.',
        medicineOrSupplements: [
          'Omega-3 DHA (200-300mg) for baby brain & eyes',
          'Doxylamine + Vitamin B6 (agar severe nausea ke lie doctor ne prescribe kia ho)',
        ],
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Fruit Therapies (Femina & Maternal)
  // ---------------------------------------------------------------------------

  FruitTherapyGuide getFeminaFruitTherapy(FeminaPhase phase) {
    switch (phase) {
      case FeminaPhase.menstrual:
        return const FruitTherapyGuide(
          dailyFruitRule: 'Always consume room-temperature fruits. Avoid refrigerated cold melons during bleeding.',
          recommendedFruits: [
            FruitDetail(
              name: 'Pomegranate',
              hindiName: 'Anaar',
              benefits: 'High bioavailable non-heme iron and polyphenol antioxidants; directly combats menstrual fatigue and replenishes red blood cells.',
              nutrientKey: 'Iron, Vitamin C, Folate',
              timing: 'Mid-morning (11:00 AM)',
              bestConsumedWith: 'Pinch of black salt and ground flax seeds',
            ),
            FruitDetail(
              name: 'Ripe Banana',
              hindiName: 'Kela',
              benefits: 'Rich in Vitamin B6 and potassium; relieves smooth muscle cramps and prevents sudden dopamine drops.',
              nutrientKey: 'Vitamin B6, Potassium, Magnesium',
              timing: 'Breakfast or mid-afternoon',
              bestConsumedWith: 'Warm cinnamon dash',
            ),
            FruitDetail(
              name: 'Kiwi & Indian Gooseberry',
              hindiName: 'Amla',
              benefits: 'Mega-dose Vitamin C amplifies plant-based iron absorption by over 300%.',
              nutrientKey: 'Vitamin C, Bioflavonoids',
              timing: 'Right after lunch or breakfast',
              bestConsumedWith: 'Fresh water',
            ),
          ],
          avoidOrCautionFruits: [
            FruitContraindication(
              name: 'Chilled Melons',
              hindiName: 'Thandi Kharbooza / Tarbooz',
              riskLevel: 'caution',
              clinicalReason: 'Cold temperatures trigger pelvic vasoconstriction and worsen spasmodic dysmenorrhea.',
              scientificMechanism: 'Cold-induced smooth muscle shivering increases prostaglandin release.',
            ),
          ],
        );

      case FeminaPhase.follicular:
        return const FruitTherapyGuide(
          dailyFruitRule: 'Focus on high-fiber prebiotic fruits that nourish gut bacteria for clean estrogen synthesis.',
          recommendedFruits: [
            FruitDetail(
              name: 'Green Apple',
              hindiName: 'Seb',
              benefits: 'High pectin soluble fiber feeds estrobolome gut bacteria, supporting healthy estrogen levels.',
              nutrientKey: 'Pectin, Quercetin, Vitamin C',
              timing: 'Mid-morning snack',
              bestConsumedWith: 'Almond butter or raw pumpkin seeds',
            ),
            FruitDetail(
              name: 'Ripe Papaya',
              hindiName: 'Paka Papita',
              benefits: 'Rich in carotenes and digestive papain enzyme; maintains smooth bowel regularity.',
              nutrientKey: 'Beta-Carotene, Papain, Folate',
              timing: 'Mid-morning',
              bestConsumedWith: 'Fresh lime squeeze',
            ),
            FruitDetail(
              name: 'Blueberries & Blackberries',
              hindiName: 'Berries / Jamun',
              benefits: 'Anthocyanins protect the developing ovarian follicle from cellular oxidative stress.',
              nutrientKey: 'Anthocyanins, Vitamin E',
              timing: 'Breakfast bowl',
              bestConsumedWith: 'Greek yogurt or curd',
            ),
          ],
          avoidOrCautionFruits: [],
        );

      case FeminaPhase.ovulatory:
        return const FruitTherapyGuide(
          dailyFruitRule: 'Focus on high hydration, glutathione, and capillary-strengthening citrus bioflavonoids.',
          recommendedFruits: [
            FruitDetail(
              name: 'Watermelon',
              hindiName: 'Tarbooz',
              benefits: '92% cellular hydration with lycopene; keeps cervical crypts hydrated and cools body during LH peak.',
              nutrientKey: 'Lycopene, Citrulline, Potassium',
              timing: 'Mid-morning (11:00 AM)',
              bestConsumedWith: 'Fresh mint leaves',
            ),
            FruitDetail(
              name: 'Sweet Lime & Oranges',
              hindiName: 'Mosambi / Santra',
              benefits: 'Bioflavonoids strengthen vascular capillary walls around the ovulating follicle.',
              nutrientKey: 'Hesperidin, Vitamin C',
              timing: 'Afternoon snack',
              bestConsumedWith: 'Pinch of black pepper',
            ),
          ],
          avoidOrCautionFruits: [],
        );

      case FeminaPhase.luteal:
        return const FruitTherapyGuide(
          dailyFruitRule: 'Prioritize high-potassium, low-glycemic fruits to combat PMS water retention and sugar cravings.',
          recommendedFruits: [
            FruitDetail(
              name: 'Robusta Banana',
              hindiName: 'Paka Kela',
              benefits: 'High potassium flushes excess sodium; Vitamin B6 drives serotonin synthesis to abolish PMS irritability.',
              nutrientKey: 'Potassium, Vitamin B6, Tryptophan',
              timing: 'Breakfast or 4:00 PM craving window',
              bestConsumedWith: '1 tsp peanut butter or sunflower seeds',
            ),
            FruitDetail(
              name: 'Fresh Figs',
              hindiName: 'Anjeer',
              benefits: 'High magnesium and bioavailable iron; satisfies pre-menstrual sweet cravings with zero glycemic spike.',
              nutrientKey: 'Magnesium, Soluble Fiber, Iron',
              timing: 'Mid-morning',
              bestConsumedWith: 'Warm water or walnuts',
            ),
          ],
          avoidOrCautionFruits: [
            FruitContraindication(
              name: 'Sugar-Coated Candied Fruits',
              hindiName: 'Chashni wale Sukhe Phal',
              riskLevel: 'caution',
              clinicalReason: 'Sharp glucose spikes trigger reactive hypoglycemia, aggravating mood swings and acne.',
              scientificMechanism: 'Insulin surges stimulate sebaceous androgen receptors, triggering cystic acne.',
            ),
          ],
        );
    }
  }

  FruitTherapyGuide getMaternalFruitTherapy(MaternalTrimester trimester) {
    return const FruitTherapyGuide(
      dailyFruitRule: 'Sabhi fruits ko pehle warm water aur pinch of salt/baking soda se wash karein. Roadside unwashed cut fruits ya unpasteurized pack juices strictly avoid karein.',
      recommendedFruits: [
        FruitDetail(
          name: 'Pomegranate',
          hindiName: 'Anaar',
          benefits: 'High non-heme iron, folate aur polyphenols; clinically proven to protect fetal brain from hypoxia and maximize uterine artery perfusion.',
          nutrientKey: 'Iron, Folate, Vitamin K, Polyphenols',
          timing: 'Mid-morning snack (11:00 AM)',
          bestConsumedWith: 'Fresh room temperature seeds',
        ),
        FruitDetail(
          name: 'Fresh Avocado',
          hindiName: 'Makhan Phal',
          benefits: 'Abundant in folate, potassium, and monounsaturated DHA fats; supports fetal neural tube and prevents painful maternal leg cramps.',
          nutrientKey: 'Folate, Potassium, MUFA healthy fats',
          timing: 'Breakfast toast or lunch salad',
          bestConsumedWith: 'Lemon juice & olive oil',
        ),
        FruitDetail(
          name: 'Oranges & Sweet Lime',
          hindiName: 'Santra / Mosambi',
          benefits: 'Vitamin C strengthens amniotic sac membrane collagen and multiplies maternal iron absorption.',
          nutrientKey: 'Vitamin C, Bioflavonoids, Hydration',
          timing: 'Post lunch or 4:00 PM',
          bestConsumedWith: 'Fresh room-temperature segments',
        ),
        FruitDetail(
          name: 'Ripe Banana',
          hindiName: 'Paka Kela',
          benefits: 'Vitamin B6 acts as natural antacid for morning nausea; high potassium prevents nocturnal calf spasms.',
          nutrientKey: 'Vitamin B6, Potassium, Soluble Fiber',
          timing: 'Early morning or afternoon',
          bestConsumedWith: 'Room temperature',
        ),
        FruitDetail(
          name: 'Apples',
          hindiName: 'Seb',
          benefits: 'High pectin soluble fiber prevents pregnancy constipation. Clinical studies show maternal apple intake lowers childhood asthma risk.',
          nutrientKey: 'Pectin fiber, Quercetin, Vitamin C',
          timing: 'Mid-morning or evening snack',
          bestConsumedWith: 'Wash thoroughly; eat with peel',
        ),
        FruitDetail(
          name: 'Tender Coconut Water',
          hindiName: 'Nariyal Paani',
          benefits: 'Pure natural isotonic electrolyte drink; supports optimal Amniotic Fluid Index (AFI) and fights maternal exhaustion.',
          nutrientKey: 'Potassium, Magnesium, Natural Electrolytes',
          timing: 'Mid-morning (11:00 AM)',
          bestConsumedWith: 'Freshly opened coconut',
        ),
      ],
      avoidOrCautionFruits: [
        FruitContraindication(
          name: 'Raw / Unripe / Green Papaya',
          hindiName: 'Kaccha / Adhpaka Papita',
          riskLevel: 'strict_avoid',
          clinicalReason: 'STRICTLY FORBIDDEN: Kaccha papita contains concentrated latex and active Papain enzyme. Body me ye oxytocin aur prostaglandin mimic karta hai, causing violent uterine contractions, cervical softening and high risk of miscarriage / preterm labor.',
          scientificMechanism: 'Papain induces premature uterine smooth muscle contractions and weakens placental attachment.',
        ),
        FruitContraindication(
          name: 'Raw Pineapple in High Amounts',
          hindiName: 'Anannas (Early Pregnancy)',
          riskLevel: 'caution',
          clinicalReason: 'Contains Bromelain proteolytic enzyme which can soften the cervix and induce irregular uterine spasms, especially in 1st Trimester.',
          scientificMechanism: 'Bromelain degrades collagen in the cervix, potentially precipitating cervical ripening.',
        ),
        FruitContraindication(
          name: 'Unpasteurized Packaged Juices & Unwashed Cut Street Fruits',
          hindiName: 'Thele ke Kate Phal aur Raw Juices',
          riskLevel: 'strict_avoid',
          clinicalReason: 'High risk of Toxoplasma gondii, Listeria monocytogenes, and Salmonella. Listeria crosses the placenta and can cause fetal sepsis and stillbirth.',
          scientificMechanism: 'Listeriolysin O allows Listeria to cross maternal-fetal endothelial barriers.',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sleep Protocols (Femina & Maternal)
  // ---------------------------------------------------------------------------

  SleepSanctuaryProtocol getFeminaSleepProtocol(FeminaPhase phase) {
    switch (phase) {
      case FeminaPhase.menstrual:
        return const SleepSanctuaryProtocol(
          targetSleepHours: '8.5 - 9.5 hours',
          optimalPosture: 'Fetal Posture (Side lying with knees tucked) or Supine with a bolster under knees',
          pillowSetup: 'Place a soft bolster or pillow under your knees to release pelvic and sacral tension.',
          circadianTip: 'Wear warm cotton socks to bed; warming peripheral extremities induces rapid sleep onset.',
          windDownRitual: [
            'Digital screen sunset 45 minutes before sleep.',
            'Apply warm castor oil or sesame oil gently to lower belly.',
            'Sip warm Golden Turmeric Milk.',
            'Listen to 432 Hz delta sleep tones or practice 4-7-8 breathing.',
          ],
          hormonalContext: 'Estrogen and progesterone are at their lowest baseline; immune cytokines rise slightly, requiring maximum restorative slow-wave sleep.',
        );

      case FeminaPhase.follicular:
        return const SleepSanctuaryProtocol(
          targetSleepHours: '7.5 - 8.0 hours',
          optimalPosture: 'Side sleeping with ergonomic cervical pillow',
          pillowSetup: 'Single medium-firm pillow aligning cervical spine with thoracic vertebrae.',
          circadianTip: 'Wake up with natural morning blue-sky light to anchor daytime cortisol rhythm.',
          windDownRitual: [
            'Read 10-15 pages of an inspiring book.',
            'Sip chamomile or lemon balm infusion.',
            'Dim bedroom lights to warm amber 1 hour before sleep.',
          ],
          hormonalContext: 'Rising estrogen enhances REM sleep efficiency and rapid morning wakefulness.',
        );

      case FeminaPhase.ovulatory:
        return const SleepSanctuaryProtocol(
          targetSleepHours: '7.5 hours',
          optimalPosture: 'Left or right lateral recumbent',
          pillowSetup: 'Supportive pillow ensuring neck is level.',
          circadianTip: 'Set bedroom AC/fan to 20-22°C to counteract natural ovulatory body temperature rise.',
          windDownRitual: [
            '10 minutes evening gratitude journaling.',
            'Cool water wash for face and feet.',
            'Gentle forward folds before getting into bed.',
          ],
          hormonalContext: 'Estrogen and testosterone peak; sleep need is lowest, energy is highest.',
        );

      case FeminaPhase.luteal:
        return const SleepSanctuaryProtocol(
          targetSleepHours: '8.5 - 9.0 hours',
          optimalPosture: 'Side sleeping with pillow firmly between thighs',
          pillowSetup: 'Placing a pillow between knees prevents pelvic torsion and relieves pre-menstrual lower back ache.',
          circadianTip: 'Progesterone elevates core body temperature by 0.3-0.5°C; keep bedroom extra cool and dark.',
          windDownRitual: [
            'Take a warm epsom salt bath 90 mins before bed.',
            'Sip warm Ashwagandha-Chamomile tea.',
            'Wear loose breathable modal or organic cotton nightwear.',
          ],
          hormonalContext: 'High progesterone increases sleep fragmentation and daytime drowsiness. Extra sleep duration is biologically essential.',
        );
    }
  }

  SleepSanctuaryProtocol getMaternalSleepProtocol(
    int week,
    MaternalTrimester trimester,
  ) {
    return const SleepSanctuaryProtocol(
      targetSleepHours: '8.5 - 9.5 hours',
      optimalPosture: 'Left-Lateral Recumbent (SOS - Sleep On Side). Left side par soyein with knee support.',
      pillowSetup: 'Place a firm pregnancy pillow or normal pillow between thighs/knees to align pelvis; a wedge pillow under the belly; and a support pillow behind back.',
      circadianTip: 'CRITICAL CLINICAL INVARIANT: Week 16 ke baad kabhi bhi peeth ke bal (supine flat) na soyein! Supine position me heavy uterus Inferior Vena Cava (IVC) ko daba deta hai jisse blood pressure girta hai aur baby ko oxygen supply ghat sakti hai.',
      windDownRitual: [
        'Dinner finish strictly 2 hours before bed to eliminate heartburn.',
        'Warm water foot wash and gentle ankle circular mobility.',
        'Sip warm saffron-cardamom milk for natural tryptophan sleep induction.',
        'Dark bedroom with ambient temperature kept between 20-22°C.',
      ],
      hormonalContext: 'High progesterone and growing belly disrupt sleep continuity. Dedicated left-lateral posture ensures optimal blood flow to the placenta and kidneys.',
    );
  }

  // ---------------------------------------------------------------------------
  // Home Remedies (Femina & Maternal)
  // ---------------------------------------------------------------------------

  List<SymptomHomeRemedy> getFeminaHomeRemedies(
    FeminaPhase phase,
    List<String> symptoms,
    int crampSeverity,
  ) {
    final list = <SymptomHomeRemedy>[];

    if (crampSeverity >= 2 || symptoms.contains('cramps')) {
      list.add(const SymptomHomeRemedy(
        symptom: 'Menstrual Cramps (Dysmenorrhea)',
        title: 'Ajwain-Jeera & Jaggery (Gud) Decoction',
        ingredients: ['1 tsp Ajwain', '1 tsp Jeera', '1 piece Jaggery', '2 cups water'],
        preparation: 'Boil ajwain and jeera in 2 cups water until reduced to 1 cup. Add jaggery, stir until dissolved, strain and sip warm.',
        clinicalRationale: 'Thymol in ajwain acts as a potent natural antispasmodic on uterine myometrial smooth muscle.',
        timing: 'Morning and evening during peak cramps',
        cautions: 'Drink warm, not scalding hot.',
      ));

      list.add(const SymptomHomeRemedy(
        symptom: 'Spasmodic Pelvic Pain',
        title: 'Suprapubic Warm Castor Oil Compress',
        ingredients: ['Cold-pressed Castor oil', 'Flannel cloth', 'Hot water bottle'],
        preparation: 'Warm 2 tbsp castor oil, massage onto suprapubic abdomen, cover with warm cloth and rest hot water bag for 15-20 mins.',
        clinicalRationale: 'Ricinoleic acid penetrates dermally to stimulate pelvic lymphatic flow and down-regulate prostaglandin E2.',
        timing: 'Evening while lying down',
        cautions: 'Do not use if heavy bleeding with clots is uncontrolled.',
      ));
    }

    if (symptoms.contains('bloating') || phase == FeminaPhase.luteal) {
      list.add(const SymptomHomeRemedy(
        symptom: 'Premenstrual Bloating & Water Retention',
        title: 'Cumin-Coriander-Fennel (CCF) Detox Tea',
        ingredients: ['1/2 tsp Cumin', '1/2 tsp Coriander', '1/2 tsp Fennel', '2.5 cups water'],
        preparation: 'Boil gently for 7 minutes, strain, and sip warm throughout the afternoon.',
        clinicalRationale: 'Fennel anethole relaxes gastrointestinal sphincters while coriander acts as a gentle natural diuretic.',
        timing: 'Post lunch or 4:00 PM',
        cautions: 'Safe for daily use.',
      ));
    }

    if (list.isEmpty) {
      list.add(const SymptomHomeRemedy(
        symptom: 'Daily Hormone Balance',
        title: 'Golden Turmeric & Cardamom Healing Milk',
        ingredients: ['1 cup Milk', '1/4 tsp Turmeric', '2 Cardamom pods', 'pinch of black pepper'],
        preparation: 'Simmer on low heat for 5 minutes. Sweeten lightly with raw honey or dates.',
        clinicalRationale: 'Curcumin suppresses systemic inflammatory prostaglandins and promotes restful restorative sleep.',
        timing: 'Bedtime',
        cautions: 'None.',
      ));
    }

    return list;
  }

  List<SymptomHomeRemedy> getMaternalHomeRemedies(MaternalTrimester trimester) {
    return const [
      SymptomHomeRemedy(
        symptom: 'Morning Sickness & Nausea (NVP)',
        title: 'Fresh Ginger-Lemon & Cardamom Infusion',
        ingredients: ['1/2 inch ginger', '1 green cardamom', '1 glass water', 'drops of lemon juice'],
        preparation: 'Boil ginger and elaichi in water for 5 minutes. Strain, cool slightly, add 2 drops lemon juice and sip very slowly.',
        clinicalRationale: 'Gingerol and shogaols normalize gastric dysrhythmia and block vestibular 5-HT3 serotonin receptors.',
        timing: 'First thing in morning or when nausea waves surge',
        cautions: 'Avoid excess ginger if gastric ulcer history exists.',
      ),
      SymptomHomeRemedy(
        symptom: 'Heartburn & Acid Reflux (GERD)',
        title: 'Fennel (Saunf) Overnight Cold Infusion',
        ingredients: ['1 tsp green Saunf', '1 glass room-temperature water'],
        preparation: 'Soak saunf in water overnight. Morning me strain karke sip karein, ya khane ke baad 1/2 tsp roasted saunf chabayein.',
        clinicalRationale: 'Anethole soothes esophageal lining and cools hyperacidic stomach secretions without impacting digestion.',
        timing: 'Post lunch and post dinner',
        cautions: 'Do not use sugar-coated commercial mukhwas.',
      ),
      SymptomHomeRemedy(
        symptom: 'Nocturnal Calf & Leg Cramps',
        title: 'Active Dorsiflexion Immediate Release & Epsom Soak',
        ingredients: ['Warm water bucket', '2 tbsp Epsom Salt (Magnesium Sulfate)'],
        preparation: 'Jab bhi leg me achanak cramp aaye: Leg seedha karke panje (toes) ko turant upar ghutne ki taraf kheencho (Dorsiflexion). Sone se pehle 10 min pairo ko warm water me dip karein.',
        clinicalRationale: 'Dorsiflexion actively elongates the contracting gastrocnemius muscle, terminating the neuromuscular spasm instantly.',
        timing: 'Immediate when cramp strikes; soak before bedtime',
        cautions: 'Water should be comfortably warm, not hot.',
      ),
      SymptomHomeRemedy(
        symptom: 'Pregnancy Constipation & Hemorrhoids',
        title: 'Soaked Munakka (Black Raisins) & Warm Ghee Milk',
        ingredients: ['6-8 Black Raisins (Munakka)', '1 cup warm milk', '1/2 tsp A2 Desi Cow Ghee'],
        preparation: 'Munakka ko subah paani me soak karein aur dopahar me chabakar khayein. Raat ko sone se pehle gungune doodh me 1/2 tsp ghee mila kar piyein.',
        clinicalRationale: 'Munakka sorbitol and ghee butyric acid lubricate the bowel lumen, stimulating peristalsis gently without harsh laxatives.',
        timing: 'Munakka mid-morning, Ghee milk at bedtime',
        cautions: 'If lactose intolerant, replace milk with warm water.',
      ),
      SymptomHomeRemedy(
        symptom: 'Swollen Feet & Pedal Edema',
        title: 'Lymphatic Drainage Ankle Elevation Protocol',
        ingredients: ['2 firm pillows', 'Comfortable couch or bed'],
        preparation: 'Peeth ke peeche incline support lein aur dono pairo ko 2 pillows par dil ke level se upar rakhein. 15 minute deep breathing karein.',
        clinicalRationale: 'Gravitational venous return drains accumulated extracellular interstitial fluid back to the heart and kidneys.',
        timing: 'Twice daily: 3:00 PM and 8:30 PM',
        cautions: 'If swelling suddenly appears on face and hands with headache, immediately contact doctor to rule out preeclampsia.',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Medication Schedules (Femina & Maternal)
  // ---------------------------------------------------------------------------

  List<MedicationTimingRule> getFeminaMedicationSchedule(FeminaPhase phase) {
    return const [
      MedicationTimingRule(
        name: 'Iron (Ferrous Ascorbate / Bisglycinate)',
        dosageExample: 'As prescribed by physician (e.g. 50-100mg elemental iron)',
        idealTime: 'Mid-Morning (11:00 AM) with fresh Orange / Lemon water',
        clinicalPurpose: 'Replenishes lost ferritin stores and prevents iron-deficiency microcytic anemia.',
        interactionWarning: 'CRITICAL: Never consume with Milk, Dahi, Tea, or Coffee. Calcium and polyphenols block iron absorption by 80%.',
        timingTip: 'Keep a 2-hour window before and after dairy or tea.',
        isPregnancySafe: true,
      ),
      MedicationTimingRule(
        name: 'Magnesium Glycinate',
        dosageExample: '250mg - 350mg',
        idealTime: 'Bedtime (09:45 PM)',
        clinicalPurpose: 'Relaxes uterine smooth muscles, prevents nocturnal calf cramps, and modulates GABA receptors for deep sleep.',
        interactionWarning: 'Take with half glass of water. Glycinate form avoids diarrhea seen in oxide forms.',
        timingTip: 'Take 30 minutes before turning off lights.',
        isPregnancySafe: true,
      ),
      MedicationTimingRule(
        name: 'Vitamin B6 (Pyridoxine)',
        dosageExample: '25mg - 50mg',
        idealTime: 'Morning after breakfast (09:00 AM)',
        clinicalPurpose: 'Cofactor for serotonin and dopamine synthesis; clinically proven to reduce premenstrual anxiety and fluid retention.',
        interactionWarning: 'Do not exceed 100mg daily without doctor advice.',
        timingTip: 'Best taken in the morning to prevent vivid dreaming.',
        isPregnancySafe: true,
      ),
    ];
  }

  List<MedicationTimingRule> getMaternalMedicationSchedule(
    int week,
    MaternalTrimester trimester,
  ) {
    return const [
      MedicationTimingRule(
        name: 'Thyroid Medication (Levothyroxine, if prescribed)',
        dosageExample: 'As prescribed by endocrinologist (e.g. 25mcg - 75mcg)',
        idealTime: '06:00 AM (Immediate wakeup, completely empty stomach)',
        clinicalPurpose: 'Maintains maternal euthyroid state crucial for fetal brain myelination and neurodevelopment.',
        interactionWarning: 'CRITICAL: Wait at least 45 to 60 minutes before tea, coffee, milk, or breakfast. Food reduces bioavailability by 50%.',
        timingTip: 'Keep tablet and water bottle on the nightstand.',
        isPregnancySafe: true,
      ),
      MedicationTimingRule(
        name: 'Folic Acid / Methylfolate',
        dosageExample: '5mg or 400 - 800mcg daily',
        idealTime: '08:30 AM (With breakfast)',
        clinicalPurpose: 'Closes fetal neural tube in Weeks 1 to 12, preventing Spina Bifida and Anencephaly.',
        interactionWarning: 'Safe with all breakfast foods. Continue through Trimester 1.',
        timingTip: 'Take consistently every morning with your first meal.',
        isPregnancySafe: true,
      ),
      MedicationTimingRule(
        name: 'Calcium + Vitamin D3',
        dosageExample: '500mg - 1000mg elemental calcium + 400IU D3',
        idealTime: '01:30 PM (With lunch or breakfast)',
        clinicalPurpose: 'Mineralizes baby\'s 206 developing bones and teeth; protects mother against dental and bone demineralization.',
        interactionWarning: 'CRITICAL INVARIANT: NEVER take Calcium and Iron together! Keep at least a 2 to 3-hour time gap. Calcium blocks iron transporter channels.',
        timingTip: 'Best taken with food for optimal stomach acid dissolution.',
        isPregnancySafe: true,
      ),
      MedicationTimingRule(
        name: 'Iron (Ferrous Ascorbate / Bisglycinate)',
        dosageExample: '60mg - 100mg elemental iron daily',
        idealTime: '04:30 PM (Evening with fresh Lemon or Orange juice)',
        clinicalPurpose: 'Prevents maternal gestational anemia, low birth weight, and postpartum hemorrhage.',
        interactionWarning: 'CRITICAL: NEVER take Calcium and Iron together (keep a 2 to 3-hour time gap). Vitamin C multiplies absorption. Never take with Dairy (Milk/Curd), Tea, or Coffee. High tannins bind iron into insoluble salts.',
        timingTip: 'Take 2 hours after lunch and 2 hours before dinner.',
        isPregnancySafe: true,
      ),
      MedicationTimingRule(
        name: 'Prenatal Omega-3 DHA',
        dosageExample: '200mg - 300mg DHA',
        idealTime: '08:30 PM (With or immediately after dinner)',
        clinicalPurpose: 'Builds fetal cerebral cortex neurons and retinal photoreceptors during Trimester 2 & 3.',
        interactionWarning: 'Fat-soluble; best absorbed when taken with dinner containing healthy fats (ghee/olive oil).',
        timingTip: 'Taking at dinner also prevents fishy burps during daytime.',
        isPregnancySafe: true,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Partner Guidance & Empathy Companion
  // ---------------------------------------------------------------------------

  PartnerEmpathyGuide getFeminaPartnerGuide(FeminaPhase phase, int cycleDay) {
    switch (phase) {
      case FeminaPhase.menstrual:
        return PartnerEmpathyGuide(
          phaseOrTrimester: 'Menstrual Phase (Period Bleeding)',
          emotionalContext: 'Estrogen and progesterone drop to baseline levels; prostaglandins trigger uterine cramping, pelvic congestion, fatigue, and lower dopamine.',
          whatSheNeedsMost: 'Deep physical warmth, emotional safety, proactive help with chores, and zero pressure for high-energy activities.',
          dosList: const [
            'Bring her a hot water bag or heating pad without waiting to be asked.',
            'Prepare a warm cup of Ginger-Jaggery tea or Golden Haldi milk.',
            'Take care of dinner, kitchen cleaning, or grocery runs proactively.',
            'Offer gentle lower-back or foot massages with warm almond/sesame oil.',
            'Remind her she is cherished, loved, and safe to rest.',
          ],
          dontsList: const [
            'NEVER say "Tum itna chidchid kyu kar rahi ho?" or minimize her pain.',
            'Don\'t initiate arguments or take temporary quietness personally.',
            'Don\'t offer cold drinks or icy treats that cause uterine vasoconstriction.',
            'Don\'t push her to attend crowded social gatherings if she feels depleted.',
          ],
          suggestedGiftsAndCare: const [
            {
              'item': '70%+ Dark Chocolate Artisan Box',
              'whyItHelps': 'High bioavailable magnesium releases uterine spasms and naturally elevates brain endorphins.',
            },
            {
              'item': 'Electric Heating Pad / Hot Water Bag',
              'whyItHelps': 'Continuous suprapubic warmth dilates pelvic micro-vessels, slashing cramp pain by up to 40%.',
            },
            {
              'item': 'Organic Chamomile & Lavender Sleep Infusion',
              'whyItHelps': 'Soothes autonomic nervous tension and promotes uninterrupted deep delta sleep.',
            },
            {
              'item': 'Fuzzy Warm Cotton Bed Socks',
              'whyItHelps': 'Warming peripheral extremities redirects blood flow and relieves deep pelvic congestion.',
            },
          ],
          readyToShareMessage: 'Hey love! ❤️ Just a gentle heads-up from VYRA: Today is Day $cycleDay of my menstrual cycle. Hormones are at baseline and cramps might be high. A hot water bag, dark chocolate, and an extra long hug would mean the absolute world to me right now! 🥰✨',
        );

      case FeminaPhase.follicular:
        return const PartnerEmpathyGuide(
          phaseOrTrimester: 'Follicular Phase (Rising Stamina)',
          emotionalContext: 'Estrogen levels are steadily rising; brain neurochemistry is primed for curiosity, optimism, social bonding, and high energy.',
          whatSheNeedsMost: 'Shared adventures, engaging conversations, fitness partnership, and enthusiasm for new ideas.',
          dosList: [
            'Plan a romantic outdoor date or brisk evening walk together.',
            'Encourage her fitness goals and join her for workouts or runs.',
            'Cook fresh, colorful, high-protein meals together.',
            'Support her passions, projects, and creative brainstorming.',
          ],
          dontsList: [
            'Don\'t hold her back from ambitious workout or work milestones.',
            'Don\'t let routine get stagnant; her brain thrives on novelty right now.',
          ],
          suggestedGiftsAndCare: [
            {
              'item': 'Fresh Seasonal Flower Bouquet (Lilies / Roses)',
              'whyItHelps': 'Celebrates her blossoming energy and lifts home aesthetic dopamine.',
            },
            {
              'item': 'Electrolyte Sipper or Stylish Gym Bottle',
              'whyItHelps': 'Supports her peak athletic workout hydration.',
            },
          ],
          readyToShareMessage: 'Hey partner! 🌸 My energy is rising and I am in the Follicular phase! Feeling motivated, strong, and ready for adventure. Let\'s do something fun or go for a workout together tonight! 💃✨',
        );

      case FeminaPhase.ovulatory:
        return const PartnerEmpathyGuide(
          phaseOrTrimester: 'Ovulatory Phase (Peak Glow & Vitality)',
          emotionalContext: 'Estrogen and testosterone hit their monthly peak; maximum confidence, verbal eloquence, social magnetism, and peak fertility.',
          whatSheNeedsMost: 'Romantic presence, verbal compliments, affection, and active quality time together.',
          dosList: [
            'Take her out on a special romantic dinner date.',
            'Give heartfelt compliments on her beauty, intellect, and grace.',
            'Be fully present without phone distractions.',
            'Enjoy active high-energy workouts or sports together.',
          ],
          dontsList: [
            'Don\'t be emotionally distant or unresponsive.',
            'Don\'t forget that this is the biological fertile window if planning conception.',
          ],
          suggestedGiftsAndCare: [
            {
              'item': 'Aromatherapy Floral Perfume / Rose Water Mist',
              'whyItHelps': 'Complements her natural ovulatory pheromones and high sensory awareness.',
            },
            {
              'item': 'Artisan Fruit & Berry Platter',
              'whyItHelps': 'Glutathione and antioxidants protect cellular vitality.',
            },
          ],
          readyToShareMessage: 'Hey sweetheart! 💖 I am in my peak Ovulatory phase today! Feeling radiant, happy, and energized. Looking forward to spending some romantic quality time together tonight! 🥰🍷',
        );

      case FeminaPhase.luteal:
        return const PartnerEmpathyGuide(
          phaseOrTrimester: 'Luteal Phase (PMS & Emotional Sensitivity)',
          emotionalContext: 'Progesterone surges and then fluctuates; serotonin dips while core body temperature rises 0.5°C. Emotional sensitivity, bloating, and fatigue are biologically real.',
          whatSheNeedsMost: 'Compassionate listening without problem-solving, quiet comforting presence, and zero judgment for craving carbs or quiet rest.',
          dosList: [
            'Listen attentively to her day without jumping to analyze or criticize.',
            'Surprise her with warm, comforting meals (moong dal khichdi, comforting soup).',
            'Draw a warm bath or prepare an Epsom salt foot soak for her swollen ankles.',
            'Keep bedroom cool and dark at night to counter progesterone night heat.',
            'Offer gentle reassurance: "You are doing great, and I am here for you."',
          ],
          dontsList: [
            'NEVER say "Tumhara period aane wala hai kya?" in an irritated tone.',
            'Don\'t dismiss tears or frustration as "just hormones".',
            'Don\'t bring high-sodium salty chips or fast food that triggers painful puffiness.',
            'Don\'t start stressful financial or contentious arguments right now.',
          ],
          suggestedGiftsAndCare: [
            {
              'item': 'Lavender Essential Oil Pillow Spray',
              'whyItHelps': 'Promotes deep restorative sleep despite progesterone-induced micro-awakenings.',
            },
            {
              'item': 'Soft Sherpa Weighted Blanket',
              'whyItHelps': 'Provides comforting somatic grounding that relieves pre-menstrual sensory overload.',
            },
            {
              'item': 'Basket of Ripe Bananas, Fresh Figs & Dark Cocoa',
              'whyItHelps': 'Supplies high potassium and vitamin B6 to clear bloating and lift mood.',
            },
          ],
          readyToShareMessage: 'Hey partner! 💕 Just letting you know that my Luteal/PMS phase is active right now. Progesterone shifts can make me feel emotionally sensitive, tired, and bloated. A listening ear, a warm dinner, and a calm hug tonight would be pure magic! Love you! 🥰🛋️',
        );
    }
  }

  PartnerEmpathyGuide getMaternalPartnerGuide(
    int week,
    MaternalTrimester trimester,
  ) {
    if (trimester == MaternalTrimester.first) {
      return PartnerEmpathyGuide(
        phaseOrTrimester: '1st Trimester • Organogenesis & Morning Nausea',
        emotionalContext: 'Maternal hCG and progesterone are surging exponentially; severe morning sickness, extreme fatigue, breast tenderness, and anxiety about early pregnancy stability are very common.',
        whatSheNeedsMost: 'Gentle patience, help with meals and smells she can\'t tolerate, bedside morning crackers before she stands up, and loving reassurance.',
        dosList: const [
          'Keep dry crackers or roasted chana on her nightstand every single night so she can eat before standing up.',
          'Take over cooking when tadka, onion, or garlic smells trigger nausea.',
          'Ensure she takes Folic Acid daily with breakfast.',
          'Attend first trimester doctor visits and ultrasound dating scans with her.',
          'Let her rest whenever fatigue strikes — her body is building an entire organ (the placenta)!',
        ],
        dontsList: const [
          'Don\'t force her to eat foods she feels strongly nauseous about.',
          'Don\'t let her lift heavy grocery bags or move heavy furniture.',
          'Don\'t bring strong artificial perfumes or room sprays around her.',
          'Don\'t let her forget her Folic Acid tablet.',
        ],
        suggestedGiftsAndCare: const [
          {
            'item': 'Morning Nausea Rescue Box (Ginger drops, Cardamom, Marie biscuits)',
            'whyItHelps': 'Immediately curbs gastric nausea and morning hyperacidity.',
          },
          {
            'item': 'U-Shaped Ergonomic Maternity Body Pillow',
            'whyItHelps': 'Supports expanding pelvic bones and enables comfortable side sleep.',
          },
        ],
        readyToShareMessage: 'Hey papa-to-be! 🤰 Baby is at Week $week right now! Morning nausea and tiredness are quite real today. Could you please bring me a glass of warm lemon water and some bedside crackers? Your support means everything to our little family! Love you! 👶❤️✨',
      );
    } else {
      return PartnerEmpathyGuide(
        phaseOrTrimester: trimester == MaternalTrimester.second
            ? '2nd Trimester • Golden Growth & Vitality'
            : '3rd Trimester • Final Maturation & Delivery Prep',
        emotionalContext: 'Belly is expanding rapidly; relaxin hormone softens ligaments causing lower back pain, pelvic girdle ache, and leg cramps. Baby kicks actively!',
        whatSheNeedsMost: 'Daily foot and calf massage, help arranging sleeping pillows on her LEFT side, hydration reminders, and nesting partnership.',
        dosList: const [
          'Give her a 15-minute soothing foot and calf massage every night to prevent painful cramps.',
          'Help arrange pillows so she comfortably sleeps on her LEFT side (SOS).',
          'Participate in fetal kick counting sessions (feel the baby kick together!).',
          'Ensure her Iron and Calcium tablets are taken with at least a 2-hour gap.',
          'Pack the hospital maternity delivery bag together ahead of time.',
        ],
        dontsList: const [
          'NEVER let her sleep flat on her back (supine) after Week 16 — it compresses the Inferior Vena Cava!',
          'Don\'t ignore sudden hand or facial swelling or severe headaches (check blood pressure).',
          'Don\'t let her stand on her feet for hours without resting.',
        ],
        suggestedGiftsAndCare: const [
          {
            'item': 'Whipped Shea Butter & Almond Belly Stretch Balm',
            'whyItHelps': 'Deeply nourishes expanding belly skin and relieves stretching itching.',
          },
          {
            'item': 'Epsom Salt Foot Spa Soak Basin',
            'whyItHelps': 'Drains third-trimester fluid retention from swollen ankles and feet.',
          },
          {
            'item': 'Maternity Hospital Bag Packing Organizer Kit',
            'whyItHelps': 'Eliminates last-minute delivery panic with organized clothes and baby essentials.',
          },
        ],
        readyToShareMessage: 'Hey love! 🤰 Week $week update from baby and me: Baby is kicking up a storm today! My back and feet are feeling quite heavy. A 10-minute foot massage and help tucking in my sleep pillows tonight would make you my absolute superhero! See you soon! 👶❤️✨',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Smart Watch Biometric Telemetry Sync
  // ---------------------------------------------------------------------------

  SmartWatchBiometricSync getFeminaSmartWatchSync(FeminaPhase phase) {
    switch (phase) {
      case FeminaPhase.menstrual:
        return const SmartWatchBiometricSync(
          restingHeartRateBpm: 66,
          skinTemperatureOffsetCelsius: -0.1,
          heartRateVariabilityMs: 58,
          bloodOxygenSpo2: 99,
          sleepDurationHours: 8.8,
          deepSleepMinutes: 115,
          biphasicOvulationConfirmed: false,
          biometricInsight: 'Baseline temperature restored after luteal decline. Elevated parasympathetic recovery indicates safe window for gentle restorative movement.',
        );
      case FeminaPhase.follicular:
        return const SmartWatchBiometricSync(
          restingHeartRateBpm: 64,
          skinTemperatureOffsetCelsius: 0.0,
          heartRateVariabilityMs: 65,
          bloodOxygenSpo2: 99,
          sleepDurationHours: 7.8,
          deepSleepMinutes: 98,
          biphasicOvulationConfirmed: false,
          biometricInsight: 'High HRV and low resting heart rate indicate peak athletic capacity and autonomic nervous readiness for intense training.',
        );
      case FeminaPhase.ovulatory:
        return const SmartWatchBiometricSync(
          restingHeartRateBpm: 68,
          skinTemperatureOffsetCelsius: 0.2,
          heartRateVariabilityMs: 60,
          bloodOxygenSpo2: 99,
          sleepDurationHours: 7.5,
          deepSleepMinutes: 90,
          biphasicOvulationConfirmed: true,
          biometricInsight: 'Watch sensors detect initial +0.2°C skin temperature inflection and subtle resting HR elevation, confirming active luteinizing hormone (LH) surge.',
        );
      case FeminaPhase.luteal:
        return const SmartWatchBiometricSync(
          restingHeartRateBpm: 72,
          skinTemperatureOffsetCelsius: 0.45,
          heartRateVariabilityMs: 48,
          bloodOxygenSpo2: 98,
          sleepDurationHours: 8.5,
          deepSleepMinutes: 80,
          biphasicOvulationConfirmed: true,
          biometricInsight: 'Sustained +0.45°C Basal Body Temperature elevation and lower HRV confirm active post-ovulatory corpus luteum progesterone dominance.',
        );
    }
  }

  SmartWatchBiometricSync getMaternalSmartWatchSync(
    int week,
    MaternalTrimester trimester,
  ) {
    final isLate = week >= 28;
    return SmartWatchBiometricSync(
      restingHeartRateBpm: isLate ? 76 : 72,
      skinTemperatureOffsetCelsius: 0.48,
      heartRateVariabilityMs: 46,
      bloodOxygenSpo2: 99,
      sleepDurationHours: 8.6,
      deepSleepMinutes: 85,
      biphasicOvulationConfirmed: true,
      biometricInsight: 'Sustained +0.48°C elevated skin temperature and healthy +8-10 bpm resting heart rate elevation confirm 40% increased maternal circulatory plasma volume and robust gestational health.',
    );
  }

  // ---------------------------------------------------------------------------
  // Default Care Reminders
  // ---------------------------------------------------------------------------

  List<CareReminderItem> getDefaultReminders(
    bool isPregnancy, {
    FeminaPhase? phase,
    int? week,
    MaternalTrimester? trimester,
  }) {
    if (isPregnancy) {
      final curWeek = week ?? 20;
      final curTri = trimester ?? MaternalTrimester.second;
      return [
        const CareReminderItem(
          id: 'mat_rem_thyroid',
          category: 'medication',
          title: 'Thyroid Medication (Empty Stomach)',
          timeSlot: '06:00 AM',
          isEnabled: false,
          repeatDaily: true,
          notes: 'Take with plain water 45 mins before tea or breakfast.',
        ),
        const CareReminderItem(
          id: 'mat_rem_crackers',
          category: 'meal',
          title: 'Bedside Dry Crackers / Roasted Chana',
          timeSlot: '06:45 AM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'Eat 2-3 bites before lifting head from pillow to stop nausea.',
        ),
        CareReminderItem(
          id: 'mat_rem_folic_or_calcium',
          category: 'medication',
          title: curTri == MaternalTrimester.first
              ? 'Folic Acid Supplement (5mg)'
              : 'Calcium + Vitamin D3 (500mg)',
          timeSlot: '08:30 AM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'Take with breakfast food for optimal absorption.',
        ),
        const CareReminderItem(
          id: 'mat_rem_fruit_coconut',
          category: 'hydration',
          title: 'Pomegranate / Apple + Tender Coconut Water',
          timeSlot: '11:00 AM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'Supports healthy Amniotic Fluid Index (AFI) and iron levels.',
        ),
        const CareReminderItem(
          id: 'mat_rem_sos_nap',
          category: 'rest',
          title: 'SOS Left-Side Circulation Rest (30 mins)',
          timeSlot: '02:30 PM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'Relieves Inferior Vena Cava pressure; elevate feet on pillow.',
        ),
        const CareReminderItem(
          id: 'mat_rem_iron',
          category: 'medication',
          title: 'Iron Supplement (with Lemon Water)',
          timeSlot: '04:30 PM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'NEVER take with milk, curd, tea or coffee. Keep 2h gap from calcium.',
        ),
        CareReminderItem(
          id: 'mat_rem_kick_count',
          category: 'checkup',
          title: 'Fetal Kick Count Session (10 movements)',
          timeSlot: '08:00 PM',
          isEnabled: curWeek >= 24,
          repeatDaily: true,
          notes: 'Lie on left side after dinner and count baby movements.',
        ),
        const CareReminderItem(
          id: 'mat_rem_sleep_posture',
          category: 'rest',
          title: 'Left-Side 3-Pillow Sleep Setup & Kesar Milk',
          timeSlot: '09:45 PM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'Pillow between knees, wedge under belly. Never sleep flat on back.',
        ),
      ];
    } else {
      final curPhase = phase ?? FeminaPhase.menstrual;
      return [
        const CareReminderItem(
          id: 'fem_rem_wake_hydration',
          category: 'hydration',
          title: 'Morning Warm Herbal Hydration',
          timeSlot: '07:00 AM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'Warm water with ginger/ajwain or lemon-chia for gut circulation.',
        ),
        const CareReminderItem(
          id: 'fem_rem_breakfast',
          category: 'meal',
          title: 'Bioavailable Protein & Micronutrient Breakfast',
          timeSlot: '08:30 AM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'Cheela / sprouted moong / dalia aligned with cycle phase.',
        ),
        const CareReminderItem(
          id: 'fem_rem_fruit_seeds',
          category: 'meal',
          title: 'Mid-Morning Fruit Therapy & Seed Cycling',
          timeSlot: '11:00 AM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'Pomegranate/Flax in Phase 1, or Banana/Sesame in Phase 2.',
        ),
        CareReminderItem(
          id: 'fem_rem_iron_supplement',
          category: 'medication',
          title: 'Iron Supplement (with Lemon Water)',
          timeSlot: '04:00 PM',
          isEnabled: curPhase == FeminaPhase.menstrual,
          repeatDaily: true,
          notes: 'Keep 2 hours away from tea, coffee, milk and calcium.',
        ),
        const CareReminderItem(
          id: 'fem_rem_evening_asana',
          category: 'rest',
          title: 'Restorative Asana & Pelvic Relax Time',
          timeSlot: '05:30 PM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'Child\'s pose, Supta Baddha Konasana, or brisk walk.',
        ),
        const CareReminderItem(
          id: 'fem_rem_magnesium_sleep',
          category: 'medication',
          title: 'Magnesium Glycinate & Golden Milk',
          timeSlot: '09:45 PM',
          isEnabled: true,
          repeatDaily: true,
          notes: 'Relaxes smooth uterine muscles for deep restorative sleep.',
        ),
      ];
    }
  }
}
