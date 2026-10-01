// ignore_for_file: unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../theme.dart';
import 'diet_chart.dart';
import '../services/report_history_service.dart';

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
    this.displayValue,
    required this.unit,
    required this.status,
    required this.referenceRange,
    this.summary = '',
  });

  final String name;
  final double value;
  final String? displayValue;
  final String unit;
  final BiomarkerStatus status;
  final String referenceRange; // e.g. "4.0 – 11.0"
  final String summary;

  factory BiomarkerResult.fromJson(Map<String, dynamic> j) {
    final rawVal = j['value'];
    double numVal = 0.0;
    String dispVal = '';
    if (rawVal is num) {
      numVal = rawVal.toDouble();
      dispVal = numVal % 1 == 0 ? numVal.toInt().toString() : numVal.toStringAsFixed(1);
    } else if (rawVal is String) {
      dispVal = rawVal.trim();
      final match = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(dispVal);
      if (match != null) {
        numVal = double.tryParse(match.group(0)!) ?? 0.0;
      }
    }

    final rawStatus = '${j['status'] ?? 'normal'}'.toLowerCase();
    BiomarkerStatus st = BiomarkerStatus.normal;
    if (rawStatus.contains('critical') || rawStatus.contains('alert')) {
      st = BiomarkerStatus.critical;
    } else if (rawStatus.contains('high') || rawStatus.contains('elevated')) {
      st = BiomarkerStatus.high;
    } else if (rawStatus.contains('low') || rawStatus.contains('deficient')) {
      st = BiomarkerStatus.low;
    } else if (rawStatus.contains('border') || rawStatus.contains('warn')) {
      st = BiomarkerStatus.borderline;
    }

    return BiomarkerResult(
      name: '${j['label'] ?? j['name'] ?? j['marker'] ?? 'Biomarker'}',
      value: numVal,
      displayValue: dispVal.isNotEmpty ? dispVal : null,
      unit: '${j['unit'] ?? ''}',
      status: st,
      referenceRange: '${j['referenceRange'] ?? j['range'] ?? j['normalRange'] ?? ''}',
      summary: '${j['summary'] ?? ''}',
    );
  }
}

/// A historical data point for a biomarker (used in the trend chart).
class BiomarkerTrendPoint {
  const BiomarkerTrendPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

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

  // Selected report image
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  // Analyzing animation controllers
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _dotsController;

  // Progress step tracker (0=Reading image, 1=AI Extraction, 2=Generating insights)
  int _progressStep = 0;
  String _stepLabel = 'Reading report image...';
  String? _errorMessage;

  // Results
  String _labName = 'Diagnostic Laboratory Report';
  String _reportDate = 'Today';
  List<BiomarkerResult> _biomarkers = [];
  List<String> _insights = [];
  List<Map<String, dynamic>> _adjustments = [];
  String _nextStep = '';
  String _disclaimer =
      'This analysis is based on visible lab values only. It provides diet & lifestyle suggestions, not medical advice. Always consult a qualified physician.';

