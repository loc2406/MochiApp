enum RobotEmotion {
  idle,
  focus,
  listening,
  thinking,
  happy,
  celebrate,
  sleeping,
}

enum TaskStatus { pending, inProgress, completed, archived }

enum PomodoroPhase { focus, shortBreak, longBreak }

class ProfileModel {
  String name;
  String gender; // male, female, neutral
  String gradeBand; // THCS, THPT, Đại học, Tự học
  String school;
  String mainGoal;
  String robotName;
  ColorThemeModel colorTheme;
  String themePreset;
  String themeMode;
  String backgroundPreset;
  double glassOpacity;
  bool hapticEnabled;
  bool reducedMotion;
  bool highContrast;
  String robotAvatar;
  String tutorPersona;
  String tutorDetailLevel;
  String focusPresence;

  ProfileModel({
    required this.name,
    this.gender = 'neutral',
    this.gradeBand = 'THCS',
    this.school = '',
    this.mainGoal = '',
    this.robotName = 'Mochi',
    ColorThemeModel? colorTheme,
    this.themePreset = 'oceanCyan',
    this.themeMode = 'light',
    this.backgroundPreset = 'lavender',
    this.glassOpacity = 0.85,
    this.hapticEnabled = true,
    this.reducedMotion = false,
    this.highContrast = false,
    this.robotAvatar = 'happy',
    this.tutorPersona = 'friendly',
    this.tutorDetailLevel = 'step_by_step',
    this.focusPresence = 'normal',
  }) : colorTheme = colorTheme ?? ColorThemeModel();

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      name: json['name'] ?? '',
      gender: json['gender'] ?? 'neutral',
      gradeBand: json['gradeBand'] ?? json['className'] ?? 'THCS',
      school: json['school'] ?? '',
      mainGoal: json['mainGoal'] ?? '',
      robotName: json['robotName'] ?? 'Mochi',
      colorTheme: json['colorTheme'] != null
          ? ColorThemeModel.fromJson(json['colorTheme'])
          : ColorThemeModel(),
      themePreset: json['themePreset']?.toString() ?? 'oceanCyan',
      themeMode: json['themeMode']?.toString() ?? 'light',
      backgroundPreset: json['backgroundPreset']?.toString() ?? 'lavender',
      glassOpacity: (json['glassOpacity'] as num?)?.toDouble() ?? 0.85,
      hapticEnabled: json['hapticEnabled'] != false,
      reducedMotion: json['reducedMotion'] == true,
      highContrast: json['highContrast'] == true,
      robotAvatar: json['robotAvatar']?.toString() ?? 'happy',
      tutorPersona: json['tutorPersona']?.toString() ?? 'friendly',
      tutorDetailLevel: json['tutorDetailLevel']?.toString() ?? 'step_by_step',
      focusPresence: json['focusPresence']?.toString() ?? 'normal',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'gradeBand': gradeBand,
    'school': school,
    'mainGoal': mainGoal,
    'robotName': robotName,
    'colorTheme': colorTheme.toJson(),
    'themePreset': themePreset,
    'themeMode': themeMode,
    'backgroundPreset': backgroundPreset,
    'glassOpacity': glassOpacity,
    'hapticEnabled': hapticEnabled,
    'reducedMotion': reducedMotion,
    'highContrast': highContrast,
    'robotAvatar': robotAvatar,
    'tutorPersona': tutorPersona,
    'tutorDetailLevel': tutorDetailLevel,
    'focusPresence': focusPresence,
  };
}

class ColorThemeModel {
  int primaryHex;
  ColorThemeModel({this.primaryHex = 0xFF50C9A7});

  factory ColorThemeModel.fromJson(Map<String, dynamic> json) =>
      ColorThemeModel(primaryHex: json['primaryHex'] ?? 0xFF50C9A7);

  Map<String, dynamic> toJson() => {'primaryHex': primaryHex};
}

class GoalModel {
  final String id;
  String title;
  DateTime targetDate;
  bool isDone;
  DateTime createdAt;

  /// Môn trọng tâm của mục tiêu. Dữ liệu cũ không có trường này sẽ nhận "Chung".
  String subject;

