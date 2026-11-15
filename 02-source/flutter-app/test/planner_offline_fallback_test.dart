import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:mochi_app/core/services/ai_service.dart';

void main() {
  test(
    'AI failure falls back to a labelled offline plan within constraints',
    () async {
      final service = AIService(
        client: MockClient((_) async => http.Response('upstream down', 503)),
      );

      final drafts = await service.breakDownGoalIntoTasks(
        goalTitle: 'Ôn thi học kỳ',
        subject: 'Vật lý',
        totalDays: 14,
        dailyMinutes: 60,
        freeTimeStart: '19:30',
        freeTimeEnd: '21:30',
      );

      expect(drafts, isNotEmpty);
      expect(drafts.length, lessThanOrEqualTo(5));
      expect(drafts.every((d) => d['source'] == 'offline_template'), isTrue);
      expect(drafts.every((d) => d['subject'] == 'Vật lý'), isTrue);
      expect(drafts.every((d) => (d['durationMinutes'] as int) <= 60), isTrue);
      expect(
        drafts.every(
          (d) => (d['scheduledDate'] as String?)?.isNotEmpty == true,
        ),
        isTrue,
      );
      expect(
        drafts.every(
          (d) => (d['scheduledTime'] as String?)?.isNotEmpty == true,
        ),
        isTrue,
      );
    },
  );

  test('offline fallback shrinks to one task for a one-day horizon', () async {
    // Lịch bắt đầu từ hôm nay nên khung giờ phải tính từ lúc chạy test; nếu đã
    // quá muộn trong ngày thì không thể xếp một task 30 phút một cách hợp lệ.
    final now = DateTime.now();
    final remainingMinutes = 24 * 60 - (now.hour * 60 + now.minute);
    if (remainingMinutes < 35) {
      markTestSkipped(
        'Không còn đủ 35 phút trong ngày để kiểm tra kế hoạch 1 ngày.',
      );
      return;
    }
    String clock(int minutes) =>
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
    final start = now.hour * 60 + now.minute + 1;

    final service = AIService(
      client: MockClient((_) async => http.Response('upstream down', 503)),
    );

    final drafts = await service.breakDownGoalIntoTasks(
      goalTitle: 'Ôn nhanh',
      subject: 'Hóa học',
      totalDays: 1,
      dailyMinutes: 30,
      freeTimeStart: clock(start),
      freeTimeEnd: '23:59',
    );

    expect(drafts, hasLength(1));
    expect(drafts.single['source'], 'offline_template');
  });

  test('offline fallback reports when no free time can hold the plan', () async {
    final service = AIService(
      client: MockClient((_) async => http.Response('upstream down', 503)),
    );
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await expectLater(
      service.breakDownGoalIntoTasks(
        goalTitle: 'Không còn giờ',
        subject: 'Toán',
        totalDays: 1,
        dailyMinutes: 30,
        routine: DailyRoutine(
          preferredDailyMinutes: 30,
          dateFree: {todayKey: const []},
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
