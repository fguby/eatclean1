part of '../main.dart';

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({required this.startInRegister});

  final bool startInRegister;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  late bool _isRegister;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isRegister = widget.startInRegister;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _completeAuth(String status) async {
    await AuthStore.instance.setStatus(status);
    if (!mounted) return;
    Navigator.of(context).pop('dashboard');
  }

  void _showAuthMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1F2B23),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _pickUserName(Map user, {String? fallback}) {
    const keys = [
      'name',
      'nickname',
      'user_name',
      'username',
      'account',
      'email',
    ];
    for (final key in keys) {
      final value = user[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return '';
  }

  Future<void> _applyUserNameIfNeeded(
    UserProfileStore store,
    Map user, {
    String? fallback,
  }) async {
    final picked = _pickUserName(user, fallback: fallback);
    if (picked.isEmpty || picked == store.userName.trim()) return;
    await store.setUserName(picked);
  }

  Future<bool> _promptSettingsChoice(Map<String, dynamic> remote) async {
    if (!mounted) return false;
    final app = context.appColors;
    final primary = app.primary;
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              decoration: BoxDecoration(
                color: app.card,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: app.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: app.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '同步设置',
                    style: GoogleFonts.inter(
                      color: app.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '检测到云端有已保存的设置，选择要使用的版本：',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: app.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SettingsChoiceButton(
                    color: primary,
                    label: '使用云端设置',
                    subtitle: '直接加载云端配置',
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                  const SizedBox(height: 10),
                  _SettingsChoiceButton(
                    color: app.cardAlt,
                    textColor: app.textPrimary,
                    label: '保留本地设置',
                    subtitle: '继续使用当前设备配置',
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                  SizedBox(height: MediaQuery.of(ctx).padding.bottom + 6),
                ],
              ),
            );
          },
        ) ??
        false;
  }

  Future<void> _signInWithApple() async {
    if (_isSubmitting) return;
    if (!Platform.isIOS) {
      _showAuthMessage('当前设备不支持 Apple 登录');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        _showAuthMessage('Apple 登录暂不可用');
        return;
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      final userId = credential.userIdentifier;
      if (identityToken == null || identityToken.isEmpty) {
        _showAuthMessage('无法获取 Apple 登录凭证');
        return;
      }

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'platform': 'ios',
          'apple_identity_token': identityToken,
          if (userId != null) 'apple_user_id': userId,
        }),
      );

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || payload['code'] != 0) {
        final message = payload['message']?.toString() ?? '登录失败';
        _showAuthMessage(message);
        return;
      }

      final data = (payload['data'] as Map?) ?? {};
      final token = data['token']?.toString() ?? '';
      final user = (data['user'] as Map?) ?? {};
      final idValue = user['id'];
      final userIdValue = idValue is num ? idValue.toInt() : null;
      final profileStore = UserProfileStore.instance;
      await profileStore.ensureLoaded();
      final avatar = user['avatar_url']?.toString() ?? '';
      if (avatar.isNotEmpty) {
        await profileStore.setAvatarUrl(avatar);
      }
      final appleName = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((name) => name.trim().isNotEmpty).join('');
      final appleFallback = appleName.isNotEmpty
          ? appleName
          : credential.email?.toString();
      final settings = data['settings'];
      Map<String, dynamic>? remoteSettings;
      if (settings is Map) {
        remoteSettings = settings.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      } else if (settings is String && settings.isNotEmpty) {
        final decoded = jsonDecode(settings);
        if (decoded is Map) {
          remoteSettings = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      }
      if (remoteSettings != null && remoteSettings.isNotEmpty) {
        final useCloud = await _promptSettingsChoice(remoteSettings);
        if (useCloud) {
          await profileStore.applyRemoteSettings(remoteSettings);
        } else {
          await profileStore.markPendingSyncIfDirty();
        }
      }
      profileStore.updateSubscriptionFromUser(
        user.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (data['is_subscriber'] == true || profileStore.isSubscriber) {
        await profileStore.setSubscriberStatus(true);
      }
      await _applyUserNameIfNeeded(profileStore, user, fallback: appleFallback);
      await AuthStore.instance.setSession(
        status: 'logged_in',
        token: token,
        userId: userIdValue,
      );
      unawaited(profileStore.triggerSyncAfterLogin());
      unawaited(MealStore.instance.refreshFromServer());
      if (!mounted) return;
      Navigator.of(context).pop('dashboard');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      _showAuthMessage('Apple 登录失败，请稍后再试');
    } catch (_) {
      _showAuthMessage('Apple 登录失败，请检查网络');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitCredentials() async {
    if (_isSubmitting) return;
    final account = _accountController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (account.isEmpty) {
      _showAuthMessage('请输入账号');
      return;
    }
    if (password.isEmpty) {
      _showAuthMessage('请输入密码');
      return;
    }
    if (_isRegister && password != confirm) {
      _showAuthMessage('两次输入的密码不一致');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final endpoint = _isRegister ? 'register' : 'login';
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/$endpoint'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'platform': 'account',
          'account': account,
          'password': password,
        }),
      );

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || payload['code'] != 0) {
        final message = payload['message']?.toString() ?? '登录失败';
        _showAuthMessage(message);
        return;
      }

      final data = (payload['data'] as Map?) ?? {};
      final token = data['token']?.toString() ?? '';
      final user = (data['user'] as Map?) ?? {};
      final idValue = user['id'];
      final userIdValue = idValue is num ? idValue.toInt() : null;
      final profileStore = UserProfileStore.instance;
      await profileStore.ensureLoaded();
      final avatar = user['avatar_url']?.toString() ?? '';
      if (avatar.isNotEmpty) {
        await profileStore.setAvatarUrl(avatar);
      }
      final settings = data['settings'];
      Map<String, dynamic>? remoteSettings;
      if (settings is Map) {
        remoteSettings = settings.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      } else if (settings is String && settings.isNotEmpty) {
        final decoded = jsonDecode(settings);
        if (decoded is Map) {
          remoteSettings = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      }
      if (remoteSettings != null && remoteSettings.isNotEmpty) {
        final useCloud = await _promptSettingsChoice(remoteSettings);
        if (useCloud) {
          await profileStore.applyRemoteSettings(remoteSettings);
        } else {
          await profileStore.markPendingSyncIfDirty();
        }
      }
      profileStore.updateSubscriptionFromUser(
        user.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (data['is_subscriber'] == true || profileStore.isSubscriber) {
        await profileStore.setSubscriberStatus(true);
      }
      await _applyUserNameIfNeeded(profileStore, user, fallback: account);
      await AuthStore.instance.setSession(
        status: 'logged_in',
        token: token,
        userId: userIdValue,
      );
      unawaited(profileStore.triggerSyncAfterLogin());
      unawaited(MealStore.instance.refreshFromServer());
      if (!mounted) return;
      Navigator.of(context).pop('dashboard');
    } catch (_) {
      _showAuthMessage('登录失败，请检查网络');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            margin: EdgeInsets.fromLTRB(8, 0, 8, 16 + safeBottom),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final baseWidth = constraints.maxWidth;
                final cardWidth = min(baseWidth * 0.94, screenWidth - 24);
                const titleAspectRatio = 1024 / 1536;
                final titleHeight = cardWidth * titleAspectRatio;
                final titleTop = -(titleHeight * 0.53);
                final maxCardHeight = screenHeight * 0.68;
                final desiredCardHeight = cardWidth * 1.15;
                final cardHeight = min(desiredCardHeight, maxCardHeight);
                final cardRadius = BorderRadius.circular(26);
                final cardGradient = context.isDarkMode
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1C2A23), Color(0xFF0E1511)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFF8F0), Color(0xFFFFEEDC)],
                      );
                final cardHighlight = context.isDarkMode
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x22FFFFFF), Color(0x00000000)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                      );
                final cardBorderColor = context.isDarkMode
                    ? app.border.withOpacity(0.8)
                    : const Color(0xFFF1C5A2);
                final cardInnerBorder = context.isDarkMode
                    ? const Color(0x26FFFFFF)
                    : const Color(0x66FFFFFF);
                final bodyPadding = EdgeInsets.fromLTRB(
                  cardWidth * 0.1,
                  cardWidth * 0.16,
                  cardWidth * 0.1,
                  cardWidth * 0.12,
                );

                return SizedBox(
                  width: cardWidth,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: cardWidth,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          borderRadius: cardRadius,
                          gradient: cardGradient,
                          border: Border.all(
                            color: cardBorderColor,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: app.shadow.withOpacity(0.22),
                              blurRadius: 26,
                              offset: const Offset(0, -8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: cardRadius,
                                  gradient: cardHighlight,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: cardInnerBorder),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: bodyPadding,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      _isRegister
                                          ? '使用账号密码完成注册'
                                          : '使用 Apple 或账号密码登录',
                                      style: GoogleFonts.inter(
                                        color: app.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _AuthField(
                                      controller: _accountController,
                                      label: '账号',
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: 12),
                                    _AuthField(
                                      controller: _passwordController,
                                      label: '密码',
                                      obscureText: _obscurePassword,
                                      textInputAction: _isRegister
                                          ? TextInputAction.next
                                          : TextInputAction.done,
                                      suffix: IconButton(
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: app.textSecondary,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    if (_isRegister) ...[
                                      const SizedBox(height: 12),
                                      _AuthField(
                                        controller: _confirmController,
                                        label: '确认密码',
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 52,
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : _submitCredentials,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primary,
                                          foregroundColor: app.textInverse,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          textStyle: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        child: _isSubmitting
                                            ? Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation(
                                                            Color(0xFF102216),
                                                          ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('请稍候...'),
                                                ],
                                              )
                                            : Text(
                                                _isRegister
                                                    ? '注册并继续'
                                                    : '账号密码登录',
                                              ),
                                      ),
                                    ),
                                    if (!_isRegister) ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 46,
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: _isSubmitting
                                              ? null
                                              : _signInWithApple,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDark
                                                ? app.textPrimary
                                                : app.primary,
                                            backgroundColor: isDark
                                                ? app.cardAlt.withOpacity(0.35)
                                                : const Color(0xFFFDF6EF),
                                            side: BorderSide(
                                              color: isDark
                                                  ? app.border
                                                  : app.primary.withOpacity(
                                                      0.5,
                                                    ),
                                              width: isDark ? 1 : 1.4,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            textStyle: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Image.asset(
                                                'images/apple.png',
                                                width: 18,
                                                height: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              if (_isSubmitting) ...[
                                                SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation(
                                                          app.textPrimary,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              const Text('使用 Apple 登录'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isRegister ? '已有账号？' : '还没有账号？',
                                          style: GoogleFonts.inter(
                                            color: app.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => setState(
                                            () => _isRegister = !_isRegister,
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: primary,
                                            textStyle: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          child: Text(
                                            _isRegister ? '去登录' : '去注册',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: titleTop,
                        left: 0,
                        right: 0,
                        height: titleHeight,
                        child: Image.asset(
                          'images/login_card_title.png',
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final isDark = context.isDarkMode;
    final fillColor = isDark
        ? app.cardAlt.withOpacity(0.75)
        : const Color(0xFFFDF8F3);
    final borderColor = isDark
        ? app.border.withOpacity(0.4)
        : const Color(0xFFE7C7A6);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      style: GoogleFonts.inter(
        color: app.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: app.textSecondary),
        floatingLabelStyle: GoogleFonts.inter(
          color: app.primary,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor, width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: app.primary, width: 1.6),
        ),
        suffixIcon: suffix,
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final Future<void> _loadFuture;
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _todayWeightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _calorieController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _allergyController = TextEditingController();
  final DateTime _calendarMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  String _cycleMode = 'weekly';
  final Set<int> _monthlyTrainingDays = {};
  final Set<int> _monthlyCheatDays = {};

  @override
  void initState() {
    super.initState();
    _loadFuture = _hydrateFromStore();
  }

  Future<void> _hydrateFromStore() async {
    final store = UserProfileStore.instance;
    await store.ensureLoaded();
    await AuthStore.instance.ensureLoaded();
    if (!mounted) return;
    _syncControllers(store);
    setState(() {
      _monthlyTrainingDays
        ..clear()
        ..addAll(store.monthlyTrainingDaysList);
      _monthlyCheatDays
        ..clear()
        ..addAll(store.monthlyCheatDaysList);
    });
  }

  void _syncControllers(UserProfileStore store) {
    _heightController.text = store.height > 0 ? store.height.toString() : '';
    _weightController.text = store.weight > 0 ? store.weight.toString() : '';
    _todayWeightController.text = store.weight > 0
        ? store.weight.toString()
        : '';
    _ageController.text = store.age > 0 ? store.age.toString() : '';
    _calorieController.text = store.calorieTarget > 0
        ? store.calorieTarget.toString()
        : '';
    _proteinController.text = store.macroProtein > 0
        ? store.macroProtein.toString()
        : '';
    _carbsController.text = store.macroCarbs > 0
        ? store.macroCarbs.toString()
        : '';
    _fatController.text = store.macroFat > 0 ? store.macroFat.toString() : '';
    final extras = store.excludedFoods
        .where((item) => !_excludedFoodOptions.contains(item))
        .toList();
    _allergyController.text = extras.join('，');
  }

  Future<void> _openWeightPlanEditor(UserProfileStore store) async {
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
          submitLabel: '更新计划',
          onSubmit: (planMode, kg, days) async {
            await store.setWeightPlan(mode: planMode, kg: kg, days: days);
            await store.setGoalType(planMode == 'loss' ? '减重' : '增重');
          },
        );
      },
    );
  }

  Future<void> _openLoginSheet() async {
    await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return const _AuthSheet(startInRegister: false);
      },
    );
  }

  Future<void> _openSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _SettingsPage(onShowExportSheet: (ctx) => _showExportSheet(ctx)),
      ),
    );
  }

  Future<void> _logout() async {
    await UserProfileStore.instance.markPendingSyncIfDirty();
    await AuthStore.instance.setStatus('none');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已退出登录，设置将仅保存在本地')));
  }

  Future<void> _openOnboardingPreview() async {
    if (_previewOnboardingFlow) return;
    setState(() {
      _previewOnboardingFlow = true;
      _forceOnboardingPreview = true;
    });
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SplashScreen()));
  }

  void _saveTodayWeight(UserProfileStore store) {
    final parsed = double.tryParse(_todayWeightController.text.trim());
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的体重数值')));
      return;
    }
    final double weightValue = parsed;
    unawaited(store.setWeightWithHistory(weightValue));
    _weightController.text = weightValue
        .toStringAsFixed(1)
        .replaceAll('.0', '');
    _todayWeightController.text = weightValue
        .toStringAsFixed(1)
        .replaceAll('.0', '');
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已更新今日体重')));
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _calorieController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _allergyController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final store = UserProfileStore.instance;
    await store.ensureLoaded();
    await AuthStore.instance.ensureLoaded();
    if (!store.isSubscriber) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订阅用户可自定义头像')));
      }
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    final urls = await OssUploadService.uploadImages(
      images: [picked],
      category: 'avatar',
    );
    if (urls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('上传失败，请重试')));
      }
      return;
    }
    final url = urls.first;
    try {
      final auth = AuthStore.instance;
      await auth.ensureLoaded();
      if (auth.token.isEmpty) return;
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/user/avatar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({'url': url}),
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && payload['code'] == 0) {
        await store.setAvatarUrl(url, localPath: picked.path);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('头像已更新')));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(payload['message']?.toString() ?? '头像更新失败')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('头像更新失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;

    return Container(
      color: app.background,
      child: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: primary));
          }
          return AnimatedBuilder(
            animation: Listenable.merge([
              UserProfileStore.instance,
              AuthStore.instance,
              ThemeStore.instance,
            ]),
            builder: (context, child) {
              final store = UserProfileStore.instance;
              final isLoggedIn = AuthStore.instance.status == 'logged_in';
              final displayName = isLoggedIn && store.userName.trim().isNotEmpty
                  ? store.userName
                  : '健康档案';
              final weekTraining = store.weeklyTrainingDays;
              final cheatFrequency = store.cheatFrequency;

              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => FocusScope.of(context).unfocus(),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16 + MediaQuery.of(context).padding.top,
                    16,
                    140,
                  ),
                  children: [
                    Row(
                      children: [
                        Text(
                          '我的设置',
                          style: GoogleFonts.inter(
                            color: app.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _openSettingsPage,
                          icon: Icon(Icons.settings, color: app.textPrimary),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: isLoggedIn ? null : _openLoginSheet,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: app.heroGradient,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: app.border.withOpacity(0.6),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: app.shadow.withOpacity(0.2),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: _ProfileInfoColumn(
                              displayName: displayName,
                              app: app,
                              store: store,
                              weekTraining: weekTraining,
                              cheatFrequency: cheatFrequency,
                              onPickAvatar: _pickAvatar,
                              canUploadAvatar: isLoggedIn && store.isSubscriber,
                            ),
                          ),
                          Positioned(
                            right: 12,
                            top: -10,
                            child: _StatusBubble(
                              label: isLoggedIn ? '已登录' : '点击登录',
                              textColor: isLoggedIn
                                  ? primary
                                  : app.textSecondary,
                              backgroundColor: isLoggedIn
                                  ? primary.withOpacity(0.18)
                                  : app.card,
                              borderColor: isLoggedIn
                                  ? primary.withOpacity(0.35)
                                  : app.border,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: '徽章馆', subtitle: '你的成长里程碑'),
                    const SizedBox(height: 12),
                    _BadgeTimeline(
                      entries: [
                        _BadgeEntry(
                          asset: 'images/first.png',
                          dateLabel: _formatShortDate(DateTime.now()),
                          locked: !isLoggedIn,
                          title: '初见元气',
                        ),
                        _BadgeEntry(
                          asset: 'images/vip.png',
                          dateLabel: '订阅解锁',
                          locked: !store.isSubscriber,
                          title: 'VIP',
                        ),
                        const _BadgeEntry(
                          asset: '',
                          dateLabel: '即将上线',
                          locked: true,
                          title: '更多徽章',
                          upcoming: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: '体重计划', subtitle: '减重/增重曲线预览'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '目标曲线',
                          style: GoogleFonts.inter(
                            color: app.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _openWeightPlanEditor(store),
                          style: TextButton.styleFrom(
                            foregroundColor: primary,
                            textStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('调整计划'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            await store.resetWeightHistoryToToday();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已重置计划起点为今天')),
                              );
                            }
                            setState(() {});
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: app.textSecondary,
                            textStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('重置计划'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              app.card.withOpacity(0.9),
                              app.backgroundAlt.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _WeightPlanChart(
                            currentWeight: (store.weight > 0
                                ? store.weight.toDouble()
                                : 65),
                            targetWeight:
                                (store.weight > 0
                                    ? store.weight.toDouble()
                                    : 65) +
                                (store.weightPlanMode == 'loss'
                                    ? -store.weightPlanKg
                                    : store.weightPlanKg),
                            days: store.weightPlanDays,
                            mode: store.weightPlanMode,
                            history: store.weightHistory,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '输入今日体重（kg）',
                      style: GoogleFonts.inter(
                        color: app.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: app.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: app.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.monitor_weight_outlined,
                                  size: 18,
                                  color: app.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _todayWeightController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: GoogleFonts.inter(
                                      color: app.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textInputAction: TextInputAction.done,
                                    onTapOutside: (_) =>
                                        FocusScope.of(context).unfocus(),
                                    onSubmitted: (_) => _saveTodayWeight(store),
                                    decoration: InputDecoration(
                                      hintText: '输入今日体重',
                                      hintStyle: GoogleFonts.inter(
                                        color: app.textSecondary,
                                        fontSize: 12,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                Text(
                                  'kg',
                                  style: GoogleFonts.inter(
                                    color: app.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () => _saveTodayWeight(store),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: app.textInverse,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '更新后会同步到目标曲线与基础信息。',
                      style: GoogleFonts.inter(
                        color: app.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '计划：${store.weightPlanDays} 天内${_weightPlanModeLabels[store.weightPlanMode] ?? '减重'} ${store.weightPlanKg.toStringAsFixed(1).replaceAll('.0', '')} kg',
                      style: GoogleFonts.inter(
                        color: app.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: '周期计划',
                      subtitle: '按周或按月设置放纵日与锻炼日',
                    ),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _SegmentButton(
                                  label: '按周',
                                  selected: _cycleMode == 'weekly',
                                  onTap: () => setState(() {
                                    _cycleMode = 'weekly';
                                  }),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SegmentButton(
                                  label: '按月',
                                  selected: _cycleMode == 'monthly',
                                  onTap: () => setState(() {
                                    _cycleMode = 'monthly';
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_cycleMode == 'weekly') ...[
                            Text(
                              '训练日',
                              style: GoogleFonts.inter(
                                color: app.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _weekDayLabels.asMap().entries.map((
                                entry,
                              ) {
                                final day = entry.key + 1;
                                return _DayToggleChip(
                                  label: '周${entry.value}',
                                  selected: store.weeklyTrainingDaysList
                                      .contains(day),
                                  activeColor: primary,
                                  onTap: () => _toggleWeeklyDay(
                                    isTraining: true,
                                    day: day,
                                    store: store,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '放纵日',
                              style: GoogleFonts.inter(
                                color: app.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _weekDayLabels.asMap().entries.map((
                                entry,
                              ) {
                                final day = entry.key + 1;
                                return _DayToggleChip(
                                  label: '周${entry.value}',
                                  selected: store.weeklyCheatDaysList.contains(
                                    day,
                                  ),
                                  activeColor: const Color(0xFFFFB020),
                                  onTap: () => _toggleWeeklyDay(
                                    isTraining: false,
                                    day: day,
                                    store: store,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '未选择的日期默认为正常日。',
                              style: GoogleFonts.inter(
                                color: app.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ] else ...[
                            _MonthlyCalendarCard(
                              title: '锻炼日',
                              subtitle: '选择本月训练日',
                              month: _calendarMonth,
                              selectedDays: _monthlyTrainingDays,
                              accentColor: primary,
                              onToggle: (day) {
                                _toggleMonthlyDay(
                                  isTraining: true,
                                  day: day,
                                  store: store,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _MonthlyCalendarCard(
                              title: '放纵日',
                              subtitle: '选择本月放松日',
                              month: _calendarMonth,
                              selectedDays: _monthlyCheatDays,
                              accentColor: const Color(0xFFFFB020),
                              onToggle: (day) {
                                _toggleMonthlyDay(
                                  isTraining: false,
                                  day: day,
                                  store: store,
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '月度选择将自动换算为每周训练天数与放纵频率。',
                              style: GoogleFonts.inter(
                                color: app.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          // 生成菜单功能已移除
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: '基本信息',
                      subtitle: '更新你的基础身体数据与训练背景',
                    ),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _InlineField(
                                  controller: _heightController,
                                  label: '身高',
                                  suffix: 'cm',
                                  onChanged: (value) {
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed != null) {
                                      unawaited(store.setHeight(parsed));
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InlineField(
                                  controller: _weightController,
                                  label: '体重',
                                  suffix: 'kg',
                                  onChanged: (value) {
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed != null) {
                                      unawaited(store.setWeight(parsed));
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _InlineField(
                            controller: _ageController,
                            label: '年龄',
                            suffix: '岁',
                            onChanged: (value) {
                              final parsed = int.tryParse(value.trim());
                              if (parsed != null) {
                                unawaited(store.setAge(parsed));
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _ChipGroup(
                            title: '性别',
                            options: _genderOptions,
                            selected: store.gender,
                            onSelect: (value) =>
                                unawaited(store.setGender(value)),
                          ),
                          const SizedBox(height: 16),
                          _ChipGroup(
                            title: '活动水平',
                            options: _activityLevelOptions,
                            selected: store.activityLevel,
                            onSelect: (value) =>
                                unawaited(store.setActivityLevel(value)),
                          ),
                          const SizedBox(height: 16),
                          _ChipGroup(
                            title: '训练经验',
                            options: _trainingExperienceOptions,
                            selected: store.trainingExperience,
                            onSelect: (value) =>
                                unawaited(store.setTrainingExperience(value)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: '健身目标',
                      subtitle: '决定你的训练节奏与训练偏好',
                    ),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChipGroup(
                            title: '健身目标',
                            options: _goalTypeOptions,
                            selected: store.goalType,
                            onSelect: (value) =>
                                unawaited(store.setGoalType(value)),
                          ),
                          const SizedBox(height: 16),
                          _ChipGroup(
                            title: '偏好训练时间',
                            options: _preferredTrainingTimeOptions,
                            selected: store.preferredTrainingTime,
                            onSelect: (value) => unawaited(
                              store.setPreferredTrainingTime(value),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _MultiChipGroup(
                            title: '训练类型偏好',
                            options: _trainingTypeOptions,
                            selected: store.trainingTypePreference,
                            onToggle: (value) => unawaited(
                              store.toggleTrainingTypePreference(value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: '饮食偏好与限制',
                      subtitle: '让推荐更贴合你的饮食习惯',
                    ),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MultiChipGroup(
                            title: '饮食偏好',
                            options: _dietPreferenceOptions,
                            selected: store.dietPreferences,
                            onToggle: (value) =>
                                unawaited(store.toggleDietPreference(value)),
                          ),
                          const SizedBox(height: 16),
                          _MultiChipGroup(
                            title: '过敏源',
                            options: _excludedFoodOptions,
                            selected: store.excludedFoods,
                            onToggle: (value) =>
                                unawaited(store.toggleExcludedFood(value)),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _allergyController,
                            style: GoogleFonts.inter(color: app.textPrimary),
                            onChanged: (value) =>
                                _updateCustomAllergens(store, value),
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              labelText: '其他过敏源（可选，逗号分隔）',
                              labelStyle: GoogleFonts.inter(
                                color: app.textSecondary,
                              ),
                              filled: true,
                              fillColor: app.cardAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _InlineField(
                            controller: _calorieController,
                            label: '每日热量目标',
                            suffix: 'kcal',
                            onChanged: (value) {
                              final parsed = int.tryParse(value.trim());
                              if (parsed != null) {
                                unawaited(store.setCalorieTarget(parsed));
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '宏量目标',
                            style: GoogleFonts.inter(
                              color: app.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _InlineField(
                                  controller: _proteinController,
                                  label: '蛋白',
                                  suffix: 'g',
                                  onChanged: (value) {
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed != null) {
                                      unawaited(
                                        store.setMacroTargets(protein: parsed),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InlineField(
                                  controller: _carbsController,
                                  label: '碳水',
                                  suffix: 'g',
                                  onChanged: (value) {
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed != null) {
                                      unawaited(
                                        store.setMacroTargets(carbs: parsed),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InlineField(
                                  controller: _fatController,
                                  label: '脂肪',
                                  suffix: 'g',
                                  onChanged: (value) {
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed != null) {
                                      unawaited(
                                        store.setMacroTargets(fat: parsed),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ChipGroup(
                            title: '晚间进食习惯',
                            options: _lateEatingHabitOptions,
                            selected: store.lateEatingHabit,
                            onSelect: (value) =>
                                unawaited(store.setLateEatingHabit(value)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: '大胡子个性化设置',
                      subtitle: '调整大胡子提醒和建议方式',
                    ),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChipGroup(
                            title: '大胡子建议风格',
                            options: _aiSuggestionStyleOptions,
                            selected: store.aiSuggestionStyle,
                            onSelect: (value) =>
                                unawaited(store.setAiSuggestionStyle(value)),
                          ),
                          const SizedBox(height: 16),
                          _SwitchTile(
                            title: '启用行动提示',
                            subtitle: '提醒使用应用内功能',
                            value: store.actionSuggestionEnabled,
                            onChanged: (value) => unawaited(
                              store.setActionSuggestionEnabled(value),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SliderRow(
                            title: '提醒频率（次/天）',
                            subtitle: '控制大胡子提示频率',
                            min: 0,
                            max: 5,
                            value: store.reminderFrequency,
                            onChanged: (value) =>
                                unawaited(store.setReminderFrequency(value)),
                          ),
                          const SizedBox(height: 12),
                          _SwitchTile(
                            title: '数据使用授权',
                            subtitle: '允许大胡子记录并优化推荐',
                            value: store.dataUsageConsent,
                            onChanged: (value) =>
                                unawaited(store.setDataUsageConsent(value)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _toggleWeeklyDay({
    required bool isTraining,
    required int day,
    required UserProfileStore store,
  }) {
    final updated = isTraining
        ? List<int>.from(store.weeklyTrainingDaysList)
        : List<int>.from(store.weeklyCheatDaysList);
    if (updated.contains(day)) {
      updated.remove(day);
    } else {
      updated.add(day);
    }
    if (isTraining) {
      unawaited(store.setWeeklyTrainingDaysList(updated));
    } else {
      unawaited(store.setWeeklyCheatDaysList(updated));
    }
  }

  Future<void> _generateWeeklyMenus() async {
    // 功能已移除
  }

  void _toggleMonthlyDay({
    required bool isTraining,
    required int day,
    required UserProfileStore store,
  }) {
    setState(() {
      final targetSet = isTraining ? _monthlyTrainingDays : _monthlyCheatDays;
      if (targetSet.contains(day)) {
        targetSet.remove(day);
      } else {
        targetSet.add(day);
      }
    });
    final daysInMonth = DateUtils.getDaysInMonth(
      _calendarMonth.year,
      _calendarMonth.month,
    );
    final selectedCount = isTraining
        ? _monthlyTrainingDays.length
        : _monthlyCheatDays.length;
    final normalized = ((selectedCount / daysInMonth) * 7).round();
    if (isTraining) {
      unawaited(store.setWeeklyTrainingDays(normalized));
      unawaited(
        store.setMonthlyTrainingDaysList(_monthlyTrainingDays.toList()),
      );
    } else {
      unawaited(store.setCheatFrequency(normalized));
      unawaited(store.setMonthlyCheatDaysList(_monthlyCheatDays.toList()));
    }
  }

  void _updateCustomAllergens(UserProfileStore store, String value) {
    final extras = value
        .split(RegExp(r'[，,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final selected = store.excludedFoods
        .where((item) => _excludedFoodOptions.contains(item))
        .toList();
    unawaited(store.setExcludedFoods([...selected, ...extras]));
  }

  Future<void> _pickTime(
    BuildContext context,
    String current,
    ValueChanged<String> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(current),
    );
    if (picked == null) return;
    onPicked(_formatTimeOfDay(picked));
  }

  Future<void> _showExportSheet(BuildContext context) async {
    final store = UserProfileStore.instance;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final app = context.appColors;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: app.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: app.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: app.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '选择导出格式',
                style: GoogleFonts.inter(
                  color: app.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _SheetOption(
                label: '导出 JSON',
                onTap: () => Navigator.of(context).pop('json'),
              ),
              const SizedBox(height: 8),
              _SheetOption(
                label: '导出 CSV',
                onTap: () => Navigator.of(context).pop('csv'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    await store.markExportData(selected);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已导出为 ${selected.toUpperCase()}')));
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.onShowExportSheet});

  final Future<void> Function(BuildContext context) onShowExportSheet;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool _previewOnboarding = _previewOnboardingFlow;

  Future<void> _pickTime(
    BuildContext context,
    String current,
    ValueChanged<String> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(current),
    );
    if (picked == null) return;
    onPicked(_formatTimeOfDay(picked));
  }

  Future<void> _logout() async {
    await UserProfileStore.instance.markPendingSyncIfDirty();
    await AuthStore.instance.setStatus('none');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已退出登录，设置将仅保存在本地')));
  }

  Future<void> _openOnboardingPreview() async {
    if (_previewOnboardingFlow) return;
    setState(() {
      _previewOnboardingFlow = true;
      _forceOnboardingPreview = true;
      _previewOnboarding = true;
    });
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SplashScreen()));
    if (!mounted) return;
    setState(() {
      _previewOnboarding = _previewOnboardingFlow;
    });
  }

  void _togglePreview(bool value) {
    if (!value) {
      setState(() {
        _previewOnboardingFlow = false;
        _forceOnboardingPreview = false;
        _previewOnboarding = false;
      });
      return;
    }
    unawaited(_openOnboardingPreview());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;

    return Scaffold(
      backgroundColor: app.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: app.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, color: app.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text(
              '设置',
              style: GoogleFonts.inter(
                color: app.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<void>(
        future: UserProfileStore.instance.ensureLoaded(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: primary));
          }
          return AnimatedBuilder(
            animation: Listenable.merge([
              UserProfileStore.instance,
              AuthStore.instance,
              ThemeStore.instance,
            ]),
            builder: (context, child) {
              final store = UserProfileStore.instance;
              final isLoggedIn = AuthStore.instance.status == 'logged_in';
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const _SectionTitle(title: '外观', subtitle: '主题与显示'),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: app.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            ThemeStore.instance.isDark
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color: app.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '主题模式',
                                style: GoogleFonts.inter(
                                  color: app.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ThemeStore.instance.isDark
                                    ? '深色 · 夜间护眼'
                                    : '浅色 · 清新明亮',
                                style: GoogleFonts.inter(
                                  color: app.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: ThemeStore.instance.mode == ThemeMode.light,
                          onChanged: (value) {
                            ThemeStore.instance.setMode(
                              value ? ThemeMode.light : ThemeMode.dark,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: '通知与提醒', subtitle: '保持节奏与习惯养成'),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReminderTile(
                          title: '饮食提醒',
                          subtitle: '按时提醒三餐',
                          enabled: store.mealReminderEnabled,
                          timeLabel: store.mealReminderTime,
                          onToggle: (value) =>
                              unawaited(store.setMealReminderEnabled(value)),
                          onPickTime: () => _pickTime(
                            context,
                            store.mealReminderTime,
                            (value) =>
                                unawaited(store.setMealReminderTime(value)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ReminderTile(
                          title: '训练提醒',
                          subtitle: '保持训练节奏',
                          enabled: store.trainingReminderEnabled,
                          timeLabel: store.trainingReminderTime,
                          onToggle: (value) => unawaited(
                            store.setTrainingReminderEnabled(value),
                          ),
                          onPickTime: () => _pickTime(
                            context,
                            store.trainingReminderTime,
                            (value) =>
                                unawaited(store.setTrainingReminderTime(value)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          title: '水分摄入提醒',
                          subtitle: '规律补水更高效',
                          value: store.waterReminderEnabled,
                          leading: Image.asset(
                            'images/fantuan_water.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                          ),
                          onChanged: (value) =>
                              unawaited(store.setWaterReminderEnabled(value)),
                        ),
                        if (store.waterReminderEnabled) ...[
                          const SizedBox(height: 8),
                          _SliderRow(
                            title: '喝水提醒间隔（分钟）',
                            subtitle: '建议 30-120 分钟',
                            min: 30,
                            max: 120,
                            value: store.waterReminderInterval,
                            onChanged: (value) => unawaited(
                              store.setWaterReminderInterval(value),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _SwitchTile(
                          title: '每日小贴士',
                          subtitle: '获取每日健康建议',
                          value: store.dailyTipsEnabled,
                          onChanged: (value) =>
                              unawaited(store.setDailyTipsEnabled(value)),
                        ),
                        const SizedBox(height: 12),
                        _ActionButton(
                          label: '测试通知',
                          subtitle: '立即弹出一条本地提醒',
                          onTap: () async {
                            await NotificationService.instance
                                .showTestNotification();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已发送测试通知')),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          title: '摇一摇拍照记餐',
                          subtitle: '摇动手机直接拍照生成用餐记录',
                          value: store.shakeToScanEnabled,
                          onChanged: (value) =>
                              unawaited(store.setShakeToScanEnabled(value)),
                        ),
                        if (store.shakeToScanEnabled) ...[
                          const SizedBox(height: 8),
                          _SliderRowDouble(
                            title: '摇一摇灵敏度',
                            subtitle: '数值越大越不敏感',
                            min: 1.2,
                            max: 4.0,
                            value: store.shakeSensitivity,
                            onChanged: (value) =>
                                unawaited(store.setShakeSensitivity(value)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: '高级选项', subtitle: '更细颗粒度的大胡子设置'),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SliderRow(
                          title: '大胡子推荐严格度',
                          subtitle: '数值越高越严格',
                          min: 0,
                          max: 100,
                          value: store.aiPersonalityAdjustment,
                          onChanged: (value) => unawaited(
                            store.setAiPersonalityAdjustment(value),
                          ),
                        ),
                        if (store.aiPersonalityAdjustment >= 100) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFEF4444).withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '不近人情模式已开启，回答会更直接严厉。',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFFCA5A5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _ActionButton(
                          label: '重置饮食人格',
                          subtitle: '清空大胡子记忆偏好',
                          onTap: () async {
                            await store.markResetFoodPersonality();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已重置饮食人格')),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _ActionButton(
                          label: '导出用户数据',
                          subtitle: '支持 CSV 或 JSON',
                          onTap: () => widget.onShowExportSheet(context),
                        ),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          title: '本地生成发现页菜单',
                          subtitle: '仅用于测试，允许生成未来日期菜单',
                          value: store.discoverDevMode,
                          onChanged: (value) =>
                              unawaited(store.setDiscoverDevMode(value)),
                        ),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          title: '预览引导设置页',
                          subtitle: '用于查看引导流程效果',
                          value: _previewOnboarding,
                          onChanged: _togglePreview,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: '帮助与反馈', subtitle: '联系我们'),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: app.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.mail_outline, color: app.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '反馈邮箱',
                                style: GoogleFonts.inter(
                                  color: app.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'fguby1995@gmail.com',
                                style: GoogleFonts.inter(
                                  color: app.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: app.textSecondary),
                      ],
                    ),
                  ),
                  if (isLoggedIn) ...[
                    const SizedBox(height: 24),
                    const _SectionTitle(title: '账户', subtitle: '登录与同步'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      child: _ActionButton(
                        label: '退出登录',
                        subtitle: '退出后仅本地保存，登录后再同步',
                        onTap: _logout,
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: app.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(color: app.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: app.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: app.border),
      ),
      child: child,
    );
  }
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.onChanged,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: app.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: app.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: app.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType ?? TextInputType.number,
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  onChanged: onChanged,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              Text(
                suffix,
                style: GoogleFonts.inter(
                  color: app.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: app.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => _OptionChip(
                  label: option,
                  selected: option == selected,
                  onTap: () => onSelect(option),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MultiChipGroup extends StatelessWidget {
  const _MultiChipGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: app.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => _OptionChip(
                  label: option,
                  selected: selected.contains(option),
                  onTap: () => onToggle(option),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.subtitle,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int min;
  final int max;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: app.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: app.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                value.toString(),
                style: GoogleFonts.inter(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: primary,
          inactiveColor: app.border,
          onChanged: (val) => onChanged(val.round()),
        ),
      ],
    );
  }
}

class _SliderRowDouble extends StatelessWidget {
  const _SliderRowDouble({
    required this.title,
    required this.subtitle,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final display = value.toStringAsFixed(1);
    final divisions = ((max - min) / 0.1).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: app.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: app.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                display,
                style: GoogleFonts.inter(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: primary,
          inactiveColor: app.border,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MonthlyCalendarCard extends StatelessWidget {
  const _MonthlyCalendarCard({
    required this.title,
    required this.subtitle,
    required this.month,
    required this.selectedDays,
    required this.accentColor,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final DateTime month;
  final Set<int> selectedDays;
  final Color accentColor;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final leading = firstWeekday - 1;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;
    final cells = List<int?>.filled(totalCells, null);
    for (var day = 1; day <= daysInMonth; day += 1) {
      cells[leading + day - 1] = day;
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: app.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              Text(
                '${month.year}年${month.month}月',
                style: GoogleFonts.inter(
                  color: app.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _weekDayLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          color: app.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final day = cells[index];
              if (day == null) {
                return const SizedBox.shrink();
              }
              final selected = selectedDays.contains(day);
              return GestureDetector(
                onTap: () => onToggle(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: selected ? accentColor : app.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? accentColor : app.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: GoogleFonts.inter(
                        color: selected ? app.textInverse : app.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '已选择 ${selectedDays.length} 天',
            style: GoogleFonts.inter(
              color: accentColor.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.timeLabel,
    required this.onToggle,
    required this.onPickTime,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final String timeLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: app.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: app.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
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
          GestureDetector(
            onTap: enabled ? onPickTime : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: enabled ? primary.withOpacity(0.18) : app.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: enabled ? primary.withOpacity(0.5) : app.border,
                ),
              ),
              child: Text(
                timeLabel,
                style: GoogleFonts.inter(
                  color: enabled ? primary : app.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Switch.adaptive(
            value: enabled,
            activeColor: primary,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: app.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: app.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: app.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            Icon(Icons.chevron_right, color: app.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: app.cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: app.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: app.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SettingsChoiceButton extends StatelessWidget {
  const _SettingsChoiceButton({
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.color,
    this.textColor,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final bg = color ?? app.cardAlt;
    final fg = textColor ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: app.border),
          boxShadow: [
            BoxShadow(
              color: app.shadow.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: (textColor ?? app.textPrimary).withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(0.2) : app.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? primary : app.border, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? primary : app.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary : app.cardAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? primary : app.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? app.textInverse : app.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DayToggleChip extends StatelessWidget {
  const _DayToggleChip({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.18) : app.cardAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? activeColor : app.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? activeColor : app.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? primary : app.cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? primary : app.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? app.textInverse : app.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CounterStepper extends StatelessWidget {
  const _CounterStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: app.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: app.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          const SizedBox(width: 10),
          Text(
            value.toString(),
            style: GoogleFonts.inter(
              color: app.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          _StepperButton(
            icon: Icons.add,
            enabled: value < max,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? primary.withOpacity(0.2) : app.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: enabled ? primary : app.textSecondary,
          size: 16,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.leading,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: app.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: app.border),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: app.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: app.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoChip extends StatelessWidget {
  const _ProfileInfoChip({required this.label});

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

class _ProfileInfoColumn extends StatelessWidget {
  const _ProfileInfoColumn({
    required this.displayName,
    required this.app,
    required this.store,
    required this.weekTraining,
    required this.cheatFrequency,
    required this.onPickAvatar,
    required this.canUploadAvatar,
  });

  final String displayName;
  final AppColors app;
  final UserProfileStore store;
  final int weekTraining;
  final int cheatFrequency;
  final VoidCallback onPickAvatar;
  final bool canUploadAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedBuilder(
              animation: UserProfileStore.instance,
              builder: (context, child) {
                final asset = _defaultAvatarAsset(
                  UserProfileStore.instance.gender,
                );
                final local = store.displayAvatarLocalPath;
                final avatar = store.displayAvatarUrl.trim();
                Widget avatarWidget;
                if (local != null) {
                  avatarWidget = ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(local),
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                    ),
                  );
                } else if (avatar.isNotEmpty) {
                  avatarWidget = ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      avatar,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                    ),
                  );
                } else {
                  avatarWidget = SizedBox(
                    width: 58,
                    height: 58,
                    child: Image.asset(asset, fit: BoxFit.cover),
                  );
                }
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    avatarWidget,
                    if (canUploadAvatar)
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: GestureDetector(
                          onTap: onPickAvatar,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: app.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: app.primary.withOpacity(0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      color: app.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${store.goalType} · ${store.trainingExperience} · ${store.activityLevel}',
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ProfileInfoChip(label: '训练 $weekTraining 天/周'),
            _ProfileInfoChip(label: '放纵 $cheatFrequency 次/周'),
            _ProfileInfoChip(label: '热量 ${store.calorieTarget} kcal'),
            _ProfileInfoChip(label: '偏好 ${store.dietPreferences.length} 项'),
          ],
        ),
      ],
    );
  }
}

class _BadgeEntry {
  const _BadgeEntry({
    required this.asset,
    required this.dateLabel,
    required this.title,
    this.locked = false,
    this.upcoming = false,
  });

  final String asset;
  final String dateLabel;
  final String title;
  final bool locked;
  final bool upcoming;
}

class _BadgeTimeline extends StatelessWidget {
  const _BadgeTimeline({required this.entries});

  final List<_BadgeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    if (entries.isEmpty) {
      return Text(
        '暂无徽章',
        style: GoogleFonts.inter(color: app.textSecondary, fontSize: 12),
      );
    }

    const itemWidth = 150.0;
    final totalWidth = itemWidth * entries.length + 24;

    return SizedBox(
      height: 190,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SizedBox(
          width: totalWidth,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 132,
                child: Container(height: 2, color: app.border),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.map((entry) {
                return SizedBox(
                  width: itemWidth,
                  child: Column(
                    children: [
                        Text(
                          entry.dateLabel,
                          style: GoogleFonts.inter(
                            color: app.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    const SizedBox(height: 6),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          entry.asset.isNotEmpty
                              ? entry.asset
                              : 'images/first.png',
                          width: 130,
                          height: 130,
                          fit: BoxFit.contain,
                          opacity: entry.locked
                              ? const AlwaysStoppedAnimation(0.4)
                              : null,
                        ),
                        if (entry.upcoming)
                          Positioned(
                            bottom: 6,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC93C),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFC93C)
                                        .withOpacity(0.45),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                '待上线',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF6B3A00),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.locked ? '等待解锁' : entry.title,
                          style: GoogleFonts.inter(
                            color: entry.locked
                                ? app.textSecondary
                                : app.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBubble extends StatelessWidget {
  const _StatusBubble({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: -4,
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.all(color: borderColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeItem extends StatelessWidget {
  const _BadgeItem({required this.asset, required this.size});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
  }
}


class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF13EC5B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
