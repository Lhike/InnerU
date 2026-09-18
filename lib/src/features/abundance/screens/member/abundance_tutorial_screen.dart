import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_controller.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_steps.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_tutorial_overlay.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';

typedef TutorialCompletionSaver = Future<void> Function(String uid);

class AbundanceTutorialScreen extends StatefulWidget {
  const AbundanceTutorialScreen({
    super.key,
    required this.uid,
    this.saveCompletion,
    this.isCoach = false,
  });

  final String uid;
  final TutorialCompletionSaver? saveCompletion;
  final bool isCoach;

  static String completionKey(String uid) => 'abundance_tutorial_done_$uid';

  static Future<bool> shouldShow(String uid) async =>
      !(await _readCompletion(uid));

  static Future<bool> _readCompletion(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(completionKey(uid)) ?? false;
  }

  @override
  State<AbundanceTutorialScreen> createState() =>
      _AbundanceTutorialScreenState();
}

class _AbundanceTutorialScreenState extends State<AbundanceTutorialScreen> {
  late final AbundanceTutorialController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AbundanceTutorialController(
      uid: widget.uid,
      roles: {
        AbundanceTutorialRole.member,
        if (widget.isCoach) AbundanceTutorialRole.coach,
      },
      completionSaver: widget.saveCompletion,
      stepsOverride: widget.saveCompletion == null
          ? null
          : const [
              AbundanceTutorialStep(
                eyebrow: 'Welcome to Abundance 12',
                title: 'Let’s look around',
                description:
                    'This is your first time here. We will show you the important parts of the app.',
              ),
              AbundanceTutorialStep(
                eyebrow: 'Your progress',
                title: 'Build your Life Power',
                description: 'Complete missions and quests across every realm.',
              ),
              AbundanceTutorialStep(
                eyebrow: 'Your guild',
                title: 'Play with your guild',
                description:
                    'Track your rank, celebrate progress, and stay accountable.',
              ),
            ],
    )..start();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    if (!_controller.active && !_controller.pending) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(abundanceBackdropAsset, fit: BoxFit.cover),
          const ColoredBox(color: Color(0xB3080C1C)),
          SafeArea(
            child: const Center(
              child: Text(
                'Preparing your Abundance 12 tour…',
                style: TextStyle(color: AbundanceColors.muted),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (_, __) => _controller.active
                ? AbundanceTutorialOverlay(controller: _controller)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
