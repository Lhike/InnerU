import 'package:flutter/material.dart';

enum AbundanceDestinationKind { tab, overflow }

class AbundanceDestination {
  const AbundanceDestination({
    required this.key,
    required this.label,
    required this.icon,
    required this.kind,
    this.coachOnly = false,
  });

  final String key;
  final String label;
  final IconData icon;
  final AbundanceDestinationKind kind;
  final bool coachOnly;
}

const List<AbundanceDestination> _memberDestinations = <AbundanceDestination>[
  AbundanceDestination(
    key: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    kind: AbundanceDestinationKind.tab,
  ),
  AbundanceDestination(
    key: 'missions',
    label: 'Mission',
    icon: Icons.calendar_month_outlined,
    kind: AbundanceDestinationKind.tab,
  ),
  AbundanceDestination(
    key: 'quests',
    label: 'Quests',
    icon: Icons.flag_outlined,
    kind: AbundanceDestinationKind.tab,
  ),
  AbundanceDestination(
    key: 'achievements',
    label: 'Awards',
    icon: Icons.workspace_premium_outlined,
    kind: AbundanceDestinationKind.tab,
  ),
  AbundanceDestination(
    key: 'guild',
    label: 'Guild',
    icon: Icons.groups_outlined,
    kind: AbundanceDestinationKind.overflow,
  ),
  AbundanceDestination(
    key: 'profile',
    label: 'Character',
    icon: Icons.person_outline,
    kind: AbundanceDestinationKind.overflow,
  ),
];

const List<AbundanceDestination> _coachDestinations = <AbundanceDestination>[
  AbundanceDestination(
    key: 'more',
    label: 'Coaching',
    icon: Icons.more_horiz,
    kind: AbundanceDestinationKind.tab,
    coachOnly: true,
  ),
  AbundanceDestination(
    key: 'coach_students',
    label: 'Students',
    icon: Icons.school_outlined,
    kind: AbundanceDestinationKind.overflow,
    coachOnly: true,
  ),
  AbundanceDestination(
    key: 'coach_core_tasks',
    label: 'Core Tasks',
    icon: Icons.checklist_outlined,
    kind: AbundanceDestinationKind.overflow,
    coachOnly: true,
  ),
  AbundanceDestination(
    key: 'coach_quests',
    label: 'Quest List',
    icon: Icons.flag_outlined,
    kind: AbundanceDestinationKind.overflow,
    coachOnly: true,
  ),
  AbundanceDestination(
    key: 'coach_directory',
    label: 'Coaches',
    icon: Icons.auto_awesome_outlined,
    kind: AbundanceDestinationKind.overflow,
    coachOnly: true,
  ),
];

List<AbundanceDestination> abundanceNavigationFor({required bool isCoach}) =>
    List<AbundanceDestination>.unmodifiable(<AbundanceDestination>[
      ..._memberDestinations,
      if (isCoach) ..._coachDestinations,
    ]);
