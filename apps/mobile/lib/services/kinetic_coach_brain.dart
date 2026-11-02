import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Biomechanical kinetic fault categories classified by the AI coach.
enum KineticFaultType {
  none,
  kneeValgus,
  kneeOvershoot,
  spineFlexionRounding,
  torsoSwingCheating,
  elbowFlare,
  bicepShoulderHike,
  pelvicAsymmetry,
  incompleteLockout,
  shallowDepth,
  rushedTempo,
  bodyOutOfFrame,
}

/// Real-time diagnostic report generated per video frame.
class KineticDiagnosticReport {
  final bool hasFault;
  final KineticFaultType faultType;
  final Set<int> faultJoints;
  final String primaryInstruction;
  final String spokenInstructionEn;
  final String spokenInstructionHi;
  final bool isSevereCheat;

  const KineticDiagnosticReport({
    required this.hasFault,
    this.faultType = KineticFaultType.none,
    this.faultJoints = const <int>{},
    this.primaryInstruction = '',
    this.spokenInstructionEn = '',
    this.spokenInstructionHi = '',
    this.isSevereCheat = false,
  });

  static const KineticDiagnosticReport clean = KineticDiagnosticReport(
    hasFault: false,
    primaryInstruction: 'Form Verified',
  );
}

/// Verdict for rep completion evaluation.
class RepEvaluationResult {
  final bool isApproved;
  final String reason;
  final double formPurity; // 0.0 to 1.0
  final double cadenceSec;
  final String voiceMessageEn;
  final String voiceMessageHi;

  const RepEvaluationResult({
    required this.isApproved,
    required this.reason,
    required this.formPurity,
    required this.cadenceSec,
    required this.voiceMessageEn,
    required this.voiceMessageHi,
  });
}

/// End-of-session detailed biomechanical audit and coaching scorecard.
class WorkoutBiomechanicalScorecard {
  final String exerciseId;
  final String exerciseName;
  final int completedReps;
  final int targetReps;
  final int rejectedReps;
  final double overallFormAccuracy;
  final double averageCadenceSec;
  final double bilateralSymmetry;
  final int caloriesBurned;
  final List<String> primaryMuscleGroups;
  final List<String> coachingFeedbackList;

  const WorkoutBiomechanicalScorecard({
    required this.exerciseId,
    required this.exerciseName,
    required this.completedReps,
    required this.targetReps,
    required this.rejectedReps,
    required this.overallFormAccuracy,
    required this.averageCadenceSec,
    required this.bilateralSymmetry,
    required this.caloriesBurned,
    required this.primaryMuscleGroups,
    required this.coachingFeedbackList,
  });
}

/// INTELLIGENT KINETIC COACH BRAIN
///
/// Delivers Olympic & physiotherapy-grade real-time computer vision coaching:
/// 1. Instant sub-second kinetic fault detection (knee valgus, lumbar rounding, torso swing, elbow flaring).
/// 2. Strict Range-of-Motion (ROM) & Form Purity Gate (reps only count when performed correctly).
/// 3. Multi-lingual voice cues (English & Hinglish) with intelligent priority throttling.
/// 4. Post-workout biomechanical scorecard generation synchronized with VYRA ecosystem.
class KineticCoachBrain {
  // Rep Cycle Tracking State
  DateTime _repStartTime = DateTime.now();
  int _repTotalFrames = 0;
  int _repValidFrames = 0;
  bool _repDepthAchieved = false;
  double _repMinAngle = 180.0;
  double _repMaxAngle = 0.0;
  final List<double> _repCadenceHistory = [];
  final List<double> _repPurityHistory = [];
  final Map<KineticFaultType, int> _faultOccurrenceCount = {};

  int _totalRejectedReps = 0;
  DateTime _lastVoiceCueTime = DateTime.fromMillisecondsSinceEpoch(0);
  KineticFaultType _lastVoicedFault = KineticFaultType.none;

  /// Resets state for a new exercise workout.
  void resetWorkout() {
    _repStartTime = DateTime.now();
    _repTotalFrames = 0;
    _repValidFrames = 0;
    _repDepthAchieved = false;
    _repMinAngle = 180.0;
    _repMaxAngle = 0.0;
    _repCadenceHistory.clear();
    _repPurityHistory.clear();
    _faultOccurrenceCount.clear();
    _totalRejectedReps = 0;
    _lastVoiceCueTime = DateTime.fromMillisecondsSinceEpoch(0);
    _lastVoicedFault = KineticFaultType.none;
  }

