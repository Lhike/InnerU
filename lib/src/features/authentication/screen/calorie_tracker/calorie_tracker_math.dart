class CalorieFoodPreset {
  const CalorieFoodPreset({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.aliases,
    required this.defaultUnit,
    required this.gramsPerUnit,
  });

  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final List<String> aliases;
  final String defaultUnit;
  final double gramsPerUnit;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    return name.toLowerCase() == normalized ||
        aliases.any((alias) => alias.toLowerCase() == normalized);
  }
}

class CalorieFoodAmount {
  const CalorieFoodAmount({
    required this.displayName,
    required this.quantityLabel,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String displayName;
  final String quantityLabel;
  final String unit;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
}

class CalorieTrackerMath {
  const CalorieTrackerMath._();

  /// Returns the Atwater estimate for the supplied macronutrients.
  static int caloriesFromMacros({
    required int protein,
    required int carbs,
    required int fat,
  }) {
    return (protein * 4 + carbs * 4 + fat * 9).round();
  }

  /// Nutrition labels can differ slightly because of fibre, sugar alcohols,
  /// rounding, and database conventions. Keep a generous but useful sanity
  /// range instead of rejecting otherwise valid labelled food.
  static bool isCaloriesConsistent({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    double tolerance = 0.20,
  }) {
    if (calories <= 0 || protein < 0 || carbs < 0 || fat < 0) return false;
    final estimated = caloriesFromMacros(
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    final allowedDifference = (calories * tolerance).round().clamp(35, 120);
    return (calories - estimated).abs() <= allowedDifference;
  }

  /// Reads numbers that may arrive as strings with units, e.g. "250 kcal",
  /// "12,5 g" or "~300".
  static double? parseLooseNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is! String) return null;
    final match = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  /// Stable key for saving a food, keeping non-English letters.
  static String foodMemoryKey(String name) {
    final key = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return key.length > 120 ? key.substring(0, 120) : key;
  }

  /// A gentle check that typed macros roughly match the calories. Returns a
  /// warning to show, never a reason to block saving: alcohol, fibre and
  /// sugar alcohols legitimately break the 4/4/9 rule.
  static String? macroWarning({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
  }) {
    if (calories <= 0 || protein + carbs + fat <= 0) return null;
    final estimated =
        caloriesFromMacros(protein: protein, carbs: carbs, fat: fat);
    final allowance = (calories * 0.20).round().clamp(35, 120);
    if (estimated > calories + allowance) {
      return 'The macros add up to about $estimated kcal, more than the $calories kcal entered.';
    }
    final allMacrosEntered = protein > 0 && carbs > 0 && fat > 0;
    if (allMacrosEntered && estimated < calories - allowance) {
      return 'The macros only add up to about $estimated kcal. Fine for drinks with alcohol, otherwise double-check.';
    }
    return null;
  }

  static String normalizeMeasurementUnit(String rawUnit) {
    final normalized = rawUnit.trim().toLowerCase();
    if (normalized.isEmpty) return 'piece';
    if (normalized == 'grams' || normalized == 'gram') return 'g';
    if (normalized == 'kilograms' || normalized == 'kilogram') return 'kg';
    if (normalized == 'ounces' || normalized == 'ounce') return 'oz';
    if (normalized == 'pounds' || normalized == 'pound') return 'lb';
    if (normalized == 'milliliters' || normalized == 'milliliter') return 'ml';
    if (normalized == 'liters' ||
        normalized == 'liter' ||
        normalized == 'litres' ||
        normalized == 'litre') {
      return 'liter';
    }
    if (normalized == 'cups') return 'cup';
    if (normalized == 'tablespoons' || normalized == 'tablespoon') {
      return 'tbsp';
    }
    if (normalized == 'teaspoons' || normalized == 'teaspoon') return 'tsp';
    if (normalized == 'slices') return 'slice';
    if (normalized == 'pieces' || normalized == 'pcs' || normalized == 'pc') {
      return 'piece';
    }
    if (normalized == 'mg' ||
        normalized == 'milligram' ||
        normalized == 'milligrams') {
      return 'mg';
    }
    // Amount-prefixed preset units such as "100g" or "250ml".
    if (RegExp(r'^\d*\.?\d*ml$').hasMatch(normalized)) return 'ml';
    if (RegExp(r'^\d*\.?\d*g$').hasMatch(normalized)) return 'g';
    return normalized;
  }

  static CalorieFoodPreset? findPresetFood(
    String query,
    Iterable<CalorieFoodPreset> presets,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final preset in presets) {
      if (preset.matches(normalized)) return preset;
    }
    return null;
  }

  static double measurementMultiplier({
    required String unit,
    required double quantity,
    required CalorieFoodPreset preset,
  }) {
    switch (normalizeMeasurementUnit(unit)) {
      case 'g':
        return quantity / preset.gramsPerUnit;
      case 'kg':
        return (quantity * 1000) / preset.gramsPerUnit;
      case 'oz':
        return (quantity * 28.3495) / preset.gramsPerUnit;
      case 'lb':
        return (quantity * 453.592) / preset.gramsPerUnit;
      case 'ml':
        return quantity / preset.gramsPerUnit;
      case 'liter':
        return (quantity * 1000) / preset.gramsPerUnit;
      case 'cup':
        return quantity *
            (preset.defaultUnit == 'cup' ? 1 : 240 / preset.gramsPerUnit);
      case 'tbsp':
        return quantity *
            (preset.defaultUnit == 'tbsp' ? 1 : 15 / preset.gramsPerUnit);
      case 'tsp':
        return quantity *
            (preset.defaultUnit == 'tsp' ? 1 : 5 / preset.gramsPerUnit);
      case 'slice':
        return quantity *
            (preset.defaultUnit == 'slice' ? 1 : 30 / preset.gramsPerUnit);
      case 'serving':
      case 'piece':
      default:
        return quantity;
    }
  }

  static CalorieFoodAmount? calculateFromMeasurement({
    required String mealName,
    required double quantity,
    required String unit,
    required Iterable<CalorieFoodPreset> presets,
  }) {
    final preset = findPresetFood(mealName, presets);
    if (preset == null || quantity <= 0) return null;

    final normalizedUnit = normalizeMeasurementUnit(unit);
    final multiplier = measurementMultiplier(
      unit: normalizedUnit,
      quantity: quantity,
      preset: preset,
    );
    final quantityLabel = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1);

    return CalorieFoodAmount(
      displayName: '$quantityLabel $normalizedUnit ${preset.name}',
      quantityLabel: quantityLabel,
      unit: normalizedUnit,
      calories: (preset.calories * multiplier).round(),
      protein: (preset.protein * multiplier).round(),
      carbs: (preset.carbs * multiplier).round(),
      fat: (preset.fat * multiplier).round(),
    );
  }

