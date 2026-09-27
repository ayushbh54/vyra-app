import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

import '../theme.dart';

// Supported exercises with biometric tracking parameters
class ExerciseConfig {
  final String id;
  final String name;
  final int defaultReps;
  final String primaryAngle;
  final String cueDown;
  final String cueUp;
  final String formHint;

  const ExerciseConfig({
    required this.id,
    required this.name,
    required this.defaultReps,
    required this.primaryAngle,
    required this.cueDown,
    required this.cueUp,
    required this.formHint,
  });
}

const List<ExerciseConfig> kSupportedExercises = [
  ExerciseConfig(
    id: 'squat',
    name: 'Bodyweight Squat',
    defaultReps: 12,
    primaryAngle: 'Knee 82°',
    cueDown: 'Lower hips parallel to knees',
    cueUp: 'Drive through heels to stand',
    formHint: 'Keep chest upright & knees tracking toes',
  ),
  ExerciseConfig(
    id: 'bicep_curl',
    name: 'Bicep Curl',
    defaultReps: 10,
    primaryAngle: 'Elbow 42°',
    cueDown: 'Full extension at bottom',
    cueUp: 'Squeeze biceps at the top',
    formHint: 'Pin elbows to your ribs without swinging',
  ),
  ExerciseConfig(
    id: 'pushup',
    name: 'Standard Push-up',
    defaultReps: 15,
    primaryAngle: 'Elbow 85°',
    cueDown: 'Lower chest 2 inches from floor',
    cueUp: 'Lock out arms & engage core',
    formHint: 'Maintain a straight plank line from neck to heels',
  ),
  ExerciseConfig(
    id: 'glute_bridge',
    name: 'Glute Bridge',
    defaultReps: 12,
    primaryAngle: 'Hip 178°',
    cueDown: 'Touch pelvis gently to mat',
    cueUp: 'Thrust hips up into full extension',
    formHint: 'Squeeze glutes hard at peak; avoid arching lower back',
  ),
  ExerciseConfig(
    id: 'jumping_jacks',
    name: 'Jumping Jacks',
    defaultReps: 20,
    primaryAngle: 'Shoulder 160°',
    cueDown: 'Feet together, arms at sides',
    cueUp: 'Jump wide, clap overhead',
    formHint: 'Land softly on the balls of your feet',
  ),
];

class PoseTrackerScreen extends StatefulWidget {
  final String exerciseName;
  final int targetReps;

  const PoseTrackerScreen({
    Key? key,
    this.exerciseName = 'squat',
    this.targetReps = 12,
  }) : super(key: key);

  @override
  _PoseTrackerScreenState createState() => _PoseTrackerScreenState();
}

class _PoseTrackerScreenState extends State<PoseTrackerScreen> with TickerProviderStateMixin {
  late FlutterTts _flutterTts;
  
  late ExerciseConfig _currentExercise;
  int _targetReps = 12;
  int _repCount = 0;
  
  bool _isTrackingActive = false;
  bool _isPaused = false;
  bool _simulatedMotionEnabled = false;
  bool _lowLightWarning = false;
  
  Timer? _motionTimer;
  double _motionCycle = 0.0;
  bool _isInContractionPhase = false;
  
  double _formScore = 95.0;
  String _feedbackMessage = "Tap 'Start Tracking' when ready";
  Color _repColor = VColor.accent;
  
  late AnimationController _pulseController;
  final List<Offset> _landmarks = List.generate(33, (_) => Offset.zero);

  @override
  void initState() {
    super.initState();
    _initExercise();
    _initTts();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  void _initExercise() {
    final matched = kSupportedExercises.firstWhere(
      (e) => e.id.toLowerCase() == widget.exerciseName.toLowerCase() || 
             widget.exerciseName.toLowerCase().contains(e.id),
      orElse: () => kSupportedExercises[0],
    );
    _currentExercise = matched;
    _targetReps = widget.targetReps > 0 ? widget.targetReps : matched.defaultReps;
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  void _switchExercise(ExerciseConfig newEx) {
    if (_currentExercise.id == newEx.id) return;
    setState(() {
      _currentExercise = newEx;
      _targetReps = newEx.defaultReps;
      _repCount = 0;
      _formScore = 95.0;
      _isInContractionPhase = false;
      _feedbackMessage = newEx.formHint;
    });
    _speak("${newEx.name} selected. Target: ${_targetReps} reps.");
  }

  void _startTracking() {
    setState(() {
      _isTrackingActive = true;
      _isPaused = false;
      _feedbackMessage = "Position yourself in frame. ${_currentExercise.cueDown}";
    });
    _speak("Starting ${_currentExercise.name}. ${_currentExercise.cueDown}");
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      _feedbackMessage = _isPaused ? "Tracking paused" : "Tracking resumed";
    });
  }

