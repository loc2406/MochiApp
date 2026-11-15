import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_haptics.dart';

class MochiSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  const MochiSegment({required this.value, required this.label, this.icon});
}

/// Pill segmented control: light track, gradient pill for the selected option.
class MochiSegmentedControl<T> extends StatelessWidget {
  final List<MochiSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool expanded;

  const MochiSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    this.onChanged,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);

    final items = [
      for (final segment in segments)
        _SegmentButton(
          label: segment.label,
          icon: segment.icon,
          selected: segment.value == value,
          onTap: onChanged == null || segment.value == value
              ? null
              : () {
                  MochiHaptics.tap(context);
                  onChanged!(segment.value);
                },
          palette: palette,
          theme: theme,
          expanded: expanded,
        ),
    ];

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: MochiRadius.pillBorder,
          border: Border.all(color: palette.cardBorder),
        ),
        child: expanded
            ? Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(child: items[i]),
                  ],
                ],
              )
            : Row(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final MochiPalette palette;
  final ThemeData theme;
  final bool expanded;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.palette,
    required this.theme,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? palette.onAccent : palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: MochiMotion.of(context, MochiMotion.base),
        curve: MochiMotion.curve,
        decoration: BoxDecoration(
          gradient: selected ? palette.primaryGradient : null,
          borderRadius: MochiRadius.pillBorder,
          boxShadow: selected ? palette.glow : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MochiSpacing.md,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: foreground),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontSize: 12.5,
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
    );
  }
}
