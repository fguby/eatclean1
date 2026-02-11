part of '../main.dart';

class _BottomBarClipper extends CustomClipper<Path> {
  const _BottomBarClipper();

  @override
  Path getClip(Size size) {
    const cornerRadius = 22.0;
    const notchRadius = 44.0;
    const notchCenterY = 6.0;
    final outer = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, size.width, size.height),
          topLeft: const Radius.circular(cornerRadius),
          topRight: const Radius.circular(cornerRadius),
        ),
      );
    final notch = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, notchCenterY),
          radius: notchRadius,
        ),
      );
    return Path.combine(PathOperation.difference, outer, notch);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Center(
      child: Container(
        width: 128,
        height: 5,
        decoration: BoxDecoration(
          color: app.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: primary),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: app.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.tag,
    required this.onSelect,
  });

  final IconData icon;
  final String title;
  final String description;
  final String imageUrl;
  final String tag;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: app.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: app.border, width: 1),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: primary, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              color: app.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          color: app.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl.startsWith('http')
                      ? Image.network(
                          imageUrl,
                          width: 72,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          imageUrl,
                          width: 72,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.inter(
                      color: primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onSelect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: app.textInverse,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('选择计划'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              color: primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.checklist, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: app.textPrimary,
              ),
            ),
          ),
          Checkbox(
            value: value,
            onChanged: (value) => onChanged(value ?? false),
            activeColor: primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricField extends StatelessWidget {
  const _MetricField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
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
              color: app.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: app.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(color: app.textPrimary),
              onChanged: onChanged,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.inter(color: app.textSecondary),
                hintText: hint,
                hintStyle: GoogleFonts.inter(color: app.textTertiary),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BmiStatusBar extends StatelessWidget {
  const _BmiStatusBar({required this.bmi});

  final double? bmi;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final ranges = _bmiRanges;
    final min = ranges.first.min;
    final max = ranges.last.max;
    final double ratio = bmi == null
        ? 0.0
        : ((bmi! - min) / (max - min)).clamp(0.0, 1.0).toDouble();
    final indicatorColor = bmi == null ? app.textTertiary : _bmiColorFor(bmi!);
    final tickStyle = GoogleFonts.inter(
      color: app.textTertiary,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    final labelStyle = GoogleFonts.inter(
      color: app.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('18.5', style: tickStyle),
            Text('25.0', style: tickStyle),
            Text('30.0', style: tickStyle),
            Text('35.0', style: tickStyle),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const barHeight = 8.0;
            const dotSize = 12.0;
            final double indicatorX = constraints.maxWidth * ratio;
            final double indicatorLeft = (indicatorX - dotSize / 2)
                .clamp(0.0, constraints.maxWidth - dotSize)
                .toDouble();
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: barHeight,
                    child: Row(
                      children: ranges
                          .map(
                            (range) => Expanded(
                              flex: ((range.max - range.min) * 10).round(),
                              child: Container(
                                color: range.color.withOpacity(0.85),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                if (bmi != null)
                  Positioned(
                    left: indicatorLeft,
                    top: -10,
                    child: Column(
                      children: [
                        Container(
                          width: 2,
                          height: 14,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: indicatorColor.withOpacity(0.45),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: ranges
              .map(
                (range) => Expanded(
                  flex: ((range.max - range.min) * 10).round(),
                  child: Text(
                    range.label,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _WeightPlanSheet extends StatefulWidget {
  const _WeightPlanSheet({
    required this.initialMode,
    required this.initialKg,
    required this.initialDays,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String initialMode;
  final double initialKg;
  final int initialDays;
  final String submitLabel;
  final void Function(String mode, double kg, int days) onSubmit;

  @override
  State<_WeightPlanSheet> createState() => _WeightPlanSheetState();
}

class _WeightPlanSheetState extends State<_WeightPlanSheet> {
  late String _mode;
  late final TextEditingController _kgController;
  late final TextEditingController _daysController;

  @override
  void initState() {
    super.initState();
    _mode = _weightPlanModeOptions.contains(widget.initialMode)
        ? widget.initialMode
        : 'loss';
    _kgController = TextEditingController(
      text: widget.initialKg.toStringAsFixed(1).replaceAll('.0', ''),
    );
    _daysController = TextEditingController(
      text: widget.initialDays.toString(),
    );
    _kgController.addListener(_refreshPreview);
    _daysController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _kgController.removeListener(_refreshPreview);
    _daysController.removeListener(_refreshPreview);
    _kgController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  void _submit() {
    final kg = double.tryParse(_kgController.text.trim());
    final days = int.tryParse(_daysController.text.trim());
    if (kg == null || kg <= 0) {
      _showMessage('请输入有效的体重变化');
      return;
    }
    if (days == null || days <= 0) {
      _showMessage('请输入有效的计划天数');
      return;
    }
    Navigator.of(context).pop();
    widget.onSubmit(_mode, kg, days);
  }

  void _showMessage(String message) {
    final app = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: app.textPrimary),
        ),
        backgroundColor: app.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final shadowOpacity = context.isDarkMode ? 0.45 : 0.18;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final modeLabel = _weightPlanModeLabels[_mode] ?? '减重';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + safeBottom),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: app.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: app.border),
              boxShadow: [
                BoxShadow(
                  color: app.shadow.withOpacity(shadowOpacity),
                  blurRadius: 18,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: app.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '体重计划',
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '设定减重或增重的目标节奏。',
                  style: GoogleFonts.inter(
                    color: app.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SegmentButton(
                        label: '减重',
                        selected: _mode == 'loss',
                        onTap: () => setState(() => _mode = 'loss'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SegmentButton(
                        label: '增重',
                        selected: _mode == 'gain',
                        onTap: () => setState(() => _mode = 'gain'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _AuthField(
                        controller: _daysController,
                        label: '计划天数',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AuthField(
                        controller: _kgController,
                        label: '目标变化（kg）',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '计划：${_daysController.text.isEmpty ? '--' : _daysController.text} 天内$modeLabel ${_kgController.text.isEmpty ? '--' : _kgController.text} kg',
                  style: GoogleFonts.inter(
                    color: app.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: app.textInverse,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(widget.submitLabel),
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

class _WeightPlanChart extends StatefulWidget {
  const _WeightPlanChart({
    required this.currentWeight,
    required this.targetWeight,
    required this.days,
    required this.mode,
    required this.history,
  });

  final double currentWeight;
  final double targetWeight;
  final int days;
  final String mode;
  final Map<String, double> history;

  @override
  State<_WeightPlanChart> createState() => _WeightPlanChartState();
}

class _WeightPlanChartState extends State<_WeightPlanChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_WeightPlanChart old) {
    super.didUpdateWidget(old);
    if (old.currentWeight != widget.currentWeight ||
        old.targetWeight != widget.targetWeight ||
        old.days != widget.days ||
        old.mode != widget.mode) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final isDark = context.isDarkMode;

    return AnimatedBuilder(
      animation: _animation,
      builder: (ctx, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
                  : [const Color(0xFFF8F9FA), const Color(0xFFFFFFFF)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: app.border.withOpacity(0.5), width: 1),
          ),
          child: SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _WeightCurvePainter(
                currentWeight: widget.currentWeight,
                targetWeight: widget.targetWeight,
                days: widget.days,
                mode: widget.mode,
                isDark: isDark,
                history: widget.history,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeightCurvePainter extends CustomPainter {
  _WeightCurvePainter({
    required this.currentWeight,
    required this.targetWeight,
    required this.days,
    required this.mode,
    required this.isDark,
    required this.history,
  });

  final double currentWeight;
  final double targetWeight;
  final int days;
  final String mode;
  final bool isDark;
  final Map<String, double> history;

  @override
  void paint(Canvas canvas, Size size) {
    final isLoss = mode == 'loss';

    // Rainbow gradient colors
    final rainbowColors = isLoss
        ? [
            const Color(0xFFFF6B6B),
            const Color(0xFFFFB347),
            const Color(0xFFFFF59D),
            const Color(0xFF9AE6B4),
            const Color(0xFF4FC3F7),
            const Color(0xFF7E57C2),
          ]
        : [
            const Color(0xFF7E57C2),
            const Color(0xFF4FC3F7),
            const Color(0xFF9AE6B4),
            const Color(0xFFFFF59D),
            const Color(0xFFFFB347),
            const Color(0xFFFF6B6B),
          ];

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: rainbowColors,
    );

    // Calculate positions
    const paddingX = 36.0;
    const paddingY = 60.0;
    final startX = paddingX;
    final endX = size.width - paddingX;
    final minY = paddingY;
    final maxY = size.height - paddingY;

    // 动态弧度：根据体重差与天数调整，适度收敛
    // Start/Today weights from历史: 取最早为起点，最近为今天
    double startWeight = currentWeight;
    double todayWeight = currentWeight;
    DateTime startDate = DateTime.now();
    DateTime todayDate = DateTime.now();
    if (history.isNotEmpty) {
      final sorted = history.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      startWeight = sorted.first.value;
      todayWeight = sorted.last.value;
      startDate = DateTime.tryParse(sorted.first.key) ?? startDate;
      todayDate = DateTime.tryParse(sorted.last.key) ?? todayDate;
    }

    final sameDay = history.length <= 1 ||
        _sameDay(startDate, todayDate) ||
        (todayDate.difference(startDate).inDays).abs() == 0 &&
            (startWeight - todayWeight).abs() < 0.01;
    final effectiveStartWeight = sameDay ? todayWeight : startWeight;

    final isGain = targetWeight > effectiveStartWeight;
    final usable = maxY - minY;
    final weightDiff = (targetWeight - effectiveStartWeight).abs();
    final normalizedDiff = (weightDiff / 20).clamp(0.0, 1.0); // diff 越大弧度越大
    final normalizedDays = (days / 120).clamp(0.0, 1.0); // 天数越长弧度略大

    final baseStart = isGain ? 0.62 : 0.38;
    final baseEnd = isGain ? 0.38 : 0.62;
    final delta = 0.08 + 0.08 * normalizedDiff - 0.05 * normalizedDays;

    final startY =
        minY +
        usable * (baseStart + (isGain ? delta : -delta)).clamp(0.25, 0.75);
    final endY =
        minY + usable * (baseEnd - (isGain ? delta : -delta)).clamp(0.25, 0.75);

    // Create smooth curve path
    final path = Path();
    path.moveTo(startX, startY);

    final cp1X = startX + (endX - startX) * 0.32;
    final cp2X = startX + (endX - startX) * 0.68;
    // 差越大、天数越长弯曲越明显，但收敛至安全范围
    final bendFactor = 0.12 + 0.16 * normalizedDiff + 0.06 * normalizedDays;
    final bend = (endY - startY) * bendFactor;
    final cp1Y = (startY + bend).clamp(minY + 12, maxY - 12);
    final cp2Y = (endY - bend).clamp(minY + 12, maxY - 12);

    path.cubicTo(cp1X, cp1Y, cp2X, cp2Y, endX, endY);

    // Always draw a faint base curve to keep visible even at progress 0
    final basePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..colorFilter = ColorFilter.mode(
        Colors.white.withOpacity(isDark ? 0.25 : 0.35),
        BlendMode.srcATop,
      );
    canvas.drawPath(path, basePaint);

    // Draw full curve with gradient (no animation)
    final curvePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, curvePaint);

    // Draw dots and labels
    // 起点
    if (!sameDay) {
      _drawPoint(
        canvas,
        Offset(startX, startY),
        rainbowColors.first,
        '起点',
        '${startWeight.toStringAsFixed(1)} kg',
        size,
      );
    }

    // 进度点（今天）
    final progress = () {
      if (startDate != null && todayDate != null && days > 0) {
        final elapsed = todayDate.difference(startDate).inDays;
        return (elapsed / days).clamp(0.0, 1.0);
      }
      return 0.5;
    }();
    final currentPoint = _pointOnCubic(
      startX,
      startY,
      cp1X,
      cp1Y,
      cp2X,
      cp2Y,
      endX,
      endY,
      progress,
    );
    final currentColor = rainbowColors[
        (progress * (rainbowColors.length - 1)).clamp(0, rainbowColors.length - 1).toInt()];
    _drawPoint(
      canvas,
      currentPoint,
      currentColor,
      '今天',
      '${todayWeight.toStringAsFixed(1)} kg',
      size,
    );

    // 目标
    _drawPoint(
      canvas,
      Offset(endX, endY),
      rainbowColors.last,
      '目标',
      '${targetWeight.toStringAsFixed(1)} kg',
      size,
    );
  }

  void _drawPoint(
    Canvas canvas,
    Offset point,
    Color color,
    String label,
    String value,
    Size size,
  ) {
    // Draw outer glow circle
    final glowPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 12, glowPaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 8, borderPaint);

    // Draw colored center
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 5, centerPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Label text
    textPainter.text = TextSpan(
      text: label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF666666),
      ),
    );
    textPainter.layout();
    final labelY = (point.dy - 28).clamp(6.0, size.height - 18);
    textPainter.paint(canvas, Offset(point.dx - textPainter.width / 2, labelY));

    // Value text
    textPainter.text = TextSpan(
      text: value,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
    textPainter.layout();
    final valueY = (point.dy - 45).clamp(6.0, size.height - 18);
    textPainter.paint(canvas, Offset(point.dx - textPainter.width / 2, valueY));
  }

  Offset _pointOnCubic(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
    double t,
  ) {
    final mt = 1 - t;
    final mt2 = mt * mt;
    final t2 = t * t;
    final a = mt2 * mt;
    final b = 3 * mt2 * t;
    final c = 3 * mt * t2;
    final d = t * t2;
    final x = a * x0 + b * x1 + c * x2 + d * x3;
    final y = a * y0 + b * y1 + c * y2 + d * y3;
    return Offset(x, y);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  bool shouldRepaint(_WeightCurvePainter old) {
    return old.currentWeight != currentWeight ||
        old.targetWeight != targetWeight ||
        old.mode != mode;
  }
}

class _HomeChatPreview extends StatelessWidget {
  const _HomeChatPreview({
    required this.intro,
    required this.suggestions,
    required this.showHint,
    required this.hintText,
    required this.onTap,
  });

  final String intro;
  final List<String> suggestions;
  final bool showHint;
  final String hintText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final accent = app.accentBlue;
    final darkText = app.textPrimary;
    final softText = app.textSecondary;
    final shadowOpacity = context.isDarkMode ? 0.35 : 0.16;

    return Container(
      decoration: BoxDecoration(
        color: app.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: app.border),
        boxShadow: [
          BoxShadow(
            color: app.shadow.withOpacity(shadowOpacity),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.08, 0.1),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: showHint
                      ? _ChatbotHintBubble(
                          key: ValueKey(hintText),
                          text: hintText,
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: app.cardAlt,
                    boxShadow: [
                      BoxShadow(
                        color: app.shadow.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Lottie.asset(
                      'images/bearded_coach.json',
                      fit: BoxFit.cover,
                      repeat: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 120, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '大胡子营养师',
                      style: GoogleFonts.inter(
                        color: darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '在线',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF15803D),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios, size: 12, color: softText),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onTap,
                  child: _ChatPreviewBubble(text: intro),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: suggestions
                        .map(
                          (text) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _ChatSuggestionChip(
                              label: text,
                              onTap: onTap,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _ChatInputPreview(onTap: onTap)),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPreviewBubble extends StatelessWidget {
  const _ChatPreviewBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final isDark = context.isDarkMode;
    final lightBubble = const Color(0xFFE8F1FF);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? null : lightBubble,
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E7BFF), Color(0xFF0F5BD6)],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E7BFF).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : app.textPrimary,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Positioned(
          left: 18,
          bottom: -6,
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E7BFF) : lightBubble,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatSuggestionChip extends StatelessWidget {
  const _ChatSuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: app.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: app.border),
          boxShadow: [
            BoxShadow(
              color: app.shadow.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: app.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: app.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputPreview extends StatelessWidget {
  const _ChatInputPreview({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: app.backgroundAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: app.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '问任何问题',
                style: GoogleFonts.inter(
                  color: app.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.photo_camera_outlined,
              size: 18,
              color: app.textSecondary,
            ),
            const SizedBox(width: 8),
            Icon(Icons.image_outlined, size: 18, color: app.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _QuickModeCard extends StatelessWidget {
  const _QuickModeCard({
    required this.icon,
    required this.label,
    required this.imageUrl,
  });

  final IconData icon;
  final String label;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF13EC5B);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(child: Image.network(imageUrl, fit: BoxFit.cover)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.2),
                  ],
                ),
              ),
            ),
          ),
          Positioned(left: 12, top: 12, child: Icon(icon, color: primary)),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({
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
    final primary = app.primary;
    return Container(
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
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primary),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
          Icon(Icons.chevron_right, color: app.textTertiary),
        ],
      ),
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  const _BottomTabItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final color = active ? app.primary : app.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: active ? 14 : 6,
          height: 2,
          decoration: BoxDecoration(
            color: active ? app.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _ScanOptionTile extends StatelessWidget {
  const _ScanOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: app.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: app.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: app.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: app.primary),
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
                      fontSize: 15,
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
            Icon(Icons.chevron_right, color: app.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ScanBubbleOption extends StatelessWidget {
  const _ScanBubbleOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bubbleColor,
    required this.accentColor,
    required this.tailLeft,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color bubbleColor;
  final Color accentColor;
  final bool tailLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: app.border),
              boxShadow: [
                BoxShadow(
                  color: app.shadow.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: app.textPrimary,
                    fontSize: 15,
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
          Positioned(
            bottom: -6,
            left: tailLeft ? 18 : null,
            right: tailLeft ? null : 18,
            child: Transform.rotate(
              angle: pi / 4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomScanItem extends StatelessWidget {
  const _BottomScanItem({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF20C863),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x6620C863),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(
                'images/panda_camera.svg',
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
