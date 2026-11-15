import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_haptics.dart';
import '../pastel/pastel_components.dart';

/// Pastel surface, using the same implementation as the approved review cards.
class MochiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool elevated;
  final bool bordered;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  final String? semanticLabel;

  const MochiCard({
    super.key,
    required this.child,
    this.padding = MochiSpacing.card,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.elevated = true,
    this.bordered = true,
    this.radius = MochiRadius.card,
    this.color,
    this.borderColor,
    this.gradient,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: PastelCard(
        padding: padding,
        margin: margin,
        radius: radius,
        color: color,
        borderColor: borderColor,
        gradient: gradient,
        elevated: elevated,
        bordered: bordered,
        onTap: onTap == null
            ? null
            : () {
                MochiHaptics.tap(context);
                onTap!();
              },
        child: child,
      ),
    );
  }
}

/// A grouped list inside one card, with an optional section title and a
/// trailing "Xem tất cả" action, matching the grouped lists of the reference.
class MochiSection extends StatelessWidget {
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final bool separated;

  const MochiSection({
    super.key,
    this.title,
    this.actionLabel,
    this.onAction,
    required this.children,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.symmetric(vertical: MochiSpacing.xxs),
    this.separated = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && separated) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            color: palette.cardBorder,
            indent: MochiSpacing.lg,
            endIndent: MochiSpacing.lg,
          ),
        );
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MochiSpacing.xxs,
              0,
              MochiSpacing.xxs,
              MochiSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.action,
                      padding: const EdgeInsets.symmetric(
                        horizontal: MochiSpacing.xs,
                      ),
                      minimumSize: const Size(0, 32),
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(actionLabel!),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        MochiCard(
          margin: margin,
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ],
    );
  }
}
