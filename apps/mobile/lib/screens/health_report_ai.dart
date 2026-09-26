// ignore_for_file: unused_import

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// Status levels for a biomarker reading.
enum BiomarkerStatus { normal, borderline, high, low, critical }

/// A single biomarker result extracted from the blood report.
class BiomarkerResult {
  const BiomarkerResult({
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
    required this.referenceRange,
  });

  final String name;
  final double value;
  final String unit;
  final BiomarkerStatus status;
  final String referenceRange; // e.g. "4.0 – 11.0"
}

/// A historical data point for a biomarker (used in the trend chart).
class BiomarkerTrendPoint {
  const BiomarkerTrendPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

// ---------------------------------------------------------------------------
// Mock data – replace with Gemini Vision API response
// ---------------------------------------------------------------------------

/// TODO: Replace with Gemini Vision API call:
///   model.generateContent([imagePart, prompt])
/// where `imagePart` is the uploaded image bytes as an InlineDataPart and
/// `prompt` instructs the model to return structured JSON of biomarker values.
const List<BiomarkerResult> _mockBiomarkers = [
  BiomarkerResult(
    name: 'Hemoglobin',
    value: 13.8,
    unit: 'g/dL',
    status: BiomarkerStatus.normal,
    referenceRange: '12.0 – 17.5',
  ),
  BiomarkerResult(
    name: 'WBC Count',
    value: 7.2,
    unit: '×10³/µL',
    status: BiomarkerStatus.normal,
    referenceRange: '4.5 – 11.0',
  ),
  BiomarkerResult(
    name: 'Platelet',
    value: 210,
    unit: '×10³/µL',
    status: BiomarkerStatus.normal,
    referenceRange: '150 – 400',
  ),
  BiomarkerResult(
    name: 'Glucose (F)',
    value: 105,
    unit: 'mg/dL',
    status: BiomarkerStatus.borderline,
    referenceRange: '70 – 100',
  ),
  BiomarkerResult(
    name: 'HbA1c',
    value: 5.8,
    unit: '%',
    status: BiomarkerStatus.borderline,
    referenceRange: '< 5.7',
  ),
  BiomarkerResult(
    name: 'Cholesterol',
    value: 218,
    unit: 'mg/dL',
    status: BiomarkerStatus.high,
    referenceRange: '< 200',
  ),
  BiomarkerResult(
    name: 'Vitamin D',
    value: 18,
    unit: 'ng/mL',
    status: BiomarkerStatus.low,
    referenceRange: '30 – 100',
  ),
  BiomarkerResult(
    name: 'Vitamin B12',
    value: 380,
    unit: 'pg/mL',
    status: BiomarkerStatus.normal,
    referenceRange: '200 – 900',
  ),
  BiomarkerResult(
    name: 'Ferritin',
    value: 14,
    unit: 'ng/mL',
    status: BiomarkerStatus.low,
    referenceRange: '15 – 200',
  ),
  BiomarkerResult(
    name: 'TSH',
    value: 2.4,
    unit: 'mIU/L',
    status: BiomarkerStatus.normal,
    referenceRange: '0.5 – 4.5',
  ),
  BiomarkerResult(
    name: 'Creatinine',
    value: 0.9,
    unit: 'mg/dL',
    status: BiomarkerStatus.normal,
    referenceRange: '0.6 – 1.2',
  ),
  BiomarkerResult(
    name: 'Uric Acid',
    value: 6.8,
    unit: 'mg/dL',
    status: BiomarkerStatus.borderline,
    referenceRange: '2.6 – 6.0',
  ),
];

const List<String> _mockInsights = [
  '• Your Vitamin D is low (18 ng/mL). Aim for 15 min of morning sunlight daily and consider a D3 supplement after consulting your doctor.',
  '• Cholesterol is slightly elevated (218 mg/dL). Reducing saturated fats, adding omega-3 rich foods (salmon, walnuts), and 30 min of cardio 5×/week can help.',
  '• Fasting glucose (105 mg/dL) and HbA1c (5.8%) sit in the pre-diabetic range. Swap refined carbs for whole grains and reduce sugary beverages.',
  '• Ferritin is marginally low (14 ng/mL). Include iron-rich foods like lentils, spinach, and lean red meat. Pair with Vitamin C to boost absorption.',
  '• Uric acid is mildly high (6.8 mg/dL). Stay well-hydrated (≥ 2.5 L/day) and limit red meat and alcohol intake.',
  '• Overall metabolic health is moderate. Prioritising sleep (7–8 h), stress management, and consistent exercise will positively impact most of these markers.',
];

/// Mock historical data for the Cholesterol trend chart.
final List<BiomarkerTrendPoint> _mockCholesterolTrend = [
  BiomarkerTrendPoint(date: DateTime(2025, 3), value: 205),
  BiomarkerTrendPoint(date: DateTime(2025, 6), value: 212),
  BiomarkerTrendPoint(date: DateTime(2025, 9), value: 218),
];

// ---------------------------------------------------------------------------
// Screen states
// ---------------------------------------------------------------------------

enum _ScreenState { upload, analyzing, results }

// ---------------------------------------------------------------------------
// Main screen widget
// ---------------------------------------------------------------------------

class HealthReportAiScreen extends StatefulWidget {
  const HealthReportAiScreen({super.key});

