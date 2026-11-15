import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/mochi_backdrop.dart';

/// Haptics that respect the profile switch. Every component funnels through
/// here so "Rung phản hồi" can turn the whole app silent at once.
abstract final class MochiHaptics {
  static bool enabled(BuildContext context) => MochiVisuals.of(context).haptics;

  static void tap(BuildContext context) {
    if (enabled(context)) HapticFeedback.selectionClick();
  }

  static void medium(BuildContext context) {
    if (enabled(context)) HapticFeedback.mediumImpact();
  }

  static void success(BuildContext context) {
    if (enabled(context)) HapticFeedback.lightImpact();
  }
}
