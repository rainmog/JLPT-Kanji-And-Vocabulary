import 'package:audioplayers/audioplayers.dart';

// Ambient track display label → filename (matches englishFonts/japaneseFonts pattern)
const ambientTracks = {
  'None': 'none',
  'By The Ocean': 'By The Ocean.mp3',
  'Chimes and Rain': 'Chimes and Rain.mp3',
  'Dentist Drill for Peaceful Dreams': 'Dentist Drill For Peaceful Dreams.mp3',
  'Light Rain': 'Light Rain.mp3',
  'Storm': 'Storm.mp3',
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

  // Some tracks are quieter at the same level — multiply their effective volume.
  static const _trackVolumeBoost = {
    'Chimes and Rain.mp3': 2.0,
  };

  String _currentAmbient = 'none';
  double _currentVolume = 0.5;
  double _sfxVolume = 0.5;
  bool sfxEnabled = true;
  bool ambientEnabled = true;

  SoundService._internal() {
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
  }

  // Call once from main() before runApp.
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
    await _instance._preloadAll();
  }

  // Plays each SFX silently to force decode, then pauses at position 0.
  // onPlayerComplete listener re-arms the player after each use.
  Future<void> _preloadAll() async {
    final sfx = [
      (_selectPlayer,  'audio/select_button.wav'),
      (_correctPlayer, 'audio/Sparkle.mp3'),
      (_wrongPlayer,   'audio/Wrong.mp3'),
      (_backPlayer,    'audio/go_back.wav'),
      (_startPlayer,   'audio/test_practice_start.wav'),
      (_completePlayer,'audio/test_practice_complete.wav'),
    ];
    await Future.wait(sfx.map((e) => _prime(e.$1, e.$2)));
  }

  Future<void> _prime(AudioPlayer player, String source) async {
    player.setReleaseMode(ReleaseMode.stop);
    player.onPlayerComplete.listen((_) async {
      // Re-arm: seek to start and pause so resume() is instant next time.
      try {
        await player.seek(Duration.zero);
        await player.pause();
      } catch (_) {}
    });
    try {
      await player.setVolume(0);
      await player.play(AssetSource(source));
      await player.seek(Duration.zero);
      await player.pause();
      await player.setVolume(_sfxVolume);
    } catch (_) {}
  }

  factory SoundService() => _instance;

  void playCorrect() {
    if (!sfxEnabled) return;
    _correctPlayer.resume();
  }

  void playWrong() {
    if (!sfxEnabled) return;
    _wrongPlayer.resume();
  }

  void playSelectButton() {
    if (!sfxEnabled) return;
    _selectPlayer.resume();
  }

  void playGoBack() {
    if (!sfxEnabled) return;
    _backPlayer.resume();
  }

  void playTestStart() {
    if (!sfxEnabled) return;
    _startPlayer.resume();
  }

  void playTestComplete() {
    if (!sfxEnabled) return;
    _completePlayer.resume();
  }

  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume;
    await Future.wait([
      _selectPlayer.setVolume(volume),
      _correctPlayer.setVolume(volume),
      _wrongPlayer.setVolume(volume),
      _backPlayer.setVolume(volume),
      _startPlayer.setVolume(volume),
      _completePlayer.setVolume(volume),
    ]);
  }

  double _effectiveAmbientVolume() {
    final boost = _trackVolumeBoost[_currentAmbient] ?? 1.0;
    return (_currentVolume * boost).clamp(0.0, 1.0);
  }

  Future<void> setAmbient(String trackKey) async {
    if (_currentAmbient == trackKey) return;
    _currentAmbient = trackKey;
    await _ambientPlayer.stop();
    if (trackKey != 'none' && ambientEnabled) {
      await _ambientPlayer.setVolume(_effectiveAmbientVolume());
      await _ambientPlayer.play(AssetSource('audio/ambience/$trackKey'));
    }
  }

  Future<void> setAmbientVolume(double volume) async {
    _currentVolume = volume;
    await _ambientPlayer.setVolume(_effectiveAmbientVolume());
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
