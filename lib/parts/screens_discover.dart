part of '../main.dart';

class _DiscoverMeal {
  const _DiscoverMeal({
    this.id = '',
    required this.title,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.ingredients,
    required this.instructions,
    required this.benefits,
    this.timeMinutes = 10,
  });

  final String id;
  final String title;
  final String mealType;
  final int calories;
  final int protein;
  final int fat;
  final int carbs;
  final List<String> ingredients;
  final String instructions;
  final String benefits;
  final int timeMinutes;

  factory _DiscoverMeal.fromJson(Map<String, dynamic> json) {
    int readInt(Object? raw, int fallback) {
      if (raw is int) return raw;
      if (raw is double) return raw.round();
      if (raw is num) return raw.round();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    String classifyMealType(String type) {
      final value = type.trim();
      if (value.contains('早餐') || value.startsWith('早')) return 'breakfast';
      if (value.contains('午餐') || value.startsWith('午')) return 'lunch';
      if (value.contains('晚餐') || value.startsWith('晚')) return 'dinner';
      if (value.contains('加餐') ||
          value.contains('推荐') ||
          value.contains('零食') ||
          value.contains('小食')) {
        return 'snack';
      }
      return 'general';
    }

    List<String> defaultIngredients(String type) {
      switch (classifyMealType(type)) {
        case 'breakfast':
          return ['燕麦片 50g', '脱脂牛奶 200ml', '鸡蛋 1 个', '蓝莓 50g', '混合坚果 10g'];
        case 'lunch':
          return ['鸡胸肉 120g', '糙米饭 120g', '西兰花 100g', '胡萝卜 60g', '橄榄油 5ml'];
        case 'dinner':
          return ['三文鱼 120g', '藜麦 80g', '菠菜 80g', '番茄 60g', '柠檬汁 少许'];
        case 'snack':
          return ['希腊酸奶 150g', '香蕉 1/2 根', '奇亚籽 5g', '蜂蜜 1 茶匙'];
        default:
          return ['优质蛋白 120g', '时蔬 150g', '全谷物 80-120g', '橄榄油 5ml'];
      }
    }

    String defaultInstructions(String type, String title) {
      switch (classifyMealType(type)) {
        case 'breakfast':
          return '燕麦加牛奶小火煮 3-5 分钟，加入$title相关水果与坚果，搭配水煮蛋即可。';
        case 'lunch':
          return '$title中的蛋白食材煎至熟，糙米饭蒸热，西兰花胡萝卜焯水后拌少量橄榄油。';
        case 'dinner':
          return '$title的主蛋白煎/烤 6-8 分钟，藜麦煮熟，菠菜番茄轻炒或凉拌，挤少许柠檬汁。';
        case 'snack':
          return '酸奶打底，加入水果切块与奇亚籽，冷藏 10 分钟口感更佳。';
        default:
          return '按$title的食材组合清淡烹饪，优先蒸煮或少油翻炒，控制盐油用量。';
      }
    }

    String defaultBenefits(String type) {
      switch (classifyMealType(type)) {
        case 'breakfast':
          return '高纤维 + 优质蛋白，稳定血糖并提升饱腹。';
        case 'lunch':
          return '蛋白充足，兼顾能量与训练恢复。';
        case 'dinner':
          return '清淡易消化，降低晚间热量负担。';
        case 'snack':
          return '高蛋白低负担，缓解饥饿并保护肌肉。';
        default:
          return '营养均衡，适合日常训练与恢复。';
      }
    }

    String pickTitle() {
      for (final key in const [
        'title',
        'name',
        'dish_name',
        'meal_name',
        'dish',
        'menu_name',
      ]) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final title = pickTitle();
    final mealType =
        json['meal_type']?.toString() ??
        json['type']?.toString() ??
        json['category']?.toString() ??
        '推荐';
    final ingredients = _readStringListFromJson(
      json['ingredients'] ?? json['components'] ?? json['materials'],
    );
    final instructions =
        (json['instructions']?.toString() ?? json['steps']?.toString() ?? '')
            .trim();
    final benefits =
        (json['benefits']?.toString() ?? json['reason']?.toString() ?? '')
            .trim();
    return _DiscoverMeal(
      id: json['id']?.toString() ?? '',
      title: title.isNotEmpty ? title : '推荐餐食',
      mealType: mealType,
      calories: readInt(json['calories'], 0),
      protein: readInt(json['protein'], 0),
      fat: readInt(json['fat'], 0),
      carbs: readInt(json['carbs'], 0),
      ingredients: ingredients.isNotEmpty
          ? ingredients
          : defaultIngredients(mealType),
      instructions: instructions.isNotEmpty
          ? instructions
          : defaultInstructions(mealType, title.isNotEmpty ? title : '餐食'),
      benefits: benefits.isNotEmpty ? benefits : defaultBenefits(mealType),
      timeMinutes: readInt(json['time_minutes'] ?? json['time'], 10),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'name': title,
      'meal_type': mealType,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'ingredients': ingredients,
      'instructions': instructions,
      'benefits': benefits,
      'time_minutes': timeMinutes,
    };
  }
}

List<_DiscoverMeal> _parseDiscoverMealsPayload(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map(
          (item) => _DiscoverMeal.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      return _parseDiscoverMealsPayload(decoded);
    } catch (_) {}
  }
  return [];
}

DateTime _weekStartDate(DateTime date) {
  final weekday = date.weekday;
  final start = DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: weekday - 1));
  return DateTime(start.year, start.month, start.day);
}

