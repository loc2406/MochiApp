import 'package:flutter/material.dart';

/// Explanatory copy is available on demand, without occupying the reading area.
class NoteButton extends StatelessWidget {
  final String note;
  const NoteButton({super.key, required this.note});

  @override
  Widget build(BuildContext context) => PopupMenuButton<void>(
    tooltip: 'Xem chú thích',
    icon: const Icon(Icons.info_outline, size: 20),
    constraints: const BoxConstraints(minWidth: 180, maxWidth: 300),
    itemBuilder: (_) => [
      PopupMenuItem<void>(
        enabled: false,
        child: Text(note, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      ),
    ],
  );
}
