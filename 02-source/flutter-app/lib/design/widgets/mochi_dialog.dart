
import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_button.dart';

/// Shared responsive constraints for Mochi dialogs.
class _MochiDialogLayout {
  static const double maxWidth = 560;
  static const double horizontalInset = 20;
  static const double verticalInset = 24;

  static double maxHeight(BuildContext context) {
    final media = MediaQuery.of(context);

    return (media.size.height -
            media.viewInsets.bottom -
            verticalInset * 2)
        .clamp(200.0, media.size.height);
  }

  static const EdgeInsets contentPadding =
      EdgeInsets.all(MochiSpacing.xl);

  static const RoundedRectangleBorder shape =
      RoundedRectangleBorder(
    borderRadius: MochiRadius.sheetBorder,
  );
}

/// Responsive dialog surface for forms and previews.
class MochiFormDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;

  const MochiFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.maxWidth = _MochiDialogLayout.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: _MochiDialogLayout.horizontalInset,
        vertical: _MochiDialogLayout.verticalInset,
      ),
      shape: _MochiDialogLayout.shape,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: _MochiDialogLayout.maxHeight(context),
        ),
        child: Padding(
          padding: _MochiDialogLayout.contentPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  color: palette.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: MochiSpacing.md),

              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: content,
                ),
              ),

              if (actions.isNotEmpty) ...[
                const SizedBox(height: MochiSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: MochiSpacing.sm,
                  runSpacing: MochiSpacing.sm,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog in the Mochi design system.
class MochiDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;

  /// Custom actions replace the default cancel/confirm buttons.
  final List<Widget>? actions;

  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;
  final Color? titleColor;
  final VoidCallback? onConfirm;

  const MochiDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.actions,
    this.confirmLabel = 'Đồng ý',
    this.cancelLabel = 'Hủy',
    this.destructive = false,
    this.icon,
    this.titleColor,
    this.onConfirm,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    Color? titleColor,
    String? message,
    Widget? content,
    String confirmLabel = 'Đồng ý',
    String cancelLabel = 'Hủy',
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => MochiDialog(
        title: title,
        message: message,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        icon: icon,
        titleColor: titleColor,
      ),
    );

    return result ?? false;
  }

  Widget _buildDefaultActions(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 400;

    final cancelButton = MochiButton(
      label: cancelLabel,
      variant: MochiButtonVariant.secondary,
      expand: true,
      onPressed: () => Navigator.pop(context, false),
    );

    final confirmButton = MochiButton(
      label: confirmLabel,
      variant: destructive
          ? MochiButtonVariant.danger
          : MochiButtonVariant.primary,
      expand: true,
      onPressed: () {
        onConfirm?.call();
        Navigator.pop(context, true);
      },
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          confirmButton,
          const SizedBox(height: MochiSpacing.sm),
          cancelButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cancelButton),
        const SizedBox(width: MochiSpacing.sm),
        Expanded(child: confirmButton),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);

    final tone = destructive
        ? palette.danger
        : palette.accent;

    return Dialog(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: _MochiDialogLayout.horizontalInset,
        vertical: _MochiDialogLayout.verticalInset,
      ),
      shape: _MochiDialogLayout.shape,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: _MochiDialogLayout.maxHeight(context),
        ),
        child: Padding(
          padding: _MochiDialogLayout.contentPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: tone,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: MochiSpacing.md),
              ],

              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  color: titleColor ?? palette.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),

              if (message != null) ...[
                const SizedBox(height: MochiSpacing.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ],

              if (content != null) ...[
                const SizedBox(height: MochiSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: content!,
                  ),
                ),
              ],

              const SizedBox(height: MochiSpacing.lg),

              if (actions != null)
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: MochiSpacing.sm,
                  runSpacing: MochiSpacing.sm,
                  children: actions!,
                )
              else
                _buildDefaultActions(context),
            ],
          ),
        ),
      ),
    );
  }
}
