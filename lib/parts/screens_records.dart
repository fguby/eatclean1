part of '../main.dart';

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Container(
      color: app.background,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: app.card,
              shape: BoxShape.circle,
              border: Border.all(color: app.border),
            ),
            child: Icon(icon, color: app.textSecondary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: app.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: app.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsTab extends StatelessWidget {
  const _RecordsTab({required this.onReviewTap, required this.onActionTap});

  final void Function({String? focusRecordId}) onReviewTap;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return AnimatedBuilder(
      animation: MealStore.instance,
      builder: (context, child) {
        final store = MealStore.instance;
        if (!store.isLoaded) {
          return Center(child: CircularProgressIndicator(color: app.primary));
        }
        final records = store.records;
        if (records.isEmpty) {
          return const _EmptyRecordsState();
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16 + MediaQuery.of(context).padding.top,
            16,
            120,
          ),
          children: [
            Row(
              children: [
                Text(
                  '用餐记录',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: app.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: app.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: app.border),
                  ),
                  child: Text(
                    '${records.length} 餐',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: app.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DailyIntakeChartCard(intake: store.dailyIntake),
            const SizedBox(height: 16),
            ...records.map(
              (record) => _MealRecordCard(
                record: record,
                onReviewTap: () => onReviewTap(focusRecordId: record.id),
                onActionTap: onActionTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DailyIntakeChartCard extends StatelessWidget {
  const _DailyIntakeChartCard({required this.intake});

  final Map<String, DailyIntake> intake;

  List<DateTime> _buildDays() {
    final today = DateTime.now();
    return List.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));
      return DateTime(date.year, date.month, date.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final primary = app.primary;
    final days = _buildDays();
    final values = days.map((date) {
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return intake[key]?.calories ?? 0;
    }).toList();
    final maxValue = values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    final displayMax = maxValue == 0 ? 1 : maxValue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: app.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: app.border),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '每日摄入趋势',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: app.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '近 7 天',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: app.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _DailyIntakeChartPainter(
                values: values,
                maxValue: displayMax,
                lineColor: primary,
              ),
              child: Container(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((date) {
              return Text(
                '${date.month}/${date.day}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: app.textSecondary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DailyIntakeChartPainter extends CustomPainter {
  _DailyIntakeChartPainter({
    required this.values,
    required this.maxValue,
    required this.lineColor,
  });

  final List<int> values;
  final int maxValue;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paintLine = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.35), lineColor.withOpacity(0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    final paintDot = Paint()..color = lineColor.withOpacity(0.9);
    final textStyle = TextStyle(
      color: lineColor.withOpacity(0.95),
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );

    final stepX = values.length <= 1
        ? size.width
        : size.width / (values.length - 1);
    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = stepX * i;
      final y =
          size.height - (values[i].clamp(0, maxValue) / maxValue) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);

    for (var i = 0; i < values.length; i++) {
      final x = stepX * i;
      final y =
          size.height - (values[i].clamp(0, maxValue) / maxValue) * size.height;
      canvas.drawCircle(Offset(x, y), 3.2, paintDot);

      final label = values[i].toString();
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      var dx = x - textPainter.width / 2;
      dx = dx.clamp(0.0, size.width - textPainter.width);
      var dy = y - textPainter.height - 6;
      if (dy < 0) {
        dy = y + 6;
      }
      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _DailyIntakeChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.maxValue != maxValue;
  }
}

class _EmptyRecordsState extends StatelessWidget {
  const _EmptyRecordsState();

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: app.card,
                shape: BoxShape.circle,
                border: Border.all(color: app.border),
              ),
              child: Icon(Icons.insights, color: app.textSecondary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有用餐记录',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: app.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '完成扫描并选择菜品后，将自动生成记录。',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: app.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealRecordCard extends StatelessWidget {
  const _MealRecordCard({
    required this.record,
    required this.onReviewTap,
    required this.onActionTap,
  });

  final MealRecord record;
  final VoidCallback onReviewTap;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final isComplete = record.isComplete;
    final statusColor = isComplete
        ? const Color(0xFF13EC5B)
        : const Color(0xFFF59E0B);
    final dishes = List<MealDish>.from(record.dishes)
      ..sort((a, b) => b.score.compareTo(a.score));
    final actions = _extractActionIds(record.summary);
    final summaryText = actions.isNotEmpty
        ? _stripActionTokens(record.summary)
        : record.summary;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: app.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: app.border),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本次用餐',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: app.textPrimary,
                ),
              ),
              const Spacer(),
              _StatusChip(
                label: isComplete ? '已评价' : '待评价',
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatMealDateTime(record.createdAt),
            style: GoogleFonts.inter(fontSize: 12, color: app.textSecondary),
          ),
          const SizedBox(height: 12),
          Column(
            children: dishes
                .map(
                  (dish) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MealDishSummaryTile(dish: dish),
                  ),
                )
                .toList(),
          ),
          if (summaryText.trim().isNotEmpty || actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: app.cardAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: app.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '大胡子建议',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: app.textPrimary,
                          ),
                        ),
                        if (summaryText.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            summaryText.trim(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: app.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (actions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: actions.map((action) {
                              return OutlinedButton.icon(
                                onPressed: () => onActionTap(action),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: statusColor,
                                  side: BorderSide(
                                    color: statusColor.withOpacity(0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  textStyle: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                icon: Icon(_actionIcon(action), size: 14),
                                label: Text(_actionLabel(action)),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '总热量 ${record.totalKcal} 千卡',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: app.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '已评价 ${record.ratedCount}/${record.dishes.length}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: app.textSecondary,
                ),
              ),
              if (!isComplete) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onReviewTap,
                  style: TextButton.styleFrom(foregroundColor: statusColor),
                  child: const Text('去评价'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MealDishSummaryTile extends StatelessWidget {
  const _MealDishSummaryTile({required this.dish});

  final MealDish dish;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final tone = dish.recommended ? dish.scoreColor : const Color(0xFFF59E0B);
    final components = dish.components;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: app.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: app.border),
        boxShadow: [
          BoxShadow(
            color: tone.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tone.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  dish.recommended
                      ? Icons.thumb_up_alt_rounded
                      : Icons.warning_amber_rounded,
                  color: tone,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: app.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dish.restaurant,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: app.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${dish.score}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone,
                    ),
                  ),
                  Text(
                    dish.scoreLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: tone,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _NutritionChip(label: '${dish.kcal} 千卡'),
              _NutritionChip(label: '蛋白 ${dish.protein}g'),
              _NutritionChip(label: '碳水 ${dish.carbs}g'),
              _NutritionChip(label: '脂肪 ${dish.fat}g'),
            ],
          ),
          if (components.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: components
                  .take(6)
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: app.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: app.border),
                      ),
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: app.textSecondary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else if (dish.tag.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tone.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tone.withOpacity(0.4)),
              ),
              child: Text(
                dish.tag,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AnimatedBellButton extends StatefulWidget {
  const _AnimatedBellButton({required this.onTap, required this.active});

  final VoidCallback onTap;
  final bool active;

  @override
  State<_AnimatedBellButton> createState() => _AnimatedBellButtonState();
}

class _AnimatedBellButtonState extends State<_AnimatedBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedBellButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
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
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double angle = widget.active
              ? sin(_controller.value * 2 * pi) * 0.18
              : 0.0;
          return Transform.rotate(angle: angle, child: child);
        },
        child: Stack(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: app.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: app.border),
              ),
              child: Icon(Icons.notifications, color: app.textPrimary),
            ),
            if (widget.active)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingReviewSheet extends StatelessWidget {
  const _PendingReviewSheet({this.focusRecordId});

  final String? focusRecordId;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return AnimatedBuilder(
      animation: MealStore.instance,
      builder: (context, child) {
        final pending = MealStore.instance.pendingRecords;
        final initialSize = pending.isEmpty ? 0.45 : 0.85;
        return DraggableScrollableSheet(
          initialChildSize: initialSize,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: app.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: app.border),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                  const SizedBox(height: 12),
                  Text(
                    '未完成评价',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: app.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '为每一餐的菜品打分，帮助系统持续优化推荐。',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: app.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (pending.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: app.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: app.border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, color: app.primary),
                          const SizedBox(height: 8),
                          Text(
                            '已完成所有评价',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: app.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...pending.map(
                      (record) => _MealReviewCard(
                        record: record,
                        highlight: record.id == focusRecordId,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MealReviewCard extends StatelessWidget {
  const _MealReviewCard({required this.record, this.highlight = false});

  final MealRecord record;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    const caution = Color(0xFFF59E0B);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: app.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight ? caution.withOpacity(0.6) : app.border,
        ),
        boxShadow: [
          if (highlight)
            BoxShadow(
              color: caution.withOpacity(0.2),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatMealDateTime(record.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: app.textSecondary,
                ),
              ),
              const Spacer(),
              const _StatusChip(label: '待评价', color: caution),
            ],
          ),
          if (record.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: app.cardAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: app.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: caution.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: caution,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      record.summary.trim(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: app.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...record.dishes.map(
            (dish) => _DishRatingRow(
              dish: dish,
              rating: record.ratings[dish.id] ?? 0,
              onRatingChanged: (value) {
                MealStore.instance.updateRecord(
                  record.withRating(dish.id, value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DishRatingRow extends StatelessWidget {
  const _DishRatingRow({
    required this.dish,
    required this.rating,
    required this.onRatingChanged,
  });

  final MealDish dish;
  final int rating;
  final ValueChanged<int> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final tone = dish.recommended ? dish.scoreColor : const Color(0xFFF59E0B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: app.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dish.tag,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: app.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _StarRating(rating: rating, color: tone, onChanged: onRatingChanged),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({
    required this.rating,
    required this.onChanged,
    required this.color,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final isActive = index < rating;
        return GestureDetector(
          onTap: () => onChanged(index + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              isActive ? Icons.star_rounded : Icons.star_border_rounded,
              color: isActive ? color : app.border,
              size: 18,
            ),
          ),
        );
      }),
    );
  }
}