class DiscoverMenuStore extends ChangeNotifier {
  DiscoverMenuStore._();

  static final DiscoverMenuStore instance = DiscoverMenuStore._();

  DateTime? _cachedWeekStart;
  final Map<int, List<_DiscoverMeal>> _planMealsByWeekday = {};
  final Set<int> _fetchedWeekdays = {};
  bool _prefetching = false;

  bool get isPrefetching => _prefetching;

  bool hasFetchedFor(int weekday) => _fetchedWeekdays.contains(weekday);

  List<_DiscoverMeal> mealsFor(int weekday) =>
      _planMealsByWeekday[weekday] ?? [];

  void setMealsForWeekday(int weekday, List<_DiscoverMeal> meals) {
    _ensureWeek(DateTime.now());
    _planMealsByWeekday[weekday] = List<_DiscoverMeal>.from(meals);
    _fetchedWeekdays.add(weekday);
    notifyListeners();
  }

  void _ensureWeek(DateTime now) {
    final weekStart = _weekStartDate(now);
    if (_cachedWeekStart == null || !_isSameDay(_cachedWeekStart!, weekStart)) {
      _cachedWeekStart = weekStart;
      _planMealsByWeekday.clear();
      _fetchedWeekdays.clear();
    }
  }

  Future<void> prefetchWeek({required bool forceGenerate}) async {
    if (_prefetching) return;
    await AuthStore.instance.ensureLoaded();
    if (AuthStore.instance.token.isEmpty) return;
    _ensureWeek(DateTime.now());
    _prefetching = true;
    notifyListeners();
    for (var weekday = 1; weekday <= 7; weekday++) {
      if (_fetchedWeekdays.contains(weekday)) continue;
      await _fetchAndStore(weekday, forceGenerate: forceGenerate);
    }
    _prefetching = false;
    notifyListeners();
  }

  Future<List<_DiscoverMeal>> fetchForWeekday(
    int weekday, {
    required bool forceGenerate,
  }) async {
    _ensureWeek(DateTime.now());
    if (!forceGenerate && _fetchedWeekdays.contains(weekday)) {
      return _planMealsByWeekday[weekday] ?? [];
    }
    return _fetchAndStore(weekday, forceGenerate: forceGenerate);
  }

  Future<List<_DiscoverMeal>> _fetchAndStore(
    int weekday, {
    required bool forceGenerate,
  }) async {
    await AuthStore.instance.ensureLoaded();
    if (AuthStore.instance.token.isEmpty) return [];
    _ensureWeek(DateTime.now());
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/discover/recommendations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthStore.instance.token}',
        },
        body: jsonEncode({
          'plan_mode': 'weekly',
          'weekday': weekday,
          'client_time': _formatClientTime(DateTime.now()),
          if (forceGenerate) 'force_generate': true,
        }),
      );
      if (response.statusCode < 400) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        if (payload['code'] == 0 && payload['data'] is Map) {
          final data = payload['data'] as Map;
          final planMeals = _parseDiscoverMealsPayload(data['plan_meals']);
          _planMealsByWeekday[weekday] = planMeals;
          _fetchedWeekdays.add(weekday);
          notifyListeners();
          return planMeals;
        }
      }
    } catch (_) {}
    return _planMealsByWeekday[weekday] ?? [];
  }
}

