import '../../design/mochi_design.dart';

import 'package:flutter/material.dart';

import '../../core/app_release_info.dart';

class AppVersionCaption extends StatefulWidget {
  const AppVersionCaption({super.key});
  @override
  State<AppVersionCaption> createState() => _AppVersionCaptionState();
}

class _AppVersionCaptionState extends State<AppVersionCaption> {
  @override
  Widget build(BuildContext context) => Text(
    'Trợ lý robot thông minh đồng hành cùng học sinh mỗi ngày.',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 12,
      color: MochiPalette.of(context).muted,
      height: 1.5,
    ),
  );
}
