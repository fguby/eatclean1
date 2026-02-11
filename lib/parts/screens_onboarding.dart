part of '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2400),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            unawaited(_navigateNext());
          }
        });
    _controller.forward();
  }

  Future<void> _navigateNext() async {
    final completed = await _hasCompletedSetup();
    await AuthStore.instance.ensureLoaded();
    await UserProfileStore.instance.ensureLoaded();
    if (AuthStore.instance.token.isNotEmpty) {
      unawaited(UserProfileStore.instance.refreshDailyUsageFromServer());
      if (completed) {
        unawaited(
          DiscoverMenuStore.instance.prefetchWeek(
            forceGenerate: UserProfileStore.instance.discoverDevMode,
          ),
        );
      }
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed(completed ? '/dashboard' : '/selection');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: app.backgroundGradient),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: const SizedBox(),
            ),
          ),
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Spacer(),
                Column(
                  children: [
                    Image.asset(
                      'images/slogan.png',
                      width: 220,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 280,
                      child: Text(
                        '干净饮食，即使在外就餐。',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          color: app.textSecondary,
                          height: 1.4,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 3,
                          color: app.border,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width:
                                      constraints.maxWidth * _controller.value,
                                  color: primary,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                const _HomeIndicator(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_redirectIfCompleted());
  }

  Future<void> _redirectIfCompleted() async {
    final done = await _hasCompletedSetup();
    if (!mounted || !done) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final background = app.background;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 340,
                              width: double.infinity,
                              child: Image.asset(
                                'images/onboarding_hero.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      background.withOpacity(0.85),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            '吃得安心，不打乱你的训练计划。',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: app.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '让智能系统扫描菜单，找到符合每日宏量营养和训练目标的完美餐品。',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                              color: app.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          _FeatureItem(
                            icon: Icons.restaurant_menu,
                            label: '扫描菜单',
                          ),
                          _FeatureItem(
                            icon: Icons.fitness_center,
                            label: '追踪宏量',
                          ),
                          _FeatureItem(icon: Icons.auto_awesome, label: '智能建议'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_previewOnboardingFlow) {
                                  _previewOnboardingFlow = false;
                                  _forceOnboardingPreview = false;
                                }
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed('/dashboard');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: app.textInverse,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                elevation: 8,
                                shadowColor: primary.withOpacity(0.2),
                              ),
                              child: const Text('开始使用'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GoalSelectionScreen extends StatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_redirectIfCompleted());
  }

  Future<void> _redirectIfCompleted() async {
    final done = await _hasCompletedSetup();
    if (!mounted || !done) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  Future<void> _openWeightPlanSheet() async {
    final store = UserProfileStore.instance;
    await store.ensureLoaded();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return _WeightPlanSheet(
          initialMode: store.weightPlanMode,
          initialKg: store.weightPlanKg,
          initialDays: store.weightPlanDays,
          submitLabel: '保存并继续',
          onSubmit: (mode, kg, days) async {
            await store.setWeightPlan(mode: mode, kg: kg, days: days);
            await store.setGoalType(mode == 'loss' ? '减重' : '增重');
            if (!mounted) return;
            Navigator.of(context).pushNamed('/preferences');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final background = app.background;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Spacer(),
                  Expanded(
                    child: Text(
                      '第 1 步 / 5',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: app.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Text(
                    '确定你的目标。',
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: app.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '精准营养从清晰目标开始。请选择你的方向。',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: app.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _GoalCard(
                    icon: Icons.fitness_center,
                    title: '增肌',
                    description: '优化肌肉增长。高蛋白方案帮助提升力量与瘦体重。',
                    imageUrl: 'images/fantuan_duanlian.png',
                    tag: '高表现',
                    onSelect: () async {
                      await UserProfileStore.instance.setGoalType('增肌');
                      Navigator.of(context).pushNamed('/preferences');
                    },
                  ),
                  const SizedBox(height: 16),
                  _GoalCard(
                    icon: Icons.local_fire_department,
                    title: '减脂',
                    description: '启动代谢。通过合理热量缺口保肌减脂。',
                    imageUrl: 'images/riceball_run.png',
                    tag: '代谢优化',
                    onSelect: () async {
                      await UserProfileStore.instance.setGoalType('减脂');
                      Navigator.of(context).pushNamed('/preferences');
                    },
                  ),
                  const SizedBox(height: 16),
                  _GoalCard(
                    icon: Icons.scale,
                    title: '减重/增重计划',
                    description: '设定目标体重曲线，规划减重或增重节奏。',
                    imageUrl: 'images/riceball_eat.png',
                    tag: '体重管理',
                    onSelect: _openWeightPlanSheet,
                  ),
                  const SizedBox(height: 16),
                  _GoalCard(
                    icon: Icons.balance,
                    title: '维持',
                    description: '可持续状态。找到你的平衡并坚持长期健康。',
                    imageUrl: 'images/riceball_meditate.png',
                    tag: '日常活力',
                    onSelect: () async {
                      await UserProfileStore.instance.setGoalType('维持');
                      Navigator.of(context).pushNamed('/preferences');
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: app.cardAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: app.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.info, color: primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '你的选择会校准 智能菜单扫描器，更好地匹配你的代谢需求。',
                            style: GoogleFonts.inter(
                              color: app.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DietaryPreferencesScreen extends StatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  State<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState extends State<DietaryPreferencesScreen> {
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    unawaited(_redirectIfCompleted());
    unawaited(_hydratePreferences());
  }

  Future<void> _redirectIfCompleted() async {
    final done = await _hasCompletedSetup();
    if (!mounted || !done) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  Future<void> _hydratePreferences() async {
    final store = UserProfileStore.instance;
    await store.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(store.dietPreferences);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;

    return Scaffold(
      backgroundColor: app.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios, color: app.textPrimary),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 4,
                        color: app.border,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(width: 150, color: primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Text(
                    '个性化你的饮食',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: app.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '选择与你健身目标最匹配的饮食偏好，用于智能菜单扫描。',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: app.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _dietPreferenceOptions.map((item) {
                      final selected = _selected.contains(item);
                      return FilterChip(
                        selected: selected,
                        label: Text(item),
                        labelStyle: GoogleFonts.inter(
                          color: selected ? app.textInverse : app.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: primary,
                        backgroundColor: app.cardAlt,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selected.add(item);
                            } else {
                              _selected.remove(item);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      await UserProfileStore.instance.setDietPreferences(
                        _selected.toList(),
                      );
                      if (!mounted) return;
                      Navigator.of(context).pushNamed('/body_metrics');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: app.textInverse,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('保存偏好'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      await UserProfileStore.instance.setDietPreferences(
                        _selected.toList(),
                      );
                      if (!mounted) return;
                      Navigator.of(context).pushNamed('/body_metrics');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: app.textPrimary,
                      side: BorderSide(color: app.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('跳过'),
                  ),
                ],
              ),
            ),
            const _HomeIndicator(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class BodyMetricsScreen extends StatefulWidget {
  const BodyMetricsScreen({super.key});

  @override
  State<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

class _BodyMetricsScreenState extends State<BodyMetricsScreen> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _selectedGender = _genderOptions.first;
  double? _bmiValue;
  String _bmiLabel = '';

  @override
  void initState() {
    super.initState();
    unawaited(_redirectIfCompleted());
    unawaited(_hydrateMetrics());
  }

  Future<void> _redirectIfCompleted() async {
    final done = await _hasCompletedSetup();
    if (!mounted || !done) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  Future<void> _hydrateMetrics() async {
    final store = UserProfileStore.instance;
    await store.ensureLoaded();
    if (!mounted) return;
    _heightController.text = store.height > 0 ? store.height.toString() : '';
    _weightController.text = store.weight > 0 ? store.weight.toString() : '';
    _ageController.text = store.age > 0 ? store.age.toString() : '';
    _nameController.text = store.userName;
    _selectedGender = store.gender;
    _updateBmi();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _updateBmi() {
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    if (height == null || height <= 0 || weight == null || weight <= 0) {
      setState(() {
        _bmiValue = null;
        _bmiLabel = '';
      });
      return;
    }
    final bmi = weight / pow(height / 100, 2);
    final label = _bmiLabelFor(bmi);
    setState(() {
      _bmiValue = bmi;
      _bmiLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final bmiValue = _bmiValue;

    return Scaffold(
      backgroundColor: app.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios, color: app.textPrimary),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 4,
                        color: app.border,
                        // keep progress rail subtle in both themes
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(width: 210, color: primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Text(
                    '填写身体数据',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: app.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '用于计算能量与营养需求，数据越准确，推荐越精准。',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: app.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _MetricField(
                    controller: _heightController,
                    label: '身高（cm）',
                    hint: '例如 175',
                    icon: Icons.straighten,
                    onChanged: (_) => _updateBmi(),
                  ),
                  const SizedBox(height: 16),
                  _MetricField(
                    controller: _weightController,
                    label: '体重（kg）',
                    hint: '例如 68',
                    icon: Icons.monitor_weight,
                    onChanged: (_) => _updateBmi(),
                  ),
                  const SizedBox(height: 16),
                  _MetricField(
                    controller: _ageController,
                    label: '年龄',
                    hint: '例如 25',
                    icon: Icons.cake,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: app.cardAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: app.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: app.card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.badge_outlined, color: primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.done,
                            style: GoogleFonts.inter(color: app.textPrimary),
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              labelText: '昵称',
                              labelStyle: GoogleFonts.inter(
                                color: app.textSecondary,
                              ),
                              hintText: '例如 小胡子',
                              hintStyle: GoogleFonts.inter(
                                color: app.textTertiary,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: app.cardAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: app.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '性别',
                          style: GoogleFonts.inter(
                            color: app.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SegmentButton(
                                label: '男',
                                selected: _selectedGender == '男',
                                onTap: () =>
                                    setState(() => _selectedGender = '男'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SegmentButton(
                                label: '女',
                                selected: _selectedGender == '女',
                                onTap: () =>
                                    setState(() => _selectedGender = '女'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: app.cardAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: app.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: app.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.monitor_heart,
                                color: app.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '身体质量指数（BMI）',
                                style: GoogleFonts.inter(
                                  color: app.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (bmiValue == null)
                          Text(
                            '填写身高与体重后自动计算',
                            style: GoogleFonts.inter(
                              color: app.textSecondary,
                              fontSize: 12,
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BMI ${bmiValue.toStringAsFixed(1)}',
                                style: GoogleFonts.inter(
                                  color: app.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              RichText(
                                text: TextSpan(
                                  style: GoogleFonts.inter(
                                    color: app.textSecondary,
                                    fontSize: 12,
                                  ),
                                  children: [
                                    const TextSpan(text: '你的BMI显示你是 '),
                                    TextSpan(
                                      text: _bmiLabel,
                                      style: GoogleFonts.inter(
                                        color: _bmiColorFor(bmiValue),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const TextSpan(text: '!'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        _BmiStatusBar(bmi: bmiValue),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      final height = int.tryParse(
                        _heightController.text.trim(),
                      );
                      final weight = int.tryParse(
                        _weightController.text.trim(),
                      );
                      final age = int.tryParse(_ageController.text.trim());
                      final name = _nameController.text.trim();
                      final store = UserProfileStore.instance;
                      if (height == null || height <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请填写有效身高')),
                        );
                        return;
                      }
                      if (weight == null || weight <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请填写有效体重')),
                        );
                        return;
                      }
                      if (age == null || age <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请填写有效年龄')),
                        );
                        return;
                      }
                      await store.setHeight(height);
                      await store.setWeight(weight);
                      await store.setAge(age);
                      if (name.isNotEmpty) {
                        await store.setUserName(name);
                      }
                      await store.setGender(_selectedGender);
                      if (!mounted) return;
                      Navigator.of(context).pushNamed('/allergies');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: app.textInverse,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('继续'),
                  ),
                ],
              ),
            ),
            const _HomeIndicator(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class AllergiesScreen extends StatefulWidget {
  const AllergiesScreen({super.key});

  @override
  State<AllergiesScreen> createState() => _AllergiesScreenState();
}

class _AllergiesScreenState extends State<AllergiesScreen> {
  final Set<String> _selected = {};
  final TextEditingController _otherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_redirectIfCompleted());
    unawaited(_hydrateAllergies());
  }

  Future<void> _redirectIfCompleted() async {
    final done = await _hasCompletedSetup();
    if (!mounted || !done) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  Future<void> _hydrateAllergies() async {
    final store = UserProfileStore.instance;
    await store.ensureLoaded();
    if (!mounted) return;
    final extras = store.excludedFoods
        .where((item) => !_excludedFoodOptions.contains(item))
        .toList();
    setState(() {
      _selected
        ..clear()
        ..addAll(
          store.excludedFoods.where(
            (item) => _excludedFoodOptions.contains(item),
          ),
        );
    });
    _otherController.text = extras.join('，');
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final options = _excludedFoodOptions;

    return Scaffold(
      backgroundColor: app.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios, color: app.textPrimary),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 4,
                        color: app.border,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(width: 270, color: primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Text(
                    '不吃食物',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: app.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '标记你通常会避免的食物或禁忌食材。',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: app.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: options.map((item) {
                      final selected = _selected.contains(item);
                      return FilterChip(
                        selected: selected,
                        label: Text(item),
                        labelStyle: GoogleFonts.inter(
                          color: selected ? app.textInverse : app.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: primary,
                        backgroundColor: app.cardAlt,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selected.add(item);
                            } else {
                              _selected.remove(item);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _otherController,
                    style: GoogleFonts.inter(color: app.textPrimary),
                    decoration: InputDecoration(
                      labelText: '其他不吃（可选，逗号分隔）',
                      labelStyle: GoogleFonts.inter(color: app.textSecondary),
                      filled: true,
                      fillColor: app.cardAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      final extras = _otherController.text
                          .split(RegExp(r'[，,]'))
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty);
                      final updated = <String>{..._selected, ...extras};
                      await UserProfileStore.instance.setExcludedFoods(
                        updated.toList(),
                      );
                      if (!mounted) return;
                      Navigator.of(
                        context,
                      ).pushReplacementNamed('/setup_preferences');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: app.textInverse,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('继续设置'),
                  ),
                ],
              ),
            ),
            const _HomeIndicator(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class SetupPreferencesScreen extends StatefulWidget {
  const SetupPreferencesScreen({super.key});

  @override
  State<SetupPreferencesScreen> createState() => _SetupPreferencesScreenState();
}

class _SetupPreferencesScreenState extends State<SetupPreferencesScreen> {
  String _activityLevel = _activityLevelOptions.first;
  String _trainingExperience = _trainingExperienceOptions.first;
  String _preferredTrainingTime = _preferredTrainingTimeOptions.first;
  final Set<String> _trainingTypes = {};
  String _aiSuggestionStyle = _aiSuggestionStyleOptions.first;
  bool _actionSuggestionEnabled = true;
  int _reminderFrequency = 2;
  bool _dataUsageConsent = true;

  @override
  void initState() {
    super.initState();
    unawaited(_redirectIfCompleted());
    unawaited(_hydratePreferences());
  }

  Future<void> _redirectIfCompleted() async {
    final done = await _hasCompletedSetup();
    if (!mounted || !done) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  Future<void> _hydratePreferences() async {
    final store = UserProfileStore.instance;
    await store.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _activityLevel = store.activityLevel;
      _trainingExperience = store.trainingExperience;
      _preferredTrainingTime = store.preferredTrainingTime;
      _trainingTypes
        ..clear()
        ..addAll(store.trainingTypePreference);
      _aiSuggestionStyle = store.aiSuggestionStyle;
      _actionSuggestionEnabled = store.actionSuggestionEnabled;
      _reminderFrequency = store.reminderFrequency;
      _dataUsageConsent = store.dataUsageConsent;
    });
  }

  void _toggleTrainingType(String value) {
    setState(() {
      if (_trainingTypes.contains(value)) {
        _trainingTypes.remove(value);
      } else {
        _trainingTypes.add(value);
      }
    });
    unawaited(UserProfileStore.instance.toggleTrainingTypePreference(value));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;

    return Scaffold(
      backgroundColor: app.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios, color: app.textPrimary),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 4,
                        color: app.border,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(width: 300, color: primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Text(
                    '完善训练与大胡子偏好',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: app.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '这些设置将帮助你获得更精准的训练与饮食建议。',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: app.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: '训练背景', subtitle: '活动水平与训练经验'),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChipGroup(
                          title: '活动水平',
                          options: _activityLevelOptions,
                          selected: _activityLevel,
                          onSelect: (value) {
                            setState(() => _activityLevel = value);
                            unawaited(
                              UserProfileStore.instance.setActivityLevel(value),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _ChipGroup(
                          title: '训练经验',
                          options: _trainingExperienceOptions,
                          selected: _trainingExperience,
                          onSelect: (value) {
                            setState(() => _trainingExperience = value);
                            unawaited(
                              UserProfileStore.instance.setTrainingExperience(
                                value,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: '训练偏好', subtitle: '训练时间与训练类型'),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChipGroup(
                          title: '偏好训练时间',
                          options: _preferredTrainingTimeOptions,
                          selected: _preferredTrainingTime,
                          onSelect: (value) {
                            setState(() => _preferredTrainingTime = value);
                            unawaited(
                              UserProfileStore.instance
                                  .setPreferredTrainingTime(value),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _MultiChipGroup(
                          title: '训练类型偏好',
                          options: _trainingTypeOptions,
                          selected: _trainingTypes.toList(),
                          onToggle: _toggleTrainingType,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: '大胡子个性化设置', subtitle: '风格与提醒节奏'),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChipGroup(
                          title: '大胡子建议风格',
                          options: _aiSuggestionStyleOptions,
                          selected: _aiSuggestionStyle,
                          onSelect: (value) {
                            setState(() => _aiSuggestionStyle = value);
                            unawaited(
                              UserProfileStore.instance.setAiSuggestionStyle(
                                value,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _SwitchTile(
                          title: '启用行动提示',
                          subtitle: '提醒使用应用内功能',
                          value: _actionSuggestionEnabled,
                          onChanged: (value) {
                            setState(() => _actionSuggestionEnabled = value);
                            unawaited(
                              UserProfileStore.instance
                                  .setActionSuggestionEnabled(value),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _SliderRow(
                          title: '提醒频率（次/天）',
                          subtitle: '控制大胡子提示频率',
                          min: 0,
                          max: 5,
                          value: _reminderFrequency,
                          onChanged: (value) {
                            setState(() => _reminderFrequency = value);
                            unawaited(
                              UserProfileStore.instance.setReminderFrequency(
                                value,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          title: '数据使用授权',
                          subtitle: '允许大胡子记录并优化推荐',
                          value: _dataUsageConsent,
                          onChanged: (value) {
                            setState(() => _dataUsageConsent = value);
                            unawaited(
                              UserProfileStore.instance.setDataUsageConsent(
                                value,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      await _markSetupCompleted();
                      if (!mounted) return;
                      final nextRoute = _previewOnboardingFlow
                          ? '/welcome'
                          : '/dashboard';
                      Navigator.of(context).pushReplacementNamed(nextRoute);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: app.textInverse,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('完成设置'),
                  ),
                ],
              ),
            ),
            const _HomeIndicator(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
