import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  static Future<void> speak(
    String text, {
    String lang = 'eng',
    String speed = 'normal',
  }) async {
    if (text.trim().isEmpty) return;
    await _init();
    await _tts.setLanguage(lang == 'fil' ? 'fil-PH' : 'en-US');
    await _tts.setSpeechRate(
      speed == 'slow'
          ? 0.35
          : speed == 'fast'
          ? 0.65
          : 0.5,
    );
    await _tts.speak(text);
  }

  static Future<void> stop() => _tts.stop();
}
