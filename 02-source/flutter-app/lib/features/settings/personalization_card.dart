import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../design/mochi_design.dart';
import '../../shared/widgets/note_button.dart';
import 'background_picker.dart';

/// Personalisation block: accent preset, light/dark mode, companion name and
/// tutor voice. Every choice is persisted through [MochiStore.save].
class PersonalizationCard extends StatelessWidget {
  const PersonalizationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    final palette = MochiPalette.of(context);
    final theme = Theme.of(context);
    final preset = store.profile.themePreset;
    final accent = MochiPresets.accentFor(preset);

    return MochiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.softAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: palette.accent,
                  size: MochiIconSize.md,
                ),
              ),
              SizedBox(width: MochiSpacing.sm),
              Expanded(
                child: Text(
                  'Cá nhân hóa không gian học',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              NoteButton(
                note: 'Tùy chỉnh sắc màu chủ đạo của ứng dụng, đặt biệt danh cho người bạn đồng hành và lựa chọn phong cách trả lời của trợ lý học tập theo sở thích riêng của bạn.',
              ),
            ],
          ),
          SizedBox(height: MochiSpacing.lg),
          Text(
            'Sắc màu chủ đạo',
            style: theme.textTheme.labelLarge?.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: MochiSpacing.sm),
          Wrap(
            spacing: MochiSpacing.sm,
            runSpacing: MochiSpacing.sm,
            children: [
              for (final entry in MochiPresets.colors.entries)
                _AccentSwatch(
                  color: entry.value,
                  label: MochiPresets.labelFor(entry.key),
                  selected: preset == entry.key,
                  onTap: () {
                    store.profile.themePreset = entry.key;
                    store.robotColorHex = entry.value.toARGB32();
                    store.save();
                  },
                ),
            ],
          ),
          SizedBox(height: MochiSpacing.lg),
          const BackgroundPicker(),
          const SizedBox(height: MochiSpacing.lg),
          Text(
            'Chế độ hiển thị',
            style: theme.textTheme.labelLarge?.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: MochiSpacing.sm),
          MochiSegmentedControl<String>(
            value: store.profile.themeMode,
            segments: [
              MochiSegment(
                value: 'light',
                label: 'Sáng',
                icon: Icons.light_mode_outlined,
              ),
              MochiSegment(
                value: 'dark',
                label: 'Tối',
                icon: Icons.dark_mode_outlined,
              ),
              MochiSegment(
                value: 'system',
                label: 'Hệ thống',
                icon: Icons.brightness_auto_outlined,
              ),
            ],
            onChanged: (value) {
              store.profile.themeMode = value;
              store.save();
            },
          ),
          SizedBox(height: MochiSpacing.lg),
          Divider(height: 1, color: palette.cardBorder),
          SizedBox(height: MochiSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn đồng hành',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: palette.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      store.profile.robotName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              MochiButton(
                label: 'Đổi tên',
                icon: Icons.edit_outlined,
                size: MochiButtonSize.small,
                variant: MochiButtonVariant.secondary,
                onPressed: () => _renameCompanion(context, store),
              ),
            ],
          ),
          SizedBox(height: MochiSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Phong cách trợ lý học tập',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              NoteButton(
                note: 'Thân thiện: gần gũi, kiên nhẫn. Nghiêm túc: tập trung logic. Truyền cảm hứng: gợi mở ứng dụng thực tế.',
              ),
            ],
          ),
          SizedBox(height: MochiSpacing.sm),
          Wrap(
            spacing: MochiSpacing.xs,
            runSpacing: MochiSpacing.xs,
            children: [
              for (final item in [
                {'id': 'friendly', 'name': 'Thân thiện'},
                {'id': 'strict', 'name': 'Nghiêm túc'},
                {'id': 'inspiring', 'name': 'Truyền cảm hứng'},
              ])
                MochiFilterChip(
                  label: item['name']!,
                  selected: store.profile.tutorPersona == item['id'],
                  onSelected: (selected) {
                    if (!selected) return;
                    store.profile.tutorPersona = item['id']!;
                    store.save();
                  },
                ),
            ],
          ),
          SizedBox(height: MochiSpacing.md),
          Text(
            'Độ sâu giải thích bài tập',
            style: theme.textTheme.labelLarge?.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: MochiSpacing.sm),
          Wrap(
            spacing: MochiSpacing.xs,
            runSpacing: MochiSpacing.xs,
            children: [
              MochiFilterChip(
                label: 'Từng bước chi tiết',
                icon: Icons.format_list_numbered_rounded,
                selected: store.profile.tutorDetailLevel == 'step_by_step',
                onSelected: (selected) {
                  if (!selected) return;
                  store.profile.tutorDetailLevel = 'step_by_step';
                  store.save();
                },
              ),
              MochiFilterChip(
                label: 'Ngắn gọn súc tích',
                icon: Icons.short_text_rounded,
                selected: store.profile.tutorDetailLevel == 'concise',
                onSelected: (selected) {
                  if (!selected) return;
                  store.profile.tutorDetailLevel = 'concise';
                  store.save();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _renameCompanion(BuildContext context, MochiStore store) async {
    final controller = TextEditingController(text: store.profile.robotName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Đặt tên bạn đồng hành'),
        content: MochiTextField(
          controller: controller,
          hint: 'Nhập tên mới (VD: Mochi, Astra...)',
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
          MochiPrimaryButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Lưu'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      store.profile.robotName = newName;
      store.save();
    }
  }
}

class _AccentSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AccentSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: MochiMotion.of(context, MochiMotion.quick),
            curve: MochiMotion.curve,
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? color : Colors.transparent,
                width: 2.2,
              ),
            ),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: .4),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: MochiContrast.on(color),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
