part of '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;
  final Random _chatbotRandom = Random();
  Timer? _chatbotHintTimer;
  bool _showChatbotHint = false;
  String _chatbotHintText = '';
  final List<_ChatMessage> _homeMessages = [];
  final TextEditingController _homeInputController = TextEditingController();
  final ScrollController _homeScrollController = ScrollController();
  final ImagePicker _chatImagePicker = ImagePicker();
  ShakeDetector? _shakeDetector;
  double _shakeThreshold = 2.0;
  bool _shakeProcessing = false;

  static const List<String> _chatbotHints = [
    '你好，我是大胡子，可以帮你规划训练。',
    '点我聊聊，给你今日训练建议。',
    '尼古拉·卡洛夫在此，随时为你定制饮食计划。',
    '需要放纵日安排？我可以帮你规划。',
    '想提升训练效率？我来给你方案。',
  ];

  @override
  void initState() {
    super.initState();
    MealStore.instance.ensureLoaded();
    unawaited(
      UserProfileStore.instance.ensureLoaded().then((_) {
        if (mounted) {
          _syncShakeDetector();
        }
      }),
    );
    unawaited(_prefetchWeeklyMenus());
    _scheduleChatbotHint();
    unawaited(_initHomeChat());
    UserProfileStore.instance.addListener(_syncShakeDetector);
    _syncShakeDetector();
  }

  @override
  void dispose() {
    _chatbotHintTimer?.cancel();
    _homeInputController.dispose();
    _homeScrollController.dispose();
    _shakeDetector?.stopListening();
    UserProfileStore.instance.removeListener(_syncShakeDetector);
    super.dispose();
  }

  void _syncShakeDetector() {
    if (!mounted) return;
    final enabled = UserProfileStore.instance.shakeToScanEnabled;
    final threshold = UserProfileStore.instance.shakeSensitivity;
    if (!enabled) {
      _shakeDetector?.stopListening();
      _shakeDetector = null;
      return;
    }
    if (_shakeDetector != null && _shakeThreshold == threshold) {
      return;
    }
    _shakeDetector?.stopListening();
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: _handleShake,
      shakeThresholdGravity: threshold,
    );
    _shakeThreshold = threshold;
  }

  void _handleShake() {
    if (!mounted) return;
    if (_shakeProcessing || !UserProfileStore.instance.shakeToScanEnabled) {
      return;
    }
    _shakeProcessing = true;
    HapticFeedback.mediumImpact();
    unawaited(
      () async {
        if (!await _ensureLoggedIn('记录餐食')) return;
        if (!await _ensureDailyQuota(
          DailyUsageType.mealRecord,
          '今日餐食记录次数已用完，开通订阅可无限使用',
        )) {
          return;
        }
        await _captureQuickFoodRecord();
      }().whenComplete(() {
        _shakeProcessing = false;
      }),
    );
  }

  Future<void> _prefetchWeeklyMenus() async {
    await AuthStore.instance.ensureLoaded();
    await UserProfileStore.instance.ensureLoaded();
    if (AuthStore.instance.token.isEmpty) return;
    final forceGenerate = UserProfileStore.instance.discoverDevMode;
    await DiscoverMenuStore.instance.prefetchWeek(forceGenerate: forceGenerate);
  }

  Future<void> _captureQuickFoodRecord() async {
    await _openFoodScan();
  }

  Future<void> _initHomeChat() async {
    final store = UserProfileStore.instance;
    await store.ensureLoaded();
    final completed = await _hasCompletedSetup();
    if (!mounted) return;
    if (!completed) {
      if (_homeMessages.isEmpty) {
        setState(() {
          _homeMessages.add(
            _ChatMessage(
              text: _buildHomeChatIntro(store),
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollHomeToBottom(force: true);
        Future.delayed(const Duration(milliseconds: 80), () {
          _scrollHomeToBottom(force: true);
        });
      }
      return;
    }
    if (_homeMessages.isNotEmpty) return;
    final loaded = await _loadChatHistory();
    if (loaded || !mounted) return;
    setState(() {
      _homeMessages.add(
        _ChatMessage(
          text: _buildHomeChatIntro(store),
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollHomeToBottom(force: true);
  }

  Future<bool> _loadChatHistory() async {
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) return false;
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/chat/messages?limit=100'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = payload['data'];
        if (data is List && data.isNotEmpty) {
          final trimmed = data.length > 100
              ? data.sublist(0, 100)
              : List.of(data);
          final messages = <_ChatMessage>[];
          for (final item in trimmed.reversed) {
            if (item is Map) {
              final map = item.map((k, v) => MapEntry(k.toString(), v));
              final role = map['role']?.toString() ?? 'assistant';
              final rawText = map['text']?.toString() ?? '';
              final text = role == 'assistant'
                  ? _sanitizeAiReply(rawText)
                  : rawText;
              final imageUrls = _parseImageUrls(map['image_urls']);
              messages.add(
                _ChatMessage(
                  text: text,
                  isUser: role == 'user',
                  timestamp:
                      DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                      DateTime.now(),
                  imageUrls: imageUrls,
                ),
              );
            }
          }
          if (!mounted) return false;
          setState(() {
            _homeMessages
              ..clear()
              ..addAll(messages);
          });
          _scrollHomeToBottom(force: true);
          if (messages.any((msg) => msg.imageUrls.isNotEmpty)) {
            unawaited(_signChatImagesInHistory());
          }
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _signChatImagesInHistory() async {
    final allUrls = <String>{};
    for (final msg in _homeMessages) {
      allUrls.addAll(msg.imageUrls);
    }
    if (allUrls.isEmpty) return;
    final urls = allUrls.toList();
    final signed = await OssUploadService.signUrls(urls);
    if (signed.isEmpty || !mounted) return;
    final mapping = <String, String>{};
    for (var i = 0; i < signed.length && i < urls.length; i++) {
      mapping[urls[i]] = signed[i];
    }
    setState(() {
      for (var i = 0; i < _homeMessages.length; i++) {
        final msg = _homeMessages[i];
        if (msg.imageUrls.isEmpty) continue;
        final updated = msg.imageUrls
            .map((url) => mapping[url] ?? url)
            .toList();
        _homeMessages[i] = _ChatMessage(
          text: msg.text,
          isUser: msg.isUser,
          timestamp: msg.timestamp,
          imageUrls: updated,
        );
      }
    });
  }

  List<String> _parseImageUrls(dynamic raw) {
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

  void _scheduleChatbotHint() {
    _chatbotHintTimer?.cancel();
    final delay = Duration(seconds: 6 + _chatbotRandom.nextInt(9));
    _chatbotHintTimer = Timer(delay, _showChatbotHintOnce);
  }

  void _showChatbotHintOnce() {
    if (!mounted) return;
    if (_tabIndex != 0) {
      _scheduleChatbotHint();
      return;
    }
    setState(() {
      _chatbotHintText =
          _chatbotHints[_chatbotRandom.nextInt(_chatbotHints.length)];
      _showChatbotHint = true;
    });
    _chatbotHintTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _showChatbotHint = false);
      _scheduleChatbotHint();
    });
  }

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

  Future<void> _openScanMenu() async {
    if (!await _ensureLoggedIn('扫描菜单')) return;
    if (!await _ensureDailyQuota(
      DailyUsageType.menuScan,
      '今日菜单扫描次数已用完，开通订阅可无限使用',
    )) {
      return;
    }
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const FoodRecordScreen(initialMode: _UnifiedScanMode.menu),
      ),
    );
    if (!mounted) return;
    if (result is Map) {
      final action = result['action']?.toString();
      if (action == 'ai_replace') {
        final prompt = result['prompt']?.toString().trim() ?? '';
        setState(() => _tabIndex = 0);
        if (prompt.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _sendHomeQuickPrompt(prompt);
          });
        }
        return;
      }
      if (action == 'records') {
        setState(() => _tabIndex = 2);
        return;
      }
      if (action == 'discover') {
        setState(() => _tabIndex = 1);
        return;
      }
    }
    if (result == 'records') {
      setState(() => _tabIndex = 2);
    } else if (result == 'discover') {
      setState(() => _tabIndex = 1);
    }
  }

  Future<void> _openFoodScan() async {
    if (!await _ensureLoggedIn('记录餐食')) return;
    if (!await _ensureDailyQuota(
      DailyUsageType.mealRecord,
      '今日餐食记录次数已用完，开通订阅可无限使用',
    )) {
      return;
    }
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const FoodRecordScreen(initialMode: _UnifiedScanMode.food),
      ),
    );
    if (!mounted) return;
    if (result == 'records') {
      setState(() => _tabIndex = 2);
    }
  }

  void _showScanOptions() {
    _openScanMenu();
  }

  void _showPendingReviews({String? focusRecordId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PendingReviewSheet(focusRecordId: focusRecordId),
    );
  }

  void _handleActionTap(String action) {
    switch (action) {
      case 'discover':
        setState(() => _tabIndex = 1);
        break;
      case 'history':
        setState(() => _tabIndex = 2);
        break;
      case 'setting':
        setState(() => _tabIndex = 3);
        break;
      case 'xiangji':
        unawaited(_openScanMenu());
        break;
      case 'record_meal':
        unawaited(_openFoodScan());
        break;
      case 'ai_replace':
        setState(() => _tabIndex = 1);
        break;
      case 'home':
        _goHomeTab();
        break;
      default:
        break;
    }
  }

  void _goHomeTab() {
    setState(() => _tabIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollHomeToBottom(force: true);
      Future.delayed(const Duration(milliseconds: 80), () {
        _scrollHomeToBottom(force: true);
      });
    });
  }

  Future<void> _sendHomeMessage() async {
    final text = _homeInputController.text.trim();
    if (text.isEmpty) return;
    if (!await _ensureLoggedIn('提问')) return;
    if (!await _ensureDailyQuota(
      DailyUsageType.question,
      '今日提问次数已用完，开通订阅可无限使用',
    )) {
      return;
    }
    setState(() {
      _homeMessages.add(
        _ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
    });
    _addTypingIndicator();
    _homeInputController.clear();
    _scrollHomeToBottom();
    UserProfileStore.instance.markDailyUsage(DailyUsageType.question);
    unawaited(_saveChatMessage(role: 'user', text: text));
    unawaited(_requestAIReply(text));
  }

  void _sendHomeQuickPrompt(String text) {
    _homeInputController.text = text;
    unawaited(_sendHomeMessage());
  }

  Future<void> _pickChatFromCamera() async {
    final file = await _chatImagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (!mounted) return;
    if (file != null) {
      await _uploadChatImages([file]);
    }
  }

  Future<void> _pickChatFromGallery() async {
    final files = await _chatImagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (!mounted) return;
    if (files.isNotEmpty) {
      await _uploadChatImages(files);
    }
  }

  Future<void> _uploadChatImages(List<XFile> images) async {
    if (images.isEmpty) return;
    if (!await _ensureLoggedIn('提问')) return;
    if (!await _ensureDailyQuota(
      DailyUsageType.question,
      '今日提问次数已用完，开通订阅可无限使用',
    )) {
      return;
    }
    final urls = await OssUploadService.uploadImages(
      images: images,
      category: 'chat',
    );
    if (!mounted) return;
    if (urls.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片上传失败，请检查登录或网络')));
      return;
    }
    UserProfileStore.instance.markDailyUsage(DailyUsageType.question);
    final signedUrls = await OssUploadService.signUrls(urls);
    setState(() {
      _homeMessages.add(
        _ChatMessage(
          text: '',
          isUser: true,
          timestamp: DateTime.now(),
          imageUrls: signedUrls.isNotEmpty ? signedUrls : urls,
        ),
      );
    });
    _scrollHomeToBottom();
    unawaited(_saveChatMessage(role: 'user', text: '', imageUrls: urls));
    unawaited(_requestAIReplyWithImages(urls));
  }

  void _addTypingIndicator() {
    final existingIndex =
        _homeMessages.lastIndexWhere((m) => !m.isUser && m.isTyping);
    if (existingIndex == -1) {
      setState(() {
        _homeMessages.add(
          _ChatMessage(
            text: '',
            isUser: false,
            isTyping: true,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  void _removeTypingIndicator() {
    final index =
        _homeMessages.lastIndexWhere((m) => !m.isUser && m.isTyping);
    if (index >= 0) {
      setState(() {
        _homeMessages.removeAt(index);
      });
    }
  }

  void _simulateHomeReply(String text) {
    Future.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      final reply = _generateHomeReply(text);
      setState(() {
        _homeMessages.add(
          _ChatMessage(text: reply, isUser: false, timestamp: DateTime.now()),
        );
      });
      _scrollHomeToBottom();
      unawaited(_saveChatMessage(role: 'assistant', text: reply));
    });
  }

  Future<void> _requestAIReply(String text) async {
    final reply = await _fetchAIReply(text: text, markdownHint: true);
    if (!mounted) return;
    _removeTypingIndicator();
    final output = reply.isNotEmpty ? reply : _generateHomeReply(text);
    setState(() {
      _homeMessages.add(
        _ChatMessage(text: output, isUser: false, timestamp: DateTime.now()),
      );
    });
    _scrollHomeToBottom();
    unawaited(_saveChatMessage(role: 'assistant', text: output));
  }

  Future<void> _requestAIReplyWithImages(List<String> imageUrls) async {
    final reply = await _fetchAIReply(
      text: '请根据图片内容给出营养与饮食建议。',
      imageUrls: imageUrls,
      markdownHint: true,
    );
    if (!mounted) return;
    _removeTypingIndicator();
    if (reply.isEmpty) return;
    setState(() {
      _homeMessages.add(
        _ChatMessage(text: reply, isUser: false, timestamp: DateTime.now()),
      );
    });
    _scrollHomeToBottom();
    unawaited(_saveChatMessage(role: 'assistant', text: reply));
  }

  Future<String> _fetchAIReply({
    required String text,
    List<String> imageUrls = const [],
    bool markdownHint = false,
  }) async {
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) return '';
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/chat/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({
          'text': text,
          if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
          'history_limit': 8,
          'client_time': _formatClientTime(DateTime.now()),
          if (markdownHint)
            'format_hint':
                '请用 Markdown 格式输出，适当分段和列表，突出重点，避免长段落。',
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
        await UserProfileStore.instance.refreshDailyUsageFromServer();
        if (mounted) {
          final remain =
              response.headers['x-quota-remaining'] ??
              response.headers['X-Quota-Remaining'];
          final msg = (errorMessage != null && errorMessage.isNotEmpty)
              ? errorMessage
              : '额度已用完，订阅可继续使用';
          final tip = remain != null ? '$msg（剩余 $remain 分）' : msg;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tip)));
          await showSubscriptionSheet(
            context,
            reason: tip,
            forceShow: !UserProfileStore.instance.isAnnualSubscriber,
          );
        }
        return '';
      }
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = payload['data'];
        if (data is Map && data['reply'] != null) {
          final cleaned = data['reply'].toString();
          return cleaned.trim();
        }
      }
    } catch (_) {}
    return '';
  }

  String _sanitizeAiReply(String raw) {
    // 轻量处理：还原转义换行，去掉首尾空白，其余保持原样（Markdown 交由前端气泡折行）
    return raw
        .replaceAll('\\r', '')
        .replaceAll('\\n', '\n')
        .trim();
  }

  String _formatAssistantText(String input) {
    var cleaned = input.replaceAll('\\n', '\n').replaceAll('\r', '');
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([。！？!?,，])'),
      (m) => '${m.group(0)}\n',
    );
    final sentences = cleaned
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) return cleaned;
    return sentences.map((s) => '• $s').join('\n');
  }

  String _stripCodeFence(String raw) {
    var text = raw.trim();
    if (!text.startsWith('```')) return text;
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '').trim();
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3).trim();
    }
    return text;
  }

  String? _extractJsonPayload(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('{') || text.startsWith('[')) {
      return text;
    }
    final startObj = text.indexOf('{');
    final endObj = text.lastIndexOf('}');
    if (startObj >= 0 && endObj > startObj) {
      return text.substring(startObj, endObj + 1);
    }
    final startArr = text.indexOf('[');
    final endArr = text.lastIndexOf(']');
    if (startArr >= 0 && endArr > startArr) {
      return text.substring(startArr, endArr + 1);
    }
    return null;
  }

  String? _extractLooseSummary(String raw) {
    final candidates = <RegExp>[
      RegExp(r'''(?:"summary"|'summary'|summary)\s*:\s*"([^"]+)"'''),
      RegExp(r'''(?:"reply"|'reply'|reply)\s*:\s*"([^"]+)"'''),
      RegExp(r'''(?:"message"|'message'|message)\s*:\s*"([^"]+)"'''),
      RegExp(r'''(?:"text"|'text'|text)\s*:\s*"([^"]+)"'''),
    ];
    for (final pattern in candidates) {
      final match = pattern.firstMatch(raw);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  String _pickReplyText(dynamic decoded) {
    if (decoded is String) return decoded.trim();
    if (decoded is List) {
      for (final item in decoded) {
        final picked = _pickReplyText(item);
        if (picked.isNotEmpty) return picked;
      }
      return '';
    }
    if (decoded is Map) {
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      for (final key in const [
        'reply',
        'message',
        'answer',
        'summary',
        'text',
        'content',
      ]) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      final data = map['data'];
      if (data != null) {
        final picked = _pickReplyText(data);
        if (picked.isNotEmpty) return picked;
      }
      final choices = map['choices'];
      if (choices is List) {
        final picked = _pickReplyText(choices);
        if (picked.isNotEmpty) return picked;
      }
    }
    return '';
  }

  String _summarizeJson(dynamic decoded) {
    if (decoded is Map) {
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      final summary = map['summary'];
      if (summary is String && summary.trim().isNotEmpty) {
        return summary.trim();
      }
      final message = map['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      final reply = map['reply'];
      if (reply is String && reply.trim().isNotEmpty) {
        return reply.trim();
      }
      final dishes = map['dishes'];
      if (dishes != null) {
        final summarized = _summarizeJson(dishes);
        if (summarized.isNotEmpty) return summarized;
      }
      final items = map['items'];
      if (items != null) {
        final summarized = _summarizeJson(items);
        if (summarized.isNotEmpty) return summarized;
      }
      return '';
    }
    if (decoded is List) {
      final lines = <String>[];
      for (final item in decoded) {
        if (item is Map) {
          final row = item.map((k, v) => MapEntry(k.toString(), v));
          final title = row['name'] ?? row['title'] ?? row['dish'];
          final reason = row['reason'] ?? row['summary'] ?? row['text'];
          final action = row['action_suggestion'] ?? row['action'];
          final buffer = StringBuffer();
          if (title != null && title.toString().trim().isNotEmpty) {
            buffer.write(title.toString().trim());
          }
          if (reason != null && reason.toString().trim().isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write('：');
            buffer.write(reason.toString().trim());
          }
          if (action != null && action.toString().trim().isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write(' ');
            buffer.write(action.toString().trim());
          }
          final line = buffer.toString().trim();
          if (line.isNotEmpty) {
            lines.add('• $line');
          }
        } else if (item is String && item.trim().isNotEmpty) {
          lines.add('• ${item.trim()}');
        }
      }
      return lines.join('\n');
    }
    return '';
  }

  String _generateHomeReply(String text) {
    if (text.contains('放纵')) {
      return '放纵日建议控制在每周 1-2 次，并安排在训练强度较低的日子。要我帮你调整周期计划吗？';
    }
    if (text.contains('训练')) {
      return '今天更适合做力量 + 核心的组合训练，时长 45 分钟左右。你更偏好器械还是徒手？';
    }
    if (text.contains('热量') || text.contains('kcal')) {
      return '我会根据你当前设置的热量目标来优化餐单与训练日的摄入比例。';
    }
    if (text.contains('体重') || text.contains('减脂')) {
      return '减脂阶段建议稳定热量缺口，并保持蛋白充足。你希望我给你一个一周计划吗？';
    }
    return '收到。我会结合你的设置给出建议，可以告诉我今天的训练或饮食目标。';
  }

  Future<void> _saveChatMessage({
    required String role,
    required String text,
    List<String> imageUrls = const [],
  }) async {
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) {
      return;
    }
    try {
      await http.post(
        Uri.parse('$_apiBaseUrl/chat/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({'role': role, 'text': text, 'image_urls': imageUrls}),
      );
    } catch (_) {
      // ignore chat sync errors
    }
  }

  void _scrollHomeToBottom({bool force = false}) {
    _scheduleScrollToBottom(force: force);
  }

  void _scheduleScrollToBottom({bool force = false, int retries = 4}) {
    void tryScroll() {
      if (!_homeScrollController.hasClients) return;
      final position = _homeScrollController.position;
      final target = position.maxScrollExtent;
      if (!force && (target - position.pixels).abs() > 140) {
        return;
      }
      _homeScrollController.jumpTo(target);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryScroll();
    });

    // 再补充几次，避免首次进入时列表尚未挂载
    for (var i = 1; i <= retries; i++) {
      Future.delayed(Duration(milliseconds: 60 * i), () {
        if (!mounted) return;
        tryScroll();
      });
    }
  }

  Widget _buildHomeTab(BuildContext context, {bool showHeader = true}) {
    final app = context.appColors;
    final primary = app.primary;
    final background = app.background;
    final card = app.card;
    return Container(
      color: background,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: UserProfileStore.instance,
                      builder: (context, child) {
                        final store = UserProfileStore.instance;
                        final asset = _defaultAvatarAsset(store.gender);
                        final local = store.displayAvatarLocalPath;
                        if (local != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(local),
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        final avatar = store.displayAvatarUrl.trim();
                        if (avatar.isNotEmpty) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              avatar,
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        return SizedBox(
                          width: 42,
                          height: 42,
                          child: Image.asset(asset, fit: BoxFit.cover),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: UserProfileStore.instance,
                        builder: (context, child) {
                          final name =
                              UserProfileStore.instance.userName.trim().isEmpty
                              ? '大胡子'
                              : UserProfileStore.instance.userName;
                          return Text(
                            name,
                            style: GoogleFonts.inter(
                              color: app.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          );
                        },
                      ),
                    ),
                    AnimatedBuilder(
                      animation: MealStore.instance,
                      builder: (context, child) {
                        final pending =
                            MealStore.instance.pendingRecords.length;
                        return _AnimatedBellButton(
                          onTap: _showPendingReviews,
                          active: pending > 0,
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      UserProfileStore.instance,
                      MealStore.instance,
                    ]),
                    builder: (context, child) {
                      final store = UserProfileStore.instance;
                      final mealStore = MealStore.instance;
                      final target = store.calorieTarget > 0
                          ? store.calorieTarget
                          : 2400;
                      final consumed = _calculateTodayCalories(mealStore);
                      final remaining = max(target - consumed, 0);
                      final overshoot = max(consumed - target, 0);
                      final rawProgress = target == 0 ? 0.0 : consumed / target;
                      final progress = rawProgress.clamp(0.0, 1.0).toDouble();
                      final isOver = overshoot > 0;
                      final statusText = isOver
                          ? '超出 $overshoot kcal'
                          : '剩余 $remaining kcal';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: app.border),
                          boxShadow: [
                            BoxShadow(
                              color: app.shadow.withOpacity(0.16),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '目标：${store.goalType}',
                              style: GoogleFonts.inter(
                                color: app.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '今日已摄入 $consumed / $target kcal · $statusText',
                              style: GoogleFonts.inter(
                                color: app.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final barWidth = constraints.maxWidth;
                                  return Container(
                                    height: 6,
                                    color: app.border.withOpacity(0.5),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: barWidth * progress,
                                        decoration: BoxDecoration(
                                          color: isOver ? null : primary,
                                          gradient: isOver
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFFB454),
                                                    Color(0xFFFF7A2F),
                                                  ],
                                                )
                                              : null,
                                          boxShadow: isOver
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFFFFB454,
                                                    ).withOpacity(0.35),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: app.backgroundAlt,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    children: [
                      Expanded(
                        child: AnimatedBuilder(
                          animation: UserProfileStore.instance,
                          builder: (context, child) {
                            final store = UserProfileStore.instance;
                            final suggestions = _buildHomeChatSuggestions(
                              store,
                            );
                            final widgets = <Widget>[];
                            if (_homeMessages.isNotEmpty) {
                              widgets.add(
                                _ChatBubble(
                                  message: _homeMessages.first,
                                  onActionTap: _handleActionTap,
                                ),
                              );
                              widgets.add(const SizedBox(height: 10));
                              widgets.add(
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: suggestions
                                        .map(
                                          (text) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: _ChatSuggestionChip(
                                              label: text,
                                              onTap: () =>
                                                  _sendHomeQuickPrompt(text),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              );
                              widgets.add(const SizedBox(height: 16));
                              for (var i = 1; i < _homeMessages.length; i++) {
                                widgets.add(
                                  _ChatBubble(
                                    message: _homeMessages[i],
                                    onActionTap: _handleActionTap,
                                  ),
                                );
                              }
                            }
                            if (_homeMessages.isEmpty) {
                              widgets.add(const SizedBox(height: 8));
                              widgets.add(
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: suggestions
                                        .map(
                                          (text) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: _ChatSuggestionChip(
                                              label: text,
                                              onTap: () =>
                                                  _sendHomeQuickPrompt(text),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              );
                            }
                            return ListView(
                              controller: _homeScrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.only(bottom: 12),
                              children: widgets,
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _homeInputController,
                                  style: GoogleFonts.inter(
                                    color: app.textPrimary,
                                    fontSize: 14,
                                  ),
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendHomeMessage(),
                                  onTapOutside: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  decoration: InputDecoration(
                                    hintText: '问任何问题',
                                    hintStyle: GoogleFonts.inter(
                                      color: app.textSecondary,
                                    ),
                                    filled: true,
                                    fillColor: app.card,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    suffixIcon: GestureDetector(
                                      onTap: _pickChatFromGallery,
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 18,
                                        color: app.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: _sendHomeMessage,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: app.primary,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: app.primary.withOpacity(0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                  child: SvgPicture.asset(
                                    'images/send.svg',
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.contain,
                                    colorFilter: ColorFilter.mode(
                                      context.isDarkMode
                                          ? Colors.white
                                          : app.textInverse,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final background = app.background;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: background,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.fromLTRB(18, 6, 18, 6 + bottomInset),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  app.card.withOpacity(0.96),
                  app.backgroundAlt.withOpacity(0.98),
                ],
              ),
              border: Border(top: BorderSide(color: app.border)),
              boxShadow: [
                BoxShadow(
                  color: app.shadow.withOpacity(0.35),
                  blurRadius: 22,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    _goHomeTab();
                  },
                  child: _BottomTabItem(
                    icon: Icons.dashboard,
                    label: '首页',
                    active: _tabIndex == 0,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _tabIndex = 1);
                  },
                  child: _BottomTabItem(
                    icon: Icons.explore,
                    label: '发现',
                    active: _tabIndex == 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _BottomScanItem(onPressed: _showScanOptions),
                ),
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _tabIndex = 2);
                  },
                  child: _BottomTabItem(
                    icon: Icons.insights,
                    label: '记录',
                    active: _tabIndex == 2,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _tabIndex = 3);
                  },
                  child: _BottomTabItem(
                    icon: Icons.person,
                    label: '账户',
                    active: _tabIndex == 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _tabIndex,
            children: [
              _StatusHomeTab(
                onOpenChat: _openChatFull,
                onActionTap: _handleActionTap,
              ),
              const _DiscoverTab(),
              _RecordsTab(
                onReviewTap: _showPendingReviews,
                onActionTap: _handleActionTap,
              ),
              const _ProfileTab(),
            ],
          ),
        ],
      ),
    );
  }

  void _openChatFull() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: context.appColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 6,
                  left: 4,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    color: context.appColors.textPrimary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: _buildHomeTab(context, showHeader: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrls = const [],
    this.isTyping = false,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> imageUrls;
  final bool isTyping;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.onActionTap});

  final _ChatMessage message;
  final ValueChanged<String>? onActionTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final isDark = context.isDarkMode;
    final primary = app.primary;
    final isUser = message.isUser;
    if (!isUser && message.isTyping) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.12),
                border: Border.all(color: primary.withOpacity(0.35)),
              ),
              child: ClipOval(
                child: Lottie.asset(
                  'images/bearded_coach.json',
                  fit: BoxFit.cover,
                  repeat: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF16213e) : app.cardAlt.withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: app.border.withOpacity(0.4)),
              ),
              child: const _TypingDots(),
            ),
          ],
        ),
      );
    }

    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final textColor = isDark ? app.textInverse : app.textPrimary;
    final isLight = !isDark;
    final actions = message.isUser
        ? const <String>[]
        : _extractActionIds(message.text);
    final displayText = actions.isNotEmpty
        ? _stripActionTokens(message.text)
        : message.text;
    final userGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [app.primary, app.primary.withOpacity(0.8)],
    );
    final botGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E7BFF), Color(0xFF0F5BD6)],
    );
    final userLightColor = const Color(0xFFE6F7EE);
    final botLightColor = const Color(0xFFE8F1FF);

    if (isUser) {
      final hasImages = message.imageUrls.isNotEmpty;
      return Align(
        alignment: alignment,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isLight ? userLightColor : null,
            gradient: isDark ? userGradient : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLight
                  ? app.primary.withOpacity(0.25)
                  : app.border.withOpacity(0.6),
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (displayText.isNotEmpty)
                Text(
                  displayText,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (hasImages) ...[
                if (displayText.isNotEmpty) const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: message.imageUrls
                      .map(
                        (url) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 78,
                            height: 78,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withOpacity(0.12),
              border: Border.all(color: primary.withOpacity(0.35)),
            ),
            child: ClipOval(
              child: Lottie.asset(
                'images/bearded_coach.json',
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isLight ? botLightColor : null,
                gradient: isDark ? botGradient : null,
                borderRadius: BorderRadius.circular(18),
                border: isLight
                    ? Border.all(color: app.accentBlue.withOpacity(0.2))
                    : null,
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: app.accentBlue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (displayText.isNotEmpty)
                    Builder(builder: (context) {
                      final md = MarkdownGenerator(
                        linesMargin: const EdgeInsets.only(bottom: 6),
                      );
                      final widgets = md.buildWidgets(
                        displayText,
                        config: MarkdownConfig(
                          configs: [
                            PConfig(
                              textStyle: GoogleFonts.inter(
                                color: textColor,
                                fontSize: 13,
                                height: 1.48,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const ListConfig(
                              marginLeft: 26,
                              marginBottom: 6,
                            ),
                            H1Config(
                              style: GoogleFonts.inter(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            H2Config(
                              style: GoogleFonts.inter(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            H3Config(
                              style: GoogleFonts.inter(
                                color: textColor,
                                fontSize: 14.5,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            BlockquoteConfig(
                              textColor: textColor.withOpacity(0.85),
                              sideColor: app.primary.withOpacity(0.35),
                              padding:
                                  const EdgeInsets.fromLTRB(14, 4, 10, 4),
                              margin: const EdgeInsets.fromLTRB(0, 6, 0, 8),
                            ),
                            CodeConfig(
                              style: GoogleFonts.robotoMono(
                                color: textColor,
                                fontSize: 12,
                                backgroundColor:
                                    app.cardAlt.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (widgets.isEmpty) {
                        return Text(
                          displayText,
                          style: GoogleFonts.inter(
                            color: textColor,
                            fontSize: 13,
                            height: 1.48,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widgets,
                      );
                    }),
                    if (message.imageUrls.isNotEmpty) ...[
                      if (displayText.isNotEmpty) const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: message.imageUrls
                            .map(
                              (url) => ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  url,
                                  width: 78,
                                  height: 78,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: actions.map((action) {
                          return _ChatActionPill(
                            label: _actionLabel(action),
                            icon: _actionIcon(action),
                            onTap: onActionTap == null
                                ? null
                                : () => onActionTap!(action),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final active = (int idx) => (t * 3 - idx).clamp(0, 1).toDouble();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final opacity = max(0.2, 1 - (active(i)));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: app.textSecondary.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ChatActionPill extends StatelessWidget {
  const _ChatActionPill({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final isDark = context.isDarkMode;
    final accent = app.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1E3A2B).withOpacity(0.95),
                      const Color(0xFF0F2017).withOpacity(0.95),
                    ]
                  : [app.cardAlt, app.backgroundAlt],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withOpacity(0.45)),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: app.shadow.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: accent.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.55)),
                  ),
                  child: Icon(icon, size: 12, color: accent),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
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

class _ChatbotHintBubble extends StatelessWidget {
  const _ChatbotHintBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final isDark = context.isDarkMode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF2A3B33).withOpacity(0.72),
                            const Color(0xFF151F19).withOpacity(0.6),
                          ]
                        : [
                            app.cardAlt.withOpacity(0.9),
                            app.backgroundAlt.withOpacity(0.85),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: app.border.withOpacity(0.6)),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: app.shadow.withOpacity(0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : const [],
                ),
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Transform.translate(
          offset: const Offset(-18, 0),
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2B24).withOpacity(0.7)
                    : app.cardAlt.withOpacity(0.9),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: app.border.withOpacity(0.6)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusHomeTab extends StatelessWidget {
  const _StatusHomeTab({
    required this.onOpenChat,
    required this.onActionTap,
  });

  final VoidCallback onOpenChat;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final store = UserProfileStore.instance;
    final mealStore = MealStore.instance;
    final target = store.calorieTarget > 0 ? store.calorieTarget : 2000;
    final consumed = _calculateTodayCalories(mealStore);
    final remaining = (target - consumed).clamp(0, target);

    return Container(
      color: app.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _AvatarThumb(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: UserProfileStore.instance,
                      builder: (_, __) {
                        final name = store.userName.trim().isEmpty
                            ? '大胡子'
                            : store.userName;
                        return Text(
                          name,
                          style: GoogleFonts.inter(
                            color: app.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                  AnimatedBuilder(
                    animation: MealStore.instance,
                    builder: (_, __) {
                      final pending = MealStore.instance.pendingRecords.length;
                      return _AnimatedBellButton(
                        onTap: () => onActionTap('history'),
                        active: pending > 0,
                      );
                    },
                  ),
                  IconButton(
                    onPressed: onOpenChat,
                    icon: const Icon(Icons.chat_bubble_outline),
                    color: app.textPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _formatClientTime(DateTime.now()),
                    style: GoogleFonts.inter(
                      color: app.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onOpenChat,
                    icon: const Icon(Icons.chat_bubble_outline),
                    color: app.textPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatusGrid(
                cards: [
                  _StatusCard(
                    title: '热量',
                    subtitle: '还可以吃',
                    highlight: '$remaining',
                    unit: 'kcal',
                    accent: primary,
                    leading: Icons.local_fire_department,
                    trailing: '目标 $target',
                  ),
                  _StatusCard(
                    title: '体重',
                    subtitle: '最近',
                    highlight: store.weight > 0
                        ? store.weight.toStringAsFixed(1)
                        : '--',
                    unit: 'kg',
                    accent: const Color(0xFFFA4B4B),
                    leading: Icons.monitor_weight_outlined,
                    trailing: '',
                  ),
                  _StatusCard(
                    title: '训练',
                    subtitle: '本周计划',
                    highlight: '${store.weeklyTrainingDays}',
                    unit: '天',
                    accent: const Color(0xFF36C25B),
                    leading: Icons.fitness_center,
                    trailing: '',
                  ),
                  _StatusCard(
                    title: '饮水',
                    subtitle: '今日',
                    highlight: store.waterReminderEnabled ? '进行中' : '未开启',
                    unit: '',
                    accent: const Color(0xFF7B61FF),
                    leading: Icons.water_drop_outlined,
                    trailing: '',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = UserProfileStore.instance;
    final asset = _defaultAvatarAsset(store.gender);
    final local = store.displayAvatarLocalPath;
    if (local != null) {
      return Image.file(File(local), width: 44, height: 44, fit: BoxFit.cover);
    }
    final avatar = store.displayAvatarUrl.trim();
    if (avatar.isNotEmpty) {
      return Image.network(avatar, width: 44, height: 44, fit: BoxFit.cover);
    }
    return Image.asset(asset, width: 44, height: 44, fit: BoxFit.cover);
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: cards,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.highlight,
    required this.unit,
    required this.accent,
    required this.leading,
    this.trailing = '',
  });

  final String title;
  final String subtitle;
  final String highlight;
  final String unit;
  final Color accent;
  final IconData leading;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: app.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: app.shadow.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(leading, color: accent, size: 18),
              ),
              const Spacer(),
              if (trailing.isNotEmpty)
                Text(
                  trailing,
                  style: GoogleFonts.inter(
                    color: app.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: app.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: highlight,
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: unit.isNotEmpty ? ' $unit' : '',
                  style: GoogleFonts.inter(
                    color: app.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: app.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: app.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
