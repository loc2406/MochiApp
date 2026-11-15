import 'package:flutter_test/flutter_test.dart';
import 'package:mochi_app/core/database/mochi_store.dart';
import 'package:mochi_app/core/models/mochi_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('goal subject persists and legacy goals default to Chung', () {
    final goal = GoalModel(
      id: 'goal_1',
      title: 'Ôn thi',
      targetDate: DateTime(2027, 1, 10),
      subject: 'Hóa học',
    );
    final restored = GoalModel.fromJson(goal.toJson());
    expect(restored.subject, 'Hóa học');

    final legacy = GoalModel.fromJson({
      'id': 'goal_old',
      'title': 'Mục tiêu cũ',
      'targetDate': '2027-01-10T00:00:00.000',
    });
    expect(legacy.subject, 'Chung');
  });

  test('deleting a goal removes only its linked tasks', () async {
    SharedPreferences.setMockInitialValues({});
    final store = MochiStore();
    store.addGoal('Mục tiêu A', DateTime(2027, 1, 10), subject: 'Toán');
    final goalId = store.goals.single.id;
    store.addTask(title: 'Việc 1', goalId: goalId);
    store.addTask(title: 'Việc 2', goalId: goalId);
    store.addTask(title: 'Việc không liên kết');
    await store.save();

    store.deleteGoal(goalId);
    await store.save();

    expect(store.goals, isEmpty);
    expect(store.tasks.map((t) => t.title), ['Việc không liên kết']);
  });
}
