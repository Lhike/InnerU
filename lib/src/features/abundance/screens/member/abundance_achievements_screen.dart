import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/services/abundance_achievement_presentation.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_achievements_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_tutorial_target.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_controller.dart';

/// The Awards page renders the achievement catalog supplied by the gateway.
/// The optional legacy inputs remain for old callers/tests; production callers
/// pass the typed gateway's [load] method.
class AbundanceAchievementsScreen extends StatefulWidget {
  const AbundanceAchievementsScreen({
    super.key,
    this.unlockedKeys = const <String>{},
    this.loader,
    this.tutorialController,
  });

  final Set<String> unlockedKeys;
  final Future<dynamic> Function()? loader;
  final AbundanceTutorialController? tutorialController;

  @override
  State<AbundanceAchievementsScreen> createState() =>
      _AbundanceAchievementsScreenState();
}

class _AbundanceAchievementsScreenState
    extends State<AbundanceAchievementsScreen> {
  Future<dynamic>? _future;

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
    if (_future == null) return _content(_legacyRecords(widget.unlockedKeys));
    return FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ColoredBox(
            color: AbundanceColors.background,
            child: Center(
              child: CircularProgressIndicator(
                color: AbundanceColors.primaryGold,
              ),
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
        return _content(_recordsFrom(snapshot.data));
      },
    );
  }

  Widget _content(List<AbundanceAchievementRecord> records) {
    final catalog = AbundanceAchievementCatalog.fromRecords(records);
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 104),
      children: [
        AbundanceTutorialTarget(
          name: 'achievements-overview',
          controller: widget.tutorialController,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('THE HALL OF RECORDS', style: AbundanceTypography.eyebrow),
              SizedBox(height: 6),
              Text(
                'Achievements',
                style: TextStyle(
                  color: AbundanceColors.foreground,
                  fontFamily: AbundanceTypography.displayFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Proof of the days you showed up. Every relic is earned, never given.',
                style: TextStyle(
                  color: AbundanceColors.muted,
                  fontSize: 13,
                  height: 1.46,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AbundanceTutorialTarget(
          name: 'achievements-tally',
          controller: widget.tutorialController,
          child: _SummaryRow(
            unlocked: catalog.unlocked.length,
            inProgress: catalog.inProgress.length,
            locked: catalog.locked.length,
          ),
        ),
        if (catalog.recent.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('RECENTLY UNLOCKED', style: AbundanceTypography.eyebrow),
          const SizedBox(height: 10),
          AbundanceTutorialTarget(
            name: 'achievements-wall',
            controller: widget.tutorialController,
            child: _AwardGrid(records: catalog.recent),
          ),
        ],
        for (final entry in catalog.groups.entries) ...[
          const SizedBox(height: 16),
          Text(entry.key.toUpperCase(), style: AbundanceTypography.eyebrow),
          const SizedBox(height: 10),
          AbundanceTutorialTarget(
            name: 'achievements-wall',
            controller: widget.tutorialController,
            child: _AwardGrid(records: entry.value),
          ),
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

  List<AbundanceAchievementRecord> _recordsFrom(dynamic value) {
    if (value is List<AbundanceAchievementRecord>) return value;
    if (value is Set<String>) return _legacyRecords(value);
    return _legacyRecords(const <String>{});
  }

  List<AbundanceAchievementRecord> _legacyRecords(Set<String> unlockedKeys) {
    return abundanceAchievementDefinitions.map((definition) {
      final unlocked = unlockedKeys.contains(definition.key) ||
          unlockedKeys.contains(definition.assetKey);
      return AbundanceAchievementRecord(
        definition: definition,
        current: unlocked ? definition.target : 0,
        unlocked: unlocked,
      );
    }).toList(growable: false);
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({required this.record});

  final AbundanceAchievementRecord record;

  @override
  Widget build(BuildContext context) {
    final definition = record.definition;
    final unlocked = record.unlocked;
    final inProgress = !unlocked && record.current > 0;
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
                  ? AbundanceArtwork(
                      child: Image.asset(
                        abundanceAchievementAssets[definition.assetKey]!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : const _LockedRelic(),
            ),
            const SizedBox(height: 8),
            Text(
              definition.name,
              style: AbundanceTypography.title.copyWith(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              definition.description,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: AbundanceTypography.body.copyWith(
                color: AbundanceColors.muted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              unlocked
                  ? 'UNLOCKED'
                  : inProgress
                      ? abundanceAchievementHint(record)
                      : 'LOCKED',
              style: TextStyle(
                color: unlocked
                    ? AbundanceColors.accentCyan
                    : inProgress
                        ? AbundanceColors.primaryGold
                        : AbundanceColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            if (inProgress) ...[
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: record.percent / 100,
                minHeight: 3,
                backgroundColor: AbundanceColors.surfaceSunken,
                color: AbundanceColors.primaryGold,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AwardGrid extends StatelessWidget {
  const _AwardGrid({required this.records});

  final List<AbundanceAchievementRecord> records;

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: records.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 238,
        ),
        itemBuilder: (_, index) => _AwardCard(record: records[index]),
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.unlocked,
    required this.inProgress,
    required this.locked,
  });

  final int unlocked;
  final int inProgress;
  final int locked;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _SummaryStat(
            value: unlocked,
            label: 'UNLOCKED',
            color: AbundanceColors.accentCyan,
          ),
          const SizedBox(width: 8),
          _SummaryStat(
            value: inProgress,
            label: 'IN PROGRESS',
            color: AbundanceColors.primaryGold,
          ),
          const SizedBox(width: 8),
          _SummaryStat(
            value: locked,
            label: 'LOCKED',
            color: AbundanceColors.muted,
          ),
        ],
      );
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: AbundanceCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontFamily: AbundanceTypography.displayFamily,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: AbundanceColors.muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
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
          border: Border.all(color: AbundanceColors.border, width: 2),
        ),
        child: const Center(
          child: Text(
            '▣',
            style: TextStyle(color: AbundanceColors.muted, fontSize: 20),
          ),
        ),
      );
}