class _DiscoverTab extends StatefulWidget {
  const _DiscoverTab();

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab> {
  final TextEditingController _searchController = TextEditingController();
  String _planMode = 'weekly';
  int _selectedWeekday = DateTime.now().weekday;
  String _query = '';
  List<_DiscoverMeal> _searchFoods = [];
  bool _searchingFoods = false;
  bool _loadingDiscover = false;
  bool _hasLoadedDiscover = false;
  bool _hasDiscoverData = false;
  List<_DiscoverMeal> _planMeals = [];
  List<_DiscoverMeal> _recommendations = [];

  Future<bool> _ensureLoggedIn(String actionLabel) async {
    await AuthStore.instance.ensureLoaded();
    if (AuthStore.instance.status != 'logged_in' ||
        AuthStore.instance.token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('请先登录后再$actionLabel')));
      }
      return false;
    }
    return true;
  }

  Future<bool> _ensureDailyQuota(
    DailyUsageType type,
    String limitMessage,
  ) async {
    final store = UserProfileStore.instance;
    await store.ensureLoaded();
    if (store.canUseDailyUsage(type)) {
      return true;
    }
    if (mounted) {
      await showSubscriptionSheet(context, reason: limitMessage);
    }
    return false;
  }

  Future<void> _openFoodRecord() async {
    if (!await _ensureLoggedIn('记录食物')) return;
    if (!await _ensureDailyQuota(
      DailyUsageType.mealRecord,
      '今日餐食记录次数已用完，开通订阅可无限使用',
    )) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const FoodRecordScreen(initialMode: _UnifiedScanMode.food),
      ),
    );
  }

  static const _fallbackPlanMeals = [
    _DiscoverMeal(
      title: '燕麦核桃蓝莓早餐碗',
      mealType: '早餐',
      calories: 400,
      protein: 20,
      fat: 12,
      carbs: 50,
      ingredients: ['燕麦片 50g', '脱脂牛奶 200ml', '核桃仁 15g', '蓝莓 50g', '蜂蜜 1 茶匙'],
      instructions: '将燕麦片加入牛奶中加热，撒上核桃与蓝莓，淋少许蜂蜜。',
      benefits: '高纤维与抗氧化成分，帮助维持饱腹与稳定血糖。',
      timeMinutes: 10,
    ),
    _DiscoverMeal(
      title: '鸡胸肉藜麦蔬菜碗',
      mealType: '午餐',
      calories: 450,
      protein: 45,
      fat: 10,
      carbs: 35,
      ingredients: ['去皮鸡胸肉 120g', '熟藜麦 100g', '西兰花 80g', '胡萝卜 50g', '橄榄油 1 茶匙'],
      instructions: '鸡胸肉煎熟切片，藜麦与蔬菜拌匀，淋上橄榄油即可。',
      benefits: '优质蛋白与低 GI 碳水组合，支持肌肉恢复。',
      timeMinutes: 15,
    ),
    _DiscoverMeal(
      title: '三文鱼藜麦彩蔬沙拉',
      mealType: '晚餐',
      calories: 520,
      protein: 35,
      fat: 18,
      carbs: 42,
      ingredients: ['三文鱼 100g', '熟藜麦 80g', '牛油果 40g', '彩椒 60g', '柠檬汁少许'],
      instructions: '三文鱼煎熟切块，与藜麦和彩蔬拌匀，挤上柠檬汁。',
      benefits: '富含 Omega-3 与矿物质，有助于心血管健康。',
      timeMinutes: 18,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final value = _searchController.text.trim();
      if (value == _query) return;
      setState(() => _query = value);
      if (value.isEmpty) {
        setState(() => _searchFoods = []);
      }
    });
    _loadDiscoverData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_DiscoverMeal> get _activePlanMeals {
    final cached = DiscoverMenuStore.instance.mealsFor(_selectedWeekday);
    if (cached.isNotEmpty) return cached;
    if (AuthStore.instance.token.isNotEmpty) {
      return _planMeals;
    }
    return _planMeals.isNotEmpty ? _planMeals : _fallbackPlanMeals;
  }

  List<_DiscoverMeal> get _activeRecommendations {
    if (_hasLoadedDiscover) return _recommendations;
    return _recommendations;
  }

  int _readInt(Object? raw, int fallback) {
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null) return parsed;
      final asDouble = double.tryParse(raw.trim());
      if (asDouble != null) return asDouble.round();
    }
    return fallback;
  }

  Future<void> _loadDiscoverData() async {
    if (_loadingDiscover) return;
    setState(() => _loadingDiscover = true);
    await AuthStore.instance.ensureLoaded();
    await UserProfileStore.instance.ensureLoaded();
    if (!mounted) return;
    if (AuthStore.instance.token.isEmpty) {
      setState(() => _loadingDiscover = false);
      return;
    }
    final forceGenerate = UserProfileStore.instance.discoverDevMode;
    final requestedDay = _selectedWeekday;
    try {
      final planMeals = await DiscoverMenuStore.instance.fetchForWeekday(
        requestedDay,
        forceGenerate: forceGenerate,
      );
      if (!mounted || requestedDay != _selectedWeekday) return;
      setState(() {
        _hasLoadedDiscover = true;
        _hasDiscoverData = planMeals.isNotEmpty;
        _planMeals = planMeals;
        _recommendations = const [];
      });
    } catch (_) {
      // ignore network errors
    } finally {
      if (mounted) {
        setState(() => _loadingDiscover = false);
      }
    }
  }

  Future<void> _generateSelectedDay() async {
    if (!await _ensureLoggedIn('生成菜单')) return;
    if (!await _ensureDailyQuota(
      DailyUsageType.question,
      '今日生成次数已用完，开通订阅可无限使用',
    )) {
      return;
    }
    setState(() => _loadingDiscover = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/discover/weekly/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthStore.instance.token}',
        },
        body: jsonEncode({
          'weekday': _selectedWeekday,
          'client_time': _formatClientTime(DateTime.now()),
          'plan_mode': 'weekly',
        }),
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = payload['data'];
        final planRaw = (data is Map) ? data['plan_meals'] : null;
        final meals = _parseDiscoverMealsPayload(planRaw);
        if (meals.isNotEmpty) {
          setState(() {
            _planMeals = meals;
            _hasLoadedDiscover = true;
          });
          DiscoverMenuStore.instance.setMealsForWeekday(
            _selectedWeekday,
            meals,
          );
        }
      } else if (response.statusCode == 429 || payload['code'] == 429) {
        await UserProfileStore.instance.refreshDailyUsageFromServer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(payload['message']?.toString() ?? '额度已用完，订阅可继续使用'),
            ),
          );
          await showSubscriptionSheet(
            context,
            reason: '额度已用完，订阅可继续使用',
            forceShow: !UserProfileStore.instance.isAnnualSubscriber,
          );
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loadingDiscover = false);
    }
  }

  Future<void> _searchFood(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    if (!await _ensureLoggedIn('搜索食物')) return;
    setState(() {
      _searchingFoods = true;
      _searchFoods = [];
    });
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/food/search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthStore.instance.token}',
        },
        body: jsonEncode({'query': query}),
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = payload['data'];
        if (data is Map) {
          final meal = _DiscoverMeal(
            title: data['name']?.toString() ?? query,
            mealType: '食物',
            calories: _readInt(data['calories_kcal_per100g'], 0),
            protein: _readInt(data['protein_g_per100g'], 0),
            fat: _readInt(data['fat_g_per100g'], 0),
            carbs: _readInt(data['carbs_g_per100g'], 0),
            ingredients: const [],
            instructions: '',
            benefits: data['advice']?.toString() ?? '',
            timeMinutes: 0,
          );
          setState(() => _searchFoods = [meal]);
        }
      } else if (response.statusCode == 429 || payload['code'] == 429) {
        await UserProfileStore.instance.refreshDailyUsageFromServer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(payload['message']?.toString() ?? '额度已用完，订阅可继续使用'),
            ),
          );
          await showSubscriptionSheet(
            context,
            reason: '额度已用完，订阅可继续使用',
            forceShow: !UserProfileStore.instance.isAnnualSubscriber,
          );
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _searchingFoods = false);
    }
  }

  Future<List<_DiscoverMeal>> _fetchReplaceMeals(_DiscoverMeal meal) async {
    await AuthStore.instance.ensureLoaded();
    if (AuthStore.instance.token.isEmpty) return [];
    try {
      final payload = meal.toJson()
        ..['client_time'] = _formatClientTime(DateTime.now());
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/discover/replace'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthStore.instance.token}',
        },
        body: jsonEncode(payload),
      );
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final errorMessage =
          (decoded['message'] ??
                  decoded['msg'] ??
                  decoded['error'] ??
                  decoded['detail'])
              ?.toString()
              .trim();
      if (response.statusCode == 429 || decoded['code'] == 429) {
        if (mounted) {
          await showSubscriptionSheet(
            context,
            reason: (errorMessage != null && errorMessage.isNotEmpty)
                ? errorMessage
                : '今日提问次数已用完，开通订阅可无限使用',
          );
          UserProfileStore.instance.markDailyUsage(DailyUsageType.question);
        }
        return [];
      }
      if (response.statusCode < 400 && decoded['code'] == 0) {
        final data = decoded['data'];
        if (data is Map) {
          final meals = _parseDiscoverMealsPayload(data['meals']);
          if (meals.isNotEmpty) {
            UserProfileStore.instance.markDailyUsage(DailyUsageType.question);
            return meals;
          }
          final recs = _parseDiscoverMealsPayload(data['recommendations']);
          if (recs.isNotEmpty) {
            UserProfileStore.instance.markDailyUsage(DailyUsageType.question);
            return recs;
          }
          final parsed = _parseDiscoverMealsPayload(data);
          if (parsed.isNotEmpty) {
            UserProfileStore.instance.markDailyUsage(DailyUsageType.question);
          }
          return parsed;
        }
        if (data is List) {
          final parsed = _parseDiscoverMealsPayload(data);
          if (parsed.isNotEmpty) {
            UserProfileStore.instance.markDailyUsage(DailyUsageType.question);
          }
          return parsed;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> _openReplaceSheet(
    _DiscoverMeal meal, {
    required bool isPlan,
    required int index,
  }) async {
    if (!await _ensureLoggedIn('智能替换')) return;
    if (!await _ensureDailyQuota(
      DailyUsageType.question,
      '今日提问次数已用完，开通订阅可无限使用',
    )) {
      return;
    }
    final selected = await showModalBottomSheet<_DiscoverMeal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DiscoverReplaceSheet(
          meal: meal,
          fetcher: _fetchReplaceMeals,
          onSelect: (item) => Navigator.of(context).pop(item),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (isPlan) {
        final updated = _planMeals.isNotEmpty
            ? List<_DiscoverMeal>.from(_planMeals)
            : List<_DiscoverMeal>.from(_activePlanMeals);
        if (index >= 0 && index < updated.length) {
          updated[index] = selected;
        }
        _planMeals = updated;
        DiscoverMenuStore.instance.setMealsForWeekday(
          _selectedWeekday,
          updated,
        );
        unawaited(_persistWeeklyMenu(updated));
      } else {
        final updated = _recommendations.isNotEmpty
            ? List<_DiscoverMeal>.from(_recommendations)
            : List<_DiscoverMeal>.from(_activeRecommendations);
        if (index >= 0 && index < updated.length) {
          updated[index] = selected;
        }
        _recommendations = updated;
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已替换为更健康方案')));
  }

  Future<void> _persistWeeklyMenu(List<_DiscoverMeal> meals) async {
    await AuthStore.instance.ensureLoaded();
    if (AuthStore.instance.token.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/discover/weekly/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthStore.instance.token}',
        },
        body: jsonEncode({
          'weekday': _selectedWeekday,
          'plan_meals': meals.map((meal) => meal.toJson()).toList(),
          'client_time': _formatClientTime(DateTime.now()),
        }),
      );
      if (response.statusCode >= 400) {
        debugPrint('Weekly menu save failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Weekly menu save error: $e');
    }
  }

  List<_DiscoverMeal> get _searchResults {
    if (_query.isEmpty) return [];
    if (_searchFoods.isNotEmpty) return _searchFoods;
    return [];
  }

  IconData _mealIcon(String type) {
    switch (type) {
      case '早餐':
        return Icons.wb_sunny;
      case '午餐':
        return Icons.cloud;
      case '晚餐':
        return Icons.nightlight_round;
      default:
        return Icons.restaurant;
    }
  }

  Map<String, int> _summarizeMeals(List<_DiscoverMeal> meals) {
    var calories = 0;
    var protein = 0;
    var fat = 0;
    var carbs = 0;
    for (final meal in meals) {
      calories += meal.calories;
      protein += meal.protein;
      fat += meal.fat;
      carbs += meal.carbs;
    }
    return {
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    };
  }

  Widget _buildWeekdayThermoSelector(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final card = app.card;
    final selectedLabel = _weekDayLabels[_selectedWeekday - 1];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: app.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '每周计划',
                style: GoogleFonts.inter(
                  color: app.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: primary.withOpacity(0.5)),
                ),
                child: Text(
                  '周$selectedLabel',
                  style: GoogleFonts.inter(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF4FC3F7),
                      Color(0xFF13EC5B),
                      Color(0xFFFFB454),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 14,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: primary,
                  overlayColor: primary.withOpacity(0.2),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  value: _selectedWeekday.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  onChanged: (value) {
                    final day = value.round();
                    if (day == _selectedWeekday) return;
                    setState(() {
                      _selectedWeekday = day;
                      final cached = DiscoverMenuStore.instance.mealsFor(day);
                      if (cached.isNotEmpty ||
                          DiscoverMenuStore.instance.hasFetchedFor(day)) {
                        _hasLoadedDiscover = true;
                        _hasDiscoverData = cached.isNotEmpty;
                        _planMeals = cached;
                      }
                    });
                  },
                  onChangeEnd: (_) => unawaited(_loadDiscoverData()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _weekDayLabels.asMap().entries.map((entry) {
              final day = entry.key + 1;
              final selected = day == _selectedWeekday;
              final app = context.appColors;
              return Text(
                entry.value,
                style: GoogleFonts.inter(
                  color: selected ? app.textPrimary : app.textSecondary,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final background = app.background;
    final card = app.card;
    final softText = app.textSecondary;
    final isSearching = _query.isNotEmpty;
    final store = DiscoverMenuStore.instance;
    final cachedMeals = store.mealsFor(_selectedWeekday);
    final mealsForDay = cachedMeals.isNotEmpty ? cachedMeals : _activePlanMeals;
    final macro = _summarizeMeals(mealsForDay);
    final hasMealData = mealsForDay.isNotEmpty;

    return Container(
      color: background,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: DiscoverMenuStore.instance,
          builder: (context, child) {
            final store = DiscoverMenuStore.instance;
            final cachedMeals = store.mealsFor(_selectedWeekday);
            final hasStoreLoaded = store.hasFetchedFor(_selectedWeekday);
            final hasLoaded = _hasLoadedDiscover || hasStoreLoaded;
            final hasData = cachedMeals.isNotEmpty || _planMeals.isNotEmpty;
            final showLoading =
                !hasLoaded &&
                (_loadingDiscover || store.isPrefetching) &&
                AuthStore.instance.token.isNotEmpty;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              children: [
                Row(
                  children: [
                    Text(
                      '发现',
                      style: GoogleFonts.inter(
                        color: app.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MiniTag(label: '每周菜单'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _loadingDiscover ? null : _generateSelectedDay,
                      icon: Icon(
                        Icons.auto_awesome,
                        color: app.primary,
                        size: 18,
                      ),
                      label: Text(
                        '一键生成',
                        style: GoogleFonts.inter(
                          color: app.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: app.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: softText, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.inter(
                            color: app.textPrimary,
                            fontSize: 14,
                          ),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '搜索食物、食材或热量',
                            hintStyle: GoogleFonts.inter(color: softText),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (value) => _searchFood(value),
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () => _searchController.clear(),
                          child: Icon(Icons.close, color: softText, size: 18),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isSearching) ...[
                  Text(
                    '搜索结果',
                    style: GoogleFonts.inter(
                      color: app.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_searchingFoods)
                    Center(child: CircularProgressIndicator(color: app.primary))
                  else if (_searchResults.isEmpty)
                    Text(
                      '没有找到相关餐食，换个关键词试试。',
                      style: GoogleFonts.inter(color: softText, fontSize: 12),
                    )
                  else
                    Column(
                      children: _searchResults
                          .map((meal) => _DiscoverSearchCard(meal: meal))
                          .toList(),
                    ),
                ] else ...[
                  _buildWeekdayThermoSelector(context),
                  const SizedBox(height: 16),
                  if (showLoading) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: app.border),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '正在加载本周菜单...',
                            style: GoogleFonts.inter(
                              color: app.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (hasLoaded && !hasData) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: app.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '该日期菜单尚未生成',
                            style: GoogleFonts.inter(
                              color: app.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '尚未生成菜单，可点击上方“一键生成”立即获取今日/本周菜单。',
                            style: GoogleFonts.inter(
                              color: softText,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: app.border),
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 60,
                              bottom: 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '你的均衡饮食计划',
                                        style: GoogleFonts.inter(
                                          color: app.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '智能替换日',
                                        style: GoogleFonts.inter(
                                          color: primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _MacroStat(
                                      icon: Icons.local_fire_department,
                                      value: hasMealData
                                          ? '${macro['calories']} kcal'
                                          : '-- kcal',
                                      color: const Color(0xFFFF8A3D),
                                      label: '卡路里',
                                    ),
                                    _MacroStat(
                                      icon: Icons.fitness_center,
                                      value: hasMealData
                                          ? '${macro['protein']}g'
                                          : '-- g',
                                      color: const Color(0xFF4DA3FF),
                                      label: '蛋白质',
                                    ),
                                    _MacroStat(
                                      icon: Icons.opacity,
                                      value: hasMealData
                                          ? '${macro['fat']}g'
                                          : '-- g',
                                      color: const Color(0xFFFFC64B),
                                      label: '脂肪',
                                    ),
                                    _MacroStat(
                                      icon: Icons.eco,
                                      value: hasMealData
                                          ? '${macro['carbs']}g'
                                          : '-- g',
                                      color: const Color(0xFF46E38A),
                                      label: '碳水',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Opacity(
                              opacity: 0.9,
                              child: Image.asset(
                                'images/riceball_meditate.png',
                                width: 56,
                                height: 56,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._activePlanMeals.asMap().entries.map((entry) {
                      final meal = entry.value;
                      return _MealPlanSection(
                        meal: meal,
                        icon: _mealIcon(meal.mealType),
                        onReplace: () => _openReplaceSheet(
                          meal,
                          isPlan: true,
                          index: entry.key,
                        ),
                        onRecord: _openFoodRecord,
                      );
                    }).toList(),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                color: app.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(color: app.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _MealPlanSection extends StatelessWidget {
  const _MealPlanSection({
    required this.meal,
    required this.icon,
    required this.onReplace,
    this.onRecord,
  });

  final _DiscoverMeal meal;
  final IconData icon;
  final VoidCallback onReplace;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final card = app.card;
    final displayTitle = meal.title.trim().isNotEmpty ? meal.title : '推荐餐食';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: app.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primary),
              const SizedBox(width: 8),
              Text(
                meal.mealType,
                style: GoogleFonts.inter(
                  color: app.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _MacroInline(
                value: '${meal.calories}kcal',
                icon: Icons.local_fire_department,
              ),
              const SizedBox(width: 8),
              _MacroInline(
                value: '${meal.protein}g',
                icon: Icons.fitness_center,
              ),
              const SizedBox(width: 8),
              _MacroInline(value: '${meal.fat}g', icon: Icons.opacity),
              const SizedBox(width: 8),
              _MacroInline(value: '${meal.carbs}g', icon: Icons.eco),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayTitle,
            style: GoogleFonts.inter(
              color: app.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...meal.ingredients.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $item',
                style: GoogleFonts.inter(
                  color: app.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.timer, color: app.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(
                '${meal.timeMinutes} 分钟',
                style: GoogleFonts.inter(
                  color: app.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '如何准备',
            style: GoogleFonts.inter(
              color: app.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meal.instructions,
            style: GoogleFonts.inter(
              color: app.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '健康益处',
            style: GoogleFonts.inter(
              color: app.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meal.benefits,
            style: GoogleFonts.inter(
              color: app.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReplace,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('智能替换'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('记录食物'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroInline extends StatelessWidget {
  const _MacroInline({required this.value, required this.icon});

  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: app.textSecondary),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: app.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DiscoverSearchCard extends StatelessWidget {
  const _DiscoverSearchCard({required this.meal});

  final _DiscoverMeal meal;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: app.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: app.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: app.cardAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.restaurant_menu, color: app.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meal.title,
                            style: GoogleFonts.inter(
                              color: app.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: app.cardAlt,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: app.border),
                          ),
                          child: Text(
                            '每100g',
                            style: GoogleFonts.inter(
                              color: app.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MacroChip(
                          label: '热量',
                          value: '${meal.calories} kcal',
                          color: const Color(0xFFFF7A45),
                        ),
                        _MacroChip(
                          label: '蛋白',
                          value: '${meal.protein} g',
                          color: const Color(0xFF36CFC9),
                        ),
                        _MacroChip(
                          label: '脂肪',
                          value: '${meal.fat} g',
                          color: const Color(0xFFFAAD14),
                        ),
                        _MacroChip(
                          label: '碳水',
                          value: '${meal.carbs} g',
                          color: const Color(0xFF40A9FF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (meal.benefits.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates, size: 18, color: app.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    meal.benefits,
                    style: GoogleFonts.inter(
                      color: app.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverRecommendationCard extends StatelessWidget {
  const _DiscoverRecommendationCard({
    required this.meal,
    required this.onReplace,
  });

  final _DiscoverMeal meal;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final displayTitle = meal.title.trim().isNotEmpty ? meal.title : '推荐餐食';
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: app.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: app.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayTitle,
            style: GoogleFonts.inter(
              color: app.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meal.benefits,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: app.textSecondary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const Spacer(),
          Text(
            '${meal.calories} kcal',
            style: GoogleFonts.inter(
              color: app.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onReplace,
              style: OutlinedButton.styleFrom(
                foregroundColor: app.primary,
                side: BorderSide(color: app.primary.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('智能替换'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverReplaceSheet extends StatelessWidget {
  const _DiscoverReplaceSheet({
    required this.meal,
    required this.fetcher,
    required this.onSelect,
  });

  final _DiscoverMeal meal;
  final Future<List<_DiscoverMeal>> Function(_DiscoverMeal) fetcher;
  final ValueChanged<_DiscoverMeal> onSelect;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: app.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: app.border),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: app.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '智能替换建议',
                style: GoogleFonts.inter(
                  color: app.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: app.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: app.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.restaurant_menu, color: primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.title,
                            style: GoogleFonts.inter(
                              color: app.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${meal.calories} kcal · P${meal.protein} F${meal.fat} C${meal.carbs}',
                            style: GoogleFonts.inter(
                              color: app.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<_DiscoverMeal>>(
                future: fetcher(meal),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: primary,
                          strokeWidth: 2.4,
                        ),
                      ),
                    );
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return Text(
                      '暂时没有更合适的替换方案，稍后再试试。',
                      style: GoogleFonts.inter(
                        color: app.textSecondary,
                        fontSize: 12,
                      ),
                    );
                  }
                  return Column(
                    children: items
                        .map(
                          (item) => _DiscoverReplacementCard(
                            meal: item,
                            onSelect: () => onSelect(item),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiscoverReplacementCard extends StatelessWidget {
  const _DiscoverReplacementCard({required this.meal, required this.onSelect});

  final _DiscoverMeal meal;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final displayTitle = meal.title.trim().isNotEmpty ? meal.title : '推荐餐食';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: app.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: app.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayTitle,
                style: GoogleFonts.inter(
                  color: app.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${meal.calories} kcal · P${meal.protein} F${meal.fat} C${meal.carbs}',
                style: GoogleFonts.inter(
                  color: app.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meal.benefits,
                style: GoogleFonts.inter(
                  color: app.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (meal.ingredients.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: meal.ingredients.take(6).map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: app.cardAlt,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: app.border),
                      ),
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          color: app.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: primary.withOpacity(0.5)),
                  ),
                  child: Text(
                    '点击采用',
                    style: GoogleFonts.inter(
                      color: primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
