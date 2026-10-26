import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:selfcare_projects/src/features/authentication/screen/calorie_tracker/barcode_scanner_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/calorie_tracker/calorie_entry_edit_sheet.dart';
import 'package:selfcare_projects/src/features/authentication/screen/calorie_tracker/calorie_goal_sheet.dart';
import 'package:selfcare_projects/src/features/authentication/screen/calorie_tracker/calorie_tracker_math.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/services/calorie_tracker_api_service.dart';
import 'package:selfcare_projects/src/services/company_theme_service.dart';
import 'package:selfcare_projects/src/services/daily_tracker_api_service.dart';
import 'package:selfcare_projects/src/services/image_storage_service.dart';
import 'package:selfcare_projects/src/services/ollama_nutrition_service.dart';
import 'package:selfcare_projects/src/utils/theme/app_theme.dart';

class CalorieTrackerScreen extends StatefulWidget {
  const CalorieTrackerScreen({super.key});

  @override
  State<CalorieTrackerScreen> createState() => _CalorieTrackerScreenState();
}

class _CalorieTrackerScreenState extends State<CalorieTrackerScreen> {
  static const List<_PresetFood> _presetFoods = [
    _PresetFood(
      name: 'Boiled Egg',
      calories: 78,
      protein: 6,
      carbs: 1,
      fat: 5,
      aliases: ['egg', 'eggs', 'boiled egg', 'boiled eggs'],
      defaultUnit: 'piece',
      gramsPerUnit: 50.0,
    ),
    _PresetFood(
      name: 'Chicken Breast',
      calories: 165,
      protein: 31,
      carbs: 0,
      fat: 4,
      aliases: ['chicken breast', 'chicken'],
      defaultUnit: '100g',
      gramsPerUnit: 100.0,
    ),
    _PresetFood(
      name: 'White Rice',
      calories: 205,
      protein: 4,
      carbs: 45,
      fat: 0,
      aliases: ['white rice', 'rice'],
      defaultUnit: 'cup',
      gramsPerUnit: 158.0,
    ),
    _PresetFood(
      name: 'Banana',
      calories: 105,
      protein: 1,
      carbs: 27,
      fat: 0,
      aliases: ['banana', 'bananas'],
      defaultUnit: 'piece',
      gramsPerUnit: 118.0,
    ),
    _PresetFood(
      name: 'Apple',
      calories: 95,
      protein: 0,
      carbs: 25,
      fat: 0,
      aliases: ['apple', 'apples'],
      defaultUnit: 'piece',
      gramsPerUnit: 182.0,
    ),
    _PresetFood(
      name: 'Greek Yogurt',
      calories: 120,
      protein: 17,
      carbs: 7,
      fat: 2,
      aliases: ['greek yogurt', 'yogurt'],
      defaultUnit: 'cup',
      gramsPerUnit: 170.0,
    ),
    _PresetFood(
      name: 'Milk',
      calories: 103,
      protein: 8,
      carbs: 12,
      fat: 2,
      aliases: ['milk'],
      defaultUnit: '250ml',
      gramsPerUnit: 250.0,
    ),
    _PresetFood(
      name: 'Bread',
      calories: 80,
      protein: 3,
      carbs: 15,
      fat: 1,
      aliases: ['bread', 'toast'],
      defaultUnit: 'slice',
      gramsPerUnit: 30.0,
    ),
    _PresetFood(
      name: 'Peanut Butter',
      calories: 95,
      protein: 4,
      carbs: 3,
      fat: 8,
      aliases: ['peanut butter'],
      defaultUnit: 'tbsp',
      gramsPerUnit: 16.0,
    ),
    _PresetFood(
      name: 'Olive Oil',
      calories: 40,
      protein: 0,
      carbs: 0,
      fat: 5,
      aliases: ['olive oil'],
      defaultUnit: 'tsp',
      gramsPerUnit: 5.0,
    ),
    // Standard restaurant reference portions. Menus vary by country.
    _PresetFood(
      name: 'McDonald\'s Big Mac',
      calories: 550,
      protein: 25,
      carbs: 45,
      fat: 30,
      aliases: ['big mac', 'big macs', 'big mac burger', 'mcdonalds big mac'],
      defaultUnit: 'serving',
      gramsPerUnit: 219.0,
    ),
    _PresetFood(
      name: 'McDonald\'s McChicken',
      calories: 400,
      protein: 14,
      carbs: 39,
      fat: 21,
      aliases: ['mcchicken', 'mcdonalds mcchicken', 'chicken burger'],
      defaultUnit: 'serving',
      gramsPerUnit: 173.0,
    ),
    _PresetFood(
      name: 'McDonald\'s Medium Fries',
      calories: 320,
      protein: 5,
      carbs: 43,
      fat: 15,
      aliases: ['mcdonalds fries', 'medium fries', 'fast food fries'],
      defaultUnit: 'serving',
      gramsPerUnit: 111.0,
    ),
    _PresetFood(
      name: 'McDonald\'s 10-piece McNuggets',
      calories: 410,
      protein: 23,
      carbs: 25,
      fat: 24,
      aliases: ['10 piece nuggets', '10 pc nuggets', 'mcnuggets'],
      defaultUnit: 'serving',
      gramsPerUnit: 162.0,
    ),
    _PresetFood(
      name: 'Burger King Whopper',
      calories: 670,
      protein: 31,
      carbs: 54,
      fat: 40,
      aliases: ['whopper', 'whoppers', 'burger king whopper'],
      defaultUnit: 'serving',
      gramsPerUnit: 291.0,
    ),
    _PresetFood(
      name: 'KFC Original Recipe Chicken Breast',
      calories: 390,
      protein: 39,
      carbs: 11,
      fat: 21,
      aliases: ['kfc chicken', 'kfc breast', 'fried chicken breast'],
      defaultUnit: 'piece',
      gramsPerUnit: 181.0,
    ),
    _PresetFood(
      name: 'Jollibee Chickenjoy',
      calories: 320,
      protein: 22,
      carbs: 8,
      fat: 20,
      aliases: [
        'chickenjoy',
        'chickenjoys',
        'jollibee chicken',
        'jollibee fried chicken',
      ],
      defaultUnit: 'piece',
      gramsPerUnit: 170.0,
    ),
    _PresetFood(
      name: 'Jollibee Jolly Spaghetti',
      calories: 560,
      protein: 19,
      carbs: 64,
      fat: 25,
      aliases: ['jolly spaghetti', 'jollibee spaghetti'],
      defaultUnit: 'serving',
      gramsPerUnit: 330.0,
    ),
    _PresetFood(
      name: 'Subway Italian B.M.T. 6-inch',
      calories: 410,
      protein: 18,
      carbs: 46,
      fat: 17,
      aliases: ['subway italian bmt', 'italian bmt', 'subway bmt'],
      defaultUnit: 'serving',
      gramsPerUnit: 238.0,
    ),
    _PresetFood(
      name: 'Fast-food Cheeseburger',
      calories: 303,
      protein: 15,
      carbs: 30,
      fat: 14,
      aliases: [
        'cheeseburger',
        'cheeseburgers',
        'fast food burger',
        'hamburger with cheese',
      ],
      defaultUnit: 'piece',
      gramsPerUnit: 150.0,
    ),
  ];

