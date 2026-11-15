import 'package:flutter/material.dart';

import '../pastel/pastel_theme.dart';

/// Pastel gradient for actions that contain arbitrary widget content.
class MochiPrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  const MochiPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });
  MochiPrimaryButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.style,
  }) : child = Row(
         mainAxisSize: MainAxisSize.min,
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           icon,
           const SizedBox(width: 8),
           Flexible(child: label),
         ],
       );
  @override
  Widget build(BuildContext context) {
    final p = PastelPalette.of(context);
    return Opacity(
      opacity: onPressed == null ? .48 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: p.primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: p.shadow,
        ),
        child: TextButton(
          onPressed: onPressed,
          style: (style ?? const ButtonStyle()).copyWith(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            foregroundColor: WidgetStatePropertyAll(p.onAction),
            shape: const WidgetStatePropertyAll(StadiumBorder()),
            minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
