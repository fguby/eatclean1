part of '../main.dart';

class MealDish {
  const MealDish({
    required this.id,
    required this.name,
    required this.restaurant,
    required this.score,
    required this.scoreLabel,
    required this.scoreColor,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.tag,
    required this.recommended,
    this.components = const [],
    this.reason = '',
  });

  final String id;
  final String name;
  final String restaurant;
  final int score;
  final String scoreLabel;
  final Color scoreColor;
  final int kcal;
  final int protein;
  final int carbs;
  final int fat;
  final String tag;
  final bool recommended;
  final List<String> components;
  final String reason;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'restaurant': restaurant,
        'score': score,
        'scoreLabel': scoreLabel,
        'scoreColor': _colorToHex(scoreColor),
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'tag': tag,
        'recommended': recommended,
        'components': components,
        'reason': reason,
      };

  factory MealDish.fromJson(Map<String, dynamic> json) {
    return MealDish(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      restaurant: json['restaurant'] as String? ?? '',
      score: (json['score'] as num? ?? 0).toInt(),
      scoreLabel: json['scoreLabel'] as String? ?? '',
      scoreColor: _colorFromHex(json['scoreColor'] as String? ?? 'ff13ec5b'),
      kcal: (json['kcal'] as num? ?? 0).toInt(),
      protein: (json['protein'] as num? ?? 0).toInt(),
      carbs: (json['carbs'] as num? ?? 0).toInt(),
      fat: (json['fat'] as num? ?? 0).toInt(),
      tag: json['tag'] as String? ?? '',
      recommended: json['recommended'] as bool? ?? true,
      components:
          _readStringListFromJson(json['components'] ?? json['ingredients']),
      reason: json['reason'] as String? ?? '',
    );
  }
}

class MealRecord {
  MealRecord({
    required this.id,
    required this.createdAt,
    required this.dishes,
    this.summary = '',
    Map<String, int>? ratings,
  }) : ratings = ratings ?? {};

  final String id;
  final DateTime createdAt;
  final List<MealDish> dishes;
  final String summary;
  final Map<String, int> ratings;

  int get totalKcal => dishes.fold(0, (total, dish) => total + dish.kcal);

  int get ratedCount => ratings.values.where((value) => value > 0).length;

  bool get isComplete => dishes.isEmpty || ratedCount >= dishes.length;

  MealRecord copyWith({Map<String, int>? ratings}) {
    return MealRecord(
      id: id,
      createdAt: createdAt,
      dishes: dishes,
      summary: summary,
      ratings: ratings ?? this.ratings,
    );
  }

  MealRecord withRating(String dishId, int rating) {
    final updatedRatings = Map<String, int>.from(ratings);
    updatedRatings[dishId] = rating;
    return copyWith(ratings: updatedRatings);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'dishes': dishes.map((dish) => dish.toJson()).toList(),
        'summary': summary,
        'ratings': ratings,
      };

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    final rawDishes = json['dishes'] ?? json['items'] ?? [];
    final dishes = (rawDishes as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MealDish.fromJson)
        .toList();
    final rawRatings = json['ratings'] as Map<String, dynamic>? ?? {};
    final ratings = <String, int>{};
    for (final entry in rawRatings.entries) {
      ratings[entry.key] = (entry.value as num? ?? 0).toInt();
    }
    final rawId = json['id'];
    final id = rawId is String ? rawId : rawId?.toString() ?? '';
    final createdRaw =
        json['createdAt'] ?? json['recorded_at'] ?? json['created_at'];
    final summary = _extractSummary(json);
    return MealRecord(
      id: id,
      createdAt: DateTime.tryParse(createdRaw?.toString() ?? '') ??
          DateTime.now(),
      dishes: dishes,
      summary: summary,
      ratings: ratings,
    );
  }
}

class DailyIntake {
  DailyIntake({
    required this.date,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  final String date;
  int calories;
  int protein;
  int carbs;
  int fat;

  Map<String, dynamic> toJson() => {
        'date': date,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory DailyIntake.fromJson(Map<String, dynamic> json) {
    return DailyIntake(
      date: json['date'] as String? ?? '',
      calories: (json['calories'] as num? ?? 0).toInt(),
      protein: (json['protein'] as num? ?? 0).toInt(),
      carbs: (json['carbs'] as num? ?? 0).toInt(),
      fat: (json['fat'] as num? ?? 0).toInt(),
    );
  }
}