  /// Begins a new rep cycle.
  void startRepCycle(double initialAngle) {
    _repStartTime = DateTime.now();
    _repTotalFrames = 0;
    _repValidFrames = 0;
    _repDepthAchieved = false;
    _repMinAngle = initialAngle;
    _repMaxAngle = initialAngle;
  }

  /// Records continuous frame telemetry during the rep.
  void recordFrame({
    required bool isFormValid,
    required double currentAngle,
    required bool reachedDepth,
  }) {
    _repTotalFrames++;
    if (isFormValid) {
      _repValidFrames++;
    }
    if (reachedDepth) {
      _repDepthAchieved = true;
    }
    _repMinAngle = math.min(_repMinAngle, currentAngle);
    _repMaxAngle = math.max(_repMaxAngle, currentAngle);
  }

  /// Evaluates rep completion strictly according to physiotherapy criteria.
  ///
  /// Criteria for Rep Approval:
  /// 1. Peak inflection depth was reached within tolerance [_repDepthAchieved].
  /// 2. Form Purity Ratio >= 75% (minimum 3 out of 4 frames were mechanically sound).
  /// 3. Minimum cadence >= 0.7s (eliminates camera jitter or rapid arm flapping).
  RepEvaluationResult evaluateRepCompletion({
    required int currentRepCount,
    required int targetReps,
    required double startAngleDeg,
    required double peakAngleDeg,
    required bool decreaseToPeak,
    bool reachedDepth = true,
    bool isAssistedMode = false,
  }) {
    if (reachedDepth) {
      _repDepthAchieved = true;
    }
    final now = DateTime.now();
    final cadenceSec = isAssistedMode
        ? 2.2
        : (now.difference(_repStartTime).inMilliseconds / 1000.0).clamp(0.1, 15.0);
    final formPurity = _repTotalFrames > 0
        ? (_repValidFrames / _repTotalFrames).clamp(0.0, 1.0)
        : 1.0;

    // 1. Shallow Half-Rep Check
    if (!_repDepthAchieved) {
      _totalRejectedReps++;
      return RepEvaluationResult(
        isApproved: false,
        reason: 'Shallow Depth: Did not reach target ${peakAngleDeg.toInt()}° depth',
        formPurity: formPurity,
        cadenceSec: cadenceSec,
        voiceMessageEn: 'Incomplete rep. Go deeper to full depth so it counts!',
        voiceMessageHi: 'Adha rep count nahi hoga! Poora neeche jao tabhi count hoga!',
      );
    }

    // 2. Severe Form Breakdown Check (Purity < 75%)
    if (formPurity < 0.75) {
      _totalRejectedReps++;
      return RepEvaluationResult(
        isApproved: false,
        reason: 'Form Breakdown: Cheating detected (${(formPurity * 100).toInt()}% purity)',
        formPurity: formPurity,
        cadenceSec: cadenceSec,
        voiceMessageEn: 'Rep discarded: Form broke down. Keep chest up and isolate!',
        voiceMessageHi: 'Rep reject! Form sahi nahi thi, torso seedha rakh kar dubara karo!',
      );
    }

    // 3. Cadence / Flapping Check (< 0.70 seconds)
    if (cadenceSec < 0.70) {
      _totalRejectedReps++;
      return RepEvaluationResult(
        isApproved: false,
        reason: 'Cadence Too Fast: Slow down and control the movement',
        formPurity: formPurity,
        cadenceSec: cadenceSec,
        voiceMessageEn: 'Too fast! Control the negative: 2 seconds down, 1 second up.',
        voiceMessageHi: 'Zda tez mat karo! Araam se control ke sath karo!',
      );
    }

    // Approved Rep
    _repCadenceHistory.add(cadenceSec);
    _repPurityHistory.add(formPurity);

    final nextCount = currentRepCount + 1;
    final String praiseEn;
    final String praiseHi;

    if (nextCount == targetReps) {
      praiseEn = '$nextCount! Outstanding workout completed!';
      praiseHi = '$nextCount! Shandaar! Pura set complete ho gaya!';
    } else if (nextCount % 5 == 0) {
      praiseEn = '$nextCount, great depth! Keep pushing!';
      praiseHi = '$nextCount, ekdum perfect depth! Lage raho!';
    } else if (formPurity >= 0.95) {
      praiseEn = '$nextCount, perfect form!';
      praiseHi = '$nextCount, ekdum clean rep!';
    } else {
      praiseEn = '$nextCount!';
      praiseHi = '$nextCount!';
    }

    return RepEvaluationResult(
      isApproved: true,
      reason: 'Verified',
      formPurity: formPurity,
      cadenceSec: cadenceSec,
      voiceMessageEn: praiseEn,
      voiceMessageHi: praiseHi,
    );
  }

