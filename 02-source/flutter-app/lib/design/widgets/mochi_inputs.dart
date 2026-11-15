import 'package:flutter/material.dart';

import '../foundation/mochi_palette.dart';
import '../foundation/mochi_tokens.dart';
import 'mochi_haptics.dart';

/// Text input matching the design language: filled soft surface, 18 radius,
/// accent focus ring and no hard outline.
class MochiTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final int maxLines;
  final int minLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool autofocus;
  final bool enabled;

  const MochiTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.maxLines = 1,
    this.minLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffix,
    this.autofocus = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final field = TextField(
      controller: controller,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? 1 : minLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      enabled: enabled,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: palette.ink),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: MochiIconSize.sm, color: palette.muted),
        suffixIcon: suffix,
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: MochiSpacing.xxs,
            bottom: MochiSpacing.xxs,
          ),
          child: Text(
            label!,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: palette.ink, fontWeight: FontWeight.w700),
          ),
        ),
        field,
      ],
    );
  }
}

/// Dropdown input sharing the filled surface and rounded focus border of
/// [MochiTextField].
class MochiDropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;

  const MochiDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(18);
    final mochiItems = items
        .map(
          (item) => DropdownMenuItem<T>(
            key: item.key,
            value: item.value,
            enabled: item.enabled,
            alignment: item.alignment,
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodyMedium!.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w500,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: palette.accent),
                child: item.child,
              ),
            ),
          ),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: MochiSpacing.xxs,
            bottom: MochiSpacing.xxs,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: mochiItems,
          onChanged: onChanged,
          isExpanded: isExpanded,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: palette.muted),
          dropdownColor: palette.card,
          borderRadius: BorderRadius.circular(16),
          style: theme.textTheme.bodyMedium?.copyWith(color: palette.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.cardSoft,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MochiSpacing.md,
              vertical: MochiSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: palette.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: palette.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: palette.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: MochiSpacing.sm),
      ],
    );
  }
}

/// Search variant with a leading magnifier and an optional clear button.
class MochiSearchField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const MochiSearchField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<MochiSearchField> createState() => _MochiSearchFieldState();
}

class _MochiSearchFieldState extends State<MochiSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    return MochiTextField(
      controller: _controller,
      label: widget.label,
      hint: widget.hint ?? 'Tìm kiếm',
      prefixIcon: Icons.search_rounded,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        widget.onChanged?.call(value);
        setState(() {});
      },
      onSubmitted: widget.onSubmitted,
      suffix: _controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Xoá tìm kiếm',
              onPressed: () {
                _controller.clear();
                widget.onChanged?.call('');
                setState(() {});
              },
              icon: Icon(Icons.close_rounded, size: 18, color: palette.muted),
            ),
    );
  }
}

/// Selectable filter pill. Selected state uses the accent gradient.
class MochiFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  const MochiFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final foreground = selected ? palette.onAccent : palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: MochiMotion.of(context, MochiMotion.quick),
        decoration: BoxDecoration(
          gradient: selected ? palette.primaryGradient : null,
          color: selected ? null : palette.card,
          borderRadius: MochiRadius.pillBorder,
          border: Border.all(
            color: selected ? Colors.transparent : palette.cardBorder,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onSelected == null
                ? null
                : () {
                    MochiHaptics.tap(context);
                    onSelected!(!selected);
                  },
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MochiSpacing.md,
                vertical: 9,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: foreground),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: foreground, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
