/// Durable learning data. Self-reported progress is deliberately not a grade.
enum TopicReadiness { unknown, notStudied, needsReview, confident }

class LearningTopic {
  final String id, title, sourceRef;
  final List<String> prerequisites;
  const LearningTopic({
    required this.id,
    required this.title,
    required this.sourceRef,
    this.prerequisites = const [],
  });
  factory LearningTopic.fromJson(Map<String, dynamic> j) => LearningTopic(
    id: j['id'],
    title: j['title'],
    sourceRef: j['sourceRef'] ?? '',
    prerequisites: List<String>.from(j['prerequisites'] ?? []),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sourceRef': sourceRef,
    'prerequisites': prerequisites,
  };
}

class LearningCourse {
  final String id, subject, textbook, sourceLabel;
  final List<LearningTopic> topics;
  const LearningCourse({
    required this.id,
    required this.subject,
    this.textbook = '',
    this.sourceLabel = '',
    this.topics = const [],
  });
  factory LearningCourse.fromJson(Map<String, dynamic> j) => LearningCourse(
    id: j['id'],
    subject: j['subject'],
    textbook: j['textbook'] ?? '',
    sourceLabel: j['sourceLabel'] ?? '',
    topics: (j['topics'] as List? ?? [])
        .map((x) => LearningTopic.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'textbook': textbook,
    'sourceLabel': sourceLabel,
    'topics': topics.map((x) => x.toJson()).toList(),
  };
}

class TopicProgress {
  final String id, courseId, topicId;
  final TopicReadiness readiness;
  final DateTime updatedAt;
  const TopicProgress({
    required this.id,
    required this.courseId,
    required this.topicId,
    required this.readiness,
    required this.updatedAt,
  });
  factory TopicProgress.fromJson(Map<String, dynamic> j) => TopicProgress(
    id: j['id'],
    courseId: j['courseId'],
    topicId: j['topicId'],
    readiness: TopicReadiness.values.firstWhere(
      (x) => x.name == j['readiness'],
      orElse: () => TopicReadiness.unknown,
    ),
    updatedAt: DateTime.parse(j['updatedAt']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'courseId': courseId,
    'topicId': topicId,
    'readiness': readiness.name,
    'updatedAt': updatedAt.toIso8601String(),
    'evidenceType': 'self_report',
  };
}

class SchoolLesson {
  final String id, subject, title, startTime, endTime;
  final int weekday;
  final String? effectiveFrom, effectiveTo, specificDate, parityAnchor;

  /// all/even/odd, relative to the explicitly chosen anchor Monday.
  final String weekPattern;
  const SchoolLesson({
    required this.id,
    required this.subject,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    this.title = '',
    this.effectiveFrom,
    this.effectiveTo,
    this.specificDate,
    this.weekPattern = 'all',
    this.parityAnchor,
  });
  bool occursOn(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    DateTime? parse(String? x) => x == null ? null : DateTime.tryParse(x);
    final from = parse(effectiveFrom), to = parse(effectiveTo);
    if (from != null && date.isBefore(from) || to != null && date.isAfter(to))
      return false;
    if (specificDate != null) return specificDate == learningDateKey(date);
    if (date.weekday != weekday) return false;
    if (weekPattern == 'all') return true;
    final anchor = parse(parityAnchor);
    if (anchor == null)
      throw StateError('Lịch tuần chẵn/lẻ cần chọn tuần bắt đầu.');
    final monday = DateTime(date.year, date.month, date.day - date.weekday + 1);
    final anchorMonday = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - anchor.weekday + 1,
    );
    final weeks = (monday.toUtc().difference(anchorMonday.toUtc()).inDays / 7)
        .round();
    return weekPattern == 'even' ? weeks.isEven : weeks.isOdd;
  }

