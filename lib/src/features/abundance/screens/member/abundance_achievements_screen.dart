import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';

class _AwardDefinition {
  const _AwardDefinition(this.key, this.name, this.description);
  final String key;
  final String name;
  final String description;
}

const _awards = <_AwardDefinition>[
  _AwardDefinition(
      'first-flame', 'First Flame', 'Complete your first mission.'),
  _AwardDefinition('finding-rythm', 'Finding Rhythm', 'Build a steady streak.'),
  _AwardDefinition(
      '30-days-strong', '30 Days Strong', 'Show up for thirty days.'),
  _AwardDefinition('unbroken', 'Unbroken', 'Protect an exceptional streak.'),
  _AwardDefinition(
      'discipline', 'Discipline', 'Master your everyday missions.'),
  _AwardDefinition(
      'finished-first', 'Finished First', 'Complete your first quest.'),
  _AwardDefinition('closer', 'Closer', 'Bring several quests to completion.'),
  _AwardDefinition(
      'quest-architect', 'Quest Architect', 'Build a complete quest plan.'),
  _AwardDefinition(
      'high-performer', 'High Performer', 'Raise your Life Power.'),
  _AwardDefinition(
      'abundance-elite', 'Abundance Elite', 'Reach the highest standard.'),
  _AwardDefinition(
      'tended-ground', 'Tended Ground', 'Complete a personal quest.'),
  _AwardDefinition(
      'forged-craft', 'Forged Craft', 'Complete a professional quest.'),
  _AwardDefinition(
      'given-freely', 'Given Freely', 'Complete a contribution quest.'),
  _AwardDefinition('immovable', 'Immovable', 'Keep a 20-day streak.'),
  _AwardDefinition('examine-life', 'Examined Life', 'Reflect on your days.'),
];

class AbundanceAchievementsScreen extends StatefulWidget {
  const AbundanceAchievementsScreen({
    super.key,
    this.unlockedKeys = const <String>{},
    this.loader,
  });

  final Set<String> unlockedKeys;
  final Future<Set<String>> Function()? loader;

  @override
  State<AbundanceAchievementsScreen> createState() =>
      _AbundanceAchievementsScreenState();
}

class _AbundanceAchievementsScreenState
    extends State<AbundanceAchievementsScreen> {
  Future<Set<String>>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader?.call();
  }

  void _retry() => setState(() => _future = widget.loader?.call());

  Future<void> _refresh() async {
    final loader = widget.loader;
    if (loader == null) return;
    final future = loader();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) return _content(widget.unlockedKeys);
    return FutureBuilder<Set<String>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ColoredBox(
            color: AbundanceColors.background,
            child: Center(
              child:
                  CircularProgressIndicator(color: AbundanceColors.primaryGold),
            ),
          );
        }
        if (snapshot.hasError) {
          return ColoredBox(
            color: AbundanceColors.background,
            child: Center(
              child: AbundanceButton(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: _retry,
              ),
            ),
          );
        }
        return _content(snapshot.data ?? const <String>{});
      },
    );
  }

  Widget _content(Set<String> unlockedKeys) {
    final earned = _awards
        .where((award) => unlockedKeys.contains(award.key))
        .toList(growable: false);
    final locked = _awards
        .where((award) => !unlockedKeys.contains(award.key))
        .toList(growable: false);
    final discipline = _awards.sublist(0, 5);
    final realms = _awards.sublist(10, 13);
    final quests = _awards.sublist(5, 8);
    final lifePower = _awards.sublist(8, 10);
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 104),
      children: [
        const Text('THE HALL OF RECORDS', style: AbundanceTypography.eyebrow),
        const SizedBox(height: 6),
        const Text(
          'Achievements',
          style: TextStyle(
            color: AbundanceColors.foreground,
            fontFamily: AbundanceTypography.displayFamily,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Proof of the days you showed up. Every relic is earned, never given.',
          style: TextStyle(
              color: AbundanceColors.muted, fontSize: 13, height: 1.46),
        ),
        const SizedBox(height: 16),
        _SummaryRow(
            unlocked: earned.length, inProgress: 0, locked: locked.length),
        if (earned.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('RECENTLY UNLOCKED', style: AbundanceTypography.eyebrow),
          const SizedBox(height: 10),
          _AwardGrid(awards: earned, unlockedKeys: unlockedKeys),
        ],
        for (final section in <({String title, List<_AwardDefinition> awards})>[
          (title: 'DISCIPLINE', awards: discipline),
          (title: 'THE THREE REALMS', awards: realms),
          (title: 'QUESTS', awards: quests),
          (title: 'LIFE POWER', awards: lifePower),
        ]) ...[
          const SizedBox(height: 16),
          Text(section.title, style: AbundanceTypography.eyebrow),
          const SizedBox(height: 10),
          _AwardGrid(awards: section.awards, unlockedKeys: unlockedKeys),
        ],
      ],
    );
    return ColoredBox(
      color: AbundanceColors.background,
      child: widget.loader == null
          ? list
          : RefreshIndicator(onRefresh: _refresh, child: list),
    );
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({required this.award, required this.unlocked});
  final _AwardDefinition award;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : .52,
      child: AbundanceCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: unlocked
                  ? Image.asset(abundanceAchievementAssets[award.key]!,
                      fit: BoxFit.contain)
                  : const _LockedRelic(),
            ),
            const SizedBox(height: 8),
            Text(
              award.name,
              style: AbundanceTypography.title.copyWith(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              award.description,
              style: AbundanceTypography.body
                  .copyWith(color: AbundanceColors.muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(unlocked ? 'UNLOCKED' : 'LOCKED',
                style: TextStyle(
                  color: unlocked
                      ? AbundanceColors.accentCyan
                      : AbundanceColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                )),
          ],
        ),
      ),
    );
  }
}

class _AwardGrid extends StatelessWidget {
  const _AwardGrid({required this.awards, required this.unlockedKeys});
  final List<_AwardDefinition> awards;
  final Set<String> unlockedKeys;

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: awards.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: .92,
        ),
        itemBuilder: (_, index) => _AwardCard(
          award: awards[index],
          unlocked: unlockedKeys.contains(awards[index].key),
        ),
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.unlocked, required this.inProgress, required this.locked});
  final int unlocked;
  final int inProgress;
  final int locked;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _SummaryStat(
              value: unlocked,
              label: 'UNLOCKED',
              color: AbundanceColors.accentCyan),
          const SizedBox(width: 8),
          _SummaryStat(
              value: inProgress,
              label: 'IN PROGRESS',
              color: AbundanceColors.primaryGold),
          const SizedBox(width: 8),
          _SummaryStat(
              value: locked, label: 'LOCKED', color: AbundanceColors.muted),
        ],
      );
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat(
      {required this.value, required this.label, required this.color});
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: AbundanceCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Column(children: [
            Text('$value',
                style: TextStyle(
                    color: color,
                    fontFamily: AbundanceTypography.displayFamily,
                    fontSize: 20)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: AbundanceColors.muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6)),
          ]),
        ),
      );
}

class _LockedRelic extends StatelessWidget {
  const _LockedRelic();
  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            color: AbundanceColors.surfaceSunken,
            shape: BoxShape.circle,
            border: Border.all(color: AbundanceColors.border, width: 2)),
        child: const Center(
            child: Text('▣',
                style: TextStyle(color: AbundanceColors.muted, fontSize: 20))),
      );
}
