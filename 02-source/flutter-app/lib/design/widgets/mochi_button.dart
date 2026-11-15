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
    this.size = MochiButtonSize.medium,
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

/// Circular icon action used in app bars and card headers.
class MochiIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  final Color? color;
  final Color? background;

  const MochiIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 44,
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
      icon: Icon(icon, size: MochiIconSize.md),
    );
  }
}