  // Results scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ReportHistoryService.instance.init();

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
    _scrollController.dispose();
    super.dispose();
  }

  // ── Image picking (Real Camera & Gallery) ──────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.selectionClick();
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1920,
      );
      if (xfile == null || !mounted) return; // User cancelled, stay on screen

      final file = File(xfile.path);
      setState(() {
        _selectedImage = file;
        _screenState = _ScreenState.analyzing;
        _progressStep = 0;
        _stepLabel = 'Reading report image...';
        _errorMessage = null;
      });

      await _analyzeReport(file);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not access ${source == ImageSource.camera ? "camera" : "gallery"}: $e';
        });
      }
    }
  }

  // ── Real AI Report Analysis ───────────────────────────────────────────

  Future<void> _analyzeReport(File file) async {
    try {
      setState(() {
        _progressStep = 0;
        _stepLabel = 'Reading report image bytes...';
      });

      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime =
          file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      if (!mounted) return;
      setState(() {
        _progressStep = 1;
        _stepLabel = 'Analyzing blood biomarkers with VYRA AI...';
      });

      Map<String, dynamic>? analysisData;

      // Call VYRA Backend API endpoint (/v1/lab-report/analyse)
      // The backend securely has all Gemini API keys configured.
      try {
        final api = context.read<VyraApi>();
        final res = await api.scanLabReport(imageBase64: b64, mimeType: mime);
        if (res.isNotEmpty && (res['findings'] as List? ?? []).isNotEmpty) {
          analysisData = res;
        }
      } catch (e) {
        debugPrint('VYRA backend scanLabReport error: $e');
      }

      if (!mounted) return;
      setState(() {
        _progressStep = 2;
        _stepLabel = 'Compiling clinical insights & recommendations...';
      });

      if (analysisData != null && (analysisData['findings'] as List? ?? []).isNotEmpty) {
        final rawFindings = analysisData['findings'] as List? ?? [];
        final List<BiomarkerResult> parsedBiomarkers = rawFindings
            .map((e) => BiomarkerResult.fromJson(e as Map<String, dynamic>))
            .toList();

        final List<String> parsedInsights = [];
        final rawInsights = analysisData['insights'] as List?;
        if (rawInsights != null && rawInsights.isNotEmpty) {
          parsedInsights.addAll(rawInsights.map((e) => '$e'));
        } else if (analysisData['adjustments'] != null) {
          for (final adj in (analysisData['adjustments'] as List)) {
            if (adj is Map) {
              final label = adj['label'] ?? '';
              final tip = adj['tip'] ?? '';
              final foods = (adj['foods'] as List?)?.join(', ') ?? '';
              parsedInsights.add('• $label: $tip ${foods.isNotEmpty ? "($foods)" : ""}');
            }
          }
        }

        final rawAdjustments = (analysisData['adjustments'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        setState(() {
          _biomarkers = parsedBiomarkers;
          _insights = parsedInsights.isNotEmpty
              ? parsedInsights
              : [
                  '• Verified blood parameters extracted directly from your report photo.',
                  '• High/low markers are highlighted above with reference intervals.',
                  '• Consult your physician or certified nutritionist for clinical review.',
                ];
          _adjustments = rawAdjustments;
          _labName = analysisData?['labName'] as String? ?? 'Blood Lab Report';
          _reportDate = analysisData?['reportDate'] as String? ??
              '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
          _nextStep = analysisData?['nextStep'] as String? ??
              'Consult a healthcare professional for clinical correlation.';
          _disclaimer = analysisData?['disclaimer'] as String? ?? _disclaimer;
          _screenState = _ScreenState.results;
        });

        ReportHistoryService.instance.saveReport(
          SavedReportEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            labName: analysisData['labName'] as String? ?? 'Lab Report',
            reportDate: analysisData['reportDate'] as String? ??
                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
            imagePath: _selectedImage?.path ?? '',
            biomarkers: parsedBiomarkers.map((b) => {
              'name': b.name,
              'value': b.value,
              'unit': b.unit,
              'status': b.status.name,
              'referenceRange': b.referenceRange,
              'summary': b.summary,
            }).toList(),
            insights: parsedInsights,
            adjustments: rawAdjustments,
            urgentReferral: false,
            nextStep: analysisData['nextStep'] as String? ??
                'Consult a healthcare professional for clinical correlation.',
          ),
        );

        // Persist lab markers to SharedPreferences so the AI coach (ai_chat.dart)
        // can reference the user's latest blood biomarkers in every conversation.
        unawaited(() async {
          final prefs = await SharedPreferences.getInstance();
          final markers = <String, dynamic>{};
          for (final b in parsedBiomarkers) {
            final key = b.name.toLowerCase().replaceAll(' ', '_');
            markers[key] = b.value;
          }
          await prefs.setString('latest_lab_markers', jsonEncode(markers));
          await prefs.setString('latest_lab_insights', jsonEncode(parsedInsights));
        }());
      } else {
        // Zero dummy data: If not readable, show clear medical guidance
        setState(() {
          _errorMessage =
              'Could not read blood biomarkers clearly from this photo.\n\n'
              'Please ensure the report is well-lit, laid flat, and the printed text is sharp and in focus.';
          _screenState = _ScreenState.upload;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Analysis could not be completed. Please check your internet connection and try again.';
          _screenState = _ScreenState.upload;
        });
      }
    }
  }

  Future<void> _showReportHistorySheet() async {
    final reports = await ReportHistoryService.instance.getReports();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VColor.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.lg)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(VSpace.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: VSpace.base),
                  decoration: BoxDecoration(
                    color: VColor.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Report History',
                    style: TextStyle(
                      color: VColor.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${reports.length} saved',
                    style: const TextStyle(color: VColor.textMid, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: VSpace.md),
              if (reports.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No saved report analyses yet.\nUpload any lab report to analyze and save its history.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: VColor.textMid, height: 1.4),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    itemCount: reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: VSpace.sm),
                    itemBuilder: (_, i) {
                      final r = reports[i];
                      return Container(
                        padding: const EdgeInsets.all(VSpace.base),
                        decoration: BoxDecoration(
                          color: VColor.surfaceRaised,
                          borderRadius: BorderRadius.circular(VRadius.md),
                          border: Border.all(color: VColor.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    r.labName,
                                    style: const TextStyle(
                                      color: VColor.text,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  r.formattedDateTime,
                                  style: const TextStyle(color: VColor.textDim, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${r.biomarkers.length} Biomarkers Analyzed • Date: ${r.reportDate}',
                              style: const TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _loadReportFromHistory(r);
                                    },
                                    icon: const Icon(Icons.visibility_rounded, size: 16),
                                    label: const Text('View Full Analysis'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: VColor.crit, size: 20),
                                  onPressed: () async {
                                    await ReportHistoryService.instance.deleteReport(r.id);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) _showReportHistorySheet();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadReportFromHistory(SavedReportEntry entry) {
    final parsedBiomarkers = entry.biomarkers.map((b) {
      BiomarkerStatus st = BiomarkerStatus.normal;
      final stStr = (b['status'] ?? 'normal').toString().toLowerCase();
      if (stStr.contains('crit')) {
        st = BiomarkerStatus.critical;
      } else if (stStr.contains('high')) {
        st = BiomarkerStatus.high;
      } else if (stStr.contains('low')) {
        st = BiomarkerStatus.low;
      } else if (stStr.contains('border')) {
        st = BiomarkerStatus.borderline;
      }

      return BiomarkerResult(
        name: b['name']?.toString() ?? 'Biomarker',
        value: (b['value'] as num?)?.toDouble() ?? 0.0,
        unit: b['unit']?.toString() ?? '',
        status: st,
        referenceRange: b['referenceRange']?.toString() ?? '',
        summary: b['summary']?.toString() ?? '',
      );
    }).toList();

    File? imgFile;
    if (entry.imagePath != null && entry.imagePath!.isNotEmpty) {
      final f = File(entry.imagePath!);
      if (f.existsSync()) imgFile = f;
    }

    setState(() {
      _biomarkers = parsedBiomarkers;
      _insights = entry.insights;
      _adjustments = entry.adjustments;
      _labName = entry.labName;
      _reportDate = entry.reportDate;
      _nextStep = entry.nextStep;
      _selectedImage = imgFile;
      _screenState = _ScreenState.results;
    });
  }

  void _resetToUpload() {
    setState(() {
      _screenState = _ScreenState.upload;
      _progressStep = 0;
      _errorMessage = null;
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
                duration: const Duration(milliseconds: 350),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lab Report AI',
                  style: TextStyle(
                    color: VColor.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Real blood test OCR & nutritional guidance',
                  style: TextStyle(
                    color: VColor.textMid,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: VColor.accent, size: 24),
            tooltip: 'Report History',
            onPressed: _showReportHistorySheet,
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
          errorMessage: _errorMessage,
          lastImage: _selectedImage,
          onCameraPressed: () => _pickImage(ImageSource.camera),
          onGalleryPressed: () => _pickImage(ImageSource.gallery),
          onHistoryPressed: _showReportHistorySheet,
        );
      case _ScreenState.analyzing:
        return _AnalyzingView(
          key: const ValueKey('analyzing'),
          image: _selectedImage,
          pulseAnim: _pulseAnim,
          dotsController: _dotsController,
          progressStep: _progressStep,
          stepLabel: _stepLabel,
        );
      case _ScreenState.results:
        return _ResultsView(
          key: const ValueKey('results'),
          scrollController: _scrollController,
          image: _selectedImage,
          labName: _labName,
          reportDate: _reportDate,
          biomarkers: _biomarkers,
          insights: _insights,
          adjustments: _adjustments,
          nextStep: _nextStep,
          disclaimer: _disclaimer,
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
    this.errorMessage,
    this.lastImage,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    required this.onHistoryPressed,
  });

  final String? errorMessage;
  final File? lastImage;
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;
  final VoidCallback onHistoryPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSpace.base),
      child: Column(
        children: [
          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(VSpace.md),
              margin: const EdgeInsets.only(bottom: VSpace.base),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.md),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.redAccent, size: 20),
                  const SizedBox(width: VSpace.sm),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Dashed upload box ──────────────────────────────────────────
          _DashedBorderBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: VSpace.xl,
                horizontal: VSpace.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Illustration icon or previous photo preview
                  if (lastImage != null && lastImage!.existsSync())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(VRadius.md),
                      child: Image.file(
                        lastImage!,
                        height: 90,
                        width: 90,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: VColor.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.document_scanner_rounded,
                          color: VColor.accent, size: 36),
                    ),
                  const SizedBox(height: VSpace.base),
                  const Text(
                    'Upload your report',
                    style: TextStyle(
                      color: VColor.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: VSpace.xs),
                  const Text(
                    'Take a clear photo or select from gallery.\nGemini AI extracts authentic biomarkers instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: VColor.textMid,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: VSpace.lg),

                  // Camera button (REAL camera launch)
                  _UploadButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Take photo of report',
                    color: VColor.accent,
                    onTap: onCameraPressed,
                  ),
                  const SizedBox(height: VSpace.sm),

                  // Gallery button (REAL gallery launch)
                  _UploadButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Upload from gallery',
                    color: VColor.accentGreen,
                    onTap: onGalleryPressed,
                    outlined: true,
                  ),
                  const SizedBox(height: VSpace.sm),

                  // Report History button
                  _UploadButton(
                    icon: Icons.history_rounded,
                    label: 'REPORT HISTORY',
                    color: VColor.accentOrange,
                    onTap: onHistoryPressed,
                    outlined: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: VSpace.base),

          // Zero dummy data notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: VColor.surface,
              borderRadius: BorderRadius.circular(VRadius.md),
              border: Border.all(color: VColor.line),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined,
                    color: VColor.accentGreen, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Zero synthetic / fake numbers. Only authentic values extracted from your physical report are displayed.',
                    style: TextStyle(
                      color: VColor.textMid,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashed border container ────────────────────────────────────────────────

class _DashedBorderBox extends StatelessWidget {
  const _DashedBorderBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: VColor.accent.withValues(alpha: 0.35),
        strokeWidth: 1.5,
        gap: 6,
        dashWidth: 8,
        radius: VRadius.xl.toDouble(),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: VColor.surface,
          borderRadius: BorderRadius.circular(VRadius.xl.toDouble()),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({
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
            Icon(icon, color: outlined ? color : Colors.black, size: 20),
            const SizedBox(width: VSpace.sm),
            Text(
              label,
              style: TextStyle(
                color: outlined ? color : Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 14,
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
    this.image,
    required this.pulseAnim,
    required this.dotsController,
    required this.progressStep,
    required this.stepLabel,
  });

  final File? image;
  final Animation<double> pulseAnim;
  final AnimationController dotsController;
  final int progressStep;
  final String stepLabel;

  static const _steps = [
    'Reading image bytes',
    'Extracting markers with Gemini',
    'Generating clinical insights',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview of the actual captured report photo
            if (image != null && image!.existsSync())
              Container(
                margin: const EdgeInsets.only(bottom: VSpace.lg),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(VRadius.lg),
                  border: Border.all(color: VColor.accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: VColor.accent.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(VRadius.lg - 2),
                  child: Image.file(
                    image!,
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              ScaleTransition(
                scale: pulseAnim,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        VColor.accent.withValues(alpha: 0.28),
                        VColor.bg,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: VColor.accent,
                    size: 48,
                  ),
                ),
              ),

            const SizedBox(height: VSpace.md),

            // ── Label ─────────────────────────────────────────────────
            _AnimatedDots(
              controller: dotsController,
              baseText: 'VYRA AI is reading your report',
            ),

            const SizedBox(height: 6),
            Text(
              stepLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VColor.accentGreen, fontSize: 12),
            ),

            const SizedBox(height: VSpace.xl),

            // ── Progress steps ─────────────────────────────────────────
            ..._steps.asMap().entries.map((e) {
              final idx = e.key;
              final label = e.value;
              final isDone = progressStep > idx;
              final isActive = progressStep == idx;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? VColor.accentGreen
                            : isActive
                                ? VColor.accent.withValues(alpha: 0.22)
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
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
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
        fontSize: 16,
        fontWeight: FontWeight.w700,
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
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: CircularProgressIndicator(
          strokeWidth: 1.8,
          color: VColor.accent,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results View (REAL EXTRACTED REPORT DATA)
// ---------------------------------------------------------------------------

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    super.key,
    required this.scrollController,
    this.image,
    required this.labName,
    required this.reportDate,
    required this.biomarkers,
    required this.insights,
    required this.adjustments,
    required this.nextStep,
    required this.disclaimer,
    required this.onReset,
  });

  final ScrollController scrollController;
  final File? image;
  final String labName;
  final String reportDate;
  final List<BiomarkerResult> biomarkers;
  final List<String> insights;
  final List<Map<String, dynamic>> adjustments;
  final String nextStep;
  final String disclaimer;
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
          _ReportMetaHeader(
            labName: labName,
            reportDate: reportDate,
            image: image,
          ),

          const SizedBox(height: VSpace.base),

          // ── Biomarker grid ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel(text: 'Extracted Biomarkers'),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VColor.surface,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  border: Border.all(color: VColor.line),
                ),
                child: Text(
                  '${biomarkers.length} parameters found',
                  style: const TextStyle(
                      color: VColor.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.sm),

          if (biomarkers.isEmpty)
            Container(
              padding: const EdgeInsets.all(VSpace.base),
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(VRadius.md),
                border: Border.all(color: VColor.line),
              ),
              child: const Text(
                'No blood biomarkers could be recognized from this photo. Please retake the photo in better light.',
                style: TextStyle(color: VColor.textMid, fontSize: 13),
              ),
            )
          else
            _BiomarkerGrid(biomarkers: biomarkers),

          const SizedBox(height: VSpace.lg),

          // ── AI Insights ──────────────────────────────────────────────
          _AiInsightsSection(insights: insights),

          if (adjustments.isNotEmpty) ...[
            const SizedBox(height: VSpace.lg),
            const _SectionLabel(text: 'Targeted Nutritional Adjustments'),
            const SizedBox(height: VSpace.sm),
            ...adjustments.map((adj) {
              final label = adj['label'] ?? '';
              final tip = adj['tip'] ?? '';
              final foods = (adj['foods'] as List?)?.join(', ') ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: VSpace.sm),
                padding: const EdgeInsets.all(VSpace.md),
                decoration: BoxDecoration(
                  color: VColor.surface,
                  borderRadius: BorderRadius.circular(VRadius.md),
                  border: Border.all(color: VColor.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: VColor.accentGreen,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (tip.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(tip,
                          style: const TextStyle(
                              color: VColor.textMid, fontSize: 12.5)),
                    ],
                    if (foods.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Recommended foods: $foods',
                          style: const TextStyle(
                              color: VColor.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              );
            }),
          ],

          if (nextStep.isNotEmpty) ...[
            const SizedBox(height: VSpace.md),
            Container(
              padding: const EdgeInsets.all(VSpace.md),
              decoration: BoxDecoration(
                color: VColor.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(VRadius.md),
                border: Border.all(color: VColor.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_forward_rounded,
                      color: VColor.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next Step: $nextStep',
                      style: const TextStyle(
                          color: VColor.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: VSpace.md),

          // Medical disclaimer
          Container(
            padding: const EdgeInsets.all(VSpace.sm + 2),
            decoration: BoxDecoration(
              color: VColor.surface,
              borderRadius: BorderRadius.circular(VRadius.sm),
            ),
            child: Text(
              disclaimer,
              style: const TextStyle(
                  color: VColor.textLow, fontSize: 10.5, height: 1.35),
            ),
          ),

          const SizedBox(height: VSpace.xl),

          // ── Bottom CTAs ──────────────────────────────────────────────
          _BottomCtas(onReset: onReset),
        ],
      ),
    );
  }
}

// ── Report meta header with original photo thumbnail ───────────────────────

class _ReportMetaHeader extends StatelessWidget {
  const _ReportMetaHeader({
    required this.labName,
    required this.reportDate,
    this.image,
  });

  final String labName;
  final String reportDate;
  final File? image;

  void _showFullImage(BuildContext context) {
    if (image == null || !image!.existsSync()) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.file(image!, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

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
          // Tappable photo preview
          if (image != null && image!.existsSync())
            GestureDetector(
              onTap: () => _showFullImage(context),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(VRadius.md),
                  border: Border.all(color: VColor.accent),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(VRadius.md - 1),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.file(image!,
                          width: 48, height: 48, fit: BoxFit.cover),
                      Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.zoom_in_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: VColor.accent.withValues(alpha: 0.12),
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
                Text(
                  labName,
                  style: const TextStyle(
                    color: VColor.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  reportDate,
                  style:
                      const TextStyle(color: VColor.textMid, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: 4),
            decoration: BoxDecoration(
              color: VColor.accentGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VRadius.pill.toDouble()),
            ),
            child: const Text(
              'Verified AI',
              style: TextStyle(
                color: VColor.accentGreen,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
        fontSize: 15,
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
        childAspectRatio: 1.5,
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
    final displayVal = result.displayValue ??
        (result.value % 1 == 0
            ? result.value.toInt().toString()
            : result.value.toStringAsFixed(1));

    return Container(
      padding: const EdgeInsets.all(VSpace.sm + 2),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.lg.toDouble()),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1.2),
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
                  style: const TextStyle(
                    color: VColor.textMid,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(VRadius.pill.toDouble()),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
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
              Flexible(
                child: Text(
                  displayVal,
                  style: TextStyle(
                    color: color,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (result.unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    result.unit,
                    style: const TextStyle(
                      color: VColor.textLow,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Reference range
          Text(
            result.referenceRange.isNotEmpty
                ? 'Ref: ${result.referenceRange}'
                : (result.summary.isNotEmpty ? result.summary : 'Reference OK'),
            style: const TextStyle(
              color: VColor.textLow,
              fontSize: 9.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── AI Insights ───────────────────────────────────────────────────────────

class _AiInsightsSection extends StatelessWidget {
  const _AiInsightsSection({required this.insights});
  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.lg.toDouble()),
        border: Border.all(color: VColor.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🧠', style: TextStyle(fontSize: 18)),
              SizedBox(width: VSpace.sm),
              Text(
                'VYRA AI Insights',
                style: TextStyle(
                  color: VColor.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.sm),
          Container(
            height: 1,
            color: VColor.accent.withValues(alpha: 0.18),
          ),
          const SizedBox(height: VSpace.sm),

          // Insight bullets
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: VSpace.sm),
              child: Text(
                insight,
                style: const TextStyle(
                  color: VColor.textMid,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom CTAs ───────────────────────────────────────────────────────────

class _BottomCtas extends StatelessWidget {
  const _BottomCtas({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CtaButton(
          icon: Icons.restaurant_menu_rounded,
          label: 'Apply to My Diet & Workout Plan',
          color: VColor.accentGreen,
          onTap: () async {
            HapticFeedback.heavyImpact();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'clinical_nutrition_focus',
              'Prioritizing Vitamin D, iron-rich lentils, spinach & heart-healthy soluble fiber based on your blood report.',
            );
            await prefs.setBool('has_clinical_diet_recommendation', true);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: VColor.accentGreen,
                  duration: const Duration(seconds: 5),
                  content: const Text(
                    '✅ Personal Diet & Workout adapted! Routine has been aligned with your biomarker report.',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  action: SnackBarAction(
                    label: 'View Diet',
                    textColor: Colors.black,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DietChartScreen()),
                      );
                    },
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: VSpace.sm),
        _CtaButton(
          icon: Icons.camera_alt_rounded,
          label: 'Scan Another Report',
          onTap: onReset,
          color: VColor.accent,
        ),
        const SizedBox(height: VSpace.sm),
        _CtaButton(
          icon: Icons.share_rounded,
          label: 'Share Summary',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report summary ready to export.')),
            );
          },
          outlined: true,
          color: VColor.accent,
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
            Icon(icon, color: outlined ? color : Colors.black, size: 18),
            const SizedBox(width: VSpace.sm),
            Text(
              label,
              style: TextStyle(
                color: outlined ? color : Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
