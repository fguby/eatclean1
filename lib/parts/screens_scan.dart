part of '../main.dart';

class ScanMenuScreen extends StatefulWidget {
  const ScanMenuScreen({super.key});

  @override
  State<ScanMenuScreen> createState() => _ScanMenuScreenState();
}

class MenuScanResult {
  const MenuScanResult({
    required this.recognizedText,
    required this.summary,
    required this.actions,
    required this.dishes,
  });

  final String recognizedText;
  final String summary;
  final List<String> actions;
  final List<MealDish> dishes;

  static const empty = MenuScanResult(
    recognizedText: '',
    summary: '',
    actions: const [],
    dishes: const [],
  );
}

enum _UnifiedScanMode { menu, food }

DateTime? _parseDateKey(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  try {
    return DateTime.parse(normalized);
  } catch (_) {}
  try {
    final parts = normalized.split(RegExp(r'[-/]', unicode: true));
    if (parts.length >= 3) {
      final year = int.tryParse(parts[0]) ?? 0;
      final month = int.tryParse(parts[1]) ?? 0;
      final day = int.tryParse(parts[2]) ?? 0;
      if (year > 0 && month > 0 && day > 0) {
        return DateTime(year, month, day);
      }
    }
  } catch (_) {}
  return null;
}

List<MealDish> _parseMenuItemsPayload(dynamic raw) {
  if (raw is! List) {
    return [];
  }
  final items = <MealDish>[];
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is Map) {
      final map = item.map((key, value) => MapEntry(key.toString(), value));
      final rawName =
          map['name']?.toString() ?? map['title']?.toString() ?? '';
      final name = rawName.trim();
      final hasName = name.isNotEmpty;
      final hasNutrition =
          map['kcal'] != null ||
          map['protein'] != null ||
          map['carbs'] != null ||
          map['fat'] != null;
      final hasScore = map.containsKey('score') || map.containsKey('scoreLabel');
      final hasComponents =
          map['components'] != null || map['ingredients'] != null;
      if (!hasName && !hasNutrition && !hasScore && !hasComponents) {
        continue;
      }
      final resolvedName = hasName ? name : '菜品${i + 1}';
      if (map.containsKey('score') ||
          map.containsKey('kcal') ||
          map.containsKey('scoreLabel')) {
        final normalized = Map<String, dynamic>.from(map);
        if (!hasName && !normalized.containsKey('name')) {
          normalized['name'] = resolvedName;
        }
        items.add(MealDish.fromJson(normalized));
        continue;
      }
      items.add(
        MealDish(
          id: map['id']?.toString() ?? 'menu_${i + 1}',
          name: resolvedName,
          restaurant: map['restaurant']?.toString() ?? '菜单识别',
          score: (map['score'] as num?)?.toInt() ?? 72,
          scoreLabel: map['scoreLabel']?.toString() ?? '待评估',
          scoreColor: _colorFromHex(
            map['scoreColor']?.toString() ?? 'ff37f07a',
          ),
          kcal: (map['kcal'] as num?)?.toInt() ?? 0,
          protein: (map['protein'] as num?)?.toInt() ?? 0,
          carbs: (map['carbs'] as num?)?.toInt() ?? 0,
          fat: (map['fat'] as num?)?.toInt() ?? 0,
          tag: map['tag']?.toString() ?? '菜单',
          recommended: map['recommended'] as bool? ?? true,
        ),
      );
    } else if (item is String) {
      if (item.trim().isEmpty) {
        continue;
      }
      items.add(
        MealDish(
          id: 'menu_${i + 1}',
          name: item.trim(),
          restaurant: '菜单识别',
          score: 72,
          scoreLabel: '待评估',
          scoreColor: const Color(0xFF37F07A),
          kcal: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          tag: '菜单',
          recommended: true,
        ),
      );
    }
  }
  items.sort((a, b) {
    final scoreDiff = b.score.compareTo(a.score);
    if (scoreDiff != 0) return scoreDiff;
    if (a.recommended == b.recommended) return 0;
    return a.recommended ? -1 : 1;
  });
  return items;
}

List<String> _parseActionListPayload(dynamic raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return _readStringListFromJson(raw);
  }
  return const [];
}

class FoodRecordScreen extends StatefulWidget {
  const FoodRecordScreen({super.key, this.initialMode = _UnifiedScanMode.food});

  final _UnifiedScanMode initialMode;

  @override
  State<FoodRecordScreen> createState() => _FoodRecordScreenState();
}

