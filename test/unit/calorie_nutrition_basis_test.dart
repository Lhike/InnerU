import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/authentication/screen/calorie_tracker/calorie_tracker_math.dart';

const _chicken = CalorieFoodPreset(
  name: 'Chicken Breast',
  calories: 165,
  protein: 31,
  carbs: 0,
  fat: 4,
  aliases: ['chicken'],
  defaultUnit: '100g',
  gramsPerUnit: 100,
);

const _rice = CalorieFoodPreset(
  name: 'White Rice',
  calories: 205,
  protein: 4,
  carbs: 45,
  fat: 0,
  aliases: ['rice'],
  defaultUnit: 'cup',
  gramsPerUnit: 158,
);

void main() {
  group('FoodNutritionBasis', () {
    test('a preset scales by its own unit, servings and grams', () {
      final rice = FoodNutritionBasis.fromPreset(_rice);
      expect(rice.servingUnit, 'cup');
      expect(rice.scaled(2, 'cup')!.roundedCalories, 410);
      expect(rice.scaled(1.5, 'serving')!.roundedCalories, 308);
      expect(rice.scaled(79, 'g')!.roundedCalories, 103);
      expect(rice.supportedUnits, containsAll(['cup', 'serving', 'g', 'oz']));
    });

    test('an amount-prefixed preset unit like 100g is read as 100 g', () {
      final chicken = FoodNutritionBasis.fromPreset(_chicken);
      expect(chicken.servingQuantity, 100);
      expect(chicken.servingUnit, 'g');
      expect(chicken.scaled(250, 'g')!.roundedCalories, 413);
      expect(chicken.scaled(250, 'g')!.roundedProtein, 78);
      expect(chicken.scaled(0.5, 'kg')!.roundedCalories, 825);
    });

    test('units it cannot convert return null instead of a wrong number', () {
      final burger = FoodNutritionBasis(
        name: 'Burger',
        perServing: const NutritionValues(calories: 550),
      );
      expect(burger.scaled(2, 'serving')!.roundedCalories, 1100);
      expect(burger.scaled(200, 'g'), isNull);
      expect(burger.scaled(1, 'cup'), isNull);
      expect(burger.scaled(0, 'serving'), isNull);
      expect(burger.supportedUnits, ['serving']);
    });

    test('keeps precision until rounding', () {
      final oil = FoodNutritionBasis(
        name: 'Oil',
        perServing: const NutritionValues(calories: 40, fat: 4.5),
        servingUnit: 'tsp',
      );
      expect(oil.scaled(3, 'tsp')!.roundedFat, 14);
    });
  });

  group('Open Food Facts parsing', () {
    test('uses per-serving values and keeps per-100g for gram portions', () {
      final basis = FoodNutritionBasis.fromOpenFoodFacts({
        'product_name': 'Choco Bar',
        'brands': 'Acme, Other',
        'serving_quantity': '40',
        'nutriments': {
          'energy-kcal_serving': 210,
          'proteins_serving': 3,
          'carbohydrates_serving': 25,
          'fat_serving': 11,
          'energy-kcal_100g': 525,
          'proteins_100g': 7.5,
          'carbohydrates_100g': 62.5,
          'fat_100g': 27.5,
        },
      })!;
      expect(basis.name, 'Acme Choco Bar');
      expect(basis.servingUnit, 'serving');
      expect(basis.scaled(2, 'serving')!.roundedCalories, 420);
      expect(basis.scaled(2, 'serving')!.roundedProtein, 6);
      expect(basis.scaled(100, 'g')!.roundedCalories, 525);
    });

    test('derives a serving from per-100g values and the serving size', () {
      final basis = FoodNutritionBasis.fromOpenFoodFacts({
        'product_name': 'Crackers',
        'serving_size': '30 g (6 crackers)',
        'nutriments': {
          'energy-kcal_100g': 450,
          'proteins_100g': 10,
          'carbohydrates_100g': 70,
          'fat_100g': 15,
        },
      })!;
      expect(basis.scaled(1, 'serving')!.roundedCalories, 135);
      expect(basis.scaled(1, 'serving')!.roundedFat, 5);
    });

    test('falls back to 100 g when there is no serving info', () {
      final basis = FoodNutritionBasis.fromOpenFoodFacts({
        'product_name': 'Oats',
        'nutriments': {'energy-kcal_100g': 389, 'proteins_100g': 16.9},
      })!;
      expect(basis.servingQuantity, 100);
      expect(basis.servingUnit, 'g');
      expect(basis.scaled(40, 'g')!.roundedCalories, 156);
    });

    test('converts kJ when kcal is missing', () {
      final basis = FoodNutritionBasis.fromOpenFoodFacts({
        'product_name': 'Juice',
        'nutriments': {'energy_100g': 1046},
      })!;
      expect(basis.per100g!.roundedCalories, 250);

      final kjOnly = FoodNutritionBasis.fromOpenFoodFacts({
        'product_name': 'Water',
        'nutriments': {'energy-kj_serving': '418.4'},
      })!;
      expect(kjOnly.perServing.roundedCalories, 100);
    });

    test('rejects products without a name or energy', () {
      expect(
        FoodNutritionBasis.fromOpenFoodFacts({
          'product_name': 'Mystery',
          'nutriments': {'proteins_100g': 3},
        }),
        isNull,
      );
      expect(
        FoodNutritionBasis.fromOpenFoodFacts({
          'nutriments': {'energy-kcal_100g': 100},
        }),
        isNull,
      );
    });
  });

  group('CalorieProfile', () {
    const base = CalorieProfile(
      isMale: false,
      age: 30,
      heightCm: 160,
      weightKg: 60,
      activityLevel: ActivityLevel.moderate,
    );

    test('uses Mifflin-St Jeor with a sedentary base when steps count', () {
      // 600 + 1000 - 150 - 161 = 1289
      expect(base.bmr, closeTo(1289, 0.01));
      expect(base.dailyGoal, 1550); // 1289 * 1.2
    });

    test('uses the chosen activity level when steps do not count', () {
      const profile = CalorieProfile(
        isMale: false,
        age: 30,
        heightCm: 160,
        weightKg: 60,
        activityLevel: ActivityLevel.moderate,
        countSteps: false,
      );
      expect(profile.dailyGoal, 2000); // 1289 * 1.55 = 1998
    });

    test('applies the weight goal but never goes under the safe minimum', () {
      const losing = CalorieProfile(
        isMale: false,
        age: 30,
        heightCm: 160,
        weightKg: 60,
        goalType: CalorieGoalType.lose,
      );
      expect(losing.dailyGoal, 1200);
      expect(losing.goalWasRaisedToMinimum, isTrue);

      const male = CalorieProfile(
        isMale: true,
        age: 25,
        heightCm: 180,
        weightKg: 80,
        goalType: CalorieGoalType.loseSlow,
      );
      // (800 + 1125 - 125 + 5) * 1.2 - 250 = 1916
      expect(male.dailyGoal, 1920);
    });

    test('validates unrealistic input', () {
      expect(base.validate(), isNull);
      expect(
        const CalorieProfile(
                isMale: true, age: 300, heightCm: 170, weightKg: 70)
            .validate(),
        isNotNull,
      );
      expect(
        const CalorieProfile(isMale: true, age: 30, heightCm: 170, weightKg: 5)
            .validate(),
        isNotNull,
      );
    });

    test('round-trips through the API payload', () {
      final restored = CalorieProfile.fromApi({
        'sex': 'female',
        'age': 30,
        'heightCm': '160.0',
        'weightKg': 60,
        'activityLevel': 'moderate',
        'goalType': 'lose_slow',
        'countSteps': false,
      })!;
      expect(restored.isMale, isFalse);
      expect(restored.activityLevel, ActivityLevel.moderate);
      expect(restored.goalType, CalorieGoalType.loseSlow);
      expect(restored.countSteps, isFalse);
      expect(base.toApi()['goal_type'], 'maintain');
      expect(CalorieProfile.fromApi({'sex': 'male'}), isNull);
    });
  });

  group('activity and helpers', () {
    test('step calories scale with weight and height', () {
      expect(CalorieActivityMath.stepCalories(0), 0);
      // 10,000 steps * 0.67 m = 6.7 km * 70 kg * 0.4
      expect(CalorieActivityMath.stepCalories(10000), 188);
      expect(
        CalorieActivityMath.stepCalories(10000, weightKg: 90, heightCm: 180),
        greaterThan(CalorieActivityMath.stepCalories(10000)),
      );
    });

    test('age from birthdate respects whether the birthday has passed', () {
      final today = DateTime(2026, 10, 26);
      expect(
          CalorieActivityMath.ageFromBirthdate(DateTime(1990, 10, 26), today),
          36);
      expect(CalorieActivityMath.ageFromBirthdate(DateTime(1990, 12, 1), today),
          35);
      expect(CalorieActivityMath.ageFromBirthdate(null, today), isNull);
    });

    test('meal type follows the time of day', () {
      expect(CalorieActivityMath.mealTypeFor(DateTime(2026, 1, 1, 7)),
          'Breakfast');
      expect(CalorieActivityMath.mealTypeFor(DateTime(2026, 1, 1, 12, 30)),
          'Lunch');
      expect(
          CalorieActivityMath.mealTypeFor(DateTime(2026, 1, 1, 16)), 'Snack');
      expect(
          CalorieActivityMath.mealTypeFor(DateTime(2026, 1, 1, 19)), 'Dinner');
      expect(
          CalorieActivityMath.mealTypeFor(DateTime(2026, 1, 1, 23)), 'Snack');
    });

    test('parses loose numbers from AI or database text', () {
      expect(CalorieTrackerMath.parseLooseNumber(250), 250);
      expect(CalorieTrackerMath.parseLooseNumber('250 kcal'), 250);
      expect(CalorieTrackerMath.parseLooseNumber('~12,5 g'), 12.5);
      expect(CalorieTrackerMath.parseLooseNumber('none'), isNull);
      expect(CalorieTrackerMath.parseLooseNumber(null), isNull);
    });

    test('food memory keys keep non-English letters', () {
      expect(CalorieTrackerMath.foodMemoryKey("McDonald's Big Mac"),
          'mcdonald_s_big_mac');
      expect(CalorieTrackerMath.foodMemoryKey('Café Latte'), 'café_latte');
      expect(CalorieTrackerMath.foodMemoryKey('  Sinigang na Baboy! '),
          'sinigang_na_baboy');
    });

    test('macro warnings never fire for partial or alcoholic entries', () {
      expect(
        CalorieTrackerMath.macroWarning(
            calories: 400, protein: 30, carbs: 0, fat: 0),
        isNull,
      );
      expect(
        CalorieTrackerMath.macroWarning(
            calories: 150, protein: 1, carbs: 13, fat: 0),
        isNull,
      );
      expect(
        CalorieTrackerMath.macroWarning(
            calories: 100, protein: 30, carbs: 30, fat: 10),
        isNotNull,
      );
    });

    test('kg is no longer mistaken for grams', () {
      expect(CalorieTrackerMath.normalizeMeasurementUnit('kg'), 'kg');
      expect(CalorieTrackerMath.normalizeMeasurementUnit('mg'), 'mg');
      expect(CalorieTrackerMath.normalizeMeasurementUnit('100g'), 'g');
      expect(CalorieTrackerMath.normalizeMeasurementUnit('250ml'), 'ml');
    });
  });
}