  static CalorieFoodAmount? calculateFoodAmount({
    required String query,
    required Iterable<CalorieFoodPreset> presets,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final parts = normalized.split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;

    final firstTokenMatch =
        RegExp(r'^(\d+(?:\.\d+)?)([a-zA-Z]+)?$').firstMatch(parts.first);
    final quantity = firstTokenMatch == null
        ? double.tryParse(parts.first)
        : double.tryParse(firstTokenMatch.group(1)!);
    if (quantity == null) return null;

    final inlineUnit = firstTokenMatch?.group(2)?.toLowerCase() ?? '';
    final remaining = parts.skip(1).join(' ').trim();
    if (remaining.isEmpty) return null;

    final unitMatchers = <String>[
      'milliliters',
      'milliliter',
      'ml',
      'slices',
      'slice',
      'tablespoons',
      'tablespoon',
      'tbsp',
      'teaspoons',
      'teaspoon',
      'tsp',
      'grams',
      'gram',
      'g',
      'cups',
      'cup',
      'pieces',
      'piece',
      'pcs',
      'pc',
    ];

    String unit = inlineUnit;
    String foodName = remaining;

    if (unit.isEmpty) {
      for (final matcher in unitMatchers) {
        if (remaining.startsWith('$matcher ')) {
          unit = matcher;
          foodName = remaining.substring(matcher.length).trim();
          break;
        }
      }
    }

    if (foodName.isEmpty) return null;

    final preset = findPresetFood(foodName, presets);
    if (preset == null) return null;

    final normalizedUnit = unit.isEmpty ? preset.defaultUnit : unit;
    double multiplier;

    if (normalizedUnit == 'g' ||
        normalizedUnit == 'gram' ||
        normalizedUnit == 'grams' ||
        normalizedUnit == 'ml' ||
        normalizedUnit == 'milliliter' ||
        normalizedUnit == 'milliliters') {
      multiplier = quantity / preset.gramsPerUnit;
    } else if (normalizedUnit == 'cup' || normalizedUnit == 'cups') {
      if (preset.defaultUnit != 'cup') return null;
      multiplier = quantity;
    } else if (normalizedUnit == 'slice' || normalizedUnit == 'slices') {
      if (preset.defaultUnit != 'slice') return null;
      multiplier = quantity;
    } else if (normalizedUnit == 'tbsp' ||
        normalizedUnit == 'tablespoon' ||
        normalizedUnit == 'tablespoons') {
      if (preset.defaultUnit != 'tbsp') return null;
      multiplier = quantity;
    } else if (normalizedUnit == 'tsp' ||
        normalizedUnit == 'teaspoon' ||
        normalizedUnit == 'teaspoons') {
      if (preset.defaultUnit != 'tsp') return null;
      multiplier = quantity;
    } else {
      multiplier = quantity;
    }

    final quantityLabel = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();

    return CalorieFoodAmount(
      displayName:
          '$quantityLabel ${unit.isEmpty ? preset.defaultUnit : unit} ${preset.name}',
      quantityLabel: quantityLabel,
      unit: normalizeMeasurementUnit(unit.isEmpty ? preset.defaultUnit : unit),
      calories: (preset.calories * multiplier).round(),
      protein: (preset.protein * multiplier).round(),
      carbs: (preset.carbs * multiplier).round(),
      fat: (preset.fat * multiplier).round(),
    );
  }
}

/// Calories and macros as doubles, so scaling and summing keep precision
/// until the final display/storage rounding.
class NutritionValues {
  const NutritionValues({
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  NutritionValues operator *(double factor) => NutritionValues(
        calories: calories * factor,
        protein: protein * factor,
        carbs: carbs * factor,
        fat: fat * factor,
      );

  int get roundedCalories => calories.round();
  int get roundedProtein => protein.round();
  int get roundedCarbs => carbs.round();
  int get roundedFat => fat.round();
}

/// What a food's nutrition is measured against: one serving
/// ([servingQuantity] of [servingUnit], e.g. 1 piece, 1 cup, 100 g) and,
/// when known, its weight and per-100 g values. Any portion the user picks
/// is scaled from here, whatever the source (preset, database, barcode,
/// saved food or AI estimate).
class FoodNutritionBasis {
  FoodNutritionBasis({
    required this.name,
    required this.perServing,
    this.servingQuantity = 1,
    String servingUnit = 'serving',
    this.gramsPerServing,
    this.per100g,
    this.sourceLabel,
  })  : servingUnit = CalorieTrackerMath.normalizeMeasurementUnit(servingUnit),
        assert(servingQuantity > 0);

  final String name;
  final NutritionValues perServing;
  final double servingQuantity;
  final String servingUnit;
  final double? gramsPerServing;
  final NutritionValues? per100g;
  final String? sourceLabel;

  static const _gramsPerUnit = <String, double>{
    'mg': 0.001,
    'g': 1,
    'kg': 1000,
    'oz': 28.3495,
    'lb': 453.592,
    // Volumes assume water density; close enough for drinks and soups.
    'ml': 1,
    'liter': 1000,
  };

  static bool isWeightOrVolume(String unit) => _gramsPerUnit
      .containsKey(CalorieTrackerMath.normalizeMeasurementUnit(unit));

  /// Grams in one serving, from an explicit weight or a weight-based unit.
  double? get servingGrams {
    if (gramsPerServing != null && gramsPerServing! > 0) return gramsPerServing;
    final factor = _gramsPerUnit[servingUnit];
    return factor == null ? null : servingQuantity * factor;
  }

  NutritionValues? get _nutritionPer100g {
    if (per100g != null) return per100g;
    final grams = servingGrams;
    if (grams == null || grams <= 0) return null;
    return perServing * (100 / grams);
  }

  /// Units this food can be measured in.
  List<String> get supportedUnits {
    final units = <String>[servingUnit];
    if (servingUnit != 'serving') units.add('serving');
    if (_nutritionPer100g != null) {
      for (final unit in const ['g', 'kg', 'oz', 'lb', 'ml']) {
        if (!units.contains(unit)) units.add(unit);
      }
    }
    return units;
  }

  /// Nutrition for [quantity] of [unit], or null when the unit can't be
  /// converted (e.g. grams of a food with no known weight).
  NutritionValues? scaled(double quantity, String unit) {
    if (quantity <= 0) return null;
    final normalized = CalorieTrackerMath.normalizeMeasurementUnit(unit);

    if (normalized == servingUnit) {
      return perServing * (quantity / servingQuantity);
    }
    if (normalized == 'serving') {
      return perServing * quantity;
    }
    final gramsFactor = _gramsPerUnit[normalized];
    if (gramsFactor != null) {
      final per100 = _nutritionPer100g;
      if (per100 == null) return null;
      return per100 * (quantity * gramsFactor / 100);
    }
    return null;
  }

  FoodNutritionBasis copyWith({String? name, String? sourceLabel}) =>
      FoodNutritionBasis(
        name: name ?? this.name,
        perServing: perServing,
        servingQuantity: servingQuantity,
        servingUnit: servingUnit,
        gramsPerServing: gramsPerServing,
        per100g: per100g,
        sourceLabel: sourceLabel ?? this.sourceLabel,
      );

  factory FoodNutritionBasis.fromPreset(
    CalorieFoodPreset preset, {
    String? sourceLabel,
  }) {
    final rawUnit = preset.defaultUnit.trim().toLowerCase();
    final amount = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-z]+)$').firstMatch(rawUnit);
    return FoodNutritionBasis(
      name: preset.name,
      perServing: NutritionValues(
        calories: preset.calories.toDouble(),
        protein: preset.protein.toDouble(),
        carbs: preset.carbs.toDouble(),
        fat: preset.fat.toDouble(),
      ),
      servingQuantity: amount == null ? 1 : double.parse(amount.group(1)!),
      servingUnit: amount == null ? rawUnit : amount.group(2)!,
      gramsPerServing: preset.gramsPerUnit,
      sourceLabel: sourceLabel,
    );
  }

