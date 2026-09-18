import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';

class AbundanceTutorialService {
  AbundanceTutorialService({AbundanceApiTransport? transport})
      : _transport = transport ?? A12ApiTransport();

  final AbundanceApiTransport _transport;

  Future<void> complete() async {
    await _transport.postJson('/tutorial/complete', const <String, dynamic>{});
  }

  Future<void> replay() async {
    await _transport.postJson('/tutorial/replay', const <String, dynamic>{});
  }
}
