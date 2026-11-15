import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../design/mochi_design.dart';

enum AppPageTransition { adaptive, fade, slideUp }

abstract final class CustomPageTransition {
  static Route<T> route<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    AppPageTransition transition = AppPageTransition.adaptive,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    final themes = InheritedTheme.capture(
      from: context,
      to: Navigator.of(context).context,
    );
    Widget page(BuildContext ctx) => themes.wrap(Builder(builder: builder));
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MochiVisuals.of(context).reduceMotion;
    if (!reduced &&
        transition == AppPageTransition.adaptive &&
        Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoPageRoute<T>(
        builder: page,
        settings: settings,
        fullscreenDialog: fullscreenDialog,
      );
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return PageRouteBuilder<T>(
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      transitionDuration: reduced ? Duration.zero : MochiMotion.slow,
      reverseTransitionDuration: reduced ? Duration.zero : MochiMotion.base,
      pageBuilder: (ctx, _, _) => page(ctx),
      transitionsBuilder: (ctx, animation, secondary, child) {
        if (reduced) return child;
        final curved = animation.drive(CurveTween(curve: MochiMotion.curve));
        final fade = FadeTransition(opacity: curved, child: child);
        if (transition == AppPageTransition.fade) return fade;
        return SlideTransition(
          position: Tween<Offset>(
            begin: transition == AppPageTransition.slideUp
                ? const Offset(0, .08)
                : Offset(rtl ? -.06 : .06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: fade,
        );
      },
    );
  }
}
