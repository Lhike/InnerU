import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_tutorial_service.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_controller.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_steps.dart';

class _SuccessfulTutorialTransport implements AbundanceApiTransport {
  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async =>
      const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async =>
      const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async =>
      const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async =>
      const <String, dynamic>{};
}

void main() {
  test('successful tutorial completion is persisted for the next login',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = AbundanceTutorialController(
      uid: 'student-1',
      roles: const {AbundanceTutorialRole.member},
      service: AbundanceTutorialService(
        transport: _SuccessfulTutorialTransport(),
      ),
      stepsOverride: const [
        AbundanceTutorialStep(
          eyebrow: 'Welcome',
          title: 'Start',
          description: 'Start here.',
        ),
      ],
    );

    controller.start();
    await controller.finish();

    final preferences = await SharedPreferences.getInstance();
    expect(controller.active, isFalse);
    expect(
      preferences.getBool('abundance_tutorial_done_student-1'),
      isTrue,
    );
    controller.dispose();
  });
}
