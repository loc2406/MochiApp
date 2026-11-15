import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_haptics.dart';
import 'mochi_nav_bar.dart';

/// Desktop/tablet sidebar: brand mark, profile card, grouped navigation and a
/// streak footer. Shares the accent palette with the rest of the system.
class MochiSidebar extends StatelessWidget {
  final List<MochiNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final String userName;
  final String userSubtitle;
  final String streakLabel;
  final Widget? footer;
  final double width;

  const MochiSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.userName,
    required this.userSubtitle,
    required this.streakLabel,
    this.footer,
    this.width = 264,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(right: BorderSide(color: palette.cardBorder)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MochiSpacing.lg,
            MochiSpacing.lg,
            MochiSpacing.md,
            MochiSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: palette.primaryGradient,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: palette.glow,
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: palette.onAccent,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: MochiSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MOCHI',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.4,
                            color: palette.ink,
                          ),
                        ),
                        Text(
                          'Học cùng nhau',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MochiSpacing.xl),
              Container(
                padding: const EdgeInsets.all(MochiSpacing.sm),
                decoration: BoxDecoration(
                  color: palette.cardSoft,
                  borderRadius: BorderRadius.circular(MochiRadius.control),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: palette.softAccent,
                      child: Text(
                        userName.isEmpty ? 'M' : userName[0].toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: palette.action,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: MochiSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName.isEmpty ? 'Người học' : userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 13,
                              color: palette.ink,
                            ),
                          ),
                          Text(
                            userSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MochiSpacing.xl),
              Padding(
                padding: const EdgeInsets.only(left: MochiSpacing.xs),
                child: Text(
                  'MENU CHÍNH',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.muted,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: MochiSpacing.xs),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: MochiSpacing.xxs),
                  itemBuilder: (context, index) => _SidebarRow(
                    item: items[index],
                    selected: index == currentIndex,
                    onTap: () {
                      MochiHaptics.tap(context);
                      onSelected(index);
                    },
                  ),
                ),
              ),
              ?footer,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MochiSpacing.sm,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.cardSoft,
                  borderRadius: BorderRadius.circular(MochiRadius.control),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: palette.warning,
                      size: 20,
                    ),
                    const SizedBox(width: MochiSpacing.xs),
                    Expanded(
                      child: Text(
                        streakLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: palette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  final MochiNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final color = item.prominent
        ? palette.accent
        : (selected ? palette.ink : palette.muted);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: selected || item.prominent
            ? palette.softAccent
            : Colors.transparent,
        borderRadius: BorderRadius.circular(MochiRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MochiRadius.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MochiSpacing.sm,
              vertical: 10,
            ),
            child: Row(
              children: [
                item.iconBuilder?.call(color) ??
                    Icon(item.icon, size: 20, color: color),
                const SizedBox(width: MochiSpacing.sm),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 13.5,
                      color: color,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.circle, size: 7, color: palette.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