  /// Parses an Open Food Facts product. Handles per-serving and per-100 g
  /// values separately (never mixing them) and falls back to kJ when kcal
  /// is missing. Returns null when there is no usable energy value.
  static FoodNutritionBasis? fromOpenFoodFacts(Map<String, dynamic> product) {
    final nutriments = product['nutriments'];
    if (nutriments is! Map) return null;
    final n = nutriments.cast<String, dynamic>();

    NutritionValues? valuesFor(String suffix) {
      final calories = CalorieTrackerMath.parseLooseNumber(
              n['energy-kcal_$suffix']) ??
          _kjToKcal(
              CalorieTrackerMath.parseLooseNumber(n['energy-kj_$suffix'])) ??
          // Plain "energy" is reported in kJ by Open Food Facts.
          _kjToKcal(CalorieTrackerMath.parseLooseNumber(n['energy_$suffix']));
      if (calories == null || calories <= 0) return null;
      return NutritionValues(
        calories: calories,
        protein:
            CalorieTrackerMath.parseLooseNumber(n['proteins_$suffix']) ?? 0,
        carbs:
            CalorieTrackerMath.parseLooseNumber(n['carbohydrates_$suffix']) ??
                0,
        fat: CalorieTrackerMath.parseLooseNumber(n['fat_$suffix']) ?? 0,
      );
    }

    final per100g = valuesFor('100g');
    var perServing = valuesFor('serving');
    final servingGrams = _openFoodFactsServingGrams(product);

    if (perServing == null && per100g != null && servingGrams != null) {
      perServing = per100g * (servingGrams / 100);
    }

    final name = _openFoodFactsName(product);
    if (name.isEmpty) return null;

    if (perServing != null) {
      return FoodNutritionBasis(
        name: name,
        perServing: perServing,
        servingUnit: 'serving',
        gramsPerServing: servingGrams,
        per100g: per100g,
      );
    }
    if (per100g != null) {
      return FoodNutritionBasis(
        name: name,
        perServing: per100g,
        servingQuantity: 100,
        servingUnit: 'g',
        per100g: per100g,
      );
    }
    return null;
  }

