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
      ],
    );
  }
}
