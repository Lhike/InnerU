import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selfcare_projects/src/features/abundance/services/abundance_tutorial_service.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_math.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_steps.dart';

class AbundanceTutorialController extends ChangeNotifier {
  AbundanceTutorialController({
    required this.uid,
    required Set<AbundanceTutorialRole> roles,
    AbundanceTutorialService? service,
    List<AbundanceTutorialStep>? stepsOverride,
    this.completionSaver,
  })  : steps = stepsOverride ?? abundanceTutorialStepsFor(roles),
        _service = service ?? AbundanceTutorialService();

  final String uid;
  final List<AbundanceTutorialStep> steps;
  final AbundanceTutorialService _service;
  final Future<void> Function(String uid)? completionSaver;
  final Map<String, AbundanceTutorialRect> targetRects = {};
  bool active = false;
  int stepIndex = 0;
  String? currentRoute;
  String? error;
  bool pending = false;

  AbundanceTutorialStep get step => steps[stepIndex];

  void start() {
    active = true;
    stepIndex = 0;
    error = null;
    targetRects.clear();
    notifyListeners();
  }

  void registerTarget(String name, AbundanceTutorialRect rect) {
    targetRects[name] = rect;
    notifyListeners();
  }

  void unregisterTarget(String name) {
    targetRects.remove(name);
    notifyListeners();
  }

  void setCurrentRoute(String route) {
    currentRoute = route;
    notifyListeners();
  }

  void next() {
    if (stepIndex < steps.length - 1) {
      stepIndex++;
      error = null;
      notifyListeners();
    }
  }

  void back() {
    if (stepIndex > 0) {
      stepIndex--;
      error = null;
      notifyListeners();
    }
  }

  Future<void> skip() => finish();

  Future<void> finish() async {
    if (pending) return;
    pending = true;
    error = null;
    notifyListeners();
    try {
      try {
        if (completionSaver != null) {
          await completionSaver!(uid);
        } else {
          await _service.complete();
        }
      } catch (_) {
        final preferences = await SharedPreferences.getInstance();
        final saved = await preferences.setBool(
          'abundance_tutorial_done_$uid',
          true,
        );
        if (!saved) rethrow;
      }
      active = false;
    } catch (cause) {
      error = 'Your tutorial progress could not be saved. Please try again.';
    } finally {
      pending = false;
      notifyListeners();
    }
  }
}
