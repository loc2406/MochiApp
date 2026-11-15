import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_haptics.dart';

class MochiNavItem {
  final String label;

  /// Regular icon. Ignored when [iconBuilder] is provided.
  final IconData? icon;

  /// Custom icon builder (used for the app's vector icons). Receives the tint
  /// that matches the current state.
  final Widget Function(Color color)? iconBuilder;

  /// Renders the item as the raised, gradient "assistant" action.
  final bool prominent;

  const MochiNavItem({
    required this.label,
    this.icon,
    this.iconBuilder,
    this.prominent = false,
  });
}

/// Floating pill navigation: white card, soft shadow, accent pill on the
/// active item and a gradient circle for the assistant action.
class MochiNavBar extends StatelessWidget {
  final List<MochiNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final double height;

  const MochiNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.height = MochiSpacing.navBar,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    return Semantics(
      container: true,
      label: 'Điều hướng chính',
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(
          horizontal: MochiSpacing.md,
          vertical: MochiSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: palette.navBar,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: palette.cardBorder),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: palette.shadow.a * .9),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: -8,
            ),
            BoxShadow(
              color: palette.accent.withValues(alpha: .10),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () {
                    MochiHaptics.medium(context);
                    onSelected(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final MochiNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final color = selected ? palette.accent : palette.muted;

    if (item.prominent) {
      return Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: InkResponse(
          onTap: onTap,
          radius: 34,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: palette.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: palette.glow,
                ),
                child: Icon(
                  item.icon ?? Icons.auto_awesome_rounded,
                  color: palette.onAccent,
                  size: 21,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? palette.accent : palette.muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final iconColor = selected ? palette.accent : palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Center(
          child: AnimatedContainer(
            duration: MochiMotion.of(context, MochiMotion.quick),
            curve: MochiMotion.curve,
            padding: const EdgeInsets.symmetric(
              horizontal: MochiSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: selected ? palette.softAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item.iconBuilder?.call(iconColor) ??
                    Icon(item.icon, size: 21, color: iconColor),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
