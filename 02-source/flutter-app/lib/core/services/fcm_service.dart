// Firebase Console test sends need the registration token, not the new FID API.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Android's FCM SDK displays background notification payloads itself.
/// Do not display them again here, which would create duplicate notifications.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FCMService extends ChangeNotifier {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void>? _initializing;
  bool _initialized = false;
  bool _connecting = false;
  String? _fcmToken;
  String? _error;
  RemoteMessage? lastOpenedMessage;

  String? get fcmToken => _fcmToken;
  String? get error => _error;
  bool get connecting => _connecting;

  // Retained for the application's lifetime. Install listeners only once.
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Future<void> init() {
    if (!supported || _initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    _connecting = true;
    _error = null;
    notifyListeners();
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 15));
      await NotificationService().init();
      final messaging = FirebaseMessaging.instance;

      // These APIs return the FCM registration token used by Firebase Console's
      // "Send test message". The new onRegistered API returns an FID instead.
      _subscriptions.add(
        messaging.onTokenRefresh.listen(
          _setToken,
          onError: (Object e) => _setError(e),
        ),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) async {
          final notification = message.notification;
          if (notification == null) {
            return; // Data-only payloads are not alerts.
          }
          try {
            await NotificationService().showPushNotification(
              id:
                  (message.messageId ?? notification.hashCode.toString())
                      .hashCode &
                  0x3fffffff,
              title: notification.title,
              body: notification.body,
            );
          } catch (e) {
            debugPrint('Could not display foreground push: $e');
          }
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(_rememberOpenedMessage),
      );
      _initialized = true;
      final initial = await messaging.getInitialMessage();
      if (initial != null) _rememberOpenedMessage(initial);
      await _fetchToken();
    } catch (e) {
      _setError(e);
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<void> refreshToken() async {
    if (!supported) return;
    if (!_initialized) return init();
    if (_connecting) return;
    _connecting = true;
    _error = null;
    notifyListeners();
    try {
      await _fetchToken();
    } catch (e) {
      _setError(e);
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<void> _fetchToken() async {
    // See the API compatibility note above. Never log the device's token.
    final token = await FirebaseMessaging.instance.getToken().timeout(
      const Duration(seconds: 15),
    );
    if (token == null || token.isEmpty) {
      throw StateError('FCM did not return a registration token');
    }
    _setToken(token);
  }

  void _setToken(String token) {
    _fcmToken = token;
    _error = null;
    notifyListeners();
  }

  void _setError(Object error) {
    _error =
        'Chưa kết nối Firebase. Kiểm tra mạng và Google Play Services, '
        'sau đó thử lại.';
    debugPrint('FCM connection error: $error');
    notifyListeners();
  }

  void _rememberOpenedMessage(RemoteMessage message) {
    lastOpenedMessage = message;
    notifyListeners();
  }
}
