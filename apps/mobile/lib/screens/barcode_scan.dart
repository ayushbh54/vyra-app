import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Stitch Pages 33 & 33b: Packaged Food Barcode Scanner & Nutrition Detail
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scanLineAnimation;
  bool _torchOn = false;
  bool _scanning = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String barcode) async {
    if (_scanning || barcode.trim().isEmpty) return;
    setState(() => _scanning = true);
    HapticFeedback.mediumImpact();

    try {
      final product = await context.read<VyraApi>().lookupBarcode(barcode.trim());
      if (mounted) {
        _showProductBottomSheet(product);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning barcode: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _showProductBottomSheet(BarcodeProduct product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VColor.surfaceRaised,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            VSpace.base,
            VSpace.md,
            VSpace.base,
            MediaQuery.of(ctx).padding.bottom + VSpace.base,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VColor.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: VSpace.base),

              // Product Name & Brand
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.brand.toUpperCase(),
                          style: const TextStyle(
                            color: VColor.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          style: const TextStyle(
                            color: VColor.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Barcode: ${product.barcode}',
                          style: const TextStyle(color: VColor.textLow, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  _buildNovaBadge(product.novaScore),
                ],
              ),
              const SizedBox(height: VSpace.base),

              // Macro Grid
              Container(
                padding: const EdgeInsets.all(VSpace.md),
                decoration: BoxDecoration(
                  color: VColor.bg,
                  borderRadius: BorderRadius.circular(VRadius.md),
                  border: Border.all(color: VColor.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _macroMetric('CALORIES', '${product.calories}', 'kcal', VColor.accentOrange),
                    _macroMetric('PROTEIN', '${product.proteinG}g', '14%', VColor.accent),
                    _macroMetric('CARBS', '${product.carbsG}g', '22%', VColor.text),
                    _macroMetric('FATS', '${product.fatG}g', '6.5%', VColor.accentGreen),
                  ],
                ),
              ),
              const SizedBox(height: VSpace.md),

              // Micro & Health Badges
              Row(
                children: [
                  _infoPill(Icons.grain, 'Fiber: ${product.fiberG}g'),
                  const SizedBox(width: 8),
                  _infoPill(Icons.water_drop_outlined, 'Sodium: ${product.sodiumMg}mg'),
                  const SizedBox(width: 8),
                  _infoPill(Icons.verified_outlined, product.category),
                ],
              ),
              const SizedBox(height: VSpace.lg),

              // Action button
              VGradientButton(
                label: 'Log ${product.calories} kcal to Diary',
                icon: Icons.add_task_rounded,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ ${product.name} (${product.calories} kcal) logged to daily budget!'),
                      backgroundColor: VColor.accentGreen,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNovaBadge(int nova) {
    Color bg = VColor.accentGreen;
    String label = 'NOVA 1 (Clean)';
    if (nova == 2) {
      bg = Colors.blue;
      label = 'NOVA 2 (Culinary)';
    } else if (nova == 3) {
      bg = VColor.accentOrange;
      label = 'NOVA 3 (Processed)';
    } else if (nova >= 4) {
      bg = Colors.redAccent;
      label = 'NOVA 4 (Ultra)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(VRadius.sm),
        border: Border.all(color: bg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: bg, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _macroMetric(String title, String val, String sub, Color col) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: VColor.textLow, fontSize: 9.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(color: col, fontSize: 16, fontWeight: FontWeight.w800)),
        Text(sub, style: const TextStyle(color: VColor.textMid, fontSize: 10)),
      ],
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VColor.bgLift,
        borderRadius: BorderRadius.circular(VRadius.pill),
        border: Border.all(color: VColor.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: VColor.textMid),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: VColor.textMid, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surfaceRaised,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: VColor.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Barcode Scanner', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: _torchOn ? 'Turn Flash Off' : 'Turn Flash On',
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchOn ? VColor.accentOrange : VColor.textMid,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(VSpace.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Optical HUD Viewfinder Box (Stitch Page 33) ──
            Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(VRadius.xl),
                border: Border.all(color: VColor.accent.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: VColor.accent.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Corner target brackets
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: VColor.accent, width: 3),
                          left: BorderSide(color: VColor.accent, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: VColor.accent, width: 3),
                          right: BorderSide(color: VColor.accent, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: VColor.accent, width: 3),
                          left: BorderSide(color: VColor.accent, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: VColor.accent, width: 3),
                          right: BorderSide(color: VColor.accent, width: 3),
                        ),
                      ),
                    ),
                  ),

                  // Center Barcode Target Outline
                  Center(
                    child: Container(
                      width: 200,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.white30),
                      ),
                    ),
                  ),

                  // Sweeping laser animation line
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 280 * _scanLineAnimation.value,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, VColor.accent, VColor.accentGreen, Colors.transparent],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: VColor.accent.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Status badge top center
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(VRadius.pill),
                          border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fiber_manual_record, color: VColor.accentGreen, size: 8),
                            SizedBox(width: 6),
                            Text(
                              'OPTICAL HUD READY',
                              style: TextStyle(color: VColor.accentGreen, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: VSpace.base),

            // ── Quick Test Barcode Buttons ──
            const VLabel('PRE-CALIBRATED PRODUCT SAMPLES'),
            const SizedBox(height: VSpace.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.barcode_reader, size: 16, color: VColor.accent),
                  label: const Text('Protein Bar 890123', style: TextStyle(color: VColor.text, fontSize: 12)),
                  backgroundColor: VColor.surfaceRaised,
                  side: const BorderSide(color: VColor.line),
                  onPressed: () => _handleBarcode('8901234567890'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.local_drink_rounded, size: 16, color: VColor.accentGreen),
                  label: const Text('Electrolyte Water 890987', style: TextStyle(color: VColor.text, fontSize: 12)),
                  backgroundColor: VColor.surfaceRaised,
                  side: const BorderSide(color: VColor.line),
                  onPressed: () => _handleBarcode('8909876543210'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.breakfast_dining_rounded, size: 16, color: VColor.accentOrange),
                  label: const Text('Oat Muesli 890456', style: TextStyle(color: VColor.text, fontSize: 12)),
                  backgroundColor: VColor.surfaceRaised,
                  side: const BorderSide(color: VColor.line),
                  onPressed: () => _handleBarcode('8904561237894'),
                ),
              ],
            ),
            const SizedBox(height: VSpace.lg),

            // ── Manual Barcode Entry ──
            const VLabel('MANUAL BARCODE ENTRY'),
            const SizedBox(height: VSpace.xs),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: VColor.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter 12 or 13 digit EAN/UPC...',
                      hintStyle: const TextStyle(color: VColor.textLow, fontSize: 13),
                      fillColor: VColor.surfaceRaised,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.md),
                        borderSide: const BorderSide(color: VColor.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.md),
                        borderSide: const BorderSide(color: VColor.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.md),
                        borderSide: const BorderSide(color: VColor.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: VSpace.sm),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VColor.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.md)),
                  ),
                  onPressed: () => _handleBarcode(_manualController.text),
                  child: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Lookup', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
