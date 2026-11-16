import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../design/mochi_design.dart';

/// The application-wide background setting, stored with the user's profile.
class BackgroundPicker extends StatelessWidget {
  const BackgroundPicker({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    final p = PastelPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Màu nền & gradient',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: p.muted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Áp dụng cho toàn bộ ứng dụng, độc lập với màu chủ đạo.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in PastelBackgrounds.labels.entries)
              Semantics(
                selected: store.profile.backgroundPreset == entry.key,
                button: true,
                child: SizedBox(
                  width: 140,
                  child: Material(
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: PastelBackgrounds.colors(entry.key, p.dark),
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: store.profile.backgroundPreset == entry.key
                              ? p.action
                              : p.border,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        key: ValueKey('background-${entry.key}'),
                        onTap: () {
                          store.profile.backgroundPreset = entry.key;
                          store.save();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    color: p.ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (store.profile.backgroundPreset == entry.key)
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: p.action,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Chọn ảnh nền',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: p.muted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _BackgroundImageOption(
              number: 1,
              assetPath: 'assets/bg/bg-01.jpg',
              selected: store.profile.backgroundPreset == 'image-1',
              onTap: () {
                store.profile.backgroundPreset = 'image-1';
                store.save();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _BackgroundImageOption extends StatelessWidget {
  final int number;
  final String assetPath;
  final bool selected;
  final VoidCallback onTap;

  const _BackgroundImageOption({
    required this.number,
    required this.assetPath,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PastelPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: 'Ảnh nền $number',
      child: SizedBox(
        width: 140,
        height: 88,
        child: Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            key: ValueKey('background-image-$number'),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(assetPath),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? p.action : p.border,
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.black.withValues(alpha: 0.58),
                      child: Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Icon(
                        Icons.check_circle,
                        size: 20,
                        color: p.action,
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
