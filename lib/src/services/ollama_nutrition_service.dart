import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:selfcare_projects/src/features/authentication/screen/calorie_tracker/calorie_tracker_math.dart';

class OllamaNutritionService {
  OllamaNutritionService._();

  static final OllamaNutritionService instance = OllamaNutritionService._();

  static const String _baseUrlFromDefine =
      String.fromEnvironment('OLLAMA_BASE_URL');
  static const String _modelFromDefine =
      String.fromEnvironment('OLLAMA_MODEL', defaultValue: 'llava');
  static const String _apiKeyFromDefine =
      String.fromEnvironment('OLLAMA_API_KEY');

  static String get baseUrl => _baseUrlFromDefine.isNotEmpty
      ? _baseUrlFromDefine
      : 'http://127.0.0.1:11434';

  static String get model => _modelFromDefine;
  static String get apiKey => _apiKeyFromDefine;

  // The 127.0.0.1 fallback above only ever resolves on a simulator running
  // on the same machine as a local Ollama server — on every real user's
  // phone it's unreachable. Without this check, isConfigured was true by
  // default (model has a non-empty default), so every unmatched food photo
  // silently burned a ~45s timeout in production before falling through.
  // Require an explicit OLLAMA_BASE_URL so that path is skipped entirely
  // unless a real, reachable endpoint has actually been deployed.
  static bool get isConfigured =>
      _baseUrlFromDefine.isNotEmpty && model.trim().isNotEmpty;

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      if (apiKey.isNotEmpty) 'X-API-Key': apiKey,
    };
  }

  Future<OllamaServiceStatus> checkStatus() async {
    if (!isConfigured) {
      return const OllamaServiceStatus(
        isReachable: false,
        message: 'AI assist is not configured.',
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/tags'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return OllamaServiceStatus(
          isReachable: true,
          message: 'Ollama is ready for new food photos.',
        );
      }

      return OllamaServiceStatus(
        isReachable: false,
        message: 'Ollama responded with ${response.statusCode}.',
      );
    } on SocketException {
      return const OllamaServiceStatus(
        isReachable: false,
        message: 'Ollama could not be reached from this device.',
      );
    } on HttpException {
      return const OllamaServiceStatus(
        isReachable: false,
        message: 'Ollama rejected the connection.',
      );
    } on FormatException {
      return const OllamaServiceStatus(
        isReachable: false,
        message: 'Ollama returned an unexpected response.',
      );
    } catch (_) {
      return const OllamaServiceStatus(
        isReachable: false,
        message: 'Ollama is unavailable right now.',
      );
    }
  }

  Future<OllamaNutritionEstimate?> estimateNutritionFromImage({
    required String imagePath,
  }) async {
    if (!isConfigured) return null;

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) return null;

    final imageBytes = await imageFile.readAsBytes();
    final imageBase64 = base64Encode(imageBytes);

    final uri = Uri.parse('$baseUrl/api/generate');
    final prompt = '''
You are a nutrition assistant.
Analyze this food image and identify the most likely food or meal.
Estimate a single realistic serving that best matches what is visible.
Return ONLY valid compact JSON with these keys:
meal_name, portion_grams, calories, protein, carbs, fat, confidence

Rules:
- meal_name must be a short, searchable food name in plain English
- prefer specific common names that could match a nutrition database
- if the food is packaged or branded, use the product name when obvious
- if multiple foods are visible, choose the main item in the portion
- portion_grams is your estimate of the visible portion's weight in grams
- calories, protein, carbs, fat are for that whole visible portion
- all values must be plain numbers without units
- confidence must be a number from 0 to 1
- no markdown
- no explanation
''';

    final response = await http
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({
            'model': model,
            'prompt': prompt,
            'images': [imageBase64],
            'stream': false,
            'format': 'json',
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('Ollama request failed (${response.statusCode})');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) return null;

    final rawResponse = payload['response'];
    if (rawResponse is! String || rawResponse.trim().isEmpty) return null;

    return parseEstimate(rawResponse);
  }

  /// Parses the model's JSON reply. Tolerates numbers sent as text with
  /// units ("250 kcal") and code fences. A reply without a confidence is
  /// kept (and shown as unrated); one that rates itself below
  /// [minimumConfidence] is dropped.
  static OllamaNutritionEstimate? parseEstimate(String rawResponse) {
    var text = rawResponse.trim();
    final fenced = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (fenced != null) text = fenced.group(0)!;

    final dynamic parsed;
    try {
      parsed = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (parsed is! Map) return null;

    double? number(String key) => CalorieTrackerMath.parseLooseNumber(parsed[key]);

    final mealName = parsed['meal_name']?.toString().trim();
    final calories = number('calories');
    var confidence = number('confidence');
    // Some models answer on a 0-100 scale.
    if (confidence != null && confidence > 1) confidence = confidence / 100;
    final grams = number('portion_grams');

    if (mealName == null || mealName.isEmpty) return null;
    if (calories == null || calories <= 0) return null;
    if (confidence != null && confidence < minimumConfidence) return null;

    return OllamaNutritionEstimate(
      mealName: mealName,
      calories: calories.round(),
      protein: (number('protein') ?? 0).round(),
      carbs: (number('carbs') ?? 0).round(),
      fat: (number('fat') ?? 0).round(),
      confidence: confidence,
      portionGrams: grams != null && grams > 0 ? grams : null,
    );
  }

  static const double minimumConfidence = 0.65;
}

class OllamaNutritionEstimate {
  const OllamaNutritionEstimate({
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.confidence,
    this.portionGrams,
  });

  final String mealName;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  /// 0..1, or null when the model didn't rate itself.
  final double? confidence;

  /// Estimated weight of the photographed portion, when the model gave one.
  final double? portionGrams;
}

class OllamaServiceStatus {
  const OllamaServiceStatus({
    required this.isReachable,
    required this.message,
  });

  final bool isReachable;
  final String message;
}
