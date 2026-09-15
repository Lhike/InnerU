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
    final earned = _awards.where((award) => unlockedKeys.contains(award.key));
    final locked = _awards.where((award) => !unlockedKeys.contains(award.key));
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text('ACHIEVEMENTS', style: AbundanceTypography.eyebrow),
        const SizedBox(height: 6),
        const Text('Your legacy', style: AbundanceTypography.display),
        const SizedBox(height: 8),
        Text(
          '${earned.length} of ${_awards.length} earned',
          style:
              AbundanceTypography.body.copyWith(color: AbundanceColors.muted),
        ),
        const SizedBox(height: 22),
        if (earned.isNotEmpty) ...[
          const Text('EARNED', style: AbundanceTypography.eyebrow),
          const SizedBox(height: 10),
          ...earned.map((award) => _AwardCard(award: award, unlocked: true)),
          const SizedBox(height: 18),
        ],
        const Text('LOCKED', style: AbundanceTypography.eyebrow),
        const SizedBox(height: 10),
        ...locked.map((award) => _AwardCard(award: award, unlocked: false)),
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
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: unlocked
                  ? Image.asset(abundanceAchievementAssets[award.key]!)
                  : const Icon(Icons.lock_outline,
                      color: AbundanceColors.muted, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(award.name, style: AbundanceTypography.title),
                  const SizedBox(height: 4),
                  Text(
                    award.description,
                    style: AbundanceTypography.body
                        .copyWith(color: AbundanceColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
