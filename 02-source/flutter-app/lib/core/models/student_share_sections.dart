/// Keys describing which parts of a student's data are shared with a viewer.
///
/// Keep these values in sync with the allow-list in
/// `supabase/migrations/20261118_student_viewer_sections.sql`.
abstract final class StudentShareSections {
  static const profile = 'profile';
  static const xp = 'xp';
  static const streak = 'streak';
  static const studyMinutes = 'studyMinutes';
  static const goals = 'goals';
  static const courses = 'courses';
  static const progress = 'progress';
  static const recentStudy = 'recentStudy';

  /// Canonical order used when saving and when listing checkboxes.
  static const all = <String>[
    profile,
    xp,
    streak,
    studyMinutes,
    goals,
    courses,
    progress,
    recentStudy,
  ];

  /// Reads the `sharedSections` field returned by the RPC.
  ///
  /// A missing field means the grant predates section permissions, so every
  /// section stays enabled for backwards compatibility. An explicit empty list
  /// means the student deliberately shares nothing.
  static Set<String> parse(dynamic value) {
    if (value is! List) return {...all};
    return value.whereType<String>().where(all.contains).toSet();
  }
}