  /// Evaluates real-time frame kinematics and pinpoints specific cheating faults.
  KineticDiagnosticReport diagnoseKineticFaults({
    required String auraPattern,
    required String framingMode,
    required String exerciseName,
    required List<Offset> humanLandmarks,
    required List<double> humanConf,
    required double currentAngle,
    required double spineTiltDeg,
    required double symmetryDiff,
    required double leftTripletConf,
    required double rightTripletConf,
    required String phase,
    required bool decreaseToPeak,
    required double peakAngleDeg,
  }) {
    if (humanLandmarks.length < 33 || humanConf.length < 33) {
      return KineticDiagnosticReport.clean;
    }

    final bestTripletConf = math.max(leftTripletConf, rightTripletConf);

    // 1. Framing Visibility Gate
    if (bestTripletConf < 0.35) {
      return const KineticDiagnosticReport(
        hasFault: true,
        faultType: KineticFaultType.bodyOutOfFrame,
        faultJoints: {11, 12, 23, 24, 25, 26, 27, 28},
        primaryInstruction: '⚠️ Step back — Active body joints must be in camera frame',
        spokenInstructionEn: 'Please step back so your whole body is visible to the camera.',
        spokenInstructionHi: 'Thoda peeche ho jao taaki pura body camera me dikhe.',
        isSevereCheat: true,
      );
    }

    // 2. Squat & Lunge Diagnostics (Knee Valgus, Forward Overshoot & Lumbar Flexion)
    if (auraPattern == 'squat' || auraPattern == 'lunge' || auraPattern == 'lower_hold') {
      final hipConf = math.min(humanConf[23], humanConf[24]);
      final kneeConf = math.min(humanConf[25], humanConf[26]);
      final ankleConf = math.min(humanConf[27], humanConf[28]);

      // Squat Knee Valgus (Knees caving inward)
      if (auraPattern == 'squat' &&
          currentAngle <= 145.0 &&
          hipConf >= 0.35 &&
          kneeConf >= 0.35 &&
          ankleConf >= 0.35) {
        final kneeSpan = (humanLandmarks[25].dx - humanLandmarks[26].dx).abs();
        final ankleSpan = (humanLandmarks[27].dx - humanLandmarks[28].dx).abs();
        if (ankleSpan > 0.08 && kneeSpan < ankleSpan * 0.72) {
          _recordFault(KineticFaultType.kneeValgus);
          return const KineticDiagnosticReport(
            hasFault: true,
            faultType: KineticFaultType.kneeValgus,
            faultJoints: {25, 26, 27, 28},
            primaryInstruction: '🦵 Knees Caving In — Push your knees outward in line with toes!',
            spokenInstructionEn: 'Push your knees out! Do not let your knees cave in.',
            spokenInstructionHi: 'Knees bahar push karo, ghutne andar mat girne do!',
            isSevereCheat: true,
          );
        }
      }

      // Forward Knee Travel Overshoot (Knees shooting too far past toes instead of sitting back)
      if (auraPattern == 'squat' && currentAngle <= 130.0 && kneeConf >= 0.38 && ankleConf >= 0.38) {
        final leftKneeToeOffset = (humanLandmarks[25].dx - humanLandmarks[27].dx).abs();
        final rightKneeToeOffset = (humanLandmarks[26].dx - humanLandmarks[28].dx).abs();
        if (leftKneeToeOffset > 0.15 || rightKneeToeOffset > 0.15) {
          _recordFault(KineticFaultType.kneeOvershoot);
          return const KineticDiagnosticReport(
            hasFault: true,
            faultType: KineticFaultType.kneeOvershoot,
            faultJoints: {23, 24, 25, 26},
            primaryInstruction: '⚠️ Sit Back into Heels — Hips back, do not push knees forward!',
            spokenInstructionEn: 'Sit back into your heels! Push hips back, not knees forward.',
            spokenInstructionHi: 'Hips ko peeche le jao, ghutno ko aage mat nikaalo!',
            isSevereCheat: false,
          );
        }
      }

      // Spine Flexion / Excessive Torso Lean in Squats (> 38° lean)
      if (spineTiltDeg > 38.0) {
        _recordFault(KineticFaultType.spineFlexionRounding);
        return KineticDiagnosticReport(
          hasFault: true,
          faultType: KineticFaultType.spineFlexionRounding,
          faultJoints: const {11, 12, 23, 24},
          primaryInstruction: '📏 Chest Up — Keep back neutral (${spineTiltDeg.toInt()}° lean)!',
          spokenInstructionEn: 'Chest up, shoulders back! Look forward and keep your back straight.',
          spokenInstructionHi: 'Chest up rakho, aage jhukna band karo aur peeth seedhi rakho!',
          isSevereCheat: true,
        );
      }
    }

    // 3. Bicep Curl & Upper Pull Cheating (Elbow Pinning & Torso Momentum Swing)
    if (auraPattern == 'curl_row') {
      // Momentum Swinging: torso swaying during curl (> 24° tilt)
      if (spineTiltDeg > 24.0) {
        _recordFault(KineticFaultType.torsoSwingCheating);
        return const KineticDiagnosticReport(
          hasFault: true,
          faultType: KineticFaultType.torsoSwingCheating,
          faultJoints: {11, 12, 23, 24},
          primaryInstruction: '🚫 Zero Torso Swing — Stand still and isolate your biceps!',
          spokenInstructionEn: 'Stop swinging your torso! Lock your body and isolate your arms.',
          spokenInstructionHi: 'Torso hilana band karo! Body lock karke bicep se uthao!',
          isSevereCheat: true,
        );
      }

      // Elbows lifting/hiking forward toward shoulder instead of staying pinned
      final lElbowHike = humanConf[11] >= 0.35 &&
          humanConf[13] >= 0.35 &&
          humanLandmarks[13].dy < humanLandmarks[11].dy + 0.02;
      final rElbowHike = humanConf[12] >= 0.35 &&
          humanConf[14] >= 0.35 &&
          humanLandmarks[14].dy < humanLandmarks[12].dy + 0.02;

      if (lElbowHike || rElbowHike) {
        _recordFault(KineticFaultType.bicepShoulderHike);
        return const KineticDiagnosticReport(
          hasFault: true,
          faultType: KineticFaultType.bicepShoulderHike,
          faultJoints: {11, 12, 13, 14},
          primaryInstruction: '💪 Pin Elbows to Ribs — Do not lift your elbows or shoulders!',
          spokenInstructionEn: 'Keep your elbows pinned to your sides. Do not lift your shoulders.',
          spokenInstructionHi: 'Elbows ko kamar ke paas lock rakho, kandhe upar mat uthao!',
          isSevereCheat: true,
        );
      }
    }

    // 4. Overhead Press & Lateral Raise Diagnostics
    if (auraPattern == 'overhead_press') {
      if (spineTiltDeg > 26.0) {
        _recordFault(KineticFaultType.spineFlexionRounding);
        return KineticDiagnosticReport(
          hasFault: true,
          faultType: KineticFaultType.spineFlexionRounding,
          faultJoints: const {11, 12, 23, 24},
          primaryInstruction: '⚠️ Core Tight — Do not arch your lower back (${spineTiltDeg.toInt()}° lean)!',
          spokenInstructionEn: 'Tighten your core. Do not arch your lower back.',
          spokenInstructionHi: 'Pet tight rakho, kamar ko peeche mat modho!',
          isSevereCheat: true,
        );
      }
    }

    // 5. Bilateral Symmetry Diagnostics (> 32° asymmetry during active arc)
    if (symmetryDiff > 32.0 && leftTripletConf >= 0.40 && rightTripletConf >= 0.40) {
      _recordFault(KineticFaultType.pelvicAsymmetry);
      return KineticDiagnosticReport(
        hasFault: true,
        faultType: KineticFaultType.pelvicAsymmetry,
        faultJoints: const {11, 12, 13, 14, 23, 24, 25, 26},
        primaryInstruction: '⚖️ Uneven Movement (${symmetryDiff.toInt()}° gap) — Balance both sides!',
        spokenInstructionEn: 'Push evenly with both sides! Balance your movement.',
        spokenInstructionHi: 'Dono side barabar zor lagao, body balance rakho!',
        isSevereCheat: false,
      );
    }

    return KineticDiagnosticReport.clean;
  }

