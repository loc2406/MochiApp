import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';

enum MochiChipTone {
  accent,
  neutral,
  success,
  warning,
  danger,
  high,
  medium,
  low,
}

/// Pastel status chip: soft tinted background with a strong same-hue label.
/// Used for priorities ("Ưu tiên cao"), counters ("Thẻ 3/8") and statuses.
class MochiChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final MochiChipTone tone;
  final bool compact;

  const MochiChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = MochiChipTone.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final (Color background, Color foreground) = switch (tone) {
      MochiChipTone.accent => (palette.softAccent, palette.action),
      MochiChipTone.neutral => (palette.cardSoft, palette.muted),
      MochiChipTone.success => (palette.successSoft, palette.success),
      MochiChipTone.warning => (palette.warningSoft, palette.warning),
      MochiChipTone.danger => (palette.dangerSoft, palette.danger),
      MochiChipTone.high => (palette.chipHighBg, palette.chipHighFg),
      MochiChipTone.medium => (palette.chipMediumBg, palette.chipMediumFg),
      MochiChipTone.low => (palette.chipLowBg, palette.chipLowFg),
    };
    final text = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w700,
      fontSize: compact ? 11 : 12,
    );

    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? MochiSpacing.xs : MochiSpacing.sm,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(MochiRadius.badge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 13 : 15, color: foreground),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(label, style: text)),
          ],
        ),
      ),
    );
  }
}
