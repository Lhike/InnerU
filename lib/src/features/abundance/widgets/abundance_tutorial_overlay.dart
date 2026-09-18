import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_controller.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_math.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';

class AbundanceTutorialOverlay extends StatefulWidget {
  const AbundanceTutorialOverlay({super.key, required this.controller});

  final AbundanceTutorialController controller;

  @override
  State<AbundanceTutorialOverlay> createState() =>
      _AbundanceTutorialOverlayState();
}

class _AbundanceTutorialOverlayState extends State<AbundanceTutorialOverlay> {
  final _sheetKey = GlobalKey();
  double _sheetHeight = 0;

  void _measureSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final render = _sheetKey.currentContext?.findRenderObject();
      if (render is RenderBox &&
          render.hasSize &&
          (render.size.height - _sheetHeight).abs() > .5) {
        setState(() => _sheetHeight = render.size.height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _measureSheet();
    final controller = widget.controller;
    final step = controller.step;
    final target =
        step.target == null ? null : controller.targetRects[step.target];
    final insets = MediaQuery.paddingOf(context);
    final topPosition = insets.top + 10 > 16 ? insets.top + 10 : 16.0;
    final bottomInset = insets.bottom > 8 ? insets.bottom + 58 : 66.0;
    final ring = target == null
        ? null
        : Rect.fromLTWH(target.left - 6, target.top - 6, target.width + 12,
            target.height + 12);
    final calculatedPlacement = tutorialSheetPlacement(
      targetTop: ring?.top,
      targetBottom: ring?.bottom,
      sheetHeight: _sheetHeight == 0 ? 320 : _sheetHeight,
      safeTop: topPosition,
      safeBottom: MediaQuery.sizeOf(context).height - bottomInset,
      gap: 12,
    );
    final placement = calculatedPlacement;
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
            top: placement == AbundanceTutorialSheetPlacement.top
                ? topPosition
                : null,
            bottom: placement == AbundanceTutorialSheetPlacement.bottom
                ? bottomInset
                : null,
            child: _TutorialSheet(key: _sheetKey, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _TutorialSheet extends StatelessWidget {
  const _TutorialSheet({super.key, required this.controller});
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
        borderRadius: BorderRadius.circular(24),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x332C2D46),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: AbundanceColors.primaryGold, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step.eyebrow.toUpperCase(),
                        style: AbundanceTypography.eyebrow.copyWith(
                          color: AbundanceColors.accentCyan,
                          fontSize: 10,
                          letterSpacing: 1.4,
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
                          color: AbundanceColors.foreground, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                    controller.stepIndex == 0
                        ? 'Welcome, ${controller.displayName?.trim().isNotEmpty == true ? controller.displayName!.trim() : 'Champion'}'
                        : step.title,
                    style: AbundanceTypography.display.copyWith(fontSize: 21)),
                const SizedBox(height: 12),
                Text(step.description,
                    style: AbundanceTypography.body
                        .copyWith(fontSize: 14, height: 1.42)),
                if (controller.error != null) ...[
                  const SizedBox(height: 8),
                  Text(controller.error!,
                      style: const TextStyle(
                          color: AbundanceColors.scoreCritical)),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SHOWING · $showing',
                        style: AbundanceTypography.eyebrow.copyWith(
                            color: AbundanceColors.primaryGold,
                            fontSize: 9,
                            letterSpacing: 1.2),
                      ),
                    ),
                    Text(
                        '${controller.stepIndex + 1} of ${controller.steps.length}',
                        style: AbundanceTypography.body.copyWith(
                            color: AbundanceColors.muted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (controller.stepIndex > 0)
                      OutlinedButton(
                        onPressed: controller.pending ? null : controller.back,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AbundanceColors.foreground,
                          side: const BorderSide(color: AbundanceColors.border),
                          minimumSize: const Size(92, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('‹  Back',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      )
                    else
                      const SizedBox(width: 92),
                    const Spacer(),
                    FilledButton(
                      onPressed: controller.pending
                          ? null
                          : (last ? controller.finish : controller.next),
                      style: FilledButton.styleFrom(
                        backgroundColor: AbundanceColors.primaryGold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(132, 46),
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
                            fontSize: 14, fontWeight: FontWeight.w800),
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
