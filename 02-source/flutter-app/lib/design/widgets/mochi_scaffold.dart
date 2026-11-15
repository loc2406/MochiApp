import 'package:flutter/material.dart';

import '../foundation/mochi_backdrop.dart';
import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_app_bar.dart';

/// Page shell for the Mochi design language: accent gradient behind, optional
/// app bar, content constrained to a comfortable reading width.
///
/// The scaffold itself is transparent, so it also works inside the tab shell
/// without painting a second background.
class MochiScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final MochiBackdrop? backdrop;
  final double maxWidth;
  final bool centerContent;
  final bool resizeToAvoidBottomInset;

  const MochiScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backdrop,
    this.maxWidth = MochiSpacing.contentMax,
    this.centerContent = true,
    this.resizeToAvoidBottomInset = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = centerContent
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: body,
            ),
          )
        : body;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: MochiBackground(
        backdrop: backdrop,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?appBar,
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

/// Convenience wrapper used by screens that push a detail route: transparent
/// scaffold + centred detail header + iOS back chevron.
class MochiDetailScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final MochiBackdrop? backdrop;

  const MochiDetailScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.backdrop,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    return MochiScaffold(
      backdrop: backdrop,
      appBar: MochiAppBar.detail(
        title: title,
        subtitle: subtitle,
        actions: actions,
      ),
      body: ColoredBox(
        color: Colors.transparent,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: palette.ink),
          child: body,
        ),
      ),
    );
  }
}
