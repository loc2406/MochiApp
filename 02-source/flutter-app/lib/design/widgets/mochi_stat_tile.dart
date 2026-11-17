import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_chip.dart';

/// Statistic card in the reference style: pastel icon, small label, big value,
/// optional trend/caption and an optional mini bar chart.
class MochiStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? caption;
  final String? trend;
  final IconData? icon;
  final MochiChipTone iconTone;
  final List<double>? bars;
  final bool dense;

  const MochiStatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.trend,
    this.icon,
    this.iconTone = MochiChipTone.accent,
    this.bars,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final positive = trend != null && !trend!.trimLeft().startsWith('-');
    final (Color badgeBg, Color badgeFg) = switch (iconTone) {
      MochiChipTone.accent => (palette.softAccent, palette.action),
      MochiChipTone.neutral => (palette.cardSoft, palette.muted),
      MochiChipTone.success => (palette.successSoft, palette.success),
      MochiChipTone.warning => (palette.warningSoft, palette.warning),
      MochiChipTone.danger => (palette.dangerSoft, palette.danger),
      MochiChipTone.high => (palette.chipHighBg, palette.chipHighFg),
      MochiChipTone.medium => (palette.chipMediumBg, palette.chipMediumFg),
      MochiChipTone.low => (palette.chipLowBg, palette.chipLowFg),
    };

    return Padding(
      padding: EdgeInsets.all(dense ? MochiSpacing.sm : MochiSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Container(
              width: dense ? 38 : 44,
              height: dense ? 38 : 44,
              decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
              child: Icon(icon, size: dense ? 19 : 22, color: badgeFg),
            ),
          if (icon != null) SizedBox(width: dense ? 10 : MochiSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.muted,
                    fontSize: dense ? 11 : 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: dense ? 16 : 20,
                          fontWeight: FontWeight.w800,
                          color: palette.ink,
                          letterSpacing: -.4,
                        ),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 3),
                      Text(
                        unit!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: palette.muted,
                          fontSize: dense ? 11 : 12,
                        ),
                      ),
                    ],
                  ],
                ),
                if (trend != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        positive
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: positive ? palette.success : palette.danger,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: positive ? palette.success : palette.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ] else if (caption != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (bars != null && bars!.isNotEmpty) ...[
            const SizedBox(width: MochiSpacing.xs),
            _MiniBars(bars: bars!, color: palette.accent),
          ],
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  final List<double> bars;
  final Color color;
  const _MiniBars({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 44,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < bars.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Container(
                width: 7,
                height: 10 + 30 * bars[i].clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: .25 + .65 * bars[i].clamp(0, 1),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Places two or three [MochiStatTile]s side by side with equal width.
class MochiStatRow extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const MochiStatRow({
    super.key,
    required this.children,
    this.gap = MochiSpacing.sm,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14);
      if (constraints.maxWidth < 360 || textScale > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              children[i],
            ],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: children[i]),
            ],
          ],
        ),
      );
    },
  );
}
