import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_button.dart';

/// Decorative illustration slot: a soft accent blob with sparkles and one of
/// the bundled mascot images. Falls back to the blob alone if the asset is
/// missing, so the layout never breaks.
class MochiIllustration extends StatelessWidget {
  final String? asset;
  final double size;
  final String? semanticLabel;
  final bool sparkles;

  const MochiIllustration({
    super.key,
    this.asset,
    this.size = 132,
    this.semanticLabel,
    this.sparkles = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.softAccent,
                      palette.softAccent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            if (asset != null)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(size * .1),
                  child: Image.asset(
                    asset!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
                ),
              )
            else
              Icon(
                Icons.auto_awesome_rounded,
                size: size * .32,
                color: palette.action,
              ),
            if (sparkles)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SparklePainter(
                      color: palette.action,
                      secondary: palette.gradientEnd,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color, secondary;
  const _SparklePainter({required this.color, required this.secondary});

  @override
  void paint(Canvas canvas, Size size) {
    final specs = [
      (0.10, 0.20, 5.0, color),
      (0.86, 0.16, 4.0, secondary),
      (0.90, 0.66, 6.0, color.withValues(alpha: .8)),
      (0.16, 0.78, 3.5, secondary.withValues(alpha: .8)),
      (0.72, 0.90, 3.0, color.withValues(alpha: .7)),
    ];
    final paint = Paint()..style = PaintingStyle.fill;
    for (final (fx, fy, radius, tint) in specs) {
      paint.color = tint;
      final center = Offset(size.width * fx, size.height * fy);
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final angle = math.pi / 2 * i;
        final tip = center + Offset(math.cos(angle), math.sin(angle)) * radius;
        final next =
            center +
            Offset(
                  math.cos(angle + math.pi / 2),
                  math.sin(angle + math.pi / 2),
                ) *
                radius *
                .28;
        if (i == 0) {
          path.moveTo(tip.dx, tip.dy);
        } else {
          path.lineTo(tip.dx, tip.dy);
        }
        path.lineTo(next.dx, next.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) =>
      old.color != color || old.secondary != secondary;
}

/// Empty / idle block: illustration, title, message and an optional action.
class MochiEmptyState extends StatelessWidget {
  final String? asset;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? footer;

  const MochiEmptyState({
    super.key,
    required this.message,
    this.asset,
    this.title,
    this.actionLabel,
    this.onAction,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: MochiIllustration(
            asset: asset,
            size: 148,
            semanticLabel: title,
          ),
        ),
        const SizedBox(height: MochiSpacing.sm),
        if (title != null)
          Text(
            title!,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(color: palette.ink),
          ),
        if (title != null) const SizedBox(height: MochiSpacing.xxs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: MochiSpacing.md),
          Center(
            child: MochiButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: MochiButtonVariant.secondary,
            ),
          ),
        ],
        if (footer != null) ...[
          const SizedBox(height: MochiSpacing.md),
          footer!,
        ],
      ],
    );
  }
}

/// Skeleton placeholder with a gentle pulse (static when motion is reduced).
class MochiSkeleton extends StatefulWidget {
  final double height;
  final double width;
  final double radius;
  const MochiSkeleton({
    super.key,
    this.height = 14,
    this.width = double.infinity,
    this.radius = 8,
  });

  @override
  State<MochiSkeleton> createState() => _MochiSkeletonState();
}

class _MochiSkeletonState extends State<MochiSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final bar = Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: palette.softAccent,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
    if (reduce) return bar;
    return FadeTransition(
      opacity: Tween<double>(
        begin: .45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: bar,
    );
  }
}

/// Loading block with the pulse skeleton and a short Vietnamese label.
class MochiLoadingState extends StatelessWidget {
  final String label;
  const MochiLoadingState({super.key, this.label = 'Đang tải…'});

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    return Padding(
      padding: MochiSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MochiSkeleton(width: 120, height: 12),
          const SizedBox(height: MochiSpacing.sm),
          const MochiSkeleton(),
          const SizedBox(height: MochiSpacing.xs),
          const MochiSkeleton(width: 220, height: 12),
          const SizedBox(height: MochiSpacing.lg),
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(palette.accent),
                ),
              ),
              const SizedBox(width: MochiSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