  static double? _kjToKcal(double? kj) => kj == null ? null : kj / 4.184;

  static double? _openFoodFactsServingGrams(Map<String, dynamic> product) {
    final quantity =
        CalorieTrackerMath.parseLooseNumber(product['serving_quantity']);
    final quantityUnit =
        product['serving_quantity_unit']?.toString().trim().toLowerCase();
    if (quantity != null && quantity > 0) {
      if (quantityUnit == null ||
          quantityUnit.isEmpty ||
          quantityUnit == 'g' ||
          quantityUnit == 'ml') {
        return quantity;
      }
    }
    final size = product['serving_size']?.toString().toLowerCase() ?? '';
    final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(g|ml)\b').firstMatch(size);
    if (match == null) return null;
    final grams = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    return grams != null && grams > 0 ? grams : null;
  }

  static String _openFoodFactsName(Map<String, dynamic> product) {
    final name = (product['product_name'] ??
            product['product_name_en'] ??
            product['generic_name'] ??
            '')
        .toString()
        .trim();
    final brand = (product['brands'] ?? '').toString().split(',').first.trim();
    if (name.isEmpty) return '';
    if (brand.isEmpty || name.toLowerCase().contains(brand.toLowerCase())) {
      return name;
    }
    return '$brand $name';
  }
}

enum CalorieGoalType {
  lose('lose', 'Lose 0.5 kg/week', -500),
  loseSlow('lose_slow', 'Lose 0.25 kg/week', -250),
  maintain('maintain', 'Maintain weight', 0),
  gainSlow('gain_slow', 'Gain 0.25 kg/week', 250),
  gain('gain', 'Gain 0.5 kg/week', 500);

