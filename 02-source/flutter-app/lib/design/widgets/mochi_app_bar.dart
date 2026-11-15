import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_haptics.dart';

/// Page header used by every Mochi screen.
///
/// Two layouts share one component:
/// * **root tabs** (`large: true`) show a big left-aligned title with a
///   subtitle and circular actions on the right, like the home/plan screens;
/// * **detail screens** centre the title, keep the iOS chevron on the leading
///   edge and put the actions on the trailing edge.
///
/// The bar is transparent over the page gradient: no fill, no blur, no divider
/// by default. Text and icons use the palette ink/accent so dark mode works.
class MochiAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool large;
  final double elevation;
  final bool automaticallyImplyLeading;
  final bool showDivider;
  final double? toolbarHeight;

  const MochiAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.large = false,
    this.elevation = 0,
    this.automaticallyImplyLeading = true,
    this.showDivider = false,
    this.toolbarHeight,
  });

  /// Compact centred header for pushed routes.
  const MochiAppBar.detail({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.elevation = 0,
    this.automaticallyImplyLeading = true,
    this.showDivider = false,
    this.toolbarHeight,
  }) : large = false;

  double get _toolbar => toolbarHeight ?? (large ? 92 : 64);

  double get _height => _toolbar + (showDivider ? 1 : 0);

  @override
  Size get preferredSize => Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final leadingWidget =
        leading ??
        (automaticallyImplyLeading && (ModalRoute.of(context)?.canPop ?? false)
            ? _MochiBackButton(color: palette.ink)
            : null);
    final statusBrightness = palette.pageTop.computeLuminance() > .5
        ? Brightness.dark
        : Brightness.light;

    final content = large
        ? _largeHeader(context, palette, theme, leadingWidget)
        : _detailHeader(context, palette, theme, leadingWidget);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBrightness,
        statusBarBrightness: statusBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (elevation > 0)
              Material(
                elevation: elevation,
                color: Colors.transparent,
                child: content,
              )
            else
              content,
            if (showDivider) Container(height: 1, color: palette.cardBorder),
          ],
        ),
      ),
    );
  }

  Widget _largeHeader(
    BuildContext context,
    MochiPalette palette,
    ThemeData theme,
    Widget? leadingWidget,
  ) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 22,
              color: palette.ink,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MochiSpacing.xl,
        MochiSpacing.sm,
        MochiSpacing.md,
        MochiSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ?leadingWidget,
          Expanded(child: titleBlock),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: MochiSpacing.sm),
            _ActionRow(actions: actions),
          ],
        ],
      ),
    );
  }

  Widget _detailHeader(
    BuildContext context,
    MochiPalette palette,
    ThemeData theme,
    Widget? leadingWidget,
  ) {
    final titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ],
      ],
    );

    return SizedBox(
      height: _toolbar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MochiSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final leadingWidth = leadingWidget == null
                ? 0.0
                : MochiSpacing.touch;
            final actionsWidth = actions.isEmpty
                ? 0.0
                : actions.length * 44 + (actions.length - 1) * MochiSpacing.xs;
            final reserve =
                math.max(leadingWidth, actionsWidth) + MochiSpacing.xs;
            return Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: math.min(reserve, constraints.maxWidth / 2),
                  ),
                  child: FittedBox(fit: BoxFit.scaleDown, child: titleBlock),
                ),
                Row(
                  children: [
                    ?leadingWidget,
                    const Spacer(),
                    if (actions.isNotEmpty) _ActionRow(actions: actions),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final List<Widget> actions;
  const _ActionRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    return IconTheme(
      data: IconThemeData(color: palette.action, size: MochiIconSize.md),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: palette.accent),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: MochiSpacing.xs),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _MochiBackButton extends StatelessWidget {
  final Color color;
  const _MochiBackButton({required this.color});

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return IconButton(
      tooltip: 'Quay lại',
      onPressed: () {
        MochiHaptics.tap(context);
        Navigator.maybePop(context);
      },
      style: IconButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.zero,
        minimumSize: const Size(MochiSpacing.touch, MochiSpacing.touch),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: Icon(
        rtl
            ? Icons.arrow_forward_ios_rounded
            : Icons.arrow_back_ios_new_rounded,
        size: 20,
      ),
    );
  }
}
