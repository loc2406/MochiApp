import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/shared/widgets/reminder_alarm_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const localChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final calls = <MethodCall>[];
  var notificationsEnabled = true;
  var exactEnabled = false;

  setUpAll(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(localChannel, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'areNotificationsEnabled':
          return notificationsEnabled;
        case 'canScheduleExactNotifications':
          return exactEnabled;
        case 'requestExactAlarmsPermission':
          exactEnabled = true;
          return true;
        case 'pendingNotificationRequests':
          return <Map<String, dynamic>>[];
        default:
          return null;
      }
    });
  });

  setUp(() {
    calls.clear();
    notificationsEnabled = true;
    exactEnabled = false;
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      localChannel,
      null,
    ),
  );

  Future<void> pumpPrompt(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => offerExactAlarmsForTimedTasks(context),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('timed tasks ask for exact alarms at most once', (tester) async {
    await pumpPrompt(tester);
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Nhắc đúng giờ hơn'), findsOneWidget);
    expect(find.textContaining('Báo thức và lời nhắc'), findsOneWidget);

    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('mochi_exact_alarm_prompted_v1'), isTrue);

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Nhắc đúng giờ hơn'), findsNothing);
  });

  testWidgets('granting opens Android exact-alarm settings', (tester) async {
    await pumpPrompt(tester);
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cho phép'));
    await tester.pumpAndSettle();
    expect(exactEnabled, isTrue);
    expect(
      calls.any((c) => c.method == 'requestExactAlarmsPermission'),
      isTrue,
    );
  });

  testWidgets('never prompts while notifications are still off', (
    tester,
  ) async {
    notificationsEnabled = false;
    await pumpPrompt(tester);
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Nhắc đúng giờ hơn'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('mochi_exact_alarm_prompted_v1'), isNull);
  });
}
