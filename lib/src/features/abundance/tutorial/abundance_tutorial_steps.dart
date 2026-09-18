enum AbundanceTutorialRole { member, coach, admin }

class AbundanceTutorialStep {
  const AbundanceTutorialStep({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.target,
    this.route,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String? target;
  final String? route;
}

const _welcomeStep = AbundanceTutorialStep(
  eyebrow: 'Welcome to Abundance 12',
  title: 'Let’s look around',
  description:
      'This is your first time here. We will show you the important parts of the app. You can skip this tour now and play it again later from your account menu.',
  route: '/(tabs)',
);

const _memberSteps = <AbundanceTutorialStep>[
  AbundanceTutorialStep(
    eyebrow: 'Home · Your progress',
    title: 'See how you are doing',
    description:
        'Rank and XP show how much you have done. Life Power is your score out of 100. It comes from your Personal, Professional, and Contribution goals.',
    target: 'home-overview',
    route: '/(tabs)',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Home · Today',
    title: 'Your missions for today',
    description:
        'These are the small things you need to do today. Tap a mission when you finish it. Finishing missions helps you earn XP and build a good habit.',
    target: 'home-missions',
    route: '/(tabs)',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Home · Your three areas',
    title: 'See each goal score',
    description:
        'These bars show your Personal, Professional, and Contribution scores. All three are important, and together they make your Life Power.',
    target: 'home-goal',
    route: '/(tabs)',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Goals · What you want to finish',
    title: 'Make a new goal',
    description:
        'Tap New Quest to make a goal. The questions help you say what you want, how you will do it, and who you want to become.',
    target: 'quests-overview',
    route: '/quests',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Goals · Your Life Power',
    title: 'How your score works',
    description:
        'Life Power joins your three goal scores into one number out of 100. Make a goal in every area. An empty area gets zero points.',
    target: 'quests-life-power',
    route: '/quests',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Goals · Three areas',
    title: 'Pick the right area',
    description:
        'Personal is about you and your family. Professional is about work or business. Contribution is about helping other people. Tap a filter to see one area.',
    target: 'quests-categories',
    route: '/quests',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Goals · A goal card',
    title: 'See what to do next',
    description:
        'A card shows the goal’s area, status, progress, action plans, and time left. Tap the card when you want to update the goal.',
    target: 'quests-list',
    route: '/quests',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Everyday Missions · Keep showing up',
    title: 'Do a little every day',
    description:
        'This page keeps today’s missions in one place. The timer tells you when a new mission day will begin.',
    target: 'daily-overview',
    route: '/missions',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Everyday Missions · Today',
    title: 'Check what you finished',
    description:
        'Tap only the missions you really finished. Each mission shows the XP you can earn.',
    target: 'daily-board',
    route: '/missions',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Everyday Missions · Past days',
    title: 'Fix a day you forgot',
    description:
        'Choose a date to look at an older day. You can fix it if your coach has not locked that week yet.',
    target: 'daily-board',
    route: '/missions',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Guild · Your group',
    title: 'See your team',
    description:
        'Your Guild shows you, your coach, and the other students in your group. You can cheer each other on and see how everyone is doing.',
    target: 'allies-overview',
    route: '/guild',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Guild · Find someone',
    title: 'Search your team',
    description:
        'Search for a name or rank. Use the filters to see people who were active this week, this month, or all the time.',
    target: 'allies-controls',
    route: '/guild',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Guild · The list',
    title: 'See everyone’s place',
    description:
        'People are ordered by their total goal score. Tap a person to see their scores, goals, progress, and due dates.',
    target: 'allies-board',
    route: '/guild',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Guild · Your place',
    title: 'See where you are',
    description:
        'This shows the leaders and your place in the group. Using a filter does not change anyone’s real rank.',
    target: 'allies-rank',
    route: '/guild',
  ),
];

const _coachSteps = <AbundanceTutorialStep>[
  AbundanceTutorialStep(
    eyebrow: 'Coaching · Your students',
    title: 'Review your council',
    description:
        'See each student’s Life Power, current quests, and today’s mission progress.',
    target: 'coach-mentees',
    route: '/coach/students',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Coaching · Quests and missions',
    title: 'Follow student progress',
    description:
        'Open a student’s quest list or daily mission view to see how their plans are moving.',
    target: 'coach-goals',
    route: '/coach/goals',
  ),
];

const _sharedSteps = <AbundanceTutorialStep>[
  AbundanceTutorialStep(
    eyebrow: 'Achievements · Your awards',
    title: 'See what you earned',
    description:
        'You earn achievements by doing missions, finishing goals, building streaks, and raising your Life Power. The app gives them to you automatically.',
    target: 'achievements-overview',
    route: '/achievements',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Achievements · Status',
    title: 'See what is done and what is next',
    description:
        'Unlocked means you earned it. In progress means you already started. Locked means you have not started yet.',
    target: 'achievements-tally',
    route: '/achievements',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Achievements · Requirements',
    title: 'Learn how to earn each one',
    description:
        'A locked achievement tells you what to do and how close you are. Once you earn it, it stays in your collection.',
    target: 'achievements-wall',
    route: '/achievements',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Profile · About you',
    title: 'See your player card',
    description:
        'Your player card shows your photo, level, rank, XP, role, Guild, coach, and Life Power. XP keeps what you earned. Life Power shows how your goals are doing now.',
    target: 'profile-character',
    route: '/profile',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Profile · Your record',
    title: 'See your important numbers',
    description:
        'These numbers show your goals, streaks, Life Power, and total XP. They give you a quick look at your progress.',
    target: 'profile-stats',
    route: '/profile',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Profile · Your Guild',
    title: 'See your group and coach',
    description:
        'This shows your Guild and coach. If you change Guilds, your coach, teammates, and Everyday Missions may also change.',
    target: 'profile-council',
    route: '/profile',
  ),
  AbundanceTutorialStep(
    eyebrow: 'Profile · Settings',
    title: 'Change your account',
    description:
        'Change your details, photo, password, and app colors here. You can also play this tutorial again from your account menu.',
    target: 'profile-settings',
    route: '/profile',
  ),
];

List<AbundanceTutorialStep> abundanceTutorialStepsFor(
  Set<AbundanceTutorialRole> roles,
) {
  final isMember =
      roles.isEmpty || roles.contains(AbundanceTutorialRole.member);
  final steps = <AbundanceTutorialStep>[
    _welcomeStep,
    if (isMember) ..._memberSteps,
    if (roles.contains(AbundanceTutorialRole.coach)) ..._coachSteps,
    ..._sharedSteps,
  ];

  return List<AbundanceTutorialStep>.unmodifiable(steps);
}
