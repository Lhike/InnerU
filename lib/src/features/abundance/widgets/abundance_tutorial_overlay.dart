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
      sheetHeight: 260,
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
                        color: AbundanceColors.primaryGold, width: 2),
                    borderRadius: BorderRadius.circular(14),
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
    return Card(
      color: AbundanceColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AbundanceColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: (controller.stepIndex + 1) / controller.steps.length,
            backgroundColor: AbundanceColors.border,
            color: AbundanceColors.primaryGold,
            minHeight: 4,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome,
                      color: AbundanceColors.primaryGold),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(step.eyebrow.toUpperCase(),
                          style: AbundanceTypography.eyebrow)),
                  IconButton(
                    tooltip: 'Skip tutorial',
                    onPressed: controller.pending ? null : controller.skip,
                    icon: const Icon(Icons.close, color: AbundanceColors.muted),
                  ),
                ]),
                Text(
                    controller.stepIndex == 0
                        ? 'Welcome, Champion'
                        : step.title,
                    style: AbundanceTypography.title),
                const SizedBox(height: 8),
                Text(step.description, style: AbundanceTypography.body),
                if (controller.error != null) ...[
                  const SizedBox(height: 8),
                  Text(controller.error!,
                      style: const TextStyle(
                          color: AbundanceColors.scoreCritical)),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  if (controller.stepIndex > 0)
                    TextButton(
                        onPressed: controller.pending ? null : controller.back,
                        child: const Text('‹ Back'))
                  else
                    const SizedBox(width: 76),
                  const Spacer(),
                  Text(
                      '${controller.stepIndex + 1} of ${controller.steps.length}',
                      style: AbundanceTypography.body.copyWith(fontSize: 11)),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: controller.pending
                        ? null
                        : (last ? controller.finish : controller.next),
                    style: FilledButton.styleFrom(
                        backgroundColor: AbundanceColors.primaryGold,
                        foregroundColor: Colors.black),
                    child: Text(controller.pending
                        ? 'Saving…'
                        : last
                            ? (controller.completionSaver != null
                                ? 'Enter the game'
                                : 'Finish tour  ✓')
                            : 'Next'),
                  ),
                ]),
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
    path.addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(14)));
    canvas.drawPath(path..fillType = PathFillType.evenOdd,
        Paint()..color = const Color(0xD2080C1C));
  }

  @override
  bool shouldRepaint(_TutorialShadePainter oldDelegate) =>
      oldDelegate.cutout != cutout;
}
