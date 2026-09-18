import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_controller.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_math.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';

class AbundanceTutorialOverlay extends StatelessWidget {
  const AbundanceTutorialOverlay({super.key, required this.controller});

  final AbundanceTutorialController controller;

  @override
  Widget build(BuildContext context) {
    final step = controller.step;
    final target =
        step.target == null ? null : controller.targetRects[step.target];
    final size = MediaQuery.sizeOf(context);
    final ring = target == null
        ? null
        : Rect.fromLTWH(target.left - 6, target.top - 6, target.width + 12,
            target.height + 12);
    final placement = tutorialSheetPlacement(
      targetTop: ring?.top,
      targetBottom: ring?.bottom,
      sheetHeight: 430,
      safeTop: MediaQuery.paddingOf(context).top + 10,
      safeBottom: size.height - MediaQuery.paddingOf(context).bottom - 80,
      gap: 12,
    );
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (ring == null)
            const Positioned.fill(child: ColoredBox(color: Color(0xD2080C1C)))
          else ...[
            Positioned.fill(
                child: CustomPaint(painter: _TutorialShadePainter(ring))),
            Positioned.fromRect(
              rect: ring,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AbundanceColors.primaryGold, width: 3),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ),
          ],
          Positioned(
            left: 16,
            right: 16,
            top: placement == AbundanceTutorialSheetPlacement.top ? 24 : null,
            bottom:
                placement == AbundanceTutorialSheetPlacement.bottom ? 88 : null,
            child: _TutorialSheet(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _TutorialSheet extends StatelessWidget {
  const _TutorialSheet({required this.controller});
  final AbundanceTutorialController controller;

  @override
  Widget build(BuildContext context) {
    final step = controller.step;
    final last = controller.stepIndex == controller.steps.length - 1;
    final progress = (controller.stepIndex + 1) / controller.steps.length;
    final showing = step.eyebrow.contains('·')
        ? step.eyebrow.split('·').last.trim().toUpperCase()
        : 'YOUR ABUNDANCE 12 JOURNEY';
    return Container(
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AbundanceColors.border, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: const SizedBox(
                height: 5,
                child: ColoredBox(color: AbundanceColors.primaryGold),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x332C2D46),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: AbundanceColors.primaryGold, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        step.eyebrow.toUpperCase(),
                        style: AbundanceTypography.eyebrow.copyWith(
                          color: AbundanceColors.accentCyan,
                          fontSize: 12,
                          letterSpacing: 2,
                          height: 1.3,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Skip tutorial',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: controller.pending ? null : controller.skip,
                      icon: const Icon(Icons.close,
                          color: AbundanceColors.foreground, size: 30),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                    controller.stepIndex == 0
                        ? 'Welcome to Abundance 12'
                        : step.title,
                    style: AbundanceTypography.display.copyWith(fontSize: 27)),
                const SizedBox(height: 18),
                Text(step.description,
                    style: AbundanceTypography.body
                        .copyWith(fontSize: 17, height: 1.5)),
                if (controller.error != null) ...[
                  const SizedBox(height: 8),
                  Text(controller.error!,
                      style: const TextStyle(
                          color: AbundanceColors.scoreCritical)),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SHOWING · $showing',
                        style: AbundanceTypography.eyebrow.copyWith(
                            color: AbundanceColors.primaryGold,
                            fontSize: 11,
                            letterSpacing: 1.8),
                      ),
                    ),
                    Text(
                        '${controller.stepIndex + 1} of ${controller.steps.length}',
                        style: AbundanceTypography.body.copyWith(
                            color: AbundanceColors.muted, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (controller.stepIndex > 0)
                      OutlinedButton(
                        onPressed: controller.pending ? null : controller.back,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AbundanceColors.foreground,
                          side: const BorderSide(color: AbundanceColors.border),
                          minimumSize: const Size(118, 58),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('‹  Back',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                      )
                    else
                      const SizedBox(width: 118),
                    const Spacer(),
                    FilledButton(
                      onPressed: controller.pending
                          ? null
                          : (last ? controller.finish : controller.next),
                      style: FilledButton.styleFrom(
                        backgroundColor: AbundanceColors.primaryGold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(155, 60),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        controller.pending
                            ? 'Saving…'
                            : last
                                ? (controller.completionSaver != null
                                    ? 'Enter the game'
                                    : 'Finish tour  ✓')
                                : 'Next',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialShadePainter extends CustomPainter {
  const _TutorialShadePainter(this.cutout);
  final Rect cutout;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    path.addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(22)));
    canvas.drawPath(path..fillType = PathFillType.evenOdd,
        Paint()..color = const Color(0xD2080C1C));
  }

  @override
  bool shouldRepaint(_TutorialShadePainter oldDelegate) =>
      oldDelegate.cutout != cutout;
}
