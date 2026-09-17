import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/authentication/screen/leaderboard/leaderboard_screen.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_council_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_header_profile_button.dart';

/// Abundance's Guild route reuses the established company-scoped leaderboard
/// data surface, but applies the source app's "Allies" title for this route.
/// The default leaderboard title remains unchanged for every other company.
class AbundanceGuildScreen extends StatefulWidget {
  const AbundanceGuildScreen({super.key});

  Widget buildLeaderboard() => const Leaderboard(appBarTitle: 'Allies');

  @override
  State<AbundanceGuildScreen> createState() => _AbundanceGuildScreenState();
}

class _AbundanceGuildScreenState extends State<AbundanceGuildScreen> {
  late Future<String?> _councilFuture;
  final _councils = AbundanceCouncilService();

  @override
  void initState() {
    super.initState();
    _councilFuture = _loadCouncil();
  }

  Future<String?> _loadCouncil() async {
    if (AuthService.instance.currentSession == null) return null;
    try {
      final current = await _councils.fetchCurrent();
      if (current != null) return current.name;
    } catch (_) {
      // Keep the empty state usable while the A12 bridge is unavailable.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _councilFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AbundanceColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AbundanceColors.primaryGold,
              ),
            ),
          );
        }
        final councilName = snapshot.data;
        if (councilName != null) {
          return Leaderboard(
            appBarTitle: 'Allies',
            onLeaveCouncil: _leaveCouncil,
          );
        }
        return _NoCouncilView(
          onJoin: () => _showJoinCouncil(context),
          onRetry: () => setState(() => _councilFuture = _loadCouncil()),
        );
      },
    );
  }

  Future<void> _leaveCouncil() async {
    try {
      await _councils.leave();
      if (mounted) setState(() => _councilFuture = _loadCouncil());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to leave this council.')),
        );
      }
    }
  }

  Future<void> _showJoinCouncil(BuildContext context) async {
    List<AbundanceCouncil> available = const [];
    Object? loadError;
    try {
      available = await _councils.fetchAvailable();
    } catch (error) {
      loadError = error;
    }
    if (!context.mounted) return;
    String? selectedId;
    for (final council in available) {
      if (council.isCurrent) {
        selectedId = council.id;
        break;
      }
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AbundanceColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 64,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AbundanceColors.muted,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Choose your council',
                        style: AbundanceTypography.title),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close,
                          color: AbundanceColors.foreground),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the council you want to climb with.',
                  style: AbundanceTypography.body,
                ),
                const SizedBox(height: 14),
                if (loadError != null)
                  const Text('Councils could not be loaded. Try again later.',
                      style: AbundanceTypography.body)
                else if (available.isEmpty)
                  const Text(
                      'There are no active councils available in your organization yet.',
                      style: AbundanceTypography.body)
                else
                  ...available.map((council) {
                    final selected = council.id == selectedId;
                    return InkWell(
                      onTap: () => setSheetState(() => selectedId = council.id),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AbundanceColors.surfaceSunken,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? AbundanceColors.primaryGold
                                : AbundanceColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(council.name,
                                    style: AbundanceTypography.title),
                                Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: selected
                                        ? AbundanceColors.primaryGold
                                        : AbundanceColors.muted),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                                'Coach ${council.coachName} · ${council.memberCount} members · ${council.averageScore}% Life Power',
                                style: AbundanceTypography.body),
                            if (council.description?.isNotEmpty == true)
                              Text(council.description!,
                                  style: AbundanceTypography.body),
                            if (council.isCurrent)
                              const Text('CURRENT COUNCIL',
                                  style: AbundanceTypography.eyebrow),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: selectedId == null
                          ? null
                          : () async {
                              try {
                                await _councils.join(selectedId!);
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                if (mounted) {
                                  setState(
                                      () => _councilFuture = _loadCouncil());
                                }
                              } catch (_) {
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Unable to join this council.')));
                                }
                              }
                            },
                      child: const Text('Join council'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoCouncilView extends StatelessWidget {
  const _NoCouncilView({required this.onJoin, required this.onRetry});

  final VoidCallback onJoin;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      appBar: AuthService.instance.currentSession == null
          ? AppBar(
              backgroundColor: AbundanceColors.surfaceRaised,
              foregroundColor: AbundanceColors.foreground,
              title: const Text('Allies'),
            )
          : const AbundanceHeaderBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
        children: [
          const Text('Allies', style: AbundanceTypography.display),
          const SizedBox(height: 8),
          const Text(
            'Champions of growth. Inspiring others by leading the way.',
            style: AbundanceTypography.body,
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Join council'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF8F6EE),
              foregroundColor: AbundanceColors.primaryGold,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AbundanceColors.surfaceRaised,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AbundanceColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Council yet', style: AbundanceTypography.title),
                SizedBox(height: 8),
                Text(
                  'Once you join a Council, the fellow students in it will appear here as your allies.',
                  style: AbundanceTypography.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh council status'),
          ),
        ],
      ),
    );
  }
}
