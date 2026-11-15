import 'dart:async';

import 'package:flutter/material.dart';

import 'database/mochi_store.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'services/smart_reminder_service.dart';

/// Paint the Flutter launch screen first, then initialize real application data.
/// There is no minimum splash duration and animation never controls readiness.
class MochiiBootstrap extends StatefulWidget {
  final Widget Function(MochiStore, Future<void>, String, VoidCallback)
  appBuilder;
  const MochiiBootstrap({super.key, required this.appBuilder});
  @override
  State<MochiiBootstrap> createState() => _MochiiBootstrapState();
}

class _MochiiBootstrapState extends State<MochiiBootstrap> {
  final MochiStore _store = MochiStore();
  late Future<void> _startup;
  String _status = 'Mochii đang chuẩn bị góc học tập…';

  @override
  void initState() {
    super.initState();
    _startup = _initialize();
  }

  Future<void> _initialize() async {
    await NotificationService().init();
    if (mounted) setState(() => _status = 'Đang mở dữ liệu học tập…');
    await _store.init();
    if (!mounted) return;
    unawaited(FCMService().init());
    unawaited(
      SmartReminderService().start(_store).catchError((Object e) {
        debugPrint('Smart reminder initialization failed: $e');
      }),
    );
  }

  void _retry() => setState(() {
    _status = 'Mochii đang thử mở lại ứng dụng…';
    _startup = _initialize();
  });

  @override
  Widget build(BuildContext context) =>
      widget.appBuilder(_store, _startup, _status, _retry);
}
