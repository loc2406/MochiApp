import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mochi_models.dart';
import '../models/tutor_quiz.dart';
import '../models/knowledge_identity.dart';
import '../models/knowledge_content.dart';
import '../learning/review_policy.dart';
import '../learning/learning_models.dart';
import '../learning/unified_study_planner.dart';
import '../services/study_schedule.dart';
import '../services/schedule_change_policy.dart';
import '../services/ai_service.dart';
import '../services/account_state_merge.dart';
import '../services/cloud_sync_service.dart';

class MochiStore extends ChangeNotifier {
  static const String prefKey = 'mochi_app_data_v1';
  static const String aiKeyPref = 'mochi_groq_api_key';
  static const String aiEndpointPref = 'mochi_ai_endpoint';
  static const String supaUrlPref = 'mochi_supabase_url';
  static const String supaAnonPref = 'mochi_supabase_anon';

  final AIService aiService;
  MochiStore({AIService? aiService, CloudSyncService? cloudService})
    : aiService = aiService ?? AIService(),
      cloudService = cloudService ?? CloudSyncService();
  final CloudSyncService cloudService;
  Map<String, dynamic>? _baseState;
  String _cacheKey(String? owner) =>
      owner == null ? prefKey : 'mochi_account_cache_$owner';
  String _outboxKey(String owner) => 'mochi_account_outbox_$owner';
  Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));

  Timer? _cloudPoll;
  bool _pulling = false;
  int _localGeneration = 0;
  @override
  void dispose() {
    _cloudPoll?.cancel();
    super.dispose();
  }

  void startCloudRefresh() {
    _cloudPoll?.cancel();
    _cloudPoll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_pulling && cloudService.hasActiveUser) {
        if (_dirty && _cloudReady) {
          unawaited(retryCloudSync());
        } else {
          unawaited(refreshCloudAuth(preserveRecovery: false));
        }
      }
    });
  }

  String? syncError;
  String? _cloudOwner;
  bool _cloudReady = false;
  bool _dirty = false;
  Future<void> _writeQueue = Future<void>.value();

  bool get isCloudSynced => _cloudReady && !_dirty && syncError == null;

  bool isLoaded = false;
  bool isFirstTime = true;

  // App State
  LearningState learning = LearningState();
  List<ChatMessageModel> tutorMessages = [];
  DailyRoutine dailyRoutine = const DailyRoutine();
  ProfileModel profile = ProfileModel(name: '');
  List<GoalModel> goals = [];
  List<TaskModel> tasks = [];
  List<StudySessionRecord> sessions = [];
  Map<String, bool> activityDays = {}; // 'YYYY-MM-DD' -> true
  Map<String, int> dayCustomColors = {}; // 'YYYY-MM-DD' -> primaryHex

  int stars = 0;
  int xp = 0;
  int currentStreak = 0;
  int longestStreak = 0;
  int totalStudyMinutes = 0;

  // Robot Shop & Equipment
  List<String> ownedItems = ['default'];
  String equippedAccessory = '';
  String equippedClothes = '';
  String equippedSpecial = '';
  int robotColorHex = 0xFF50C9A7;

  // Flashcards
  List<FlashcardDeck> decks = [];
  List<FlashcardItem> flashcards = [];

  // Privacy & Companion Observers (Website compatibility)
  List<Map<String, dynamic>> companions = [];
  Map<String, bool> parentPerms = {
    'weekly': true,
    'time': true,
    'plan': true,
    'days': true,
    'goals': false,
    'attendance': true,
  };
  Map<String, bool> teacherPerms = {
    'weekly': true,
    'time': false,
    'plan': false,
    'days': false,
    'goals': false,
    'attendance': true,
  };

  // Robot Emotion
  RobotEmotion robotEmotion = RobotEmotion.idle;

  // Static Shop Catalog
  static const List<ShopItem> shopCatalog = [
    ShopItem(
      id: 'sunglasses',
      name: 'Kính râm cực ngầu',
      assetId: 'sunglasses',
      price: 3,
      requiredStreak: 3,
      category: 'accessory',
      desc: 'Phong cách tự tin, nổi bật cá tính',
    ),
    ShopItem(
      id: 'beanie',
      name: 'Mũ len ấm áp',
      assetId: 'beanie',
      price: 3,
      requiredStreak: 3,
      category: 'accessory',
      desc: 'Ấm áp, dễ thương mỗi ngày học tập',
    ),
    ShopItem(
      id: 'cap',
      name: 'Mũ lưỡi trai năng động',
      assetId: 'cap',
      price: 3,
      requiredStreak: 3,
      category: 'accessory',
      desc: 'Năng động, tươi trẻ khi đến trường',
    ),
    ShopItem(
      id: 'tee',
      name: 'Áo phông năng động',
      assetId: 'tee',
      price: 7,
      requiredStreak: 7,
      category: 'clothes',
      desc: 'Thoải mái khi ngồi vào bàn học',
    ),
    ShopItem(
      id: 'tank',
      name: 'Áo ba lỗ thể thao',
      assetId: 'tank',
      price: 7,
      requiredStreak: 7,
      category: 'clothes',
      desc: 'Sẵn sàng chinh phục mọi thử thách',
    ),
    ShopItem(
      id: 'backpack',
      name: 'Ba lô tri thức',
      assetId: 'backpack',
      price: 7,
      requiredStreak: 7,
      category: 'accessory',
      desc: 'Chứa đựng tương lai và ước mơ',
    ),
    ShopItem(
      id: 'suit',
      name: 'Vest sang chảnh',
      assetId: 'suit',
      price: 10,
      requiredStreak: 10,
      category: 'clothes',
      desc: 'Lịch lãm, quyết tâm và bản lĩnh',
    ),
    ShopItem(
      id: 'armor',
      name: 'Giáp robot tối tân',
      assetId: 'armor',
      price: 10,
      requiredStreak: 10,
      category: 'special',
      desc: 'Tăng cường ý chí thép trước kỳ thi',
    ),
    ShopItem(
      id: 'astronaut',
      name: 'Bộ đồ phi hành gia',
      assetId: 'astronaut',
      price: 10,
      requiredStreak: 10,
      category: 'special',
      desc: 'Vươn xa ra các vũ trụ tri thức mới',
    ),
    ShopItem(
      id: 'christmas',
      name: 'Mùa Giáng Sinh',
      assetId: 'christmas',
      price: 15,
      requiredStreak: 15,
      category: 'special',
      desc: 'Sắc đỏ ấm áp mùa cuối năm',
    ),
    ShopItem(
      id: 'tet',
      name: 'Sắc xuân rực rỡ',
      assetId: 'tet',
      price: 15,
      requiredStreak: 15,
      category: 'special',
      desc: 'Mang lại tài lộc và điểm cao may mắn',
    ),
    ShopItem(
      id: 'sticker',
      name: 'Huy hiệu bí ẩn',
      assetId: 'sticker',
      price: 0,
      requiredStreak: 15,
      category: 'special',
      desc: 'Quà tặng khi kiên trì 15 ngày liên tục',
      isGift: true,
    ),
    ShopItem(
      id: 'golden',
      name: 'Robot ánh sao vàng',
      assetId: 'golden',
      price: 30,
      requiredStreak: 30,
      category: 'special',
      desc: 'Danh hiệu cao quý nhất cho bậc thầy tập trung',
      isGift: true,
    ),
  ];

  // Helper date key
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int streakOn(DateTime day) {
    var count = 0;
    for (
      var cursor = DateTime(day.year, day.month, day.day);
      activityDays[dateKey(cursor)] == true;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1)
    ) {
      count++;
    }
    return count;
  }

  String get todayKey => dateKey(DateTime.now());

  // Initialization
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Automatically connect embedded cloud services silently
    await cloudService.initialize();

    // Load main app JSON data
    final rawJson = prefs.getString(_cacheKey(cloudService.currentUserId));
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(rawJson);
        _hydrate(data);
        isFirstTime = profile.name.trim().isEmpty;
      } catch (e) {
        debugPrint('Error loading saved state: $e');
        _initSampleDefaults();
      }
    } else {
      _initSampleDefaults();
    }

    final owner = cloudService.currentUserId;
    final base = owner == null
        ? null
        : prefs.getString('mochi_account_base_$owner');
    if (owner != null && base != null) {
      _baseState = Map<String, dynamic>.from(jsonDecode(base));
      _cloudOwner = owner;
      _cloudReady = true;
      _dirty = prefs.containsKey(_outboxKey(owner));
    }
    if (cloudService.hasActiveUser) await refreshCloudAuth();
    _calculateStreak();
    isLoaded = true;
    notifyListeners();
  }

  void _initSampleDefaults() {
    profile = ProfileModel(
      name: '',
      gender: 'neutral',
      gradeBand: 'THCS',
      school: '',
      mainGoal: '',
      robotName: 'Mochi',
    );
    isFirstTime = true;
    goals = [];
    tasks = [];
    decks = [
      FlashcardDeck(
        id: 'deck_1',
        title: 'Thuật ngữ Khoa học cơ bản',
        subject: 'KHTN',
      ),
    ];
    flashcards = [
      FlashcardItem(
        id: 'fc_1',
        deckId: 'deck_1',
        front: 'Hiện tượng quang hợp ở thực vật là gì?',
        back: 'Quá trình diệp lục hấp thụ ánh sáng mặt trời để tổng hợp chất hữu cơ từ CO2 và H2O, giải phóng O2.',
      ),
      FlashcardItem(
        id: 'fc_2',
        deckId: 'deck_1',
        front: 'Định luật vạn vật hấp dẫn của ai?',
        back: 'Isaac Newton (mọi vật trong vũ trụ đều hút nhau với một lực tỉ lệ thuận với tích khối lượng và tỉ lệ nghịch với bình phương khoảng cách).',
      ),
    ];
  }

  void _hydrate(Map<String, dynamic> data) {
    learning = LearningState.fromJson(
      Map<String, dynamic>.from(data['learning'] ?? {}),
    );
    tutorMessages = (data['tutorMessages'] as List? ?? [])
        .map((x) => ChatMessageModel.fromJson(Map<String, dynamic>.from(x)))
        .toList();
    if (data['dailyRoutine'] != null) {
      dailyRoutine = DailyRoutine.fromJson(data['dailyRoutine']);
    }
    if (data['profile'] != null) {
      profile = ProfileModel.fromJson(data['profile']);
    }
    if (data['goals'] is List) {
      goals = (data['goals'] as List)
          .map((g) => GoalModel.fromJson(Map<String, dynamic>.from(g)))
          .toList();
    }
    if (data['tasks'] is List) {
      tasks = (data['tasks'] as List)
          .map((t) => TaskModel.fromJson(Map<String, dynamic>.from(t)))
          .toList();
    }
    if (data['sessions'] is List) {
      sessions = (data['sessions'] as List)
          .map((s) => StudySessionRecord.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    }
    if (data['activity'] is Map) {
      activityDays = Map<String, bool>.from(data['activity']);
    }
    if (data['dayColors'] is Map) {
      dayCustomColors = Map<String, int>.from(data['dayColors']);
    }

    stars = data['stars'] ?? 0;
    xp = data['xp'] ?? 0;
    currentStreak = data['currentStreak'] ?? 0;
    longestStreak = data['longestStreak'] ?? 0;
    totalStudyMinutes = data['totalStudyMinutes'] ?? data['minutes'] ?? 0;

    if (data['owned'] is List) {
      ownedItems = List<String>.from(data['owned']);
    }
    if (data['equipped'] is Map) {
      equippedAccessory = data['equipped']['accessory'] ?? '';
      equippedClothes = data['equipped']['clothes'] ?? '';
      equippedSpecial = data['equipped']['special'] ?? '';
    }
    robotColorHex = data['robotColorHex'] ?? 0xFF50C9A7;

    if (data['decks'] is List) {
      decks = (data['decks'] as List)
          .map((d) => FlashcardDeck.fromJson(Map<String, dynamic>.from(d)))
          .toList();
    }
    if (data['flashcards'] is List) {
      flashcards =
          repairKnowledgeIds(
                (data['flashcards'] as List)
                    .map((c) => Map<String, dynamic>.from(c))
                    .toList(),
              )
              .map((c) => FlashcardItem.fromJson(Map<String, dynamic>.from(c)))
              .toList();
    }
    for (final session in learning.reviewSessions.where(
      (s) => s['status'] == 'active',
    )) {
      try {
        _checkReviewSources(session);
        final cardsDone =
            (session['grades'] as Map).length ==
            (session['cardIds'] as List).length;
        final quiz = session['quiz'] as Map;
        if (cardsDone &&
            (session['mode'] == 'offline' ||
                (quiz['answers'] as Map).length ==
                    (quiz['questions'] as List).length)) {
          _completeReview(session);
        }
      } on StateError {
        // A remote edit/deletion makes the old session unusable immediately.
      }
    }
    if (data['companions'] is List) {
      companions = List<Map<String, dynamic>>.from(data['companions']);
    }
  }

  Future<void> saveLearningSetup({
    required int gradeLevel,
    required String academicYear,
    required List<LearningCourse> courses,
  }) async {
    if (gradeLevel < 1 || gradeLevel > 12 || academicYear.trim().isEmpty)
      throw ArgumentError('Chọn lớp và năm học.');
    learning.gradeLevel = gradeLevel;
    learning.academicYear = academicYear.trim();
    learning.courses = courses;
    await save();
  }

  Future<void> setTopicReadiness(
    String courseId,
    String topicId,
    TopicReadiness readiness,
  ) async {
    final course = learning.courses.where((c) => c.id == courseId).firstOrNull;
    if (course == null || !course.topics.any((t) => t.id == topicId))
      throw ArgumentError('Chủ đề không thuộc môn đã chọn.');
    final id = '$courseId/$topicId';
    learning.progress.removeWhere((p) => p.id == id);
    learning.progress.add(
      TopicProgress(
        id: id,
        courseId: courseId,
        topicId: topicId,
        readiness: readiness,
        updatedAt: DateTime.now(),
      ),
    );
    if (readiness == TopicReadiness.needsReview) {
      final linked = decks
          .where((d) => d.topicIds.contains(topicId))
          .map((d) => d.id)
          .toSet();
      for (final card in flashcards.where((c) => linked.contains(c.deckId))) {
        card.nextReviewAt = DateTime.now();
        card.repetitions = 0;
      }
      for (final session in learning.reviewSessions.where(
        (s) => s['status'] == 'completed',
      )) {
        session['needsNewReview'] = true;
      }
    }
    await save();
  }

  Future<void> upsertSchoolLesson(SchoolLesson lesson) async {
    final a = scheduleMinute(lesson.startTime),
        b = scheduleMinute(lesson.endTime);
    if (a >= b ||
        lesson.weekday < 1 ||
        lesson.weekday > 7 ||
        lesson.subject.trim().isEmpty)
      throw ArgumentError('Kiểm tra môn, thứ và giờ bắt đầu/kết thúc.');
    if (lesson.weekPattern != 'all' && lesson.parityAnchor == null)
      throw ArgumentError('Chọn tuần bắt đầu cho lịch chẵn/lẻ.');
    learning.timetable.removeWhere((x) => x.id == lesson.id);
    learning.timetable.add(lesson);
    await save();
  }

  Future<void> removeSchoolLesson(String id) async {
    learning.timetable.removeWhere((x) => x.id == id);
    await save();
  }

  UnifiedStudyPlan previewUnifiedPlan({DateTime? now, int days = 7}) =>
      UnifiedStudyPlanner().build(
        now: now ?? DateTime.now(),
        tasks: tasks,
        goals: goals,
        routine: dailyRoutine,
        learning: learning,
        days: days,
      );
  Future<void> acceptUnifiedPlan(UnifiedStudyPlan plan) async {
    final signature = UnifiedStudyPlanner.signature(
      tasks: tasks,
      routine: dailyRoutine,
      learning: learning,
      goals: goals,
    );
    if (plan.contextSignature != signature)
      throw StateError(
        'Dữ liệu đã thay đổi. Hãy xem lại kế hoạch mới trước khi áp dụng.',
      );
    if (learning.plans.any((x) => x.id == plan.id)) return;
    learning.plans.add(plan);
    learning.activePlanId = plan.id;
    await save();
  }

  List<TaskModel> get reminderTasks {
    final blocks = learning.activePlan?.blocks ?? <LearningBlock>[];
    final parents = blocks.map((x) => x.taskId).toSet();
    return [
      ...tasks.where((t) => !parents.contains(t.id) || t.scheduleLocked),
      for (final block in blocks)
        if (tasks.any((t) => t.id == block.taskId && !t.isDone) &&
            learning.completedMinutesForBlock(block.id) < block.minutes)
          TaskModel(
            id: 'block/${block.id}',
            title: block.title,
            subject: block.subject,
            durationMinutes: block.minutes,
            scheduledDate: block.date,
            scheduledTime: block.startTime,
          ),
    ];
  }

  Future<void> recordTutorMessage(ChatMessageModel message) async {
    if (tutorMessages.any((x) => x.id == message.id)) return;
    tutorMessages.add(message);
    notifyListeners();
    await save();
  }

  Future<void> confirmTutorScheduleChange(
    String messageId, {
    DateTime? at,
  }) async {
    final index = tutorMessages.indexWhere((m) => m.id == messageId);
    if (index < 0) throw StateError('Không còn đề xuất này.');
    final message = tutorMessages[index];
    final action = Map<String, dynamic>.from(message.scheduleActionData ?? {});
    if (action['ownerId'] != (cloudService.currentUserId ?? 'guest'))
      throw StateError('Đề xuất thuộc phiên tài khoản khác.');
    if (action['status'] == 'applied') return;
    final task = ScheduleChangePolicy.validate(
      action: action,
      tasks: tasks,
      routine: dailyRoutine,
      learning: learning,
      now: at ?? DateTime.now(),
      spentMinutes: sessions
          .where((s) => dateKey(s.endedAt) == action['date'])
          .fold<int>(0, (sum, s) => sum + s.activeSeconds ~/ 60),
    );
    final taskIndex = tasks.indexWhere((t) => t.id == task.id);
    tasks[taskIndex] = task.copyWith(
      scheduledDate: action['date'],
      scheduledTime: action['newTime'],
    );
    final data = message.toJson();
    data['scheduleActionData'] = {
      ...action,
      'status': 'applied',
      'appliedAt': DateTime.now().toIso8601String(),
    };
    tutorMessages[index] = ChatMessageModel.fromJson(data);
    await save();
  }

  Future<void> answerTutorQuiz(
    String messageId,
    int question,
    int option,
  ) async {
    final index = tutorMessages.indexWhere((m) => m.id == messageId);
    if (index < 0) throw StateError('Không còn phiên quiz này.');
    final message = tutorMessages[index];
    final quiz = validateTutorQuiz(message.quizData);
    if (question < 0 ||
        question >= (quiz['questions'] as List).length ||
        option < 0 ||
        option > 3)
      throw ArgumentError('Lựa chọn không hợp lệ.');
    final answers = Map<String, dynamic>.from(quiz['answers'] as Map? ?? {});
    if (answers.containsKey('$question')) return;
    answers['$question'] = {
      'optionIndex': option,
      'answeredAt': DateTime.now().toIso8601String(),
    };
    final data = message.toJson();
    data['quizData'] = {...quiz, 'answers': answers};
    tutorMessages[index] = ChatMessageModel.fromJson(data);
    notifyListeners();
    await save();
  }

  void updateDailyRoutine(DailyRoutine routine) {
    dailyRoutine = routine;
    save();
    notifyListeners();
  }

  Future<void> refreshCloudAuth({bool preserveRecovery = true}) async {
    if (_pulling) return;
    final owner = cloudService.currentUserId;
    if (cloudService.hasActiveUser &&
        owner == _cloudOwner &&
        _dirty &&
        _baseState != null) {
      await retryCloudSync();
      return;
    }
    _pulling = true;
    final generation = _localGeneration;
    if (!cloudService.hasActiveUser || owner == null) {
      if (_cloudOwner != null) {
        _hydrate(MochiStore()._snapshot());
        isFirstTime = true;
      }
      _cloudOwner = null;
      _cloudReady = false;
      _baseState = null;
      _dirty = false;
      syncError = null;
      _pulling = false;
      notifyListeners();
      return;
    }
    if (owner != _cloudOwner) _cloudReady = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (preserveRecovery) {
        await prefs.setString(
          'mochi_recovery_${DateTime.now().microsecondsSinceEpoch}',
          jsonEncode(_snapshot()),
        );
      }
      if (_cloudOwner != owner) {
        _hydrate(MochiStore()._snapshot());
        final cached = prefs.getString(_cacheKey(owner));
        if (cached != null)
          _hydrate(Map<String, dynamic>.from(jsonDecode(cached)));
        _cloudOwner = owner;
        _baseState = null;
        _dirty = false;
        isFirstTime = profile.name.trim().isEmpty;
      }
      var row = await cloudService.fetchAccountState();
      if (row == null) {
        // A new account starts empty. Never adopt another account's cache.
        try {
          await cloudService.saveAccountState(MochiStore()._snapshot(), 0);
        } catch (_) {
          // Another device may have created it meanwhile. Read the winner.
        }
        row = await cloudService.fetchAccountState();
        if (row == null) throw StateError('account_state_unavailable');
      }
      if (owner != cloudService.currentUserId || generation != _localGeneration)
        return;
      final remote = _copy(Map<String, dynamic>.from(row['state']));
      final pending = prefs.getString(_outboxKey(owner));
      var local = remote;
      if (pending != null) {
        final journal = jsonDecode(pending) as Map;
        // Keep the correct account's pending edits visible even if merge conflicts.
        _hydrate(Map<String, dynamic>.from(journal['state']));
        _cloudOwner = owner;
        _baseState = Map<String, dynamic>.from(journal['base']);
        _cloudReady = true;
        _dirty = true;
        local = mergeAccountState(
          Map<String, dynamic>.from(journal['base']),
          Map<String, dynamic>.from(journal['state']),
          remote,
        );
      }
      _hydrate(local);
      _baseState = remote;
      _cloudOwner = owner;
      _cloudReady = true;
      _dirty = pending != null;
      syncError = null;
      isFirstTime = profile.name.trim().isEmpty;
      await _persistLocal(owner);
    } on AccountStateConflict {
      syncError = 'Có thay đổi cùng dữ liệu từ hai thiết bị. Bản chỉnh sửa trên máy vẫn được giữ để đối chiếu, chưa ghi đè.';
    } catch (_) {
      syncError = 'Chưa kết nối được dữ liệu. Các thay đổi chưa gửi sẽ được thử đồng bộ lại khi có mạng.';
    } finally {
      _pulling = false;
      if (_cloudPoll == null) startCloudRefresh();
      notifyListeners();
    }
    if (_dirty && _cloudReady) await retryCloudSync();
  }

  Future<void> _persistLocal(String? owner) async {
    final prefs = await SharedPreferences.getInstance();
    final state = _copy(_snapshot());
    await prefs.setString(_cacheKey(owner), jsonEncode(state));
    if (owner != null && _baseState != null) {
      await prefs.setString(
        'mochi_account_base_$owner',
        jsonEncode(_baseState),
      );
      if (_dirty) {
        await prefs.setString(
          _outboxKey(owner),
          jsonEncode({'base': _baseState, 'state': state}),
        );
      } else {
        await prefs.remove(_outboxKey(owner));
      }
    }
  }

  Future<void> retryCloudSync() {
    _writeQueue = _writeQueue.then((_) => _flushCloud());
    return _writeQueue;
  }

  Future<void> _flushCloud() async {
    final owner = _cloudOwner;
    if (!_cloudReady ||
        !_dirty ||
        owner == null ||
        owner != cloudService.currentUserId)
      return;
    try {
      for (var attempt = 0; attempt < 4 && _dirty; attempt++) {
        final generation = _localGeneration;
        final sent = _copy(_snapshot());
        final row = await cloudService.fetchAccountState();
        if (owner != cloudService.currentUserId) return;
        if (row == null) throw StateError('missing_account_state');
        final merged = mergeAccountState(
          _baseState!,
          sent,
          Map<String, dynamic>.from(row['state']),
        );
        try {
          await cloudService.saveAccountState(
            merged,
            (row['revision'] as num).toInt(),
          );
          if (owner != cloudService.currentUserId) return;
          final updated = generation == _localGeneration
              ? merged
              : mergeAccountState(sent, _copy(_snapshot()), merged);
          _hydrate(updated);
          _baseState = _copy(merged);
          _dirty = generation != _localGeneration;
          syncError = null;
          await _persistLocal(owner);
        } catch (e) {
          if (e.toString().contains('sync_conflict') && attempt < 3) continue;
          rethrow;
        }
      }
    } on AccountStateConflict {
      syncError = 'Hai thiết bị đã sửa cùng dữ liệu. Bản trên máy được giữ nguyên, chưa ghi đè thay đổi trên tài khoản.';
    } catch (_) {
      syncError = 'Chưa gửi được thay đổi. App sẽ tự thử lại khi có mạng; dữ liệu chưa gửi vẫn được giữ.';
    }
    notifyListeners();
  }

  Map<String, dynamic> _snapshot() => {
    'learning': learning.toJson(),
    'tutorMessages': tutorMessages.map((x) => x.toJson()).toList(),
    'dailyRoutine': dailyRoutine.toJson(),
    'profile': profile.toJson(),
    'goals': goals.map((g) => g.toJson()).toList(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'activity': activityDays,
    'dayColors': dayCustomColors,
    'stars': stars,
    'xp': xp,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'totalStudyMinutes': totalStudyMinutes,
    'owned': ownedItems,
    'equipped': {
      'accessory': equippedAccessory,
      'clothes': equippedClothes,
      'special': equippedSpecial,
    },
    'robotColorHex': robotColorHex,
    'decks': decks.map((d) => d.toJson()).toList(),
    'flashcards': flashcards.map((f) => f.toJson()).toList(),
    'companions': companions,
  };
  Future<void> save() {
    _localGeneration++;
    final owner = cloudService.currentUserId;
    if (cloudService.hasActiveUser && _cloudReady && owner == _cloudOwner)
      _dirty = true;
    notifyListeners();
    _writeQueue = _writeQueue.then((_) async {
      if (owner != cloudService.currentUserId) return;
      await _persistLocal(owner);
      await _flushCloud();
    });
    return _writeQueue;
  }

  // Complete Onboarding
  Future<void> completeOnboarding({
    required String learnerName,
    required String gradeBand,
    required String robotName,
    required String primaryGoal,
    required String targetSubject,
  }) async {
    profile.name = learnerName;
    profile.gradeBand = gradeBand;
    profile.robotName = robotName;
    profile.mainGoal = primaryGoal;
    isFirstTime = false;

    // Add first initial goal
    if (primaryGoal.isNotEmpty) {
      final newGoal = GoalModel(
        id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
        title: primaryGoal,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        subject: targetSubject,
      );
      goals.add(newGoal);

      // Add 2 initial action tasks
      tasks.add(
        TaskModel(
          id: 'task_${DateTime.now().millisecondsSinceEpoch}_1',
          goalId: newGoal.id,
          title: 'Khởi động mục tiêu: Xem tổng quan & chuẩn bị tài liệu',
          subject: targetSubject,
          durationMinutes: 20,
          priority: 1,
        ),
      );
      tasks.add(
        TaskModel(
          id: 'task_${DateTime.now().millisecondsSinceEpoch}_2',
          goalId: newGoal.id,
          title: 'Thực hiện phiên học tập trung đầu tiên (25 phút)',
          subject: targetSubject,
          durationMinutes: 25,
          priority: 2,
        ),
      );
    }

    setRobotEmotion(RobotEmotion.happy);
    await save();
  }

  // CRUD Goals
  void addGoal(String title, DateTime targetDate, {String subject = 'Chung'}) {
    goals.add(
      GoalModel(
        id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        targetDate: targetDate,
        subject: subject,
      ),
    );
    setRobotEmotion(RobotEmotion.happy);
    save();
  }

  void toggleGoal(String id, bool isDone) {
    final g = goals.firstWhere((x) => x.id == id);
    g.isDone = isDone;
    if (isDone) {
      _recordActivity();
      setRobotEmotion(RobotEmotion.celebrate);
    }
    save();
  }

  void deleteGoal(String id) {
    goals.removeWhere((x) => x.id == id);
    tasks.removeWhere((t) => t.goalId == id);
    save();
  }

  // CRUD Tasks
  void addTask({
    required String title,
    String goalId = '',
    String subject = 'Chung',
    int duration = 25,
    int priority = 0,
    String? scheduledDate,
    String? scheduledTime,
    String kind = 'practice',
    DateTime? dueAt,
    List<String> goalIds = const [],
    List<String> topicIds = const [],
    bool scheduleLocked = false,
  }) {
    tasks.add(
      TaskModel(
        id: 'task_${DateTime.now().microsecondsSinceEpoch}_${tasks.length}',
        goalId: goalId,
        title: title,
        subject: subject,
        durationMinutes: duration,
        priority: priority,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        kind: kind,
        dueAt: dueAt,
        goalIds: goalIds,
        topicIds: topicIds,
        scheduleLocked: scheduleLocked,
      ),
    );
    setRobotEmotion(RobotEmotion.happy);
    save();
  }

  void toggleTask(String id, bool isDone) {
    final t = tasks.firstWhere((x) => x.id == id);
    if (t.isDone == isDone) return;
    t.isDone = isDone;
    if (isDone) {
      t.completedDate = DateTime.now();
      if (!t.rewardClaimed) {
        _awardReward(starsToAdd: 1, xpToAdd: 30);
        t.rewardClaimed = true;
      }
      _recordActivity();
      setRobotEmotion(RobotEmotion.celebrate);
    } else {
      t.completedDate = null;
    }
    save();
  }

  void deleteTask(String id) {
    tasks.removeWhere((x) => x.id == id);
    save();
  }

  void rescheduleTask(String id, String newTime, {String? newDate}) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      tasks[idx] = tasks[idx].copyWith(
        scheduledTime: newTime,
        scheduledDate: newDate ?? tasks[idx].scheduledDate,
      );
      save();
    }
  }

  // Study Session Complete (Atomic & Idempotent)
  void completeStudySession({
    required String taskId,
    required String taskTitle,
    required String mode,
    required int activeMinutes,
    int selfRating = 5,
    String reflection = '',
    String? operationKey,
    String? learningBlockId,
    bool completeTask = true,
  }) {
    if (operationKey != null && sessions.any((s) => s.id == operationKey))
      return;
    if (activeMinutes < 1 || activeMinutes > 180)
      throw ArgumentError('Thời gian phiên học không hợp lệ.');
    final sessionSecs = activeMinutes * 60;
    final starsEarned = (activeMinutes >= 20) ? 2 : 1;
    final xpEarned = activeMinutes * 5;

    final rec = StudySessionRecord(
      id: operationKey ?? 'sess_${DateTime.now().microsecondsSinceEpoch}',
      taskId: taskId,
      taskTitle: taskTitle,
      mode: mode,
      activeSeconds: sessionSecs,
      startedAt: DateTime.now().subtract(Duration(minutes: activeMinutes)),
      endedAt: DateTime.now(),
      earnedStars: starsEarned,
      earnedXp: xpEarned,
      selfRating: selfRating,
      reflection: reflection,
    );

    sessions.insert(0, rec);
    if (learningBlockId != null) {
      learning.studyEvents.add({
        'id': rec.id,
        'taskId': taskId,
        'blockId': learningBlockId,
        'minutes': activeMinutes,
        'endedAt': rec.endedAt.toIso8601String(),
        'evidenceType': 'focus_time_not_mastery',
      });
    }
    totalStudyMinutes += activeMinutes;
    _awardReward(starsToAdd: starsEarned, xpToAdd: xpEarned);
    _recordActivity();
    setRobotEmotion(RobotEmotion.celebrate);

    // If task is completed as well
    if (completeTask && taskId.isNotEmpty) {
      try {
        final t = tasks.firstWhere((x) => x.id == taskId);
        t.isDone = true;
        t.completedDate = DateTime.now();
      } catch (_) {}
    }

    save();
  }

  // Reward and Ledger
  void _awardReward({required int starsToAdd, required int xpToAdd}) {
    stars += starsToAdd;
    xp += xpToAdd;
  }

  void _recordActivity() {
    final key = todayKey;
    final alreadyRecorded = activityDays[key] ?? false;
    activityDays[key] = true;

    if (!alreadyRecorded) {
      _calculateStreak();
    }
  }

  void _calculateStreak() {
    if (activityDays.isEmpty) {
      currentStreak = 0;
      return;
    }

    final sortedKeys =
        activityDays.keys.where((k) => activityDays[k] == true).toList()
          ..sort();
    if (sortedKeys.isEmpty) {
      currentStreak = 0;
      return;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastParts = sortedKeys.last.split('-').map(int.parse).toList();
    final lastDate = DateTime(lastParts[0], lastParts[1], lastParts[2]);

    final diff = todayDate.difference(lastDate).inDays;
    if (diff > 1) {
      currentStreak = 0;
      return;
    }

    int count = 1;
    DateTime cur = lastDate;
    for (int i = sortedKeys.length - 2; i >= 0; i--) {
      final p = sortedKeys[i].split('-').map(int.parse).toList();
      final prevDate = DateTime(p[0], p[1], p[2]);
      if (cur.difference(prevDate).inDays == 1) {
        count++;
        cur = prevDate;
      } else if (cur.difference(prevDate).inDays > 1) {
        break;
      }
    }

    currentStreak = count;
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }
  }

  // Shop purchase & equip
  bool buyItem(ShopItem item) {
    if (ownedItems.contains(item.id)) return false;
    if (stars < item.price) return false;
    if (currentStreak < item.requiredStreak) return false;

    stars -= item.price;
    ownedItems.add(item.id);
    equipItem(item.id, item.category);
    setRobotEmotion(RobotEmotion.celebrate);
    save();
    return true;
  }

  void equipItem(String itemId, String category) {
    if (category == 'accessory') {
      equippedAccessory = (equippedAccessory == itemId) ? '' : itemId;
    } else if (category == 'clothes') {
      equippedClothes = (equippedClothes == itemId) ? '' : itemId;
    } else if (category == 'special') {
      equippedSpecial = (equippedSpecial == itemId) ? '' : itemId;
    }
    save();
  }

  void changeRobotColor(int colorHex) {
    robotColorHex = colorHex;
    save();
  }

  // Emotion
  void setRobotEmotion(RobotEmotion emotion) {
    robotEmotion = emotion;
    notifyListeners();
  }

  // Flashcards CRUD & Spaced Repetition (SuperMemo-2 derivative)
  Future<void> ensureKnowledgeExplanation(String cardId) async {
    final card = flashcards.firstWhere((c) => c.id == cardId);
    if (hasKnowledgeExplanation(card.back)) return;
    final owner = cloudService.currentUserId,
        oldBack = card.back,
        oldFront = card.front;
    final deck = decks.where((d) => d.id == card.deckId).firstOrNull;
    final explanation = await aiService
        .explainKnowledgeCard(
          question: oldFront,
          answer: oldBack,
          subject: deck?.subject ?? 'Theo nội dung thẻ',
          grade: learning.gradeLevel?.toString() ?? profile.gradeBand,
        )
        .timeout(const Duration(seconds: 10));
    if (owner != cloudService.currentUserId) return;
    final current = flashcards.where((c) => c.id == cardId).firstOrNull;
    if (current == null || current.front != oldFront || current.back != oldBack)
      return;
    current.originalBack ??= oldBack;
    current.back = explanation;
    await save();
  }

  Future<String> addKnowledgePack(
    String title,
    String subject,
    List<String> topicIds,
    List<Map<String, String>> cards, {
    String? operationKey,
  }) async {
    if (cards.isEmpty ||
        cards.any(
          (c) =>
              (c['front'] ?? '').trim().isEmpty ||
              (c['back'] ?? '').trim().isEmpty,
        )) {
      throw ArgumentError('Nội dung ôn tập chưa đầy đủ.');
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final id = operationKey == null
        ? 'deck_$stamp'
        : 'deck_${Uri.encodeComponent(operationKey)}';
    if (decks.any((d) => d.id == id)) return id;
    decks.add(
      FlashcardDeck(id: id, title: title, subject: subject, topicIds: topicIds),
    );
    for (var i = 0; i < cards.length; i++) {
      flashcards.add(
        FlashcardItem(
          id: 'fc_${stamp}_$i',
          deckId: id,
          front: cards[i]['front']!,
          back: cards[i]['back']!,
        ),
      );
    }
    await save();
    return id;
  }

  Future<String> createReviewSession(
    Map<String, dynamic> draft, {
    DateTime? at,
    bool offline = false,
  }) async {
    final now = at ?? DateTime.now();
    final existing = learning.reviewSessions
        .where((s) => s['date'] == dateKey(now) && s['status'] == 'active')
        .firstOrNull;
    if (existing != null) return existing['id'] as String;
    final due = ReviewPolicy.dueCards(
      now: now,
      cards: flashcards,
      decks: decks,
      learning: learning,
    );
    final budget = ReviewPolicy.availableMinutes(
      now: now,
      routine: dailyRoutine,
      learning: learning,
      tasks: tasks,
      sessions: sessions,
    );
    final checked = offline
        ? ReviewPolicy.offlineDraft(due, budget)
        : ReviewPolicy.validateDraft(draft, due, budget);
    final id = 'review_${now.microsecondsSinceEpoch}';
    final routineData = dailyRoutine.toJson();
    final busy = <String, List<String>>{...dailyRoutine.dateBusy};
    busy[dateKey(now)] = [
      ...?dailyRoutine.dateBusy[dateKey(now)],
      for (final lesson in learning.timetable.where((l) => l.occursOn(now)))
        '${lesson.startTime}-${lesson.endTime}',
      for (final block in learning.activePlan?.blocks ?? <LearningBlock>[])
        if (block.date == dateKey(now))
          '${block.startTime}-${learningClock(scheduleMinute(block.startTime) + block.minutes)}',
    ];
    routineData['dateBusy'] = busy;
    final slot = scheduleStudyDrafts(
      [
        {'durationMinutes': checked['durationMinutes']},
      ],
      now: now,
      start: dailyRoutine.eveningFreeStart,
      end: dailyRoutine.eveningFreeEnd,
      dailyMinutes: dailyRoutine.preferredDailyMinutes,
      routine: DailyRoutine.fromJson(routineData),
      existing: tasks,
      horizonDays: 1,
    ).single;
    tasks.add(
      TaskModel(
        id: id,
        title: 'Ôn tập: ${checked['quiz']['topic']}',
        subject: 'Ôn tập',
        durationMinutes: checked['durationMinutes'],
        kind: 'review',
        scheduledDate: slot['scheduledDate'],
        scheduledTime: slot['scheduledTime'],
        topicIds: decks
            .where(
              (d) => due
                  .where((c) => (checked['cardIds'] as List).contains(c.id))
                  .any((c) => c.deckId == d.id),
            )
            .expand((d) => d.topicIds)
            .toSet()
            .toList(),
      ),
    );
    learning.reviewSessions.add({
      ...checked,
      'id': id,
      'date': dateKey(now),
      'scheduledDate': slot['scheduledDate'],
      'scheduledTime': slot['scheduledTime'],
      'status': 'active',
      'createdAt': now.toIso8601String(),
      'cardSnapshots': {
        for (final c in due.where(
          (c) => (checked['cardIds'] as List).contains(c.id),
        ))
          c.id: {'front': c.front, 'back': c.originalBack ?? c.back},
      },
      'grades': <String, dynamic>{},
      'quiz': {
        ...Map<String, dynamic>.from(checked['quiz']),
        'answers': <String, dynamic>{},
      },
    });
    await save();
    return id;
  }

  Future<void> gradeReviewCard(
    String sessionId,
    String cardId,
    int grade,
  ) async {
    final session = learning.reviewSessions.firstWhere(
      (s) => s['id'] == sessionId,
    );
    _checkReviewSources(session);
    if (session['status'] != 'active' ||
        !(session['cardIds'] as List).contains(cardId) ||
        grade < 0 ||
        grade > 3) {
      throw StateError('Thẻ không còn trong lượt ôn này.');
    }
    final grades = Map<String, dynamic>.from(session['grades']);
    if (grades.containsKey(cardId)) return;
    grades[cardId] = {'grade': grade, 'at': DateTime.now().toIso8601String()};
    session['grades'] = grades;
    reviewFlashcard(cardId, grade);
    if (session['mode'] == 'offline' &&
        grades.length == (session['cardIds'] as List).length) {
      _completeReview(session);
    }
    await save();
  }

  Future<void> answerReviewQuiz(
    String sessionId,
    int question,
    int option,
  ) async {
    final session = learning.reviewSessions.firstWhere(
      (s) => s['id'] == sessionId,
    );
    if (session['status'] != 'active') throw StateError('Lượt ôn đã kết thúc.');
    if ((session['grades'] as Map).length !=
        (session['cardIds'] as List).length) {
      throw StateError('Hoàn thành thẻ trước khi làm quiz.');
    }
    final quiz = validateTutorQuiz(session['quiz']);
    if (question < 0 ||
        question >= (quiz['questions'] as List).length ||
        option < 0 ||
        option > 3)
      throw ArgumentError('Đáp án không hợp lệ.');
    final answers = Map<String, dynamic>.from(quiz['answers'] as Map? ?? {});
    if (answers.containsKey('$question')) return;
    answers['$question'] = {
      'optionIndex': option,
      'answeredAt': DateTime.now().toIso8601String(),
    };
    session['quiz'] = {...quiz, 'answers': answers};
    final q = (quiz['questions'] as List)[question];
    if (['A', 'B', 'C', 'D'][option] != q['correctAnswer']) {
      final card = flashcards
          .where((c) => c.id == q['sourceCardId'])
          .firstOrNull;
      if (card != null) {
        card.repetitions = 0;
        card.intervalDays = 1;
        card.nextReviewAt = DateTime.now().add(const Duration(days: 1));
      }
    }
    if (answers.length == (quiz['questions'] as List).length) {
      _completeReview(session);
    }
    await save();
  }

  Future<void> skipReviewQuiz(String sessionId) async {
    final session = learning.reviewSessions.firstWhere(
      (s) => s['id'] == sessionId,
    );
    _checkReviewSources(session);
    if (session['status'] != 'active' ||
        (session['grades'] as Map).length !=
            (session['cardIds'] as List).length) {
      throw StateError('Hoàn thành thẻ trước khi bỏ qua quiz.');
    }
    session['quizSkipped'] = true;
    _completeReview(session);
    await save();
  }

  void _completeReview(Map<String, dynamic> session) {
    session['status'] = 'completed';
    session['completedAt'] = DateTime.now().toIso8601String();
    final task = tasks.where((t) => t.id == session['id']).firstOrNull;
    if (task != null) {
      task.isDone = true;
      task.completedDate = DateTime.now();
    }
  }

  void _checkReviewSources(Map<String, dynamic> session) {
    final snapshots = session['cardSnapshots'] as Map?;
    for (final id in session['cardIds'] as List) {
      final card = flashcards.where((c) => c.id == id).firstOrNull;
      final source = snapshots?[id];
      if (card == null ||
          (source != null &&
              (source['front'] != card.front ||
                  source['back'] != (card.originalBack ?? card.back)))) {
        session['status'] = 'invalidated';
        tasks.removeWhere((t) => t.id == session['id']);
        throw StateError('Kiến thức đã thay đổi. Hãy tạo lượt ôn mới.');
      }
    }
  }

  Future<void> editKnowledgeCard(String id, String front, String back) async {
    if (front.trim().isEmpty || back.trim().isEmpty)
      throw ArgumentError('Nhập đủ câu hỏi và giải thích.');
    final card = flashcards.firstWhere((c) => c.id == id);
    if (card.front == front.trim() && card.back == back.trim()) return;
    card.front = front.trim();
    card.back = back.trim();
    card.originalBack = null;
    card.repetitions = 0;
    card.nextReviewAt = DateTime.now();
    card.intervalDays = 1;
    for (final completed in learning.reviewSessions.where(
      (s) => s['status'] == 'completed',
    )) {
      if ((completed['cardIds'] as List).contains(id))
        completed['needsNewReview'] = true;
    }
    for (final s in learning.reviewSessions.where(
      (s) => s['status'] == 'active',
    )) {
      if ((s['cardIds'] as List).contains(id)) {
        s['status'] = 'invalidated';
        tasks.removeWhere((t) => t.id == s['id']);
      }
    }
    await save();
  }

  String addDeck(
    String title,
    String subject, {
    List<String> topicIds = const [],
  }) {
    final id = 'deck_' + DateTime.now().microsecondsSinceEpoch.toString();
    decks.add(
      FlashcardDeck(id: id, title: title, subject: subject, topicIds: topicIds),
    );
    save();
    return id;
  }

  void addFlashcard(String deckId, String front, String back) {
    flashcards.add(
      FlashcardItem(
        id: 'fc_${DateTime.now().microsecondsSinceEpoch}_${flashcards.length}',
        deckId: deckId,
        front: front,
        back: back,
      ),
    );
    save();
  }

  void reviewFlashcard(String cardId, int grade) {
    // grade: 0=Again, 1=Hard, 2=Good, 3=Easy
    final c = flashcards.firstWhere((x) => x.id == cardId);
    if (grade >= 2) {
      if (c.repetitions == 0) {
        c.intervalDays = 1;
      } else if (c.repetitions == 1) {
        c.intervalDays = 6;
      } else {
        c.intervalDays = (c.intervalDays * (c.easeFactor / 100)).round();
      }
      c.repetitions++;
    } else {
      c.repetitions = 0;
      c.intervalDays = 1;
    }

    c.easeFactor =
        (c.easeFactor + (0.1 - (3 - grade) * (0.08 + (3 - grade) * 0.02)) * 100)
            .round()
            .clamp(130, 300);
    c.nextReviewAt = DateTime.now().add(Duration(days: c.intervalDays));

    _awardReward(starsToAdd: 1, xpToAdd: 15);
    save();
  }

  // Backup & Restore (Full JSON compatibility with Netlify web version)
  String exportBackupJson() {
    final Map<String, dynamic> data = {
      'profile': profile.toJson(),
      'goals': goals.map((g) => g.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'activity': activityDays,
      'dayColors': dayCustomColors,
      'stars': stars,
      'xp': xp,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalStudyMinutes': totalStudyMinutes,
      'owned': ownedItems,
      'equipped': {
        'accessory': equippedAccessory,
        'clothes': equippedClothes,
        'special': equippedSpecial,
      },
      'robotColorHex': robotColorHex,
      'decks': decks.map((d) => d.toJson()).toList(),
      'flashcards': flashcards.map((f) => f.toJson()).toList(),
      'companions': companions,
      'privacy': {'parent': parentPerms, 'teacher': teacherPerms},
      'version': '1.0.0-flutter-mochi',
      'exportedAt': DateTime.now().toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  bool importBackupJson(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      _hydrate(data);
      _calculateStreak();
      isFirstTime = profile.name.trim().isEmpty;
      save();
      return true;
    } catch (e) {
      debugPrint('import error: $e');
      return false;
    }
  }

  void resetAllData() {
    _initSampleDefaults();
    activityDays.clear();
    dayCustomColors.clear();
    stars = 0;
    xp = 0;
    currentStreak = 0;
    longestStreak = 0;
    totalStudyMinutes = 0;
    ownedItems = ['default'];
    equippedAccessory = '';
    equippedClothes = '';
    equippedSpecial = '';
    save();
  }
}
