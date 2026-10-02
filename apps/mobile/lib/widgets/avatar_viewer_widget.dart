import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AVATAR VIEWER WIDGET (Offline-First Adobe Mixamo 3D GLB Engine)
/// Hardware-accelerated 60 FPS 3D avatar viewport with 360° touch orbit,
/// embedded Mixamo skeletal animations, auto-centering, and smooth lighting.
/// ─────────────────────────────────────────────────────────────────────────────
class AvatarViewerWidget extends StatefulWidget {
  const AvatarViewerWidget({
    required this.modelPath,
    this.animationName = 'Idle',
    this.autoPlay = true,
    this.cameraOrbit = '0deg 75deg 2.2m',
    this.height = 360,
    this.showHUD = true,
    this.coachName,
    this.coachTitle,
    this.onRotateHint,
    super.key,
  });

  /// Path to local asset (.glb) or remote HTTPS URL fallback
  final String modelPath;

  /// Embedded animation clip (e.g. 'Idle', 'Run', 'Walk', 'SambaDance')
  final String animationName;

  /// Whether the animation should auto-play in loop
  final bool autoPlay;

  /// Initial camera angle and zoom distance
  final String cameraOrbit;

  /// Viewport height
  final double height;

  /// Whether to render top/bottom status HUD overlays
  final bool showHUD;

  /// Coach name to display in HUD (e.g. "Alex", "Sara")
  final String? coachName;

  /// Coach title to display in HUD (e.g. "Fitness & Discipline Coach")
  final String? coachTitle;

  /// Callback when user interacts with rotation
  final VoidCallback? onRotateHint;

  @override
  State<AvatarViewerWidget> createState() => _AvatarViewerWidgetState();
}

class _AvatarViewerWidgetState extends State<AvatarViewerWidget> {
  bool _isCanvasReady = false;

  @override
  void initState() {
    super.initState();
    // Allow small delay for webview/hardware surface to mount cleanly
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isCanvasReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Background Ambient Studio Glow ──
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.1),
                radius: 0.9,
                colors: [
                  Color(0xFF191928),
                  Color(0xFF0D0D12),
                ],
              ),
            ),
          ),

          // ── 3D Hardware Accelerated Model Viewport ──
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ModelViewer(
              key: ValueKey('${widget.modelPath}_${widget.animationName}'),
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
            ),
          ),

          // ── Shimmer / Initializing Loader ──
          if (!_isCanvasReady)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0D0D12),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: VColor.surface,
                          border: Border.all(
                            color: VColor.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(VColor.accent),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Initializing 3D Coach…',
                        style: TextStyle(
                          color: VColor.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: VColor.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(VRadius.sm),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VColor.bg.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(VRadius.pill),
                      border: Border.all(color: VColor.accent.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.threed_rotation_rounded, size: 14, color: VColor.accentCyan),
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
    );
  }
}
