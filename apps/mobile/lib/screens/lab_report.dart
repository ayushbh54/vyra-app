import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../theme.dart';

/// LAB REPORT SCAN — upload a blood test / lab report image.
///
/// AI reads the markers, flags which nutrients look low/high,
/// and suggests diet-only adjustments (never medicine or dosage).
/// Always ends with "consult your doctor."
class LabReportScreen extends StatefulWidget {
  const LabReportScreen({super.key});

  @override
  State<LabReportScreen> createState() => _LabReportScreenState();
}

class _Finding {
  final String marker;
  final String label;
  final String status;   // 'low' | 'high' | 'normal'
  final String summary;
  _Finding.fromJson(Map<String, dynamic> j)
      : marker  = '${j['marker'] ?? j['key'] ?? ''}',
        label   = '${j['label'] ?? j['marker'] ?? ''}',
        status  = '${j['status'] ?? 'normal'}',
        summary = '${j['summary'] ?? ''}';
}

class _Adjustment {
  final String label;
  final List<String> foods;
  final String tip;
  final bool seeDoctor;
  _Adjustment.fromJson(Map<String, dynamic> j)
      : label     = '${j['label'] ?? ''}',
        foods     = List<String>.from(j['foods'] as List? ?? []),
        tip       = '${j['tip'] ?? ''}',
        seeDoctor = j['seeADoctor'] == true;
}

class _LabReportScreenState extends State<LabReportScreen> {
  final _picker = ImagePicker();
  File? _image;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  List<_Finding>  get _findings    => (_result?['findings'] as List? ?? [])
      .map((e) => _Finding.fromJson(e as Map<String, dynamic>)).toList();
  List<_Adjustment> get _adjustments => (_result?['adjustments'] as List? ?? [])
      .map((e) => _Adjustment.fromJson(e as Map<String, dynamic>)).toList();
  String get _nextStep => '${_result?['nextStep'] ?? ''}';
  String get _disclaimer => '${_result?['disclaimer'] ?? ''}';

  Future<void> _pick(ImageSource src) async {
    try {
      final xfile = await _picker.pickImage(source: src, imageQuality: 85, maxWidth: 1600);
      if (xfile == null) return;
      final file = File(xfile.path);
      setState(() { _image = file; _result = null; _error = null; });
      await _analyse(file);
    } catch (_) {
      setState(() => _error = 'Could not access camera or gallery.');
    }
  }

