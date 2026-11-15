import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/services/cloud_sync_service.dart';
import 'package:mochi_app/core/services/account_state_merge.dart';

Map<String, dynamic> copy(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));

class FakeCloud extends CloudSyncService {
  Map<String, dynamic>? state;
  int revision = 1;
  bool offline = false;
  Completer<void>? gate;
  Completer<void>? entered;
  FakeCloud({Map<String, dynamic>? initial})
    : state =
          initial ??
          {
            'profile': {'name': 'Canonical', 'robotName': 'Buddy'},
            'stars': 0,
            'xp': 0,
          } {
    currentUserId = 'account-one';
  }
  @override
  bool get hasActiveUser => currentUserId != null;
  @override
  Future<bool> initialize({String? url, String? anonKey}) async => true;
  @override
  Future<Map<String, dynamic>?> fetchAccountState() async {
    if (offline) throw StateError('offline');
    return state == null ? null : {'state': copy(state!), 'revision': revision};
  }

  @override
  Future<int> saveAccountState(Map<String, dynamic> value, int expected) async {
    if (offline) throw StateError('offline');
    entered?.complete();
    entered = null;
    if (gate != null) {
      final wait = gate!;
      gate = null;
      await wait.future;
    }
    if (state != null && expected != revision)
      throw StateError('sync_conflict');
    state = copy(value);
    return ++revision;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('merge preserves separate task edits, additions and deletions', () {
    final base = {
      'tasks': [
        {'id': 'a', 'title': 'A'},
        {'id': 'b', 'title': 'B'},
      ],
    };
    final local = {
      'tasks': [
        {'id': 'a', 'title': 'A changed'},
      ],
    };
    final remote = {
      'tasks': [
        {'id': 'a', 'title': 'A'},
        {'id': 'b', 'title': 'B'},
        {'id': 'c', 'title': 'C'},
      ],
    };
    expect(mergeAccountState(base, local, remote), {
      'tasks': [
        {'id': 'a', 'title': 'A changed'},
        {'id': 'c', 'title': 'C'},
      ],
    });
  });
  test('same field conflict is not silently overwritten', () {
    expect(
      () => mergeAccountState({'name': 'A'}, {'name': 'B'}, {'name': 'C'}),
      throwsA(isA<AccountStateConflict>()),
    );
  });
  test(
    'new authenticated account gets empty database state, not guest profile',
    () async {
      final cloud = FakeCloud()..state = null;
      final store = MochiStore(cloudService: cloud);
      store.profile.name = 'Previous guest';
      await store.refreshCloudAuth();
      expect(cloud.state!['profile']['name'], '');
      expect(store.profile.name, '');
      expect(store.isCloudSynced, true);
      store.dispose();
    },
  );
  test(
    'edit during network write is not marked clean or overwritten by polling',
    () async {
      final cloud = FakeCloud();
      final store = MochiStore(cloudService: cloud);
      await store.init();
      final gate = Completer<void>(), entered = Completer<void>();
      cloud.gate = gate;
      cloud.entered = entered;
      store.profile.name = 'Changed';
      final first = store.save();
      await entered.future;
      store.profile.robotName = 'New buddy';
      final second = store.save();
      expect(store.isCloudSynced, false);
      gate.complete();
      await first;
      await second;
      expect(cloud.state!['profile']['name'], 'Changed');
      expect(cloud.state!['profile']['robotName'], 'New buddy');
      expect(store.isCloudSynced, true);
      store.dispose();
    },
  );
  test(
    'offline outbox survives restart and merges a different device edit',
    () async {
      final cloud = FakeCloud();
      var store = MochiStore(cloudService: cloud);
      await store.init();
      cloud.offline = true;
      store.profile.name = 'Offline name';
      await store.save();
      expect(store.isCloudSynced, false);
      store.dispose();
      store = MochiStore(cloudService: cloud);
      await store.init();
      expect(store.profile.name, 'Offline name');
      cloud.offline = false;
      cloud.state!['profile']['robotName'] = 'Remote buddy';
      cloud.revision++;
      await store.retryCloudSync();
      expect(cloud.state!['profile']['name'], 'Offline name');
      expect(cloud.state!['profile']['robotName'], 'Remote buddy');
      expect(store.profile.robotName, 'Remote buddy');
      expect(store.isCloudSynced, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('mochi_account_outbox_account-one'), false);
      store.dispose();
    },
  );
  test('switch account offline never displays previous identity', () async {
    final cloud = FakeCloud();
    final store = MochiStore(cloudService: cloud);
    await store.init();
    cloud.currentUserId = 'different-account';
    cloud.offline = true;
    await store.refreshCloudAuth();
    expect(store.profile.name, '');
    expect(store.isCloudSynced, false);
    store.dispose();
  });

  test('logout does not leave previous account data visible', () async {
    final cloud = FakeCloud();
    final store = MochiStore(cloudService: cloud);
    await store.init();
    cloud.currentUserId = null;
    await store.refreshCloudAuth();
    expect(store.profile.name, '');
    expect(store.tasks, isEmpty);
    expect(store.stars, 0);
    store.dispose();
  });
}
