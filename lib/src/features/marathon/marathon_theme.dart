import 'package:flutter/material.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';

/// Look of a marathon: its colours, art and the kit runners' walkers wear.
/// Keys match `Marathon::THEMES` on the backend. A 'custom' theme (made
/// with AI) carries its own colours in the marathon's theme data.
class MarathonTheme {
  const MarathonTheme({
    required this.key,
    required this.name,
    required this.emoji,
    required this.gradient,
    required this.kitTop,
    required this.kitBottom,
    required this.kitShoes,
    this.kitStyle = WalkerTop.tee,
    this.accessory,
  });

  static const customKey = 'custom';

  final String key;
  final String name;
  final String emoji;
  final List<Color> gradient;
  final Color kitTop;
  final Color kitBottom;
  final Color kitShoes;
  final WalkerTop kitStyle;

  /// Worn with the kit; null keeps the runner's own accessory.
  final WalkerAccessory? accessory;

  Color get accent => gradient.last;

  static const all = <MarathonTheme>[
    MarathonTheme(
      key: 'sunrise',
      name: 'Sunrise',
      emoji: '🌅',
      gradient: [Color(0xFFFF9A44), Color(0xFFFC6076)],
      kitTop: Color(0xFFFF7043),
      kitBottom: Color(0xFF37474F),
      kitShoes: Color(0xFFFFC93C),
    ),
    MarathonTheme(
      key: 'ocean',
      name: 'Ocean',
      emoji: '🌊',
      gradient: [Color(0xFF2193B0), Color(0xFF0B5E8C)],
      kitTop: Color(0xFF0288D1),
      kitBottom: Color(0xFF263238),
      kitShoes: Color(0xFF4DD0E1),
    ),
    MarathonTheme(
      key: 'forest',
      name: 'Forest',
      emoji: '🌲',
      gradient: [Color(0xFF71B280), Color(0xFF134E5E)],
      kitTop: Color(0xFF2E7D32),
      kitBottom: Color(0xFF3E2723),
      kitShoes: Color(0xFF9CCC65),
    ),
    MarathonTheme(
      key: 'sakura',
      name: 'Sakura',
      emoji: '🌸',
      gradient: [Color(0xFFFFB7C5), Color(0xFFE75480)],
      kitTop: Color(0xFFF48FB1),
      kitBottom: Color(0xFF6D4C41),
      kitShoes: Color(0xFFFFFFFF),
    ),
    MarathonTheme(
      key: 'neon_night',
      name: 'Neon Night',
      emoji: '⚡',
      gradient: [Color(0xFF8E2DE2), Color(0xFF141E30)],
      kitTop: Color(0xFF7C4DFF),
      kitBottom: Color(0xFF1B1B1B),
      kitShoes: Color(0xFF00E5FF),
    ),
    MarathonTheme(
      key: 'holiday',
      name: 'Holiday',
      emoji: '🎄',
      gradient: [Color(0xFFD32F2F), Color(0xFF1B5E20)],
      kitTop: Color(0xFFD32F2F),
      kitBottom: Color(0xFF1B5E20),
      kitShoes: Color(0xFFFFFFFF),
    ),
    MarathonTheme(
      key: 'independence',
      name: 'Kalayaan',
      emoji: '🇵🇭',
      gradient: [Color(0xFF0038A8), Color(0xFFCE1126)],
      kitTop: Color(0xFF0038A8),
      kitBottom: Color(0xFFCE1126),
      kitShoes: Color(0xFFFCD116),
    ),
    MarathonTheme(
      key: 'undersea',
      name: 'Under the Sea',
      emoji: '🫧',
      gradient: [Color(0xFF4FC3F7), Color(0xFF01579B)],
      kitTop: Color(0xFFFFEB3B),
      kitBottom: Color(0xFF795548),
      kitShoes: Color(0xFF1B1B1B),
    ),
  ];

  /// The theme for [key]; a custom one is read from [data].
  static MarathonTheme of(String? key, [Map<String, dynamic>? data]) {
    if (key == customKey) {
      return data == null ? _customFallback : MarathonTheme.fromData(data);
    }
    return all.firstWhere((theme) => theme.key == key, orElse: () => all.first);
  }

  /// A custom theme from the backend's theme data (hex colours).
  factory MarathonTheme.fromData(Map<String, dynamic> data) {
    final gradient = data['gradient'] is List
        ? (data['gradient'] as List).map((c) => _hex(c, null)).toList()
        : const <Color?>[];
    final fallback = _customFallback;
    final accessory = data['accessory']?.toString();
    return MarathonTheme(
      key: customKey,
      name: (data['name']?.toString().trim().isNotEmpty ?? false)
          ? data['name'].toString().trim()
          : fallback.name,
      emoji: (data['emoji']?.toString().trim().isNotEmpty ?? false)
          ? data['emoji'].toString().trim()
          : fallback.emoji,
      gradient: [
        (gradient.isNotEmpty ? gradient.first : null) ??
            fallback.gradient.first,
        (gradient.length > 1 ? gradient[1] : null) ?? fallback.gradient.last,
      ],
      kitTop: _hex(data['kitTop'], fallback.kitTop)!,
      kitBottom: _hex(data['kitBottom'], fallback.kitBottom)!,
      kitShoes: _hex(data['kitShoes'], fallback.kitShoes)!,
      kitStyle: WalkerTop.values.firstWhere((t) => t.name == data['top'],
          orElse: () => WalkerTop.tee),
      accessory: accessory == null
          ? null
          : WalkerAccessory.values
              .where((a) => a.name == accessory)
              .firstOrNull,
    );
  }

  /// A custom theme whose colours are not known here (e.g. a kit label).
  static const _customFallback = MarathonTheme(
    key: customKey,
    name: 'Marathon',
    emoji: '🏅',
    gradient: [Color(0xFFFF9A44), Color(0xFFFC6076)],
    kitTop: Color(0xFFFF7043),
    kitBottom: Color(0xFF37474F),
    kitShoes: Color(0xFFFFC93C),
  );

  static Color? _hex(dynamic value, Color? fallback) {
    final hex = value?.toString().replaceFirst('#', '') ?? '';
    final parsed = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
    return parsed == null ? fallback : Color(0xFF000000 | parsed);
  }

  /// [look] dressed in this marathon's kit with the runner's [bib].
  WalkerLook dress(WalkerLook look, int bib) => look.copyWith(
        top: kitStyle,
        accessory: accessory,
        topColor: kitTop,
        bottomColor: kitBottom,
        shoeColor: kitShoes,
        kit: key,
        bib: bib,
      );
}

extension MarathonLook on Marathon {
  /// This marathon's theme, including an AI-made one.
  MarathonTheme get look => MarathonTheme.of(theme, themeData);
}
