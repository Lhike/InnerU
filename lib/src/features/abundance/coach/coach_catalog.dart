import 'dart:convert';

import 'package:flutter/services.dart';

class AbundanceCoachCatalogEntry {
  const AbundanceCoachCatalogEntry({
    required this.name,
    required this.declaration,
    required this.background,
    required this.assetPath,
  });

  final String name;
  final String declaration;
  final List<String> background;
  final String assetPath;
}

class AbundanceCoachCatalog {
  AbundanceCoachCatalog._();

  static const String catalogAsset = 'assets/data/a12_coaches.json';
  static const String coachesAssetPrefix = 'assets/images/abundance/coaches/';
  static const String fallbackAsset = 'assets/images/coachpic.png';

  static const List<String> _levelPrefixes = <String>['level1-', 'level2-'];

  static Future<List<AbundanceCoachCatalogEntry>> load() async {
    final decoded = jsonDecode(await rootBundle.loadString(catalogAsset));
    if (decoded is! List) return const <AbundanceCoachCatalogEntry>[];

    final records = decoded
        .whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .where((record) {
      return _string(record['name']).isNotEmpty &&
          _string(record['picture']).isNotEmpty;
    }).toList();
    records.sort(_compareRecords);

    return records
        .map(
          (record) => AbundanceCoachCatalogEntry(
            name: _string(record['name']),
            declaration: _string(record['declaration']),
            background: (record['background'] is List
                    ? (record['background'] as List)
                        .map((line) => line.toString().trim())
                        .where((line) => line.isNotEmpty)
                        .toList()
                    : const <String>[])
                .toList(growable: false),
            assetPath: '$coachesAssetPrefix${_string(record['picture'])}',
          ),
        )
        .toList(growable: false);
  }

  static int _compareRecords(
      Map<String, dynamic> left, Map<String, dynamic> right) {
    final leftPicture = _string(left['picture']);
    final rightPicture = _string(right['picture']);
    final levelCompare =
        _levelOf(leftPicture).compareTo(_levelOf(rightPicture));
    if (levelCompare != 0) return levelCompare;
    return _sortKey(leftPicture, left).compareTo(_sortKey(rightPicture, right));
  }

  static int _levelOf(String picture) {
    final index = _levelPrefixes.indexWhere(picture.startsWith);
    return index == -1 ? _levelPrefixes.length : index;
  }

  static String _sortKey(String picture, Map<String, dynamic> record) {
    final match = RegExp(r'^level[12]-([a-z])-').firstMatch(picture);
    return (match?.group(1) ?? _string(record['name'])).toLowerCase();
  }

  static String _string(Object? value) => value?.toString().trim() ?? '';
}
