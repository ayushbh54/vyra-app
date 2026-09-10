import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared VYRA widgets.
///
/// Every screen is built from these, so the rules that matter — how a
/// disclaimer looks, minimum touch targets, how an empty state reads — are
/// decided once here instead of being re-invented on each screen.

// -----------------------------------------------------------------------------
// Surfaces
// -----------------------------------------------------------------------------

enum CardTone { normal, raised, accent, warn, critical }

class VCard extends StatelessWidget {
  const VCard({super.key, required this.child, this.tone = CardTone.normal, this.padding});

  final Widget child;
  final CardTone tone;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final (bg, border) = switch (tone) {
      CardTone.raised => (VColor.surfaceRaised, VColor.line),
      CardTone.accent => (VColor.accentGlow, VColor.accent),
      CardTone.warn => (VColor.warnSoft, VColor.warn),
      CardTone.critical => (VColor.critSoft, VColor.crit),
      CardTone.normal => (VColor.surface, VColor.line),
    };

    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(VSpace.base),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(VRadius.lg),
      ),
      child: child,
    );
  }
}

class VLabel extends StatelessWidget {
  const VLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      );
}

class VSectionHeader extends StatelessWidget {
  const VSectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: VSpace.sm, bottom: VSpace.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [VLabel(title), if (trailing != null) trailing!],
        ),
      );
}

// -----------------------------------------------------------------------------
// Progress ring
// -----------------------------------------------------------------------------

class VRing extends StatelessWidget {
  const VRing({
    super.key,
    required this.progress,
    this.size = 88,
    this.stroke = 9,
    this.tint = VColor.accent,
    this.child,
  });

  /// 0..1. Values above 1 are clamped — an overachieved goal should read as
  /// "full", not wrap around and look like it was barely started.
  final double progress;
  final double size;
  final double stroke;
  final Color tint;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress.clamp(0, 1).toDouble(), stroke, tint),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.stroke, this.tint);

  final double progress;
  final double stroke;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..color = VColor.steel
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final arc = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(centre, radius, track);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2, // start at twelve o'clock, not three
        2 * math.pi * progress,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.tint != tint || old.stroke != stroke;
}

// -----------------------------------------------------------------------------
// Sparkline
// -----------------------------------------------------------------------------

class VSparkline extends StatelessWidget {
  const VSparkline({
    super.key,
    required this.values,
    this.tint = VColor.accent,
    this.bandLow,
    this.bandHigh,
    this.height = 56,
  });

  final List<double> values;
  final Color tint;
  final double? bandLow;
  final double? bandHigh;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Not enough readings yet — log a few more to see a trend.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VColor.textLow),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(values, tint, bandLow, bandHigh)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.tint, this.bandLow, this.bandHigh);

  final List<double> values;
  final Color tint;
  final double? bandLow;
  final double? bandHigh;

  @override
  void paint(Canvas canvas, Size size) {
    var min = values.reduce(math.min);
    var max = values.reduce(math.max);
    if (bandLow != null) min = math.min(min, bandLow!);
    if (bandHigh != null) max = math.max(max, bandHigh!);

    final range = (max - min).abs() < 0.001 ? 1.0 : max - min;
    double x(int i) => (i / (values.length - 1)) * size.width;
    double y(double v) => size.height - ((v - min) / range) * size.height;

    // The shaded "usual range" band. Reference only — never a diagnosis.
    if (bandLow != null && bandHigh != null) {
      canvas.drawRect(
        Rect.fromLTRB(0, y(bandHigh!), size.width, y(bandLow!)),
        Paint()..color = tint.withValues(alpha: 0.10),
      );
    }

    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Emphasise the latest reading — the one the user actually cares about.
    canvas.drawCircle(
      Offset(x(values.length - 1), y(values.last)),
      3.5,
      Paint()..color = tint,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values;
}

// -----------------------------------------------------------------------------
// Messaging
// -----------------------------------------------------------------------------

/// Every disclaimer in the app renders through this widget, so none can be
/// quietly dropped, shrunk, or restyled into invisibility during a redesign.
class VDisclaimer extends StatelessWidget {
  const VDisclaimer(this.text, {super.key, this.severe = false});

  final String text;
  final bool severe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.md),
      decoration: BoxDecoration(
        color: severe ? VColor.critSoft : VColor.warnSoft,
        borderRadius: BorderRadius.circular(VRadius.sm),
        border: Border(
          left: BorderSide(color: severe ? VColor.crit : VColor.warn, width: 2),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(color: VColor.textMid, fontSize: 11.5, height: 1.5),
      ),
    );
  }
}

class VPill extends StatelessWidget {
  const VPill(this.text, {super.key, this.tone = CardTone.accent});

  final String text;
  final CardTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      CardTone.warn => (VColor.warnSoft, VColor.warn),
      CardTone.critical => (VColor.critSoft, VColor.crit),
      CardTone.raised || CardTone.normal => (VColor.surfaceRaised, VColor.textLow),
      CardTone.accent => (VColor.accentGlow, VColor.accent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(VRadius.pill)),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      ),
    );
  }
}

class VEmptyState extends StatelessWidget {
  const VEmptyState({super.key, required this.title, required this.body, this.action});

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => VCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: VSpace.sm),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
            if (action != null) ...[const SizedBox(height: VSpace.base), action!],
          ],
        ),
      );
}

class VLoading extends StatelessWidget {
  const VLoading({super.key, this.label = 'Loading'});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: VSpace.xxl),
        child: Column(
          children: [
            const CircularProgressIndicator(color: VColor.accent, strokeWidth: 2.5),
            const SizedBox(height: VSpace.md),
            Text(label, style: const TextStyle(color: VColor.textLow, fontSize: 13)),
          ],
        ),
      );
}

class VErrorView extends StatelessWidget {
  const VErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => VCard(
        tone: CardTone.warn,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(color: VColor.text, fontSize: 14, height: 1.45)),
            if (onRetry != null) ...[
              const SizedBox(height: VSpace.md),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      );
}

/// A metric tile. `unit` is separated so numbers stay visually aligned in a row.
class VStat extends StatelessWidget {
  const VStat({super.key, required this.label, required this.value, this.unit, this.tint});

  final String label;
  final String value;
  final String? unit;
  final Color? tint;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          VLabel(label),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              text: value,
              style: TextStyle(
                color: tint ?? VColor.text,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: VColor.textLow, fontSize: 11.5, fontWeight: FontWeight.w400),
                  ),
              ],
            ),
          ),
        ],
      );
}

// -----------------------------------------------------------------------------
// Kinetic Obsidian Gradient Primary CTA & Header Components
// -----------------------------------------------------------------------------

class VGradientButton extends StatelessWidget {
  const VGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.gradient,
    this.height = 54,
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final Gradient? gradient;
  final double height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ??
        const LinearGradient(
          colors: [VColor.accent, VColor.accentGreen],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );

    final radius = BorderRadius.circular(borderRadius ?? VRadius.lg);

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D00D2FF),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: isLoading ? null : onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: VColor.textOnAccent,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: VColor.textOnAccent, size: 20),
                        const SizedBox(width: VSpace.sm),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: VColor.textOnAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: VSpace.sm),
                        Icon(trailingIcon, color: VColor.textOnAccent, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class VHeaderBadge extends StatelessWidget {
  const VHeaderBadge({
    super.key,
    required this.label,
    this.accentColor = VColor.accent,
  });

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

