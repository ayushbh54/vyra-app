import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../theme.dart';

/// FOOD SCAN — take or pick a photo of any meal and get instant AI macro breakdown.
///
/// Image is base64-encoded locally, sent to /v1/food/scan, and the model
/// returns per-item estimates the user can review before logging.
/// No diary write happens here — that's a separate deliberate action.
class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({super.key});

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanItem {
  final String name;
  final String portion;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final String confidence; // 'high' | 'medium' | 'low'

  _FoodScanItem.fromJson(Map<String, dynamic> j)
      : name       = '${j['name']}',
        portion    = '${j['portion']}',
        calories   = (j['calories'] as num).round(),
        proteinG   = (j['proteinG'] as num).toDouble(),
        carbsG     = (j['carbsG'] as num).toDouble(),
        fatG       = (j['fatG'] as num).toDouble(),
        fiberG     = (j['fiberG'] as num).toDouble(),
        confidence = '${j['confidence']}';
}

class _FoodScanScreenState extends State<FoodScanScreen> {
  final _picker = ImagePicker();

  File? _image;
  bool _scanning = false;
  String? _error;
  List<_FoodScanItem>? _items;
  String? _disclaimer;

  Future<void> _pick(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1280);
      if (xfile == null) return;
      setState(() {
        _image    = File(xfile.path);
        _items    = null;
        _error    = null;
        _disclaimer = null;
      });
      await _scan(File(xfile.path));
    } catch (e) {
      setState(() => _error = 'Could not access camera or gallery. Please grant permission in Settings.');
    }
  }

  Future<void> _scan(File file) async {
    setState(() { _scanning = true; _error = null; });
    try {
      final bytes  = await file.readAsBytes();
      final b64    = base64Encode(bytes);
      final mime   = file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final api    = context.read<VyraApi>();
      final result = await api.scanFood(imageBase64: b64, mimeType: mime);
      final rawItems = result['items'] as List? ?? [];
      setState(() {
        _items      = rawItems.map((e) => _FoodScanItem.fromJson(e as Map<String, dynamic>)).toList();
        _disclaimer = result['disclaimer'] as String?;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _scanning = false);
    }
  }

  int get _totalCalories => _items?.fold(0, (s, i) => s! + i.calories) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        leading: const BackButton(color: VColor.text),
        title: const Text('Food Scan', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700)),
        actions: [
          if (_image != null && !_scanning)
            TextButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.refresh_rounded, color: VColor.accent, size: 18),
              label: const Text('Rescan', style: TextStyle(color: VColor.accent, fontSize: 13)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Photo picker area ────────────────────────────────────────────
          if (_image == null) ...[
            const SizedBox(height: 32),
            const Text('Scan your meal', textAlign: TextAlign.center,
                style: TextStyle(color: VColor.text, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Take a photo or choose from gallery.\nOur AI estimates nutrition per item instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VColor.textMid, fontSize: 14, height: 1.5)),
            const SizedBox(height: 36),
            Row(children: [
              Expanded(child: _PickButton(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: VColor.accent,
                onTap: () => _pick(ImageSource.camera),
              )),
              const SizedBox(width: 12),
              Expanded(child: _PickButton(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: VColor.accentGreen,
                onTap: () => _pick(ImageSource.gallery),
              )),
            ]),
          ] else ...[
            // ── Preview ────────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_image!, height: 220, fit: BoxFit.cover, width: double.infinity),
            ),
            const SizedBox(height: 16),

            if (_scanning)
              const _ScanningCard()
            else if (_error != null)
              _ErrorCard(_error!, onRetry: () => _scan(_image!))
            else if (_items != null) ...[
              // ── Totals pill ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: VColor.accentGlow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: VColor.accent.withOpacity(0.4)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total (estimated)', style: TextStyle(color: VColor.textMid, fontSize: 13)),
                  Text('~$_totalCalories kcal',
                      style: const TextStyle(color: VColor.accent, fontSize: 18, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Item cards ───────────────────────────────────────────────
              ..._items!.map((item) => _FoodItemCard(item)),

              if (_disclaimer != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VColor.warnSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_disclaimer!,
                      style: const TextStyle(color: VColor.warn, fontSize: 11, height: 1.5)),
                ),
              ],
              const SizedBox(height: 20),

              // ── New scan button ──────────────────────────────────────────
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('New Scan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VColor.accent,
                    side: BorderSide(color: VColor.accent.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )),
              ]),
            ],
          ],
        ]),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _PickButton extends StatelessWidget {
  const _PickButton({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: VColor.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ScanningCard extends StatelessWidget {
  const _ScanningCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VColor.line),
      ),
      child: const Column(children: [
        CircularProgressIndicator(color: VColor.accent, strokeWidth: 2.5),
        SizedBox(height: 16),
        Text('Analysing your meal…', style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w600)),
        SizedBox(height: 6),
        Text('Gemini AI is identifying each item', style: TextStyle(color: VColor.textLow, fontSize: 12)),
      ]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.message, {required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VColor.critSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VColor.crit.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(message, style: const TextStyle(color: VColor.crit, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('Try again', style: TextStyle(color: VColor.accent))),
      ]),
    );
  }
}

class _FoodItemCard extends StatelessWidget {
  const _FoodItemCard(this.item);
  final _FoodScanItem item;

  Color get _confidenceColor => switch (item.confidence) {
    'high'   => VColor.accentGreen,
    'medium' => VColor.warn,
    _        => VColor.textLow,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VColor.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: const TextStyle(color: VColor.text, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(item.portion, style: const TextStyle(color: VColor.textLow, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${item.calories} kcal',
                style: const TextStyle(color: VColor.accent, fontSize: 16, fontWeight: FontWeight.w700)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _confidenceColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item.confidence, style: TextStyle(color: _confidenceColor, fontSize: 10)),
            ),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _Macro('Protein', item.proteinG, VColor.accentGreen),
          const SizedBox(width: 10),
          _Macro('Carbs', item.carbsG, VColor.accent),
          const SizedBox(width: 10),
          _Macro('Fat', item.fatG, VColor.accentOrange),
          const SizedBox(width: 10),
          _Macro('Fibre', item.fiberG, VColor.textMid),
        ]),
      ]),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.label, this.g, this.color);
  final String label;
  final double g;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text('${g.toStringAsFixed(1)}g', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      Text(label, style: const TextStyle(color: VColor.textLow, fontSize: 10)),
    ]));
  }
}
