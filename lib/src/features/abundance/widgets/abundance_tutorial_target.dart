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
        if (!mounted || widget.controller?.active != true) return;
        final targetContext = _key.currentContext;
        if (targetContext == null) return;
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: .24,
        );
      });
    }
  }

  @override
  void didUpdateWidget(covariant AbundanceTutorialTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    widget.controller?.unregisterTarget(widget.name);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return Container(key: _key, child: widget.child);
  }
}