  GoalModel({
    required this.id,
    required this.title,
    required this.targetDate,
    this.isDone = false,
    DateTime? createdAt,
    this.subject = 'Chung',
  }) : createdAt = createdAt ?? DateTime.now();

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    final subject = json['subject']?.toString().trim() ?? '';
    return GoalModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['text'] ?? '',
      targetDate: json['targetDate'] != null
          ? DateTime.parse(json['targetDate'])
          : DateTime.now().add(const Duration(days: 30)),
      isDone: json['isDone'] ?? json['done'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      subject: subject.isEmpty ? 'Chung' : subject,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'targetDate': targetDate.toIso8601String(),
    'isDone': isDone,
    'createdAt': createdAt.toIso8601String(),
    'subject': subject,
  };
}

class TaskModel {
  final String id;
  String goalId;
  String title;
  String subject;
  int durationMinutes;
  bool isDone;
  bool rewardClaimed;
  DateTime createdAt;
  DateTime? completedDate;
  int priority; // 0=normal, 1=high, 2=urgent
  final String? scheduledDate; // YYYY-MM-DD
  final String? scheduledTime; // HH:mm
  final String kind; // homework, preparation, learn, review, practice, mock
  final DateTime? dueAt;
  final List<String> goalIds, topicIds;
  final bool scheduleLocked;

