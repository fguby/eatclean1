part of '../main.dart';

class ThemeStore extends ChangeNotifier {
  ThemeStore._();

  static final ThemeStore instance = ThemeStore._();

  ThemeMode _mode = ThemeMode.light;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('theme_mode') ?? 'light';
    _mode = raw == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _loaded = true;
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme_mode',
      _mode == ThemeMode.light ? 'light' : 'dark',
    );
  }

  Future<void> toggle() async {
    await setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

class MealStore extends ChangeNotifier {
  MealStore._();

  static final MealStore instance = MealStore._();

  final List<MealRecord> _records = [];
  final Map<String, DailyIntake> _dailyIntake = {};
  final Set<String> _dirtyIntakeDates = {};
  bool _loaded = false;
  Timer? _syncTimer;
  Timer? _dailySyncTimer;
  bool _syncing = false;
  bool _dailySyncing = false;

  bool get isLoaded => _loaded;

  List<MealRecord> get records => List.unmodifiable(_records);

  Map<String, DailyIntake> get dailyIntake =>
      Map<String, DailyIntake>.unmodifiable(_dailyIntake);

  List<MealRecord> get pendingRecords =>
      _records.where((record) => !record.isComplete).toList();

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('meal_records');
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _records
          ..clear()
          ..addAll(
            decoded.whereType<Map<String, dynamic>>().map(MealRecord.fromJson),
          );
      }
    }
    _loaded = true;
    _rebuildDailyIntake(markDirty: false);
    notifyListeners();
    unawaited(_syncFromServer());
  }

  Future<void> addRecord(MealRecord record) async {
    await ensureLoaded();
    _records.insert(0, record);
    await _save();
    _rebuildDailyIntake(markDirty: true);
    notifyListeners();
  }

  Future<MealRecord> createRecord({
    required String source,
    required List<MealDish> dishes,
    Map<String, int>? ratings,
    Map<String, dynamic>? meta,
    DateTime? recordedAt,
  }) async {
    await ensureLoaded();
    final now = recordedAt ?? DateTime.now();
    final fallbackRecord = MealRecord(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      dishes: dishes,
      ratings: ratings ?? {},
    );

    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) {
      await addRecord(fallbackRecord);
      UserProfileStore.instance.markDailyUsage(DailyUsageType.mealRecord);
      return fallbackRecord;
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/meals'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({
          'source': source,
          'items': dishes.map((dish) => dish.toJson()).toList(),
          if (ratings != null) 'ratings': ratings,
          if (meta != null) 'meta': meta,
          'recorded_at': now.toIso8601String(),
        }),
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = (payload['data'] as Map?) ?? {};
        final record = MealRecord.fromJson(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
        await addRecord(record);
        UserProfileStore.instance.markDailyUsage(DailyUsageType.mealRecord);
        return record;
      }
    } catch (_) {
      // ignore network errors; fallback to local record.
    }

    await addRecord(fallbackRecord);
    UserProfileStore.instance.markDailyUsage(DailyUsageType.mealRecord);
    return fallbackRecord;
  }

  Future<MealRecord?> createPhotoRecord({
    required List<String> imageUrls,
    String note = '',
  }) async {
    await ensureLoaded();
    if (imageUrls.isEmpty) {
      return null;
    }
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) {
      return null;
    }

    final trimmedNote = note.trim();
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/meals/photo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({
          'image_urls': imageUrls,
          'client_time': _formatClientTime(DateTime.now()),
          if (trimmedNote.isNotEmpty) 'note': trimmedNote,
        }),
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final errorMessage =
          (payload['message'] ??
                  payload['msg'] ??
                  payload['error'] ??
                  payload['detail'])
              ?.toString()
              .trim();
      if (response.statusCode == 429 || payload['code'] == 429) {
        final msg = (errorMessage != null && errorMessage.isNotEmpty)
            ? errorMessage
            : '额度已用完，订阅可继续使用';
        throw DailyQuotaExceededException(msg);
      }
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = (payload['data'] as Map?) ?? {};
        final record = MealRecord.fromJson(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (record.dishes.isEmpty) {
          return null;
        }
        await addRecord(record);
        return record;
      } else {
        print(payload);
      }
    } catch (_) {
      // ignore network errors
    }
    return null;
  }

  Future<void> updateRecord(MealRecord record) async {
    await ensureLoaded();
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index == -1) return;
    _records[index] = record;
    await _save();
    _rebuildDailyIntake(markDirty: true);
    notifyListeners();
  }

  Future<void> refreshFromServer() async {
    await ensureLoaded();
    await _syncFromServer();
  }

  Future<void> _syncFromServer() async {
    if (_syncing) return;
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) return;
    _syncing = true;
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/meals?limit=50'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = payload['data'];
        if (data is List) {
          final remoteRecords = data
              .whereType<Map<String, dynamic>>()
              .map(MealRecord.fromJson)
              .toList();
          if (remoteRecords.isNotEmpty) {
            final remoteIds = remoteRecords.map((record) => record.id).toSet();
            final localOnly = _records
                .where((record) => !remoteIds.contains(record.id))
                .toList();
            final merged = [...localOnly, ...remoteRecords];
            merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _records
              ..clear()
              ..addAll(merged);
            await _save();
            _rebuildDailyIntake(markDirty: false);
            notifyListeners();
          }
        }
      }
    } catch (_) {
      // ignore sync errors
    } finally {
      _syncing = false;
    }
  }

  void _rebuildDailyIntake({required bool markDirty}) {
    final previous = Map<String, DailyIntake>.from(_dailyIntake);
    _dailyIntake.clear();
    for (final record in _records) {
      final dateKey = _dateKey(record.createdAt);
      final entry = _dailyIntake.putIfAbsent(
        dateKey,
        () => DailyIntake(date: dateKey),
      );
      for (final dish in record.dishes) {
        entry.calories += dish.kcal;
        entry.protein += dish.protein;
        entry.carbs += dish.carbs;
        entry.fat += dish.fat;
      }
    }
    if (markDirty) {
      for (final entry in _dailyIntake.entries) {
        final previousValue = previous[entry.key];
        if (previousValue == null ||
            previousValue.calories != entry.value.calories ||
            previousValue.protein != entry.value.protein ||
            previousValue.carbs != entry.value.carbs ||
            previousValue.fat != entry.value.fat) {
          _dirtyIntakeDates.add(entry.key);
        }
      }
      if (_dirtyIntakeDates.isNotEmpty) {
        _scheduleDailyIntakeSync();
      }
    }
    unawaited(_saveDailyIntake());
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _saveDailyIntake() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _dailyIntake.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await prefs.setString('daily_intake', jsonEncode(payload));
  }

  void _scheduleDailyIntakeSync() {
    _dailySyncTimer?.cancel();
    _dailySyncTimer = Timer(
      const Duration(milliseconds: 600),
      _syncDailyIntake,
    );
  }

  Future<void> _syncDailyIntake() async {
    if (_dailySyncing || _dirtyIntakeDates.isEmpty) return;
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) return;
    _dailySyncing = true;
    try {
      final dates = List<String>.from(_dirtyIntakeDates);
      for (final date in dates) {
        final entry = _dailyIntake[date];
        if (entry == null) continue;
        final response = await http.post(
          Uri.parse('$_apiBaseUrl/intake/daily'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode({
            'date': entry.date,
            'calories': entry.calories,
            'protein': entry.protein,
            'carbs': entry.carbs,
            'fat': entry.fat,
          }),
        );
        if (response.statusCode < 400) {
          _dirtyIntakeDates.remove(date);
        }
      }
    } catch (_) {
      // ignore sync errors
    } finally {
      _dailySyncing = false;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _records.map((record) => record.toJson()).toList(),
    );
    await prefs.setString('meal_records', encoded);
  }
}

