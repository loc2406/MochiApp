import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';

enum MochiNoticeSeverity { info, success, warning, error }

/// Inline message block: pastel background, tone icon, optional action.
/// Errors are announced to screen readers.
class MochiNoticeBanner extends StatelessWidget {
  final String message;
  final String? title;
  final MochiNoticeSeverity severity;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  final bool dismissible;
  final VoidCallback? onDismiss;

  const MochiNoticeBanner({
    super.key,
    required this.message,
    this.title,
    this.severity = MochiNoticeSeverity.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.dismissible = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final (
      Color background,
      Color foreground,
      IconData defaultIcon,
    ) = switch (severity) {
      MochiNoticeSeverity.info => (
        palette.softAccent,
        palette.accent,
        Icons.info_outline_rounded,
      ),
      MochiNoticeSeverity.success => (
        palette.successSoft,
        palette.success,
        Icons.check_circle_outline_rounded,
      ),
      MochiNoticeSeverity.warning => (
        palette.warningSoft,
        palette.warning,
        Icons.warning_amber_rounded,
      ),
      MochiNoticeSeverity.error => (
        palette.dangerSoft,
        palette.danger,
        Icons.error_outline_rounded,
      ),
    };

    return Semantics(
      liveRegion: severity == MochiNoticeSeverity.error,
      container: true,
      child: Container(
        padding: EdgeInsets.all(compact ? MochiSpacing.sm : MochiSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(MochiRadius.control + 4),
          border: Border.all(color: foreground.withValues(alpha: .18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon ?? defaultIcon,
              size: compact ? 18 : 20,
              color: foreground,
            ),
            const SizedBox(width: MochiSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.ink,
                      fontSize: compact ? 12.5 : 13,
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(height: MochiSpacing.xxs),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: foreground,
                        padding: const EdgeInsets.symmetric(
                          horizontal: MochiSpacing.xs,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: theme.textTheme.labelLarge,
                      ),
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
            if (dismissible)
              IconButton(
                tooltip: 'Đóng',
                onPressed: onDismiss,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: palette.muted),
              ),
          ],
        ),
      ),
    );
  }
}
