import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/models/student_share_sections.dart';
import 'package:mochi_app/features/settings/student_sharing_permissions_screen.dart';

void main() {
  testWidgets('renders every share section and toggles the selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentSharingPermissionsScreen(
          viewerId: 'viewer-1',
          email: 'phuhuynh@example.com',
          role: 'parent',
          initialSections: StudentShareSections.all,
        ),
      ),
    );

    expect(find.text('Quyền xem thông tin'), findsOneWidget);
    expect(find.text('Hồ sơ học sinh'), findsOneWidget);
    expect(find.text('Môn học & chủ đề'), findsOneWidget);
    expect(find.text('Hoạt động gần đây'), findsOneWidget);
    expect(find.text('8/8'), findsOneWidget);

    await tester.tap(find.text('Điểm XP'));
    await tester.pump();

    expect(find.text('7/8'), findsOneWidget);

    await tester.tap(find.text('Chọn tất cả'));
    await tester.pump();

    expect(find.text('8/8'), findsOneWidget);

    await tester.tap(find.text('Bỏ chọn tất cả'));
    await tester.pump();

    expect(find.text('0/8'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('học sinh chưa chia sẻ thông tin nào'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('học sinh chưa chia sẻ thông tin nào'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