enum DailyUsageType { menuScan, mealRecord, question }

class DailyQuotaExceededException implements Exception {
  DailyQuotaExceededException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserProfileStore extends ChangeNotifier {
  UserProfileStore._();

  static final UserProfileStore instance = UserProfileStore._();

  bool _loaded = false;
  Timer? _syncTimer;
  Timer? _autoSyncTimer;
  bool _syncing = false;
  bool _dirty = false;
  bool _pendingSync = false;
  String _lastSavedPayload = '';
  String _lastSyncedPayload = '';

  bool get isLoaded => _loaded;
  bool get hasPendingSync => _pendingSync;

  int height = 175;
  int weight = 68;
  Map<String, double> weightHistory = {};
  int age = 28;
  String gender = '男';
  String userName = '大胡子';
  String avatarUrl = '';
  String _signedAvatarUrl = '';
  String activityLevel = '中等活动';
  String trainingExperience = '中级';

  String goalType = '增肌';
  String weightPlanMode = 'loss';
  double weightPlanKg = 5;
  int weightPlanDays = 60;
  int weeklyTrainingDays = 4;
  List<int> weeklyTrainingDaysList = [];
  List<int> weeklyCheatDaysList = [];
  List<int> monthlyTrainingDaysList = [];
  List<int> monthlyCheatDaysList = [];
  String preferredTrainingTime = '晚上';
  List<String> trainingTypePreference = ['力量训练'];

  List<String> dietPreferences = ['高蛋白'];
  List<String> excludedFoods = [];
  int calorieTarget = 2400;
  int macroProtein = 160;
  int macroCarbs = 260;
  int macroFat = 70;
  int cheatFrequency = 1;
  String lateEatingHabit = '偶尔';

  String aiSuggestionStyle = '亲近';
  bool actionSuggestionEnabled = true;
  int reminderFrequency = 2;
  bool dataUsageConsent = true;

  bool mealReminderEnabled = true;
  String mealReminderTime = '08:00';
  bool trainingReminderEnabled = true;
  String trainingReminderTime = '19:00';
  bool waterReminderEnabled = false;
  int waterReminderInterval = 60;
  bool dailyTipsEnabled = true;
  bool shakeToScanEnabled = true;
  double shakeSensitivity = 2.6;
  bool discoverDevMode = false;
  bool isSubscriber = false;
  String subscriptionSku = '';
  String avatarLocalPath = '';
  String usageDate = '';
  int menuScanUsage = 0;
  int mealRecordUsage = 0;
  int questionUsage = 0;

  int aiPersonalityAdjustment = 60;
  String resetFoodPersonality = '';
  String exportData = '';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings_page');
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _applyFromJson(decoded);
      } else if (decoded is Map) {
        _applyFromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }
    _loadUsageLimits(prefs);
    discoverDevMode = prefs.getBool('discover_dev_mode') ?? false;
    _pendingSync = prefs.getBool('settings_pending_sync') ?? false;
    _loaded = true;
    _lastSavedPayload = jsonEncode(_toJson());
    _lastSyncedPayload = _lastSavedPayload;
    _startAutoSync();
    await NotificationService.instance.syncFromSettings(this);
    notifyListeners();
  }

  Map<String, dynamic> _toJson() => {
    'height': height,
    'weight': weight,
    'avatar_url': avatarUrl,
    'avatar_local': avatarLocalPath,
    'age': age,
    'gender': gender,
    'user_name': userName,
    'weight_history': weightHistory.entries
        .map((entry) => {'date': entry.key, 'weight': entry.value})
        .toList(),
    'activity_level': activityLevel,
    'training_experience': trainingExperience,
    'goal_type': goalType,
    'weight_plan_mode': weightPlanMode,
    'weight_plan_kg': weightPlanKg,
    'weight_plan_days': weightPlanDays,
    'weekly_training_days': weeklyTrainingDays,
    'weekly_training_days_list': weeklyTrainingDaysList,
    'weekly_cheat_days_list': weeklyCheatDaysList,
    'monthly_training_days': monthlyTrainingDaysList,
    'monthly_cheat_days': monthlyCheatDaysList,
    'preferred_training_time': preferredTrainingTime,
    'training_type_preference': trainingTypePreference,
    'diet_preferences': dietPreferences,
    'excluded_foods': excludedFoods,
    'calorie_target': calorieTarget,
    'macro_targets': {
      'protein': macroProtein,
      'carbs': macroCarbs,
      'fat': macroFat,
    },
    'cheat_frequency': cheatFrequency,
    'late_eating_habit': lateEatingHabit,
    'ai_suggestion_style': aiSuggestionStyle,
    'action_suggestion_enabled': actionSuggestionEnabled,
    'reminder_frequency': reminderFrequency,
    'data_usage_consent': dataUsageConsent,
    'meal_reminder_enabled': mealReminderEnabled,
    'meal_reminder_time': mealReminderTime,
    'training_reminder_enabled': trainingReminderEnabled,
    'training_reminder_time': trainingReminderTime,
    'water_reminder_enabled': waterReminderEnabled,
    'water_reminder_interval': waterReminderInterval,
    'daily_tips_enabled': dailyTipsEnabled,
    'shake_to_scan_enabled': shakeToScanEnabled,
    'shake_sensitivity': shakeSensitivity,
    'ai_personality_adjustment': aiPersonalityAdjustment,
    'reset_food_personality': resetFoodPersonality,
    'export_data': exportData,
  };

  void _applyFromJson(Map<String, dynamic> json) {
    height = _readInt(json['height'], height, min: 0, max: 260);
    weight = _readInt(json['weight'], weight, min: 0, max: 200);
    avatarUrl = _readString(json['avatar_url'], avatarUrl);
    avatarLocalPath = _readString(json['avatar_local'], avatarLocalPath);
    if (avatarUrl.isNotEmpty && _signedAvatarUrl.isEmpty) {
      unawaited(_signAvatarUrl());
    }
    weightHistory = _readWeightHistory(json['weight_history']);
    if (weightHistory.isEmpty && weight > 0) {
      weightHistory[_dateKey(DateTime.now())] = weight.toDouble();
    }
    age = _readInt(json['age'], age, min: 0, max: 99);
    gender = _readString(json['gender'], gender, allowed: _genderOptions);
    userName = _readString(json['user_name'], userName);
    activityLevel = _readString(
      json['activity_level'],
      activityLevel,
      allowed: _activityLevelOptions,
    );
    trainingExperience = _readString(
      json['training_experience'],
      trainingExperience,
      allowed: _trainingExperienceOptions,
    );
    goalType = _readString(
      json['goal_type'],
      goalType,
      allowed: _goalTypeOptions,
    );
    weightPlanMode = _readString(
      json['weight_plan_mode'],
      weightPlanMode,
      allowed: _weightPlanModeOptions,
    );
    weightPlanKg = _readDouble(
      json['weight_plan_kg'],
      weightPlanKg,
      min: 0,
      max: 50,
    );
    weightPlanDays = _readInt(
      json['weight_plan_days'],
      weightPlanDays,
      min: 7,
      max: 365,
    );
    weeklyTrainingDays = _readInt(
      json['weekly_training_days'],
      weeklyTrainingDays,
      min: 0,
      max: 7,
    );
    weeklyTrainingDaysList = _readIntList(
      json['weekly_training_days_list'],
      fallback: weeklyTrainingDaysList,
    );
    weeklyCheatDaysList = _readIntList(
      json['weekly_cheat_days_list'],
      fallback: weeklyCheatDaysList,
    );
    monthlyTrainingDaysList = _readIntList(
      json['monthly_training_days'],
      fallback: monthlyTrainingDaysList,
    );
    monthlyCheatDaysList = _readIntList(
      json['monthly_cheat_days'],
      fallback: monthlyCheatDaysList,
    );
    preferredTrainingTime = _readString(
      json['preferred_training_time'],
      preferredTrainingTime,
      allowed: _preferredTrainingTimeOptions,
    );
    trainingTypePreference = _readStringList(
      json['training_type_preference'],
      fallback: trainingTypePreference,
    );
    dietPreferences = _readStringList(
      json['diet_preferences'],
      fallback: dietPreferences,
    );
    excludedFoods = _readStringList(
      json['excluded_foods'],
      fallback: excludedFoods,
    );
    calorieTarget = _readInt(
      json['calorie_target'],
      calorieTarget,
      min: 0,
      max: 6000,
    );
    final macroTargets = _readMacroTargets(json['macro_targets']);
    macroProtein = macroTargets['protein'] ?? macroProtein;
    macroCarbs = macroTargets['carbs'] ?? macroCarbs;
    macroFat = macroTargets['fat'] ?? macroFat;
    cheatFrequency = _readInt(
      json['cheat_frequency'],
      cheatFrequency,
      min: 0,
      max: 5,
    );
    if (weeklyTrainingDaysList.isEmpty && weeklyTrainingDays > 0) {
      weeklyTrainingDaysList = List<int>.generate(
        weeklyTrainingDays,
        (index) => index + 1,
      );
    }
    if (weeklyCheatDaysList.isEmpty && cheatFrequency > 0) {
      weeklyCheatDaysList = List<int>.generate(
        cheatFrequency,
        (index) => 7 - index,
      );
    }
    weeklyTrainingDaysList = _sanitizeWeekdays(weeklyTrainingDaysList);
    weeklyCheatDaysList = _sanitizeWeekdays(weeklyCheatDaysList);
    monthlyTrainingDaysList = _sanitizeMonthDays(monthlyTrainingDaysList);
    monthlyCheatDaysList = _sanitizeMonthDays(monthlyCheatDaysList);
    if (weeklyCheatDaysList.isNotEmpty) {
      weeklyTrainingDaysList = weeklyTrainingDaysList
          .where((day) => !weeklyCheatDaysList.contains(day))
          .toList();
    }
    weeklyTrainingDays = weeklyTrainingDaysList.isNotEmpty
        ? weeklyTrainingDaysList.length
        : weeklyTrainingDays;
    cheatFrequency = weeklyCheatDaysList.isNotEmpty
        ? weeklyCheatDaysList.length
        : cheatFrequency;
    lateEatingHabit = _readString(
      json['late_eating_habit'],
      lateEatingHabit,
      allowed: _lateEatingHabitOptions,
    );
    aiSuggestionStyle = _readString(
      json['ai_suggestion_style'],
      aiSuggestionStyle,
      allowed: _aiSuggestionStyleOptions,
    );
    actionSuggestionEnabled = _readBool(
      json['action_suggestion_enabled'],
      actionSuggestionEnabled,
    );
    reminderFrequency = _readInt(
      json['reminder_frequency'],
      reminderFrequency,
      min: 0,
      max: 5,
    );
    dataUsageConsent = _readBool(json['data_usage_consent'], dataUsageConsent);
    mealReminderEnabled = _readBool(
      json['meal_reminder_enabled'],
      mealReminderEnabled,
    );
    mealReminderTime = _readString(
      json['meal_reminder_time'],
      mealReminderTime,
    );
    trainingReminderEnabled = _readBool(
      json['training_reminder_enabled'],
      trainingReminderEnabled,
    );
    trainingReminderTime = _readString(
      json['training_reminder_time'],
      trainingReminderTime,
    );
    waterReminderEnabled = _readBool(
      json['water_reminder_enabled'],
      waterReminderEnabled,
    );
    waterReminderInterval = _readInt(
      json['water_reminder_interval'],
      waterReminderInterval,
      min: 30,
      max: 120,
    );
    dailyTipsEnabled = _readBool(json['daily_tips_enabled'], dailyTipsEnabled);
    shakeToScanEnabled = _readBool(
      json['shake_to_scan_enabled'],
      shakeToScanEnabled,
    );
    shakeSensitivity = _readDouble(
      json['shake_sensitivity'],
      shakeSensitivity,
      min: 1.2,
      max: 4.0,
    );
    aiPersonalityAdjustment = _readInt(
      json['ai_personality_adjustment'],
      aiPersonalityAdjustment,
      min: 0,
      max: 100,
    );
    resetFoodPersonality = _readString(
      json['reset_food_personality'],
      resetFoodPersonality,
    );
    exportData = _readString(json['export_data'], exportData);
  }

  void _loadUsageLimits(SharedPreferences prefs) {
    final raw = prefs.getString('daily_usage_limits');
    if (raw == null || raw.isEmpty) {
      usageDate = _dateKey(DateTime.now());
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        usageDate = map['date']?.toString() ?? usageDate;
        menuScanUsage = _readInt(
          map['menu_scan'],
          menuScanUsage,
          min: 0,
          max: 99,
        );
        mealRecordUsage = _readInt(
          map['meal_record'],
          mealRecordUsage,
          min: 0,
          max: 99,
        );
        questionUsage = _readInt(
          map['question'],
          questionUsage,
          min: 0,
          max: 99,
        );
        isSubscriber = _readBool(map['is_subscriber'], isSubscriber);
        subscriptionSku =
            map['subscription_sku']?.toString() ?? subscriptionSku;
      }
    } catch (_) {}
    if (usageDate.isEmpty) {
      usageDate = _dateKey(DateTime.now());
    }
  }

  Future<void> _saveUsageLimits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'daily_usage_limits',
      jsonEncode({
        'date': usageDate,
        'menu_scan': menuScanUsage,
        'meal_record': mealRecordUsage,
        'question': questionUsage,
        'is_subscriber': isSubscriber,
        'subscription_sku': subscriptionSku,
      }),
    );
  }

  void _ensureUsageDate() {
    final today = _dateKey(DateTime.now());
    if (usageDate == today) return;
    usageDate = today;
    menuScanUsage = 0;
    mealRecordUsage = 0;
    questionUsage = 0;
    unawaited(_saveUsageLimits());
  }

  bool canUseDailyUsage(DailyUsageType type) {
    if (isSubscriber) return true;
    _ensureUsageDate();
    switch (type) {
      case DailyUsageType.menuScan:
        return menuScanUsage < 1;
      case DailyUsageType.mealRecord:
        return mealRecordUsage < 1;
      case DailyUsageType.question:
        return questionUsage < 1;
    }
  }

  bool markDailyUsage(DailyUsageType type) {
    if (isSubscriber) return true;
    _ensureUsageDate();
    switch (type) {
      case DailyUsageType.menuScan:
        if (menuScanUsage >= 1) return false;
        menuScanUsage += 1;
        break;
      case DailyUsageType.mealRecord:
        if (mealRecordUsage >= 1) return false;
        mealRecordUsage += 1;
        break;
      case DailyUsageType.question:
        if (questionUsage >= 1) return false;
        questionUsage += 1;
        break;
    }
    unawaited(_saveUsageLimits());
    notifyListeners();
    return true;
  }

  Future<void> refreshDailyUsageFromServer() async {
    await ensureLoaded();
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/usage/check'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({
          'type': 'all',
          'client_time': _formatClientTime(DateTime.now()),
        }),
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || payload['code'] != 0) return;
      final data = payload['data'];
      if (data is! Map) return;
      final usage = data['usage'];
      int readUsed(String key, int fallback) {
        if (usage is Map) {
          final entry = usage[key];
          if (entry is Map) {
            return _readInt(entry['used'], fallback, min: 0, max: 99);
          }
        }
        return fallback;
      }

      final nowKey = _dateKey(DateTime.now());
      usageDate = nowKey;
      menuScanUsage = readUsed('menu_scan', menuScanUsage);
      mealRecordUsage = readUsed('meal_record', mealRecordUsage);
      questionUsage = readUsed('question', questionUsage);
      isSubscriber = _readBool(data['is_subscriber'], isSubscriber);
      await _saveUsageLimits();
      notifyListeners();
    } catch (_) {
      // ignore usage sync errors
    }
  }

  void updateSubscriptionFromUser(Map<String, dynamic> user) {
    final parsed = _parseSubscriptionStatus(user);
    if (parsed == null) return;
    isSubscriber = parsed;
    unawaited(_saveUsageLimits());
    notifyListeners();
  }

  Future<void> setSubscriberStatus(bool value) async {
    if (isSubscriber == value) return;
    isSubscriber = value;
    await _saveUsageLimits();
    notifyListeners();
  }

  Future<void> setSubscriptionSku(String sku) async {
    subscriptionSku = sku;
    await _saveUsageLimits();
    notifyListeners();
  }

  bool get isAnnualSubscriber =>
      isSubscriber &&
      subscriptionSku.isNotEmpty &&
      subscriptionSku.toLowerCase().contains('year');

  bool? _parseSubscriptionStatus(Map<String, dynamic> user) {
    for (final key in const [
      'is_subscribed',
      'subscribed',
      'subscription',
      'subscription_active',
      'subscription_status',
      'plan_status',
      'vip',
      'is_vip',
      'vip_status',
      'member',
      'is_member',
      'premium',
      'is_premium',
      'is_subscribed_user',
      'isSubscribed',
      'pro',
      'is_pro',
    ]) {
      if (!user.containsKey(key)) continue;
      final value = user[key];
      if (value is bool) return value;
      if (value is num) return value > 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if ([
          'true',
          '1',
          'yes',
          'active',
          'subscribed',
          'vip',
          'premium',
          'pro',
        ].contains(normalized)) {
          return true;
        }
        if ([
          'false',
          '0',
          'no',
          'inactive',
          'free',
          'none',
        ].contains(normalized)) {
          return false;
        }
      }
    }
    return null;
  }

  Future<void> applyRemoteSettings(Map<String, dynamic> json) async {
    _applyFromJson(json);
    await _save();
    _lastSyncedPayload = _lastSavedPayload;
    _dirty = false;
    await NotificationService.instance.syncFromSettings(this);
    notifyListeners();
  }

  Future<void> _save() async {
    final payload = jsonEncode(_toJson());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_page', payload);
    _lastSavedPayload = payload;
  }

  Future<void> _persistPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_pending_sync', _pendingSync);
  }

  Future<void> _commit() async {
    await _save();
    _dirty = _lastSavedPayload != _lastSyncedPayload;
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.status == 'logged_in' && auth.token.isNotEmpty) {
      _scheduleSync();
    } else {
      _pendingSync = true;
      await _persistPendingSync();
    }
    notifyListeners();
  }

  void _startAutoSync() {
    if (_autoSyncTimer != null) return;
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!_dirty) return;
      _scheduleSync();
    });
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 800), _syncToServer);
  }

  Future<void> _syncToServer() async {
    if (_syncing || !_dirty) return;
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.status != 'logged_in' || auth.token.isEmpty) {
      return;
    }
    if (_lastSavedPayload.isEmpty) {
      _lastSavedPayload = jsonEncode(_toJson());
    }
    _syncing = true;
    try {
      final url = Uri.parse('$_apiBaseUrl/user/settings');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: _lastSavedPayload,
      );
      if (response.statusCode >= 400) {
        debugPrint('Settings sync failed: ${response.statusCode}');
      } else {
        _lastSyncedPayload = _lastSavedPayload;
        _dirty = false;
        if (_pendingSync) {
          _pendingSync = false;
          await _persistPendingSync();
        }
      }
    } catch (e) {
      debugPrint('Settings sync error: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> triggerSyncAfterLogin() async {
    if (_lastSavedPayload.isEmpty) {
      _lastSavedPayload = jsonEncode(_toJson());
    }
    _dirty = _lastSavedPayload != _lastSyncedPayload || _pendingSync;
    if (_dirty) {
      _scheduleSync();
    }
  }

  Future<void> markPendingSyncIfDirty() async {
    if (_lastSavedPayload.isEmpty) {
      _lastSavedPayload = jsonEncode(_toJson());
    }
    _dirty = _lastSavedPayload != _lastSyncedPayload;
    if (_dirty) {
      _pendingSync = true;
      await _persistPendingSync();
    }
  }

  List<String> _readStringList(Object? raw, {required List<String> fallback}) {
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }
    return List<String>.from(fallback);
  }

  List<int> _readIntList(Object? raw, {required List<int> fallback}) {
    if (raw is List) {
      final values = <int>[];
      for (final item in raw) {
        final parsed = int.tryParse(item.toString());
        if (parsed != null) {
          values.add(parsed);
        }
      }
      return values;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final parts = raw.split(',');
      final values = <int>[];
      for (final part in parts) {
        final parsed = int.tryParse(part.trim());
        if (parsed != null) {
          values.add(parsed);
        }
      }
      return values;
    }
    return List<int>.from(fallback);
  }

  List<int> _sanitizeWeekdays(List<int> input) {
    final filtered = input
        .where((day) => day >= 1 && day <= 7)
        .toSet()
        .toList();
    filtered.sort();
    return filtered;
  }

  List<int> _sanitizeMonthDays(List<int> input) {
    final filtered = input
        .where((day) => day >= 1 && day <= 31)
        .toSet()
        .toList();
    filtered.sort();
    return filtered;
  }

  String _readString(Object? raw, String fallback, {List<String>? allowed}) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) {
      return fallback;
    }
    if (allowed != null && !allowed.contains(value)) {
      return fallback;
    }
    return value;
  }

  int _readInt(
    Object? raw,
    int fallback, {
    required int min,
    required int max,
  }) {
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (value == null) return fallback;
    return value.clamp(min, max).toInt();
  }

  double _readDouble(
    Object? raw,
    double fallback, {
    required double min,
    required double max,
  }) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '');
    if (value == null) return fallback;
    if (value.isNaN || value.isInfinite) return fallback;
    return value.clamp(min, max).toDouble();
  }

  bool _readBool(Object? raw, bool fallback) {
    if (raw is bool) return raw;
    return fallback;
  }

  Map<String, int> _readMacroTargets(Object? raw) {
    if (raw is Map) {
      return {
        'protein': _readInt(raw['protein'], macroProtein, min: 0, max: 400),
        'carbs': _readInt(raw['carbs'], macroCarbs, min: 0, max: 600),
        'fat': _readInt(raw['fat'], macroFat, min: 0, max: 200),
      };
    }
    return {'protein': macroProtein, 'carbs': macroCarbs, 'fat': macroFat};
  }

  Map<String, double> _readWeightHistory(Object? raw) {
    final Map<String, double> result = {};
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final date = item['date']?.toString() ?? '';
          final weightValue = _readDouble(item['weight'], 0, min: 0, max: 500);
          if (date.isNotEmpty && weightValue > 0) {
            result[date] = weightValue;
          }
        }
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final date = entry.key.toString();
        final weightValue = _readDouble(entry.value, 0, min: 0, max: 500);
        if (date.isNotEmpty && weightValue > 0) {
          result[date] = weightValue;
        }
      }
    }
    return result;
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String get displayAvatarUrl =>
      _signedAvatarUrl.isNotEmpty ? _signedAvatarUrl : avatarUrl;

  String? get displayAvatarLocalPath {
    if (avatarLocalPath.isEmpty) return null;
    final file = File(avatarLocalPath);
    return file.existsSync() ? file.path : null;
  }

  Future<void> setHeight(int value) async {
    height = value.clamp(0, 260).toInt();
    await _commit();
  }

  Future<void> setWeight(int value) async {
    await setWeightWithHistory(value.toDouble());
  }

  Future<void> setWeightWithHistory(double value, {DateTime? date}) async {
    weight = value.clamp(0, 200).round();
    final key = _dateKey(date ?? DateTime.now());
    weightHistory[key] = value.clamp(0, 500).toDouble();
    await _commit();
  }

  Future<void> resetWeightHistoryToToday() async {
    final todayKey = _dateKey(DateTime.now());
    final double todayValue = weight > 0 ? weight.toDouble() : 0.0;
    weightHistory
      ..clear()
      ..[todayKey] = todayValue;
    await _commit();
  }

  Future<void> setAge(int value) async {
    age = value.clamp(0, 99).toInt();
    await _commit();
  }

  Future<void> setGender(String value) async {
    gender = value;
    await _commit();
  }

  Future<void> setUserName(String value) async {
    userName = value;
    await _commit();
  }

  Future<void> setAvatarUrl(String value, {String? localPath}) async {
    avatarUrl = value.trim();
    if (localPath != null && localPath.isNotEmpty) {
      avatarLocalPath = localPath;
    }
    _signedAvatarUrl = '';
    await _signAvatarUrl();
    if (avatarLocalPath.isEmpty) {
      unawaited(_cacheAvatarToLocal());
    } else {
      await _commit();
      notifyListeners();
    }
  }

  Future<void> _cacheAvatarToLocal() async {
    if (avatarUrl.isEmpty) return;
    try {
      final signed = _signedAvatarUrl.isNotEmpty ? _signedAvatarUrl : avatarUrl;
      if (signed.isEmpty) return;
      final response = await http.get(Uri.parse(signed));
      if (response.statusCode != 200) return;
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/avatar_${avatarUrl.hashCode}.jpg');
      await file.writeAsBytes(response.bodyBytes);
      avatarLocalPath = file.path;
      await _commit();
      notifyListeners();
    } catch (_) {
      await _commit();
      notifyListeners();
    }
  }

  Future<void> _signAvatarUrl() async {
    if (avatarUrl.isEmpty) return;
    try {
      final urls = await OssUploadService.signUrls([avatarUrl]);
      if (urls.isNotEmpty) {
        _signedAvatarUrl = urls.first;
      }
    } catch (_) {}
  }

  Future<void> setActivityLevel(String value) async {
    activityLevel = value;
    await _commit();
  }

  Future<void> setTrainingExperience(String value) async {
    trainingExperience = value;
    await _commit();
  }

  Future<void> setGoalType(String value) async {
    goalType = value;
    await _commit();
  }

  Future<void> setWeightPlan({
    required String mode,
    required double kg,
    required int days,
  }) async {
    if (!_weightPlanModeOptions.contains(mode)) {
      return;
    }
    weightPlanMode = mode;
    weightPlanKg = kg.clamp(0, 50).toDouble();
    weightPlanDays = days.clamp(1, 365).toInt();
    await _commit();
  }

  Future<void> setWeeklyTrainingDays(int value) async {
    weeklyTrainingDays = value.clamp(0, 7).toInt();
    await _commit();
  }

  Future<void> setWeeklyTrainingDaysList(List<int> days) async {
    weeklyTrainingDaysList = _sanitizeWeekdays(days);
    weeklyTrainingDays = weeklyTrainingDaysList.length;
    if (weeklyCheatDaysList.isNotEmpty) {
      weeklyCheatDaysList = weeklyCheatDaysList
          .where((day) => !weeklyTrainingDaysList.contains(day))
          .toList();
      cheatFrequency = weeklyCheatDaysList.length;
    }
    await _commit();
  }

  Future<void> setWeeklyCheatDaysList(List<int> days) async {
    weeklyCheatDaysList = _sanitizeWeekdays(days);
    cheatFrequency = weeklyCheatDaysList.length;
    if (weeklyTrainingDaysList.isNotEmpty) {
      weeklyTrainingDaysList = weeklyTrainingDaysList
          .where((day) => !weeklyCheatDaysList.contains(day))
          .toList();
      weeklyTrainingDays = weeklyTrainingDaysList.length;
    }
    await _commit();
  }

  Future<void> setMonthlyTrainingDaysList(List<int> days) async {
    monthlyTrainingDaysList = _sanitizeMonthDays(days);
    await _commit();
  }

  Future<void> setMonthlyCheatDaysList(List<int> days) async {
    monthlyCheatDaysList = _sanitizeMonthDays(days);
    await _commit();
  }

  Future<void> setPreferredTrainingTime(String value) async {
    preferredTrainingTime = value;
    await _commit();
  }

  Future<void> setTrainingTypePreference(List<String> value) async {
    trainingTypePreference = List<String>.from(value);
    await _commit();
  }

  Future<void> toggleTrainingTypePreference(String value) async {
    final updated = List<String>.from(trainingTypePreference);
    if (updated.contains(value)) {
      updated.remove(value);
    } else {
      updated.add(value);
    }
    await setTrainingTypePreference(updated);
  }

  Future<void> setDietPreferences(List<String> value) async {
    dietPreferences = List<String>.from(value);
    await _commit();
  }

  Future<void> toggleDietPreference(String value) async {
    final updated = List<String>.from(dietPreferences);
    if (updated.contains(value)) {
      updated.remove(value);
    } else {
      updated.add(value);
    }
    await setDietPreferences(updated);
  }

  Future<void> setExcludedFoods(List<String> value) async {
    excludedFoods = List<String>.from(value);
    await _commit();
  }

  Future<void> toggleExcludedFood(String value) async {
    final updated = List<String>.from(excludedFoods);
    if (updated.contains(value)) {
      updated.remove(value);
    } else {
      updated.add(value);
    }
    await setExcludedFoods(updated);
  }

  Future<void> setCalorieTarget(int value) async {
    calorieTarget = value.clamp(0, 6000).toInt();
    await _commit();
  }

  Future<void> setMacroTargets({int? protein, int? carbs, int? fat}) async {
    if (protein != null) {
      macroProtein = protein.clamp(0, 400).toInt();
    }
    if (carbs != null) {
      macroCarbs = carbs.clamp(0, 600).toInt();
    }
    if (fat != null) {
      macroFat = fat.clamp(0, 200).toInt();
    }
    await _commit();
  }

  Future<void> setCheatFrequency(int value) async {
    cheatFrequency = value.clamp(0, 5).toInt();
    await _commit();
  }

  Future<void> setLateEatingHabit(String value) async {
    lateEatingHabit = value;
    await _commit();
  }

  Future<void> setAiSuggestionStyle(String value) async {
    aiSuggestionStyle = value;
    await _commit();
  }

  Future<void> setActionSuggestionEnabled(bool value) async {
    actionSuggestionEnabled = value;
    await _commit();
  }

  Future<void> setReminderFrequency(int value) async {
    reminderFrequency = value.clamp(0, 5).toInt();
    await _commit();
  }

  Future<void> setDataUsageConsent(bool value) async {
    dataUsageConsent = value;
    await _commit();
  }

  Future<void> setMealReminderEnabled(bool value) async {
    mealReminderEnabled = value;
    await _commit();
    await NotificationService.instance.syncFromSettings(this);
  }

  Future<void> setMealReminderTime(String value) async {
    mealReminderTime = value;
    await _commit();
    await NotificationService.instance.syncFromSettings(this);
  }

  Future<void> setTrainingReminderEnabled(bool value) async {
    trainingReminderEnabled = value;
    await _commit();
    await NotificationService.instance.syncFromSettings(this);
  }

  Future<void> setTrainingReminderTime(String value) async {
    trainingReminderTime = value;
    await _commit();
    await NotificationService.instance.syncFromSettings(this);
  }

  Future<void> setWaterReminderEnabled(bool value) async {
    waterReminderEnabled = value;
    await _commit();
    await NotificationService.instance.syncFromSettings(this);
  }

  Future<void> setWaterReminderInterval(int value) async {
    waterReminderInterval = value.clamp(30, 120).toInt();
    await _commit();
    await NotificationService.instance.syncFromSettings(this);
  }

  Future<void> setDailyTipsEnabled(bool value) async {
    dailyTipsEnabled = value;
    await _commit();
  }

  Future<void> setShakeToScanEnabled(bool value) async {
    shakeToScanEnabled = value;
    await _commit();
  }

  Future<void> setShakeSensitivity(double value) async {
    shakeSensitivity = value.clamp(1.2, 4.0).toDouble();
    await _commit();
  }

  Future<void> setDiscoverDevMode(bool value) async {
    discoverDevMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('discover_dev_mode', value);
    notifyListeners();
  }

  Future<void> setAiPersonalityAdjustment(int value) async {
    aiPersonalityAdjustment = value.clamp(0, 100).toInt();
    await _commit();
  }

  Future<void> markResetFoodPersonality() async {
    resetFoodPersonality = 'triggered';
    await _commit();
  }

  Future<void> markExportData(String format) async {
    exportData = format.toUpperCase();
    await _commit();
  }
}

