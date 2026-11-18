import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/mochi_store.dart';
import '../models/mochi_models.dart';
import 'notification_service.dart';
import 'reminder_copy_writer.dart';
import 'smart_reminder_policy.dart';

class SmartReminderService extends ChangeNotifier with WidgetsBindingObserver {
  static final SmartReminderService _instance = SmartReminderService._();
  factory SmartReminderService() => _instance;
  SmartReminderService._();

  static const _prefix = 'mochii_smart_v1_';
  MochiStore? _store;
  SharedPreferences? _prefs;
  Timer? _debounce;
  String _fingerprint = '';
  RobotEmotion? _previousEmotion;
  DateTime? _lastOpened;
  Future<void> _queue = Future<void>.value();
  bool enabled = true;
  bool aiEnabled = true;
  bool preparingCopy = false;
  String copySource = 'rules';
  String? statusError;
  List<PlannedReminder> scheduled = [];

  Future<void> start(MochiStore store) async {
    if (!NotificationService.supported || _store != null) return;
    _store = store;
    _prefs = await SharedPreferences.getInstance();
    enabled = _prefs!.getBool('${_prefix}enabled') ?? true;
    aiEnabled = _prefs!.getBool('${_prefix}ai_enabled') ?? true;
    final now = DateTime.now();
    if (!_prefs!.containsKey('${_prefix}activated')) {
      await _prefs!.setString(
        '${_prefix}activated',
        now.toUtc().toIso8601String(),
      );
    }
    _lastOpened = now;
    await _prefs!.setString(
      '${_prefix}last_opened',
      now.toUtc().toIso8601String(),
    );
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_onStoreChanged);
    _fingerprint = _stateFingerprint();
    await refresh();
  }

  /// Detach observers without deleting OS alarms (also useful for tests).
  Future<void> stop() async {
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _store?.removeListener(_onStoreChanged);
    await _queue;
    _store = null;
    _prefs = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _prefs == null) return;
    _lastOpened = DateTime.now();
    unawaited(
      _prefs!.setString(
        '${_prefix}last_opened',
        _lastOpened!.toUtc().toIso8601String(),
      ),
    );
    unawaited(refresh());
  }

  String _stateFingerprint() {
    final store = _store!;
    return jsonEncode({
      'name': store.profile.name,
      'firstTime': store.isFirstTime,
      'routine': store.dailyRoutine.toJson(),
      'timetable': store.learning.timetable
          .map((lesson) => lesson.toJson())
          .toList(),
      'activePlanId': store.learning.activePlanId,
      'tasks': store.reminderTasks.map((t) => t.toJson()).toList(),
      'sessions': store.sessions
          .map((s) => s.endedAt.toIso8601String())
          .toList(),
    });
  }

  void _onStoreChanged() {
    final store = _store!;
    if (store.robotEmotion == RobotEmotion.focus &&
        _previousEmotion != RobotEmotion.focus) {
      unawaited(
        _prefs!.setString(
          '${_prefix}study_started',
          DateTime.now().toUtc().toIso8601String(),
        ),
      );
      _fingerprint = '';
    }
    _previousEmotion = store.robotEmotion;
    final fingerprint = _stateFingerprint();
    if (fingerprint == _fingerprint) return;
    _fingerprint = fingerprint;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(refresh()),
    );
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    await _prefs?.setBool('${_prefix}enabled', value);
    notifyListeners();
    await refresh();
  }

  Future<void> setAIEnabled(bool value) async {
    aiEnabled = value;
    await _prefs?.setBool('${_prefix}ai_enabled', value);
    notifyListeners();
    await refresh();
  }

  Future<void> refresh({bool forceAI = false}) {
    if (_prefs == null || _store == null) return Future.value();
    if (forceAI) {
      _prefs!.remove('${_prefix}last_attempt');
      _prefs!.remove('${_prefix}copy_at');
    }
    _queue = _queue.then((_) => _reconcile()).catchError((Object e) {
      statusError =
          'Chưa cập nhật được lịch nhắc. Kiểm tra quyền thông báo rồi thử lại.';
      debugPrint('Smart reminder scheduling error: $e');
      notifyListeners();
    });
    return _queue;
  }

  ReminderCopy _cachedCopy() {
    if (!aiEnabled) return ReminderCopy.fallback;
    final raw = _prefs!.getString('${_prefix}copy');
    if (raw == null) return ReminderCopy.fallback;
    try {
      return ReminderCopyWriter.parse(raw);
    } catch (_) {
      return ReminderCopy.fallback;
    }
  }

  List<Map<String, dynamic>> _readRecords(String key) {
    try {
      final value = jsonDecode(_prefs!.getString('$_prefix$key') ?? '[]');
      return (value as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _reconcile() async {
    final now = DateTime.now();
    final old = _readRecords('pending');
    final ledger = _readRecords('ledger');
    final ledgerIds = ledger.map((r) => r['key']).toSet();
    // A past reservation is conservatively counted, even if Doze delayed it.
    // This prevents re-opening the app from resetting the daily anti-spam cap.
    for (final record in old) {
      final when = DateTime.tryParse(record['when']?.toString() ?? '');
      if (when != null && !when.isAfter(now) && ledgerIds.add(record['key'])) {
        ledger.add(record);
      }
    }
    ledger.removeWhere((r) {
      final when = DateTime.tryParse(r['when']?.toString() ?? '');
      return when == null ||
          when.isBefore(now.subtract(const Duration(days: 8)));
    });
    await _prefs!.setString('${_prefix}ledger', jsonEncode(ledger));
    for (final r in [...old, ...ledger]) {
      final when = DateTime.tryParse(r['when']?.toString() ?? '');
      final taskObsolete =
          r['taskId'] != null &&
          !_store!.reminderTasks.any((t) => t.id == r['taskId'] && !t.isDone);
      // Updating cached AI wording must not erase an already displayed alert.
      if (r['id'] is int &&
          (!enabled || taskObsolete || (when != null && when.isAfter(now)))) {
        await NotificationService().cancelReminder(r['id'] as int);
      }
    }
    await _prefs!.setString('${_prefix}pending', '[]');
    scheduled = [];
    if (!enabled ||
        _store!.isFirstTime ||
        !await NotificationService().notificationsEnabled()) {
      statusError = null;
      notifyListeners();
      return;
    }
    if (_prefs!.getBool('${_prefix}migrated_legacy') != true) {
      await NotificationService().cancelLegacyTaskReminders();
      await _prefs!.setBool('${_prefix}migrated_legacy', true);
    }
    var lastStudy = DateTime.parse(_prefs!.getString('${_prefix}activated')!)
        .toLocal();
    // On first activation, existing history is more useful than the install time.
    final knownActivity = [
      ..._store!.sessions
          .where((s) => s.activeSeconds > 0)
          .map((s) => s.endedAt),
      ..._store!.tasks
          .where((t) => t.isDone && t.completedDate != null)
          .map((t) => t.completedDate!),
    ];
    if (knownActivity.isNotEmpty) {
      lastStudy = knownActivity.reduce((a, b) => a.isAfter(b) ? a : b);
    }
    final started = DateTime.tryParse(
      _prefs!.getString('${_prefix}study_started') ?? '',
    );
    if (started != null && started.isAfter(lastStudy)) {
      lastStudy = started.toLocal();
    }
    if (lastStudy.isAfter(now)) lastStudy = now;
    final copy = _cachedCopy();
    copySource = copy.source;
    final plan = const SmartReminderPolicy().plan(
      now: now,
      tasks: _store!.reminderTasks,
      lastAppOpen: _lastOpened ?? now,
      lastStudyActivity: lastStudy,
      learnerName: _store!.profile.name,
      copy: copy,
      pastReservations: ledger
          .where((r) => r['kind'] != 'due')
          .map((r) => DateTime.parse(r['when'] as String).toLocal())
          .toList(),
    );
    final successful = <PlannedReminder>[];
    for (final reminder in plan) {
      await NotificationService().scheduleSmartReminder(reminder);
      successful.add(reminder);
      // Persist incrementally so every scheduled ID can be cancelled after a crash.
      await _prefs!.setString(
        '${_prefix}pending',
        jsonEncode(successful.map((r) => r.toJson()).toList()),
      );
    }
    scheduled = successful;
    statusError = null;
    notifyListeners();
    _maybePrepareCopy();
  }

  void _maybePrepareCopy() {
    if (!enabled || !aiEnabled || preparingCopy) return;
    final now = DateTime.now();
    final cachedAt = DateTime.tryParse(
      _prefs!.getString('${_prefix}copy_at') ?? '',
    );
    if (cachedAt != null &&
        now.difference(cachedAt) < const Duration(days: 1)) {
      return;
    }
    final attempted = DateTime.tryParse(
      _prefs!.getString('${_prefix}last_attempt') ?? '',
    );
    if (attempted != null &&
        now.difference(attempted) < const Duration(hours: 1)) {
      return;
    }
    unawaited(_prepareCopy());
  }

  Future<void> _prepareCopy() async {
    preparingCopy = true;
    await _prefs!.setString(
      '${_prefix}last_attempt',
      DateTime.now().toUtc().toIso8601String(),
    );
    notifyListeners();
    try {
      final copy = await ReminderCopyWriter().generate(_store!.aiService);
      await _prefs!.setString('${_prefix}copy', jsonEncode(copy.templates));
      await _prefs!.setString(
        '${_prefix}copy_at',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      // Existing cached copy, or explicitly labelled rule-based text, still works offline.
    } finally {
      preparingCopy = false;
      notifyListeners();
      unawaited(refresh());
    }
  }
}