  const CalorieGoalType(this.apiValue, this.label, this.dailyAdjustment);

  final String apiValue;
  final String label;
  final int dailyAdjustment;

  static CalorieGoalType fromApi(String? value) => values.firstWhere(
        (type) => type.apiValue == value,
        orElse: () => CalorieGoalType.maintain,
      );
}

enum ActivityLevel {
  sedentary('sedentary', 'Sedentary', 'Desk job, little exercise', 1.2),
  light('light', 'Lightly active', 'Exercise 1-3 days/week', 1.375),
  moderate('moderate', 'Moderately active', 'Exercise 3-5 days/week', 1.55),
  active('active', 'Very active', 'Exercise 6-7 days/week', 1.725),
  veryActive('very_active', 'Extra active', 'Physical job or 2x training', 1.9);

  const ActivityLevel(
      this.apiValue, this.label, this.description, this.multiplier);

  final String apiValue;
  final String label;
  final String description;
  final double multiplier;

  static ActivityLevel fromApi(String? value) => values.firstWhere(
        (level) => level.apiValue == value,
        orElse: () => ActivityLevel.sedentary,
      );
}

/// Body stats behind the daily calorie goal.
class CalorieProfile {
  const CalorieProfile({
    required this.isMale,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    this.activityLevel = ActivityLevel.sedentary,
    this.goalType = CalorieGoalType.maintain,
    this.countSteps = true,
  });

  final bool isMale;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;
  final CalorieGoalType goalType;

  /// When true, steps are added back each day, so the base goal uses the
  /// sedentary multiplier to avoid counting walking twice.
  final bool countSteps;

