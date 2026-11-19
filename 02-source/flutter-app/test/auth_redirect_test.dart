import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/services/cloud_sync_service.dart';

void main() {
  test('confirmation link uses the app custom scheme', () {
    final redirect = CloudSyncService.emailRedirectTo;
    expect(redirect, 'mochiapp://auth-callback');

    final uri = Uri.parse(redirect);
    expect(uri.scheme, CloudSyncService.authCallbackScheme);
    expect(uri.host, CloudSyncService.authCallbackHost);
  });

  test('Android manifest accepts the confirmation deep link', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:scheme="mochiapp"'));
    expect(manifest, contains('android:host="auth-callback"'));
    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
  });
}
