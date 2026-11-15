
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_haptics.dart';

class MochiAppBar extends StatelessWidget
    implements PreferredSizeWidget {
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

  double get _toolbarHeight =>
      toolbarHeight ?? (large ? 112 : 64);

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (showDivider ? 1 : 0));

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);

    final canPop = ModalRoute.of(context)?.canPop ?? false;

    final leadingWidget = leading ??
        (automaticallyImplyLeading && canPop
            ? _MochiBackButton(color: palette.ink)
            : null);

    final statusBrightness =
        palette.pageTop.computeLuminance() > 0.5
            ? Brightness.dark
            : Brightness.light;

    final content = large
        ? _buildLargeHeader(context, palette, leadingWidget)
        : _buildDetailHeader(context, palette, leadingWidget);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBrightness,
        statusBarBrightness:
            statusBrightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
        ),
        child: Material(
          color: Colors.transparent,
          elevation: elevation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              content,
              if (showDivider)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: palette.cardBorder,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeHeader(
    BuildContext context,
    MochiPalette palette,
    Widget? leadingWidget,
  ) {
    final theme = Theme.of(context);

    return SizedBox(
      height: _toolbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MochiSpacing.lg,
          vertical: MochiSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leadingWidget != null) ...[
              leadingWidget,
              const SizedBox(width: MochiSpacing.sm),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: -0.6,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: palette.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: MochiSpacing.sm),
              _ActionRow(actions: actions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailHeader(
    BuildContext context,
    MochiPalette palette,
    Widget? leadingWidget,
  ) {
    final theme = Theme.of(context);

    return SizedBox(
      height: _toolbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MochiSpacing.sm,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const buttonWidth = 48.0;
            final leadingWidth =
                leadingWidget == null ? 0.0 : buttonWidth;

            final actionsWidth = actions.length * buttonWidth;

            final sideWidth = math.max(
              leadingWidth,
              actionsWidth,
            );

            return Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sideWidth + MochiSpacing.sm,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (leadingWidget != null) leadingWidget,
                    const Spacer(),
                    if (actions.isNotEmpty)
                      _ActionRow(actions: actions),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0)
            const SizedBox(width: MochiSpacing.xs),
          actions[i],
        ],
      ],
    );
  }
}

class _MochiBackButton extends StatelessWidget {
  final Color color;

  const _MochiBackButton({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final rtl =
        Directionality.of(context) == TextDirection.rtl;

    return IconButton(
      tooltip: 'Quay lại',
      onPressed: () {
        MochiHaptics.tap(context);
        Navigator.maybePop(context);
      },
      style: IconButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(48, 48),
        maximumSize: const Size(48, 48),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: const CircleBorder(),
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
