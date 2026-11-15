import '../../design/mochi_design.dart';

import 'package:flutter/material.dart';

import '../../core/app_release_info.dart';

class AppVersionCaption extends StatefulWidget {
  const AppVersionCaption({super.key});
  @override
  State<AppVersionCaption> createState() => _AppVersionCaptionState();
}

class _AppVersionCaptionState extends State<AppVersionCaption> {
  late final Future<AppReleaseInfo> _release = AppReleaseInfo.read();
  @override
  Widget build(BuildContext context) => FutureBuilder<AppReleaseInfo>(
    future: _release,
    builder: (context, snapshot) => Text(
      '${snapshot.data?.label ?? "Đang đọc phiên bản…"}\nTrợ lý robot thông minh đồng hành cùng học sinh mỗi ngày.',
      style: TextStyle(
        fontSize: 12,
        color: MochiPalette.of(context).muted,
        height: 1.5,
      ),
    ),
  );
}