  @override
  State<HealthReportAiScreen> createState() => _HealthReportAiScreenState();
}

class _HealthReportAiScreenState extends State<HealthReportAiScreen>
    with TickerProviderStateMixin {
  _ScreenState _screenState = _ScreenState.upload;

  // Analyzing animation controllers
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _dotsController;

  // Progress step tracker (0=Extracting, 1=Analyzing, 2=Generating)
  int _progressStep = 0;
  Timer? _stepTimer;

  // Results scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotsController.dispose();
    _stepTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Simulated upload + analysis flow ────────────────────────────────────

  void _simulateUpload() {
    setState(() {
      _screenState = _ScreenState.analyzing;
      _progressStep = 0;
    });

    // Advance progress steps with delays
    _stepTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _progressStep = 1);

      _stepTimer = Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() => _progressStep = 2);

        // After total ~3 s, reveal results
        _stepTimer = Timer(const Duration(milliseconds: 1100), () {
          if (!mounted) return;
          setState(() => _screenState = _ScreenState.results);
        });
      });
    });
  }

  void _resetToUpload() {
    _stepTimer?.cancel();
    setState(() {
      _screenState = _ScreenState.upload;
      _progressStep = 0;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VSpace.base,
        VSpace.base,
        VSpace.base,
        VSpace.sm,
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(VRadius.md),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: VColor.text, size: 18),
            ),
          ),
          const SizedBox(width: VSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lab Report AI',
                  style: const TextStyle(
                    color: VColor.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upload any blood test for personalized insights',
                  style: TextStyle(
                    color: VColor.textMid,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Accent DNA icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [VColor.accent, VColor.accentGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VRadius.md),
            ),
            child: const Icon(Icons.biotech_rounded, color: Colors.black, size: 22),
          ),
        ],
      ),
    );
  }

  // ── Body router ──────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_screenState) {
      case _ScreenState.upload:
        return _UploadCard(
          key: const ValueKey('upload'),
          onCameraPressed: _simulateUpload,
          onGalleryPressed: _simulateUpload,
        );
      case _ScreenState.analyzing:
        return _AnalyzingView(
          key: const ValueKey('analyzing'),
          pulseAnim: _pulseAnim,
          dotsController: _dotsController,
          progressStep: _progressStep,
        );
      case _ScreenState.results:
        return _ResultsView(
          key: const ValueKey('results'),
          scrollController: _scrollController,
          onReset: _resetToUpload,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Upload Card
// ---------------------------------------------------------------------------

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    super.key,
    required this.onCameraPressed,
    required this.onGalleryPressed,
  });

  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSpace.base),
      child: Column(
        children: [
          const SizedBox(height: VSpace.lg),

          // ── Dashed upload box ──────────────────────────────────────────
          _DashedBorderBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: VSpace.xxl,
                horizontal: VSpace.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Illustration icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: VColor.accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.document_scanner_rounded,
                        color: VColor.accent, size: 40),
                  ),
                  const SizedBox(height: VSpace.lg),
                  const Text(
                    'Upload your blood report',
                    style: TextStyle(
                      color: VColor.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: VSpace.sm),
                  Text(
                    'Our AI will extract values and give you\npersonalised health insights.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: VColor.textMid,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: VSpace.xl),

                  // Camera button
                  _UploadButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Take photo of report',
                    color: VColor.accent,
                    onTap: onCameraPressed,
                  ),
                  const SizedBox(height: VSpace.sm),

                  // Gallery button
                  _UploadButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Upload from gallery',
                    color: VColor.accentGreen,
                    onTap: onGalleryPressed,
                    outlined: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: VSpace.base),

          // ── Supported formats badge ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: VColor.textLow, size: 14),
              const SizedBox(width: 6),
              Text(
                'Supported formats: JPG · PNG · PDF',
                style: TextStyle(
                  color: VColor.textLow,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: VSpace.lg),

          // ── Past reports link ──────────────────────────────────────────
          GestureDetector(
            onTap: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history_rounded,
                    color: VColor.accent, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'View past reports',
                  style: TextStyle(
                    color: VColor.accent,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: VColor.accent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: VSpace.xl),
        ],
      ),
    );
  }
}