  Future<void> _analyse(File file) async {
    setState(() { _loading = true; _error = null; });
    try {
      final bytes  = await file.readAsBytes();
      final b64    = base64Encode(bytes);
      final mime   = file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final result = await context.read<VyraApi>().scanLabReport(imageBase64: b64, mimeType: mime);
      setState(() => _result = result);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        leading: const BackButton(color: VColor.text),
        title: const Text('Lab Report Scan',
            style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Header card ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VColor.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VColor.line),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VColor.accentGreenGlow,
                    border: Border.all(color: VColor.accentGreen.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.biotech_rounded, color: VColor.accentGreen, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AI Lab Analysis', style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Diet & supplement insights • Not medical advice',
                      style: TextStyle(color: VColor.textLow, fontSize: 11)),
                ])),
              ]),
              const SizedBox(height: 14),
              const Text(
                'Upload a clear photo of your blood test or lab report. '
                'VYRA reads the markers and suggests diet adjustments — '
                'we never prescribe medicine or dosages.',
                style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.5),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Pick buttons ────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _ActionBtn(
              icon: Icons.camera_alt_rounded, label: 'Take Photo',
              color: VColor.accent, onTap: () => _pick(ImageSource.camera),
            )),
            const SizedBox(width: 12),
            Expanded(child: _ActionBtn(
              icon: Icons.photo_library_rounded, label: 'Gallery',
              color: VColor.accentGreen, onTap: () => _pick(ImageSource.gallery),
            )),
          ]),
          const SizedBox(height: 16),

          // ── Preview image ────────────────────────────────────────────────
          if (_image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(_image!, height: 200, fit: BoxFit.cover, width: double.infinity),
            ),
            const SizedBox(height: 16),
          ],

          // ── Loading ──────────────────────────────────────────────────────
          if (_loading)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: VColor.surface, borderRadius: BorderRadius.circular(16)),
              child: const Column(children: [
                CircularProgressIndicator(color: VColor.accentGreen, strokeWidth: 2.5),
                SizedBox(height: 16),
                Text('Reading your report…', style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('AI is identifying your blood markers', style: TextStyle(color: VColor.textLow, fontSize: 12)),
              ]),
            )

          // ── Error ────────────────────────────────────────────────────────
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: VColor.critSoft, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(_error!, style: const TextStyle(color: VColor.crit, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextButton(onPressed: () => _image != null ? _analyse(_image!) : null,
                    child: const Text('Try again', style: TextStyle(color: VColor.accent))),
              ]),
            )

          // ── Results ──────────────────────────────────────────────────────
          else if (_result != null) ...[
            // Findings
            if (_findings.isNotEmpty) ...[
              const _SectionHeader('Markers Found'),
              ..._findings.map((f) => _FindingCard(f)),
              const SizedBox(height: 8),
            ],

            // Diet adjustments
            if (_adjustments.isNotEmpty) ...[
              const _SectionHeader('Diet Suggestions'),
              ..._adjustments.map((a) => _AdjustmentCard(a)),
              const SizedBox(height: 8),
            ],

            // Next step
            if (_nextStep.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VColor.accentGreenGlow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VColor.accentGreen.withOpacity(0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.tips_and_updates_rounded, color: VColor.accentGreen, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_nextStep,
                      style: const TextStyle(color: VColor.text, fontSize: 13, height: 1.5))),
                ]),
              ),
            const SizedBox(height: 12),

            // Disclaimer
            if (_disclaimer.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VColor.warnSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_disclaimer,
                    style: const TextStyle(color: VColor.warn, fontSize: 11, height: 1.5)),
              ),
          ],
        ]),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: VColor.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title.toUpperCase(),
        style: const TextStyle(color: VColor.textLow, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );
}

class _FindingCard extends StatelessWidget {
  const _FindingCard(this.f);
  final _Finding f;

  Color get _statusColor => switch (f.status) {
    'low'  => VColor.accent,
    'high' => VColor.accentOrange,
    _      => VColor.accentGreen,
  };

  IconData get _statusIcon => switch (f.status) {
    'low'  => Icons.arrow_downward_rounded,
    'high' => Icons.arrow_upward_rounded,
    _      => Icons.check_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: VColor.surface, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: VColor.line),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: _statusColor.withOpacity(0.15),
        ),
        child: Icon(_statusIcon, color: _statusColor, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.label, style: const TextStyle(color: VColor.text, fontSize: 14, fontWeight: FontWeight.w600)),
        if (f.summary.isNotEmpty)
          Text(f.summary, style: const TextStyle(color: VColor.textMid, fontSize: 12, height: 1.4)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(f.status.toUpperCase(),
            style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      ),
    ]),
  );
}

class _AdjustmentCard extends StatelessWidget {
  const _AdjustmentCard(this.a);
  final _Adjustment a;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: VColor.surfaceRaised, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: VColor.line),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.restaurant_rounded, color: VColor.accentGreen, size: 18),
        const SizedBox(width: 8),
        Text(a.label, style: const TextStyle(color: VColor.text, fontSize: 14, fontWeight: FontWeight.w700)),
        if (a.seeDoctor) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: VColor.warnSoft, borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('See doctor', style: TextStyle(color: VColor.warn, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
      if (a.foods.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: a.foods.map((food) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: VColor.accentGreenGlow, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: VColor.accentGreen.withOpacity(0.3)),
          ),
          child: Text(food, style: const TextStyle(color: VColor.accentGreen, fontSize: 12)),
        )).toList()),
      ],
      if (a.tip.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(a.tip, style: const TextStyle(color: VColor.textMid, fontSize: 12, height: 1.45)),
      ],
    ]),
  );
}