  static const List<String> _mealTypes = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
  ];
  static const List<String> _measurementUnits = [
    'piece',
    'g',
    'kg',
    'oz',
    'lb',
    'ml',
    'liter',
    'cup',
    'tbsp',
    'tsp',
    'slice',
    'serving',
  ];
  static const Map<String, String> _measurementUnitLabels = {
    'piece': 'pc',
    'g': 'g',
    'kg': 'kg',
    'oz': 'oz',
    'lb': 'lb',
    'ml': 'ml',
    'liter': 'l',
    'cup': 'cup',
    'tbsp': 'tbsp',
    'tsp': 'tsp',
    'slice': 'sl',
    'serving': 'srv',
  };

  final CalorieTrackerApiService _calorieApi =
      CalorieTrackerApiService.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _mealController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _calorieController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final FocusNode _mealFocusNode = FocusNode();

  Timer? _searchDebounce;
  Timer? _goalHintTimer;
  int _dailyGoal = 2000;
  final int _dailyWaterGoal = 8;
  Map<String, dynamic>? _todayDayData;
  List<Map<String, dynamic>> _historyDays = [];
  List<Map<String, dynamic>> _todayEntries = [];
  bool _isLoadingCalorieData = true;
  bool _isSavingGoal = false;
  bool _isLookingUpFood = false;
  bool _isSearchingSuggestions = false;
  bool _isCapturingMealPhoto = false;
  bool _isAnalyzingMealPhoto = false;
  bool _isCheckingOllamaStatus = false;
  bool _showPresetFoods = false;
  bool _showGoalHintBubble = false;
  bool? _isOllamaReachable;
  String _selectedMealType = CalorieActivityMath.mealTypeFor(DateTime.now());
  String _selectedMeasurementUnit = 'piece';
  String _selectedHistoryDateKey = '';
  String? _nutritionSourceLabel;
  final GlobalKey _addMealSectionKey = GlobalKey();
  late DateTime _historyWeekStart;
  String? _mealPhotoPath;
  String _ollamaStatusMessage =
      'Saved foods are reused first. AI is only used for new foods.';
  List<_NutritionLookupResult> _onlineSuggestions = [];

  /// What the current food's nutrition is measured against; quantity and
  /// unit changes rescale from it. Null for manually typed nutrition.
  FoodNutritionBasis? _basis;

  /// True when the nutrition fields were typed by the user rather than
  /// filled from [_basis], so they are kept if the name changes.
  bool _nutritionEditedManually = false;

  /// Shown when the chosen unit can't be converted for this food.
  String? _portionMessage;

  CalorieProfile? _profile;
  int _todaySteps = 0;
  List<_NutritionLookupResult> _recentFoods = [];
  bool _showAllTodayEntries = false;

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get _sessionUserId =>
      AuthService.instance.currentUserId ??
      AuthService.instance.currentSession?.id.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _selectedHistoryDateKey = _todayKey;
    _historyWeekStart = _startOfWeekSunday(DateTime.now());
    _loadCalorieData();
    _showGoalHint();
    _refreshOllamaStatus();
  }

  void _showGoalHint() {
    _goalHintTimer?.cancel();
    _showGoalHintBubble = true;
    _goalHintTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showGoalHintBubble = false;
      });
    });
  }

  void _dismissGoalHint() {
    _goalHintTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showGoalHintBubble = false;
    });
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _openScanOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Quick Scan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you want to add food faster.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 18),
              _buildScanOptionTile(
                icon: Icons.camera_alt_rounded,
                title: 'Camera Calorie',
                subtitle: 'Take a photo and label the meal',
                onTap: () {
                  Navigator.pop(context);
                  _captureMealPhoto();
                },
              ),
              const SizedBox(height: 12),
              _buildScanOptionTile(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Barcode Scanner',
                subtitle: 'Scan packaged food details',
                onTap: () {
                  Navigator.pop(context);
                  _scanBarcode();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadCalorieData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingCalorieData = true;
    });

    try {
      final results = await Future.wait([
        _calorieApi.fetchDay(date: _todayKey),
        _calorieApi.fetchHistory(limit: 90),
      ]);

      if (!mounted) return;

      final dayResponse = results[0] as Map<String, dynamic>;
      final historyResponse = results[1] as List<Map<String, dynamic>>;
      final dayData = dayResponse['day'];
      final entries = dayResponse['entries'];
      final profileData = dayResponse['profile'];
      // A day with no entries yet still has a goal: the saved profile goal
      // or yesterday's, resolved by the server.
      final goal =
          (dayData is Map ? (dayData['dailyGoal'] as num?)?.toInt() : null) ??
              (dayResponse['defaultGoal'] as num?)?.toInt() ??
              _dailyGoal;

      setState(() {
        _todayDayData = dayData is Map
            ? dayData.cast<String, dynamic>()
            : <String, dynamic>{};
        _todayEntries = entries is List
            ? entries
                .whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList()
            : <Map<String, dynamic>>[];
        _historyDays = historyResponse;
        _dailyGoal = goal;
        _profile = CalorieProfile.fromApi(
          profileData is Map ? profileData.cast<String, dynamic>() : null,
        );
      });

      unawaited(_loadTodaySteps());
      unawaited(_loadRecentFoods());
    } catch (_) {
      if (mounted) {
        _showSnackBar('Could not load calorie data.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCalorieData = false;
        });
      }
    }
  }

  Future<void> _loadTodaySteps() async {
    try {
      final response =
          await DailyTrackerApiService.instance.fetch(date: _todayKey);
      final tracker = response['tracker'];
      final steps =
          tracker is Map ? (tracker['stepCount'] as num?)?.toInt() ?? 0 : 0;
      if (mounted) setState(() => _todaySteps = steps);
    } catch (error) {
      debugPrint('Could not load steps for calorie budget: $error');
    }
  }

  Future<void> _loadRecentFoods() async {
    try {
      final memories = await _calorieApi.fetchRecentFoods(limit: 12);
      if (!mounted) return;
      setState(() {
        _recentFoods = memories
            .map(_nutritionResultFromMemory)
            .whereType<_NutritionLookupResult>()
            .toList();
      });
    } catch (error) {
      debugPrint('Could not load recent foods: $error');
    }
  }

  /// Calories burned from today's steps, counted only when the goal was set
  /// up to exclude walking (otherwise it would be counted twice).
  int get _stepCalories {
    final profile = _profile;
    if (profile == null || !profile.countSteps) return 0;
    return CalorieActivityMath.stepCalories(
      _todaySteps,
      weightKg: profile.weightKg,
      heightCm: profile.heightCm,
    );
  }

  /// Puts a day returned by the API into the history list so weekly
  /// totals and the calendar update without reloading.
  void _upsertHistoryDay(Map<String, dynamic> day) {
    final date = day['date']?.toString();
    if (date == null) return;
    final index = _historyDays.indexWhere((d) => d['date']?.toString() == date);
    if (index >= 0) {
      _historyDays[index] = day;
    } else {
      _historyDays = [day, ..._historyDays]..sort((a, b) =>
          (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));
    }
  }

  void _applyDayResponse(Map<String, dynamic> response) {
    final day = response['day'];
    final entries = response['entries'];
    setState(() {
      if (day is Map) {
        final dayMap = day.cast<String, dynamic>();
        _todayDayData = dayMap;
        _dailyGoal = (dayMap['dailyGoal'] as num?)?.toInt() ?? _dailyGoal;
        _upsertHistoryDay(dayMap);
      }
      if (entries is List) {
        _todayEntries = entries
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
      }
    });
  }

  Future<void> _refreshOllamaStatus() async {
    if (_isCheckingOllamaStatus) return;

    setState(() {
      _isCheckingOllamaStatus = true;
    });

    try {
      final status = await OllamaNutritionService.instance.checkStatus();
      if (!mounted) return;
      setState(() {
        _isOllamaReachable = status.isReachable;
        _ollamaStatusMessage = status.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isOllamaReachable = false;
        _ollamaStatusMessage =
            'Saved foods and regular nutrition lookup are still available.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOllamaStatus = false;
        });
      }
    }
  }

  static const int _minGoal = 800;
  static const int _maxGoal = 10000;

  /// Saves [goal] for today and as the default for future days.
  Future<bool> _saveGoalValue(int goal, {CalorieProfile? profile}) async {
    if (goal < _minGoal || goal > _maxGoal) {
      _showSnackBar('Enter a goal between $_minGoal and $_maxGoal kcal.');
      return false;
    }

    setState(() {
      _isSavingGoal = true;
    });

    try {
      final response = await _calorieApi.saveProfile(
        profile:
            profile?.toApi(dailyGoalOverride: goal) ?? {'daily_goal': goal},
        date: _todayKey,
      );
      final day = response['day'];
      final savedProfile = response['profile'];

      if (!mounted) return false;
      setState(() {
        _dailyGoal = goal;
        if (day is Map) {
          _todayDayData = day.cast<String, dynamic>();
          _upsertHistoryDay(_todayDayData!);
        }
        if (savedProfile is Map) {
          _profile =
              CalorieProfile.fromApi(savedProfile.cast<String, dynamic>()) ??
                  _profile;
        }
      });
      return true;
    } catch (_) {
      _showSnackBar('Failed to save calorie goal.');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSavingGoal = false;
        });
      }
    }
  }

  Future<void> _editGoalFromProgressCard(int currentGoal) async {
    var goalText = (currentGoal > 0 ? currentGoal : _dailyGoal).toString();
    final parsedGoal = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Daily Calorie Goal'),
          content: TextFormField(
            initialValue: goalText,
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: (value) => goalText = value,
            decoration: const InputDecoration(
              hintText: 'Ex. 2200',
              suffixText: 'kcal',
              helperText:
                  'Used today and every day after, until you change it.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                int.tryParse(goalText.trim()),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (parsedGoal == null || !mounted) return;
    await _saveGoalValue(parsedGoal);
  }

  Future<void> _openCalorieCalculator() async {
    final birthdate = AuthService.instance.currentSession?.birthdate;
    final profile = await showCalorieGoalSheet(
      context,
      initialProfile: _profile,
      ageFromBirthdate: CalorieActivityMath.ageFromBirthdate(
        DateTime.tryParse(birthdate ?? ''),
        DateTime.now(),
      ),
    );
    if (profile == null || !mounted) return;

    final saved = await _saveGoalValue(profile.dailyGoal, profile: profile);
    if (!saved || !mounted) return;
    _showSnackBar('Daily goal set to ${profile.dailyGoal} kcal.');
  }

  Future<void> _captureMealPhoto() async {
    if (_isCapturingMealPhoto) return;

    setState(() {
      _isCapturingMealPhoto = true;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;
      setState(() {
        _mealPhotoPath = image.path;
        _selectedMeasurementUnit = 'g';
      });

      final autoDetected = await _analyzeCapturedMealPhoto(image.path);
      if (!mounted || autoDetected) return;
      if (!autoDetected) {
        _showSnackBar(
          'Could not identify the food clearly. You can still edit the meal name manually.',
        );
      }
    } catch (_) {
      _showSnackBar('Could not open the camera.');
    } finally {
      if (mounted) {
        setState(() {
          _isCapturingMealPhoto = false;
        });
      }
    }
  }

  Future<bool> _analyzeCapturedMealPhoto(String imagePath) async {
    if (_isAnalyzingMealPhoto) return false;

    setState(() {
      _isAnalyzingMealPhoto = true;
    });

    try {
      if (Platform.isIOS) {
        return await _tryAutofillMealFromFallbackImageAnalysis(imagePath);
      }

      final labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.65),
      );

      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        final labels = await labeler.processImage(inputImage);
        return await _autofillFromImageLabels(labels);
      } finally {
        await labeler.close();
      }
    } catch (error) {
      debugPrint('Meal photo analysis failed: $error');
      return await _tryAutofillMealFromFallbackImageAnalysis(imagePath);
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingMealPhoto = false;
        });
      }
    }
  }

  /// Tries the photo's labels against the user's saved foods and presets,
  /// then the AI estimate. Generic labels ("fruit") are never auto-filled
  /// from the online database; they become a search the user picks from.
  Future<bool> _autofillFromImageLabels(List<ImageLabel> labels) async {
    const ignoredLabels = {
      'food',
      'dish',
      'cuisine',
      'ingredient',
      'tableware',
      'table',
      'recipe',
      'plate',
      'produce',
      'meal',
      'superfood',
    };

    final candidates = labels
        .map((label) => label.label.trim().toLowerCase())
        .where((label) => label.isNotEmpty && !ignoredLabels.contains(label))
        .toList();

    for (final candidate in candidates) {
      final saved = await _lookupFoodMemory(candidate);
      if (saved != null && mounted) {
        _applyLookupResult(saved);
        _showSnackBar('Matched ${saved.displayName} from your saved foods.');
        return true;
      }
    }

    for (final candidate in candidates) {
      final preset = _findPresetFood(candidate);
      if (preset != null) {
        _applyPresetFood(preset);
        _showSnackBar('Detected ${preset.name}. Check the portion.');
        return true;
      }
    }

    if (await _tryAutofillMealFromFallbackImageAnalysis(_mealPhotoPath)) {
      return true;
    }

    if (candidates.isEmpty || !mounted) return false;
    _mealController.text = candidates.first;
    _handleMealNameChanged(candidates.first);
    _showSnackBar(
        'Looks like ${candidates.first}. Pick the closest match below.');
    return true;
  }

  Future<bool> _tryAutofillMealFromFallbackImageAnalysis(
    String? imagePath,
  ) async {
    final ollamaEstimate = await _estimateMealWithOllama(imagePath);
    if (!mounted || ollamaEstimate == null) return false;

    // The user's own saved food wins; otherwise keep the AI's portion-aware
    // numbers instead of swapping in a database item of a different size.
    final saved = await _lookupFoodMemory(ollamaEstimate.mealName);
    if (!mounted) return false;
    final result = saved ?? _nutritionResultFromOllamaEstimate(ollamaEstimate);
    _applyLookupResult(result);

    _showSnackBar(
      'Estimated ${result.displayName} from your photo. Check the portion before adding.',
    );
    return true;
  }

  _NutritionLookupResult _nutritionResultFromOllamaEstimate(
    OllamaNutritionEstimate estimate,
  ) {
    final grams = estimate.portionGrams;
    final confidence = estimate.confidence;
    return _NutritionLookupResult(
      basis: FoodNutritionBasis(
        name: estimate.mealName,
        perServing: NutritionValues(
          calories: estimate.calories.toDouble(),
          protein: estimate.protein.toDouble(),
          carbs: estimate.carbs.toDouble(),
          fat: estimate.fat.toDouble(),
        ),
        servingQuantity: grams ?? 1,
        servingUnit: grams == null ? 'serving' : 'g',
        gramsPerServing: grams,
      ),
      subtitle: confidence == null
          ? 'AI estimate · check the portion'
          : 'AI estimate (${(confidence * 100).round()}% sure) · check the portion',
    );
  }

  Future<OllamaNutritionEstimate?> _estimateMealWithOllama(
    String? imagePath,
  ) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      return await OllamaNutritionService.instance.estimateNutritionFromImage(
        imagePath: imagePath,
      );
    } catch (error) {
      debugPrint('Ollama image estimate failed: $error');
      return null;
    }
  }

  Future<String?> _uploadMealPhotoIfNeeded() async {
    final photoPath = _mealPhotoPath;
    if (photoPath == null || photoPath.isEmpty) return null;
    if (!ImageStorageService.isConfigured) return null;

    try {
      final bytes = await File(photoPath).readAsBytes();
      return await ImageStorageService.uploadImageBytes(
        bytes,
        fileName:
            'meal_${_sessionUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    } catch (_) {
      return null;
    }
  }

  void _clearMealComposer() {
    if (!mounted) return;

    _mealController.clear();
    _quantityController.clear();
    _clearNutritionFields();
    _searchDebounce?.cancel();

    setState(() {
      _mealPhotoPath = null;
      _onlineSuggestions = [];
      _isSearchingSuggestions = false;
      _nutritionSourceLabel = null;
      _basis = null;
      _nutritionEditedManually = false;
      _portionMessage = null;
      _selectedMealType = CalorieActivityMath.mealTypeFor(DateTime.now());
      _selectedMeasurementUnit = 'serving';
    });
  }

  void _clearNutritionFields() {
    _calorieController.clear();
    _proteinController.clear();
    _carbController.clear();
    _fatController.clear();
  }

  _NutritionLookupResult? _nutritionResultFromMemory(
    Map<String, dynamic> data, {
    String? fallbackName,
  }) {
    final calories = CalorieTrackerMath.parseLooseNumber(data['calories']);
    if (calories == null || calories <= 0) return null;
    final name = data['displayName']?.toString().trim();
    final displayName =
        name != null && name.isNotEmpty ? name : (fallbackName ?? '').trim();
    if (displayName.isEmpty) return null;

    double read(String key) =>
        CalorieTrackerMath.parseLooseNumber(data[key]) ?? 0;
    final servingQuantity =
        CalorieTrackerMath.parseLooseNumber(data['servingQuantity']);
    final servingUnit = data['servingUnit']?.toString().trim();

    return _NutritionLookupResult(
      basis: FoodNutritionBasis(
        name: displayName,
        perServing: NutritionValues(
          calories: calories,
          protein: read('protein'),
          carbs: read('carbs'),
          fat: read('fat'),
        ),
        // Older saved foods have no serving info: treat them as 1 serving.
        servingQuantity: servingQuantity != null && servingQuantity > 0
            ? servingQuantity
            : 1,
        servingUnit: servingUnit == null || servingUnit.isEmpty
            ? 'serving'
            : servingUnit,
        gramsPerServing:
            CalorieTrackerMath.parseLooseNumber(data['gramsPerServing']),
      ),
      subtitle: 'Saved from your previous logs',
    );
  }

  Future<_NutritionLookupResult?> _lookupFoodMemory(String mealName) async {
    final key = CalorieTrackerMath.foodMemoryKey(mealName);
    if (key.isEmpty) return null;

    try {
      final data = await _calorieApi.lookupFoodMemory(key);
      if (data == null) return null;
      return _nutritionResultFromMemory(data, fallbackName: mealName);
    } catch (error) {
      debugPrint('Food memory lookup failed: $error');
      return null;
    }
  }

  /// Remembers what was logged, per serving, so the next lookup scales
  /// correctly instead of treating a 2-serving total as one serving.
  Future<void> _saveFoodMemory({
    required String mealName,
    required FoodNutritionBasis basis,
    String source = 'meal_log',
  }) async {
    final key = CalorieTrackerMath.foodMemoryKey(mealName);
    if (key.isEmpty) return;

    try {
      await _calorieApi.upsertFoodMemory(
        key: key,
        displayName: mealName.trim(),
        lookupName: mealName.trim().toLowerCase(),
        calories: math.max(1, basis.perServing.roundedCalories),
        protein: basis.perServing.roundedProtein,
        carbs: basis.perServing.roundedCarbs,
        fat: basis.perServing.roundedFat,
        servingQuantity: basis.servingQuantity,
        servingUnit: basis.servingUnit,
        gramsPerServing: basis.gramsPerServing,
        source: source,
        used: true,
      );
    } catch (error) {
      debugPrint('Failed to save food memory: $error');
    }
  }

  int? _parseField(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  Future<void> _addMeal() async {
    final mealName = _mealController.text.trim();
    if (mealName.isEmpty) {
      _showSnackBar('Enter a food name first.');
      return;
    }

    final calories = _parseField(_calorieController);
    if (calories == null || calories <= 0) {
      await _fillNutritionForTypedName(mealName);
      return;
    }

    final protein = _parseField(_proteinController) ?? 0;
    final carbs = _parseField(_carbController) ?? 0;
    final fat = _parseField(_fatController) ?? 0;
    final quantity =
        double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));

    final warning = CalorieTrackerMath.macroWarning(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    if (warning != null && !await _confirmSaveWithWarning(warning)) return;
    if (!mounted) return;

    setState(() => _isLookingUpFood = true);
    try {
      final photoUrl = await _uploadMealPhotoIfNeeded();
      if (!mounted) return;

      final response = await _calorieApi.addEntry(
        date: _todayKey,
        meal: mealName,
        mealType: _selectedMealType,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        quantity: quantity,
        measurementUnit: _selectedMeasurementUnit,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      _applyDayResponse(response);

      // Remember the food only once it was actually logged. Use the food's
      // own serving when we have one, otherwise exactly what was logged.
      final basis = _basis != null && !_nutritionEditedManually
          ? _basis!
          : FoodNutritionBasis(
              name: mealName,
              perServing: NutritionValues(
                calories: calories.toDouble(),
                protein: protein.toDouble(),
                carbs: carbs.toDouble(),
                fat: fat.toDouble(),
              ),
              servingQuantity: quantity != null && quantity > 0 ? quantity : 1,
              servingUnit: _selectedMeasurementUnit,
            );
      unawaited(
        _saveFoodMemory(mealName: mealName, basis: basis)
            .then((_) => _loadRecentFoods()),
      );

      _clearMealComposer();
      FocusManager.instance.primaryFocus?.unfocus();
      _showSnackBar('Added $mealName · $calories kcal');
    } catch (_) {
      _showSnackBar('Failed to add meal. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isLookingUpFood = false);
    }
  }

  Future<bool> _confirmSaveWithWarning(String warning) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Double-check the numbers'),
        content: Text(warning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Edit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// "Add Entry" was tapped without calories: fill them from the user's
  /// saved foods or presets for review, or show database matches to pick
  /// from. Never saves a guess silently.
  Future<void> _fillNutritionForTypedName(String mealName) async {
    final amount = _calculateFoodAmount(mealName);
    if (amount != null) {
      _applyLookupResult(amount);
      _showSnackBar(
          'Filled ${amount.displayName}. Check it, then tap Add Entry.');
      return;
    }

    final saved = await _lookupFoodMemory(mealName);
    if (!mounted) return;
    if (saved != null) {
      _applyLookupResult(saved);
      _showSnackBar(
          'Filled from your saved foods. Check it, then tap Add Entry.');
      return;
    }

    final preset = _findPresetFood(mealName);
    if (preset != null) {
      _applyPresetFood(preset);
      _showSnackBar('Filled ${preset.name}. Check it, then tap Add Entry.');
      return;
    }

    setState(() => _isSearchingSuggestions = true);
    try {
      final results = await _fetchOnlineSuggestions(mealName, limit: 6);
      if (!mounted) return;
      setState(() => _onlineSuggestions = results);
      _showSnackBar(
        results.isEmpty
            ? 'No match found. Enter the calories yourself.'
            : 'Pick the closest match below, or enter the calories yourself.',
      );
    } on TimeoutException {
      _showSnackBar('Food lookup timed out. You can enter calories yourself.');
    } catch (_) {
      _showSnackBar('Food lookup failed. You can enter calories yourself.');
    } finally {
      if (mounted) setState(() => _isSearchingSuggestions = false);
    }
  }

  Future<void> _setWaterGlasses(int glasses) async {
    final clamped = glasses.clamp(0, _dailyWaterGoal);

    try {
      final response = await _calorieApi.updateDay(
        date: _todayKey,
        dailyGoal: _dailyGoal,
        waterGlasses: clamped,
        waterGoal: _dailyWaterGoal,
      );
      final day = response['day'];
      if (day is Map && mounted) {
        setState(() {
          _todayDayData = day.cast<String, dynamic>();
        });
      }
    } catch (_) {
      _showSnackBar('Failed to update water tracker.');
    }
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final entryId = entry['id']?.toString();
    if (entryId == null || entryId.isEmpty) return;

    final edit = await showCalorieEntryEditSheet(
      context,
      entry: entry,
      mealTypes: _mealTypes,
    );
    if (edit == null || !mounted) return;

    try {
      final response = edit.delete
          ? await _calorieApi.deleteEntry(entryId)
          : await _calorieApi.updateEntry(
              entryId: entryId,
              meal: edit.meal,
              mealType: edit.mealType,
              calories: edit.calories,
              protein: edit.protein,
              carbs: edit.carbs,
              fat: edit.fat,
            );
      if (!mounted) return;
      _applyDayResponse(response);
      _showSnackBar(edit.delete ? 'Entry deleted.' : 'Entry updated.');
    } catch (_) {
      _showSnackBar(
        edit.delete
            ? 'Could not delete the entry.'
            : 'Could not update the entry.',
      );
    }
  }

  void _applyPresetFood(_PresetFood preset) {
    _applyBasis(
      FoodNutritionBasis.fromPreset(
        preset,
        sourceLabel: 'Standard reference portion',
      ),
    );
  }

  void _applyLookupResult(_NutritionLookupResult result) {
    _applyBasis(
      result.basis.copyWith(sourceLabel: result.subtitle),
      quantity: result.quantity,
      unit: result.unit,
    );
  }

  /// Selects a food: its name, default portion and nutrition. Quantity and
  /// unit changes afterwards rescale from [basis].
  void _applyBasis(
    FoodNutritionBasis basis, {
    double? quantity,
    String? unit,
  }) {
    if (!mounted) return;
    _searchDebounce?.cancel();

    _mealController.text = basis.name;
    _mealController.selection =
        TextSelection.collapsed(offset: basis.name.length);
    final selectedUnit = unit == null
        ? basis.servingUnit
        : CalorieTrackerMath.normalizeMeasurementUnit(unit);
    _quantityController.text =
        _formatQuantity(quantity ?? basis.servingQuantity);

    setState(() {
      _basis = basis;
      _nutritionEditedManually = false;
      _selectedMeasurementUnit = selectedUnit;
      _nutritionSourceLabel = basis.sourceLabel ?? 'Nutrition database result';
      _onlineSuggestions = [];
      _isSearchingSuggestions = false;
    });
    _recalculateFromBasis();
  }

  static String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  /// Fills the nutrition fields for the current quantity and unit.
  void _recalculateFromBasis() {
    final basis = _basis;
    if (basis == null || !mounted) return;

    final quantity =
        double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));
    if (quantity == null || quantity <= 0) {
      setState(() => _portionMessage = 'Enter how much you had.');
      return;
    }

    final scaled = basis.scaled(quantity, _selectedMeasurementUnit);
    if (scaled == null) {
      setState(() {
        _portionMessage =
            "We don't know the weight of this food, so it can't be measured in "
            '${_measurementUnitLabels[_selectedMeasurementUnit] ?? _selectedMeasurementUnit}. '
            'Use ${basis.supportedUnits.map((u) => _measurementUnitLabels[u] ?? u).join(' or ')}.';
      });
      return;
    }

    _calorieController.text = scaled.roundedCalories.toString();
    _proteinController.text = scaled.roundedProtein.toString();
    _carbController.text = scaled.roundedCarbs.toString();
    _fatController.text = scaled.roundedFat.toString();
    setState(() {
      _portionMessage = null;
      _nutritionEditedManually = false;
    });
  }

  /// Units to offer: the food's convertible units when one is selected.
  List<String> get _availableUnits {
    final basis = _basis;
    if (basis == null) return _measurementUnits;
    final units = [...basis.supportedUnits];
    if (!units.contains(_selectedMeasurementUnit)) {
      units.add(_selectedMeasurementUnit);
    }
    return units;
  }

  _PresetFood? _findPresetFood(String query) {
    final preset = CalorieTrackerMath.findPresetFood(query, _presetFoods);
    if (preset == null) return null;
    return preset is _PresetFood ? preset : null;
  }

  /// Reads "2 big macs" or "150g rice" as a preset with an amount.
  _NutritionLookupResult? _calculateFoodAmount(String query) {
    final amount = CalorieTrackerMath.calculateFoodAmount(
      query: query,
      presets: _presetFoods,
    );
    if (amount == null) return null;
    final preset = _presetFoods.firstWhere(
      (food) => amount.displayName.endsWith(food.name),
      orElse: () => _presetFoods.first,
    );
    final quantity = double.tryParse(amount.quantityLabel);
    if (quantity == null) return null;
    final basis = FoodNutritionBasis.fromPreset(
      preset,
      sourceLabel: 'Calculated from your portion',
    );
    final unitIsServing = amount.unit == basis.servingUnit;
    return _NutritionLookupResult(
      basis: basis,
      subtitle: 'Calculated from your portion',
      // "2 chicken" means 2 servings of 100 g, not 2 g.
      quantity: unitIsServing && basis.servingQuantity != 1
          ? quantity * basis.servingQuantity
          : quantity,
      unit: amount.unit,
    );
  }

  /// Typing never rewrites the name. If the text no longer matches the
  /// selected food, that food (and its auto-filled numbers) is dropped so
  /// nothing stale is saved.
  void _handleMealNameChanged(String value) {
    if (!mounted) return;
    final basis = _basis;
    if (basis != null &&
        value.trim().toLowerCase() != basis.name.trim().toLowerCase()) {
      if (!_nutritionEditedManually) _clearNutritionFields();
      setState(() {
        _basis = null;
        _nutritionSourceLabel = null;
        _portionMessage = null;
      });
    }
    _queueSuggestionSearch(value);
  }

  void _handlePortionChanged() {
    if (_basis != null) _recalculateFromBasis();
  }

  Future<List<_NutritionLookupResult>> _fetchOnlineSuggestions(
    String mealName, {
    int limit = 5,
  }) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/cgi/search.pl',
      {
        'search_terms': mealName,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '$limit',
        'fields': _openFoodFactsFields,
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'InnerU-SelfcareApp/1.0 (food calorie lookup)',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return const [];

    final payload = json.decode(response.body) as Map<String, dynamic>;
    final products = (payload['products'] as List?) ?? const [];
    final suggestions = <_NutritionLookupResult>[];

    for (final product in products) {
      if (product is! Map) continue;
      final result = _nutritionFromProductMap(product.cast<String, dynamic>());
      if (result != null) suggestions.add(result);
    }

    return suggestions;
  }

  static const _openFoodFactsFields =
      'product_name,product_name_en,generic_name,brands,serving_size,'
      'serving_quantity,serving_quantity_unit,nutriments';

  _NutritionLookupResult? _nutritionFromProductMap(
    Map<String, dynamic> product,
  ) {
    final basis = FoodNutritionBasis.fromOpenFoodFacts(product);
    if (basis == null) return null;
    final per = basis.servingUnit == 'serving'
        ? 'per serving${basis.gramsPerServing == null ? '' : ' (${_formatQuantity(basis.gramsPerServing!)} g)'}'
        : 'per ${_formatQuantity(basis.servingQuantity)} ${basis.servingUnit}';
    return _NutritionLookupResult(
      basis: basis,
      subtitle: 'Food database · $per',
    );
  }

  void _queueSuggestionSearch(String query) {
    _searchDebounce?.cancel();

    if (query.trim().length < 3) {
      if (mounted) {
        setState(() {
          _onlineSuggestions = [];
          _isSearchingSuggestions = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearchingSuggestions = true;
    });

    // Wait for a pause in typing to stay within the database's rate limit.
    _searchDebounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        final results = await _fetchOnlineSuggestions(query, limit: 6);
        if (!mounted || _mealController.text.trim() != query.trim()) return;
        setState(() {
          _onlineSuggestions = results;
          _isSearchingSuggestions = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _onlineSuggestions = [];
          _isSearchingSuggestions = false;
        });
      }
    });
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || barcode == null || barcode.isEmpty) return;

    setState(() {
      _isLookingUpFood = true;
    });

    try {
      final product = await _fetchBarcodeProduct(barcode);
      if (product == null) {
        _showSnackBar('This product is not in the food database yet.');
        return;
      }

      final result = _nutritionFromProductMap(product);
      if (result == null) {
        _showSnackBar('No nutrition data found for that barcode.');
        return;
      }

      if (!mounted) return;
      _applyLookupResult(result);
      _showSnackBar('Found ${result.displayName}. Set how much you had.');
      unawaited(_scrollToSection(_addMealSectionKey));
    } on TimeoutException {
      _showSnackBar('Barcode lookup timed out. Please try again.');
    } catch (_) {
      _showSnackBar('Barcode lookup failed.');
    } finally {
      if (mounted) {
        setState(() {
          _isLookingUpFood = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchBarcodeProduct(String rawBarcode) async {
    for (final barcode in _barcodeLookupCandidates(rawBarcode)) {
      final uri = Uri.https(
        'world.openfoodfacts.org',
        '/api/v2/product/$barcode',
        {
          'fields': _openFoodFactsFields,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'InnerU-SelfcareApp/1.0 (barcode food lookup)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) continue;

      final payload = json.decode(response.body);
      if (payload is! Map<String, dynamic>) continue;
      final product = payload['product'];
      if (product is Map<String, dynamic>) return product;
    }

    return null;
  }

  List<String> _barcodeLookupCandidates(String rawBarcode) {
    final digits = rawBarcode.replaceAll(RegExp(r'[^0-9]'), '');
    final candidates = <String>[];

    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && !candidates.contains(trimmed)) {
        candidates.add(trimmed);
      }
    }

    add(rawBarcode);
    add(digits);
    if (digits.length == 12) add('0$digits');
    if (digits.length == 13 && digits.startsWith('0')) {
      add(digits.substring(1));
    }

    return candidates;
  }

  int _weeklyTotal(List<Map<String, dynamic>> docs, String key) {
    return docs.fold<int>(
      0,
      (total, doc) => total + ((doc[key] as num?)?.toInt() ?? 0),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  DateTime _startOfWeekSunday(DateTime date) {
    final offset = date.weekday % 7;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: offset));
  }

  String _historyWeekLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    if (weekStart.month == weekEnd.month) {
      return '${DateFormat('MMMM').format(weekStart)} ${weekStart.year}';
    }
    if (weekStart.year == weekEnd.year) {
      return '${DateFormat('MMM').format(weekStart)} - ${DateFormat('MMM').format(weekEnd)} ${weekStart.year}';
    }
    return '${DateFormat('MMM yyyy').format(weekStart)} - ${DateFormat('MMM yyyy').format(weekEnd)}';
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _goalHintTimer?.cancel();
    _mealController.dispose();
    _mealFocusNode.dispose();
    _quantityController.dispose();
    _calorieController.dispose();
    _proteinController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Widget _macroTile(String label, int grams, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 26,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${grams}g',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _budgetStat(String label, String value, {Color? color}) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color ?? colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProgressCard({
    required int totalCalories,
    required int currentGoal,
    required int totalCarbs,
    required int totalProtein,
    required int totalFat,
    required int mealCount,
    required double progress,
  }) {
    final goalLabel = currentGoal <= 0 ? '--' : currentGoal.toString();
    final stepCalories = _stepCalories;
    final remaining = currentGoal + stepCalories - totalCalories;
    final progressPercent = (progress * 100).round().clamp(0, 100);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.24),
            theme.colorScheme.secondary.withValues(alpha: 0.28),
            theme.colorScheme.surface,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily Progress',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isSavingGoal
                    ? null
                    : () => _editGoalFromProgressCard(currentGoal),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      children: [
                        TextSpan(text: totalCalories.toString()),
                        TextSpan(
                          text: '/$goalLabel Kcal',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.58),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showGoalHintBubble) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 230),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        'Tap the Kcal target to change your goal.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismissGoalHint,
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ArcProgressPainter(
                      progress: progress,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.14),
                      progressColor: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: theme.colorScheme.tertiary,
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      totalCalories.toString(),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'eaten',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 10,
                  bottom: 18,
                  child: Text(
                    '0%',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 18,
                  child: Text(
                    '$progressPercent%',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _budgetStat('Goal', goalLabel),
              _budgetStat('Food', '−$totalCalories'),
              _budgetStat(
                'Steps',
                _profile?.countSteps == true ? '+$stepCalories' : 'off',
              ),
              _budgetStat(
                remaining >= 0 ? 'Remaining' : 'Over',
                '${remaining.abs()}',
                color: remaining >= 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ],
          ),
          if (_profile == null) ...[
            const SizedBox(height: 8),
            Text(
              'Set up your goal to add the calories you burn walking.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ] else if (_profile!.countSteps && _todaySteps > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${NumberFormat.decimalPattern().format(_todaySteps)} steps today',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _macroTile('Carbs', totalCarbs, const Color(0xFF8FAF86)),
              const SizedBox(width: 10),
              _macroTile('Protein', totalProtein, const Color(0xFFE06464)),
              const SizedBox(width: 10),
              _macroTile('Fat', totalFat, const Color(0xFF8B8B8B)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openCalorieCalculator,
              icon: Icon(
                Icons.calculate_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              label: Text(
                _profile == null ? 'Set up my goal' : 'Update my goal',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$mealCount meal entries logged today',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCalendarStrip(List<Map<String, dynamic>> dayDocs) {
    final now = DateTime.now();
    final currentWeekStart = _startOfWeekSunday(now);
    final weekStart = _historyWeekStart;
    final canGoNext = weekStart.isBefore(currentWeekStart);
    final logsByDate = {
      for (final day in dayDocs) (day['date']?.toString() ?? ''): day,
    };
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.22 : 0.04,
            ),
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
              Expanded(
                child: Text(
                  'History',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _historyWeekStart =
                        weekStart.subtract(const Duration(days: 7));
                  });
                },
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: VisualDensity.compact,
                color: colorScheme.primary,
              ),
              Text(
                _historyWeekLabel(weekStart),
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: canGoNext
                    ? () {
                        setState(() {
                          _historyWeekStart =
                              weekStart.add(const Duration(days: 7));
                        });
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: VisualDensity.compact,
                color: colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(7, (index) {
              final date = weekStart.add(Duration(days: index));
              final key = DateFormat('yyyy-MM-dd').format(date);
              final isSelected = key == _selectedHistoryDateKey;
              final data = logsByDate[key];
              final dayCalories =
                  (data?['totalCalories'] as num?)?.toInt() ?? 0;
              final isToday = key == _todayKey;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedHistoryDateKey = key;
                      _historyWeekStart = _startOfWeekSunday(date);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('E').format(date).substring(0, 3),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: dayCalories > 0
                                ? colorScheme.primary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              maxWidth: 42,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Today',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayHistoryCard(Map<String, dynamic>? data) {
    final calories = (data?['totalCalories'] as num?)?.toInt() ?? 0;
    final protein = (data?['totalProtein'] as num?)?.toInt() ?? 0;
    final carbs = (data?['totalCarbs'] as num?)?.toInt() ?? 0;
    final fat = (data?['totalFat'] as num?)?.toInt() ?? 0;
    final water = (data?['waterGlasses'] as num?)?.toInt() ?? 0;
    final selectedDate =
        DateTime.tryParse(_selectedHistoryDateKey) ?? DateTime.now();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMM d').format(selectedDate),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _historyMetricChip('$calories kcal', 'Calories'),
              _historyMetricChip('${protein}g', 'Protein'),
              _historyMetricChip('${carbs}g', 'Carbs'),
              _historyMetricChip('${fat}g', 'Fat'),
              _historyMetricChip('$water glasses', 'Water'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyMetricChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          children: [
            TextSpan(
              text: '$value\n',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            TextSpan(
              text: label,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    String? hint,
    String? suffix,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) {
          if (!mounted) return;
          // Typed numbers are the user's call: keep them if the name changes.
          setState(() => _nutritionEditedManually = true);
        },
        decoration: _themedInputDecoration(
          theme: theme,
          labelText: label,
          hintText: hint ?? label,
          suffixText: suffix,
        ),
      ),
    );
  }

  Widget _buildNutritionPreview() {
    final calories = int.tryParse(_calorieController.text.trim()) ?? 0;
    final protein = int.tryParse(_proteinController.text.trim()) ?? 0;
    final carbs = int.tryParse(_carbController.text.trim()) ?? 0;
    final fat = int.tryParse(_fatController.text.trim()) ?? 0;
    if (calories <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final warning = CalorieTrackerMath.macroWarning(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    final isConsistent = warning == null;

    Widget metric(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Nutrition preview',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    )),
              ),
              Text('$calories kcal',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              metric('Protein', '${protein}g', const Color(0xFFE06464)),
              const SizedBox(width: 8),
              metric('Carbs', '${carbs}g', const Color(0xFF6E9B67)),
              const SizedBox(width: 8),
              metric('Fat', '${fat}g', const Color(0xFF8B6F47)),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isConsistent ? Icons.verified_outlined : Icons.warning_amber,
                size: 16,
                color:
                    isConsistent ? colorScheme.primary : colorScheme.tertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isConsistent
                      ? (_nutritionEditedManually
                          ? 'Entered by you'
                          : _nutritionSourceLabel ??
                              'Review the serving size before saving.')
                      : warning,
                  style: TextStyle(
                    color: isConsistent
                        ? colorScheme.onSurface.withValues(alpha: 0.72)
                        : colorScheme.tertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _themedInputDecoration({
    required ThemeData theme,
    required String labelText,
    String? hintText,
    String? helperText,
    String? suffixText,
  }) {
    final colorScheme = theme.colorScheme;
    final fillColor = theme.brightness == Brightness.dark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerHighest;

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      helperMaxLines: helperText == null ? null : 1,
      suffixText: suffixText,
      filled: true,
      fillColor: fillColor,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: colorScheme.primary),
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
      ),
      helperStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
      ),
      suffixStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    );
  }

  Widget _buildMealPhotoPreview() {
    final photoPath = _mealPhotoPath;
    if (photoPath == null || photoPath.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(photoPath),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 72,
                  height: 72,
                  color: colorScheme.surfaceContainer,
                  alignment: Alignment.center,
                  child: Icon(Icons.photo, color: colorScheme.onSurfaceVariant),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isAnalyzingMealPhoto
                  ? 'Analyzing your meal photo and filling calories...'
                  : 'Meal photo ready. We will auto-fill calories when the food is detected.',
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _mealPhotoPath = null;
              });
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedMealFieldsHint() {
    if (_mealPhotoPath == null || _mealPhotoPath!.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Captured meal',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check the food name, then adjust the amount. Calories update as you change it.',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOllamaStatusBanner() {
    final bool isReady = _isOllamaReachable == true;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color tint = isReady
        ? colorScheme.primaryContainer.withValues(alpha: 0.85)
        : colorScheme.tertiaryContainer.withValues(alpha: 0.85);
    final Color iconColor =
        isReady ? colorScheme.primary : colorScheme.tertiary;
    final String title = _isCheckingOllamaStatus
        ? 'Checking AI calorie assist'
        : isReady
            ? 'AI calorie assist is ready'
            : 'Using saved foods and regular lookup';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isCheckingOllamaStatus
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Icon(
                    isReady
                        ? Icons.auto_awesome_rounded
                        : Icons.inventory_2_outlined,
                    color: iconColor,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isCheckingOllamaStatus
                      ? 'Saved foods are reused first while we check the AI connection.'
                      : _ollamaStatusMessage,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (!_isCheckingOllamaStatus)
            IconButton(
              onPressed: _refreshOllamaStatus,
              tooltip: 'Refresh AI status',
              icon: const Icon(Icons.refresh_rounded),
              color: iconColor,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  /// Instant suggestions while typing: an amount the user typed ("2 eggs"),
  /// their recent foods, then presets.
  Iterable<_NutritionLookupResult> _localFoodOptions(String text) {
    final query = text.trim().toLowerCase();
    if (query.isEmpty ||
        (_basis != null && query == _basis!.name.toLowerCase())) {
      return const [];
    }
    final options = <_NutritionLookupResult>[];
    final amount = _calculateFoodAmount(query);
    if (amount != null) options.add(amount);
    for (final recent in _recentFoods) {
      if (recent.displayName.toLowerCase().contains(query)) options.add(recent);
    }
    for (final preset in _presetFoods) {
      final matches = preset.name.toLowerCase().contains(query) ||
          preset.aliases.any((alias) => alias.contains(query));
      if (!matches) continue;
      if (options.any((o) => o.displayName == preset.name)) continue;
      options.add(_NutritionLookupResult(
        basis: FoodNutritionBasis.fromPreset(preset),
        subtitle: 'Standard reference portion',
      ));
    }
    return options.take(8);
  }

  Widget _buildRecentFoods() {
    if (_recentFoods.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent · tap to log again',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentFoods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final food = _recentFoods[index];
                return ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 18),
                  label: Text('${food.displayName} · ${food.calories} kcal'),
                  onPressed: () => _applyLookupResult(food),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _mealTypes.map((mealType) {
        final isSelected = mealType == _selectedMealType;
        return ChoiceChip(
          label: Text(mealType),
          selected: isSelected,
          selectedColor:
              isDark ? colorScheme.primaryContainer : const Color(0xFF90A17D),
          backgroundColor: colorScheme.surfaceContainerHighest,
          side: BorderSide.none,
          labelStyle: TextStyle(
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _selectedMealType = mealType;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildWaterTracker({
    required int waterGlasses,
    required int waterGoal,
  }) {
    final progress = waterGoal <= 0
        ? 0.0
        : (waterGlasses / waterGoal).clamp(0, 1).toDouble();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.12),
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
              Expanded(
                child: Text(
                  'Water Tracker',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '$waterGlasses/$waterGoal glasses',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: colorScheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: waterGlasses <= 0
                      ? null
                      : () => _setWaterGlasses(waterGlasses - 1),
                  icon: const Icon(Icons.remove),
                  label: const Text('Remove Glass'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: waterGlasses >= waterGoal
                      ? null
                      : () => _setWaterGlasses(waterGlasses + 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(Icons.water_drop_outlined,
                      color: colorScheme.onPrimary),
                  label: Text(
                    'Add Glass',
                    style: TextStyle(color: colorScheme.onPrimary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSoftSection({
    required String title,
    required Widget child,
    Widget? trailing,
    Key? key,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.22 : 0.03,
            ),
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
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTodayEntriesCard(List<Map<String, dynamic>> entries) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalCalories = entries.fold<int>(
      0,
      (sum, item) => sum + ((item['calories'] as num?)?.toInt() ?? 0),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.22 : 0.03,
            ),
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
              Expanded(
                child: Text(
                  'Today\'s Entries',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${entries.length} item${entries.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No meals logged yet today.',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start with a quick scan or tap Log Food to add your first meal.',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _scrollToSection(_addMealSectionKey),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Log a meal'),
                ),
              ],
            )
          else ...[
            Text(
              '$totalCalories kcal logged today',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...entries
                .take(_showAllTodayEntries ? entries.length : 5)
                .map((entry) {
              final meal = (entry['meal'] as String?)?.trim().isNotEmpty == true
                  ? (entry['meal'] as String).trim()
                  : 'Meal';
              final mealType =
                  (entry['mealType'] as String?)?.trim().isNotEmpty == true
                      ? (entry['mealType'] as String).trim()
                      : 'Snack';
              final calories = (entry['calories'] as num?)?.toInt() ?? 0;
              final quantity = entry['quantity']?.toString().trim();
              final unit = (entry['measurementUnit'] as String?)?.trim();

              final quantityText = [
                if (quantity != null &&
                    quantity.isNotEmpty &&
                    quantity != 'null')
                  quantity,
                if (unit != null && unit.isNotEmpty) unit,
              ].join(' ').trim();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _editEntry(entry),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              mealType,
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                if (quantityText.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    quantityText,
                                    style: TextStyle(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.66),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$calories kcal',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (entries.length > 5)
              TextButton(
                onPressed: () => setState(
                  () => _showAllTodayEntries = !_showAllTodayEntries,
                ),
                child: Text(
                  _showAllTodayEntries
                      ? 'Show less'
                      : 'Show all ${entries.length} entries',
                ),
              ),
            Text(
              'Tap an entry to edit or delete it.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekStartKey = DateFormat('yyyy-MM-dd').format(_historyWeekStart);
    final weekEndKey = DateFormat('yyyy-MM-dd')
        .format(_historyWeekStart.add(const Duration(days: 6)));
    final isCurrentWeek =
        _historyWeekStart == _startOfWeekSunday(DateTime.now());
    return CompanyThemeBuilder(
      builder: (context, companyTheme) {
        return Theme(
          data: AppTheme.company(companyTheme),
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);

              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                appBar: AppBar(
                  backgroundColor: companyTheme.surfaceColor,
                  foregroundColor: companyTheme.inkColor,
                  iconTheme: IconThemeData(color: companyTheme.inkColor),
                  titleSpacing: 4,
                  title: Text(
                    'Food Calories',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: companyTheme.inkColor,
                    ),
                  ),
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  actions: [
                    IconButton(
                      onPressed: _isLookingUpFood || _isCapturingMealPhoto
                          ? null
                          : _openScanOptions,
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.iconTheme.color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.center_focus_weak_rounded),
                      tooltip: 'Quick scan',
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/todayIntake'),
                      icon: Icon(
                        Icons.calendar_month_rounded,
                        color: companyTheme.iconColor,
                        size: 18,
                      ),
                      label: Text(
                        'History',
                        style: TextStyle(
                          color: companyTheme.iconColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                body: _isLoadingCalorieData
                    ? const Center(child: CircularProgressIndicator())
                    : Builder(
                        builder: (context) {
                          final dayData = _todayDayData ?? {};
                          final currentGoal =
                              (dayData['dailyGoal'] as num?)?.toInt() ??
                                  _dailyGoal;
                          final totalCalories =
                              (dayData['totalCalories'] as num?)?.toInt() ?? 0;
                          final totalProtein =
                              (dayData['totalProtein'] as num?)?.toInt() ?? 0;
                          final totalCarbs =
                              (dayData['totalCarbs'] as num?)?.toInt() ?? 0;
                          final totalFat =
                              (dayData['totalFat'] as num?)?.toInt() ?? 0;
                          final mealCount =
                              (dayData['mealCount'] as num?)?.toInt() ?? 0;
                          final waterGlasses =
                              (dayData['waterGlasses'] as num?)?.toInt() ?? 0;
                          final waterGoal =
                              (dayData['waterGoal'] as num?)?.toInt() ??
                                  _dailyWaterGoal;
                          final progress = currentGoal <= 0
                              ? 0.0
                              : (totalCalories / currentGoal)
                                  .clamp(0, 1)
                                  .toDouble();

                          final dayDocs = _historyDays;
                          final weekDocs = dayDocs.where((doc) {
                            final date = doc['date']?.toString() ?? '';
                            return date.compareTo(weekStartKey) >= 0 &&
                                date.compareTo(weekEndKey) <= 0;
                          }).toList();
                          Map<String, dynamic>? selectedHistoryData;
                          for (final day in dayDocs) {
                            if (day['date']?.toString() ==
                                _selectedHistoryDateKey) {
                              selectedHistoryData = day;
                              break;
                            }
                          }
                          if (_selectedHistoryDateKey == _todayKey) {
                            selectedHistoryData = dayData;
                          }
                          final weeklyCalories =
                              _weeklyTotal(weekDocs, 'totalCalories');
                          final weeklyProtein =
                              _weeklyTotal(weekDocs, 'totalProtein');
                          final weeklyCarbs =
                              _weeklyTotal(weekDocs, 'totalCarbs');
                          final weeklyFat = _weeklyTotal(weekDocs, 'totalFat');

                          return RefreshIndicator(
                            onRefresh: _loadCalorieData,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDailyProgressCard(
                                    totalCalories: totalCalories,
                                    currentGoal: currentGoal,
                                    totalCarbs: totalCarbs,
                                    totalProtein: totalProtein,
                                    totalFat: totalFat,
                                    mealCount: mealCount,
                                    progress: progress,
                                  ),
                                  const SizedBox(height: 18),
                                  _buildWaterTracker(
                                    waterGlasses: waterGlasses,
                                    waterGoal: waterGoal,
                                  ),
                                  const SizedBox(height: 18),
                                  _buildTodayEntriesCard(_todayEntries),
                                  const SizedBox(height: 18),
                                  _buildSoftSection(
                                    title: 'Preset Foods',
                                    trailing: TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _showPresetFoods = !_showPresetFoods;
                                        });
                                      },
                                      child: Text(
                                        _showPresetFoods ? 'Hide' : 'Show',
                                      ),
                                    ),
                                    child: _showPresetFoods
                                        ? Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children:
                                                _presetFoods.map((preset) {
                                              return ActionChip(
                                                label: Text(preset.name),
                                                onPressed: () =>
                                                    _applyPresetFood(preset),
                                              );
                                            }).toList(),
                                          )
                                        : Text(
                                            'Show quick picks for common foods and portion ideas.',
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.72),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildSoftSection(
                                    key: _addMealSectionKey,
                                    title: 'Add Meal',
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildRecentFoods(),
                                        _buildMealTypeSelector(),
                                        const SizedBox(height: 12),
                                        _buildCapturedMealFieldsHint(),
                                        RawAutocomplete<_NutritionLookupResult>(
                                          textEditingController:
                                              _mealController,
                                          focusNode: _mealFocusNode,
                                          optionsBuilder: (textEditingValue) =>
                                              _localFoodOptions(
                                                  textEditingValue.text),
                                          displayStringForOption: (option) =>
                                              option.displayName,
                                          onSelected: _applyLookupResult,
                                          optionsViewBuilder:
                                              (context, onSelected, options) {
                                            final popupTheme =
                                                Theme.of(context);
                                            final popupColors =
                                                popupTheme.colorScheme;
                                            return Align(
                                              alignment: Alignment.topLeft,
                                              child: Material(
                                                elevation: 4,
                                                color: popupColors.surface,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child: ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                    maxHeight: 220,
                                                    maxWidth: 360,
                                                  ),
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.zero,
                                                    shrinkWrap: true,
                                                    itemCount: options.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      final option = options
                                                          .elementAt(index);
                                                      return ListTile(
                                                        title: Text(
                                                          option.quantity ==
                                                                  null
                                                              ? option
                                                                  .displayName
                                                              : '${_formatQuantity(option.quantity!)} ${_measurementUnitLabels[option.unit] ?? option.unit ?? ''} ${option.displayName}',
                                                          style: TextStyle(
                                                            color: popupColors
                                                                .onSurface,
                                                          ),
                                                        ),
                                                        subtitle: Text(
                                                          '${option.calories} kcal · ${option.subtitle ?? ''}',
                                                          style: TextStyle(
                                                            color: popupColors
                                                                .onSurface
                                                                .withValues(
                                                                    alpha:
                                                                        0.72),
                                                          ),
                                                        ),
                                                        onTap: () =>
                                                            onSelected(option),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          fieldViewBuilder: (
                                            context,
                                            textEditingController,
                                            focusNode,
                                            onFieldSubmitted,
                                          ) {
                                            return TextField(
                                              controller: textEditingController,
                                              focusNode: focusNode,
                                              onChanged: (value) {
                                                _handleMealNameChanged(value);
                                              },
                                              decoration:
                                                  _themedInputDecoration(
                                                theme: theme,
                                                labelText: 'Food Name',
                                                hintText: _mealPhotoPath == null
                                                    ? 'e.g. adobo, 2 eggs, 150g rice'
                                                    : 'Detected food name',
                                                helperText: _basis != null
                                                    ? 'Change the amount below and calories update automatically.'
                                                    : _mealPhotoPath == null
                                                        ? 'Pick a match to fill calories automatically.'
                                                        : 'Review the detected food name before saving.',
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _quantityController,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                  decimal: true,
                                                ),
                                                onChanged: (_) =>
                                                    _handlePortionChanged(),
                                                decoration:
                                                    _themedInputDecoration(
                                                  theme: theme,
                                                  labelText: 'Amount',
                                                  hintText: '1',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: DropdownButtonFormField<
                                                  String>(
                                                key: ValueKey(
                                                    '${_basis?.name}-$_selectedMeasurementUnit'),
                                                initialValue:
                                                    _selectedMeasurementUnit,
                                                style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface,
                                                ),
                                                dropdownColor:
                                                    theme.colorScheme.surface,
                                                decoration:
                                                    _themedInputDecoration(
                                                  theme: theme,
                                                  labelText:
                                                      _mealPhotoPath == null
                                                          ? 'Measurement'
                                                          : 'Unit',
                                                ),
                                                items:
                                                    _availableUnits.map((unit) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: unit,
                                                    child: Text(
                                                      _measurementUnitLabels[
                                                              unit] ??
                                                          unit,
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (value) {
                                                  if (value == null) return;
                                                  setState(() {
                                                    _selectedMeasurementUnit =
                                                        value;
                                                  });
                                                  _handlePortionChanged();
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_portionMessage != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Text(
                                              _portionMessage!,
                                              style: TextStyle(
                                                color: theme.colorScheme.error,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        if (_isSearchingSuggestions)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: LinearProgressIndicator(
                                                minHeight: 3),
                                          ),
                                        if (_onlineSuggestions.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Suggestions',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: theme
                                                        .colorScheme.onSurface,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                ..._onlineSuggestions
                                                    .map((suggestion) {
                                                  return ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    title: Text(
                                                      suggestion.displayName,
                                                      style: TextStyle(
                                                        color: theme.colorScheme
                                                            .onSurface,
                                                      ),
                                                    ),
                                                    subtitle: Text(
                                                      '${suggestion.calories} kcal ${suggestion.subtitle == null ? '' : '· ${suggestion.subtitle}'}\nP ${suggestion.protein}g  C ${suggestion.carbs}g  F ${suggestion.fat}g',
                                                      style: TextStyle(
                                                        color: theme.colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.72),
                                                      ),
                                                    ),
                                                    trailing: Icon(
                                                      Icons.north_west,
                                                      color: theme
                                                          .colorScheme.primary,
                                                    ),
                                                    onTap: () =>
                                                        _applyLookupResult(
                                                            suggestion),
                                                  );
                                                }),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (OllamaNutritionService
                                            .isConfigured) ...[
                                          const SizedBox(height: 12),
                                          _buildOllamaStatusBanner(),
                                        ],
                                        const SizedBox(height: 12),
                                        Material(
                                          color: theme.colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          child: InkWell(
                                            onTap: _isLookingUpFood ||
                                                    _isCapturingMealPhoto
                                                ? null
                                                : _openScanOptions,
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 46,
                                                    height: 46,
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme
                                                          .primaryContainer,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .center_focus_weak_rounded,
                                                      color: theme
                                                          .colorScheme.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Quick Scan',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurface,
                                                          ),
                                                        ),
                                                        SizedBox(height: 2),
                                                        Text(
                                                          'Open camera or barcode scanner',
                                                          style: TextStyle(
                                                            color: theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                    alpha:
                                                                        0.72),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    _isCapturingMealPhoto
                                                        ? 'Opening...'
                                                        : _isLookingUpFood
                                                            ? 'Loading...'
                                                            : 'Open',
                                                    style: TextStyle(
                                                      color: theme
                                                          .colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        _buildMealPhotoPreview(),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _numberField(
                                              _calorieController,
                                              'Calories',
                                              hint: '200',
                                              suffix: 'kcal',
                                            ),
                                            const SizedBox(width: 10),
                                            _numberField(
                                              _proteinController,
                                              'Protein',
                                              hint: '20',
                                              suffix: 'g',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            _numberField(
                                              _carbController,
                                              'Carbs',
                                              hint: '30',
                                              suffix: 'g',
                                            ),
                                            const SizedBox(width: 10),
                                            _numberField(
                                              _fatController,
                                              'Fat',
                                              hint: '10',
                                              suffix: 'g',
                                            ),
                                          ],
                                        ),
                                        _buildNutritionPreview(),
                                        const SizedBox(height: 14),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _isLookingUpFood
                                                ? null
                                                : _addMeal,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  theme.colorScheme.primary,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 15),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                            child: Text(
                                              _isLookingUpFood
                                                  ? 'Saving...'
                                                  : _calorieController.text
                                                          .trim()
                                                          .isEmpty
                                                      ? 'Find Calories'
                                                      : 'Add Entry',
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildSoftSection(
                                    title: 'History',
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildHistoryCalendarStrip(dayDocs),
                                        const SizedBox(height: 18),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${isCurrentWeek ? 'This Week' : _historyWeekLabel(_historyWeekStart)}: $weeklyCalories kcal',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme
                                                      .colorScheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Protein: ${weeklyProtein}g',
                                                style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.72),
                                                ),
                                              ),
                                              Text(
                                                'Carbs: ${weeklyCarbs}g',
                                                style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.72),
                                                ),
                                              ),
                                              Text(
                                                'Fat: ${weeklyFat}g',
                                                style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.72),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        _buildSoftSection(
                                          title: 'Selected Day',
                                          child: _buildSelectedDayHistoryCard(
                                              selectedHistoryData),
                                        ),
                                        const SizedBox(height: 12),
                                        if (dayDocs.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 8),
                                            child:
                                                Text('No calorie history yet.'),
                                          )
                                        else
                                          ...dayDocs.map((day) {
                                            final dateKey =
                                                day['date']?.toString() ?? '';
                                            return Card(
                                              margin: const EdgeInsets.only(
                                                  bottom: 10),
                                              elevation: 0,
                                              color: theme.colorScheme
                                                  .surfaceContainerHighest,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              child: ListTile(
                                                title: Text(
                                                  dateKey,
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme.onSurface,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  '${(day['totalCalories'] as num?)?.toInt() ?? 0} kcal - '
                                                  'P ${(day['totalProtein'] as num?)?.toInt() ?? 0}g - '
                                                  'C ${(day['totalCarbs'] as num?)?.toInt() ?? 0}g - '
                                                  'F ${(day['totalFat'] as num?)?.toInt() ?? 0}g',
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme.onSurface
                                                        .withValues(
                                                            alpha: 0.72),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PresetFood extends CalorieFoodPreset {
  const _PresetFood({
    required super.name,
    required super.calories,
    required super.protein,
    required super.carbs,
    required super.fat,
    required super.aliases,
    required super.defaultUnit,
    required super.gramsPerUnit,
  });
}

class _NutritionLookupResult {
  const _NutritionLookupResult({
    required this.basis,
    this.subtitle,
    this.quantity,
    this.unit,
  });

  final FoodNutritionBasis basis;
  final String? subtitle;

  /// Portion to preselect; defaults to one serving of [basis].
  final double? quantity;
  final String? unit;

  String get displayName => basis.name;

  NutritionValues get _portion =>
      basis.scaled(
          quantity ?? basis.servingQuantity, unit ?? basis.servingUnit) ??
      basis.perServing;

  int get calories => _portion.roundedCalories;
  int get protein => _portion.roundedProtein;
  int get carbs => _portion.roundedCarbs;
  int get fat => _portion.roundedFat;
}

class _ArcProgressPainter extends CustomPainter {
  const _ArcProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final strokeWidth = size.width * 0.055;
    final segmentCount = 22;
    final gap = 0.06;
    const startAngle = 3.141592653589793;
    const sweepAngle = 3.141592653589793;
    final radius = size.width * 0.38;
    final center = Offset(size.width / 2, size.height * 0.84);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final segmentSweep = (sweepAngle - (segmentCount - 1) * gap) / segmentCount;
    final activeSegments = (segmentCount * clampedProgress).round();

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (var index = 0; index < segmentCount; index++) {
      final segmentStart = startAngle + index * (segmentSweep + gap);
      canvas.drawArc(
        rect,
        segmentStart,
        segmentSweep,
        false,
        index < activeSegments ? progressPaint : backgroundPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor;
  }
}