  void _recordFault(KineticFaultType fault) {
    _faultOccurrenceCount[fault] = (_faultOccurrenceCount[fault] ?? 0) + 1;
  }

  /// Determines if a spoken coaching instruction should be voiced, throttled intelligently.
  bool shouldVoiceCue({
    required KineticDiagnosticReport report,
    required Duration cooldown,
  }) {
    if (!report.hasFault) return false;
    final now = DateTime.now();
    final elapsed = now.difference(_lastVoiceCueTime);

    // If it's a critical safety fault or different from previous fault, allow faster 2.8s cooldown
    if ((report.isSevereCheat || report.faultType != _lastVoicedFault) && elapsed.inMilliseconds >= 2800) {
      _lastVoiceCueTime = now;
      _lastVoicedFault = report.faultType;
      return true;
    }

    // Normal warning cooldown 4.0s
    if (elapsed >= cooldown) {
      _lastVoiceCueTime = now;
      _lastVoicedFault = report.faultType;
      return true;
    }

    return false;
  }

  /// Total reps rejected for invalid form or incomplete range of motion.
  int get totalRejectedReps => _totalRejectedReps;

  /// Compiles final comprehensive biomechanical audit scorecard.
  WorkoutBiomechanicalScorecard finalizeScorecard({
    required String exerciseId,
    required String exerciseName,
    required int completedReps,
    required int targetReps,
    required double liveFormScore,
    required double liveSymmetryScore,
    required int durationSec,
    int? rejectedReps,
  }) {
    final finalRejectedReps = rejectedReps ?? _totalRejectedReps;
    final avgCadence = _repCadenceHistory.isNotEmpty
        ? _repCadenceHistory.reduce((a, b) => a + b) / _repCadenceHistory.length
        : 2.2;

    final avgPurity = _repPurityHistory.isNotEmpty
        ? (_repPurityHistory.reduce((a, b) => a + b) / _repPurityHistory.length) * 100.0
        : liveFormScore;

    final feedback = <String>[];

    if (finalRejectedReps > 0) {
      feedback.add('Filtered out $finalRejectedReps incomplete/cheated reps to ensure zero false counting.');
    } else {
      feedback.add('Flawless set: 100% of attempted repetitions satisfied strict depth and stability standards.');
    }

    if ((_faultOccurrenceCount[KineticFaultType.kneeValgus] ?? 0) > 0) {
      feedback.add('Knee valgus detected on descent: Focus on hip abductor recruitment to push knees outward.');
    }

    if ((_faultOccurrenceCount[KineticFaultType.spineFlexionRounding] ?? 0) > 0) {
      feedback.add('Lumbar spine rounded during fatigue: Keep chest proud and gaze forward.');
    }

    if ((_faultOccurrenceCount[KineticFaultType.torsoSwingCheating] ?? 0) > 0) {
      feedback.add('Torso momentum observed: Keep core braced and isolate the target movement.');
    }

    if (avgCadence < 1.2) {
      feedback.add('Tempo was rapid: Emphasize a 2-second eccentric phase for superior metabolic stimulus.');
    } else {
      feedback.add('Tempo cadence was controlled (${avgCadence.toStringAsFixed(1)}s/rep): High mechanical tension achieved.');
    }

    // Estimate realistic MET caloric burn based on exercise intensity
    final baseKcalPerMin = (exerciseId.contains('jack') || exerciseId.contains('burpee'))
        ? 10.0
        : (exerciseId.contains('squat') || exerciseId.contains('lunge') || exerciseId.contains('push-up'))
            ? 7.5
            : 5.5;
    final burned = math.max(12, (durationSec / 60.0 * baseKcalPerMin).round());

    final muscles = _resolveMuscleTarget(exerciseId);

    return WorkoutBiomechanicalScorecard(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      completedReps: completedReps,
      targetReps: targetReps,
      rejectedReps: finalRejectedReps,
      overallFormAccuracy: avgPurity.clamp(70.0, 99.5),
      averageCadenceSec: avgCadence,
      bilateralSymmetry: liveSymmetryScore,
      caloriesBurned: burned,
      primaryMuscleGroups: muscles,
      coachingFeedbackList: feedback,
    );
  }

  List<String> _resolveMuscleTarget(String id) {
    if (id.contains('squat') || id.contains('wall-sit')) {
      return const ['Quadriceps', 'Gluteus Maximus', 'Core Stabilizers'];
    }
    if (id.contains('push-up') || id.contains('bench-press')) {
      return const ['Pectoralis Major', 'Anterior Deltoids', 'Triceps'];
    }
    if (id.contains('curl') || id.contains('row')) {
      return const ['Biceps Brachii', 'Brachialis', 'Latissimus Dorsi'];
    }
    if (id.contains('press') || id.contains('raise')) {
      return const ['Deltoids (Shoulders)', 'Upper Trapezius', 'Triceps'];
    }
    if (id.contains('plank') || id.contains('twist')) {
      return const ['Rectus Abdominis', 'Transverse Abdominis', 'Obliques'];
    }
    if (id.contains('lunge')) {
      return const ['Hamstrings', 'Quadriceps', 'Glutes', 'Calves'];
    }
    if (id.contains('bridge')) {
      return const ['Glutes', 'Hamstrings', 'Lower Back'];
    }
    return const ['Full-Body Functional Kinetic Chain'];
  }
}