class AuthStore extends ChangeNotifier {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  bool _loaded = false;
  String status = 'none';
  String token = '';
  int? userId;

  bool get isLoaded => _loaded;
  bool get shouldPrompt => status == 'none';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    status = prefs.getString('auth_status') ?? 'none';
    token = prefs.getString('auth_token') ?? '';
    userId = prefs.getInt('auth_user_id');
    _loaded = true;
  }

  Future<void> setStatus(String value) async {
    status = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_status', status);
    if (status != 'logged_in') {
      token = '';
      userId = null;
      await prefs.remove('auth_token');
      await prefs.remove('auth_user_id');
      await UserProfileStore.instance.setSubscriberStatus(false);
      await UserProfileStore.instance.setSubscriptionSku('');
      await UserProfileStore.instance.setAvatarUrl('');
    }
    notifyListeners();
  }

  Future<void> setSession({
    required String status,
    required String token,
    int? userId,
  }) async {
    this.status = status;
    this.token = token;
    this.userId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_status', status);
    await prefs.setString('auth_token', token);
    if (userId != null) {
      await prefs.setInt('auth_user_id', userId);
    } else {
      await prefs.remove('auth_user_id');
    }
    notifyListeners();
    if (status == 'logged_in') {
      unawaited(UserProfileStore.instance.triggerSyncAfterLogin());
    }
  }
}