  TaskModel({
    required this.id,
    this.goalId = '',
    required this.title,
    this.subject = 'Toán',
    this.durationMinutes = 25,
    this.isDone = false,
    this.rewardClaimed = false,
    DateTime? createdAt,
    this.completedDate,
    this.priority = 0,
    this.scheduledDate,
    this.scheduledTime,
    this.kind = 'practice',
    this.dueAt,
    this.goalIds = const [],
    this.topicIds = const [],
    this.scheduleLocked = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool isLinkedToGoal(String goalId) =>
      this.goalId == goalId || goalIds.contains(goalId);

  TaskModel copyWith({
    String? goalId,
    String? title,
    String? subject,
    int? durationMinutes,
    bool? isDone,
    bool? rewardClaimed,
    DateTime? createdAt,
    DateTime? completedDate,
    int? priority,
    String? scheduledDate,
    String? scheduledTime,
    String? kind,
    DateTime? dueAt,
    List<String>? goalIds,
    List<String>? topicIds,
    bool? scheduleLocked,
  }) {
    return TaskModel(
      id: id,
      goalId: goalId ?? this.goalId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isDone: isDone ?? this.isDone,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      createdAt: createdAt ?? this.createdAt,
      completedDate: completedDate ?? this.completedDate,
      priority: priority ?? this.priority,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      kind: kind ?? this.kind,
      dueAt: dueAt ?? this.dueAt,
      goalIds: goalIds ?? this.goalIds,
      topicIds: topicIds ?? this.topicIds,
      scheduleLocked: scheduleLocked ?? this.scheduleLocked,
    );
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id']?.toString() ?? '',
      goalId: json['goalId']?.toString() ?? '',
      title: json['title'] ?? json['text'] ?? '',
      subject: json['subject'] ?? 'Tổng hợp',
      durationMinutes: json['durationMinutes'] ?? json['duration'] ?? 25,
      isDone: json['isDone'] ?? json['done'] ?? false,
      rewardClaimed:
          json['rewardClaimed'] ?? json['isDone'] ?? json['done'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created'] != null
                ? DateTime.tryParse(json['created']) ?? DateTime.now()
                : DateTime.now()),
      completedDate: json['completedDate'] != null
          ? DateTime.tryParse(json['completedDate'])
          : null,
      priority: json['priority'] ?? 0,
      scheduledDate: json['scheduledDate']?.toString(),
      scheduledTime: json['scheduledTime']?.toString(),
      kind: json['kind']?.toString() ?? 'practice',
      dueAt: json['dueAt'] != null ? DateTime.tryParse(json['dueAt']) : null,
      goalIds: List<String>.from(json['goalIds'] ?? []),
      topicIds: List<String>.from(json['topicIds'] ?? []),
      scheduleLocked: json['scheduleLocked'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'goalId': goalId,
    'title': title,
    'subject': subject,
    'durationMinutes': durationMinutes,
    'isDone': isDone,
    'rewardClaimed': rewardClaimed,
    'createdAt': createdAt.toIso8601String(),
    'completedDate': completedDate?.toIso8601String(),
    'priority': priority,
    'scheduledDate': scheduledDate,
    'scheduledTime': scheduledTime,
    'kind': kind,
    'dueAt': dueAt?.toIso8601String(),
    'goalIds': goalIds,
    'topicIds': topicIds,
    'scheduleLocked': scheduleLocked,
  };
}

class StudySessionRecord {
  final String id;
  final String taskId;
  final String taskTitle;
  final String mode; // pomodoro, freestyle
  final int activeSeconds;
  final DateTime startedAt;
  final DateTime endedAt;
  final int earnedStars;
  final int earnedXp;
  final int selfRating; // 1-5
  final String reflection;

  StudySessionRecord({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.mode,
    required this.activeSeconds,
    required this.startedAt,
    required this.endedAt,
    this.earnedStars = 1,
    this.earnedXp = 50,
    this.selfRating = 5,
    this.reflection = '',
  });

  factory StudySessionRecord.fromJson(Map<String, dynamic> json) =>
      StudySessionRecord(
        id: json['id']?.toString() ?? '',
        taskId: json['taskId']?.toString() ?? '',
        taskTitle: json['taskTitle'] ?? '',
        mode: json['mode'] ?? 'pomodoro',
        activeSeconds: json['activeSeconds'] ?? 0,
        startedAt: DateTime.parse(json['startedAt']),
        endedAt: DateTime.parse(json['endedAt']),
        earnedStars: json['earnedStars'] ?? 1,
        earnedXp: json['earnedXp'] ?? 50,
        selfRating: json['selfRating'] ?? 5,
        reflection: json['reflection'] ?? '',
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'taskTitle': taskTitle,
    'mode': mode,
    'activeSeconds': activeSeconds,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'earnedStars': earnedStars,
    'earnedXp': earnedXp,
    'selfRating': selfRating,
    'reflection': reflection,
  };
}

class ShopItem {
  final String id;
  final String name;
  final String assetId;
  final int price;
  final int requiredStreak;
  final String category; // accessory, clothes, special
  final String desc;
  final bool isGift;

  const ShopItem({
    required this.id,
    required this.name,
    required this.assetId,
    required this.price,
    required this.requiredStreak,
    required this.category,
    required this.desc,
    this.isGift = false,
  });
}

class FlashcardDeck {
  final String id;
  String title;
  String subject;
  DateTime createdAt;
  final List<String> topicIds;

  FlashcardDeck({
    required this.id,
    required this.title,
    required this.subject,
    DateTime? createdAt,
    this.topicIds = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) => FlashcardDeck(
    id: json['id']?.toString() ?? '',
    title: json['title'] ?? '',
    subject: json['subject'] ?? 'Chung',
    topicIds: List<String>.from(json['topicIds'] ?? []),
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'topicIds': topicIds,
    'createdAt': createdAt.toIso8601String(),
  };
}

class FlashcardItem {
  final String id;
  final String deckId;
  String front;
  String back;
  String? originalBack;
  int intervalDays;
  DateTime nextReviewAt;
  int easeFactor; // 250 = 2.5
  int repetitions;

  FlashcardItem({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.originalBack,
    this.intervalDays = 1,
    DateTime? nextReviewAt,
    this.easeFactor = 250,
    this.repetitions = 0,
  }) : nextReviewAt = nextReviewAt ?? DateTime.now();

  factory FlashcardItem.fromJson(Map<String, dynamic> json) => FlashcardItem(
    id: json['id']?.toString() ?? '',
    deckId: json['deckId']?.toString() ?? '',
    front: json['front'] ?? '',
    back: json['back'] ?? '',
    originalBack: json['originalBack'],
    intervalDays: json['intervalDays'] ?? 1,
    nextReviewAt: json['nextReviewAt'] != null
        ? DateTime.parse(json['nextReviewAt'])
        : DateTime.now(),
    easeFactor: json['easeFactor'] ?? 250,
    repetitions: json['repetitions'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'deckId': deckId,
    'front': front,
    'back': back,
    'originalBack': originalBack,
    'intervalDays': intervalDays,
    'nextReviewAt': nextReviewAt.toIso8601String(),
    'easeFactor': easeFactor,
    'repetitions': repetitions,
  };
}

class ChatMessageModel {
  final String id;
  final String role; // user, assistant, system
  final String content;
  final DateTime timestamp;
  final RobotEmotion? suggestedEmotion;
  final String? source;
  final bool truncated;
  final String? model;
  final String? requestId;

  /// Mã lỗi khi `source == 'unavailable'`, dùng để UI chỉ hiện "Thử lại" khi
  /// lỗi thật sự có thể tự khỏi (mạng, quá tải tạm thời…).
  final String? failureReason;
  final Map<String, dynamic>? quizData;
  final Map<String, dynamic>? scheduleActionData;

  ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.suggestedEmotion,
    this.source,
    this.truncated = false,
    this.model,
    this.requestId,
    this.failureReason,
    this.quizData,
    this.scheduleActionData,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      ChatMessageModel(
        id: json['id'] ?? '',
        role: json['role'] ?? 'user',
        content: json['content'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
        suggestedEmotion: json['suggestedEmotion'] != null
            ? RobotEmotion.values.firstWhere(
                (e) => e.name == json['suggestedEmotion'],
                orElse: () => RobotEmotion.happy,
              )
            : null,
        source: json['source'] as String?,
        truncated: json['truncated'] == true,
        model: json['model'] as String?,
        requestId: json['requestId'] as String?,
        failureReason: json['failureReason'] as String?,
        quizData: json['quizData'] as Map<String, dynamic>?,
        scheduleActionData: json['scheduleActionData'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'suggestedEmotion': suggestedEmotion?.name,
    'source': source,
    'truncated': truncated,
    'model': model,
    'requestId': requestId,
    'failureReason': failureReason,
    'quizData': quizData,
    'scheduleActionData': scheduleActionData,
  };
}

class DailyRoutine {
  final String morningTime;
  final String eveningFreeStart;
  final String eveningFreeEnd;
  final int preferredDailyMinutes;
  final Map<String, List<String>> weeklyFree;
  final Map<String, List<String>> weeklyBusy;
  final Map<String, List<String>> dateFree;
  final Map<String, List<String>> dateBusy;

  const DailyRoutine({
    this.morningTime = '06:30',
    this.eveningFreeStart = '19:30',
    this.eveningFreeEnd = '21:30',
    this.preferredDailyMinutes = 120,
    this.weeklyFree = const {},
    this.weeklyBusy = const {},
    this.dateFree = const {},
    this.dateBusy = const {},
  });

  List<String> freeOn(DateTime day) {
    final dateKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    if (dateFree.containsKey(dateKey)) return dateFree[dateKey]!;
    final wd = day.weekday.toString();
    if (weeklyFree.containsKey(wd)) return weeklyFree[wd]!;
    return ['$eveningFreeStart-$eveningFreeEnd'];
  }

  List<String> busyOn(DateTime day) {
    final dateKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final result = <String>[];
    if (weeklyBusy.containsKey(day.weekday.toString())) {
      result.addAll(weeklyBusy[day.weekday.toString()]!);
    }
    if (dateBusy.containsKey(dateKey)) {
      result.addAll(dateBusy[dateKey]!);
    }
    return result;
  }

  factory DailyRoutine.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>> parseMap(dynamic map) {
      if (map is! Map) return {};
      final res = <String, List<String>>{};
      for (final e in map.entries) {
        if (e.value is List) {
          res[e.key.toString()] = (e.value as List)
              .map((x) => x.toString())
              .toList();
        }
      }
      return res;
    }

    return DailyRoutine(
      morningTime: json['morningTime']?.toString() ?? '06:30',
      eveningFreeStart: json['eveningFreeStart']?.toString() ?? '19:30',
      eveningFreeEnd: json['eveningFreeEnd']?.toString() ?? '21:30',
      preferredDailyMinutes:
          (json['preferredDailyMinutes'] as num?)?.toInt() ?? 120,
      weeklyFree: parseMap(json['weeklyFree']),
      weeklyBusy: parseMap(json['weeklyBusy']),
      dateFree: parseMap(json['dateFree']),
      dateBusy: parseMap(json['dateBusy']),
    );
  }

  Map<String, dynamic> toJson() => {
    'morningTime': morningTime,
    'eveningFreeStart': eveningFreeStart,
    'eveningFreeEnd': eveningFreeEnd,
    'preferredDailyMinutes': preferredDailyMinutes,
    'weeklyFree': weeklyFree,
    'weeklyBusy': weeklyBusy,
    'dateFree': dateFree,
    'dateBusy': dateBusy,
  };
}
