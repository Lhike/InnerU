import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';

typedef TutorialCompletionSaver = Future<void> Function(String uid);

class AbundanceTutorialScreen extends StatefulWidget {
  const AbundanceTutorialScreen({
    super.key,
    required this.uid,
    this.saveCompletion,
  });

  final String uid;
  final TutorialCompletionSaver? saveCompletion;

  static String completionKey(String uid) => 'abundance_tutorial_done_$uid';

  static Future<bool> shouldShow(String uid) async =>
      !((await SharedPreferences.getInstance()).getBool(completionKey(uid)) ??
          false);

  @override
  State<AbundanceTutorialScreen> createState() =>
      _AbundanceTutorialScreenState();
}

class _AbundanceTutorialScreenState extends State<AbundanceTutorialScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _steps = <({String title, String body, IconData icon})>[
    (
      title: 'WELCOME TO ABUNDANCE 12',
      body: 'Turn the life you want into missions, quests, and daily action.',
      icon: Icons.auto_awesome,
    ),
    (
      title: 'BUILD YOUR LIFE POWER',
      body: 'Complete everyday missions and advance quests across every realm.',
      icon: Icons.bolt,
    ),
    (
      title: 'PLAY WITH YOUR GUILD',
      body: 'Track your rank, celebrate progress, and stay accountable.',
      icon: Icons.groups_outlined,
    ),
  ];

  Future<void> _finish() async {
    try {
      if (widget.saveCompletion != null) {
        await widget.saveCompletion!(widget.uid);
      } else {
        final saved = await (await SharedPreferences.getInstance())
            .setBool(AbundanceTutorialScreen.completionKey(widget.uid), true);
        if (!saved) throw StateError('Tutorial preference was not saved.');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your tutorial progress could not be saved.'),
        ),
      );
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _steps.length - 1;
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(abundanceBackdropAsset, fit: BoxFit.cover),
          const ColoredBox(color: Color(0xB3080C1C)),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _steps.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 34),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(step.icon,
                                size: 74, color: AbundanceColors.primaryGold),
                            const SizedBox(height: 28),
                            Text(step.title,
                                textAlign: TextAlign.center,
                                style: AbundanceTypography.display),
                            const SizedBox(height: 16),
                            Text(step.body,
                                textAlign: TextAlign.center,
                                style: AbundanceTypography.body.copyWith(
                                    color: AbundanceColors.muted,
                                    fontSize: 16)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _steps.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == _page ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: index == _page
                            ? AbundanceColors.primaryGold
                            : AbundanceColors.border,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: AbundanceButton(
                      label: last ? 'Enter the game' : 'Next',
                      onPressed: last ? _finish : _next,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
