import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_music_controller.dart';

class _FakeMusicPlayer implements AbundanceMusicPlayer {
  final List<String> playedAssets = <String>[];
  int stopCount = 0;
  int disposeCount = 0;

  @override
  Future<void> playLoop(String assetPath) async {
    playedAssets.add(assetPath);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('starts enabled by default with the Abundance music asset', () async {
    final preferences = await SharedPreferences.getInstance();
    final player = _FakeMusicPlayer();
    final controller = AbundanceMusicController(
      preferences: preferences,
      player: player,
    );

    await controller.initialize();

    expect(controller.isEnabled, isTrue);
    expect(player.playedAssets,
        <String>['audio/centuries_pt5_made_with_voicemod.mp3']);
  });

  test('turning music off persists and stops playback', () async {
    final preferences = await SharedPreferences.getInstance();
    final player = _FakeMusicPlayer();
    final controller = AbundanceMusicController(
      preferences: preferences,
      player: player,
    );
    await controller.initialize();

    await controller.setEnabled(false);

    expect(controller.isEnabled, isFalse);
    expect(player.stopCount, 1);
    expect(
        preferences.getBool(AbundanceMusicController.preferenceKey), isFalse);
  });

  test('does not start playback when the saved setting is off', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AbundanceMusicController.preferenceKey: false,
    });
    final preferences = await SharedPreferences.getInstance();
    final player = _FakeMusicPlayer();
    final controller = AbundanceMusicController(
      preferences: preferences,
      player: player,
    );

    await controller.initialize();

    expect(controller.isEnabled, isFalse);
    expect(player.playedAssets, isEmpty);
  });

  test('turning music back on resumes the loop', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AbundanceMusicController.preferenceKey: false,
    });
    final preferences = await SharedPreferences.getInstance();
    final player = _FakeMusicPlayer();
    final controller = AbundanceMusicController(
      preferences: preferences,
      player: player,
    );
    await controller.initialize();

    await controller.setEnabled(true);

    expect(controller.isEnabled, isTrue);
    expect(player.playedAssets,
        <String>['audio/centuries_pt5_made_with_voicemod.mp3']);
  });
}
