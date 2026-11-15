import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_button.dart';

/// Confirmation dialog in the Mochi style: rounded card, icon badge, clear
/// primary/destructive action. Keeps the app free of raw AlertDialogs.
class MochiDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;
  final VoidCallback? onConfirm;

  const MochiDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.confirmLabel = 'Đồng ý',
    this.cancelLabel = 'Hủy',
    this.destructive = false,
    this.icon,
    this.onConfirm,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
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
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final tone = destructive ? palette.danger : palette.accent;
    return Dialog(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: MochiRadius.sheetBorder,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(MochiSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: tone, size: 22),
                  ),
                ),
              if (icon != null) const SizedBox(height: MochiSpacing.md),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  color: palette.ink,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: MochiSpacing.xs),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ],
              if (content != null) ...[
                const SizedBox(height: MochiSpacing.md),
                content!,
              ],
              const SizedBox(height: MochiSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: MochiButton(
                      label: cancelLabel,
                      variant: MochiButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: MochiSpacing.sm),
                  Expanded(
                    child: MochiButton(
                      label: confirmLabel,
                      variant: destructive
                          ? MochiButtonVariant.danger
                          : MochiButtonVariant.primary,
                      onPressed: () {
                        onConfirm?.call();
                        Navigator.pop(context, true);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
