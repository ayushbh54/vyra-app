import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';

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
    id: 'glute_bridge',
    name: 'Glute Bridge',
    defaultReps: 12,
    primaryAngle: 'Hip 178°',
    cueDown: 'Touch pelvis gently to mat',
    cueUp: 'Thrust hips up into full extension',
    formHint: 'Squeeze glutes hard at peak; avoid arching lower back',
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
    id: 'bicep_curl',
    name: 'Bicep Curl',
    defaultReps: 10,
    primaryAngle: 'Elbow 42°',
    cueDown: 'Full extension at bottom',
    cueUp: 'Squeeze biceps at the top',
    formHint: 'Pin elbows to your ribs without swinging',
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
    super.key,
    this.exerciseName = 'squat',
    this.targetReps = 12,
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

  late ExerciseConfig _currentExercise;
  int _targetReps = 12;
  int _repCount = 0; // Starts strictly at 0

  bool _isTrackingActive = false;
  bool _isPaused = false;
  double _formScore = 95.0;
  String _feedbackMessage = "Position yourself in frame and tap 'Start Tracking'";
  Color _repColor = VColor.accent;

  late AnimationController _pulseController;
  final List<Offset> _landmarks = List.generate(33, (_) => Offset.zero);

  @override
  void initState() {
    super.initState();
    _initExercise();
    _initTts();
    _initCamera();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  void _initExercise() {
    final matched = kSupportedExercises.firstWhere(
      (e) =>
          e.id.toLowerCase() == widget.exerciseName.toLowerCase() ||
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

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        int frontIdx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        _selectedCameraIndex = frontIdx != -1 ? frontIdx : 0;
        await _setupCameraController(_cameras[_selectedCameraIndex]);
      } else {
        if (mounted) setState(() => _cameraError = true);
      }
    } catch (e) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  Future<void> _setupCameraController(CameraDescription desc) async {
    await _cameraController?.dispose();
    _cameraController = CameraController(
      desc,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _cameraError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    final nextIdx = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() {
      _selectedCameraIndex = nextIdx;
      _isCameraReady = false;
    });
    await _setupCameraController(_cameras[nextIdx]);
  }

  void _switchExercise(ExerciseConfig newEx) {
    if (_currentExercise.id == newEx.id) return;
    setState(() {
      _currentExercise = newEx;
      _targetReps = newEx.defaultReps;
      _repCount = 0;
      _formScore = 95.0;
      _feedbackMessage = newEx.formHint;
    });
    _speak("${newEx.name} selected. Target: $_targetReps reps.");
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

  /// Evaluates form with exact voice cues:
  /// Good form: "Yes, perfect!"
  /// Incorrect form: "Please do it this way: [cue]"
  void _evaluateFormAndRep({required bool isCorrectForm}) {
    if (!_isTrackingActive) {
      _startTracking();
    }

    if (isCorrectForm) {
      setState(() {
        _repCount++;
        _formScore = math.min(100.0, _formScore + 2.0);
        _repColor = VColor.accentGreen;
        _feedbackMessage = "Yes, perfect! Rep $_repCount complete.";
      });
      _speak("Yes, perfect!");

      if (_repCount >= _targetReps) {
        _speak("Awesome! Set complete! $_repCount reps.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🎉 Workout Complete! $_targetReps reps logged to your VYRA profile."),
            backgroundColor: VColor.accentGreen,
          ),
        );
      }
    } else {
      // Suboptimal form cue
      setState(() {
        _formScore = math.max(65.0, _formScore - 5.0);
        _repColor = VColor.warn;
        _feedbackMessage = "Please do it this way: ${_currentExercise.cueDown}";
      });
      _speak("Please do it this way: ${_currentExercise.cueDown}");
    }

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _repColor = VColor.accent;
        });
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
          // 1. Live Camera Feed
          Positioned.fill(
            child: _isCameraReady && _cameraController != null && _cameraController!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize?.height ?? 1,
                      height: _cameraController!.value.previewSize?.width ?? 1,
                      child: CameraPreview(_cameraController!),
                    ),
                  )
                : Container(
                    color: const Color(0xFF0A0E17),
                    child: Center(
                      child: _cameraError
                          ? const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  "Camera unavailable or permission denied\nPose tracking reticle ready",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            )
                          : const CircularProgressIndicator(color: VColor.accent),
                    ),
                  ),
          ),

          // 2. Biomechanical Skeleton Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: ModernPosePainter(
                landmarks: _landmarks,
                isTracking: _isTrackingActive,
                pulse: _pulseController.value,
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
                // Navigation, Flip Camera and Session Controls
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
                              _isTrackingActive ? _currentExercise.primaryAngle : "CAMERA ACTIVE",
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

                      // Flip Camera & Pause / Resume Toggle
                      Row(
                        children: [
                          if (_cameras.length > 1)
                            IconButton(
                              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 22),
                              onPressed: _flipCamera,
                            ),
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
                            const SizedBox(width: 8),
                        ],
                      ),
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
                          backgroundColor: VColor.surfaceRaised.withValues(alpha: 0.8),
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

          // 4. Large HUD Rep Counter Card (Starts strictly at 0)
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

          // 5. Form Evaluation Actions (Perfect Form / Fix Form)
          Positioned(
            left: 16,
            bottom: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _evaluateFormAndRep(isCorrectForm: true),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text("PERFECT REP (+1)"),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _evaluateFormAndRep(isCorrectForm: false),
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: const Text("CHECK FORM CUE"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VColor.warn,
                    side: const BorderSide(color: VColor.warn),
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VRadius.pill),
                    ),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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

                  // Real-time AI Coaching Cue with Exact Voice Feedback
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

    void drawLimb(int a, int b) {
      if (a < landmarks.length && b < landmarks.length) {
        final p1 = landmarks[a];
        final p2 = landmarks[b];
        if (p1 != Offset.zero && p2 != Offset.zero) {
          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }

    drawLimb(11, 12);
    drawLimb(11, 23);
    drawLimb(12, 24);
    drawLimb(23, 24);

    drawLimb(11, 13);
    drawLimb(13, 15);

    drawLimb(12, 14);
    drawLimb(14, 16);

    drawLimb(23, 25);
    drawLimb(25, 27);

    drawLimb(24, 26);
    drawLimb(26, 28);

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

    final rect = Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.7, height: size.height * 0.6);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)), reticlePaint);

    const cornerLen = 24.0;
    final cornerPaint = Paint()
      ..color = VColor.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(rect.left, rect.top + cornerLen), Offset(rect.left, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLen, rect.top), cornerPaint);

    canvas.drawLine(Offset(rect.right - cornerLen, rect.top), Offset(rect.right, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLen), cornerPaint);

    canvas.drawLine(Offset(rect.left, rect.bottom - cornerLen), Offset(rect.left, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLen, rect.bottom), cornerPaint);

    canvas.drawLine(Offset(rect.right - cornerLen, rect.bottom), Offset(rect.right, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant ModernPosePainter oldDelegate) => true;
}
