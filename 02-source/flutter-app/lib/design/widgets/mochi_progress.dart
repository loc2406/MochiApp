import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';

/// Thick accent-gradient progress ring with an optional centre child.
///
/// Used for the study session and "đã hoàn thành" states. With reduced motion
/// the arc is painted at its final value immediately.
class MochiProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final IconData? icon;
  final String? semanticsLabel;
  final bool showValueLabel;

  const MochiProgressRing({
    super.key,
    required this.value,
    this.size = 72,
    this.strokeWidth = 8,
    this.child,
    this.icon,
    this.semanticsLabel,
    this.showValueLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final clamped = value.clamp(0.0, 1.0);
    final label = semanticsLabel ?? 'Tiến độ';

    return Semantics(
      label: label,
      value: '${(clamped * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: clamped,
            strokeWidth: strokeWidth,
            track: palette.softAccent,
            start: palette.gradientStart,
            end: palette.gradientEnd,
            solid: palette.highContrast,
            trackBorder: palette.cardBorder,
          ),
          child: Center(
            child:
                child ??
                (icon != null
                    ? Icon(icon, size: size * .4, color: palette.accent)
                    : showValueLabel
                    ? Text(
                        '${(clamped * 100).round()}%',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: palette.ink),
                      )
                    : null),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value, strokeWidth;
  final Color track, start, end, trackBorder;
  final bool solid;

  const _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.track,
    required this.start,
    required this.end,
    required this.solid,
    required this.trackBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);

    if (value <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = solid
          ? null
          : SweepGradient(
              startAngle: -math.pi / 2,
              endAngle: 3 * math.pi / 2,
              colors: [start, end],
              transform: const GradientRotation(-math.pi / 2),
            ).createShader(rect);
    if (solid) paint.color = start;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.strokeWidth != strokeWidth ||
      old.start != start ||
      old.end != end ||
      old.track != track ||
      old.solid != solid;
}

/// Slim gradient progress bar with optional label/value row.
class MochiProgressBar extends StatelessWidget {
  final double value;
  final String? label;
  final String? valueLabel;
  final double height;
  final bool showValue;

  const MochiProgressBar({
    super.key,
    required this.value,
    this.label,
    this.valueLabel,
    this.height = 8,
    this.showValue = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final clamped = value.clamp(0.0, 1.0);
    final text = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: palette.muted);
    return Semantics(
      label: label ?? 'Tiến độ',
      value: '${(clamped * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null || showValue)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  if (label != null)
                    Expanded(
                      child: Text(
                        label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text,
                      ),
                    )
                  else
                    const Spacer(),
                  if (showValue)
                    Text(
                      valueLabel ?? '${(clamped * 100).round()}%',
                      style: text?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: Stack(
              children: [
                Container(height: height, color: palette.softAccent),
                FractionallySizedBox(
                  widthFactor: clamped,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: palette.primaryGradient,
                      borderRadius: BorderRadius.circular(height),
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
