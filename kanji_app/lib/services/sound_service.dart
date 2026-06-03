import 'package:audioplayers/audioplayers.dart';

// Ambient track filename → display label
const ambientTracks = {
  'none': 'None',
  'By The Ocean.mp3': 'By The Ocean',
  'Chimes and Rain.mp3': 'Chimes and Rain',
  'Dentist Drill For Peaceful Dreams.mp3': 'Dentist Drill for Peaceful Dreams',
  'Light Rain.mp3': 'Light Rain',
  'Storm.mp3': 'Storm',
};

class SoundService {
  static final SoundService _instance = SoundService._internal();

  final AudioPlayer _correctPlayer = AudioPlayer();
  final AudioPlayer _wrongPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _selectPlayer = AudioPlayer();
  final AudioPlayer _backPlayer = AudioPlayer();
  final AudioPlayer _startPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();

  String _currentAmbient = 'none';
  double _currentVolume = 0.5;
  double _sfxVolume = 0.5;
  bool sfxEnabled = true;
  bool ambientEnabled = true;

  SoundService._internal() {
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
  }

  // Call once from main() before runApp — sets audio context for all players.
  // Using ambient category on iOS mixes with other apps (music, podcasts).
  // On Android, AudioFocus.none avoids interrupting background audio.
  static Future<void> init() async {
    await AudioPlayer.global.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
    ));
  }

  factory SoundService() => _instance;

  Future<void> playCorrect() async {
    if (!sfxEnabled) return;
    try {
      await _correctPlayer.stop();
      await _correctPlayer.play(AssetSource('audio/Sparkle.mp3'));
      await _correctPlayer.setVolume(_sfxVolume);
    } catch (_) {}
  }

  Future<void> playWrong() async {
    if (!sfxEnabled) return;
    try {
      await _wrongPlayer.stop();
      await _wrongPlayer.play(AssetSource('audio/Wrong.mp3'));
      await _wrongPlayer.setVolume(_sfxVolume);
    } catch (_) {}
  }

  Future<void> playSelectButton() async {
    if (!sfxEnabled) return;
    try {
      await _selectPlayer.stop();
      await _selectPlayer.play(AssetSource('audio/select_button.wav'));
      await _selectPlayer.setVolume(_sfxVolume);
    } catch (_) {}
  }

  Future<void> playGoBack() async {
    if (!sfxEnabled) return;
    try {
      await _backPlayer.stop();
      await _backPlayer.play(AssetSource('audio/go_back.wav'));
      await _backPlayer.setVolume(_sfxVolume);
    } catch (_) {}
  }

  Future<void> playTestStart() async {
    if (!sfxEnabled) return;
    try {
      await _startPlayer.stop();
      await _startPlayer.play(AssetSource('audio/test_practice_start.wav'));
      await _startPlayer.setVolume(_sfxVolume);
    } catch (_) {}
  }

  Future<void> playTestComplete() async {
    if (!sfxEnabled) return;
    try {
      await _completePlayer.stop();
      await _completePlayer.play(AssetSource('audio/test_practice_complete.wav'));
      await _completePlayer.setVolume(_sfxVolume);
    } catch (_) {}
  }

  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume;
  }

  Future<void> setAmbient(String trackKey) async {
    if (_currentAmbient == trackKey) return;
    _currentAmbient = trackKey;
    await _ambientPlayer.stop();
    if (trackKey != 'none' && ambientEnabled) {
      await _ambientPlayer.play(AssetSource('audio/ambience/$trackKey'));
      await _ambientPlayer.setVolume(_currentVolume);
    }
  }

  Future<void> setAmbientVolume(double volume) async {
    _currentVolume = volume;
    await _ambientPlayer.setVolume(volume);
  }

  Future<void> stopAmbient() async {
    _currentAmbient = 'none';
    await _ambientPlayer.stop();
  }

  Future<void> dispose() async {
    await _correctPlayer.dispose();
    await _wrongPlayer.dispose();
    await _ambientPlayer.dispose();
    await _selectPlayer.dispose();
    await _backPlayer.dispose();
    await _startPlayer.dispose();
    await _completePlayer.dispose();
  }
}

final soundService = SoundService();
