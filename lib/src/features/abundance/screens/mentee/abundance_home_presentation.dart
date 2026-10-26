import 'package:flutter/material.dart';

/// The daily mission vocabulary used by the Abundance home screen. These map
/// directly to the existing daily-tracker API fields so the reference cards
/// remain backed by InnerU's current tracker data.
class AbundanceHomeMission {
  const AbundanceHomeMission({
    required this.key,
    required this.title,
    required this.description,
    required this.payloadField,
    required this.icon,
    required this.tone,
  });

  final String key;
  final String title;
  final String description;
  final String payloadField;
  final IconData icon;
  final AbundanceMissionTone tone;
}

enum AbundanceMissionTone { learning, body, connection }

const abundanceHomeMissionCatalog = <AbundanceHomeMission>[
  AbundanceHomeMission(
    key: 'call',
    title: 'Call',
    description: 'Connect with someone',
    payloadField: 'call',
    icon: Icons.phone_in_talk_outlined,
    tone: AbundanceMissionTone.connection,
  ),
  AbundanceHomeMission(
    key: 'steps',
    title: 'Steps',
    description: 'Move your body',
    payloadField: 'steps',
    icon: Icons.directions_run_outlined,
    tone: AbundanceMissionTone.body,
  ),
  AbundanceHomeMission(
    key: 'exercise',
    title: 'Exercise',
    description: 'Train your strength',
    payloadField: 'exercise',
    icon: Icons.fitness_center_outlined,
    tone: AbundanceMissionTone.body,
  ),
  AbundanceHomeMission(
    key: 'meditation',
    title: 'Meditation',
    description: 'Make space to breathe',
    payloadField: 'meditation',
    icon: Icons.self_improvement_outlined,
    tone: AbundanceMissionTone.learning,
  ),
  AbundanceHomeMission(
    key: 'learning',
    title: 'Learning',
    description: 'Grow your mind',
    payloadField: 'learning',
    icon: Icons.menu_book_outlined,
    tone: AbundanceMissionTone.learning,
  ),
  AbundanceHomeMission(
    key: 'addValue',
    title: 'Add value',
    description: 'Leave things better',
    payloadField: 'add_value',
    icon: Icons.auto_awesome_outlined,
    tone: AbundanceMissionTone.connection,
  ),
];

AbundanceHomeMission? abundanceHomeMissionByKey(String key) {
  for (final mission in abundanceHomeMissionCatalog) {
    if (mission.key == key) return mission;
  }
  return null;
}

String abundanceHomeGreeting(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Initials used by the reference A12 profile button when no avatar image is
/// available. Keep this presentation rule independent from authentication so
/// the header can render consistently while profile data is loading.
String abundanceHeaderInitials(String displayName) {
  final words = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .toList();
  if (words.isEmpty) return 'AM';
  return words.map((word) => word[0]).join().toUpperCase();
}
