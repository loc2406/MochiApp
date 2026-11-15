import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/services/ai_service.dart';
import 'package:mochi_app/core/services/live_bridge_service.dart';

void main() {
  test('Actual Gemini camera-session exchange produces real study pack', () async {
    final session = LiveSessionImport.parse(File('/home/ben/mochi_delivery/live-bridge/verified-last-exchange.json').readAsStringSync());
    final pack = await AIService().studyPackFromTranscript(session.text);
    expect(pack['cards'], isNotEmpty);
    expect(pack['summary'], isNotEmpty);
    File('/home/ben/mochi_delivery/live-bridge/study-pack-evidence.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(pack));
  }, skip: !const bool.fromEnvironment('LIVE_AI'), timeout: const Timeout(Duration(minutes: 1)));
}
