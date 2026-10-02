import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR SPEED PRESET
// Controls how fast the Mixamo animation plays.
// Maps to model-viewer timeScale (via relatedJs injection).
// ─────────────────────────────────────────────────────────────────────────────
enum AvatarSpeed {
  slow(0.4, '🐢', 'Slow'),
  normal(1.0, '▶', 'Normal'),
  fast(1.8, '⚡', 'Fast');

  const AvatarSpeed(this.timeScale, this.icon, this.label);
  final double timeScale;
  final String icon;
  final String label;
}

/// ─────────────────────────────────────────────────────────────────────────────
/// AVATAR VIEWER WIDGET (Offline-First Adobe Mixamo 3D GLB Engine)
/// Hardware-accelerated 60 FPS 3D avatar viewport with 360° touch orbit,
/// embedded Mixamo skeletal animations, speed control, and smooth lighting.
///
/// Speed control: Three buttons (🐢 Slow / ▶ Normal / ⚡ Fast) inject
/// a JS `timeScale` into model-viewer on load — no rebuild needed.
/// ─────────────────────────────────────────────────────────────────────────────
class AvatarViewerWidget extends StatefulWidget {
  const AvatarViewerWidget({
    required this.modelPath,
    this.animationName = 'idle',
    this.autoPlay = true,
    this.cameraOrbit = '0deg 75deg 3.2m',
    this.height = 360,
    this.showHUD = true,
    this.showSpeedControl = true,
    this.initialSpeed = AvatarSpeed.normal,
    this.outfitColor,
    this.pantsColor,
    this.auraColor,
    this.coachName,
    this.coachTitle,
    this.onRotateHint,
    this.onSpeedChanged,
    super.key,
  });

  /// Path to local asset (.glb) or remote HTTPS URL fallback
  final String modelPath;

  /// Embedded animation clip (e.g. 'idle', 'run', 'walk', 'agree')
  final String animationName;

  /// Whether the animation should auto-play in loop
  final bool autoPlay;

  /// Initial camera angle and zoom distance
  final String cameraOrbit;

  /// Viewport height
  final double height;

  /// Whether to render top/bottom status HUD overlays
  final bool showHUD;

  /// Whether to show the speed control bar (🐢 / ▶ / ⚡)
  final bool showSpeedControl;

  /// Initial animation speed preset
  final AvatarSpeed initialSpeed;

  /// Outfit top/shirt color tint
  final Color? outfitColor;

  /// Pants/bottoms color tint
  final Color? pantsColor;

  /// Energy aura ambient light color
  final Color? auraColor;

  /// Coach name to display in HUD (e.g. "Remy", "Megan")
  final String? coachName;

  /// Coach title to display in HUD (e.g. "Strength & Conditioning Coach")
  final String? coachTitle;

  /// Callback when user interacts with rotation
  final VoidCallback? onRotateHint;

  /// Callback when user changes speed (receives new timeScale)
  final ValueChanged<AvatarSpeed>? onSpeedChanged;

  @override
  State<AvatarViewerWidget> createState() => _AvatarViewerWidgetState();
}

class _AvatarViewerWidgetState extends State<AvatarViewerWidget> {
  bool _isCanvasReady = false;
  late AvatarSpeed _speed;

