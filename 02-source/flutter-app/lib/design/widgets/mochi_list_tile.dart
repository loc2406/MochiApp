import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_chip.dart';
import 'mochi_haptics.dart';

/// Row used inside [MochiCard] groups: optional pastel icon badge, title,
/// subtitle, trailing widget or chevron. Mirrors the schedule/settings rows of
/// the reference design.
class MochiListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? icon;
  final MochiChipTone iconTone;
  final Widget? trailing;
  final String? trailingLabel;
  final MochiChipTone? trailingTone;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool dense;
  final EdgeInsetsGeometry padding;

  const MochiListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.icon,
    this.iconTone = MochiChipTone.accent,
    this.trailing,
    this.trailingLabel,
    this.trailingTone,
    this.showChevron = false,
    this.onTap,
    this.dense = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: MochiSpacing.lg,
      vertical: MochiSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final badge =
        leading ?? (icon == null ? null : _IconBadge(icon!, iconTone));

    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (badge != null) ...[badge, const SizedBox(width: MochiSpacing.sm)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: dense ? 13.5 : 14.5,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: dense ? 12 : 12.5,
                      color: palette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailingLabel != null) ...[
            const SizedBox(width: MochiSpacing.sm),
            MochiChip(
              label: trailingLabel!,
              tone: trailingTone ?? MochiChipTone.neutral,
              compact: true,
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: MochiSpacing.xs),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: MochiSpacing.xxs),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.muted.withValues(alpha: .8),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          MochiHaptics.tap(context);
          onTap!();
        },
        child: row,
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final MochiChipTone tone;
  const _IconBadge(this.icon, this.tone);

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
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: MochiIconSize.md, color: foreground),
    );
  }
}