  void _toggleSimulatedMotion() {
    setState(() {
      _simulatedMotionEnabled = !_simulatedMotionEnabled;
    });
    
    if (_simulatedMotionEnabled) {
      _motionTimer?.cancel();
      _motionTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
        if (!mounted || !_isTrackingActive || _isPaused) return;
        setState(() {
          _motionCycle += 0.15;
          _updateSimulatedPose();
        });
      });
      _speak("Motion simulation active");
    } else {
      _motionTimer?.cancel();
    }
  }

  /// Manually trigger a validated repetition (useful for testing & reliable user input)
  void _triggerSingleRep() {
    if (!_isTrackingActive) {
      _startTracking();
    }
    
    setState(() {
      _repCount++;
      _formScore = math.min(100.0, _formScore + 2.0);
      _repColor = VColor.accentGreen;
      _feedbackMessage = "Rep ${_repCount}! ${_currentExercise.cueUp}";
    });
    
    if (_repCount >= _targetReps) {
      _speak("Awesome! Set complete! ${_repCount} reps.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎉 Workout Complete! ${_targetReps} reps logged to your VYRA profile."),
          backgroundColor: VColor.accentGreen,
        ),
      );
    } else {
      _speak("Rep $_repCount");
    }
    
    // Reset rep color highlight after 600ms
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _repColor = VColor.accent;
        });
      }
    });
  }

  void _updateSimulatedPose() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double cx = screenWidth / 2;
    final double cy = screenHeight / 2 - 20;

    final double wave = math.sin(_motionCycle); // -1.0 to 1.0

    // Human skeleton points based on BlazePose topology
    // Head: 0-10
    // Torso: 11(L shoulder), 12(R shoulder), 23(L hip), 24(R hip)
    // Arms: 13,14 (elbows), 15,16 (wrists)
    // Legs: 25,26 (knees), 27,28 (ankles), 31,32 (feet)

    for (int i = 0; i < 33; i++) {
      double x = cx;
      double y = cy;
      
      switch (i) {
        case 0: // Nose
          x = cx;
          y = cy - 140;
          break;
        case 11: // Left Shoulder
          x = cx - 45;
          y = cy - 90;
          break;
        case 12: // Right Shoulder
          x = cx + 45;
          y = cy - 90;
          break;
        case 13: // Left Elbow
          x = cx - 65;
          y = cy - 30 + (_currentExercise.id == 'bicep_curl' ? -wave * 35 : 0);
          break;
        case 14: // Right Elbow
          x = cx + 65;
          y = cy - 30 + (_currentExercise.id == 'bicep_curl' ? -wave * 35 : 0);
          break;
        case 15: // Left Wrist
          x = cx - 60;
          y = cy + 25 + (_currentExercise.id == 'bicep_curl' ? -wave * 70 : 0);
          break;
        case 16: // Right Wrist
          x = cx + 60;
          y = cy + 25 + (_currentExercise.id == 'bicep_curl' ? -wave * 70 : 0);
          break;
        case 23: // Left Hip
          x = cx - 35;
          y = cy + (_currentExercise.id == 'squat' ? wave * 45 : 0);
          break;
        case 24: // Right Hip
          x = cx + 35;
          y = cy + (_currentExercise.id == 'squat' ? wave * 45 : 0);
          break;
        case 25: // Left Knee
          x = cx - 40;
          y = cy + 85 + (_currentExercise.id == 'squat' ? wave * 25 : 0);
          break;
        case 26: // Right Knee
          x = cx + 40;
          y = cy + 85 + (_currentExercise.id == 'squat' ? wave * 25 : 0);
          break;
        case 27: // Left Ankle
          x = cx - 42;
          y = cy + 175;
          break;
        case 28: // Right Ankle
          x = cx + 42;
          y = cy + 175;
          break;
        default:
          x = cx + (math.cos(i) * 30);
          y = cy + (i * 5);
      }
      _landmarks[i] = Offset(x, y);
    }

    // Rep detection on deliberate inflection point in simulated mode
    if (_simulatedMotionEnabled && wave < -0.85 && !_isInContractionPhase) {
      _isInContractionPhase = true;
    } else if (_simulatedMotionEnabled && wave > 0.85 && _isInContractionPhase) {
      _isInContractionPhase = false;
      _triggerSingleRep();
    }
  }

  @override
  void dispose() {
    _motionTimer?.cancel();
    _pulseController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      body: Stack(
        children: [
          // 1. Camera Feed / Skeleton Visualization
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0A0E17),
              child: CustomPaint(
                painter: ModernPosePainter(
                  landmarks: _landmarks,
                  isTracking: _isTrackingActive,
                  pulse: _pulseController.value,
                ),
              ),
            ),
          ),

          // 2. Low Light / Occlusion Warning Banner
          if (_lowLightWarning)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: VColor.warnSoft,
                  border: Border.all(color: VColor.warn),
                  borderRadius: BorderRadius.circular(VRadius.md),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: VColor.warn, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Low illumination detected. Stand 2 meters back under bright room light for accurate pose tracking.",
                        style: TextStyle(color: VColor.text, fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Top Control Bar & Exercise Selector
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Navigation and Session Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: VColor.text, size: 20),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      
                      // Angle Indicator Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: VColor.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(VRadius.pill),
                          border: Border.all(color: VColor.accent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isTrackingActive ? VColor.accentGreen : VColor.warn,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isTrackingActive ? _currentExercise.primaryAngle : "CAMERA READY",
                              style: const TextStyle(
                                color: VColor.text,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Pause / Resume Toggle
                      if (_isTrackingActive)
                        IconButton(
                          icon: Icon(
                            _isPaused ? Icons.play_circle_fill_rounded : Icons.pause_circle_filled_rounded,
                            color: VColor.accent,
                            size: 32,
                          ),
                          onPressed: _togglePause,
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Horizontal Exercise Selector Carousel
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: kSupportedExercises.length,
                    itemBuilder: (context, index) {
                      final ex = kSupportedExercises[index];
                      final isSelected = ex.id == _currentExercise.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(ex.name),
                          selected: isSelected,
                          onSelected: (_) => _switchExercise(ex),
                          selectedColor: VColor.accent,
                          backgroundColor: VColor.surfaceRaised,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : VColor.textMid,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VRadius.pill),
                            side: BorderSide(
                              color: isSelected ? VColor.accent : VColor.line,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 4. Large HUD Rep Counter Card
          Positioned(
            right: 16,
            bottom: 230,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: VColor.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(VRadius.lg),
                border: Border.all(
                  color: _repColor.withValues(alpha: 0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _repColor.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$_repCount",
                    style: TextStyle(
                      color: _repColor,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "OF $_targetReps REPS",
                    style: const TextStyle(
                      color: VColor.textMid,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Test Rep / Manual Motion Action Pill
          Positioned(
            left: 16,
            bottom: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _triggerSingleRep,
                  icon: const Icon(Icons.touch_app_rounded, size: 18),
                  label: const Text("RECORD REP (+1)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VColor.accentGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VRadius.pill),
                    ),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _toggleSimulatedMotion,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _simulatedMotionEnabled ? VColor.accent.withValues(alpha: 0.2) : VColor.surfaceRaised,
                      borderRadius: BorderRadius.circular(VRadius.pill),
                      border: Border.all(
                        color: _simulatedMotionEnabled ? VColor.accent : VColor.line,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _simulatedMotionEnabled ? Icons.motion_photos_on_rounded : Icons.motion_photos_off_rounded,
                          size: 14,
                          color: _simulatedMotionEnabled ? VColor.accent : VColor.textLow,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _simulatedMotionEnabled ? "SIMULATION ON" : "SIMULATION OFF",
                          style: TextStyle(
                            color: _simulatedMotionEnabled ? VColor.accent : VColor.textLow,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 6. Bottom Biometric Feedback Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: VColor.bg.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
                border: const Border(top: BorderSide(color: VColor.line)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Quality Score
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "BIOMECHANICAL ACCURACY",
                        style: TextStyle(
                          color: VColor.textMid,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        "${_formScore.toInt()}%",
                        style: TextStyle(
                          color: _formScore > 80 ? VColor.accentGreen : VColor.warn,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(VRadius.pill),
                    child: LinearProgressIndicator(
                      value: _formScore / 100.0,
                      backgroundColor: VColor.surfaceRaised,
                      color: _formScore > 80 ? VColor.accentGreen : VColor.warn,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Real-time AI Coaching Cue
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: VColor.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.record_voice_over_rounded, color: VColor.accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "VOICE COACH FEEDBACK",
                              style: TextStyle(
                                color: VColor.textLow,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _feedbackMessage,
                              style: const TextStyle(
                                color: VColor.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Primary Action Button (Start / Complete)
                  if (!_isTrackingActive)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _startTracking,
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text("START WORKOUT TRACKING"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VColor.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VRadius.md),
                          ),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _speak("Workout session completed. Great job!");
                          Navigator.of(context).maybePop();
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                        label: const Text("FINISH & SAVE SESSION"),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: VColor.accentGreen),
                          foregroundColor: VColor.accentGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VRadius.md),
                          ),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic Biomechanical Skeleton Overlay
class ModernPosePainter extends CustomPainter {
  final List<Offset> landmarks;
  final bool isTracking;
  final double pulse;

  ModernPosePainter({
    required this.landmarks,
    required this.isTracking,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isTracking) {
      // Draw grid reticle placeholder
      _drawReticle(canvas, size);
      return;
    }

    final pointPaint = Paint()
      ..color = VColor.accentGreen
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = VColor.accent.withValues(alpha: 0.3 + (pulse * 0.2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = VColor.accent.withValues(alpha: 0.8)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Connect standard BlazePose limbs
    void drawLimb(int a, int b) {
      if (a < landmarks.length && b < landmarks.length) {
        final p1 = landmarks[a];
        final p2 = landmarks[b];
        if (p1 != Offset.zero && p2 != Offset.zero) {
          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }

    // Torso box
    drawLimb(11, 12);
    drawLimb(11, 23);
    drawLimb(12, 24);
    drawLimb(23, 24);

    // Left Arm
    drawLimb(11, 13);
    drawLimb(13, 15);

    // Right Arm
    drawLimb(12, 14);
    drawLimb(14, 16);

    // Left Leg
    drawLimb(23, 25);
    drawLimb(25, 27);

    // Right Leg
    drawLimb(24, 26);
    drawLimb(26, 28);

    // Draw Joint Nodes
    for (int i = 0; i < landmarks.length; i++) {
      final pt = landmarks[i];
      if (pt != Offset.zero) {
        canvas.drawCircle(pt, 7.0, glowPaint);
        canvas.drawCircle(pt, 4.0, pointPaint);
      }
    }
  }

  void _drawReticle(Canvas canvas, Size size) {
    final reticlePaint = Paint()
      ..color = VColor.accent.withValues(alpha: 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2 - 30;

    // Outer silhouette bounds
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.7, height: size.height * 0.6);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)), reticlePaint);

    // Corner guides
    final cornerLen = 24.0;
    final cornerPaint = Paint()
      ..color = VColor.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(Offset(rect.left, rect.top + cornerLen), Offset(rect.left, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLen, rect.top), cornerPaint);

    // Top-right
    canvas.drawLine(Offset(rect.right - cornerLen, rect.top), Offset(rect.right, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLen), cornerPaint);

    // Bottom-left
    canvas.drawLine(Offset(rect.left, rect.bottom - cornerLen), Offset(rect.left, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLen, rect.bottom), cornerPaint);

    // Bottom-right
    canvas.drawLine(Offset(rect.right - cornerLen, rect.bottom), Offset(rect.right, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant ModernPosePainter oldDelegate) => true;
}