  static const minAge = 13;
  static const maxAge = 100;

  /// Returns a message for the first invalid field, or null.
  String? validate() {
    if (age < minAge || age > maxAge) return 'Age must be $minAge-$maxAge.';
    if (heightCm < 100 || heightCm > 250) return 'Height must be 100-250 cm.';
    if (weightKg < 30 || weightKg > 300) return 'Weight must be 30-300 kg.';
    return null;
  }

  /// Mifflin-St Jeor basal metabolic rate.
  double get bmr =>
      10 * weightKg + 6.25 * heightCm - 5 * age + (isMale ? 5 : -161);

  ActivityLevel get effectiveActivity =>
      countSteps ? ActivityLevel.sedentary : activityLevel;

  double get maintenanceCalories => bmr * effectiveActivity.multiplier;

  /// Lowest goal we suggest without medical supervision.
  int get minimumGoal => isMale ? 1500 : 1200;

  int get dailyGoal {
    final target = maintenanceCalories + goalType.dailyAdjustment;
    final rounded = (target / 10).round() * 10;
    return rounded < minimumGoal ? minimumGoal : rounded;
  }

  bool get goalWasRaisedToMinimum =>
      maintenanceCalories + goalType.dailyAdjustment < minimumGoal;

  Map<String, dynamic> toApi({int? dailyGoalOverride}) => {
        'sex': isMale ? 'male' : 'female',
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'activity_level': activityLevel.apiValue,
        'goal_type': goalType.apiValue,
        'count_steps': countSteps,
        'daily_goal': dailyGoalOverride ?? dailyGoal,
      };

  /// Builds a profile from the API payload; null when body stats are
  /// missing.
  static CalorieProfile? fromApi(Map<String, dynamic>? json) {
    if (json == null) return null;
    final age = CalorieTrackerMath.parseLooseNumber(json['age']);
    final height = CalorieTrackerMath.parseLooseNumber(json['heightCm']);
    final weight = CalorieTrackerMath.parseLooseNumber(json['weightKg']);
    if (age == null || height == null || weight == null) return null;
    return CalorieProfile(
      isMale: json['sex'] != 'female',
      age: age.round(),
      heightCm: height,
      weightKg: weight,
      activityLevel: ActivityLevel.fromApi(json['activityLevel']?.toString()),
      goalType: CalorieGoalType.fromApi(json['goalType']?.toString()),
      countSteps: json['countSteps'] != false,
    );
  }
}

class CalorieActivityMath {
  const CalorieActivityMath._();

  static const defaultWeightKg = 70.0;
  static const defaultStrideMeters = 0.67;

  /// Net walking cost above resting, in kcal per kg per km. Net (not gross)
  /// because resting calories are already in the BMR-based goal.
  static const netKcalPerKgPerKm = 0.4;

  static double strideMeters(double? heightCm) =>
      heightCm == null || heightCm <= 0
          ? defaultStrideMeters
          : heightCm * 0.415 / 100;

  /// Calories burned walking [steps], scaled by body weight and stride.
  static int stepCalories(int steps, {double? weightKg, double? heightCm}) {
    if (steps <= 0) return 0;
    final km = steps * strideMeters(heightCm) / 1000;
    return (netKcalPerKgPerKm * (weightKg ?? defaultWeightKg) * km).round();
  }

  static int? ageFromBirthdate(DateTime? birthdate, DateTime today) {
    if (birthdate == null) return null;
    var age = today.year - birthdate.year;
    if (today.month < birthdate.month ||
        (today.month == birthdate.month && today.day < birthdate.day)) {
      age--;
    }
    return age > 0 ? age : null;
  }

  /// Meal most people would be logging at [time].
  static String mealTypeFor(DateTime time) {
    final minutes = time.hour * 60 + time.minute;
    if (minutes >= 4 * 60 && minutes < 10 * 60 + 30) return 'Breakfast';
    if (minutes >= 10 * 60 + 30 && minutes < 15 * 60) return 'Lunch';
    if (minutes >= 17 * 60 && minutes < 22 * 60) return 'Dinner';
    return 'Snack';
  }
}
