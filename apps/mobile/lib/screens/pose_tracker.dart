import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

// TODO: Add to pubspec.yaml once ready for real ML:
// camera: ^0.11.0
// google_mlkit_pose_detection: ^0.11.0

import '../theme.dart';

class PoseTrackerScreen extends StatefulWidget {
  final String exerciseName;
  final int targetReps;

  const PoseTrackerScreen({
    Key? key,
    this.exerciseName = 'bicep_curl',
    this.targetReps = 10,
  }) : super(key: key);

  @override
  _PoseTrackerScreenState createState() => _PoseTrackerScreenState();
}

class _PoseTrackerScreenState extends State<PoseTrackerScreen> with TickerProviderStateMixin {
  late FlutterTts flutterTts;
  Timer? _simulationTimer;
  double _simulationTime = 0.0;
  
  bool _isSessionStarted = false;
  bool _isPaused = false;
  
  List<Offset> _simulatedLandmarks = List.generate(33, (_) => Offset.zero);
  
  int _repCount = 0;
  bool _isDownPhase = false;
  double _formScore = 100.0;
  String _feedbackMessage = "Show thumbs up to start";
  Color _repColor = VColor.text;
  
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _initTts();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _startSimulation();
  }
  
  Future<void> _initTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
  }
  
  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }
  
  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      if (_isPaused) return;
      
      setState(() {
        _simulationTime += 0.1;
        _updateSimulatedPose();
        
        if (!_isSessionStarted) {
          // Simulate thumbs up gesture after 3 seconds
          if (_simulationTime > 3.0 && _simulationTime < 3.2) {
            _isSessionStarted = true;
            _feedbackMessage = "Perfect form! Keep going";
            _speak("Session started. Let's go!");
          }
        } else {
          // Process pose for exercise
          _processExerciseLogic();
        }
      });
    });
  }
  
  void _updateSimulatedPose() {
    // Generate realistic landmarks based on a sine wave (simulating motion)
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    final double cx = screenWidth / 2;
    final double cy = screenHeight / 2;
    
    // Base scale and positions
    final double motion = math.sin(_simulationTime * 2); // -1 to 1
    
    // Simulating Bicep Curl / Squat motion roughly
    for (int i = 0; i < 33; i++) {
      double x = cx + (math.cos(i) * 50);
      double y = cy + (i * 10);
      
      // Animate arms (e.g., landmark 15, 16 for wrists)
      if (i == 15 || i == 16) {
        y += motion * 80;
      }
      
      // Animate legs (squat)
      if (i > 24) {
        y += motion * 40;
      }
      
      _simulatedLandmarks[i] = Offset(x, y);
    }
  }
  
  void _processExerciseLogic() {
    // Simple state machine for reps
    final double motion = math.sin(_simulationTime * 2);
    
    // down phase = motion < -0.5
    // up phase = motion > 0.5
    
    bool badForm = math.Random().nextDouble() > 0.95; // 5% chance of bad form
    
    if (badForm) {
      _formScore = math.max(0, _formScore - 5);
      _feedbackMessage = "Lower your hips more";
      _repColor = VColor.crit;
      if (math.Random().nextDouble() > 0.5) {
        _speak("Lower your hips");
      }
    } else {
      _formScore = math.min(100, _formScore + 1);
    }
    
    if (motion < -0.5 && !_isDownPhase) {
      _isDownPhase = true;
    } else if (motion > 0.5 && _isDownPhase) {
      _isDownPhase = false;
      if (_formScore > 50) {
        _repCount++;
        _repColor = VColor.good;
        _feedbackMessage = "Great rep!";
        if (_repCount == widget.targetReps) {
          _speak("Goal reached! Great job.");
        }
      } else {
        _repColor = VColor.crit;
        _feedbackMessage = "Bad form, rep not counted";
        _speak("Fix your form");
      }
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _pulseController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      body: Stack(
        children: [
          // Camera Placeholder / Simulation Background
          Positioned.fill(
            child: Container(
              color: VColor.surface,
              child: CustomPaint(
                painter: SkeletonPainter(
                  landmarks: _simulatedLandmarks,
                  glowIntensity: _pulseController.value,
                ),
              ),
            ),
          ),
          
          // Top Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + VSpace.base,
            left: VSpace.base,
            right: VSpace.base,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.exerciseName.toUpperCase().replaceAll('_', ' '),
                      style: const TextStyle(
                        color: VColor.textMid,
                        fontSize: 14,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: VSpace.xs),
                    Text(
                      "Target: ${widget.targetReps} reps",
                      style: const TextStyle(
                        color: VColor.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isPaused = !_isPaused;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: VColor.surface.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(VRadius.pill),
                      border: Border.all(color: VColor.line),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isPaused ? Icons.play_arrow : Icons.pause, 
                          color: VColor.text, 
                          size: 16
                        ),
                        const SizedBox(width: VSpace.xs),
                        Text(
                          _isPaused ? "RESUME" : "PAUSE",
                          style: const TextStyle(color: VColor.text, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Gesture Hint Overlay (Thumbs Up)
          if (!_isSessionStarted)
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(VSpace.lg),
                  decoration: BoxDecoration(
                    color: VColor.bg.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(VRadius.lg),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.thumb_up, color: VColor.accent, size: 48),
                      const SizedBox(height: VSpace.base),
                      const Text(
                        "Show thumbs up to start",
                        style: TextStyle(
                          color: VColor.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: VSpace.sm),
                      const Text(
                        "Please ensure full body is in frame",
                        style: TextStyle(
                          color: VColor.textMid,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
          // Rep Counter
          Positioned(
            right: VSpace.base,
            bottom: 140 + VSpace.lg,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(VSpace.lg),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VColor.surface.withOpacity(0.9),
                border: Border.all(
                  color: _repColor.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _repColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
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
                      height: 1,
                    ),
                  ),
                  const Text(
                    "REPS",
                    style: TextStyle(
                      color: VColor.textMid,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Feedback Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: VSpace.base,
                right: VSpace.base,
                top: VSpace.xl,
                bottom: MediaQuery.of(context).padding.bottom + VSpace.base,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    VColor.bg.withOpacity(0.95),
                    VColor.bg.withOpacity(0.8),
                    VColor.bg.withOpacity(0.0),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Form Score Bar
                  Row(
                    children: [
                      const Text(
                        "FORM SCORE",
                        style: TextStyle(
                          color: VColor.textMid,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: VSpace.sm),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: VColor.surface,
                            borderRadius: BorderRadius.circular(VRadius.pill),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _formScore / 100,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: _formScore > 70 ? VColor.good : (_formScore > 40 ? Colors.orange : VColor.crit),
                                borderRadius: BorderRadius.circular(VRadius.pill),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: VSpace.sm),
                      Text(
                        "${_formScore.toInt()}%",
                        style: const TextStyle(
                          color: VColor.text,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSpace.base),
                  // Feedback Text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _feedbackMessage,
                      key: ValueKey<String>(_feedbackMessage),
                      style: TextStyle(
                        color: _repColor == VColor.crit ? VColor.crit : VColor.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
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

class SkeletonPainter extends CustomPainter {
  final List<Offset> landmarks;
  final double glowIntensity;

  SkeletonPainter({required this.landmarks, required this.glowIntensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final Paint pointPaint = Paint()
      ..color = VColor.accent
      ..style = PaintingStyle.fill;
      
    final Paint glowPaint = Paint()
      ..color = VColor.accentGlow.withOpacity(0.2 + (glowIntensity * 0.2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0)
      ..style = PaintingStyle.fill;

    final Paint linePaint = Paint()
      ..color = VColor.accent.withOpacity(0.8)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Standard pose connections
    final List<List<int>> connections = [
      [11, 13], [13, 15], // Left arm
      [12, 14], [14, 16], // Right arm
      [11, 12], // Shoulders
      [11, 23], [12, 24], // Torso
      [23, 24], // Hips
      [23, 25], [25, 27], [27, 29], [29, 31], // Left leg
      [24, 26], [26, 28], [28, 30], [30, 32], // Right leg
    ];

    for (final connection in connections) {
      if (connection[0] < landmarks.length && connection[1] < landmarks.length) {
        final p1 = landmarks[connection[0]];
        final p2 = landmarks[connection[1]];
        if (p1 != Offset.zero && p2 != Offset.zero) {
          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }

    // Draw points
    for (final point in landmarks) {
      if (point != Offset.zero) {
        canvas.drawCircle(point, 8, glowPaint);
        canvas.drawCircle(point, 4, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return true; // Simple approach for animation
  }
}
