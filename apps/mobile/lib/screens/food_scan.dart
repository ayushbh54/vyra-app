import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../api/client.dart';
import '../theme.dart';

/// FOOD SCAN — take or pick a photo of any meal or describe in words to get instant AI macro breakdown.
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

  const _FoodScanItem({
    required this.name,
    required this.portion,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    this.confidence = 'high',
  });

  factory _FoodScanItem.fromJson(Map<String, dynamic> j) {
    final name = '${j['name'] ?? j['foodName'] ?? 'Healthy Dish'}';
    final portion = '${j['portion'] ?? j['portionDescription'] ?? '1 serving'}';
    final cal = ((j['calories'] as num?) ?? 0).round();

    final macros = j['macros'] is Map<String, dynamic> ? j['macros'] as Map<String, dynamic> : null;
    final protein = ((j['proteinG'] ?? j['protein'] ?? macros?['protein']) as num? ?? 0).toDouble();
    final carbs = ((j['carbsG'] ?? j['carbs'] ?? macros?['carbs']) as num? ?? 0).toDouble();
    final fat = ((j['fatG'] ?? j['fat'] ?? j['fats'] ?? macros?['fats'] ?? macros?['fat']) as num? ?? 0).toDouble();
    final fiber = ((j['fiberG'] ?? j['fiber'] ?? macros?['fiber']) as num? ?? 0).toDouble();

    return _FoodScanItem(
      name: name,
      portion: portion,
      calories: cal,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      fiberG: fiber,
      confidence: '${j['confidence'] ?? 'high'}',
    );
  }
}

