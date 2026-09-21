import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AbundanceMusicPlayer {
  Future<void> playLoop(String assetPath);

  Future<void> stop();

  Future<void> dispose();
}

abstract interface class AbundanceMusicControllerApi {
  bool get isEnabled;

  Future<void> initialize();

  Future<void> setEnabled(bool enabled);

  Future<void> dispose();
}

class AbundanceMusicController implements AbundanceMusicControllerApi {
  AbundanceMusicController({
    SharedPreferences? preferences,
    AbundanceMusicPlayer? player,
  })  : _preferences = preferences,
        _player = player ?? _AudioPlayerAbundanceMusicPlayer();

  static const preferenceKey = 'abundance-music-enabled';
  static const assetPath = 'audio/centuries_pt5_made_with_voicemod.mp3';

  SharedPreferences? _preferences;
  final AbundanceMusicPlayer _player;
  bool _enabled = true;
  bool _initialized = false;
  bool _playing = false;
  bool _disposed = false;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _preferences ??= await SharedPreferences.getInstance();
    _enabled = _preferences!.getBool(preferenceKey) ?? true;
    _initialized = true;
    if (_enabled) await _startPlayback();
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (_disposed) return;
    await initialize();
    _enabled = enabled;
    await _preferences!.setBool(preferenceKey, enabled);
    if (enabled) {
      await _startPlayback();
    } else {
      await _stopPlayback();
    }
  }

  Future<void> _startPlayback() async {
    if (_playing || !_enabled || _disposed) return;
    try {
      await _player.playLoop(assetPath);
      _playing = true;
    } catch (error) {
      // Music is an enhancement and must never prevent the Abundance shell
      // from opening if a platform audio session cannot be created.
      debugPrint('Unable to start Abundance music: $error');
    }
  }

  Future<void> _stopPlayback() async {
    if (!_playing) return;
    await _player.stop();
    _playing = false;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stopPlayback();
    await _player.dispose();
  }
}

class _AudioPlayerAbundanceMusicPlayer implements AbundanceMusicPlayer {
  final AudioPlayer _player = AudioPlayer()
    ..setPlayerMode(PlayerMode.mediaPlayer);
  bool _audioContextConfigured = false;

  @override
  Future<void> playLoop(String assetPath) async {
    if (!_audioContextConfigured) {
      await _player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      _audioContextConfigured = true;
    }
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(.28);
    await _player.play(AssetSource(assetPath));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