  @override
  void initState() {
    super.initState();
    _speed = widget.initialSpeed;
    // Allow WebView hardware surface to mount cleanly before showing canvas
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _isCanvasReady = true);
    });
  }

  /// Builds the JS snippet that sets timeScale and material colors on model-viewer.
  String _buildCustomizationJs({
    required double timeScale,
    Color? outfit,
    Color? pants,
  }) {
    String topRgba = '';
    if (outfit != null) {
      final r = (outfit.r).toStringAsFixed(2);
      final g = (outfit.g).toStringAsFixed(2);
      final b = (outfit.b).toStringAsFixed(2);
      topRgba = '[$r, $g, $b, 1.0]';
    }

    String bottomRgba = '';
    if (pants != null) {
      final r = (pants.r).toStringAsFixed(2);
      final g = (pants.g).toStringAsFixed(2);
      final b = (pants.b).toStringAsFixed(2);
      bottomRgba = '[$r, $g, $b, 1.0]';
    }

    return '''
    (function() {
      function applyCustomization() {
        var mv = document.querySelector('model-viewer');
        if (!mv) return;
        mv.timeScale = $timeScale;
        if (mv.model && mv.model.materials) {
          try {
            for (var i = 0; i < mv.model.materials.length; i++) {
              var mat = mv.model.materials[i];
              if (!mat || !mat.name) continue;
              // Remy Topmat / Megan Ch21_body
              if (mat.name === 'Topmat' || mat.name === 'Ch21_body') {
                ${topRgba.isNotEmpty ? "mat.pbrMetallicRoughness.setBaseColorFactor($topRgba);" : ""}
              }
              // Remy Bottommat
              if (mat.name === 'Bottommat') {
                ${bottomRgba.isNotEmpty ? "mat.pbrMetallicRoughness.setBaseColorFactor($bottomRgba);" : ""}
              }
            }
          } catch(e) {}
        }
      }
      var mv = document.querySelector('model-viewer');
      if (mv) {
        if (mv.loaded) {
          applyCustomization();
        } else {
          mv.addEventListener('load', applyCustomization, { once: true });
        }
      } else {
        document.addEventListener('DOMContentLoaded', function() {
          var mv2 = document.querySelector('model-viewer');
          if (mv2) mv2.addEventListener('load', applyCustomization, { once: true });
        });
      }
    })();
    ''';
  }

  void _setSpeed(AvatarSpeed speed) {
    if (_speed == speed) return;
    setState(() => _speed = speed);
    widget.onSpeedChanged?.call(speed);
  }

  @override
  Widget build(BuildContext context) {
    final aura = widget.auraColor ?? const Color(0xFF00E5FF);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 3D Viewport Stack ──
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Background Ambient Studio Glow ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 0.9,
                    colors: [
                      aura.withValues(alpha: 0.22),
                      const Color(0xFF0D0D12),
                    ],
                  ),
                ),
              ),

              // ── 3D Hardware Accelerated Model Viewport ──
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ModelViewer(
                  // Key includes all style variables so model re-tints smoothly on change
                  key: ValueKey(
                      '${widget.modelPath}_${widget.animationName}_${_speed.timeScale}_${widget.outfitColor?.toARGB32()}_${widget.auraColor?.toARGB32()}'),
                  src: widget.modelPath,
                  alt: widget.coachName ?? '3D Athletic Coach',
                  ar: false,
                  autoRotate: false,
                  cameraControls: true,
                  autoPlay: widget.autoPlay,
                  animationName: widget.animationName,
                  shadowIntensity: 0.85,
                  shadowSoftness: 0.8,
                  exposure: 1.15,
                  cameraOrbit: widget.cameraOrbit,
                  backgroundColor: const Color(0xFF0D0D12),
                  loading: Loading.eager,
                  // Inject customization JS (speed + outfit material colors)
                  relatedJs: _buildCustomizationJs(
                    timeScale: _speed.timeScale,
                    outfit: widget.outfitColor,
                    pants: widget.pantsColor,
                  ),
                ),
              ),

              // ── Shimmer / Initializing Loader ──
              if (!_isCanvasReady)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0D0D18), Color(0xFF0A0A12)],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.05),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeInOut,
                          builder: (context, scale, child) => Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    VColor.accent.withValues(alpha: 0.3),
                                    VColor.accent.withValues(alpha: 0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: VColor.accent.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 36,
                                color: VColor.accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (widget.coachName != null) ...[
                          Text(
                            widget.coachName!,
                            style: const TextStyle(
                              color: VColor.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (widget.coachTitle != null)
                            Text(
                              widget.coachTitle!,
                              style: const TextStyle(
                                color: VColor.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                        SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                            backgroundColor: VColor.line,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                VColor.accent),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Loading 3D Avatar…',
                          style: TextStyle(
                            color: VColor.textLow,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Top HUD: Coach Info & 360° Orbit Indicator ──
              if (widget.showHUD)
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.coachName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: VColor.surface.withValues(alpha: 0.85),
                            borderRadius:
                                BorderRadius.circular(VRadius.sm),
                            border: Border.all(color: VColor.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: VColor.accentGreen,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.coachName!,
                                style: const TextStyle(
                                  color: VColor.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (widget.coachTitle != null) ...[
                                Text(
                                  ' • ${widget.coachTitle}',
                                  style: const TextStyle(
                                    color: VColor.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      // 360 Drag rotation badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: VColor.bg.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(VRadius.pill),
                          border: Border.all(
                              color: VColor.accent.withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.threed_rotation_rounded,
                                size: 14, color: VColor.accentCyan),
                            SizedBox(width: 4),
                            Text(
                              '360° Drag',
                              style: TextStyle(
                                color: VColor.accentCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ── Speed Control Bar (below viewport) ──
        if (widget.showSpeedControl) ...[
          const SizedBox(height: 10),
          _SpeedControlBar(
            current: _speed,
            onChanged: _setSpeed,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPEED CONTROL BAR WIDGET
// Three pill buttons: 🐢 Slow | ▶ Normal | ⚡ Fast
// Active pill highlights with accent color + glow.
// ─────────────────────────────────────────────────────────────────────────────
class _SpeedControlBar extends StatelessWidget {
  const _SpeedControlBar({
    required this.current,
    required this.onChanged,
  });

  final AvatarSpeed current;
  final ValueChanged<AvatarSpeed> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VColor.surface,
        borderRadius: BorderRadius.circular(VRadius.md),
        border: Border.all(color: VColor.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.speed_rounded, size: 14, color: VColor.textMuted),
          const SizedBox(width: 8),
          const Text(
            'Speed',
            style: TextStyle(
              color: VColor.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: AvatarSpeed.values.map((speed) {
                final isActive = current == speed;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(speed),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? VColor.accent.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(VRadius.pill),
                        border: Border.all(
                          color: isActive
                              ? VColor.accent.withValues(alpha: 0.7)
                              : VColor.line,
                          width: isActive ? 1.5 : 1,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: VColor.accent.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            speed.icon,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            speed.label,
                            style: TextStyle(
                              color:
                                  isActive ? VColor.accent : VColor.textMuted,
                              fontSize: 9,
                              fontWeight: isActive
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
