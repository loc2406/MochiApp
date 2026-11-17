import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_haptics.dart';
import '../pastel/pastel_components.dart';

enum MochiButtonVariant { primary, secondary, ghost, danger }

enum MochiButtonSize { medium, small }

/// Pill button. Primary uses the accent gradient with a soft glow, secondary
/// is a white card with accent text, ghost is text-only and danger is for
/// destructive confirmation.
class MochiButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final MochiButtonVariant variant;
  final MochiButtonSize size;
  final bool expand;
  final bool loading;
  final String? semanticLabel;

  const MochiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = MochiButtonVariant.primary,
    this.size = MochiButtonSize.small,
    this.expand = false,
    this.loading = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: PastelButton(
        label: label,
        icon: icon,
        expand: expand,
        loading: loading,
        variant: PastelButtonVariant.values[variant.index],
        size: PastelButtonSize.values[size.index],
        onPressed: onPressed == null
            ? null
            : () {
                MochiHaptics.tap(context);
                onPressed!();
              },
      ),
    );
  }
}

/// Backgroundless text action with Mochi typography, haptics, and touch target.
/// It expands when requested while allowing its label to wrap on narrow screens.
class MochiTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final String? semanticLabel;

  const MochiTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final enabled = onPressed != null && !loading;
    final foreground = enabled ? palette.action : palette.muted;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MochiSpacing.touch),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: MochiRadius.pillBorder,
              onTap: enabled
                  ? () {
                      MochiHaptics.tap(context);
                      onPressed!();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MochiSpacing.sm,
                  vertical: MochiSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    else if (icon != null)
                      Icon(icon, size: 17, color: foreground),
                    if (loading || icon != null)
                      const SizedBox(width: MochiSpacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon action used in app bars and card headers.
class MochiIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool filled;
  final Color? color;
  final Color? background;

  const MochiIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 44,
    this.iconSize = MochiIconSize.md,
    this.filled = true,
    this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final tint = color ?? palette.accent;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed == null
          ? null
          : () {
              MochiHaptics.tap(context);
              onPressed!();
            },
      style: IconButton.styleFrom(
        backgroundColor: filled
            ? (background ?? palette.card)
            : Colors.transparent,
        foregroundColor: onPressed == null ? palette.muted : tint,
        disabledForegroundColor: palette.muted,
        minimumSize: Size(size, size),
        maximumSize: Size(size, size),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        side: filled ? BorderSide(color: palette.cardBorder) : BorderSide.none,
      ),
      icon: Icon(icon, size: iconSize),
    );
  }
}
