import 'package:flutter/material.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_status_view.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_coach_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_notifications_service.dart';

class AbundanceCoachingNoteScreen extends StatelessWidget {
  const AbundanceCoachingNoteScreen({
    super.key,
    required this.notification,
    this.coachService,
  });
  final AbundanceNotification notification;
  final AbundanceCoachService? coachService;

  Future<Map<String, List<Map<String, dynamic>>>> _load() async {
    final service = coachService ?? AbundanceCoachService();

    final noteId = notification.data?['coachingNoteId']?.toString();
    if (noteId != null && noteId.isNotEmpty) {
      Map<String, dynamic> note;
      try {
        note = await service.fetchMyCoachingNote(noteId);
      } catch (_) {
        // Older A12 deployments may not expose the detail route yet. The
        // student-scoped collection is still authorized by A12, so it is a
        // safe compatibility fallback for an existing linked note.
        final notes = await service.fetchMyCoachingNotes();
        note = notes
                .where((item) => item['id']?.toString() == noteId)
                .firstOrNull ??
            const <String, dynamic>{};
      }
      return {
        'notes': note.isEmpty ? const <Map<String, dynamic>>[] : [note],
        'actions': const <Map<String, dynamic>>[],
      };
    }

    final actionId = notification.data?['actionItemId']?.toString();
    if (actionId != null && actionId.isNotEmpty) {
      return {
        'notes': const <Map<String, dynamic>>[],
        'actions': await service.fetchMyCoachingActionItems(),
      };
    }

    final results = await Future.wait([
      service.fetchMyCoachingNotes(),
      service.fetchMyCoachingActionItems(),
    ]);
    return {
      'notes': results[0],
      'actions': results[1],
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AbundanceColors.background,
        appBar: AppBar(
            backgroundColor: AbundanceColors.surfaceRaised,
            foregroundColor: AbundanceColors.foreground,
            title:
                const Text('COACHING NOTE', style: AbundanceTypography.title)),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _load().then((data) => [
                ...data['notes'] ?? const <Map<String, dynamic>>[],
                ...data['actions'] ?? const <Map<String, dynamic>>[],
              ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AbundanceStatusView.loading();
            }
            if (snapshot.hasError) {
              return const AbundanceStatusView.empty(
                message: 'This coaching update could not be loaded.',
                icon: Icons.error_outline,
              );
            }
            final noteId = notification.data?['coachingNoteId']?.toString();
            final actionId = notification.data?['actionItemId']?.toString();
            final records = snapshot.data ?? const <Map<String, dynamic>>[];
            final note = noteId == null
                ? records.where((item) => item['body'] != null).firstOrNull
                : records
                    .where((item) => item['id']?.toString() == noteId)
                    .firstOrNull;
            final action = actionId == null
                ? records.where((item) => item['title'] != null).firstOrNull
                : records
                    .where((item) => item['id']?.toString() == actionId)
                    .firstOrNull;
            if (note == null && action == null) {
              return const AbundanceStatusView.empty(
                  message: 'This coaching update is no longer available.');
            }
            return Stack(children: [
              Positioned.fill(
                  child: Opacity(
                      opacity: .1,
                      child: Image.asset(abundanceBackdropAsset,
                          fit: BoxFit.cover))),
              ListView(padding: const EdgeInsets.all(16), children: [
                if (note != null) ...[
                  const Text('COACHING NOTE',
                      style: AbundanceTypography.eyebrow),
                  const SizedBox(height: 10),
                  const Text('From your coach',
                      style: AbundanceTypography.display),
                  Text((note['createdAt'] ?? '').toString(),
                      style: AbundanceTypography.body
                          .copyWith(color: AbundanceColors.accentCyan)),
                  const SizedBox(height: 22),
                  Text((note['body'] ?? '').toString(),
                      style: AbundanceTypography.body),
                ],
                if (action != null) ...[
                  const Text('ACTION ITEM', style: AbundanceTypography.eyebrow),
                  const SizedBox(height: 10),
                  Text((action['title'] ?? '').toString(),
                      style: AbundanceTypography.display),
                  Text(
                      'Due ${action['dueDate'] ?? 'No due date'} · ${(action['status'] ?? 'OPEN').toString().toUpperCase()}',
                      style: AbundanceTypography.body
                          .copyWith(color: AbundanceColors.accentCyan)),
                ],
              ]),
            ]);
          },
        ),
      );
}
