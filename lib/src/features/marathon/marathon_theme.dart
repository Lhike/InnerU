import 'package:flutter/material.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';

/// Look of a marathon: its colours, art and the kit runners' walkers wear.
/// Keys match `Marathon::THEMES` on the backend.
class MarathonTheme {
  const MarathonTheme({
    required this.key,
    required this.name,
    required this.emoji,
    required this.gradient,
    required this.kitTop,
    required this.kitBottom,
    required this.kitShoes,
  });

  final String key;
  final String name;
  final String emoji;
  final List<Color> gradient;
  final Color kitTop;
  final Color kitBottom;
  final Color kitShoes;

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

  static MarathonTheme of(String? key) =>
      all.firstWhere((theme) => theme.key == key, orElse: () => all.first);

  /// [look] dressed in this marathon's kit with the runner's [bib].
  WalkerLook dress(WalkerLook look, int bib) => look.copyWith(
        top: WalkerTop.tee,
        topColor: kitTop,
        bottomColor: kitBottom,
        shoeColor: kitShoes,
        kit: key,
        bib: bib,
      );
}
