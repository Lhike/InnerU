import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_controller.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_math.dart';

class AbundanceTutorialTarget extends StatefulWidget {
  const AbundanceTutorialTarget({
    super.key,
    required this.name,
    required this.controller,
    required this.child,
  });

  final String name;
  final AbundanceTutorialController? controller;
  final Widget child;

  @override
  State<AbundanceTutorialTarget> createState() =>
      _AbundanceTutorialTargetState();
}

class _AbundanceTutorialTargetState extends State<AbundanceTutorialTarget> {
  final _key = GlobalKey();
  String? _lastEnsuredTarget;
  String? _lastControllerTarget;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    final controller = widget.controller;
    if (!mounted || controller?.active != true) return;
    final target = controller!.step.target;
    if (target == _lastControllerTarget) return;
    _lastControllerTarget = target;
    if (target != widget.name) return;
    _lastEnsuredTarget = null;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  void _measure() {
    if (widget.controller?.active != true) return;
    final context = _key.currentContext;
    final render = context?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final offset = render.localToGlobal(Offset.zero);
    widget.controller!.registerTarget(
      widget.name,
      AbundanceTutorialRect(
        left: offset.dx,
        top: offset.dy,
        width: render.size.width,
        height: render.size.height,
      ),
    );
    if (widget.controller!.step.target == widget.name &&
        _lastEnsuredTarget != widget.name) {
      _lastEnsuredTarget = widget.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.controller?.active != true ||
            widget.controller?.step.target != widget.name) {
          return;
        }
        final targetContext = _key.currentContext;
        if (targetContext == null) return;
        final render = targetContext.findRenderObject();
        if (render is! RenderBox || !render.hasSize) return;

        final scrollable = Scrollable.maybeOf(targetContext);
        final viewport = scrollable?.context.findRenderObject();
        if (scrollable == null || viewport is! RenderBox || !viewport.hasSize) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: .4,
          );
          _remeasureAfterScroll();
          return;
        }

        final targetOffset = render.localToGlobal(Offset.zero);
        final viewportOffset = viewport.localToGlobal(Offset.zero);
        final requestedOffset = tutorialScrollOffset(
          targetTop: targetOffset.dy,
          targetHeight: render.size.height,
          viewportTop: viewportOffset.dy,
          currentOffset: scrollable.position.pixels,
          viewportHeight: viewport.size.height,
        );
        if (requestedOffset != null) {
          scrollable.position.animateTo(
            requestedOffset,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
          _remeasureAfterScroll();
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  void _remeasureAfterScroll() {
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted || widget.controller?.active != true) return;
      if (widget.controller?.step.target != widget.name) return;
      _measure();
    });
  }

  @override
  void didUpdateWidget(covariant AbundanceTutorialTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
      _lastControllerTarget = null;
      _lastEnsuredTarget = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    widget.controller?.unregisterTarget(widget.name);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return Container(key: _key, child: widget.child);
  }
}
