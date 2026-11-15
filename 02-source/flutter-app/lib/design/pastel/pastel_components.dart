import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pastel_theme.dart';
export 'pastel_theme.dart';

class PastelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color, borderColor;
  final Gradient? gradient;
  final double radius;
  final bool elevated, bordered;
  const PastelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color,
    this.gradient,
    this.borderColor,
    this.radius = 26,
    this.elevated = true,
    this.bordered = true,
  });
  @override
  Widget build(BuildContext context) {
    final p = PastelPalette.of(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient ?? (color == null ? p.cardGradient : null),
        borderRadius: BorderRadius.circular(radius),
        border: bordered ? Border.all(color: borderColor ?? p.border) : null,
        boxShadow: elevated ? p.shadow : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

enum PastelButtonVariant { primary, secondary, ghost, danger }

enum PastelButtonSize { medium, small }

class PastelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PastelButtonVariant variant;
  final PastelButtonSize size;
  final bool expand, loading;
  const PastelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PastelButtonVariant.primary,
    this.size = PastelButtonSize.medium,
    this.expand = false,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = PastelPalette.of(context);
    final primary = variant == PastelButtonVariant.primary;
    final danger = variant == PastelButtonVariant.danger;
    final enabled = onPressed != null && !loading;
    final foreground = primary
        ? p.onAction
        : danger
        ? Colors.white
        : p.action;
    return Opacity(
      opacity: enabled || loading ? 1 : .48,
      child: Container(
        width: expand ? double.infinity : null,
        decoration: BoxDecoration(
          gradient: primary ? p.primary : null,
          color: primary
              ? null
              : danger
              ? const Color(0xFFBB294E)
              : p.soft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: primary ? p.accent.withValues(alpha: .45) : p.border,
          ),
          boxShadow: primary ? p.shadow : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size == PastelButtonSize.small ? 48 : 54,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size == PastelButtonSize.small ? 18 : 24,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    else if (icon != null)
                      Icon(icon, size: 21, color: foreground),
                    if (loading || icon != null) const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PastelIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const PastelIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final p = PastelPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.surface,
        boxShadow: p.shadow,
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: p.action,
          side: BorderSide(color: p.border),
        ),
      ),
    );
  }
}

class PastelAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool large;
  final List<Widget> actions;
  const PastelAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.large = false,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: 8), action],
        ],
      ),
    ),
  );
}

class PastelScaffold extends StatelessWidget {
  final Widget appBar, body;
  final String background;
  const PastelScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.background = 'lavender',
  });
  @override
  Widget build(BuildContext context) {
    final p = PastelPalette.of(context);
    final colors = PastelBackgrounds.colors(background, p.dark);
    return Scaffold(
      backgroundColor: colors.first,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!p.highContrast)
              Positioned(
                top: -100,
                right: -90,
                child: IgnorePointer(
                  child: Container(
                    width: 420,
                    height: 420,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors.last.withValues(alpha: .7),
                          colors.last.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    appBar,
                    Expanded(child: body),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PastelChipTone { accent, medium }

class PastelChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final PastelChipTone tone;
  const PastelChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = PastelChipTone.accent,
  });
  @override
  Widget build(BuildContext context) {
    final p = PastelPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: p.action),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: p.action,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PastelSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const PastelSection({super.key, this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title != null) ...[
        Text(title!, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
      ],
      PastelCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    ],
  );
}

class PastelListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback? onTap;
  const PastelListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: leading,
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: subtitle == null
        ? null
        : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
    trailing:
        trailing ??
        (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
  );
}

enum PastelNoticeSeverity { info, success, warning, error }

class PastelNoticeBanner extends StatelessWidget {
  final String message;
  final String? title, actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final bool compact;
  final PastelNoticeSeverity severity;
  const PastelNoticeBanner({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.compact = false,
    this.severity = PastelNoticeSeverity.info,
  });
  @override
  Widget build(BuildContext context) {
    final p = PastelPalette.of(context);
    final tone = switch (severity) {
      PastelNoticeSeverity.error =>
        p.dark ? const Color(0xFFFFA6BB) : const Color(0xFFA52446),
      PastelNoticeSeverity.warning =>
        p.dark ? const Color(0xFFFFD28F) : const Color(0xFF875000),
      PastelNoticeSeverity.success =>
        p.dark ? const Color(0xFF87E5CB) : const Color(0xFF13715A),
      _ => p.action,
    };
    return Semantics(
      liveRegion: severity == PastelNoticeSeverity.error,
      child: PastelCard(
        padding: EdgeInsets.all(compact ? 14 : 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? Icons.info_outline_rounded, color: tone, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                  if (actionLabel != null)
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PastelIllustration extends StatelessWidget {
  final String asset;
  final double size;
  final String? semanticLabel;
  const PastelIllustration({
    super.key,
    required this.asset,
    this.size = 132,
    this.semanticLabel,
  });
  @override
  Widget build(BuildContext context) {
    final p = PastelPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: RadialGradient(colors: [p.soft, p.soft.withValues(alpha: 0)]),
      ),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) =>
            Icon(Icons.smart_toy_outlined, size: size, color: p.action),
      ),
    );
  }
}

class PastelLoadingState extends StatelessWidget {
  final String label;
  const PastelLoadingState({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );
}

class PastelProgressRing extends StatelessWidget {
  final double value, size, strokeWidth;
  final IconData? icon;
  final Widget? child;
  final String? semanticsLabel;
  final bool showValueLabel;
  const PastelProgressRing({
    super.key,
    required this.value,
    this.size = 72,
    this.strokeWidth = 8,
    this.icon,
    this.child,
    this.semanticsLabel,
    this.showValueLabel = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = PastelPalette.of(context);
    return Semantics(
      label: semanticsLabel ?? 'Tiến độ',
      value: '${(value.clamp(0, 1) * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _Ring(value.clamp(0, 1), strokeWidth, p),
          child: Center(
            child:
                child ??
                (icon == null
                    ? null
                    : Icon(icon, size: size * .42, color: p.action)),
          ),
        ),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  final double value, width;
  final PastelPalette palette;
  _Ring(this.value, this.width, this.palette);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = palette.soft;
    canvas.drawOval(rect, paint);
    paint.shader = palette.primary.createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_Ring old) =>
      value != old.value || width != old.width || palette != old.palette;
}

class PastelStatTile extends StatelessWidget {
  final String label, value;
  final String? unit, caption;
  final IconData? icon;
  final bool dense;
  const PastelStatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.icon,
    this.dense = false,
  });
  @override
  Widget build(BuildContext context) => PastelCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: PastelPalette.of(context).action),
          const SizedBox(height: 10),
        ],
        Text(
          '$value${unit == null ? '' : ' $unit'}',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        if (caption != null)
          Text(caption!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class PastelStatRow extends StatelessWidget {
  final List<Widget> children;
  const PastelStatRow({super.key, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 330 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      );
    },
  );
}
