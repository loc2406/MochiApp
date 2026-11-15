import 'package:flutter/widgets.dart';

class FloatingBarInset extends InheritedWidget {
  final double bottomObstruction;
  final bool isBarVisible;

  const FloatingBarInset({
    super.key,
    required this.bottomObstruction,
    required this.isBarVisible,
    required super.child,
  });

  static double of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<FloatingBarInset>();
    return provider?.bottomObstruction ?? 0.0;
  }

  static bool isVisible(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<FloatingBarInset>();
    return provider?.isBarVisible ?? true;
  }

  @override
  bool updateShouldNotify(FloatingBarInset oldWidget) =>
      bottomObstruction != oldWidget.bottomObstruction ||
      isBarVisible != oldWidget.isBarVisible;
}
