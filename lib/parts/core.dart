part of '../main.dart';

const String _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://118.196.47.83/api/v1',
);
const bool _allowBadCertificates = bool.fromEnvironment(
  'ALLOW_BAD_SSL',
  defaultValue: false,
);
bool _forceOnboardingPreview = false;
bool _previewOnboardingFlow = false;

const String _pandaCameraSvg = '''
<svg version="1.0" xmlns="http://www.w3.org/2000/svg" width="800.000000" height="800.000000" viewBox="0 0 800.000000 800.000000" preserveAspectRatio="xMidYMid meet">
  <metadata>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:dc="http://purl.org/dc/elements/1.1/">
      <rdf:Description dc:format="image/svg+xml" dc:Label="1" dc:ContentProducer="001191330110MACRLGPT8B00000" dc:ProduceID="371413420" dc:ReservedCode1="zN1KEbZ1KI6iNcGUYAnNGNRHcwz2nw8gkcBXWuCLU6Y=" dc:ContentPropagator="001191330110MACRLGPT8B00000" dc:PropagateID="371413420" dc:ReservedCode2="zN1KEbZ1KI6iNcGUYAnNGNRHcwz2nw8gkcBXWuCLU6Y="/>
    </rdf:RDF>
  </metadata>
  <g transform="translate(0.000000,800.000000) scale(0.100000,-0.100000)" fill="#000000" stroke="none">
    <path d="M3810 5620 c-153 -22 -272 -105 -336 -236 -15 -30 -29 -75 -32 -99 -2 -25 -8 -48 -13 -51 -4 -2 -44 -2 -88 2 l-81 7 0 52 c0 125 -57 214 -164 254 -81 30 -215 43 -329 31 -214 -22 -309 -100 -324 -266 -3 -38 -11 -72 -17 -76 -6 -4 -29 -8 -51 -8 -152 0 -309 -99 -384 -240 -59 -110 -59 -109 -72 -1134 -13 -1038 -15 -995 48 -1125 34 -71 128 -163 206 -200 127 -62 38 -59 1752 -66 1621 -7 1656 -7 1775 32 173 55 298 187 329 346 5 29 14 284 20 567 6 283 16 712 23 952 13 490 10 526 -53 637 -96 168 -255 245 -489 239 l-115 -3 -7 57 c-9 72 -47 148 -102 203 -53 53 -172 112 -251 125 -70 12 -1163 11 -1245 0z m1273 -150 c73 -23 138 -74 168 -132 11 -21 24 -76 29 -121 6 -49 16 -87 25 -96 13 -13 52 -17 208 -21 183 -6 194 -7 243 -32 66 -35 144 -121 167 -184 13 -36 17 -81 17 -174 1 -228 -30 -1592 -39 -1737 -8 -126 -12 -147 -34 -185 -57 -94 -141 -150 -267 -177 -73 -16 -295 -27 -303 -15 -3 5 9 36 26 69 23 42 38 60 50 58 15 -1 17 4 13 23 -5 18 4 43 30 90 34 61 38 65 65 59 25 -6 29 -3 29 14 0 11 -7 24 -16 29 -16 9 -16 11 0 33 9 13 16 27 16 31 0 17 -30 7 -54 -18 -23 -25 -25 -26 -47 -10 -29 20 -45 20 -53 1 -4 -11 6 -22 29 -36 l35 -21 -23 -37 c-12 -21 -29 -48 -37 -60 l-16 -23 -44 20 c-25 11 -60 23 -78 27 -21 4 -37 15 -44 31 -6 13 -14 24 -17 24 -16 -1 -41 -29 -36 -42 3 -8 -4 -35 -15 -62 -21 -47 -22 -47 -47 -31 -26 18 -53 14 -53 -8 0 -7 14 -21 31 -31 22 -13 28 -21 20 -29 -16 -16 -13 -47 3 -47 8 0 21 9 29 20 14 20 16 20 51 4 29 -14 39 -15 49 -5 9 10 7 16 -13 31 -14 11 -31 20 -37 20 -17 0 -16 20 2 64 15 35 56 64 63 45 5 -13 87 -49 110 -49 16 0 13 -11 -27 -90 l-46 -90 -1416 0 c-956 0 -1434 3 -1473 11 -85 15 -145 45 -199 97 -61 59 -95 124 -106 204 -8 58 -1 922 14 1609 6 295 14 357 59 426 52 82 121 124 236 142 40 7 277 11 611 11 l546 0 21 23 c15 16 25 45 32 97 18 130 71 202 176 245 44 17 84 20 379 26 182 3 457 5 613 2 243 -3 291 -7 345 -23z m-2061 -40 c21 -6 50 -21 65 -34 23 -20 27 -33 31 -90 l4 -66 -272 0 -272 0 4 62 c4 55 8 64 38 89 19 16 55 33 84 39 28 5 60 12 71 14 34 8 208 -2 247 -14z"/>
    <path d="M5477 4959 c-86 -14 -160 -72 -195 -152 -21 -49 -15 -137 14 -195 46 -92 116 -132 230 -132 137 1 239 95 251 232 15 163 -121 276 -300 247z m127 -153 c14 -8 29 -31 36 -50 32 -98 -92 -184 -180 -124 -50 34 -65 70 -51 120 10 32 20 43 54 59 47 22 103 20 141 -5z"/>
    <path d="M4240 4845 c-240 -51 -470 -196 -618 -388 -56 -72 -130 -214 -159 -306 -36 -111 -43 -317 -15 -453 59 -283 231 -515 497 -667 132 -76 340 -131 493 -131 84 0 228 22 301 47 304 101 555 372 643 695 20 71 23 107 23 253 0 160 -2 175 -29 255 -35 105 -100 231 -159 307 -136 177 -349 317 -565 374 -101 27 -319 34 -412 14z m348 -140 c309 -73 545 -280 648 -570 27 -76 29 -89 29 -250 0 -167 -1 -171 -34 -265 -56 -160 -140 -284 -259 -385 -94 -79 -164 -119 -273 -157 -90 -31 -100 -32 -249 -32 -176 0 -256 16 -389 79 -213 101 -392 302 -457 512 -116 380 34 753 390 967 74 45 199 93 268 105 86 14 257 12 326 -4z"/>
    <path d="M4325 4551 c-148 -24 -264 -83 -379 -191 -95 -90 -146 -171 -183 -288 -24 -77 -25 -92 -20 -215 5 -150 21 -208 88 -320 48 -81 155 -190 232 -236 103 -61 217 -94 344 -99 285 -12 504 115 637 367 97 185 102 422 12 600 -77 152 -251 297 -423 354 -87 28 -226 41 -308 28z m229 -146 c218 -57 399 -251 429 -460 35 -242 -139 -513 -378 -588 -96 -30 -232 -29 -332 2 -175 55 -318 189 -372 348 -27 81 -37 202 -21 278 39 194 223 377 422 420 85 18 182 18 252 0z"/>
    <path d="M4069 4060 c-12 -34 -15 -35 -49 -15 -34 19 -50 18 -50 -3 0 -11 14 -25 36 -35 30 -15 35 -22 30 -40 -4 -12 -9 -34 -12 -49 -4 -18 -13 -28 -25 -28 -27 0 -35 -21 -14 -36 16 -12 17 -18 7 -40 -14 -28 -8 -44 14 -44 8 0 17 13 21 30 3 17 7 30 10 30 2 0 21 -9 42 -19 44 -23 74 -14 50 15 -8 9 -29 23 -47 31 -25 11 -32 18 -27 31 3 9 9 29 12 45 7 35 16 34 66 -8 45 -39 52 -41 60 -21 4 9 -15 32 -49 61 -45 39 -52 49 -44 65 6 10 10 28 10 39 0 32 -30 25 -41 -9z"/>
    <path d="M2470 4841 c-54 -17 -89 -42 -119 -83 -61 -83 -62 -91 -74 -690 -13 -678 -3 -1015 32 -1093 38 -86 87 -126 180 -146 103 -22 218 28 268 116 12 21 26 67 32 100 12 69 13 567 2 1195 -7 391 -8 407 -29 455 -28 61 -64 100 -116 127 -43 22 -136 32 -176 19z m136 -154 c18 -16 29 -38 35 -73 15 -85 24 -1480 10 -1545 -14 -65 -42 -97 -93 -105 -57 -10 -103 18 -125 74 -17 44 -18 96 -17 772 2 783 4 823 51 872 35 37 99 39 139 5z"/>
    <path d="M5697 3038 c-62 -88 -110 -164 -141 -226 -26 -51 -28 -53 -61 -46 -27 5 -35 3 -35 -8 0 -16 177 -101 191 -92 22 13 14 21 -79 80 -8 5 66 132 135 232 39 58 70 109 67 114 -13 20 -36 3 -77 -54z"/>
  </g>
</svg>
''';

