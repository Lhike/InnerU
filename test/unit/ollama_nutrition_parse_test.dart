import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/services/ollama_nutrition_service.dart';

void main() {
  group('OllamaNutritionService.parseEstimate', () {
    test('reads plain numbers and the portion weight', () {
      final estimate = OllamaNutritionService.parseEstimate(
        '{"meal_name":"Chicken Adobo","portion_grams":250,"calories":480,'
        '"protein":38,"carbs":8,"fat":32,"confidence":0.8}',
      )!;
      expect(estimate.mealName, 'Chicken Adobo');
      expect(estimate.calories, 480);
      expect(estimate.portionGrams, 250);
      expect(estimate.confidence, 0.8);
    });

    test('tolerates numbers sent as text and code fences', () {
      final estimate = OllamaNutritionService.parseEstimate(
        '```json\n{"meal_name":"Pancit","calories":"420 kcal",'
        '"protein":"18 g","carbs":"55g","fat":"14","confidence":"85"}\n```',
      )!;
      expect(estimate.calories, 420);
      expect(estimate.protein, 18);
      expect(estimate.carbs, 55);
      expect(estimate.confidence, closeTo(0.85, 0.001));
    });

    test('keeps a reply without a confidence rating', () {
      final estimate = OllamaNutritionService.parseEstimate(
        '{"meal_name":"Banana","calories":105}',
      )!;
      expect(estimate.confidence, isNull);
      expect(estimate.portionGrams, isNull);
    });

    test('drops low-confidence, nameless, zero-calorie or broken replies', () {
      expect(
        OllamaNutritionService.parseEstimate(
          '{"meal_name":"Something","calories":300,"confidence":0.3}',
        ),
        isNull,
      );
      expect(
        OllamaNutritionService.parseEstimate('{"calories":300}'),
        isNull,
      );
      expect(
        OllamaNutritionService.parseEstimate(
          '{"meal_name":"Water","calories":0}',
        ),
        isNull,
      );
      expect(OllamaNutritionService.parseEstimate('not json'), isNull);
    });
  });
}