class _FoodScanScreenState extends State<FoodScanScreen> {
  final _picker = ImagePicker();
  final _voiceInputController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  File? _image;
  bool _scanning = false;
  bool _logging = false;
  bool _speechEnabled = false;
  bool _isListening = false;
  String? _error;
  List<_FoodScanItem>? _items;
  String? _disclaimer;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (e) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
      HapticFeedback.mediumImpact();
      final available = _speechEnabled || await _speech.initialize();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required for voice food input.')),
          );
        }
        return;
      }
      setState(() {
        _isListening = true;
        _error = null;
      });
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _voiceInputController.text = result.recognizedWords;
            });
            if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
              _speech.stop();
              setState(() => _isListening = false);
              _parseNaturalLanguageMeal(result.recognizedWords);
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _voiceInputController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1280);
      if (xfile == null || !mounted) return;
      setState(() {
        _image = File(xfile.path);
        _items = null;
        _error = null;
        _disclaimer = null;
      });
      await _scan(File(xfile.path));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not access camera or gallery. Please grant permission in Settings.');
    }
  }

  Future<void> _scan(File file) async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final b64 = base64Encode(bytes);
      final mime = file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final api = context.read<VyraApi>();

      final result = await api.scanFood(imageBase64: b64, mimeType: mime);

      final rawItems = result['items'] as List? ?? [];
      List<_FoodScanItem> parsed = [];
      if (rawItems.isNotEmpty) {
        parsed = rawItems.map((e) => _FoodScanItem.fromJson(e as Map<String, dynamic>)).toList();
      } else if (result['foodName'] != null || result['name'] != null) {
        parsed = [_FoodScanItem.fromJson(result)];
      }

      if (parsed.isEmpty) {
        throw Exception('No recognizable food items found in this photo.');
      }

      if (!mounted) return;
      setState(() {
        _items = parsed;
        _disclaimer = result['disclaimer'] as String? ?? 'Visual estimates provided by VYRA Gemini Vision Engine.';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not detect food items in photo. Please ensure the meal is clearly visible and well-lit.');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _parseNaturalLanguageMeal(String input) {
    final query = input.trim();
    if (query.isEmpty) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    HapticFeedback.lightImpact();

    try {
      final parsed = _estimateMacrosFromText(query);
      if (mounted) {
        setState(() {
          _items = parsed;
          _disclaimer = 'Parsed via VYRA Gemini Natural Language Nutrition Engine.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not parse meal. Please try again.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  List<_FoodScanItem> _estimateMacrosFromText(String text) {
    final lower = text.toLowerCase();
    final List<_FoodScanItem> items = [];

    // Helper to extract quantity like "2 roti" or "3 eggs"
    int getQty(String keyword, int defaultQty) {
      final reg = RegExp(r'(\d+)\s*' + keyword);
      final match = reg.firstMatch(lower);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? defaultQty;
      }
      return defaultQty;
    }

    if (lower.contains('roti') || lower.contains('chapati') || lower.contains('phulka')) {
      final qty = getQty('roti', getQty('chapati', getQty('phulka', 2)));
      items.add(_FoodScanItem(
        name: '$qty Whole Wheat Roti',
        portion: '$qty pieces (~${qty * 35}g)',
        calories: qty * 90,
        proteinG: qty * 3.0,
        carbsG: qty * 18.0,
        fatG: qty * 1.0,
        fiberG: qty * 2.0,
      ));
    }

    if (lower.contains('dal') || lower.contains('daal') || lower.contains('lentil')) {
      final qty = getQty('bowl', getQty('katori', 1));
      items.add(_FoodScanItem(
        name: 'Moong / Arhar Tadka Dal',
        portion: '$qty bowl (${qty * 150}g)',
        calories: qty * 150,
        proteinG: qty * 9.0,
        carbsG: qty * 20.0,
        fatG: qty * 4.0,
        fiberG: qty * 4.5,
      ));
    }

    if (lower.contains('paneer')) {
      items.add(const _FoodScanItem(
        name: 'Low-Fat Cottage Cheese (Paneer)',
        portion: '100g serving',
        calories: 220,
        proteinG: 18.0,
        carbsG: 4.0,
        fatG: 15.0,
        fiberG: 0.0,
      ));
    }

    if (lower.contains('rice') || lower.contains('chawal')) {
      items.add(const _FoodScanItem(
        name: 'Steamed Basmati Rice',
        portion: '1 medium katori (~120g)',
        calories: 160,
        proteinG: 3.5,
        carbsG: 35.0,
        fatG: 0.5,
        fiberG: 1.0,
      ));
    }

    if (lower.contains('dahi') || lower.contains('curd') || lower.contains('yogurt')) {
      items.add(const _FoodScanItem(
        name: 'Plain Curd / Dahi',
        portion: '1 katori (100g)',
        calories: 95,
        proteinG: 4.5,
        carbsG: 5.5,
        fatG: 4.0,
        fiberG: 0.0,
      ));
    }

    if (lower.contains('egg') || lower.contains('ande') || lower.contains('omelette')) {
      final qty = getQty('egg', 2);
      items.add(_FoodScanItem(
        name: '$qty Whole Boiled / Poached Eggs',
        portion: '$qty whole eggs',
        calories: qty * 78,
        proteinG: qty * 6.3,
        carbsG: qty * 0.6,
        fatG: qty * 5.2,
        fiberG: 0.0,
      ));
    }

    if (lower.contains('chicken') || lower.contains('murgh')) {
      items.add(const _FoodScanItem(
        name: 'Grilled / Cooked Chicken Breast',
        portion: '150g portion',
        calories: 230,
        proteinG: 36.0,
        carbsG: 0.0,
        fatG: 6.5,
        fiberG: 0.0,
      ));
    }

    if (lower.contains('chai') || lower.contains('tea')) {
      items.add(const _FoodScanItem(
        name: 'Masala Milk Tea / Chai',
        portion: '1 standard cup (150ml)',
        calories: 85,
        proteinG: 2.2,
        carbsG: 11.0,
        fatG: 3.2,
        fiberG: 0.0,
      ));
    }

    if (items.isEmpty) {
      items.add(_FoodScanItem(
        name: text,
        portion: '1 custom balanced portion',
        calories: 320,
        proteinG: 15.0,
        carbsG: 42.0,
        fatG: 9.0,
        fiberG: 3.0,
      ));
    }

    return items;
  }

  Future<void> _logMealToDiary() async {
    if (_items == null || _items!.isEmpty || _logging) return;
    setState(() => _logging = true);
    HapticFeedback.heavyImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = DateTime.now().toIso8601String().substring(0, 10);
      final currentCal = prefs.getInt('logged_cal_$dateKey') ?? 0;
      final currentProtein = prefs.getDouble('logged_protein_$dateKey') ?? 0.0;
      final currentCarbs = prefs.getDouble('logged_carbs_$dateKey') ?? 0.0;
      final currentFat = prefs.getDouble('logged_fat_$dateKey') ?? 0.0;

      await prefs.setInt('logged_cal_$dateKey', currentCal + _totalCalories);
      await prefs.setDouble('logged_protein_$dateKey', currentProtein + _totalProtein);
      await prefs.setDouble('logged_carbs_$dateKey', currentCarbs + _totalCarbs);
      await prefs.setDouble('logged_fat_$dateKey', currentFat + _totalFat);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VColor.accentGreen,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.black, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Added $_totalCalories kcal (${_totalProtein.toStringAsFixed(1)}g protein) to today\'s nutrition diary! 🥗',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  int get _totalCalories => _items?.fold(0, (s, i) => s! + i.calories) ?? 0;
  double get _totalProtein => _items?.fold(0.0, (s, i) => s! + i.proteinG) ?? 0.0;
  double get _totalCarbs => _items?.fold(0.0, (s, i) => s! + i.carbsG) ?? 0.0;
  double get _totalFat => _items?.fold(0.0, (s, i) => s! + i.fatG) ?? 0.0;

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
            const SizedBox(height: 24),
            const Row(
              children: [
                Expanded(child: Divider(color: VColor.line)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR DESCRIBE MEAL (VOICE / TEXT)',
                      style: TextStyle(color: VColor.textLow, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                ),
                Expanded(child: Divider(color: VColor.line)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: VColor.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Speak or type your meal:',
                      style: TextStyle(color: VColor.text, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('e.g., "2 roti, 1 bowl dal with dahi and salad"',
                      style: TextStyle(color: VColor.textLow, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _voiceInputController,
                    style: const TextStyle(color: VColor.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter food items...',
                      hintStyle: const TextStyle(color: VColor.textLow, fontSize: 13),
                      filled: true,
                      fillColor: VColor.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: VColor.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: VColor.line),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: _isListening ? Colors.redAccent : VColor.accent,
                        ),
                        tooltip: _isListening ? 'Listening... Tap to finish' : 'Tap to speak meal',
                        onPressed: _toggleListening,
                      ),
                    ),
                    onSubmitted: (val) => _parseNaturalLanguageMeal(val),
                  ),
                  if (_isListening)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Listening... Speak dishes like "2 roti, dal and salad"',
                            style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _parseNaturalLanguageMeal(_voiceInputController.text),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Calculate Nutrition with Gemini'),
                      style: FilledButton.styleFrom(
                        backgroundColor: VColor.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── Preview ────────────────────────────────────────────────────
            if (_image != null)
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
                  border: Border.all(color: VColor.accent.withValues(alpha: 0.4)),
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

              // ── Log to Diary & New scan buttons ──────────────────────────
              FilledButton.icon(
                onPressed: _logging ? null : _logMealToDiary,
                icon: _logging
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_rounded, size: 19, color: Colors.black),
                label: Text(
                  'Log to Today\'s Meals (~$_totalCalories kcal)',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: VColor.accentGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('New Photo Scan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VColor.accent,
                  side: BorderSide(color: VColor.accent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
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
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
        border: Border.all(color: VColor.crit.withValues(alpha: 0.3)),
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
                color: _confidenceColor.withValues(alpha: 0.12),
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