// ── Dashed border painter ─────────────────────────────────────────────────

class _DashedBorderBox extends StatelessWidget {
  const _DashedBorderBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: VColor.accent.withOpacity(0.45),
        strokeWidth: 1.6,
        gap: 8,
        dashWidth: 12,
        radius: VRadius.lg.toDouble(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VRadius.lg.toDouble()),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: VColor.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(VRadius.lg.toDouble()),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.dashWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
          size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => false;
}

// ── Upload button ─────────────────────────────────────────────────────────

class _UploadButton extends StatelessWidget {
  const _UploadButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: VSpace.base,
          horizontal: VSpace.lg,
        ),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          border: outlined ? Border.all(color: color, width: 1.5) : null,
          borderRadius: BorderRadius.circular(VRadius.pill.toDouble()),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: outlined ? color : Colors.black,
                size: 20),
            const SizedBox(width: VSpace.sm),
            Text(
              label,
              style: TextStyle(
                color: outlined ? color : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Analyzing View
// ---------------------------------------------------------------------------

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView({
    super.key,
    required this.pulseAnim,
    required this.dotsController,
    required this.progressStep,
  });

  final Animation<double> pulseAnim;
  final AnimationController dotsController;
  final int progressStep;

  static const _steps = [
    'Extracting values',
    'Analysing patterns',
    'Generating insights',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Pulsing brain icon ─────────────────────────────────────
            ScaleTransition(
              scale: pulseAnim,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      VColor.accent.withOpacity(0.28),
                      VColor.bg,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VColor.accent.withOpacity(0.35),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: VColor.accent,
                  size: 58,
                ),
              ),
            ),

            const SizedBox(height: VSpace.xl),

            // ── Label ─────────────────────────────────────────────────
            _AnimatedDots(
              controller: dotsController,
              baseText: 'VYRA AI is reading your report',
            ),

            const SizedBox(height: VSpace.xxl),

            // ── Progress steps ─────────────────────────────────────────
            ..._steps.asMap().entries.map((e) {
              final idx = e.key;
              final label = e.value;
              final isDone = progressStep > idx;
              final isActive = progressStep == idx;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? VColor.accentGreen
                            : isActive
                                ? VColor.accent.withOpacity(0.22)
                                : VColor.surface,
                        border: Border.all(
                          color: isDone
                              ? VColor.accentGreen
                              : isActive
                                  ? VColor.accent
                                  : VColor.line,
                          width: 1.5,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded,
                              color: Colors.black, size: 14)
                          : isActive
                              ? const _SmallSpinner()
                              : null,
                    ),
                    const SizedBox(width: VSpace.sm),
                    Text(
                      label,
                      style: TextStyle(
                        color: isDone
                            ? VColor.accentGreen
                            : isActive
                                ? VColor.text
                                : VColor.textLow,
                        fontSize: 14,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Animated "..." dots suffix ────────────────────────────────────────────

class _AnimatedDots extends AnimatedWidget {
  const _AnimatedDots({
    required AnimationController controller,
    required this.baseText,
  }) : super(listenable: controller);

  final String baseText;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as AnimationController;
    final dotCount = (animation.value * 4).floor() % 4;
    final dots = '.' * dotCount;
    return Text(
      '$baseText$dots',
      style: const TextStyle(
        color: VColor.text,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ── Small inline spinner ──────────────────────────────────────────────────

class _SmallSpinner extends StatefulWidget {
  const _SmallSpinner();

  @override
  State<_SmallSpinner> createState() => _SmallSpinnerState();
}

class _SmallSpinnerState extends State<_SmallSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: CircularProgressIndicator(
          strokeWidth: 1.8,
          color: VColor.accent,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results View
// ---------------------------------------------------------------------------

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    super.key,
    required this.scrollController,
    required this.onReset,
  });

  final ScrollController scrollController;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        VSpace.base,
        VSpace.sm,
        VSpace.base,
        VSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Report meta header ───────────────────────────────────────
          _ReportMetaHeader(),

          const SizedBox(height: VSpace.lg),

          // ── Biomarker grid ───────────────────────────────────────────
          const _SectionLabel(text: 'Biomarker Results'),
          const SizedBox(height: VSpace.sm),
          _BiomarkerGrid(biomarkers: _mockBiomarkers),

          const SizedBox(height: VSpace.lg),

          // ── AI Insights ──────────────────────────────────────────────
          _AiInsightsSection(),

          const SizedBox(height: VSpace.lg),

          // ── Action items ─────────────────────────────────────────────
          _ActionItemsSection(),

          const SizedBox(height: VSpace.lg),

          // ── Trend chart ──────────────────────────────────────────────
          const _SectionLabel(text: 'Cholesterol Trend'),
          const SizedBox(height: VSpace.sm),
          _TrendChart(points: _mockCholesterolTrend),

          const SizedBox(height: VSpace.xl),

          // ── Bottom CTAs ──────────────────────────────────────────────
          _BottomCtas(onReset: onReset),
        ],
      ),
    );
  }
}

// ── Report meta header ────────────────────────────────────────────────────

class _ReportMetaHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.lg.toDouble()),
        border: Border.all(color: VColor.line),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: VColor.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(VRadius.md.toDouble()),
            ),
            child: const Icon(Icons.description_rounded,
                color: VColor.accent, size: 24),
          ),
          const SizedBox(width: VSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comprehensive Blood Panel',
                  style: TextStyle(
                    color: VColor.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Apollo Diagnostics · 24 Sep 2026',
                  style: TextStyle(color: VColor.textMid, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: VSpace.sm, vertical: 4),
            decoration: BoxDecoration(
              color: VColor.accentGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(VRadius.pill.toDouble()),
            ),
            child: const Text(
              'Analysed',
              style: TextStyle(
                color: VColor.accentGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: VColor.text,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ── Biomarker grid ────────────────────────────────────────────────────────

class _BiomarkerGrid extends StatelessWidget {
  const _BiomarkerGrid({required this.biomarkers});
  final List<BiomarkerResult> biomarkers;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: VSpace.sm,
        mainAxisSpacing: VSpace.sm,
        childAspectRatio: 1.55,
      ),
      itemCount: biomarkers.length,
      itemBuilder: (context, i) => _BiomarkerCard(result: biomarkers[i]),
    );
  }
}

// ── Biomarker card ────────────────────────────────────────────────────────

class _BiomarkerCard extends StatelessWidget {
  const _BiomarkerCard({required this.result});
  final BiomarkerResult result;

  // Color mapping per status
  static Color _statusColor(BiomarkerStatus s) => switch (s) {
        BiomarkerStatus.normal => VColor.accentGreen,
        BiomarkerStatus.borderline => const Color(0xFFFFCC00),
        BiomarkerStatus.high => const Color(0xFFFF6B6B),
        BiomarkerStatus.low => const Color(0xFFFF6B6B),
        BiomarkerStatus.critical => const Color(0xFFBF5FFF),
      };

  static String _statusLabel(BiomarkerStatus s) => switch (s) {
        BiomarkerStatus.normal => 'Normal',
        BiomarkerStatus.borderline => 'Borderline',
        BiomarkerStatus.high => 'High',
        BiomarkerStatus.low => 'Low',
        BiomarkerStatus.critical => 'Critical',
      };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(result.status);
    final label = _statusLabel(result.status);

    return Container(
      padding: const EdgeInsets.all(VSpace.sm + 2),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.lg.toDouble()),
        border: Border.all(color: color.withOpacity(0.28), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Name + badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  result.name,
                  style: TextStyle(
                    color: VColor.textMid,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(VRadius.pill.toDouble()),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          // Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                result.value % 1 == 0
                    ? result.value.toInt().toString()
                    : result.value.toStringAsFixed(1),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2.5),
                child: Text(
                  result.unit,
                  style: TextStyle(
                    color: VColor.textLow,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          // Reference range
          Text(
            'Ref: ${result.referenceRange}',
            style: TextStyle(
              color: VColor.textLow,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Insights ───────────────────────────────────────────────────────────

class _AiInsightsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VColor.accent.withOpacity(0.08),
            VColor.accentGreen.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(VRadius.lg.toDouble()),
        border: Border.all(color: VColor.accent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 20)),
              const SizedBox(width: VSpace.sm),
              const Text(
                'VYRA AI Insights',
                style: TextStyle(
                  color: VColor.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.sm),
          Container(
            height: 1,
            color: VColor.accent.withOpacity(0.18),
          ),
          const SizedBox(height: VSpace.sm),

          // Insight bullets
          ..._mockInsights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: VSpace.sm),
              child: Text(
                insight,
                style: TextStyle(
                  color: VColor.textMid,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action items ──────────────────────────────────────────────────────────

class _ActionItemsSection extends StatelessWidget {
  static const _actions = [
    (Icons.fitness_center_rounded, 'Cardio plan for cholesterol', VColor.accent),
    (Icons.restaurant_menu_rounded, 'Iron-rich diet guide', VColor.accentGreen),
    (Icons.wb_sunny_rounded, 'Vitamin D sunlight routine', Color(0xFFFFCC00)),
    (Icons.local_hospital_rounded, 'Book a follow-up consult', Color(0xFFFF6B6B)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'Recommended Actions'),
        const SizedBox(height: VSpace.sm),
        ..._actions.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: VSpace.sm),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: VSpace.base,
                  vertical: VSpace.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: VColor.surface,
                  borderRadius:
                      BorderRadius.circular(VRadius.md.toDouble()),
                  border: Border.all(color: VColor.line),
                ),
                child: Row(
                  children: [
                    Icon(a.$1, color: a.$3, size: 20),
                    const SizedBox(width: VSpace.sm),
                    Expanded(
                      child: Text(
                        a.$2,
                        style: TextStyle(
                          color: VColor.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: VColor.textLow, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Trend chart ───────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});
  final List<BiomarkerTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxY = points.map((p) => p.value).reduce(math.max) + 20;
    final minY = points.map((p) => p.value).reduce(math.min) - 20;

    final months = points
        .map((p) => '${_monthAbbr(p.date.month)} ${p.date.year % 100}')
        .toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(color: VColor.line),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _SparklinePainter(
                values: points.map((p) => p.value).toList(),
                minY: minY,
                maxY: maxY,
                color: const Color(0xFFFF6B6B),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: months
                .map((m) => Text(m, style: const TextStyle(color: VColor.textLow, fontSize: 10)))
                .toList(),
          ),
        ],
      ),
    );
  }

  static String _monthAbbr(int month) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][month];
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final double minY;
  final double maxY;
  final Color color;

  _SparklinePainter({
    required this.values,
    required this.minY,
    required this.maxY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final dotBgPaint = Paint()
      ..color = VColor.bg
      ..style = PaintingStyle.fill;

    final range = (maxY - minY).abs();
    final safeRange = range == 0 ? 1.0 : range;
    final dx = size.width / (values.length - 1);

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final normalizedY = (values[i] - minY) / safeRange;
      final y = size.height - (normalizedY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * dx;
        final prevNormY = (values[i - 1] - minY) / safeRange;
        final prevY = size.height - (prevNormY * size.height);
        final cx = (prevX + x) / 2;
        path.cubicTo(cx, prevY, cx, y, x, y);
        fillPath.cubicTo(cx, prevY, cx, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final gradPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, gradPaint);
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final normalizedY = (values[i] - minY) / safeRange;
      final y = size.height - (normalizedY * size.height);
      canvas.drawCircle(Offset(x, y), 5, dotBgPaint);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}


// ── Bottom CTAs ───────────────────────────────────────────────────────────

class _BottomCtas extends StatelessWidget {
  const _BottomCtas({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Share report
        _CtaButton(
          icon: Icons.share_rounded,
          label: 'Share Report',
          onTap: () {},
          outlined: true,
          color: VColor.accent,
        ),
        const SizedBox(height: VSpace.sm),

        // Book appointment
        _CtaButton(
          icon: Icons.calendar_month_rounded,
          label: 'Book Doctor Appointment',
          onTap: () {},
          color: VColor.accentGreen,
        ),
        const SizedBox(height: VSpace.sm),

        // Upload another
        GestureDetector(
          onTap: onReset,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: VSpace.sm),
            child: Text(
              'Upload another report',
              style: TextStyle(
                color: VColor.textMid,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: VColor.textMid,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: VSpace.base),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          border: Border.all(
            color: outlined ? color : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(VRadius.pill.toDouble()),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: outlined ? color : Colors.black, size: 20),
            const SizedBox(width: VSpace.sm),
            Text(
              label,
              style: TextStyle(
                color: outlined ? color : Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