class _FoodRecordScreenState extends State<FoodRecordScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  final List<XFile> _galleryImages = [];
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocus = FocusNode();
  late final AnimationController _breathController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final Animation<double> _breathAnimation = CurvedAnimation(
    parent: _breathController,
    curve: Curves.easeInOut,
  );
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  bool _cameraReady = false;
  bool _showLiveCamera = true;
  String _cameraError = '';
  bool _submitting = false;
  int _activeIndex = 0;
  _UnifiedScanMode _scanMode = _UnifiedScanMode.food;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanMode = widget.initialMode;
    _breathController.repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = '未检测到可用摄像头';
          _cameraReady = false;
        });
        return;
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraController = controller;
      _cameraInitFuture = controller.initialize();
      await _cameraInitFuture;
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _cameraError = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = '摄像头启动失败';
        _cameraReady = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_submitting) return;
    if (_cameraController == null || !_cameraReady) {
      await _pickFromCamera();
      return;
    }
    try {
      await _cameraInitFuture;
      final file = await _cameraController!.takePicture();
      if (!mounted) return;
      setState(() {
        _images.add(file);
        _activeIndex = _images.length - 1;
        _showLiveCamera = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('拍照失败，请重试')));
    }
  }

  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (!mounted) return;
    if (file != null) {
      setState(() {
        _images.add(file);
        _activeIndex = _images.length - 1;
        _showLiveCamera = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (!mounted) return;
    if (files.isNotEmpty) {
      setState(() {
        _galleryImages
          ..clear()
          ..addAll(files);
        _images.addAll(files);
        _activeIndex = _images.length - 1;
        _showLiveCamera = false;
      });
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      final removed = _images.removeAt(index);
      _galleryImages.removeWhere((item) => item.path == removed.path);
      if (_images.isEmpty) {
        _activeIndex = 0;
        _showLiveCamera = true;
      } else if (_activeIndex >= _images.length) {
        _activeIndex = _images.length - 1;
      }
    });
  }

  void _setActiveImage(int index) {
    if (index < 0 || index >= _images.length) return;
    setState(() {
      _activeIndex = index;
      _showLiveCamera = false;
    });
  }

  void _focusNote() {
    FocusScope.of(context).requestFocus(_noteFocus);
  }

  Future<bool> _ensureLoggedIn(String actionLabel) async {
    await AuthStore.instance.ensureLoaded();
    if (AuthStore.instance.status != 'logged_in' ||
        AuthStore.instance.token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请先登录后再$actionLabel')),
        );
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

  Future<void> _submitRecord() async {
    if (_submitting) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先拍摄或选择食物照片')));
      return;
    }
    if (!await _ensureLoggedIn('记录餐食')) return;
    if (!await _ensureDailyQuota(
      DailyUsageType.mealRecord,
      '今日餐食记录次数已用完，开通订阅可无限使用',
    )) {
      return;
    }
    setState(() => _submitting = true);
    final urls = await OssUploadService.uploadImages(
      images: _images,
      category: 'food',
    );
    if (urls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('上传失败，请检查登录或网络')));
      }
      setState(() => _submitting = false);
      return;
    }
    MealRecord? record;
    try {
      record = await MealStore.instance.createPhotoRecord(
        imageUrls: urls,
        note: _noteController.text.trim(),
      );
    } on DailyQuotaExceededException catch (error) {
      if (mounted) {
        await UserProfileStore.instance.refreshDailyUsageFromServer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        await showSubscriptionSheet(
          context,
          reason: error.message,
          forceShow: !UserProfileStore.instance.isAnnualSubscriber,
        );
      }
      setState(() => _submitting = false);
      return;
    }
    if (!mounted) return;
    if (record == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未识别到食物，请尝试重新拍摄')));
      return;
    }
    UserProfileStore.instance.markDailyUsage(DailyUsageType.mealRecord);
    setState(() => _submitting = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已生成就餐记录')));
    Navigator.of(context).pop('records');
  }

  Future<void> _submitMenuScan() async {
    if (_submitting) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先拍摄或选择菜单照片')));
      return;
    }
    if (!await _ensureLoggedIn('扫描菜单')) return;
    if (!await _ensureDailyQuota(
      DailyUsageType.menuScan,
      '今日菜单扫描次数已用完，开通订阅可无限使用',
    )) {
      return;
    }
    setState(() => _submitting = true);
    final result = await _uploadMenuImages();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == MenuScanResult.empty) {
      return;
    }
    UserProfileStore.instance.markDailyUsage(DailyUsageType.menuScan);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              imageCount: _images.length,
              recognizedText: result.recognizedText,
              summary: result.summary,
              actions: result.actions,
              dishes: result.dishes,
            ),
          ),
        )
        .then((value) {
          if (!mounted) return;
          if (value is Map) {
            Navigator.of(context).pop(value);
            return;
          }
          if (value == 'records') {
            Navigator.of(context).pop('records');
          } else if (value == 'discover') {
            Navigator.of(context).pop('discover');
          }
        });
  }

  Future<MenuScanResult> _uploadMenuImages() async {
    final urls = await OssUploadService.uploadImages(
      images: _images,
      category: 'menu',
    );
    if (urls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('菜单上传失败，请检查登录或网络')));
      }
      return MenuScanResult.empty;
    }
    await AuthStore.instance.ensureLoaded();
    if (AuthStore.instance.token.isEmpty) {
      return MenuScanResult.empty;
    }
    final note = _noteController.text.trim();
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/menu/scan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthStore.instance.token}',
        },
        body: jsonEncode({
          'image_urls': urls,
          'client_time': _formatClientTime(DateTime.now()),
          if (note.isNotEmpty) 'note': note,
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
        if (mounted) {
          await showSubscriptionSheet(
            context,
            reason: (errorMessage != null && errorMessage.isNotEmpty)
                ? errorMessage
                : '今日菜单扫描次数已用完，开通订阅可无限使用',
          );
          UserProfileStore.instance.markDailyUsage(DailyUsageType.menuScan);
        }
        return MenuScanResult.empty;
      }
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = (payload['data'] as Map?) ?? {};
        final text = data['recognized_text'] ?? data['text'] ?? '';
        final summary = data['summary'] ?? '';
        final items = _parseMenuItemsPayload(data['items']);
        final actions = _parseActionListPayload(data['actions']);
        if (items.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  (errorMessage != null && errorMessage.isNotEmpty)
                      ? errorMessage
                      : '未识别到菜单菜品，请尝试重新拍摄',
                ),
              ),
            );
          }
          return MenuScanResult.empty;
        }
        return MenuScanResult(
          recognizedText: text.toString(),
          summary: summary.toString(),
          actions: actions,
          dishes: items,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (errorMessage != null && errorMessage.isNotEmpty)
                  ? errorMessage
                  : '菜单识别失败',
            ),
          ),
        );
      }
      return MenuScanResult.empty;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('菜单识别失败')));
    }
    return MenuScanResult.empty;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _breathController.dispose();
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _cameraController = null;
      if (mounted) {
        setState(() {
          _cameraReady = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController == null) {
        _initCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final isDark = context.isDarkMode;
    final primary = app.primary;
    final accentBlue = app.accentBlue;
    final card = app.card;
    final softBorder = app.border;
    final muted = app.textSecondary;
    final titleColor = app.textPrimary;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final hasImage = _images.isNotEmpty;
    final showLiveCamera =
        _showLiveCamera &&
        _cameraReady &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;
    final isMenuMode = _scanMode == _UnifiedScanMode.menu;
    final previewImage = (!showLiveCamera && hasImage)
        ? _images[_activeIndex]
        : null;
    final backgroundGradient = app.backgroundGradient;
    final cameraOverlayGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.55, 1.0],
      colors: [
        Colors.black.withOpacity(0.45),
        Colors.transparent,
        Colors.black.withOpacity(0.5),
      ],
    );
    final cameraFrameGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              app.card.withOpacity(0.92),
              app.backgroundAlt.withOpacity(0.9),
              app.cardAlt.withOpacity(0.92),
            ]
          : [
              Colors.white.withOpacity(0.92),
              app.backgroundAlt.withOpacity(0.95),
              const Color(0xFFE6F7EF),
            ],
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back_ios, color: titleColor),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _scanMode = _UnifiedScanMode.menu),
                          child: Column(
                            children: [
                              Text(
                                '菜单识别',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _scanMode == _UnifiedScanMode.menu
                                      ? titleColor
                                      : muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: 3,
                                width: 42,
                                decoration: BoxDecoration(
                                  color: _scanMode == _UnifiedScanMode.menu
                                      ? primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _scanMode = _UnifiedScanMode.food),
                          child: Column(
                            children: [
                              Text(
                                '食物识别',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _scanMode == _UnifiedScanMode.food
                                      ? titleColor
                                      : muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: 3,
                                width: 42,
                                decoration: BoxDecoration(
                                  color: _scanMode == _UnifiedScanMode.food
                                      ? primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          110 + safeBottom,
                        ),
                        children: [
                          Center(
                            child: Text(
                              _scanMode == _UnifiedScanMode.menu
                                  ? '拍摄菜单照片并补充说明，方便大胡子推荐'
                                  : '拍摄您整个餐点的照片和/或在下面描述',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: muted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              gradient: cameraFrameGradient,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF111827,
                                  ).withOpacity(0.08),
                                  blurRadius: 22,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: softBorder),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: AspectRatio(
                                    aspectRatio: 4 / 3,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: showLiveCamera
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                  child: CameraPreview(
                                                    _cameraController!,
                                                  ),
                                                )
                                              : (previewImage != null
                                                    ? Image.file(
                                                        File(previewImage.path),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment
                                                                .topCenter,
                                                            end: Alignment
                                                                .bottomCenter,
                                                            colors: [
                                                              app.backgroundAlt,
                                                              app.cardAlt
                                                                  .withOpacity(
                                                                    0.4,
                                                                  ),
                                                            ],
                                                          ),
                                                        ),
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Container(
                                                              width: 64,
                                                              height: 64,
                                                              decoration: BoxDecoration(
                                                                color: primary
                                                                    .withOpacity(
                                                                      0.12,
                                                                    ),
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              child: Icon(
                                                                Icons
                                                                    .restaurant,
                                                                color: primary,
                                                                size: 32,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 12,
                                                            ),
                                                            Text(
                                                              _cameraError
                                                                      .isNotEmpty
                                                                  ? _cameraError
                                                                  : '实时预览加载中…',
                                                              style:
                                                                  GoogleFonts.inter(
                                                                    color:
                                                                        muted,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                            ),
                                                            if (_cameraError
                                                                .isNotEmpty) ...[
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              TextButton(
                                                                onPressed:
                                                                    _initCamera,
                                                                child:
                                                                    const Text(
                                                                      '重试',
                                                                    ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      )),
                                        ),
                                        if (showLiveCamera) ...[
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      cameraOverlayGradient,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: CustomPaint(
                                                painter: _CameraGridPainter(
                                                  color: Colors.white
                                                      .withOpacity(0.16),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.center,
                                            child: IgnorePointer(
                                              child: FractionallySizedBox(
                                                widthFactor: 0.72,
                                                heightFactor: 0.62,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.55),
                                                      width: 1.2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: _CameraPill(
                                              icon: isMenuMode
                                                  ? Icons.menu_book_outlined
                                                  : Icons.local_dining_outlined,
                                              label: isMenuMode
                                                  ? '菜单模式'
                                                  : '餐盘模式',
                                              background: app.card.withOpacity(
                                                0.9,
                                              ),
                                              foreground: titleColor,
                                            ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: app.card.withOpacity(
                                                  0.95,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.qr_code_scanner,
                                                size: 18,
                                                color: titleColor,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 16,
                                            right: 16,
                                            bottom: 14,
                                            child: _CameraHint(
                                              text: isMenuMode
                                                  ? '尽量保持菜单平整，避免反光'
                                                  : '把餐盘放在取景框内，光线更均匀',
                                            ),
                                          ),
                                        ],
                                        if (previewImage != null)
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _removeImageAt(_activeIndex),
                                              child: Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.45),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (previewImage != null)
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(
                                                  () => _showLiveCamera = true,
                                                );
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.45),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Text(
                                                  '继续拍',
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  app.card.withOpacity(0.96),
                                  app.backgroundAlt.withOpacity(0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: softBorder.withOpacity(0.9),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: app.shadow.withOpacity(0.08),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: app.primarySoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.sticky_note_2_outlined,
                                    color: accentBlue,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _noteController,
                                    focusNode: _noteFocus,
                                    maxLines: 3,
                                    minLines: 1,
                                    decoration: InputDecoration(
                                      hintText:
                                          _scanMode == _UnifiedScanMode.menu
                                          ? '补充菜单说明，例如：“含鸡胸肉、少油、想吃高蛋白”'
                                          : '描述你的餐点，例如：“一盘烤鸡配米饭，一小份煮胡萝卜，两杯橙汁”',
                                      border: InputBorder.none,
                                      isDense: true,
                                      hintStyle: GoogleFonts.inter(
                                        color: app.textTertiary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: titleColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text(
                                '相册照片',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _pickFromGallery,
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 16,
                                ),
                                label: const Text('选择'),
                                style: TextButton.styleFrom(
                                  foregroundColor: accentBlue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  (_galleryImages.isEmpty
                                          ? _images
                                          : _galleryImages)
                                      .length +
                                  1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final list = _galleryImages.isEmpty
                                    ? _images
                                    : _galleryImages;
                                if (index == list.length) {
                                  return GestureDetector(
                                    onTap: _pickFromGallery,
                                    child: Container(
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: app.card,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: softBorder),
                                        boxShadow: [
                                          BoxShadow(
                                            color: app.shadow.withOpacity(0.08),
                                            blurRadius: 10,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: app.textSecondary,
                                      ),
                                    ),
                                  );
                                }
                                final file = list[index];
                                final selected =
                                    _images.isNotEmpty &&
                                    _images[_activeIndex].path == file.path;
                                return GestureDetector(
                                  onTap: () {
                                    final targetIndex = _images.indexWhere(
                                      (item) => item.path == file.path,
                                    );
                                    if (targetIndex != -1) {
                                      _setActiveImage(targetIndex);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: app.card,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: selected ? primary : app.border,
                                        width: selected ? 2 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(file.path),
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16 + safeBottom,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _breathAnimation,
                            builder: (context, child) {
                              final t = _breathAnimation.value;
                              return Transform.scale(
                                scale: 1 + 0.06 * t,
                                child: child,
                              );
                            },
                            child: GestureDetector(
                              onTap: _submitting
                                  ? null
                                  : ((showLiveCamera || !hasImage)
                                        ? _capturePhoto
                                        : (isMenuMode
                                              ? _submitMenuScan
                                              : _submitRecord)),
                              child: _ScanActionButton(
                                submitting: _submitting,
                                isCaptureState: showLiveCamera || !hasImage,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraGridPainter extends CustomPainter {
  const _CameraGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    final dx = size.width / 3;
    final dy = size.height / 3;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(dx * i, 0), Offset(dx * i, size.height), paint);
      canvas.drawLine(Offset(0, dy * i), Offset(size.width, dy * i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CameraGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CameraPill extends StatelessWidget {
  const _CameraPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: app.border.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanActionButton extends StatelessWidget {
  const _ScanActionButton({
    required this.submitting,
    required this.isCaptureState,
  });

  final bool submitting;
  final bool isCaptureState;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final outerColor = app.primarySoft.withOpacity(0.9);
    final innerColor = app.primary;

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: outerColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: innerColor.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          color: innerColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
        ),
        child: Center(
          child: submitting
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : (isCaptureState
                    ? SvgPicture.asset(
                        'images/panda_camera.svg',
                        width: 42,
                        height: 42,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      )
                    : const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 40,
                      )),
        ),
      ),
    );
  }
}

class _CameraHint extends StatelessWidget {
  const _CameraHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: app.border.withOpacity(0.6)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ScanMenuScreenState extends State<ScanMenuScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  final List<String> _stages = ['大胡子正在解析菜单', '正在生成推荐'];
  Timer? _timer;
  bool _processing = false;
  int _stageIndex = 0;
  double _progress = 0;
  bool _quotaConsumed = false;

  Future<bool> _ensureLoggedIn(String actionLabel) async {
    await AuthStore.instance.ensureLoaded();
    if (AuthStore.instance.status != 'logged_in' ||
        AuthStore.instance.token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请先登录后再$actionLabel')),
        );
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

  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (!mounted) return;
    if (file != null) {
      setState(() {
        _images.add(file);
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (!mounted) return;
    if (files.isNotEmpty) {
      setState(() {
        _images.addAll(files);
      });
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _startProcessing() {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先拍摄或选择菜单照片')));
      return;
    }
    unawaited(_beginOcrFlow());
  }

  Future<void> _beginOcrFlow() async {
    if (!await _ensureLoggedIn('扫描菜单')) return;
    if (!await _ensureDailyQuota(
      DailyUsageType.menuScan,
      '今日菜单扫描次数已用完，开通订阅可无限使用',
    )) {
      return;
    }
    _timer?.cancel();
    setState(() {
      _processing = true;
      _stageIndex = 0;
      _progress = 0;
      _quotaConsumed = false;
    });

    final progressFuture = _runProgressAnimation();
    final uploadFuture = _uploadMenuImages();

    final result = await uploadFuture;
    await progressFuture;

    if (!mounted) return;
    setState(() {
      _processing = false;
    });

    if (result == MenuScanResult.empty) {
      return;
    }
    if (!_quotaConsumed) {
      _quotaConsumed = UserProfileStore.instance.markDailyUsage(
        DailyUsageType.menuScan,
      );
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              imageCount: _images.length,
              recognizedText: result.recognizedText,
              summary: result.summary,
              actions: result.actions,
              dishes: result.dishes,
            ),
          ),
        )
        .then((value) {
          if (!mounted) return;
          if (value is Map) {
            Navigator.of(context).pop(value);
            return;
          }
          if (value == 'records') {
            Navigator.of(context).pop('records');
          } else if (value == 'discover') {
            Navigator.of(context).pop('discover');
          }
        });
  }

  Future<void> _runProgressAnimation() {
    final completer = Completer<void>();
    const totalTicks = 40;
    _timer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
        return;
      }
      final tick = timer.tick;
      final progress = (tick / totalTicks).clamp(0, 1).toDouble();
      final stage = (progress * _stages.length).floor().clamp(
        0,
        _stages.length - 1,
      );
      setState(() {
        _progress = progress;
        _stageIndex = stage;
      });
      if (tick >= totalTicks) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    return completer.future;
  }

  Future<MenuScanResult> _uploadMenuImages() async {
    final urls = await OssUploadService.uploadImages(
      images: _images,
      category: 'menu',
    );
    if (urls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('菜单上传失败，请检查登录或网络')));
      }
      return MenuScanResult.empty;
    }
    await AuthStore.instance.ensureLoaded();
    if (AuthStore.instance.token.isEmpty) {
      return MenuScanResult.empty;
    }
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/menu/scan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthStore.instance.token}',
        },
        body: jsonEncode({
          'image_urls': urls,
          'client_time': _formatClientTime(DateTime.now()),
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
        if (mounted) {
          await showSubscriptionSheet(
            context,
            reason: (errorMessage != null && errorMessage.isNotEmpty)
                ? errorMessage
                : '今日菜单扫描次数已用完，开通订阅可无限使用',
          );
          UserProfileStore.instance.markDailyUsage(DailyUsageType.menuScan);
        }
        return MenuScanResult.empty;
      }
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = (payload['data'] as Map?) ?? {};
        final text = data['recognized_text'] ?? data['text'] ?? '';
        final summary = data['summary'] ?? '';
        final items = _parseMenuItemsPayload(data['items']);
        final actions = _parseActionListPayload(data['actions']);
        if (items.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  (errorMessage != null && errorMessage.isNotEmpty)
                      ? errorMessage
                      : '未识别到菜单菜品，请尝试重新拍摄',
                ),
              ),
            );
          }
          return MenuScanResult.empty;
        }
        return MenuScanResult(
          recognizedText: text.toString(),
          summary: summary.toString(),
          actions: actions,
          dishes: items,
        );
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('菜单识别失败')));
    }
    return MenuScanResult.empty;
  }

  // parsing helpers moved to top-level for reuse in FoodRecordScreen

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;

    return Scaffold(
      backgroundColor: app.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: app.textPrimary,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      Text(
                        '拍摄或选择菜单照片',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: app.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '支持多张照片识别，系统会自动裁剪并矫正。',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: app.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 240,
                        decoration: BoxDecoration(
                          color: app.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: app.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _images.isEmpty
                              ? Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              app.cardAlt.withOpacity(0.6),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: primary.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.photo_camera,
                                              color: primary,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            '在这里预览菜单照片',
                                            style: GoogleFonts.inter(
                                              color: app.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _images.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: Image.file(
                                            File(_images[index].path),
                                            width: 160,
                                            height: 200,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => _removeImageAt(index),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.6,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_images.isNotEmpty)
                        Row(
                          children: [
                            Text(
                              '已选择 ${_images.length} 张',
                              style: GoogleFonts.inter(
                                color: app.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => setState(() => _images.clear()),
                              child: const Text('清空'),
                            ),
                          ],
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: const [
                          _ScanTipChip(label: '光线充足'),
                          _ScanTipChip(label: '菜单完整'),
                          _ScanTipChip(label: '保持清晰'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFromCamera,
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('拍照添加'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: app.textPrimary,
                                side: BorderSide(color: app.border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFromGallery,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('从相册选择'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: app.textPrimary,
                                side: BorderSide(color: app.border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _processing ? null : _startProcessing,
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
                        child: const Text('开始识别'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_processing)
              _ProcessingOverlay(
                stage: _stages[_stageIndex],
                progress: _progress,
                stageIndex: _stageIndex,
                stageCount: _stages.length,
              ),
          ],
        ),
      ),
    );
  }
}

class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    required this.imageCount,
    required this.recognizedText,
    required this.summary,
    required this.actions,
    required this.dishes,
  });

  final int imageCount;
  final String recognizedText;
  final String summary;
  final List<String> actions;
  final List<MealDish> dishes;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  final Set<String> _selectedIds = {};
  late final List<_ResultCategory> _categories;
  String? _primaryDishId;

  @override
  void initState() {
    super.initState();
    MealStore.instance.ensureLoaded();
    if (widget.dishes.isEmpty) {
      _categories = const [];
    } else {
      _categories = _buildMenuCategories(widget.dishes);
      final sorted = List<MealDish>.from(widget.dishes)
        ..sort((a, b) {
          final scoreDiff = b.score.compareTo(a.score);
          if (scoreDiff != 0) return scoreDiff;
          if (a.recommended == b.recommended) return 0;
          return a.recommended ? -1 : 1;
        });
      if (sorted.isNotEmpty) {
        _primaryDishId = sorted.first.id;
        _selectedIds.add(sorted.first.id);
      }
    }
  }

  List<_ResultCategory> _buildMenuCategories(List<MealDish> dishes) {
    final sorted = List<MealDish>.from(dishes)
      ..sort((a, b) {
        final scoreDiff = b.score.compareTo(a.score);
        if (scoreDiff != 0) return scoreDiff;
        if (a.recommended == b.recommended) return 0;
        return a.recommended ? -1 : 1;
      });
    final top = <MealDish>[];
    final mid = <MealDish>[];
    final low = <MealDish>[];
    for (final dish in sorted) {
      if (dish.score >= 80) {
        top.add(dish);
      } else if (dish.score >= 60) {
        mid.add(dish);
      } else {
        low.add(dish);
      }
    }
    final categories = <_ResultCategory>[];
    if (top.isNotEmpty) {
      categories.add(
        _ResultCategory(title: '优先推荐', subtitle: '分数高 · 更贴合目标', items: top),
      );
    }
    if (mid.isNotEmpty) {
      categories.add(
        _ResultCategory(title: '可以选择', subtitle: '适量即可', items: mid),
      );
    }
    if (low.isNotEmpty) {
      categories.add(
        _ResultCategory(title: '谨慎选择', subtitle: '热量或脂肪偏高', items: low),
      );
    }
    return categories;
  }

  List<String> _mergedActions() {
    final merged = <String>{};
    for (final action in widget.actions) {
      final normalized = action.toLowerCase();
      if (normalized.isNotEmpty) {
        merged.add(normalized);
      }
    }
    for (final action in _extractActionIds(widget.summary)) {
      final normalized = action.toLowerCase();
      if (normalized.isNotEmpty) {
        merged.add(normalized);
      }
    }
    return merged.toList();
  }

  bool _hasAction(String action, List<String> actions) {
    if (actions.isEmpty) {
      return action == 'discover' || action == 'record_meal';
    }
    final normalized = action.toLowerCase();
    return actions.any((item) => item.contains(normalized));
  }

  String _buildAiReplacePrompt() {
    final names = widget.dishes
        .map((dish) => dish.name)
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return '根据我刚扫描的菜单，帮我推荐更健康的替换选择。';
    }
    final sample = names.take(6).join('、');
    return '我刚扫描的菜单包括：$sample。请帮我推荐更健康的替换选择，并说明理由。';
  }

  void _toggleSelection(MealDish dish) {
    setState(() {
      if (_selectedIds.contains(dish.id)) {
        _selectedIds.remove(dish.id);
      } else {
        _selectedIds.add(dish.id);
      }
    });
  }

  void _openDishDetail(MealDish dish) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _DishDetailSheet(
          dish: dish,
          selected: _selectedIds.contains(dish.id),
          onSelectionChanged: (selected) {
            setState(() {
              if (selected) {
                _selectedIds.add(dish.id);
              } else {
                _selectedIds.remove(dish.id);
              }
            });
          },
        );
      },
    );
  }

  Future<void> _saveSelection() async {
    if (_selectedIds.isEmpty) return;
    final selectedDishes = _categories
        .expand((category) => category.items)
        .where((dish) => _selectedIds.contains(dish.id))
        .toList();
    selectedDishes.sort((a, b) => b.score.compareTo(a.score));
    await MealStore.instance.createRecord(
      source: 'menu',
      dishes: selectedDishes,
      meta: {
        'image_count': widget.imageCount,
        if (widget.recognizedText.trim().isNotEmpty)
          'recognized_text': widget.recognizedText.trim(),
        if (widget.summary.trim().isNotEmpty)
          'ai_summary': widget.summary.trim(),
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已记录本次用餐 · ${selectedDishes.length} 道菜')),
    );
    Navigator.of(context).pop('records');
  }

  Future<void> _recordAll() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择要记录的菜品')));
      return;
    }
    await _saveSelection();
  }

  void _openAiReplace() {
    final prompt = _buildAiReplacePrompt();
    Navigator.of(context).pop({'action': 'ai_replace', 'prompt': prompt});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final actions = _mergedActions();
    final summaryText = _stripActionTokens(widget.summary);

    return Scaffold(
      backgroundColor: app.background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: app.card,
            border: Border(top: BorderSide(color: app.border)),
            boxShadow: [
              BoxShadow(
                color: app.shadow.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已选择 ${_selectedIds.length} 道菜',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: app.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedIds.isEmpty ? '点击菜品卡片即可选择' : '可多选后一起记录为一餐',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: app.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _selectedIds.isEmpty ? null : _saveSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: app.textInverse,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('加入本次用餐'),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios, color: app.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      '识别结果',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: app.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  if (summaryText.trim().isNotEmpty || actions.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: app.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: app.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              color: primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '大胡子的菜单建议',
                                  style: GoogleFonts.inter(
                                    color: app.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (summaryText.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    summaryText.trim(),
                                    style: GoogleFonts.inter(
                                      color: app.textSecondary,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_hasAction('discover', actions) ||
                        _hasAction('record_meal', actions) ||
                        _hasAction('ai_replace', actions)) ...[
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final buttons = <Widget>[];
                          if (_hasAction('discover', actions)) {
                            buttons.add(
                              OutlinedButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).pop('discover'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: app.textPrimary,
                                  side: BorderSide(color: app.border),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.explore, size: 18),
                                label: Text(
                                  '去发现',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (_hasAction('record_meal', actions)) {
                            buttons.add(
                              ElevatedButton.icon(
                                onPressed: widget.dishes.isEmpty
                                    ? null
                                    : _recordAll,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: app.textInverse,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: Text(
                                  '一键记录',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (_hasAction('ai_replace', actions)) {
                            buttons.add(
                              OutlinedButton.icon(
                                onPressed: _openAiReplace,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primary,
                                  side: BorderSide(
                                    color: primary.withOpacity(0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.auto_fix_high, size: 18),
                                label: Text(
                                  '大胡子替换',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (buttons.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final width = buttons.length == 1
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: buttons
                                .map(
                                  (button) =>
                                      SizedBox(width: width, child: button),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: app.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: app.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_circle, color: primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '已识别 ${widget.imageCount} 张菜单照片',
                            style: GoogleFonts.inter(
                              color: app.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_categories.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: app.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: app.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: app.cardAlt,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              color: app.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '未识别到菜单菜品，请尝试重新扫描',
                              style: GoogleFonts.inter(
                                color: app.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._categories.map(
                      (category) => _ResultCategorySection(
                        category,
                        selectedIds: _selectedIds,
                        highlightedId: _primaryDishId,
                        onToggle: _toggleSelection,
                        onOpenDetail: _openDishDetail,
                      ),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
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
                    child: const Text('重新扫描'),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCategory {
  const _ResultCategory({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<MealDish> items;
}

class _ResultCategorySection extends StatelessWidget {
  const _ResultCategorySection(
    this.category, {
    required this.selectedIds,
    required this.highlightedId,
    required this.onToggle,
    required this.onOpenDetail,
  });

  final _ResultCategory category;
  final Set<String> selectedIds;
  final String? highlightedId;
  final ValueChanged<MealDish> onToggle;
  final ValueChanged<MealDish> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final isCaution = category.items.any((dish) => !dish.recommended);
    final headerColor = isCaution
        ? const Color(0xFFF59E0B)
        : const Color(0xFF13EC5B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: headerColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: headerColor.withOpacity(0.6), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              category.title,
              style: GoogleFonts.inter(
                color: app.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          category.subtitle,
          style: GoogleFonts.inter(color: app.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...category.items.map(
          (entry) => _ResultEntryTile(
            entry: entry,
            selected: selectedIds.contains(entry.id),
            highlighted: highlightedId == entry.id,
            onToggle: () => onToggle(entry),
            onOpenDetail: () => onOpenDetail(entry),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ResultEntryTile extends StatelessWidget {
  const _ResultEntryTile({
    required this.entry,
    required this.selected,
    required this.onToggle,
    required this.onOpenDetail,
    required this.highlighted,
  });

  final MealDish entry;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onOpenDetail;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final tone = entry.recommended ? entry.scoreColor : const Color(0xFFF59E0B);
    final surface = entry.recommended ? app.card : app.cardAlt;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: tone.withOpacity(selected ? 0.3 : 0.12),
            blurRadius: selected ? 20 : 10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: app.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onToggle,
          onLongPress: onOpenDetail,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: highlighted ? tone.withOpacity(0.12) : surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? tone.withOpacity(0.9) : app.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlighted) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tone.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: tone.withOpacity(0.6)),
                        ),
                        child: Text(
                          '大胡子精选',
                          style: GoogleFonts.inter(
                            color: tone,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: tone.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          entry.recommended
                              ? Icons.thumb_up_alt_rounded
                              : Icons.warning_amber_rounded,
                          color: tone,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.name,
                              style: GoogleFonts.inter(
                                color: app.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.restaurant,
                              style: GoogleFonts.inter(
                                color: app.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected ? tone : app.cardAlt,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? tone : app.border,
                          ),
                        ),
                        child: Icon(
                          selected ? Icons.check : Icons.add,
                          color: selected ? app.textInverse : app.textSecondary,
                          size: 18,
                        ),
                      ),
                      IconButton(
                        onPressed: onOpenDetail,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: Icon(
                          Icons.info_outline,
                          color: app.textTertiary,
                          size: 18,
                        ),
                        tooltip: '查看详情',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tone.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: tone.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              entry.recommended
                                  ? Icons.check_circle
                                  : Icons.do_not_disturb_on,
                              color: tone,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.recommended ? '推荐' : '不推荐',
                              style: GoogleFonts.inter(
                                color: tone,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${entry.score}',
                        style: GoogleFonts.inter(
                          color: tone,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.scoreLabel,
                        style: GoogleFonts.inter(
                          color: tone,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _NutritionChip(label: '${entry.kcal} 千卡'),
                      _NutritionChip(label: '蛋白 ${entry.protein}g'),
                      _NutritionChip(label: '碳水 ${entry.carbs}g'),
                      _NutritionChip(label: '脂肪 ${entry.fat}g'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: tone.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      entry.tag,
                      style: GoogleFonts.inter(
                        color: tone,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DishDetailSheet extends StatefulWidget {
  const _DishDetailSheet({
    required this.dish,
    required this.selected,
    required this.onSelectionChanged,
  });

  final MealDish dish;
  final bool selected;
  final ValueChanged<bool> onSelectionChanged;

  @override
  State<_DishDetailSheet> createState() => _DishDetailSheetState();
}

class _DishDetailSheetState extends State<_DishDetailSheet> {
  late bool _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  void _toggleSelection() {
    setState(() {
      _selected = !_selected;
    });
    widget.onSelectionChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final background = app.background;
    final card = app.card;
    final tone = widget.dish.recommended
        ? widget.dish.scoreColor
        : const Color(0xFFF59E0B);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: app.border),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: app.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: app.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: tone.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.dish.recommended
                            ? Icons.thumb_up_alt_rounded
                            : Icons.warning_amber_rounded,
                        color: tone,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.dish.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: app.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.dish.restaurant,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: app.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${widget.dish.score}',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: tone,
                          ),
                        ),
                        Text(
                          widget.dish.scoreLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tone,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _NutritionChip(label: '${widget.dish.kcal} 千卡'),
                  _NutritionChip(label: '蛋白 ${widget.dish.protein}g'),
                  _NutritionChip(label: '碳水 ${widget.dish.carbs}g'),
                  _NutritionChip(label: '脂肪 ${widget.dish.fat}g'),
                ],
              ),
              if (widget.dish.components.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: app.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '组成要素',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: app.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.dish.components
                            .take(8)
                            .map(
                              (item) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: app.cardAlt,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: app.border),
                                ),
                                child: Text(
                                  item,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: app.textSecondary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: app.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.dish.recommended ? '推荐理由' : '注意事项',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: app.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.dish.reason.isNotEmpty
                          ? widget.dish.reason
                          : (widget.dish.recommended
                                ? '蛋白密度高、脂肪适中，适合当前训练阶段补充。'
                                : '脂肪和热量偏高，建议控制份量或改为低脂替代。'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: app.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _toggleSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tone,
                  foregroundColor: app.textInverse,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(_selected ? '已加入本次用餐' : '加入本次用餐'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NutritionChip extends StatelessWidget {
  const _NutritionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: app.cardAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: app.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: app.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProcessingOverlay extends StatefulWidget {
  const _ProcessingOverlay({
    required this.stage,
    required this.progress,
    required this.stageIndex,
    required this.stageCount,
  });

  final String stage;
  final double progress;
  final int stageIndex;
  final int stageCount;

  @override
  State<_ProcessingOverlay> createState() => _ProcessingOverlayState();
}

class _ProcessingOverlayState extends State<_ProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: app.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: app.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primary.withOpacity(0.35),
                        primary.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Icon(Icons.auto_awesome, color: primary, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.stage,
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) {
                        final width = constraints.maxWidth;
                        final highlightWidth = width * 0.35;
                        final left =
                            (width - highlightWidth) * _scanController.value;
                        return Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: app.border,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: SizedBox(
                                height: 10,
                                width: width * widget.progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primary.withOpacity(0.25),
                                        primary,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: left,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: highlightWidth,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      app.textPrimary.withOpacity(0.35),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) {
                    final dot = (_scanController.value * 3).floor() % 3;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        final active = index == dot;
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: active
                                ? primary
                                : app.textTertiary.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  '智能分析中，请稍候…',
                  style: GoogleFonts.inter(
                    color: app.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanTipChip extends StatelessWidget {
  const _ScanTipChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: app.cardAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: app.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: app.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  const _ScanFab({
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.45),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: backgroundColor,
        elevation: 0,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.string(
                  _pandaCameraSvg,
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    foregroundColor,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '扫描菜单',
                  style: GoogleFonts.inter(
                    color: foregroundColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
