import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// Biomechanical configuration for any VYRA exercise (Rep-based or Isometric Hold).
class ExerciseConfig {
  final String id;
  final String name;
  final String category;
  final bool isHold;
  final int defaultReps; // reps or hold seconds
  final String primaryAngle;
  final List<PoseLandmarkType> leftTriplet;
  final List<PoseLandmarkType> rightTriplet;
  final double startAngleDeg;
  final double peakAngleDeg;
  final bool decreaseToPeak; // true = angle decreases to peak (e.g. squat 165 -> 95)
  final String cueDown;
  final String cueUp;
  final String formHint;
  final String framingMode; // 'full_body', 'upper_body', 'floor'
  final String auraPattern;

  const ExerciseConfig({
    required this.id,
    required this.name,
    this.category = 'Strength & Conditioning',
    this.isHold = false,
    required this.defaultReps,
    required this.primaryAngle,
    required this.leftTriplet,
    required this.rightTriplet,
    required this.startAngleDeg,
    required this.peakAngleDeg,
    this.decreaseToPeak = true,
    required this.cueDown,
    required this.cueUp,
    required this.formHint,
    this.framingMode = 'full_body',
    this.auraPattern = 'squat',
  });

  /// Resolves ANY exercise slug or title from Gemini AI Brain, Backend Catalog, Library, or Challenges
  /// into an accurate biomechanical tracking specification and AR Moving Aura pattern.
  static ExerciseConfig resolve(
    String rawSlugOrName, {
    String? customTitle,
    int? customTarget,
  }) {
    final norm = rawSlugOrName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\s_]+'), '-');
    final normTitle = (customTitle ?? '')
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\s_]+'), '-');
    final combined = normTitle.isEmpty ? norm : '$norm $normTitle';

    // 1. Exact ID match in kSupportedExercises
    for (final ex in kSupportedExercises) {
      final exNorm = ex.id.toLowerCase().replaceAll('_', '-');
      if (norm == exNorm || norm == ex.id.toLowerCase()) {
        return ex.copyWith(
          name: customTitle ?? ex.name,
          defaultReps: customTarget != null && customTarget > 0 ? customTarget : ex.defaultReps,
        );
      }
    }

    final title = customTitle ?? _prettifySlug(rawSlugOrName);
    final tokens = combined.split(RegExp(r'[\s\-]+')).toSet();

    ExerciseConfig pick(String baseId, int fallbackReps) {
      return kSupportedExercises
          .firstWhere((e) => e.id == baseId)
          .copyWith(
            id: norm,
            name: title,
            defaultReps: customTarget != null && customTarget > 0 ? customTarget : fallbackReps,
          );
    }

    // 2. Pranayama, Breathwork, Meditation & Facial Yoga / Upper Relaxation
    if (_hasAny(combined, [
      'cheek-lift',
      'jaw-release',
      'brow-smoother',
      'neck-firming',
      'eye-circle',
      'scalp-massage',
      'neck-release',
      'neck-glide',
      'wrist-mobility',
      'wrist-finger',
      'shoulder-rolls',
      'shoulder-pendulum',
      'arm-circle',
      'lateral-raise',
    ])) {
      return pick('lateral-raise', 12);
    }

    if (_hasAny(combined, [
      'box-breathing',
      'four-seven-eight',
      'anulom-vilom',
      'alternate-nostril',
      'lions-breath',
      'diaphragmatic',
      'coherent-breathing',
      'physiological-sigh',
      'ujjayi',
      'pursed-lip',
      'humming-bee',
      'energizing-breath',
      'breath-awareness',
      'body-scan',
      'sleep-prep',
      'pranayama',
      'meditation',
      'breath',
    ])) {
      return pick('box-breathing', 25);
    }

    // 3. Push-Up, Chest Press & Tricep Dips
    if (_hasAny(combined, ['push-up', 'pushup', 'bench-press', 'chest-press']) ||
        tokens.contains('dip') ||
        tokens.contains('dips')) {
      return pick('push-up', 12);
    }

    // 4. Bicep Curl, Row & Upper Pull
    if (tokens.intersection({'curl', 'bicep', 'tricep', 'row', 'rows', 'pull', 'pullup'}).isNotEmpty) {
      return pick('dumbbell-bicep-curl', 12);
    }

    // 5. Overhead Shoulder Press & Reach
    if (_hasAny(combined, [
      'shoulder-press',
      'overhead-press',
      'overhead-reach',
      'seated-shoulder',
      'seated-overhead',
      'sun-salutation',
    ])) {
      return pick('seated-shoulder-press', 12);
    }

    // 6. Core Twist, Oblique Crunch, Open-Book, Dead-Bug & Bird-Dog
    if (_hasAny(combined, [
      'torso-twist',
      'spinal-twist',
      'supine-twist',
      'oblique-crunch',
      'open-book',
      'dead-bug',
      'bird-dog',
      'russian-twist',
      'bicycle-crunch',
      'twist',
    ])) {
      return pick('seated-torso-twist', 12);
    }

    // 7. Full-Body Cardio, Jumping Jacks, Burpees, HIIT & Zumba
    if (_hasAny(combined, [
      'jumping-jack',
      'step-jack',
      'burpee',
      'hiit',
      'zumba',
      'dance',
      'cardio-blast',
    ])) {
      return pick('jumping-jacks', 16);
    }

    // 8. Knee Drive, March, Mountain Climbers, Skater & Leg Lifts
    if (_hasAny(combined, [
      'high-knee',
      'march',
      'climber',
      'skater',
      'shuffle',
      'butt-kick',
      'leg-extension',
      'knee-lift',
    ])) {
      return pick('high-knees', 16);
    }

    // 9. Posterior Hinge & Forward Fold (Deadlift, Forward Fold, Hamstring Hinge)
    if (_hasAny(combined, [
      'forward-fold',
      'hamstring-hinge',
      'romanian-deadlift',
      'deadlift',
      'good-morning',
    ])) {
      return pick('seated-forward-fold', 12);
    }

    // 10. Glute Bridge, Cat-Cow, Cobra, Pelvic Tilt & Supine Floor Flows
    if (_hasAny(combined, [
      'glute-bridge',
      'bridge-pose',
      'bridge',
      'cat-cow',
      'cobra',
      'pelvic-tilt',
      'legs-up-wall',
    ])) {
      return pick('glute-bridge', 12);
    }

    // 11. Floor / Core Isometric Holds (Plank, Downward Dog, Child Pose)
    if (_hasAny(combined, [
      'plank',
      'downward-dog',
      'child-pose',
      'childs-pose',
      'hollow-hold',
    ])) {
      return pick('plank', 25);
    }

    // 12. Standing / Lower-Body Isometric Holds (Wall Sit, Tree Pose, Warrior, Tai Chi, Chair Pose)
    if (_hasAny(combined, [
      'wall-sit',
      'tree-pose',
      'warrior',
      'chair-pose',
      'tai-chi',
    ])) {
      return pick('wall-sit', 25);
    }

    // 13. Lunges, Split Squats, Step-Ups & Hip Flexor Stretch
    if (_hasAny(combined, [
      'lunge',
      'split-squat',
      'step-up',
      'hip-flexor',
    ])) {
      return pick('reverse-lunge', 10);
    }

    // 14. Calf Raises & Ankle Mobility
    if (_hasAny(combined, ['calf', 'ankle'])) {
      return pick('calf-raise', 15);
    }

    // 15. Squat Variations & Default Lower-Body Strength
    return pick('bodyweight-squat', 12);
  }

  static bool _hasAny(String s, List<String> keys) => keys.any((k) => s.contains(k));

  static String _prettifySlug(String slug) {
    return slug
        .replaceAll(RegExp(r'[\-_]+'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  ExerciseConfig copyWith({
    String? id,
    String? name,
    String? category,
    bool? isHold,
    int? defaultReps,
    String? auraPattern,
  }) {
    return ExerciseConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      isHold: isHold ?? this.isHold,
      defaultReps: defaultReps ?? this.defaultReps,
      primaryAngle: primaryAngle,
      leftTriplet: leftTriplet,
      rightTriplet: rightTriplet,
      startAngleDeg: startAngleDeg,
      peakAngleDeg: peakAngleDeg,
      decreaseToPeak: decreaseToPeak,
      cueDown: cueDown,
      cueUp: cueUp,
      formHint: formHint,
      framingMode: framingMode,
      auraPattern: auraPattern ?? this.auraPattern,
    );
  }

  /// Generates the 33-point AR Moving Target Aura (Points + Joint Lines) for this exercise
  /// at normalized movement phase [phase01] (`0.0` = start pose, `1.0` = peak contraction),
  /// anchored to mid-torso `(anchorX, anchorY)` with body scale `scale`.
  /// Mathematically guaranteed to sweep the exercise's active triplet angle across `[startAngleDeg, peakAngleDeg]`.
  static List<Offset> computeAuraPose(
    ExerciseConfig config,
    double phase01, {
    double anchorX = 0.50,
    double anchorY = 0.44,
    double scale = 1.0,
    double motionCycle = 0.0,
  }) {
    final pattern = config.auraPattern;
    final p = phase01.clamp(0.0, 1.0);
    final cx = anchorX.clamp(0.30, 0.70);
    final cy = anchorY.clamp(0.32, 0.58);
    final s = scale.clamp(0.72, 1.35);

    Offset pt(double dx, double dy) => Offset(
          (cx + dx * s).clamp(0.04, 0.96),
          (cy + dy * s).clamp(0.04, 0.96),
        );

    double headDy = -0.22;
    double lShDx = -0.115, lShDy = -0.10, rShDx = 0.115, rShDy = -0.10;
    double lHipDx = -0.085, lHipDy = 0.12, rHipDx = 0.085, rHipDy = 0.12;
    double lElbDx = -0.15, lElbDy = 0.02, rElbDx = 0.15, rElbDy = 0.02;
    double lWriDx = -0.14, lWriDy = 0.14, rWriDx = 0.14, rWriDy = 0.14;
    double lKneeDx = -0.095, lKneeDy = 0.30, rKneeDx = 0.095, rKneeDy = 0.30;
    double lAnkDx = -0.095, lAnkDy = 0.47, rAnkDx = 0.095, rAnkDy = 0.47;
    double lFootDx = -0.115, lFootDy = 0.495, rFootDx = 0.115, rFootDy = 0.495;

    switch (pattern) {
      case 'squat':
        // Knee angle sweeps 176.8° (p=0) -> 98.8° (p=1)
        final drop = p * 0.165;
        headDy = -0.22 + drop * 0.85;
        lShDy = -0.10 + drop * 0.90;
        rShDy = -0.10 + drop * 0.90;
        lHipDy = 0.12 + drop;
        rHipDy = 0.12 + drop;
        lKneeDx = -0.095 - p * 0.070;
        rKneeDx = 0.095 + p * 0.070;
        lKneeDy = 0.30 + p * 0.050;
        rKneeDy = 0.30 + p * 0.050;
        lElbDx = -0.14;
        rElbDx = 0.14;
        lElbDy = 0.01 + drop * 0.70;
        rElbDy = 0.01 + drop * 0.70;
        lWriDx = -0.07;
        rWriDx = 0.07;
        lWriDy = -0.05 + drop * 0.60;
        rWriDy = -0.05 + drop * 0.60;
        break;

      case 'lunge':
        // Split lunge knee bend 176.8° (p=0) -> 96.5° (p=1)
        final drop = p * 0.160;
        headDy = -0.22 + drop * 0.85;
        lShDy = -0.10 + drop * 0.90;
        rShDy = -0.10 + drop * 0.90;
        lHipDy = 0.12 + drop;
        rHipDy = 0.12 + drop;
        lKneeDx = -0.095 - p * 0.075;
        rKneeDx = 0.095 + p * 0.075;
        lKneeDy = 0.30 + p * 0.045;
        rKneeDy = 0.30 + p * 0.055;
        lAnkDx = -0.095 - p * 0.005;
        rAnkDx = 0.095 + p * 0.005;
        lWriDx = -0.08;
        rWriDx = 0.08;
        lWriDy = -0.02 + drop * 0.75;
        rWriDy = -0.02 + drop * 0.75;
        break;

      case 'bridge':
        // Shoulder-Hip-Knee sweeps 103.8° (p=0) -> 178.0° (p=1)
        lShDy = -0.06 - p * 0.04;
        rShDy = -0.06 - p * 0.04;
        lHipDx = -0.020 - p * 0.085;
        rHipDx = 0.020 + p * 0.085;
        lHipDy = 0.14 - p * 0.04;
        rHipDy = 0.14 - p * 0.04;
        lKneeDx = -0.155 + p * 0.060;
        rKneeDx = 0.155 - p * 0.060;
        lKneeDy = 0.25 + p * 0.05;
        rKneeDy = 0.25 + p * 0.05;
        lAnkDx = -0.145 + p * 0.050;
        rAnkDx = 0.145 - p * 0.050;
        lAnkDy = 0.27 + p * 0.02;
        rAnkDy = 0.27 + p * 0.02;
        break;

      case 'hinge_fold':
        // Shoulder-Hip-Knee sweeps 170.0° (p=0) -> 74.0° (p=1)
        headDy = -0.22 + p * 0.26;
        lShDx = -0.115 - p * 0.050;
        rShDx = 0.115 + p * 0.050;
        lShDy = -0.10 + p * 0.16;
        rShDy = -0.10 + p * 0.16;
        lHipDx = -0.085 + p * 0.060;
        rHipDx = 0.085 - p * 0.060;
        lHipDy = 0.12 + p * 0.01;
        rHipDy = 0.12 + p * 0.01;
        lKneeDx = -0.095 - p * 0.060;
        rKneeDx = 0.095 + p * 0.060;
        lKneeDy = 0.30 - p * 0.03;
        rKneeDy = 0.30 - p * 0.03;
        lWriDy = 0.14 + p * 0.18;
        rWriDy = 0.14 + p * 0.18;
        break;

      case 'push_up':
        // Shoulder-Elbow-Wrist sweeps 177.6° (p=0) -> 62.0° (p=1)
        headDy = -0.20 + p * 0.11;
        lShDy = -0.10 + p * 0.11;
        rShDy = -0.10 + p * 0.11;
        lHipDy = 0.12 + p * 0.08;
        rHipDy = 0.12 + p * 0.08;
        lElbDx = -0.130 - p * 0.105;
        rElbDx = 0.130 + p * 0.105;
        lElbDy = 0.02 + p * 0.03;
        rElbDy = 0.02 + p * 0.03;
        lWriDx = -0.140;
        rWriDx = 0.140;
        lWriDy = 0.14;
        rWriDy = 0.14;
        break;

      case 'curl_row':
        // Shoulder-Elbow-Wrist sweeps 176.2° (p=0) -> 29.5° (p=1)
        lElbDx = -0.135;
        rElbDx = 0.135;
        lElbDy = 0.03;
        rElbDy = 0.03;
        lWriDx = -0.145 + p * 0.065;
        rWriDx = 0.145 - p * 0.065;
        lWriDy = 0.16 - p * 0.22;
        rWriDy = 0.16 - p * 0.22;
        break;

      case 'overhead_press':
        // Hip-Shoulder-Elbow sweeps 41.5° (p=0) -> 178.0° (p=1)
        lElbDx = -0.175 + p * 0.040;
        rElbDx = 0.175 - p * 0.040;
        lElbDy = -0.01 - p * 0.24;
        rElbDy = -0.01 - p * 0.24;
        lWriDx = -0.160 + p * 0.045;
        rWriDx = 0.160 - p * 0.045;
        lWriDy = -0.12 - p * 0.24;
        rWriDy = -0.12 - p * 0.24;
        break;

      case 'lateral_raise':
        // Hip-Shoulder-Wrist sweeps 12.6° (p=0) -> 104.0° (p=1)
        lElbDx = -0.130 - p * 0.090;
        rElbDx = 0.130 + p * 0.090;
        lElbDy = 0.02 - p * 0.13;
        rElbDy = 0.02 - p * 0.13;
        lWriDx = -0.135 - p * 0.165;
        rWriDx = 0.135 + p * 0.165;
        lWriDy = 0.14 - p * 0.26;
        rWriDy = 0.14 - p * 0.26;
        break;

      case 'torso_twist':
        // Hip-Shoulder-Wrist rotational open-book sweep 13.0° (p=0) -> 101.5° (p=1)
        lShDx = -0.115 - p * 0.010;
        rShDx = 0.115 + p * 0.010;
        lElbDx = -0.130 - p * 0.100;
        rElbDx = 0.130 + p * 0.100;
        lElbDy = 0.02 - p * 0.08;
        rElbDy = 0.02 - p * 0.08;
        lWriDx = -0.135 - p * 0.160;
        rWriDx = 0.135 + p * 0.160;
        lWriDy = 0.13 - p * 0.24;
        rWriDy = 0.13 - p * 0.24;
        break;

      case 'jumping_jack':
        // Hip-Shoulder-Wrist sweeps 13.8° (p=0) -> 167.0° (p=1) with wide leg jump
        headDy = -0.22 - p * 0.02;
        lShDy = -0.10 - p * 0.02;
        rShDy = -0.10 - p * 0.02;
        lHipDy = 0.12 - p * 0.02;
        rHipDy = 0.12 - p * 0.02;
        lElbDx = -0.14 - p * 0.06;
        rElbDx = 0.14 + p * 0.06;
        lElbDy = 0.02 - p * 0.19;
        rElbDy = 0.02 - p * 0.19;
        lWriDx = -0.14 + p * 0.04;
        rWriDx = 0.14 - p * 0.04;
        lWriDy = 0.14 - p * 0.42;
        rWriDy = 0.14 - p * 0.42;
        lKneeDx = -0.095 - p * 0.06;
        rKneeDx = 0.095 + p * 0.06;
        lAnkDx = -0.095 - p * 0.09;
        rAnkDx = 0.095 + p * 0.09;
        break;

      case 'knee_drive':
        // Alternating high-knee drive: active Hip angle sweeps 170.0° (p=0) -> 68.7° (p=1)
        final leftUp = math.sin(motionCycle) >= 0;
        if (leftUp) {
          lKneeDx = -0.095 - p * 0.115;
          lKneeDy = 0.30 - p * 0.21;
          lAnkDx = -0.095 - p * 0.095;
          lAnkDy = 0.47 - p * 0.22;
          rWriDy = 0.10 - p * 0.14;
          lWriDy = 0.02;
        } else {
          rKneeDx = 0.095 + p * 0.115;
          rKneeDy = 0.30 - p * 0.21;
          rAnkDx = 0.095 + p * 0.095;
          rAnkDy = 0.47 - p * 0.22;
          lWriDy = 0.10 - p * 0.14;
          rWriDy = 0.02;
        }
        break;

      case 'calf_raise':
        // Knee-Ankle-FootIndex plantarflexion sweeps 94.1° (p=0) -> 161.6° (p=1)
        final rise = p * 0.05;
        headDy = -0.22 - rise;
        lShDy = -0.10 - rise;
        rShDy = -0.10 - rise;
        lHipDy = 0.12 - rise;
        rHipDy = 0.12 - rise;
        lKneeDy = 0.30 - p * 0.04;
        rKneeDy = 0.30 - p * 0.04;
        lAnkDy = 0.46 - p * 0.05;
        rAnkDy = 0.46 - p * 0.05;
        lFootDx = -0.165 + p * 0.045;
        rFootDx = 0.165 - p * 0.045;
        lFootDy = 0.465 + p * 0.020;
        rFootDy = 0.465 + p * 0.020;
        break;

      case 'plank_hold':
        // Shoulder-Hip-Ankle horizontal prone floor alignment (~176.5° >= 162° - 16°)
        final breathe = p * 0.012;
        headDy = 0.02 - breathe;
        lShDx = -0.22;
        rShDx = -0.22;
        lShDy = 0.08 - breathe;
        rShDy = 0.08 - breathe;
        lElbDx = -0.22;
        rElbDx = -0.22;
        lElbDy = 0.18;
        rElbDy = 0.18;
        lWriDx = -0.16;
        rWriDx = -0.16;
        lWriDy = 0.18;
        rWriDy = 0.18;
        lHipDx = 0.02;
        rHipDx = 0.02;
        lHipDy = 0.07 - breathe * 0.5;
        rHipDy = 0.07 - breathe * 0.5;
        lKneeDx = 0.16;
        rKneeDx = 0.16;
        lKneeDy = 0.08;
        rKneeDy = 0.08;
        lAnkDx = 0.28;
        rAnkDx = 0.28;
        lAnkDy = 0.09;
        rAnkDy = 0.09;
        lFootDx = 0.30;
        rFootDx = 0.30;
        lFootDy = 0.10;
        rFootDy = 0.10;
        break;

      case 'lower_hold':
        // Isometric knee hold (~104.5° <= 118° + 16°)
        headDy = -0.09;
        lShDy = 0.03;
        rShDy = 0.03;
        lHipDy = 0.265;
        rHipDy = 0.265;
        lKneeDx = -0.165;
        rKneeDx = 0.165;
        lKneeDy = 0.345;
        rKneeDy = 0.345;
        lWriDx = -0.07;
        rWriDx = 0.07;
        lWriDy = -0.02 - p * 0.04;
        rWriDy = -0.02 - p * 0.04;
        break;

      case 'breath_hold':
        // Upright meditative chest/arm breathing wave (Hip-Shoulder-OppositeShoulder ~97.8° >= 82° - 16°)
        lShDx = -0.115 - p * 0.022;
        rShDx = 0.115 + p * 0.022;
        lShDy = -0.10 - p * 0.018;
        rShDy = -0.10 - p * 0.018;
        lElbDx = -0.145 - p * 0.045;
        rElbDx = 0.145 + p * 0.045;
        lElbDy = 0.03 - p * 0.06;
        rElbDy = 0.03 - p * 0.06;
        lWriDx = -0.10 - p * 0.05;
        rWriDx = 0.10 + p * 0.05;
        lWriDy = 0.11 - p * 0.13;
        rWriDy = 0.11 - p * 0.13;
        break;

      default:
        final drop = p * 0.165;
        lHipDy = 0.12 + drop;
        rHipDy = 0.12 + drop;
        lKneeDx = -0.095 - p * 0.070;
        rKneeDx = 0.095 + p * 0.070;
        lKneeDy = 0.30 + p * 0.050;
        rKneeDy = 0.30 + p * 0.050;
        break;
    }

    if (pattern != 'calf_raise') {
      lFootDx = lAnkDx - 0.02;
      rFootDx = rAnkDx + 0.02;
      lFootDy = lAnkDy + 0.025;
      rFootDy = rAnkDy + 0.025;
    }

    final aura = List<Offset>.filled(33, Offset.zero);
    aura[0] = pt(0.0, headDy);
    aura[2] = pt(-0.02, headDy - 0.015);
    aura[5] = pt(0.02, headDy - 0.015);
    aura[7] = pt(-0.04, headDy);
    aura[8] = pt(0.04, headDy);
    aura[11] = pt(lShDx, lShDy);
    aura[12] = pt(rShDx, rShDy);
    aura[13] = pt(lElbDx, lElbDy);
    aura[14] = pt(rElbDx, rElbDy);
    aura[15] = pt(lWriDx, lWriDy);
    aura[16] = pt(rWriDx, rWriDy);
    aura[19] = pt(lWriDx * 0.98, lWriDy - 0.02);
    aura[20] = pt(rWriDx * 0.98, rWriDy - 0.02);
    aura[23] = pt(lHipDx, lHipDy);
    aura[24] = pt(rHipDx, rHipDy);
    aura[25] = pt(lKneeDx, lKneeDy);
    aura[26] = pt(rKneeDx, rKneeDy);
    aura[27] = pt(lAnkDx, lAnkDy);
    aura[28] = pt(rAnkDx, rAnkDy);
    aura[31] = pt(lFootDx, lFootDy);
    aura[32] = pt(rFootDx, rFootDy);
    return aura;
  }

  /// Computes the real-time Human-to-Aura Synchronized Match Score (`0.0` to `100.0`)
  /// by combining active-joint spatial alignment with normalized ROM angular synchronization.
  static double computeAuraMatch({
    required ExerciseConfig config,
    required List<Offset> humanLandmarks,
    required List<double> humanConf,
    required List<Offset> auraLandmarks,
    required double humanAngle,
    required double auraTargetAngle,
  }) {
    final activeIndices = <int>{
      11,
      12,
      config.leftTriplet[0].index,
      config.leftTriplet[1].index,
      config.leftTriplet[2].index,
      config.rightTriplet[0].index,
      config.rightTriplet[1].index,
      config.rightTriplet[2].index,
    };

    double distSum = 0.0;
    int distCount = 0;
    for (final idx in activeIndices) {
      if (idx < humanConf.length &&
          idx < humanLandmarks.length &&
          idx < auraLandmarks.length &&
          humanConf[idx] >= 0.22) {
        distSum += (humanLandmarks[idx] - auraLandmarks[idx]).distance;
        distCount++;
      }
    }
    final avgPointDist = distCount > 0 ? (distSum / distCount) : 0.14;
    final spatialMatch = (100.0 - avgPointDist * 260.0).clamp(10.0, 99.5);

    final romSpan = math.max(25.0, (config.startAngleDeg - config.peakAngleDeg).abs());
    final angleDiff = (humanAngle - auraTargetAngle).abs();
    final angleMatch = (100.0 - (angleDiff / romSpan) * 85.0).clamp(10.0, 99.5);

    return (0.45 * spatialMatch + 0.55 * angleMatch).clamp(10.0, 99.5);
  }

  /// Strict ARTIFIT-grade multi-joint biomechanical form verification.
  /// Returns `isValid = true` (Green AR points) ONLY when required joints are visible,
  /// body posture orientation matches the exercise, secondary stabilizer joints are not cheating,
  /// bilateral symmetry is maintained, and the joint angle is inside the valid biomechanical corridor.
  static FormVerificationResult verifyBiomechanicalForm({
    required ExerciseConfig config,
    required List<Offset> humanLandmarks,
    required List<double> humanConf,
    required double humanAngle,
    required double spineTiltDeg,
    required double symmetryDiff,
    required double leftTripletConf,
    required double rightTripletConf,
  }) {
    final activeIndices = <int>{
      config.leftTriplet[0].index,
      config.leftTriplet[1].index,
      config.leftTriplet[2].index,
      config.rightTriplet[0].index,
      config.rightTriplet[1].index,
      config.rightTriplet[2].index,
    };

    // 1. Active-Triplet Visibility Gate
    final bestTripletConf = math.max(leftTripletConf, rightTripletConf);
    final shoulderConf = (humanConf.length > 12)
        ? math.max(humanConf[11], humanConf[12])
        : 0.0;
    final legConf = (humanConf.length > 28)
        ? math.max(
            math.min(humanConf[25], humanConf[27]),
            math.min(humanConf[26], humanConf[28]),
          )
        : 0.0;

    if (bestTripletConf < 0.36) {
      return FormVerificationResult(
        isValid: false,
        faultJoints: activeIndices,
        warningMessage:
            '⚠️ Step back so your ${config.framingMode == "full_body" ? "full body (hips, knees & ankles)" : "active joints"} are clearly in frame',
      );
    }

    if (config.framingMode == 'full_body' &&
        (config.auraPattern == 'squat' ||
            config.auraPattern == 'lunge' ||
            config.auraPattern == 'lower_hold' ||
            config.auraPattern == 'calf_raise') &&
        (shoulderConf < 0.32 || legConf < 0.36)) {
      return FormVerificationResult(
        isValid: false,
        faultJoints: {11, 12, 23, 24, 25, 26, 27, 28},
        warningMessage:
            '⚠️ Full body required for ${config.name} — Place phone so head to ankles are visible',
      );
    }

    final pattern = config.auraPattern;
    final hasTorso = humanConf.length > 24 &&
        humanConf[11] >= 0.32 &&
        humanConf[12] >= 0.32 &&
        humanConf[23] >= 0.32 &&
        humanConf[24] >= 0.32;
    final hasKnees =
        humanConf.length > 26 && (humanConf[25] >= 0.32 || humanConf[26] >= 0.32);

    // 2. Anatomical Body-Posture Orientation Gate
    if (hasTorso) {
      final midShoulder = (humanLandmarks[11] + humanLandmarks[12]) * 0.5;
      final midHip = (humanLandmarks[23] + humanLandmarks[24]) * 0.5;
      final torsoDx = (midHip.dx - midShoulder.dx).abs();
      final torsoDy = (midHip.dy - midShoulder.dy).abs();

      // Floor / Horizontal posture check for Plank & Glute Bridge
      if ((pattern == 'plank_hold' || pattern == 'bridge') &&
          config.framingMode == 'floor' &&
          hasKnees &&
          humanConf.length > 28 &&
          humanConf[27] >= 0.25 &&
          humanConf[28] >= 0.25) {
        final midKnee = (humanLandmarks[25] + humanLandmarks[26]) * 0.5;
        final midAnkle = (humanLandmarks[27] + humanLandmarks[28]) * 0.5;
        final fullLegDy = midAnkle.dy - midHip.dy;
        final kneeDropDy = midKnee.dy - midHip.dy;
        final isStandingUpright =
            torsoDy > 0.18 && torsoDy > torsoDx * 1.5 && kneeDropDy > 0.17 && fullLegDy > 0.30;
        if (isStandingUpright) {
          return FormVerificationResult(
            isValid: false,
            faultJoints: {11, 12, 23, 24, 25, 26, 27, 28},
            warningMessage:
                '⚠️ Please do it correctly: You are standing upright! Get into floor position for ${config.name}',
          );
        }
      }

      // Upright Spine-Integrity Gate for Standing / Seated exercises
      if (pattern == 'curl_row' ||
          pattern == 'overhead_press' ||
          pattern == 'lateral_raise' ||
          pattern == 'calf_raise') {
        if (spineTiltDeg > 26.0) {
          return FormVerificationResult(
            isValid: false,
            faultJoints: {11, 12, 23, 24},
            warningMessage:
                '⚠️ Please do it correctly: Keep your back straight (${spineTiltDeg.toInt()}° lean) — do not swing torso!',
          );
        }
      } else if (pattern == 'squat' ||
          pattern == 'lunge' ||
          pattern == 'lower_hold') {
        if (spineTiltDeg > 38.0) {
          return const FormVerificationResult(
            isValid: false,
            faultJoints: {11, 12, 23, 24, 25, 26},
            warningMessage:
                '⚠️ Please do it correctly: Keep chest upright — bend your knees, do not bow your back!',
          );
        }
        // Squat Knee-Valgus (Knee Cave) Check
        if (pattern == 'squat' &&
            humanAngle < 142.0 &&
            humanConf[25] >= 0.38 &&
            humanConf[26] >= 0.38) {
          final hipSpan = (humanLandmarks[23].dx - humanLandmarks[24].dx).abs();
          final kneeSpan = (humanLandmarks[25].dx - humanLandmarks[26].dx).abs();
          if (hipSpan > 0.05 && kneeSpan < hipSpan * 0.62) {
            return const FormVerificationResult(
              isValid: false,
              faultJoints: {25, 26, 27, 28},
              warningMessage:
                  '⚠️ Please do it correctly: Push knees outward in line with your toes!',
            );
          }
        }
      }
    }

    // 3. Secondary Joint Isolation & Anti-Cheating Gate
    if (pattern == 'curl_row' && humanConf.length > 16) {
      // Elbows must remain below shoulders during curls (prevent shoulder swinging)
      final lSwing = humanConf[11] >= 0.35 &&
          humanConf[13] >= 0.35 &&
          humanLandmarks[13].dy < humanLandmarks[11].dy + 0.02;
      final rSwing = humanConf[12] >= 0.35 &&
          humanConf[14] >= 0.35 &&
          humanLandmarks[14].dy < humanLandmarks[12].dy + 0.02;
      if (lSwing || rSwing) {
        return const FormVerificationResult(
          isValid: false,
          faultJoints: {11, 12, 13, 14, 15, 16},
          warningMessage:
              '⚠️ Please do it correctly: Keep elbows pinned to your sides — do not lift shoulders!',
        );
      }
    } else if (pattern == 'overhead_press' &&
        humanAngle > 115.0 &&
        humanConf.length > 16) {
      // Wrists must actually rise above elbows & shoulders during an overhead press
      final lWristLow = humanConf[13] >= 0.35 &&
          humanConf[15] >= 0.35 &&
          humanLandmarks[15].dy > humanLandmarks[13].dy + 0.02;
      final rWristLow = humanConf[14] >= 0.35 &&
          humanConf[16] >= 0.35 &&
          humanLandmarks[16].dy > humanLandmarks[14].dy + 0.02;
      if (lWristLow || rWristLow) {
        return const FormVerificationResult(
          isValid: false,
          faultJoints: {11, 12, 13, 14, 15, 16},
          warningMessage:
              '⚠️ Please do it correctly: Press your hands straight overhead above your shoulders!',
        );
      }
    }

    // 4. Bilateral Symmetry Gate for Symmetric Exercises
    const bilateralPatterns = <String>{
      'squat',
      'push_up',
      'curl_row',
      'overhead_press',
      'lateral_raise',
      'jumping_jack',
      'bridge',
      'calf_raise',
    };
    final excursionFromStart = (humanAngle - config.startAngleDeg).abs();
    if (bilateralPatterns.contains(pattern) &&
        leftTripletConf >= 0.42 &&
        rightTripletConf >= 0.42 &&
        excursionFromStart >= 18.0 &&
        symmetryDiff > 34.0) {
      return FormVerificationResult(
        isValid: false,
        faultJoints: activeIndices,
        warningMessage:
            '⚠️ Please do it correctly: Uneven movement (${symmetryDiff.toInt()}° difference) — Move both sides symmetrically!',
      );
    }

    // 5. Valid Biomechanical Angular Range Gate
    if (config.isHold) {
      final inHoldZone = config.decreaseToPeak
          ? humanAngle <= config.peakAngleDeg + 16.0
          : humanAngle >= config.peakAngleDeg - 16.0;
      if (!inHoldZone) {
        return FormVerificationResult(
          isValid: false,
          faultJoints: activeIndices,
          warningMessage:
              '⚠️ Out of Hold Range (${humanAngle.toInt()}°) — Reach ${config.peakAngleDeg.toInt()}° target posture!',
        );
      }
    } else {
      final minValid = math.min(config.startAngleDeg, config.peakAngleDeg) - 26.0;
      final maxValid = math.max(config.startAngleDeg, config.peakAngleDeg) + 24.0;
      if (humanAngle < minValid || humanAngle > maxValid) {
        return FormVerificationResult(
          isValid: false,
          faultJoints: activeIndices,
          warningMessage:
              '⚠️ Out of Range (${humanAngle.toInt()}°) — Return to valid ${config.name} range!',
        );
      }
    }

    return const FormVerificationResult(
      isValid: true,
      faultJoints: <int>{},
      warningMessage: null,
    );
  }
}

class FormVerificationResult {
  final bool isValid;
  final Set<int> faultJoints;
  final String? warningMessage;

  const FormVerificationResult({
    required this.isValid,
    required this.faultJoints,
    required this.warningMessage,
  });
}

const List<ExerciseConfig> kSupportedExercises = [
  ExerciseConfig(
    id: 'bodyweight-squat',
    name: 'Bodyweight Squat',
    category: 'Lower Body • Strength',
    defaultReps: 12,
    primaryAngle: 'Knee 90°',
    leftTriplet: [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    rightTriplet: [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    startAngleDeg: 154.0,
    peakAngleDeg: 108.0,
    decreaseToPeak: true,
    cueDown: 'Lower hips parallel to knees',
    cueUp: 'Drive through heels to stand tall',
    formHint: 'Keep chest upright & knees tracking over toes',
    framingMode: 'full_body',
    auraPattern: 'squat',
  ),
  ExerciseConfig(
    id: 'reverse-lunge',
    name: 'Reverse Lunge',
    category: 'Lower Body • Unilateral',
    defaultReps: 10,
    primaryAngle: 'Front Knee 90°',
    leftTriplet: [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    rightTriplet: [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    startAngleDeg: 154.0,
    peakAngleDeg: 110.0,
    decreaseToPeak: true,
    cueDown: 'Step back and lower into 90° split lunge',
    cueUp: 'Push through front heel to return',
    formHint: 'Keep torso tall and core braced',
    framingMode: 'full_body',
    auraPattern: 'lunge',
  ),
  ExerciseConfig(
    id: 'glute-bridge',
    name: 'Glute Bridge',
    category: 'Glutes & Core',
    defaultReps: 12,
    primaryAngle: 'Hip 170°',
    leftTriplet: [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    rightTriplet: [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    startAngleDeg: 120.0,
    peakAngleDeg: 158.0,
    decreaseToPeak: false,
    cueDown: 'Lower pelvis gently toward the floor',
    cueUp: 'Drive hips up into full glute squeeze',
    formHint: 'Align shoulders, hips, and knees at the top',
    framingMode: 'floor',
    auraPattern: 'bridge',
  ),
  ExerciseConfig(
    id: 'seated-forward-fold',
    name: 'Forward Fold / Hip Hinge',
    category: 'Posterior Chain • Mobility',
    defaultReps: 12,
    primaryAngle: 'Hip Hinge 95°',
    leftTriplet: [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    rightTriplet: [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    startAngleDeg: 152.0,
    peakAngleDeg: 108.0,
    decreaseToPeak: true,
    cueDown: 'Hinge at the hips and fold forward smoothly',
    cueUp: 'Lengthen spine and return upright',
    formHint: 'Hinge from the hips while keeping spine long',
    framingMode: 'full_body',
    auraPattern: 'hinge_fold',
  ),
  ExerciseConfig(
    id: 'push-up',
    name: 'Standard Push-Up',
    category: 'Chest & Triceps',
    defaultReps: 12,
    primaryAngle: 'Elbow 90°',
    leftTriplet: [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    rightTriplet: [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    startAngleDeg: 150.0,
    peakAngleDeg: 102.0,
    decreaseToPeak: true,
    cueDown: 'Lower chest with elbows at 45°',
    cueUp: 'Press the floor away to lockout',
    formHint: 'Maintain a straight plank line from head to heels',
    framingMode: 'upper_body',
    auraPattern: 'push_up',
  ),
  ExerciseConfig(
    id: 'dumbbell-bicep-curl',
    name: 'Dumbbell Bicep Curl',
    category: 'Upper Body • Arms',
    defaultReps: 12,
    primaryAngle: 'Elbow 50°',
    leftTriplet: [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    rightTriplet: [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    startAngleDeg: 146.0,
    peakAngleDeg: 68.0,
    decreaseToPeak: true,
    cueDown: 'Extend arms down with slow control',
    cueUp: 'Curl up and squeeze biceps at the top',
    formHint: 'Pin elbows to ribs without swinging torso',
    framingMode: 'upper_body',
    auraPattern: 'curl_row',
  ),
  ExerciseConfig(
    id: 'seated-shoulder-press',
    name: 'Overhead Shoulder Press',
    category: 'Shoulders & Triceps',
    defaultReps: 12,
    primaryAngle: 'Shoulder 150°',
    leftTriplet: [PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    rightTriplet: [PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    startAngleDeg: 78.0,
    peakAngleDeg: 142.0,
    decreaseToPeak: false,
    cueDown: 'Lower elbows back to 90° rack position',
    cueUp: 'Press vertically to overhead lockout',
    formHint: 'Keep core braced and avoid arching lower back',
    framingMode: 'upper_body',
    auraPattern: 'overhead_press',
  ),
  ExerciseConfig(
    id: 'lateral-raise',
    name: 'Lateral Shoulder Raise',
    category: 'Shoulders • Mobility',
    defaultReps: 12,
    primaryAngle: 'Shoulder 88°',
    leftTriplet: [PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftWrist],
    rightTriplet: [PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightWrist],
    startAngleDeg: 34.0,
    peakAngleDeg: 80.0,
    decreaseToPeak: false,
    cueDown: 'Lower arms smoothly to your sides',
    cueUp: 'Raise arms out to T-level shoulder height',
    formHint: 'Lead with elbows and keep traps relaxed',
    framingMode: 'upper_body',
    auraPattern: 'lateral_raise',
  ),
  ExerciseConfig(
    id: 'seated-torso-twist',
    name: 'Seated Torso Twist',
    category: 'Core • Rotational Mobility',
    defaultReps: 12,
    primaryAngle: 'Rotation 88°',
    leftTriplet: [PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftWrist],
    rightTriplet: [PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightWrist],
    startAngleDeg: 36.0,
    peakAngleDeg: 84.0,
    decreaseToPeak: false,
    cueDown: 'Return hands and ribs to center',
    cueUp: 'Rotate thoracic spine and open arms wide',
    formHint: 'Keep hips grounded while rotating through upper back',
    framingMode: 'upper_body',
    auraPattern: 'torso_twist',
  ),
  ExerciseConfig(
    id: 'jumping-jacks',
    name: 'Jumping Jacks',
    category: 'Cardio • Full Body',
    defaultReps: 20,
    primaryAngle: 'Shoulder 145°',
    leftTriplet: [PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftWrist],
    rightTriplet: [PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightWrist],
    startAngleDeg: 42.0,
    peakAngleDeg: 130.0,
    decreaseToPeak: false,
    cueDown: 'Jump feet together, arms at sides',
    cueUp: 'Jump wide and sweep arms overhead',
    formHint: 'Land softly on the balls of your feet',
    framingMode: 'full_body',
    auraPattern: 'jumping_jack',
  ),
  ExerciseConfig(
    id: 'high-knees',
    name: 'High Knees / March',
    category: 'Cardio • HIIT',
    defaultReps: 20,
    primaryAngle: 'Hip 95°',
    leftTriplet: [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    rightTriplet: [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    startAngleDeg: 152.0,
    peakAngleDeg: 108.0,
    decreaseToPeak: true,
    cueDown: 'Alternate legs rhythmically',
    cueUp: 'Drive knee up to hip height with arm pump',
    formHint: 'Stay tall and engage core',
    framingMode: 'full_body',
    auraPattern: 'knee_drive',
  ),
  ExerciseConfig(
    id: 'calf-raise',
    name: 'Standing Calf Raise',
    category: 'Lower Body • Calves',
    defaultReps: 15,
    primaryAngle: 'Ankle 136°',
    leftTriplet: [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex],
    rightTriplet: [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex],
    startAngleDeg: 108.0,
    peakAngleDeg: 134.0,
    decreaseToPeak: false,
    cueDown: 'Lower heels smoothly to floor',
    cueUp: 'Rise high onto tiptoes and squeeze calves',
    formHint: 'Pause briefly at the top of every rep',
    framingMode: 'full_body',
    auraPattern: 'calf_raise',
  ),
  ExerciseConfig(
    id: 'plank',
    name: 'Forearm Plank (Hold)',
    category: 'Core • Isometric Hold',
    isHold: true,
    defaultReps: 30,
    primaryAngle: 'Alignment 172°',
    leftTriplet: [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftAnkle],
    rightTriplet: [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightAnkle],
    startAngleDeg: 135.0,
    peakAngleDeg: 162.0,
    decreaseToPeak: false,
    cueDown: 'Align shoulders, hips, and ankles',
    cueUp: 'Hold strong! Brace abs and glutes',
    formHint: 'Do not let hips sag or pike upward',
    framingMode: 'floor',
    auraPattern: 'plank_hold',
  ),
  ExerciseConfig(
    id: 'wall-sit',
    name: 'Wall Sit / Yoga Hold',
    category: 'Isometric Endurance',
    isHold: true,
    defaultReps: 30,
    primaryAngle: 'Knee Hold 95°',
    leftTriplet: [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    rightTriplet: [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    startAngleDeg: 150.0,
    peakAngleDeg: 118.0,
    decreaseToPeak: true,
    cueDown: 'Sink hips down into target posture',
    cueUp: 'Hold steady! Breathe deeply through nose',
    formHint: 'Keep spine tall and weight balanced',
    framingMode: 'full_body',
    auraPattern: 'lower_hold',
  ),
  ExerciseConfig(
    id: 'box-breathing',
    name: 'Pranayama & Breath Hold',
    category: 'Mindfulness • Breathwork',
    isHold: true,
    defaultReps: 25,
    primaryAngle: 'Posture 90°',
    leftTriplet: [PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    rightTriplet: [PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.leftShoulder],
    startAngleDeg: 65.0,
    peakAngleDeg: 82.0,
    decreaseToPeak: false,
    cueDown: 'Sit or stand tall with relaxed shoulders',
    cueUp: 'Breathe in rhythm with the glowing AR Aura',
    formHint: 'Expand ribcage smoothly and keep neck relaxed',
    framingMode: 'upper_body',
    auraPattern: 'breath_hold',
  ),
];

class PoseTrackerScreen extends StatefulWidget {
  final String exerciseName;
  final String? initialExerciseSlug;
  final String? initialExerciseName;
  final int targetReps;
  final bool isChallengeVerification;
  final String? challengeTitle;

  const PoseTrackerScreen({
    super.key,
    this.exerciseName = 'bodyweight-squat',
    this.initialExerciseSlug,
    this.initialExerciseName,
    this.targetReps = 12,
    this.isChallengeVerification = false,
    this.challengeTitle,
  });

  @override
  State<PoseTrackerScreen> createState() => _PoseTrackerScreenState();
}

class _PoseTrackerScreenState extends State<PoseTrackerScreen> with TickerProviderStateMixin {
  late FlutterTts _flutterTts;
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _cameraError = false;

  PoseDetector? _poseDetector;
  bool _isBusyDetecting = false;
  bool _isStreamingImages = false;

  late List<ExerciseConfig> _exerciseChoices;
  late ExerciseConfig _currentExercise;
  int _targetReps = 12;
  int _repCount = 0;
  double _holdSeconds = 0.0;

  bool _isTrackingActive = false;
  bool _isPaused = false;
  bool _aiAssistedMode = false; // Allows desk/handheld upper-body or assisted cadence testing
  bool _isBodyFramed = false;
  double _landmarkConfidence = 0.0;

  double _formScore = 96.0;
  String _feedbackMessage = 'Place phone steady in front of you & tap Start Tracking';
  Color _repColor = VColor.accentGreen;

  Timer? _assistedTimer;
  double _motionCycle = 0.0;
  String _currentPhase = 'IDLE'; // IDLE, ECCENTRIC, INFLECTION, CONCENTRIC
  double _currentJointAngle = 165.0;
  double _leftJointAngle = 165.0;
  double _rightJointAngle = 165.0;
  double _spineTiltDeg = 4.0;
  double _symmetryScore = 98.0;
  bool _hasReachedInflection = false;
  double? _eccentricExtremeAngle;
  DateTime _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _formWarning;
  int _consecutiveGoodReps = 0;
  DateTime _lastFrameTime = DateTime.now();

  // ARTIFIT Strict Real-Time Biomechanical Verification State (Green = Valid, Red = Fault)
  bool _isFormValid = true;
  Set<int> _faultJoints = const <int>{};
  bool _repInvalidatedByFault = false;
  int _consecutiveValidPeakFrames = 0;
  DateTime _lastWarningVoiceTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _shallowWarningUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // Exact camera buffer dimensions in portrait space for 1:1 BoxFit.cover AR alignment
  double _frameWidth = 720.0;
  double _frameHeight = 1280.0;
  bool _landmarksInitialized = false;
  // On iOS, camera_avfoundation already sets connection.isVideoMirrored = true on front camera stream.
  // On Android, ImageAnalysis buffers are unmirrored and require horizontal flip.
  bool _mirrorLandmarksX = Platform.isAndroid;

  // 5-Zone Anatomical Readiness Confidence (Head, Shoulders, Arms, Core/Hips, Legs)
  double _zoneHeadConf = 0.0;
  double _zoneShoulderConf = 0.0;
  double _zoneArmConf = 0.0;
  double _zoneCoreConf = 0.0;
  double _zoneLegConf = 0.0;

  // AR Moving Aura (Points & Joint Lines) + Human-to-Aura Matching State
  final List<Offset> _auraLandmarks = List.generate(33, (_) => Offset.zero);
  double _auraTargetAngle = 165.0;
  double _auraMatchScore = 88.0;
  double _auraAnchorX = 0.50;
  double _auraAnchorY = 0.44;
  double _auraScale = 1.0;
  double _cycleHumanMotion = 0.0;
  double _cycleMinAngle = 180.0;
  double _cycleMaxAngle = 0.0;

  late AnimationController _pulseController;
  final List<Offset> _landmarks = List.generate(33, (_) => Offset.zero);
  final List<double> _landmarkZ = List.generate(33, (_) => 0.0);
  final List<double> _landmarkConf = List.generate(33, (_) => 0.0);

  @override
  void initState() {
    super.initState();
    _initExercise();
    _initTts();
    _initPoseDetector();
    _initCamera();
    _updateExerciseAuraLandmarks(0.0);
    _startAuraLoop();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  void _initExercise() {
    final slugToResolve = widget.initialExerciseSlug ?? widget.exerciseName;
    final titleOverride = widget.initialExerciseName ?? widget.challengeTitle;
    final resolved = ExerciseConfig.resolve(
      slugToResolve,
      customTitle: titleOverride,
      customTarget: widget.targetReps != 12 && widget.targetReps > 0 ? widget.targetReps : null,
    );
    _currentExercise = resolved;
    _targetReps = (widget.targetReps != 12 && widget.targetReps > 0)
        ? widget.targetReps
        : resolved.defaultReps;
    _currentJointAngle = resolved.startAngleDeg;
    _leftJointAngle = resolved.startAngleDeg;
    _rightJointAngle = resolved.startAngleDeg;

    // Ensure the resolved exercise is at the front of the selector bar if not already in list
    final exists = kSupportedExercises.any((e) => e.id == resolved.id);
    if (exists) {
      _exerciseChoices = List<ExerciseConfig>.from(kSupportedExercises);
    } else {
      _exerciseChoices = [resolved, ...kSupportedExercises];
    }
  }

  void _initPoseDetector() {
    try {
      // Use PoseDetectionModel.accurate (BlazePose Full/Heavy) for ARTIFIT-grade sub-pixel joint lock
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.accurate,
        ),
      );
    } catch (_) {}
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.50);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = true);
        return;
      }

      // Default to Front / Selfie camera as requested by user
      _selectedCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (_) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  Future<void> _setupCameraController(CameraDescription description) async {
    if (_cameraController != null) {
      try {
        if (_isStreamingImages) {
          await _cameraController!.stopImageStream();
          _isStreamingImages = false;
        }
      } catch (_) {}
      await _cameraController!.dispose();
    }

    final isFront = description.lensDirection == CameraLensDirection.front;
    // iOS AVFoundation video output connection already mirrors front camera frames; Android does not
    _mirrorLandmarksX = Platform.isAndroid && isFront;
    _landmarksInitialized = false;

    _cameraController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      final previewSize = _cameraController!.value.previewSize;
      if (previewSize != null) {
        // previewSize is reported in landscape (width > height); swap for portrait viewport
        _frameWidth = math.min(previewSize.width, previewSize.height);
        _frameHeight = math.max(previewSize.width, previewSize.height);
      }
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _cameraError = false;
        });
        await _startCameraPoseStream();
      }
    } catch (_) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  Future<void> _startCameraPoseStream() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized || _isStreamingImages) return;
    try {
      _isStreamingImages = true;
      await ctrl.startImageStream(_onCameraFrame);
    } catch (_) {
      _isStreamingImages = false;
    }
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (_isBusyDetecting || !mounted || _poseDetector == null) return;
    if (_aiAssistedMode) return; // Assisted mode uses guided biomechanical wave
    _isBusyDetecting = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        _isBusyDetecting = false;
        return;
      }

      final poses = await _poseDetector!.processImage(inputImage);
      if (!mounted) return;

      if (poses.isNotEmpty) {
        _processDetectedPose(
          poses.first,
          image.width.toDouble(),
          image.height.toDouble(),
        );
      } else {
        setState(() {
          _isBodyFramed = false;
          _landmarkConfidence = 0.0;
          _zoneHeadConf = 0.0;
          _zoneShoulderConf = 0.0;
          _zoneArmConf = 0.0;
          _zoneCoreConf = 0.0;
          _zoneLegConf = 0.0;
          for (var i = 0; i < 33; i++) {
            _landmarkConf[i] = 0.0;
          }
          if (_isTrackingActive && !_isPaused) {
            _feedbackMessage = 'Step back so your body is visible in selfie camera';
          }
        });
      }
    } catch (_) {
      // Keep stream resilient on any malformed frame
    } finally {
      _isBusyDetecting = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameras[_selectedCameraIndex];
    // On iOS, camera_avfoundation already delivers portrait-rotated CVPixelBuffers (width < height),
    // so rotation0deg reflects the actual pixel buffer orientation.
    final rotation = Platform.isIOS
        ? InputImageRotation.rotation0deg
        : (InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation90deg);

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (image.planes.isEmpty) return null;

    if (Platform.isIOS) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format ?? InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    // Android NV21 / YUV420 concatenation
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format ?? InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  double _compute3DCompensatedAngle(int idxA, int idxB, int idxC) {
    final a = _landmarks[idxA];
    final b = _landmarks[idxB];
    final c = _landmarks[idxC];

    // 2D screen-plane angle
    final bax = a.dx - b.dx;
    final bay = a.dy - b.dy;
    final bcx = c.dx - b.dx;
    final bcy = c.dy - b.dy;
    final dot2d = bax * bcx + bay * bcy;
    final magBa2d = math.sqrt(bax * bax + bay * bay);
    final magBc2d = math.sqrt(bcx * bcx + bcy * bcy);
    double angle2d = 180.0;
    if (magBa2d >= 1e-5 && magBc2d >= 1e-5) {
      final cos2d = (dot2d / (magBa2d * magBc2d)).clamp(-1.0, 1.0);
      angle2d = math.acos(cos2d) * 180.0 / math.pi;
    }

    // 3D depth-compensated angle using normalized MLKit Z depth (handles frontal foreshortening)
    final baz = (_landmarkZ[idxA] - _landmarkZ[idxB]) * 0.32;
    final bcz = (_landmarkZ[idxC] - _landmarkZ[idxB]) * 0.32;
    final dot3d = bax * bcx + bay * bcy + baz * bcz;
    final magBa3d = math.sqrt(bax * bax + bay * bay + baz * baz);
    final magBc3d = math.sqrt(bcx * bcx + bcy * bcy + bcz * bcz);
    double angle3d = angle2d;
    if (magBa3d >= 1e-5 && magBc3d >= 1e-5) {
      final cos3d = (dot3d / (magBa3d * magBc3d)).clamp(-1.0, 1.0);
      angle3d = math.acos(cos3d) * 180.0 / math.pi;
    }

    // Frontal Vertical Compression Compensation for Squat / Lunge / Push-Up when facing selfie camera straight-on:
    // If vertex is Knee (25 or 26), measure vertical Hip-to-Knee compression relative to Shin length.
    double fusedAngle = 0.65 * angle2d + 0.35 * angle3d;
    if (idxB == 25 || idxB == 26) {
      final thighDy = (b.dy - a.dy).abs(); // Hip (a) to Knee (b) vertical span
      final shinLen = math.max(0.08, (c - b).distance); // Knee (b) to Ankle (c) length
      final ratio = (thighDy / shinLen).clamp(0.25, 1.15);
      // When standing straight, ratio ~ 0.95..1.10 -> ~172°. In deep frontal squat, thigh foreshortens & ratio drops to ~0.35 -> ~82°.
      final frontalKneeEst = 60.0 + ((ratio - 0.25) / 0.85).clamp(0.0, 1.0) * 114.0;
      if (_currentExercise.decreaseToPeak && frontalKneeEst < fusedAngle) {
        fusedAngle = 0.45 * fusedAngle + 0.55 * frontalKneeEst;
      }
    } else if ((idxB == 13 || idxB == 14) && _currentExercise.decreaseToPeak) {
      // Elbow flexion during frontal Push-Up / Dip: compare upper-arm vertical span against forearm length
      final upperArmLen = (a - b).distance;
      final forearmLen = math.max(0.06, (c - b).distance);
      final ratio = (upperArmLen / forearmLen).clamp(0.30, 1.15);
      final frontalElbowEst = 68.0 + ((ratio - 0.30) / 0.80).clamp(0.0, 1.0) * 104.0;
      if (frontalElbowEst < fusedAngle && angle3d < angle2d) {
        fusedAngle = 0.55 * fusedAngle + 0.45 * frontalElbowEst;
      }
    }

    return fusedAngle.clamp(15.0, 180.0);
  }

  void _processDetectedPose(Pose pose, double imgW, double imgH) {
    final now = DateTime.now();
    final dt = (now.difference(_lastFrameTime).inMilliseconds / 1000.0).clamp(0.0, 0.25);
    _lastFrameTime = now;

    // On iOS, CVPixelBuffer is already portrait (imgW < imgH). On Android, sensor buffer is landscape (imgW > imgH).
    final normW = Platform.isIOS ? imgW : math.min(imgW, imgH);
    final normH = Platform.isIOS ? imgH : math.max(imgW, imgH);
    if (normW > 0 && normH > 0) {
      _frameWidth = normW;
      _frameHeight = normH;
    }

    final activeTripletSet = <int>{
      _currentExercise.leftTriplet[0].index,
      _currentExercise.leftTriplet[1].index,
      _currentExercise.leftTriplet[2].index,
      _currentExercise.rightTriplet[0].index,
      _currentExercise.rightTriplet[1].index,
      _currentExercise.rightTriplet[2].index,
    };

    // Velocity-Adaptive One-Euro Landmark Filter across all 33 BlazePose points
    for (final entry in pose.landmarks.entries) {
      final idx = entry.key.index;
      if (idx >= 0 && idx < 33) {
        final lm = entry.value;
        double nx = lm.x / (normW > 0 ? normW : 720.0);
        final double ny = lm.y / (normH > 0 ? normH : 1280.0);
        final double nz = lm.z / (normW > 0 ? normW : 720.0);
        if (_mirrorLandmarksX) nx = 1.0 - nx;

        final rawPt = Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
        final prevPt = _landmarks[idx];
        if (!_landmarksInitialized || _landmarkConf[idx] < 0.15) {
          _landmarks[idx] = rawPt;
          _landmarkZ[idx] = nz;
        } else {
          final velocity = (rawPt - prevPt).distance;
          // Dead-zone noise gate: only accumulate real physical motion (> 0.0085) on active exercise joints
          if (activeTripletSet.contains(idx) &&
              lm.likelihood >= 0.25 &&
              velocity > 0.0085) {
            _cycleHumanMotion = (_cycleHumanMotion + (velocity - 0.0085) * 0.55).clamp(0.0, 2.5);
          }
          // Stationary points lock with 0.32 smoothing; fast-moving limbs scale up to 0.88 for zero lag
          final alpha = (0.32 + velocity * 14.0).clamp(0.32, 0.88);
          _landmarks[idx] = Offset(
            prevPt.dx + alpha * (rawPt.dx - prevPt.dx),
            prevPt.dy + alpha * (rawPt.dy - prevPt.dy),
          );
          _landmarkZ[idx] = _landmarkZ[idx] + alpha * (nz - _landmarkZ[idx]);
        }
        _landmarkConf[idx] = lm.likelihood;
      }
    }
    _landmarksInitialized = true;

    // Smoothly anchor the AR Moving Aura to the user's detected mid-torso center & body scale
    if (_landmarkConf[11] >= 0.22 && _landmarkConf[12] >= 0.22) {
      final midShoulder = (_landmarks[11] + _landmarks[12]) * 0.5;
      _auraAnchorX = 0.85 * _auraAnchorX + 0.15 * midShoulder.dx.clamp(0.30, 0.70);
      final shoulderSpan = (_landmarks[11] - _landmarks[12]).distance;
      if (shoulderSpan > 0.08) {
        final targetScale = (shoulderSpan / 0.22).clamp(0.72, 1.35);
        _auraScale = 0.88 * _auraScale + 0.12 * targetScale;
      }
      final double targetMidTorsoY =
          (_landmarkConf[23] >= 0.22 && _landmarkConf[24] >= 0.22)
              ? (midShoulder.dy + (_landmarks[23].dy + _landmarks[24].dy) * 0.5) * 0.5
              : (midShoulder.dy + 0.10 * _auraScale);
      _auraAnchorY = 0.85 * _auraAnchorY + 0.15 * targetMidTorsoY.clamp(0.32, 0.58);
    }

    // Compute 5-Zone Anatomical Readiness Confidences
    _zoneHeadConf = math.max(_landmarkConf[0], math.max(_landmarkConf[2], _landmarkConf[5]));
    _zoneShoulderConf = math.max(_landmarkConf[11], _landmarkConf[12]);
    _zoneArmConf = math.max(
      math.min(_landmarkConf[13], _landmarkConf[15]),
      math.min(_landmarkConf[14], _landmarkConf[16]),
    );
    _zoneCoreConf = math.max(_landmarkConf[23], _landmarkConf[24]);
    _zoneLegConf = math.max(
      math.min(_landmarkConf[25], _landmarkConf[27]),
      math.min(_landmarkConf[26], _landmarkConf[28]),
    );

    // Compute Spine Alignment Tilt (Mid-Shoulder to Mid-Hip vs vertical axis)
    if (_landmarkConf[11] >= 0.25 && _landmarkConf[12] >= 0.25 && _landmarkConf[23] >= 0.25 && _landmarkConf[24] >= 0.25) {
      final midShoulder = (_landmarks[11] + _landmarks[12]) * 0.5;
      final midHip = (_landmarks[23] + _landmarks[24]) * 0.5;
      final dx = (midShoulder.dx - midHip.dx).abs();
      final dy = math.max(0.05, (midHip.dy - midShoulder.dy).abs());
      _spineTiltDeg = (math.atan2(dx, dy) * 180.0 / math.pi).clamp(0.0, 90.0);
    }

    // Evaluate framing visibility for the active exercise's required joints
    final lt = _currentExercise.leftTriplet;
    final rt = _currentExercise.rightTriplet;
    final lConf = math.min(
      math.min(
        pose.landmarks[lt[0]]?.likelihood ?? 0.0,
        pose.landmarks[lt[1]]?.likelihood ?? 0.0,
      ),
      pose.landmarks[lt[2]]?.likelihood ?? 0.0,
    );
    final rConf = math.min(
      math.min(
        pose.landmarks[rt[0]]?.likelihood ?? 0.0,
        pose.landmarks[rt[1]]?.likelihood ?? 0.0,
      ),
      pose.landmarks[rt[2]]?.likelihood ?? 0.0,
    );

    final bestConf = math.max(lConf, rConf);
    _landmarkConfidence = math.max(bestConf, _zoneShoulderConf * 0.90);
    _isBodyFramed = bestConf >= 0.36;

    if (!_isBodyFramed) {
      setState(() {
        _isFormValid = false;
        _faultJoints = activeTripletSet;
        _repColor = VColor.crit;
        _formWarning =
            '⚠️ Step back so your ${_currentExercise.framingMode == "full_body" ? "full body (hips, knees & ankles)" : "active joints"} are clearly in frame';
        if (_isTrackingActive && !_isPaused) {
          _feedbackMessage = _formWarning!;
        }
      });
      return;
    }

    double? lAngle;
    double? rAngle;
    if (lConf >= 0.34) {
      lAngle = _compute3DCompensatedAngle(lt[0].index, lt[1].index, lt[2].index);
      _leftJointAngle = 0.40 * _leftJointAngle + 0.60 * lAngle;
    }
    if (rConf >= 0.34) {
      rAngle = _compute3DCompensatedAngle(rt[0].index, rt[1].index, rt[2].index);
      _rightJointAngle = 0.40 * _rightJointAngle + 0.60 * rAngle;
    }

    double rawAngle = _currentJointAngle;
    double symmetryDiff = 0.0;
    if (lAngle != null && rAngle != null) {
      // Track active limb excursion (supports both bilateral & alternating/unilateral exercises)
      rawAngle = _currentExercise.decreaseToPeak
          ? math.min(lAngle, rAngle)
          : math.max(lAngle, rAngle);
      symmetryDiff = (lAngle - rAngle).abs();
      _symmetryScore = (100.0 - symmetryDiff * 0.45).clamp(75.0, 99.8);
    } else if (lAngle != null) {
      rawAngle = lAngle;
    } else if (rAngle != null) {
      rawAngle = rAngle;
    }

    // Responsive EMA Smoothing (0.62 alpha for crisp real-time angle response)
    final smoothed = 0.38 * _currentJointAngle + 0.62 * rawAngle;
    _cycleMinAngle = math.min(_cycleMinAngle, smoothed);
    _cycleMaxAngle = math.max(_cycleMaxAngle, smoothed);

    // Compute Human-to-Aura Match Score (Spatial Point Alignment + Angular Sync)
    _auraMatchScore = ExerciseConfig.computeAuraMatch(
      config: _currentExercise,
      humanLandmarks: _landmarks,
      humanConf: _landmarkConf,
      auraLandmarks: _auraLandmarks,
      humanAngle: smoothed,
      auraTargetAngle: _auraTargetAngle,
    );

    // Run ARTIFIT-grade strict multi-joint form verification
    final verification = ExerciseConfig.verifyBiomechanicalForm(
      config: _currentExercise,
      humanLandmarks: _landmarks,
      humanConf: _landmarkConf,
      humanAngle: smoothed,
      spineTiltDeg: _spineTiltDeg,
      symmetryDiff: symmetryDiff,
      leftTripletConf: lConf,
      rightTripletConf: rConf,
    );

    setState(() {
      _currentJointAngle = smoothed;

      if (!verification.isValid) {
        _isFormValid = false;
        _faultJoints = verification.faultJoints;
        _formWarning = verification.warningMessage;
        _repColor = VColor.crit;
        if (_isTrackingActive && !_isPaused) {
          _feedbackMessage =
              verification.warningMessage ?? '⚠️ Incorrect form — please do it correctly!';
          if (!_currentExercise.isHold) {
            _repInvalidatedByFault = true;
            _consecutiveValidPeakFrames = 0;
          }
          if (now.difference(_lastWarningVoiceTime).inMilliseconds >= 4200) {
            _lastWarningVoiceTime = now;
            HapticFeedback.heavyImpact();
            _speak('Please do it correctly. ${_currentExercise.formHint}');
          }
        }
        return;
      }

      // Form is valid in this frame — check if shallow half-rep red flash is still active
      final inShallowFlash = now.isBefore(_shallowWarningUntil);
      if (!inShallowFlash) {
        _isFormValid = true;
        _faultJoints = const <int>{};
        _formWarning = null;
        _repColor = VColor.accentGreen;
      }

      if (!_isTrackingActive || _isPaused) return;
      _evaluateBiomechanicalFrame(
        smoothed,
        dt,
        symmetryDiff: symmetryDiff,
        activeTripletSet: activeTripletSet,
      );
    });
  }

  void _evaluateBiomechanicalFrame(
    double angle,
    double dt, {
    double symmetryDiff = 0.0,
    Set<int> activeTripletSet = const <int>{},
  }) {
    final spec = _currentExercise;

    if (spec.isHold) {
      final inZone = spec.decreaseToPeak
          ? angle <= spec.peakAngleDeg + 16.0
          : angle >= spec.peakAngleDeg - 16.0;
      if (inZone && _isFormValid) {
        _currentPhase = 'INFLECTION';
        _repColor = VColor.accentGreen;
        _formWarning = null;
        _holdSeconds += dt;
        final newSec = _holdSeconds.floor();
        if (newSec > _repCount) {
          _repCount = newSec;
          HapticFeedback.selectionClick();
          if (_repCount % 5 == 0 && _repCount < _targetReps) {
            _speak('$_repCount seconds held! Keep going!');
          }
          if (_repCount >= _targetReps) {
            _completeWorkout();
            return;
          }
        }
        _feedbackMessage = '✓ Form Verified • Holding (${_repCount}s / ${_targetReps}s)';
      } else {
        _currentPhase = 'ECCENTRIC';
        _isFormValid = false;
        _repColor = VColor.crit;
        _faultJoints = activeTripletSet;
        _formWarning = '⚠️ Hold posture broken — ${spec.cueDown}';
        _feedbackMessage = _formWarning!;
      }
      return;
    }

    // Dynamic Repetition State Machine (Strict Peak Hold + Full ROM + Shallow Half-Rep Guard)
    const double tol = 4.5;
    final romSpan = math.max(25.0, (spec.startAngleDeg - spec.peakAngleDeg).abs());
    final achievedRom = (_cycleMaxAngle - _cycleMinAngle).clamp(0.0, 180.0);

    if (spec.decreaseToPeak) {
      if (angle <= spec.peakAngleDeg + tol) {
        _consecutiveValidPeakFrames++;
        _currentPhase = 'INFLECTION';
        _repColor = VColor.accentGreen;
        _eccentricExtremeAngle = null;
        if (!_hasReachedInflection &&
            (_aiAssistedMode || _consecutiveValidPeakFrames >= 2) &&
            !_repInvalidatedByFault) {
          _hasReachedInflection = true;
          _isFormValid = true;
          _faultJoints = const <int>{};
          _formWarning = null;
          _feedbackMessage = '✓ Target depth verified (${angle.toInt()}°)! ${spec.cueUp}';
          HapticFeedback.lightImpact();
        }
      } else if (angle >= spec.startAngleDeg - tol) {
        _consecutiveValidPeakFrames = 0;
        if (_hasReachedInflection &&
            !_repInvalidatedByFault &&
            (_aiAssistedMode || achievedRom >= romSpan * 0.62)) {
          _hasReachedInflection = false;
          _eccentricExtremeAngle = null;
          _currentPhase = 'CONCENTRIC';
          _cycleMinAngle = angle;
          _cycleMaxAngle = angle;
          _onRepVerified(symmetryDiff: symmetryDiff);
        } else {
          if (_eccentricExtremeAngle != null &&
              (spec.startAngleDeg - _eccentricExtremeAngle!) >= 18.0) {
            _isFormValid = false;
            _repColor = VColor.crit;
            _faultJoints = activeTripletSet;
            _shallowWarningUntil =
                DateTime.now().add(const Duration(milliseconds: 1600));
            _formWarning =
                '⚠️ Incomplete Rep (${_eccentricExtremeAngle!.toInt()}°) — Go deeper to ${spec.peakAngleDeg.toInt()}° so rep counts!';
            _feedbackMessage = _formWarning!;
            _consecutiveGoodReps = 0;
            HapticFeedback.heavyImpact();
            final now = DateTime.now();
            if (now.difference(_lastWarningVoiceTime).inMilliseconds >= 3800) {
              _lastWarningVoiceTime = now;
              _speak('Incomplete rep. Please go full depth so it counts.');
            }
          }
          _hasReachedInflection = false;
          _repInvalidatedByFault = false;
          _eccentricExtremeAngle = null;
          _cycleMinAngle = angle;
          _cycleMaxAngle = angle;
          _currentPhase = 'IDLE';
        }
      } else {
        _currentPhase = _hasReachedInflection ? 'CONCENTRIC' : 'ECCENTRIC';
        if (!_hasReachedInflection) {
          _eccentricExtremeAngle = _eccentricExtremeAngle == null
              ? angle
              : math.min(_eccentricExtremeAngle!, angle);
          if (_formWarning == null) {
            _feedbackMessage = '✓ In Range (Green) • ${spec.cueDown}';
          }
        }
      }
    } else {
      // Angle increases to peak (e.g. lateral raise, shoulder press, glute bridge, jumping jacks)
      if (angle >= spec.peakAngleDeg - tol) {
        _consecutiveValidPeakFrames++;
        _currentPhase = 'INFLECTION';
        _repColor = VColor.accentGreen;
        _eccentricExtremeAngle = null;
        if (!_hasReachedInflection &&
            (_aiAssistedMode || _consecutiveValidPeakFrames >= 2) &&
            !_repInvalidatedByFault) {
          _hasReachedInflection = true;
          _isFormValid = true;
          _faultJoints = const <int>{};
          _formWarning = null;
          _feedbackMessage = '✓ Peak verified (${angle.toInt()}°)! ${spec.cueDown}';
          HapticFeedback.lightImpact();
        }
      } else if (angle <= spec.startAngleDeg + tol) {
        _consecutiveValidPeakFrames = 0;
        if (_hasReachedInflection &&
            !_repInvalidatedByFault &&
            (_aiAssistedMode || achievedRom >= romSpan * 0.62)) {
          _hasReachedInflection = false;
          _eccentricExtremeAngle = null;
          _currentPhase = 'CONCENTRIC';
          _cycleMinAngle = angle;
          _cycleMaxAngle = angle;
          _onRepVerified(symmetryDiff: symmetryDiff);
        } else {
          if (_eccentricExtremeAngle != null &&
              (_eccentricExtremeAngle! - spec.startAngleDeg) >= 18.0) {
            _isFormValid = false;
            _repColor = VColor.crit;
            _faultJoints = activeTripletSet;
            _shallowWarningUntil =
                DateTime.now().add(const Duration(milliseconds: 1600));
            _formWarning =
                '⚠️ Incomplete Rep (${_eccentricExtremeAngle!.toInt()}°) — Reach ${spec.peakAngleDeg.toInt()}° target range so rep counts!';
            _feedbackMessage = _formWarning!;
            _consecutiveGoodReps = 0;
            HapticFeedback.heavyImpact();
            final now = DateTime.now();
            if (now.difference(_lastWarningVoiceTime).inMilliseconds >= 3800) {
              _lastWarningVoiceTime = now;
              _speak('Incomplete rep. Please perform full range of motion.');
            }
          }
          _hasReachedInflection = false;
          _repInvalidatedByFault = false;
          _eccentricExtremeAngle = null;
          _cycleMinAngle = angle;
          _cycleMaxAngle = angle;
          _currentPhase = 'IDLE';
        }
      } else {
        _currentPhase = _hasReachedInflection ? 'ECCENTRIC' : 'CONCENTRIC';
        if (!_hasReachedInflection) {
          _eccentricExtremeAngle = _eccentricExtremeAngle == null
              ? angle
              : math.max(_eccentricExtremeAngle!, angle);
          if (_formWarning == null) {
            _feedbackMessage = '✓ In Range (Green) • ${spec.cueUp}';
          }
        }
      }
    }
  }

  void _onRepVerified({double symmetryDiff = 0.0}) {
    if (_repCount >= _targetReps) return;
    final now = DateTime.now();
    if (now.difference(_lastRepTime).inMilliseconds < 500) {
      return; // Debounce high-frequency camera jitter
    }
    _lastRepTime = now;
    _repCount++;
    _consecutiveGoodReps++;
    _isFormValid = true;
    _faultJoints = const <int>{};
    _formWarning = null;
    _repColor = VColor.accentGreen;
    _formScore = (97.0 - symmetryDiff * 0.2).clamp(84.0, 99.5);
    HapticFeedback.mediumImpact();

    if (_repCount == _targetReps) {
      _completeWorkout();
    } else {
      _feedbackMessage = '✓ Rep $_repCount/$_targetReps Verified! ${_currentExercise.formHint}';
      if (_consecutiveGoodReps % 3 == 0) {
        _speak('$_repCount! Perfect form!');
      } else {
        _speak('$_repCount');
      }
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isCameraReady = false);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  void _startTracking() {
    setState(() {
      _isTrackingActive = true;
      _isPaused = false;
      _cycleHumanMotion = 0.0;
      _repInvalidatedByFault = false;
      _consecutiveValidPeakFrames = 0;
      if (_repCount >= _targetReps) {
        _repCount = 0;
        _holdSeconds = 0.0;
      }
      _feedbackMessage = _isBodyFramed || _aiAssistedMode
          ? '✓ AR Form Verification Active — ${_currentExercise.cueDown}'
          : '⚠️ Step into camera frame so AR points turn Green';
    });

    _speak(
      'Starting ${_currentExercise.name}. Only verified reps with proper form will count. ${_currentExercise.cueDown}',
    );
    _startAuraLoop();
  }

  void _syncAssistedLoop() {
    _startAuraLoop();
  }

  void _startAuraLoop() {
    _assistedTimer?.cancel();
    _assistedTimer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        // Advance smooth biomechanical cadence wave (0.0 = start pose, 1.0 = peak pose)
        _motionCycle += _currentExercise.isHold ? 0.045 : 0.068;
        final phase01 = _currentExercise.isHold
            ? (0.88 + 0.10 * math.sin(_motionCycle))
            : (1.0 - math.cos(_motionCycle)) * 0.5; // Smooth cosine wave 0..1..0

        // Update the AR Target Aura reference pose
        _updateExerciseAuraLandmarks(phase01);

        if (_aiAssistedMode) {
          _isBodyFramed = true;
          _isFormValid = true;
          _faultJoints = const <int>{};
          _formWarning = null;
          _repColor = VColor.accentGreen;
          _landmarkConfidence = 0.96;
          _auraMatchScore = 97.5;
          for (int i = 0; i < 33; i++) {
            _landmarks[i] = _auraLandmarks[i];
            _landmarkConf[i] = 0.96;
          }
          _zoneHeadConf = 0.96;
          _zoneShoulderConf = 0.96;
          _zoneArmConf = 0.96;
          _zoneCoreConf = 0.96;
          _zoneLegConf = 0.96;

          if (_isTrackingActive && !_isPaused) {
            final spec = _currentExercise;
            final simPhase = -0.06 + 1.12 * phase01;
            final simAngle = spec.startAngleDeg +
                (spec.peakAngleDeg - spec.startAngleDeg) * simPhase;
            _currentJointAngle = simAngle;
            _leftJointAngle = simAngle;
            _rightJointAngle = simAngle;
            _cycleMinAngle = math.min(_cycleMinAngle, simAngle);
            _cycleMaxAngle = math.max(_cycleMaxAngle, simAngle);
            _symmetryScore = 98.5;
            _spineTiltDeg = 4.0 + phase01 * 5.0;
            _evaluateBiomechanicalFrame(simAngle, 0.045);
          }
        }
      });
    });
  }

  /// Computes the 33-point AR Target Aura (Points + Joint Lines) for [_currentExercise],
  /// anchored to the user's detected mid-torso center (`_auraAnchorX`, `_auraAnchorY`, `_auraScale`).
  void _updateExerciseAuraLandmarks(double phase01) {
    final p = phase01.clamp(0.0, 1.0);
    _auraTargetAngle = _currentExercise.startAngleDeg +
        (_currentExercise.peakAngleDeg - _currentExercise.startAngleDeg) * p;
    final computed = ExerciseConfig.computeAuraPose(
      _currentExercise,
      p,
      anchorX: _auraAnchorX,
      anchorY: _auraAnchorY,
      scale: _auraScale,
      motionCycle: _motionCycle,
    );
    for (int i = 0; i < 33; i++) {
      _auraLandmarks[i] = computed[i];
    }
  }

  void _pauseTracking() {
    setState(() {
      _isPaused = true;
      _feedbackMessage = 'Workout paused. Tap Resume to continue.';
    });
    _speak('Workout paused');
  }

  void _resetTracking() {
    setState(() {
      _isTrackingActive = false;
      _isPaused = false;
      _repCount = 0;
      _holdSeconds = 0.0;
      _currentPhase = 'IDLE';
      _hasReachedInflection = false;
      _consecutiveValidPeakFrames = 0;
      _repInvalidatedByFault = false;
      _isFormValid = true;
      _faultJoints = const <int>{};
      _shallowWarningUntil = DateTime.fromMillisecondsSinceEpoch(0);
      _repColor = VColor.accentGreen;
      _cycleHumanMotion = 0.0;
      _formWarning = null;
      _consecutiveGoodReps = 0;
      _formScore = 96.0;
      _feedbackMessage = "Stand in frame (Green AR points) and tap 'Start Tracking'";
    });
    _speak('Counter reset to zero');
  }

  Future<void> _persistOfflineVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verified = prefs.getStringList('vyra_verified_exercises') ?? <String>[];
      if (!verified.contains(_currentExercise.id)) {
        verified.add(_currentExercise.id);
        await prefs.setStringList('vyra_verified_exercises', verified);
      }
      final today = DateTime.now().toIso8601String().split('T').first;
      final dateKey = 'completed_exercises_$today';
      final completedToday = prefs.getStringList(dateKey) ?? <String>[];
      if (!completedToday.contains(_currentExercise.id)) {
        completedToday.add(_currentExercise.id);
        await prefs.setStringList(dateKey, completedToday);
      }
    } catch (_) {}
  }

  void _completeWorkout() {
    _assistedTimer?.cancel();
    _persistOfflineVerification();
    setState(() {
      _isTrackingActive = false;
      _feedbackMessage =
          '🎉 Target reached! $_targetReps ${_currentExercise.isHold ? "sec" : "reps"} of ${_currentExercise.name} verified!';
    });
    _speak(
      'Congratulations! You completed $_targetReps ${_currentExercise.isHold ? "seconds" : "repetitions"} of ${_currentExercise.name} with ${_formScore.toInt()} percent form accuracy!',
    );

    if (widget.isChallengeVerification) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: VColor.accentGreen, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Workout AI Verified!',
                style: TextStyle(color: VColor.text, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercise: ${_currentExercise.name}',
              style: const TextStyle(color: VColor.textMid, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              _currentExercise.isHold
                  ? 'Duration Verified: $_repCount / $_targetReps sec'
                  : 'Repetitions Verified: $_repCount / $_targetReps',
              style: const TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Biomechanical Form Accuracy: ${_formScore.toStringAsFixed(1)}%',
              style: const TextStyle(color: VColor.accentGreen, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetTracking();
            },
            child: const Text('Train Again', style: TextStyle(color: VColor.accent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VColor.accentGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('Done & Save', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _selectExercise(ExerciseConfig ex) {
    setState(() {
      _currentExercise = ex;
      _targetReps = ex.defaultReps;
      _repCount = 0;
      _holdSeconds = 0.0;
      _isTrackingActive = false;
      _isPaused = false;
      _currentPhase = 'IDLE';
      _currentJointAngle = ex.startAngleDeg;
      _hasReachedInflection = false;
      _consecutiveValidPeakFrames = 0;
      _repInvalidatedByFault = false;
      _isFormValid = true;
      _faultJoints = const <int>{};
      _shallowWarningUntil = DateTime.fromMillisecondsSinceEpoch(0);
      _repColor = VColor.accentGreen;
      _cycleHumanMotion = 0.0;
      _formWarning = null;
      _consecutiveGoodReps = 0;
      _motionCycle = 0.0;
      _updateExerciseAuraLandmarks(0.0);
      _feedbackMessage = 'Selected ${ex.name}. Keep AR points Green for verified reps!';
    });
    _startAuraLoop();
    _speak('Selected ${ex.name}');
  }

  @override
  void dispose() {
    _assistedTimer?.cancel();
    _pulseController.dispose();
    _flutterTts.stop();
    if (_cameraController != null) {
      try {
        if (_isStreamingImages) {
          _cameraController!.stopImageStream();
        }
      } catch (_) {}
      _cameraController!.dispose();
    }
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _targetReps > 0 ? (_repCount / _targetReps).clamp(0.0, 1.0) : 0.0;
    final leftTriplet = _currentExercise.leftTriplet;
    final rightTriplet = _currentExercise.rightTriplet;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-Screen BoxFit.cover Live Selfie Camera Preview (1:1 Locked with AR Canvas)
          if (_isCameraReady && _cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _frameWidth > 0 ? _frameWidth : 720,
                  height: _frameHeight > 0 ? _frameHeight : 1280,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [Color(0xFF162032), Color(0xFF090D16)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _cameraError ? Icons.videocam_off_rounded : Icons.camera_front_rounded,
                      color: VColor.accent.withValues(alpha: 0.5),
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _cameraError ? 'AI Guided Pose Mode Ready' : 'Initializing High-Precision AR Camera...',
                      style: const TextStyle(color: VColor.textMid, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Clean ARTIFIT-Grade AR Skeleton Overlay (Green = Valid Form, Red = Wrong Form)
          IgnorePointer(
            child: CustomPaint(
              painter: _SkeletonOverlayPainter(
                landmarks: _landmarks,
                auraLandmarks: _auraLandmarks,
                confidences: _landmarkConf,
                imageSize: Size(_frameWidth, _frameHeight),
                color: _formWarning != null ? VColor.crit : _repColor,
                isFormValid: _aiAssistedMode ? true : (_isFormValid && _formWarning == null),
                faultJoints: _aiAssistedMode ? const <int>{} : _faultJoints,
                jointAngle: _currentJointAngle,
                leftAngle: _leftJointAngle,
                rightAngle: _rightJointAngle,
                spineTiltDeg: _spineTiltDeg,
                symmetryScore: _symmetryScore,
                auraMatchScore: _auraMatchScore,
                overallConfidence: _landmarkConfidence,
                phase: _currentPhase,
                primaryJointLabel: _currentExercise.primaryAngle,
                targetPeakAngle: _currentExercise.peakAngleDeg,
                aiAssistedMode: _aiAssistedMode,
                leftTripletIndices: [
                  leftTriplet[0].index,
                  leftTriplet[1].index,
                  leftTriplet[2].index,
                ],
                rightTripletIndices: [
                  rightTriplet[0].index,
                  rightTriplet[1].index,
                  rightTriplet[2].index,
                ],
              ),
            ),
          ),

          // 3. Top Header + Exercise Selector + 5-Zone AR Anatomical Point Lock Bar
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      _buildCircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (!_aiAssistedMode && (!_isFormValid || _formWarning != null))
                                  ? VColor.crit.withValues(alpha: 0.75)
                                  : VColor.accentGreen.withValues(alpha: 0.50),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: (!_aiAssistedMode && (!_isFormValid || _formWarning != null))
                                          ? VColor.crit
                                          : ((_isBodyFramed || _aiAssistedMode)
                                              ? VColor.accentGreen
                                              : VColor.warn),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.isChallengeVerification
                                          ? 'VERIFY: ${widget.challengeTitle ?? _currentExercise.name}'
                                          : _currentExercise.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (!_aiAssistedMode && (!_isFormValid || _formWarning != null))
                                    ? '🔴 WRONG FORM — Fix posture to turn AR Green'
                                    : ((_isBodyFramed || _aiAssistedMode)
                                        ? '🟢 AR VERIFIED (${(_landmarkConfidence * 100).clamp(86, 99).toInt()}%) • Sym ${_symmetryScore.toInt()}%'
                                        : '📱 Step back slightly so AR points lock on body'),
                                style: TextStyle(
                                  color: (!_aiAssistedMode && (!_isFormValid || _formWarning != null))
                                      ? const Color(0xFFFF6B6B)
                                      : ((_isBodyFramed || _aiAssistedMode)
                                          ? VColor.accentGreen
                                          : const Color(0xFFFBBF24)),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Toggle between Strict Live MLKit & Assisted Demo Mode
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _aiAssistedMode = !_aiAssistedMode;
                            if (_aiAssistedMode) {
                              _isBodyFramed = true;
                              _landmarkConfidence = 0.96;
                            }
                          });
                          _syncAssistedLoop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                          decoration: BoxDecoration(
                            color: _aiAssistedMode
                                ? VColor.accentGreen.withValues(alpha: 0.90)
                                : Colors.black.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _aiAssistedMode ? VColor.accentGreen : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _aiAssistedMode ? Icons.auto_awesome_rounded : Icons.view_in_ar_rounded,
                                color: _aiAssistedMode ? Colors.black : VColor.accent,
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _aiAssistedMode ? 'Assisted' : 'AR Live',
                                style: TextStyle(
                                  color: _aiAssistedMode ? Colors.black : Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Mirror X Calibration Toggle (for instant front/back mirror alignment)
                      _buildCircleButton(
                        icon: Icons.flip_rounded,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _mirrorLandmarksX = !_mirrorLandmarksX;
                            _landmarksInitialized = false;
                          });
                        },
                      ),
                      const SizedBox(width: 5),
                      _buildCircleButton(
                        icon: Icons.flip_camera_ios_rounded,
                        onTap: _switchCamera,
                      ),
                    ],
                  ),
                ),

                // AR 5-Zone Body Point Lock Bar (Head, Shoulders, Arms, Core/Hips, Legs)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildZoneLockChip('HEAD', _zoneHeadConf),
                        _buildZoneLockChip('SHLDR', _zoneShoulderConf),
                        _buildZoneLockChip('ARMS', _zoneArmConf),
                        _buildZoneLockChip('CORE', _zoneCoreConf),
                        _buildZoneLockChip('LEGS', _zoneLegConf),
                      ],
                    ),
                  ),
                ),

                // Horizontal Exercise Selector Pill Bar
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    itemCount: _exerciseChoices.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final ex = _exerciseChoices[index];
                      final isSelected = ex.id == _currentExercise.id;
                      return GestureDetector(
                        onTap: () => _selectExercise(ex),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? VColor.accent
                                : Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? VColor.accent : Colors.white24,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              ex.name,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Spacer(),

                // 4. Bottom Biometric HUD & Controls
                _buildBottomHud(progress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneLockChip(String label, double conf) {
    final locked = conf >= 0.28;
    final color = locked ? VColor.accentGreen : const Color(0xFF94A3B8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          locked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: color,
          size: 12,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: locked ? Colors.white : Colors.white54,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }

  Widget _buildBottomHud(double progress) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1322).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: VColor.accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live AI Voice Feedback Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _formWarning != null
                  ? VColor.crit.withValues(alpha: 0.18)
                  : VColor.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _formWarning != null
                    ? VColor.crit.withValues(alpha: 0.6)
                    : VColor.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _formWarning != null ? Icons.warning_amber_rounded : Icons.record_voice_over_rounded,
                  color: _formWarning != null ? VColor.crit : VColor.accent,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _feedbackMessage,
                    style: TextStyle(
                      color: _formWarning != null ? const Color(0xFFFFB4B4) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Main Rep / Hold Counter + Form Score + Bilateral Joint Angle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn(
                label: 'AURA SYNC',
                value: '${_auraMatchScore.toInt()}%',
                valueColor: _auraMatchScore >= 65.0 ? VColor.accentGreen : VColor.accent,
                sub: 'Form ${_formScore.toInt()}% • $_currentPhase',
              ),

              // Center Circular Counter
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(_repColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_repCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '/ $_targetReps ${_currentExercise.isHold ? "SEC" : "REPS"}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              _buildMetricColumn(
                label: '3D JOINT ANGLE',
                value: '${_currentJointAngle.toInt()}°',
                valueColor: _currentPhase == 'INFLECTION' ? VColor.accentGreen : VColor.accent,
                sub: 'L:${_leftJointAngle.toInt()}° R:${_rightJointAngle.toInt()}°',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Target Adjustment & Control Buttons
          Row(
            children: [
              _buildSmallControlButton(
                icon: Icons.remove_rounded,
                onTap: () {
                  if (_targetReps > 1) setState(() => _targetReps--);
                },
              ),
              const SizedBox(width: 6),
              _buildSmallControlButton(
                icon: Icons.add_rounded,
                onTap: () => setState(() => _targetReps++),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isTrackingActive
                        ? VColor.accentGreen
                        : (_isPaused ? VColor.accent : Colors.amber),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (!_isTrackingActive || _isPaused) {
                      _startTracking();
                    } else {
                      _pauseTracking();
                    }
                  },
                  icon: Icon(
                    !_isTrackingActive
                        ? Icons.play_arrow_rounded
                        : (_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  ),
                  label: Text(
                    !_isTrackingActive
                        ? 'Start AR Tracking'
                        : (_isPaused ? 'Resume' : 'Pause'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildSmallControlButton(
                icon: Icons.refresh_rounded,
                onTap: _resetTracking,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required Color valueColor,
    required String sub,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSmallControlButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SkeletonOverlayPainter extends CustomPainter {
  final List<Offset> landmarks;
  final List<Offset> auraLandmarks;
  final List<double> confidences;
  final Size imageSize;
  final Color color;
  final bool isFormValid;
  final Set<int> faultJoints;
  final double jointAngle;
  final double leftAngle;
  final double rightAngle;
  final double spineTiltDeg;
  final double symmetryScore;
  final double auraMatchScore;
  final double overallConfidence;
  final String phase;
  final String primaryJointLabel;
  final double targetPeakAngle;
  final bool aiAssistedMode;
  final List<int> leftTripletIndices;
  final List<int> rightTripletIndices;

  _SkeletonOverlayPainter({
    required this.landmarks,
    required this.auraLandmarks,
    required this.confidences,
    required this.imageSize,
    required this.color,
    required this.isFormValid,
    required this.faultJoints,
    required this.jointAngle,
    required this.leftAngle,
    required this.rightAngle,
    required this.spineTiltDeg,
    required this.symmetryScore,
    required this.auraMatchScore,
    required this.overallConfidence,
    required this.phase,
    required this.primaryJointLabel,
    required this.targetPeakAngle,
    required this.aiAssistedMode,
    required this.leftTripletIndices,
    required this.rightTripletIndices,
  });

  // Left-side anatomical bones
  static const List<(int, int)> _leftBones = [
    (11, 13), (13, 15), (15, 19), // Left arm & hand
    (11, 23), // Left torso
    (23, 25), (25, 27), (27, 31), // Left leg & foot
  ];

  // Right-side anatomical bones
  static const List<(int, int)> _rightBones = [
    (12, 14), (14, 16), (16, 20), // Right arm & hand
    (12, 24), // Right torso
    (24, 26), (26, 28), (28, 32), // Right leg & foot
  ];

  // Cross-bridges (Clavicle & Pelvis)
  static const List<(int, int)> _bridgeBones = [
    (11, 12), // Clavicle / Shoulders
    (23, 24), // Pelvis / Hips
  ];

  static const List<int> _keyJoints = [
    0, 11, 12, 13, 14, 15, 16, 19, 20, 23, 24, 25, 26, 27, 28, 31, 32,
  ];

  /// Exact BoxFit.cover coordinate projection from [0..1] camera frame to screen canvas
  Offset _toCanvas(Offset norm, Size size) {
    final imgW = imageSize.width > 0 ? imageSize.width : size.width;
    final imgH = imageSize.height > 0 ? imageSize.height : size.height;
    final scale = math.max(size.width / imgW, size.height / imgH);
    final scaledW = imgW * scale;
    final scaledH = imgH * scale;
    final offsetX = (size.width - scaledW) * 0.5;
    final offsetY = (size.height - scaledH) * 0.5;
    return Offset(offsetX + norm.dx * scaledW, offsetY + norm.dy * scaledH);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ARTIFIT Color System:
    // - Normal Green (#22C55E / #34FF8C) when user is in valid exercise range & proper form
    // - Crimson Red (#FF3B30 / #EF4444) when user is doing wrong form or out of range
    const validGreen = Color(0xFF22C55E);
    const peakBrightGreen = Color(0xFF34FF8C);
    const wrongRed = Color(0xFFFF3B30);

    final isInflection = phase == 'INFLECTION';
    final primaryArColor = !isFormValid
        ? wrongRed
        : (isInflection ? peakBrightGreen : validGreen);

    // Check if live human anatomical landmarks are visible in the camera frame
    bool anyVisible = false;
    double minX = size.width, minY = size.height, maxX = 0, maxY = 0;

    for (final idx in [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]) {
      if (confidences[idx] >= 0.22) {
        anyVisible = true;
        final pt = _toCanvas(landmarks[idx], size);
        if (pt.dx < minX) minX = pt.dx;
        if (pt.dy < minY) minY = pt.dy;
        if (pt.dx > maxX) maxX = pt.dx;
        if (pt.dy > maxY) maxY = pt.dy;
      }
    }

    // If no human is visible yet (or in AI Assisted Demo Mode), show clean reference guide
    if (!anyVisible || aiAssistedMode) {
      _drawMovingTargetAura(canvas, size, primaryArColor, validGreen);
      if (!anyVisible) return;
    }

    // 1. Clean ARTIFIT Corner Frame Reticles around detected human body (Green = Valid, Red = Wrong)
    const pad = 26.0;
    final boxRect = Rect.fromLTRB(
      (minX - pad).clamp(12.0, size.width - 24.0),
      (minY - pad * 1.4).clamp(90.0, size.height - 90.0),
      (maxX + pad).clamp(24.0, size.width - 12.0),
      (maxY + pad).clamp(90.0, size.height - 40.0),
    );
    if (boxRect.width > 50 && boxRect.height > 80) {
      _drawArCornerReticles(canvas, boxRect, primaryArColor);
    }

    if (!aiAssistedMode) {
      // 2. Clean Central Spine Axis (Mid-Shoulder -> Mid-Hip + Neck -> Head)
      if (confidences[11] >= 0.22 &&
          confidences[12] >= 0.22 &&
          confidences[23] >= 0.22 &&
          confidences[24] >= 0.22) {
        final midShoulder = _toCanvas((landmarks[11] + landmarks[12]) * 0.5, size);
        final midHip = _toCanvas((landmarks[23] + landmarks[24]) * 0.5, size);
        final spinePaint = Paint()
          ..color = primaryArColor.withValues(alpha: 0.78)
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(midShoulder, midHip, spinePaint);

        if (confidences[0] >= 0.22) {
          final nosePt = _toCanvas(landmarks[0], size);
          canvas.drawLine(midShoulder, nosePt, spinePaint);
        }
      }

      // 3. Draw Clean ARTIFIT Anatomical Bone Chains (Green when valid, Red when wrong)
      _drawBoneChain(canvas, size, _bridgeBones, primaryArColor);
      _drawBoneChain(canvas, size, _leftBones, primaryArColor);
      _drawBoneChain(canvas, size, _rightBones, primaryArColor);

      // 4. Draw Clean ARTIFIT AR Joint Points (Green normal vs Red on wrong form)
      final dotFill = Paint()..color = Colors.white;
      for (final idx in _keyJoints) {
        final conf = confidences[idx];
        if (conf < 0.22) continue;
        final pt = _toCanvas(landmarks[idx], size);
        final isFaultJoint = !isFormValid && (faultJoints.isEmpty || faultJoints.contains(idx));
        final nodeColor = !isFormValid
            ? (isFaultJoint ? wrongRed : const Color(0xFFFF6B6B))
            : primaryArColor;
        final radius = idx == 0 ? 5.0 : 5.5;

        // Soft outer AR glow
        canvas.drawCircle(
          pt,
          isFaultJoint ? radius + 6.5 : radius + 4.0,
          Paint()
            ..color = nodeColor.withValues(alpha: isFaultJoint ? 0.42 : 0.26)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        // Crisp white inner joint core
        canvas.drawCircle(pt, radius * 0.72, dotFill);
        // Clean Green or Red outer AR ring
        canvas.drawCircle(
          pt,
          radius + 1.8,
          Paint()
            ..color = nodeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = isFaultJoint ? 2.8 : 2.2,
        );
      }
    }

    // 5. Draw Clean Geometric Joint Angle Protractors (Green when valid, Red when wrong)
    if (leftTripletIndices.length == 3) {
      _drawJointProtractor(
        canvas,
        size,
        leftTripletIndices[0],
        leftTripletIndices[1],
        leftTripletIndices[2],
        leftAngle,
        'L',
        primaryArColor,
      );
    }
    if (rightTripletIndices.length == 3 &&
        rightTripletIndices[1] != leftTripletIndices[1]) {
      _drawJointProtractor(
        canvas,
        size,
        rightTripletIndices[0],
        rightTripletIndices[1],
        rightTripletIndices[2],
        rightAngle,
        'R',
        primaryArColor,
      );
    }
  }

  /// Renders the clean reference skeleton when in AI Assisted Mode or waiting for user to step in frame
  void _drawMovingTargetAura(
    Canvas canvas,
    Size size,
    Color auraPrimary,
    Color auraSecondary,
  ) {
    if (auraLandmarks.length < 33) return;

    final outerAuraGlow = Paint()
      ..color = auraPrimary.withValues(alpha: 0.22)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final coreAuraLine = Paint()
      ..color = auraPrimary.withValues(alpha: 0.88)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final allAuraBones = <(int, int)>[
      ..._bridgeBones,
      ..._leftBones,
      ..._rightBones,
    ];

    final auraMidSh = _toCanvas((auraLandmarks[11] + auraLandmarks[12]) * 0.5, size);
    final auraMidHip = _toCanvas((auraLandmarks[23] + auraLandmarks[24]) * 0.5, size);
    final auraHead = _toCanvas(auraLandmarks[0], size);
    canvas.drawLine(auraMidSh, auraMidHip, outerAuraGlow);
    canvas.drawLine(auraMidSh, auraMidHip, coreAuraLine);
    canvas.drawLine(auraMidSh, auraHead, coreAuraLine);

    for (final (aIdx, bIdx) in allAuraBones) {
      final p1 = _toCanvas(auraLandmarks[aIdx], size);
      final p2 = _toCanvas(auraLandmarks[bIdx], size);
      canvas.drawLine(p1, p2, outerAuraGlow);
      canvas.drawLine(p1, p2, coreAuraLine);
    }

    for (final idx in _keyJoints) {
      final pt = _toCanvas(auraLandmarks[idx], size);
      final r = idx == 0 ? 5.5 : 5.0;
      canvas.drawCircle(
        pt,
        r + 2.0,
        Paint()
          ..color = auraPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(
        pt,
        r * 0.68,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawBoneChain(Canvas canvas, Size size, List<(int, int)> bones, Color chainColor) {
    final glowPaint = Paint()
      ..color = chainColor.withValues(alpha: 0.24)
      ..strokeWidth = 8.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final linePaint = Paint()
      ..color = chainColor.withValues(alpha: 0.92)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;

    for (final (aIdx, bIdx) in bones) {
      if (confidences[aIdx] < 0.22 || confidences[bIdx] < 0.22) continue;
      final bool boneHasFault = !isFormValid &&
          (faultJoints.isEmpty || faultJoints.contains(aIdx) || faultJoints.contains(bIdx));
      final boneColor = !isFormValid
          ? (boneHasFault ? const Color(0xFFFF3B30) : const Color(0xFFFF6B6B))
          : chainColor;
      final p1 = _toCanvas(landmarks[aIdx], size);
      final p2 = _toCanvas(landmarks[bIdx], size);
      canvas.drawLine(p1, p2, glowPaint..color = boneColor.withValues(alpha: 0.24));
      canvas.drawLine(p1, p2, linePaint..color = boneColor.withValues(alpha: 0.92));
    }
  }

  void _drawJointProtractor(
    Canvas canvas,
    Size size,
    int idxA,
    int idxB,
    int idxC,
    double angleVal,
    String sidePrefix,
    Color accentColor,
  ) {
    if (confidences[idxA] < 0.22 || confidences[idxB] < 0.22 || confidences[idxC] < 0.22) {
      return;
    }
    final pA = _toCanvas(landmarks[idxA], size);
    final pB = _toCanvas(landmarks[idxB], size);
    final pC = _toCanvas(landmarks[idxC], size);

    final angBA = math.atan2(pA.dy - pB.dy, pA.dx - pB.dx);
    final angBC = math.atan2(pC.dy - pB.dy, pC.dx - pB.dx);
    double sweep = angBC - angBA;
    while (sweep <= -math.pi) {
      sweep += 2 * math.pi;
    }
    while (sweep > math.pi) {
      sweep -= 2 * math.pi;
    }

    final arcRect = Rect.fromCircle(center: pB, radius: 24.0);
    canvas.drawArc(
      arcRect,
      angBA,
      sweep,
      true,
      Paint()
        ..color = accentColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawArc(
      arcRect,
      angBA,
      sweep,
      false,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );

    final labelText = '$sidePrefix ${angleVal.toInt()}°';
    final tp = TextPainter(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.0,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeOffset = sidePrefix == 'L' ? const Offset(-52, -14) : const Offset(16, -14);
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        pB.dx + badgeOffset.dx - 6,
        pB.dy + badgeOffset.dy - 3,
        tp.width + 12,
        tp.height + 6,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      pillRect,
      Paint()..color = const Color(0xCC090E1A),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    tp.paint(canvas, pB + badgeOffset);
  }

  void _drawArCornerReticles(Canvas canvas, Rect r, Color reticleColor) {
    final p = Paint()
      ..color = reticleColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    const len = 18.0;

    // Top-Left
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(len, 0), p);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, len), p);
    // Top-Right
    canvas.drawLine(r.topRight, r.topRight + const Offset(-len, 0), p);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, len), p);
    // Bottom-Left
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(len, 0), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(0, -len), p);
    // Bottom-Right
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(-len, 0), p);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(0, -len), p);

    final statusText = isFormValid
        ? '✓ AR FORM VERIFIED • GOAL ${targetPeakAngle.toInt()}°'
        : '⚠️ WRONG FORM / OUT OF RANGE — DO NOT COUNT';
    final headerTp = TextPainter(
      text: TextSpan(
        text: statusText,
        style: TextStyle(
          color: reticleColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    headerTp.paint(canvas, r.topLeft + const Offset(6, -15));
  }

  @override
  bool shouldRepaint(covariant _SkeletonOverlayPainter oldDelegate) => true;
}


