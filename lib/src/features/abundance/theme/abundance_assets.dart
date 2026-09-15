/// Image asset paths for the Abundance Quests redesign, ported from
/// `A12-Tracker/src/components/ui/rank-medal.tsx` (`RANK_SRC`) and
/// `A12-Tracker/src/components/ui/scene.tsx` (`SCENES`). A12 collapses its
/// 10 rank keys onto 5 actual image files — this mirrors that exact
/// many-to-one mapping rather than commissioning new art for the collapsed
/// tiers.
const String _ranksBase = 'assets/images/abundance/ranks';
const String _scenesBase = 'assets/images/abundance/scenes';
const String _brandBase = 'assets/images/abundance/brand';
const String _charactersBase = 'assets/images/abundance/characters';
const String _achievementsBase = 'assets/images/abundance/achievements';

const String abundanceLogoAsset = '$_brandBase/a12-logo.png';
const String abundanceHomeSceneAsset = '$_scenesBase/bg2.webp';

const List<String> abundanceCharacterKeys = <String>[
  'warrior',
  'ranger',
  'mage',
  'healer',
  'guardian',
  'paladin',
  'vanguard',
  'rogue',
  'sage',
  'artificer',
];

String? abundanceCharacterAsset(String key) {
  final normalized = key.trim().toLowerCase();
  return abundanceCharacterKeys.contains(normalized)
      ? '$_charactersBase/$normalized.webp'
      : null;
}

const Map<String, String> abundanceAchievementAssets = <String, String>{
  'first-flame': '$_achievementsBase/first-flame.png',
  'finding-rythm': '$_achievementsBase/finding-rythm.png',
  '30-days-strong': '$_achievementsBase/30-days-strong.png',
  'unbroken': '$_achievementsBase/unbroken.png',
  'discipline': '$_achievementsBase/discipline.png',
  'finished-first': '$_achievementsBase/finished-first.png',
  'closer': '$_achievementsBase/closer.png',
  'quest-architect': '$_achievementsBase/quest-architect.png',
  'high-performer': '$_achievementsBase/high-performer.png',
  'abundance-elite': '$_achievementsBase/abundance-elite.png',
};

const Map<String, String> _rankMedalAssets = {
  'HERALD': '$_ranksBase/archon.png',
  'GUARDIAN': '$_ranksBase/archon.png',
  'CRUSADER': '$_ranksBase/archon.png',
  'ARCHON': '$_ranksBase/archon.png',
  'LEGEND': '$_ranksBase/legend.png',
  'ANCIENT': '$_ranksBase/ancient.png',
  'DIVINE': '$_ranksBase/divine.png',
  'IMMORTAL': '$_ranksBase/immortal.png',
  'MASTER_IMMORTAL': '$_ranksBase/immortal.png',
  'TITAN': '$_ranksBase/immortal.png',
};

/// [rankKey] is a `GoalRank.key` value. Falls back to `archon.png` (the
/// lowest-tier art) for any key not in the current 10-tier ladder rather
/// than throwing, since this is purely decorative.
String abundanceRankMedalAsset(String rankKey) =>
    _rankMedalAssets[rankKey] ?? '$_ranksBase/archon.png';

const Map<String, String> _questSceneAssets = {
  'PERSONAL': '$_scenesBase/quest-personal.webp',
  'PROFESSIONAL': '$_scenesBase/quest-professional.webp',
  'CONTRIBUTION': '$_scenesBase/quest-contribution.webp',
};

/// [categoryCode] is a `GoalCategory.code` value. Returns `null` for
/// anything outside the three known categories so callers can fall back to
/// a plain tinted background instead of crashing.
String? abundanceQuestSceneAsset(String categoryCode) =>
    _questSceneAssets[categoryCode];

/// The ambient backdrop art used behind the Quests screens (not the whole
/// app shell — see the design spec's "Image assets" section for why).
const String abundanceBackdropAsset = '$_scenesBase/hero-dark.webp';

final List<String> abundanceExperienceAssets = <String>{
  abundanceLogoAsset,
  abundanceHomeSceneAsset,
  abundanceBackdropAsset,
  ..._rankMedalAssets.values,
  ..._questSceneAssets.values,
  ...abundanceCharacterKeys.map((key) => '$_charactersBase/$key.webp'),
  ...abundanceAchievementAssets.values,
}.toList(growable: false);
