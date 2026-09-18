/// A measured target rectangle in the global coordinate space.
class AbundanceTutorialRect {
  const AbundanceTutorialRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) {
    return other is AbundanceTutorialRect &&
        other.left == left &&
        other.top == top &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

enum AbundanceTutorialSheetPlacement { top, bottom }

const Map<String, Set<String>> _tutorialRouteAliases = <String, Set<String>>{
  '/(tabs)': <String>{'/(tabs)', '/', '/dashboard', '/home'},
  '/missions': <String>{'/missions', '/daily'},
  '/quests': <String>{'/quests', '/goals'},
  '/achievements': <String>{'/achievements', '/awards'},
  '/guild': <String>{'/guild', '/allies'},
  '/profile': <String>{'/profile'},
};

String _canonicalTutorialRoute(String route) {
  for (final entry in _tutorialRouteAliases.entries) {
    if (entry.value.contains(route)) return entry.key;
  }
  return route;
}

/// Returns the requested route only when it is not already represented by the
/// current shell route. A null tutorial route needs no navigation.
String? tutorialRouteFor(String? route, String currentRoute) {
  if (route == null) return null;

  if (_canonicalTutorialRoute(route) == _canonicalTutorialRoute(currentRoute)) {
    return null;
  }
  return route;
}

/// Calculates the new scroll offset needed to place a target in the readable
/// part of a scroll viewport, or null when it is already visible there.
double? tutorialScrollOffset({
  required double targetTop,
  required double targetHeight,
  required double viewportTop,
  required double currentOffset,
  required double viewportHeight,
}) {
  final localTop = targetTop - viewportTop;
  final targetBottom = localTop + targetHeight;
  if (localTop >= 90 && targetBottom <= viewportHeight - 250) return null;

  final desiredTop = (viewportHeight * 0.4).roundToDouble() - viewportTop;
  final boundedDesiredTop = desiredTop < 24 ? 24 : desiredTop;
  final requestedOffset =
      (currentOffset + localTop - boundedDesiredTop).roundToDouble();
  return requestedOffset < 0 ? 0 : requestedOffset;
}

/// Chooses the side on which a tutorial sheet can explain a target without
/// covering it, respecting the supplied safe-area bounds.
AbundanceTutorialSheetPlacement tutorialSheetPlacement({
  required double? targetTop,
  required double? targetBottom,
  required double sheetHeight,
  required double safeTop,
  required double safeBottom,
  required double gap,
}) {
  if (targetTop == null || targetBottom == null) {
    return AbundanceTutorialSheetPlacement.bottom;
  }

  if (targetTop - safeTop - gap >= sheetHeight) {
    return AbundanceTutorialSheetPlacement.top;
  }
  if (safeBottom - targetBottom - gap >= sheetHeight) {
    return AbundanceTutorialSheetPlacement.bottom;
  }

  return targetTop - safeTop >= safeBottom - targetBottom
      ? AbundanceTutorialSheetPlacement.top
      : AbundanceTutorialSheetPlacement.bottom;
}