class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  }
}

class OssUploadService {
  static const MethodChannel _channel = MethodChannel('eatclean/oss_upload');

  static Future<Map<String, dynamic>?> _fetchSts() async {
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/oss/sts'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = payload['data'];
        if (data is Map) {
          return data.map((key, value) => MapEntry(key.toString(), value));
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<List<String>> uploadImages({
    required List<XFile> images,
    required String category,
  }) async {
    if (!Platform.isIOS) {
      return [];
    }
    if (images.isEmpty) return [];
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) {
      return [];
    }
    final sts = await _fetchSts();
    if (sts == null) return [];
    final accessKeyId = sts['access_key_id']?.toString() ?? '';
    final accessKeySecret = sts['access_key_secret']?.toString() ?? '';
    final securityToken = sts['security_token']?.toString() ?? '';
    final endpointRaw = sts['endpoint']?.toString() ?? '';
    final bucket = sts['bucket']?.toString() ?? '';
    if (accessKeyId.isEmpty ||
        accessKeySecret.isEmpty ||
        securityToken.isEmpty ||
        endpointRaw.isEmpty ||
        bucket.isEmpty) {
      return [];
    }
    final endpoint = endpointRaw.startsWith('http')
        ? endpointRaw
        : 'https://$endpointRaw';
    try {
      final result = await _channel.invokeMethod('uploadImages', {
        'paths': images.map((image) => image.path).toList(),
        'endpoint': endpoint,
        'bucket': bucket,
        'accessKeyId': accessKeyId,
        'accessKeySecret': accessKeySecret,
        'securityToken': securityToken,
        'prefix': category,
        'userId': auth.userId ?? 0,
      });
      if (result is Map && result['urls'] is List) {
        return (result['urls'] as List).map((e) => e.toString()).toList();
      }
      if (result is List) {
        return result.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<String>> signUrls(List<String> urls) async {
    if (urls.isEmpty) return [];
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) return [];
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/oss/sign'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({'urls': urls}),
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = payload['data'];
        if (data is Map && data['signed_urls'] is List) {
          return (data['signed_urls'] as List)
              .map((e) => e.toString())
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _mealReminderId = 1201;
  static const int _trainingReminderId = 1202;
  static const int _waterReminderBaseId = 1300;
  static const int _waterReminderMaxCount = 40;
  static const int _testReminderId = 1999;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await initialize();
  }

  Future<void> syncFromSettings(UserProfileStore store) async {
    await _ensureInitialized();
    if (store.mealReminderEnabled) {
      await scheduleMealReminder(store.mealReminderTime);
    } else {
      await cancelMealReminder();
    }
    if (store.trainingReminderEnabled) {
      await scheduleTrainingReminder(store.trainingReminderTime);
    } else {
      await cancelTrainingReminder();
    }
    if (store.waterReminderEnabled) {
      await scheduleWaterReminders(store.waterReminderInterval);
    } else {
      await cancelWaterReminders();
    }
  }

  Future<void> scheduleMealReminder(String timeLabel) async {
    await _scheduleDailyReminder(
      id: _mealReminderId,
      timeLabel: timeLabel,
      title: '饮食提醒',
      body: '该吃饭啦，记得记录你的饮食',
      channelId: 'meal_reminder',
      channelName: '饮食提醒',
      channelDescription: '按时提醒三餐',
    );
  }

  Future<void> cancelMealReminder() async {
    await _ensureInitialized();
    await _plugin.cancel(_mealReminderId);
  }

  Future<void> scheduleTrainingReminder(String timeLabel) async {
    await _scheduleDailyReminder(
      id: _trainingReminderId,
      timeLabel: timeLabel,
      title: '训练提醒',
      body: '记得完成今天的训练计划',
      channelId: 'training_reminder',
      channelName: '训练提醒',
      channelDescription: '保持训练节奏',
    );
  }

  Future<void> cancelTrainingReminder() async {
    await _ensureInitialized();
    await _plugin.cancel(_trainingReminderId);
  }

  Future<void> scheduleWaterReminders(int intervalMinutes) async {
    await _ensureInitialized();
    await cancelWaterReminders();
    final times = _buildWaterTimes(intervalMinutes);
    for (var i = 0; i < times.length; i++) {
      final time = times[i];
      final schedule = _nextInstanceOfTime(time);
      await _plugin.zonedSchedule(
        _waterReminderBaseId + i,
        '喝水提醒',
        '补充水分，让身体保持活力',
        schedule,
        _buildNotificationDetails(
          channelId: 'water_reminder',
          channelName: '喝水提醒',
          channelDescription: '水分摄入提醒',
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelWaterReminders() async {
    await _ensureInitialized();
    for (var i = 0; i < _waterReminderMaxCount; i++) {
      await _plugin.cancel(_waterReminderBaseId + i);
    }
  }

  Future<void> _scheduleDailyReminder({
    required int id,
    required String timeLabel,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    await _ensureInitialized();
    final time = _parseTimeLabel(timeLabel);
    final schedule = _nextInstanceOfTime(time);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      schedule,
      _buildNotificationDetails(
        channelId: channelId,
        channelName: channelName,
        channelDescription: channelDescription,
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showTestNotification() async {
    await _ensureInitialized();
    await _plugin.show(
      _testReminderId,
      '测试通知',
      '这是一条本地通知测试',
      _buildNotificationDetails(
        channelId: 'test_reminder',
        channelName: '测试通知',
        channelDescription: '本地通知测试',
      ),
    );
  }

  NotificationDetails _buildNotificationDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );
  }

  TimeOfDay _parseTimeLabel(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(
        hour: hour.clamp(0, 23).toInt(),
        minute: minute.clamp(0, 59).toInt(),
      );
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  List<TimeOfDay> _buildWaterTimes(int intervalMinutes) {
    final start = 8 * 60;
    final end = 22 * 60;
    final step = intervalMinutes.clamp(30, 180).toInt();
    final times = <TimeOfDay>[];
    for (var minutes = start; minutes <= end; minutes += step) {
      final hour = minutes ~/ 60;
      final minute = minutes % 60;
      times.add(TimeOfDay(hour: hour, minute: minute));
    }
    return times;
  }
}

const List<String> _subscriptionProductIds = [
  'com.midoriya.eat.month',
  'com.midoriya.eat.year',
];
const String _subscriptionTermsUrl = '';
const String _privacyPolicyUrl = '';

class SubscriptionService {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _initialized = false;
  bool _available = false;
  String? _lastError;
  List<ProductDetails> _products = [];
  Timer? _purchaseTimeout;
  final Set<String> _verifiedTxnIds = {};
  final ValueNotifier<SubscriptionFlowState> flowState = ValueNotifier(
    SubscriptionFlowState.idle,
  );

  bool get isAvailable => _available;
  String? get lastError => _lastError;
  List<ProductDetails> get products =>
      List<ProductDetails>.unmodifiable(_products);

  Future<void> _ensureAvailable() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      _lastError = '无法连接 App Store';
      flowState.value = SubscriptionFlowState.error;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    flowState.value = SubscriptionFlowState.loadingProducts;
    await _ensureAvailable();
    if (_available) {
      final response = await _iap.queryProductDetails(
        _subscriptionProductIds.toSet(),
      );
      _products = response.productDetails;
      if (response.error != null) {
        _lastError = response.error!.message;
        flowState.value = SubscriptionFlowState.error;
      } else if (response.productDetails.isEmpty) {
        _lastError = '订阅产品未配置';
        flowState.value = SubscriptionFlowState.error;
      } else {
        flowState.value = SubscriptionFlowState.idle;
      }
    } else {
      _lastError = '无法连接 App Store';
      flowState.value = SubscriptionFlowState.error;
    }
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        _lastError = error.toString();
      },
    );
    _initialized = true;
  }

  Future<void> refreshProducts() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    await _ensureAvailable();
    if (!_available) return;
    flowState.value = SubscriptionFlowState.loadingProducts;
    final response = await _iap.queryProductDetails(
      _subscriptionProductIds.toSet(),
    );
    _products = response.productDetails;
    if (response.error != null) {
      _lastError = response.error!.message;
      flowState.value = SubscriptionFlowState.error;
    } else if (response.productDetails.isEmpty) {
      _lastError = '订阅产品未配置';
      flowState.value = SubscriptionFlowState.error;
    } else {
      flowState.value = SubscriptionFlowState.idle;
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (!_initialized) {
      await initialize();
    }
    await _ensureAvailable();
    if (!_available) return;
    if (_products.isEmpty) {
      await refreshProducts();
    }
    flowState.value = SubscriptionFlowState.purchasing;
    _lastError = null;
    _purchaseTimeout?.cancel();
    // 总超时
    _purchaseTimeout = Timer(const Duration(seconds: 25), () {
      if (flowState.value == SubscriptionFlowState.purchasing ||
          flowState.value == SubscriptionFlowState.verifying) {
        _lastError = '支付已取消或中断，请重试';
        flowState.value = SubscriptionFlowState.error;
      }
    });
    // 短超时：若 6s 内没有进入验证或回调，认为拉起失败
    Timer(const Duration(seconds: 6), () {
      if (flowState.value == SubscriptionFlowState.purchasing) {
        _lastError ??= '未能拉起支付，请检查 App Store 或稍后重试';
        flowState.value = SubscriptionFlowState.error;
      }
    });
    final param = PurchaseParam(productDetails: product);
    try {
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (error) {
      _lastError = error.toString();
      flowState.value = SubscriptionFlowState.error;
    }
  }

  Future<void> restore() async {
    if (!_initialized) {
      await initialize();
    }
    await _ensureAvailable();
    if (!_available) return;
    flowState.value = SubscriptionFlowState.restoring;
    _lastError = null;
    _purchaseTimeout?.cancel();
    _purchaseTimeout = Timer(const Duration(seconds: 20), () {
      if (flowState.value == SubscriptionFlowState.restoring) {
        _lastError = '恢复购买未完成，请稍后再试';
        flowState.value = SubscriptionFlowState.error;
      }
    });
    try {
      await _iap.restorePurchases();
    } catch (error) {
      _lastError = error.toString();
      flowState.value = SubscriptionFlowState.error;
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status != PurchaseStatus.pending) {
        _purchaseTimeout?.cancel();
      }
      // 已经验过的交易直接跳过，避免反复触发验证与阻塞 UI
      if (purchase.purchaseID != null &&
          _verifiedTxnIds.contains(purchase.purchaseID!)) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        _lastError = purchase.error?.message ?? '订阅失败，请稍后再试';
        flowState.value = SubscriptionFlowState.error;
      } else if (purchase.status.toString().contains('cancel')) {
        _lastError = '已取消支付';
        flowState.value = SubscriptionFlowState.error;
      } else if (purchase.status == PurchaseStatus.pending) {
        flowState.value = SubscriptionFlowState.purchasing;
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        flowState.value = SubscriptionFlowState.verifying;
        final verified = await _verifyPurchase(purchase);
        if (purchase.purchaseID != null) {
          _verifiedTxnIds.add(purchase.purchaseID!);
        }
        if (verified) {
          await UserProfileStore.instance.ensureLoaded();
          await UserProfileStore.instance.setSubscriberStatus(true);
          unawaited(UserProfileStore.instance.refreshDailyUsageFromServer());
          if (purchase.purchaseID != null) {
            _verifiedTxnIds.add(purchase.purchaseID!);
          }
          flowState.value = SubscriptionFlowState.success;
          Future.delayed(const Duration(seconds: 2), () {
            if (flowState.value == SubscriptionFlowState.success) {
              flowState.value = SubscriptionFlowState.idle;
            }
          });
        } else {
          flowState.value = SubscriptionFlowState.error;
        }
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    final auth = AuthStore.instance;
    await auth.ensureLoaded();
    if (auth.token.isEmpty) {
      _lastError = '未登录无法验证订阅';
      return false;
    }
    final receipt = purchase.verificationData.serverVerificationData;
    if (receipt.isEmpty) {
      _lastError = '订阅凭证缺失';
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/subscription/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({
          'platform': 'ios',
          'product_id': purchase.productID,
          'transaction_id': purchase.purchaseID ?? '',
          'verification_data': receipt,
          'verification_source': purchase.verificationData.source,
          'transaction_date': purchase.transactionDate ?? '',
        }),
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && payload['code'] == 0) {
        final data = payload['data'];
        if (data is Map) {
          final status = data['status']?.toString() ?? '';
          final active = data['active'] == true || status == 'active';
          final sku = data['product_id']?.toString() ?? '';
          if (sku.isNotEmpty) {
            unawaited(UserProfileStore.instance.setSubscriptionSku(sku));
          }
          return active;
        }
        return true;
      }
      if (response.statusCode == 200 && payload['code'] != 0) {
        _lastError = payload['msg']?.toString() ?? '订阅验证失败，请稍后再试';
      } else {
        _lastError = '订阅验证失败，请稍后再试';
      }
    } catch (e) {
      _lastError = '订阅验证失败，请稍后再试';
    }
    return false;
  }
}

enum SubscriptionFlowState {
  idle,
  loadingProducts,
  purchasing,
  restoring,
  verifying,
  success,
  error,
}

Future<void> showSubscriptionSheet(
  BuildContext context, {
  String? reason,
  bool forceShow = false,
}) async {
  await SubscriptionService.instance.initialize();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SubscriptionSheet(reason: reason),
  );
}

class _SubscriptionSheet extends StatefulWidget {
  const _SubscriptionSheet({this.reason});

  final String? reason;

  @override
  State<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<_SubscriptionSheet> {
  ProductDetails? _selected;
  bool _loading = true;
  String? _error;
  List<ProductDetails> _products = [];
  SubscriptionFlowState _flowState = SubscriptionFlowState.idle;
  late final VoidCallback _flowListener;
  bool _closedOnSuccess = false;

  @override
  void initState() {
    super.initState();
    _flowState = SubscriptionService.instance.flowState.value;
    _flowListener = () {
      if (!mounted) return;
      final state = SubscriptionService.instance.flowState.value;
      setState(() => _flowState = state);
      if (state == SubscriptionFlowState.success && !_closedOnSuccess) {
        _closedOnSuccess = true;
        unawaited(_showSuccessCard());
        return;
      }
      if (state == SubscriptionFlowState.error &&
          SubscriptionService.instance.lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SubscriptionService.instance.lastError!)),
        );
      }
    };
    SubscriptionService.instance.flowState.addListener(_flowListener);
    unawaited(_loadProducts());
  }

  Future<void> _showSuccessCard() async {
    if (!mounted) return;
    final app = context.appColors;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '订阅成功',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        final width = MediaQuery.of(context).size.width * 0.8;
        return Center(
          child: Container(
            width: width.clamp(260, 360),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: app.card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: app.shadow.withOpacity(0.26),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'images/dingyue.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '订阅已生效',
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '已解锁无限扫描、提问与记录，祝你元气满满！',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: app.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: app.primary,
                      foregroundColor: app.textInverse,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('好的'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    SubscriptionService.instance.flowState.removeListener(_flowListener);
    super.dispose();
  }

  Future<void> _loadProducts() async {
    await SubscriptionService.instance.refreshProducts();
    if (!mounted) return;
    setState(() {
      _products = SubscriptionService.instance.products;
      _error = SubscriptionService.instance.lastError;
      _loading = false;
      if (_products.isNotEmpty) {
        _selected = _products.first;
      }
    });
  }

  Future<void> _startPurchase() async {
    final product = _selected;
    if (product == null) return;
    await SubscriptionService.instance.buy(product);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已发起订阅，请按提示完成支付')));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final busy =
        _flowState == SubscriptionFlowState.purchasing ||
        _flowState == SubscriptionFlowState.verifying ||
        _flowState == SubscriptionFlowState.restoring;
    return Container(
      decoration: BoxDecoration(
        color: app.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: AnimatedBuilder(
            animation: UserProfileStore.instance,
            builder: (context, child) {
              final isSubscriber = UserProfileStore.instance.isSubscriber;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: app.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '解锁 元气食光·Plus',
                              style: GoogleFonts.inter(
                                color: app.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.reason ?? '已用完今日免费次数',
                              style: GoogleFonts.inter(
                                color: app.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: app.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isSubscriber ? '已订阅' : '订阅解锁',
                          style: GoogleFonts.inter(
                            color: app.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FeatureRow(
                    icon: Icons.qr_code_scanner,
                    title: '菜单扫描不限次',
                    subtitle: '多图合并识别更准确',
                  ),
                  const SizedBox(height: 10),
                  _FeatureRow(
                    icon: Icons.restaurant_menu,
                    title: '记录餐食不限次',
                    subtitle: '持续追踪饮食进度',
                  ),
                  const SizedBox(height: 10),
                  _FeatureRow(
                    icon: Icons.chat_bubble_outline,
                    title: '每日提问无限',
                    subtitle: '大胡子实时答疑',
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(color: app.primary),
                    )
                  else ...[
                    if (busy ||
                        _flowState == SubscriptionFlowState.success) ...[
                      _SubscriptionProcessingBanner(
                        state: _flowState,
                        message: _flowState == SubscriptionFlowState.success
                            ? '订阅已生效，正在同步权益...'
                            : _flowState == SubscriptionFlowState.verifying
                            ? '正在验证订阅...'
                            : _flowState == SubscriptionFlowState.restoring
                            ? '正在恢复购买...'
                            : '正在发起订阅...',
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_products.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: app.cardAlt,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: app.border),
                        ),
                        child: Text(
                          _error ?? '订阅产品未配置，请在 App Store Connect 中创建订阅项。',
                          style: GoogleFonts.inter(
                            color: app.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else ...[
                      Column(
                        children: _products
                            .map(
                              (product) => _PlanTile(
                                product: product,
                                selected: _selected?.id == product.id,
                                onTap: () =>
                                    setState(() => _selected = product),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: busy ? null : _startPurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: app.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: Text(isSubscriber ? '重新订阅' : '立即订阅'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: busy
                            ? null
                            : SubscriptionService.instance.restore,
                        child: Text(
                          '恢复购买',
                          style: GoogleFonts.inter(
                            color: app.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (SubscriptionService.instance.lastError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          SubscriptionService.instance.lastError!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEF4444),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '开通即代表同意《订阅协议》和《隐私政策》',
                    style: GoogleFonts.inter(
                      color: app.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      _LinkText(label: '订阅协议', url: _subscriptionTermsUrl),
                      Text('·', style: TextStyle(color: app.textSecondary)),
                      _LinkText(label: '隐私政策', url: _privacyPolicyUrl),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final ProductDetails product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? app.primarySoft : app.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? app.primary : app.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? app.primary : app.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: app.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: GoogleFonts.inter(
                      color: app.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    style: GoogleFonts.inter(
                      color: app.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              product.price,
              style: GoogleFonts.inter(
                color: app.primary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionProcessingBanner extends StatefulWidget {
  const _SubscriptionProcessingBanner({
    required this.state,
    required this.message,
  });

  final SubscriptionFlowState state;
  final String message;

  @override
  State<_SubscriptionProcessingBanner> createState() =>
      _SubscriptionProcessingBannerState();
}

class _SubscriptionProcessingBannerState
    extends State<_SubscriptionProcessingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _dotAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _dotAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final showSuccess = widget.state == SubscriptionFlowState.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: app.cardAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: app.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSuccess)
            Icon(Icons.check_circle, color: app.primary, size: 18)
          else
            const SizedBox(width: 18),
          AnimatedBuilder(
            animation: _dotAnimation,
            builder: (context, child) {
              final value = _dotAnimation.value;
              final dots = (value * 3).floor() + 1;
              return Text(
                '●' * dots,
                style: GoogleFonts.inter(
                  color: app.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.message,
              style: GoogleFonts.inter(
                color: app.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: app.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: app.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: app.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: app.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.url});

  final String label;
  final String url;

  Future<void> _open(BuildContext context) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接尚未配置')));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接格式不正确')));
      return;
    }
    final success = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return GestureDetector(
      onTap: () => _open(context),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: app.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EatCleanApp extends StatelessWidget {
  const EatCleanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeStore.instance,
      builder: (context, child) {
        return MaterialApp(
          title: '元气食光',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeStore.instance.mode,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routes: {
            '/welcome': (_) => const WelcomeScreen(),
            '/selection': (_) => const GoalSelectionScreen(),
            '/preferences': (_) => const DietaryPreferencesScreen(),
            '/body_metrics': (_) => const BodyMetricsScreen(),
            '/allergies': (_) => const AllergiesScreen(),
            '/setup_preferences': (_) => const SetupPreferencesScreen(),
            '/scan': (_) => const ScanMenuScreen(),
            '/food_scan': (_) => const FoodRecordScreen(),
            '/dashboard': (_) => const DashboardScreen(),
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primarySoft,
    required this.accentBlue,
    required this.accentOrange,
    required this.background,
    required this.backgroundAlt,
    required this.card,
    required this.cardAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textInverse,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadow,
    required this.backgroundGradient,
    required this.heroGradient,
  });

  final Color primary;
  final Color primarySoft;
  final Color accentBlue;
  final Color accentOrange;
  final Color background;
  final Color backgroundAlt;
  final Color card;
  final Color cardAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textInverse;
  final Color success;
  final Color warning;
  final Color danger;
  final Color shadow;
  final LinearGradient backgroundGradient;
  final LinearGradient heroGradient;

  @override
  AppColors copyWith({
    Color? primary,
    Color? primarySoft,
    Color? accentBlue,
    Color? accentOrange,
    Color? background,
    Color? backgroundAlt,
    Color? card,
    Color? cardAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textInverse,
    Color? success,
    Color? warning,
    Color? danger,
    Color? shadow,
    LinearGradient? backgroundGradient,
    LinearGradient? heroGradient,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      accentBlue: accentBlue ?? this.accentBlue,
      accentOrange: accentOrange ?? this.accentOrange,
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      card: card ?? this.card,
      cardAlt: cardAlt ?? this.cardAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textInverse: textInverse ?? this.textInverse,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t) ?? primarySoft,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t) ?? accentBlue,
      accentOrange:
          Color.lerp(accentOrange, other.accentOrange, t) ?? accentOrange,
      background: Color.lerp(background, other.background, t) ?? background,
      backgroundAlt:
          Color.lerp(backgroundAlt, other.backgroundAlt, t) ?? backgroundAlt,
      card: Color.lerp(card, other.card, t) ?? card,
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t) ?? cardAlt,
      border: Color.lerp(border, other.border, t) ?? border,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary:
          Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      textInverse: Color.lerp(textInverse, other.textInverse, t) ?? textInverse,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
      backgroundGradient:
          LinearGradient.lerp(
            backgroundGradient,
            other.backgroundGradient,
            t,
          ) ??
          backgroundGradient,
      heroGradient:
          LinearGradient.lerp(heroGradient, other.heroGradient, t) ??
          heroGradient,
    );
  }
}

class AppTheme {
  static const AppColors lightColors = AppColors(
    primary: Color(0xFF22C55E),
    primarySoft: Color(0xFFDFF7E7),
    accentBlue: Color(0xFF3B82F6),
    accentOrange: Color(0xFFFF8A00),
    background: Color(0xFFF5F7FB),
    backgroundAlt: Color(0xFFF0F5FF),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF7F9FC),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF94A3B8),
    textInverse: Color(0xFFFFFFFF),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    shadow: Color(0xFF0F172A),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFF3F8FF), Color(0xFFF6FFF7)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE8F2FF), Color(0xFFF4FBFF)],
    ),
  );

  static const AppColors darkColors = AppColors(
    primary: Color(0xFF13EC5B),
    primarySoft: Color(0xFF123A26),
    accentBlue: Color(0xFF60A5FA),
    accentOrange: Color(0xFFF59E0B),
    background: Color(0xFF102216),
    backgroundAlt: Color(0xFF0F1A14),
    card: Color(0xFF1C271F),
    cardAlt: Color(0xFF162018),
    border: Color(0xFF223126),
    textPrimary: Color(0xFFE6F4EA),
    textSecondary: Color(0xFFA7B4AC),
    textTertiary: Color(0xFF7D8B84),
    textInverse: Color(0xFF0E1511),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    shadow: Color(0xFF0B120E),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF111813), Color(0xFF0D140E), Color(0xFF080C09)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1C3527), Color(0xFF131F18)],
    ),
  );

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lightColors.primary,
        brightness: Brightness.light,
        primary: lightColors.primary,
        secondary: lightColors.accentBlue,
      ),
      cardColor: lightColors.card,
      dividerColor: lightColors.border,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: lightColors.background,
        foregroundColor: lightColors.textPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? lightColors.primary
              : lightColors.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? lightColors.primary.withOpacity(0.4)
              : lightColors.border,
        ),
      ),
      extensions: const [lightColors],
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkColors.primary,
        brightness: Brightness.dark,
        primary: darkColors.primary,
        secondary: darkColors.accentBlue,
      ),
      cardColor: darkColors.card,
      dividerColor: darkColors.border,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: darkColors.background,
        foregroundColor: darkColors.textPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? darkColors.primary
              : darkColors.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? darkColors.primary.withOpacity(0.4)
              : darkColors.border,
        ),
      ),
      extensions: const [darkColors],
    );
  }
}

extension AppThemeX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppTheme.darkColors;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

String _colorToHex(Color color) =>
    color.value.toRadixString(16).padLeft(8, '0');

Color _colorFromHex(String value) => Color(int.parse(value, radix: 16));

String _formatClientTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  final offset = value.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final offsetHours = offset.inHours.abs().toString().padLeft(2, '0');
  final offsetMinutes = (offset.inMinutes.abs() % 60).toString().padLeft(
    2,
    '0',
  );
  return '$year-$month-$day'
      'T$hour:$minute:$second'
      '$sign$offsetHours:$offsetMinutes';
}

String _formatMealDateTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year/$month/$day $hour:$minute';
}

String _formatShortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month月$day';
}

String _formatTimeOfDay(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

TimeOfDay _parseTimeOfDay(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    return const TimeOfDay(hour: 8, minute: 0);
  }
  final hour = int.tryParse(parts[0]) ?? 8;
  final minute = int.tryParse(parts[1]) ?? 0;
  return TimeOfDay(
    hour: hour.clamp(0, 23).toInt(),
    minute: minute.clamp(0, 59).toInt(),
  );
}

Future<bool> _hasCompletedSetup() async {
  if (_forceOnboardingPreview) {
    return false;
  }
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('onboarding_completed') == true) {
    return true;
  }
  final raw = prefs.getString('settings_page');
  if (raw == null || raw.trim().isEmpty) {
    return false;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final data = decoded.map((key, value) => MapEntry(key.toString(), value));
      final height = _readIntDynamic(data['height']);
      final weight = _readIntDynamic(data['weight']);
      final age = _readIntDynamic(data['age']);
      final done = height > 0 && weight > 0 && age > 0;
      if (done) {
        await prefs.setBool('onboarding_completed', true);
      }
      return done;
    }
  } catch (_) {}
  return false;
}

Future<void> _markSetupCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_completed', true);
  if (!_previewOnboardingFlow) {
    _forceOnboardingPreview = false;
  }
}

int _readIntDynamic(Object? raw) {
  if (raw is int) return raw;
  if (raw is double) return raw.round();
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

final RegExp _actionTokenRegExp = RegExp(r'action=([a-zA-Z_]+)');

List<String> _extractActionIds(String text) {
  final matches = _actionTokenRegExp.allMatches(text);
  if (matches.isEmpty) return [];
  final actions = <String>{};
  for (final match in matches) {
    final id = match.group(1);
    if (id != null && id.trim().isNotEmpty) {
      actions.add(id.trim().toLowerCase());
    }
  }
  return actions.toList();
}

String _stripActionTokens(String text) {
  var result = text.replaceAll(_actionTokenRegExp, '');
  result = result.replaceAll(RegExp(r'\s{2,}'), ' ');
  return result.trim();
}

String _actionLabel(String action) {
  switch (action) {
    case 'discover':
      return '去发现';
    case 'history':
      return '查看记录';
    case 'setting':
      return '打开设置';
    case 'xiangji':
      return '扫描菜单';
    case 'record_meal':
      return '记录用餐';
    case 'ai_replace':
      return '大胡子替换';
    default:
      return '打开功能';
  }
}

IconData _actionIcon(String action) {
  switch (action) {
    case 'discover':
      return Icons.explore;
    case 'history':
      return Icons.history;
    case 'setting':
      return Icons.settings;
    case 'xiangji':
      return Icons.camera_alt;
    case 'record_meal':
      return Icons.restaurant;
    case 'ai_replace':
      return Icons.auto_fix_high;
    default:
      return Icons.flash_on;
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _calculateTodayCalories(MealStore store) {
  final now = DateTime.now();
  final dateKey =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final intake = store.dailyIntake[dateKey];
  if (intake != null) {
    return intake.calories;
  }
  var total = 0;
  for (final record in store.records) {
    if (!_isSameDay(record.createdAt, now)) continue;
    for (final dish in record.dishes) {
      total += dish.kcal;
    }
  }
  return total;
}

String _buildHomeChatIntro(UserProfileStore store) {
  final age = store.age > 0 ? store.age : 30;
  final height = store.height > 0 ? store.height : 175;
  final weight = store.weight > 0 ? store.weight : 68;
  final name = store.userName.trim();
  final prefix = name.isEmpty ? '，' : '$name，';
  return '嗨${prefix}我是你的智能营养师助手大胡子。看到你今年${age}岁，身高${height} cm，体重${weight} kg。我可以回答任何与饮食、训练相关的问题。想先聊什么？';
}

List<String> _buildHomeChatSuggestions(UserProfileStore store) {
  final goal = store.goalType.isNotEmpty ? store.goalType : '增肌';
  return ['结合我的年龄和活动水平，我该怎么训练？', '根据我的身高体重，蛋白质目标怎么定？', '给我一份适合$goal的三餐建议'];
}

const List<String> _weekDayLabels = ['一', '二', '三', '四', '五', '六', '日'];
const List<String> _genderOptions = ['男', '女'];
const List<String> _activityLevelOptions = ['久坐', '轻活动', '中等活动', '高强度活动'];
const List<String> _trainingExperienceOptions = ['新手', '中级', '高级'];
const List<String> _goalTypeOptions = ['减脂', '增肌', '维持', '减重', '增重'];
const List<String> _weightPlanModeOptions = ['loss', 'gain'];
const Map<String, String> _weightPlanModeLabels = {'loss': '减重', 'gain': '增重'};
const List<String> _preferredTrainingTimeOptions = ['早上', '中午', '晚上'];
const List<String> _trainingTypeOptions = ['力量训练', '有氧', 'HIIT', '体重训练'];
const List<String> _dietPreferenceOptions = ['高蛋白', '低碳', '低脂', '素食', '偏辣'];
const List<String> _excludedFoodOptions = [
  '坚果',
  '海鲜',
  '奶制品',
  '麸质',
  '花生',
  '鸡蛋',
  '大豆',
];
const List<String> _lateEatingHabitOptions = ['从不', '偶尔', '经常'];
const List<String> _aiSuggestionStyleOptions = ['严谨', '灵活', '亲近', '不近人情'];

const double _bmiDisplayMin = 16;
const double _bmiDisplayMax = 40;

class _BmiRange {
  const _BmiRange({
    required this.min,
    required this.max,
    required this.label,
    required this.color,
  });

  final double min;
  final double max;
  final String label;
  final Color color;
}

const List<_BmiRange> _bmiRanges = [
  _BmiRange(
    min: _bmiDisplayMin,
    max: 18.5,
    label: '体重过轻',
    color: Color(0xFF60A5FA),
  ),
  _BmiRange(min: 18.5, max: 25.0, label: '正常', color: Color(0xFF34D399)),
  _BmiRange(min: 25.0, max: 30.0, label: '超重', color: Color(0xFFFBBF24)),
  _BmiRange(min: 30.0, max: 35.0, label: '肥胖', color: Color(0xFFF97316)),
  _BmiRange(
    min: 35.0,
    max: _bmiDisplayMax,
    label: '极度肥胖',
    color: Color(0xFFEF4444),
  ),
];

String _bmiLabelFor(double bmi) {
  for (final range in _bmiRanges) {
    if (bmi < range.max) {
      return range.label;
    }
  }
  return _bmiRanges.last.label;
}

Color _bmiColorFor(double bmi) {
  for (final range in _bmiRanges) {
    if (bmi < range.max) {
      return range.color;
    }
  }
  return _bmiRanges.last.color;
}

String _defaultAvatarAsset(String gender) {
  final value = gender.trim().toLowerCase();
  if (value.contains('女') ||
      value.contains('female') ||
      value.contains('woman')) {
    return 'images/riceball_girl.png';
  }
  return 'images/riceball_boy.png';
}

List<String> _readStringListFromJson(Object? raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString())
        .where((v) => v.isNotEmpty)
        .toList();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return raw
        .split(RegExp(r'[,，、/|]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

String _extractSummary(Map<String, dynamic> json) {
  final direct = json['summary'] ?? json['ai_summary'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct.trim();
  }
  final meta = json['meta'];
  if (meta is Map) {
    final metaSummary = meta['ai_summary'] ?? meta['summary'];
    if (metaSummary is String && metaSummary.trim().isNotEmpty) {
      return metaSummary.trim();
    }
  }
  if (meta is String && meta.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(meta);
      if (decoded is Map) {
        final metaSummary = decoded['ai_summary'] ?? decoded['summary'];
        if (metaSummary is String && metaSummary.trim().isNotEmpty) {
          return metaSummary.trim();
        }
      }
    } catch (_) {}
  }
  return '';
}