  factory SchoolLesson.fromJson(Map<String, dynamic> j) => SchoolLesson(
    id: j['id'],
    subject: j['subject'],
    title: j['title'] ?? '',
    weekday: j['weekday'],
    startTime: j['startTime'],
    endTime: j['endTime'],
    effectiveFrom: j['effectiveFrom'],
    effectiveTo: j['effectiveTo'],
    specificDate: j['specificDate'],
    weekPattern: j['weekPattern'] ?? 'all',
    parityAnchor: j['parityAnchor'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'title': title,
    'weekday': weekday,
    'startTime': startTime,
    'endTime': endTime,
    'effectiveFrom': effectiveFrom,
    'effectiveTo': effectiveTo,
    'specificDate': specificDate,
    'weekPattern': weekPattern,
    'parityAnchor': parityAnchor,
  };
}

String learningDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String learningClock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

class LearningBlock {
  final String id, taskId, title, subject, date, startTime, reason;
  final int minutes, part;
  const LearningBlock({
    required this.id,
    required this.taskId,
    required this.title,
    required this.subject,
    required this.date,
    required this.startTime,
    required this.minutes,
    required this.part,
    required this.reason,
  });
  factory LearningBlock.fromJson(Map<String, dynamic> j) => LearningBlock(
    id: j['id'],
    taskId: j['taskId'],
    title: j['title'],
    subject: j['subject'],
    date: j['date'],
    startTime: j['startTime'],
    minutes: j['minutes'],
    part: j['part'],
    reason: j['reason'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'title': title,
    'subject': subject,
    'date': date,
    'startTime': startTime,
    'minutes': minutes,
    'part': part,
    'reason': reason,
  };
}

class LearningDeferral {
  final String id, taskId, reason;
  final int remainingMinutes;
  const LearningDeferral({
    required this.taskId,
    required this.reason,
    required this.remainingMinutes,
  }) : id = taskId;
  factory LearningDeferral.fromJson(Map<String, dynamic> j) => LearningDeferral(
    taskId: j['taskId'],
    reason: j['reason'],
    remainingMinutes: j['remainingMinutes'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'reason': reason,
    'remainingMinutes': remainingMinutes,
  };
}

class UnifiedStudyPlan {
  final String id, contextSignature;
  final DateTime createdAt;
  final List<LearningBlock> blocks;
  final List<LearningDeferral> deferred;
  const UnifiedStudyPlan({
    required this.id,
    required this.contextSignature,
    required this.createdAt,
    required this.blocks,
    required this.deferred,
  });
  factory UnifiedStudyPlan.fromJson(Map<String, dynamic> j) => UnifiedStudyPlan(
    id: j['id'],
    contextSignature: j['contextSignature'],
    createdAt: DateTime.parse(j['createdAt']),
    blocks: (j['blocks'] as List? ?? [])
        .map((x) => LearningBlock.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    deferred: (j['deferred'] as List? ?? [])
        .map((x) => LearningDeferral.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'contextSignature': contextSignature,
    'createdAt': createdAt.toIso8601String(),
    'blocks': blocks.map((x) => x.toJson()).toList(),
    'deferred': deferred.map((x) => x.toJson()).toList(),
  };
}

class LearningState {
  int? gradeLevel;
  String academicYear, activePlanId;
  List<LearningCourse> courses;
  List<TopicProgress> progress;
  List<SchoolLesson> timetable;
  List<UnifiedStudyPlan> plans;
  List<Map<String, dynamic>> studyEvents;
  List<Map<String, dynamic>> reviewSessions;
  LearningState({
    this.gradeLevel,
    this.academicYear = '',
    this.activePlanId = '',
    List<LearningCourse>? courses,
    List<TopicProgress>? progress,
    List<SchoolLesson>? timetable,
    List<UnifiedStudyPlan>? plans,
    List<Map<String, dynamic>>? studyEvents,
    List<Map<String, dynamic>>? reviewSessions,
  }) : courses = courses ?? [],
       progress = progress ?? [],
       timetable = timetable ?? [],
       plans = plans ?? [],
       studyEvents = studyEvents ?? [],
       reviewSessions = reviewSessions ?? [];
  int completedMinutesForTask(String taskId) => studyEvents
      .where((e) => e['taskId'] == taskId)
      .fold<int>(0, (n, e) => n + (e['minutes'] as num).toInt());
  int completedMinutesForBlock(String blockId) => studyEvents
      .where((e) => e['blockId'] == blockId)
      .fold<int>(0, (n, e) => n + (e['minutes'] as num).toInt());
  TopicReadiness readinessFor(String topicId) =>
      progress.where((x) => x.topicId == topicId).firstOrNull?.readiness ??
      TopicReadiness.unknown;
  UnifiedStudyPlan? get activePlan =>
      plans.where((p) => p.id == activePlanId).firstOrNull;
  factory LearningState.fromJson(Map<String, dynamic> j) => LearningState(
    gradeLevel: j['gradeLevel'],
    academicYear: j['academicYear'] ?? '',
    activePlanId: j['activePlanId'] ?? '',
    courses: (j['courses'] as List? ?? [])
        .map((x) => LearningCourse.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    progress: (j['progress'] as List? ?? [])
        .map((x) => TopicProgress.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    timetable: (j['timetable'] as List? ?? [])
        .map((x) => SchoolLesson.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    studyEvents: (j['studyEvents'] as List? ?? [])
        .map((x) => Map<String, dynamic>.from(x))
        .toList(),
    reviewSessions: (j['reviewSessions'] as List? ?? [])
        .map((x) => Map<String, dynamic>.from(x))
        .toList(),
    plans: (j['plans'] as List? ?? [])
        .map((x) => UnifiedStudyPlan.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'studyEvents': studyEvents,
    'reviewSessions': reviewSessions,
    'gradeLevel': gradeLevel,
    'academicYear': academicYear,
    'courses': courses.map((x) => x.toJson()).toList(),
    'progress': progress.map((x) => x.toJson()).toList(),
    'timetable': timetable.map((x) => x.toJson()).toList(),
    'plans': plans.map((x) => x.toJson()).toList(),
    'activePlanId': activePlanId,
  };
}
