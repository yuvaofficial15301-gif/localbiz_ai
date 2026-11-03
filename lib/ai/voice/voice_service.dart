import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wraps Android speech recognition and text-to-speech.
///
/// Recognition starts ONLY from an explicit user tap; there is no background
/// or continuous listening. By default only on-device recognition is allowed
/// ("offline only"); online recognition must be enabled explicitly by the user.
class VoiceService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttReady = false;
  String lastError = '';
  void Function(String status)? onStatus;
  void Function(String error)? onError;

  bool get isListening => _stt.isListening;
  bool get sttReady => _sttReady;

  Future<bool> init() async {
    if (_sttReady) return true;
    try {
      _sttReady = await _stt.initialize(
        onError: (e) {
          lastError = e.errorMsg;
          onError?.call(e.errorMsg);
        },
        onStatus: (s) => onStatus?.call(s),
      );
    } catch (e) {
      lastError = '$e';
      _sttReady = false;
    }
    return _sttReady;
  }

  /// Locale ids reported by the device recogniser (may be empty).
  Future<List<String>> availableLocales() async {
    if (!await init()) return const [];
    try {
      final l = await _stt.locales();
      return l.map((e) => e.localeId).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Finds the device's id for [wanted] (e.g. ta_IN), or null if unsupported.
  Future<String?> resolveLocale(String wanted) async {
    final all = await availableLocales();
    String norm(String s) => s.replaceAll('-', '_').toLowerCase();
    final w = norm(wanted);
    for (final l in all) {
      if (norm(l) == w) return l;
    }
    final lang = w.split('_').first;
    for (final l in all) {
      if (norm(l).split('_').first == lang) return l;
    }
    return null;
  }

  Future<bool> listen({
    required String localeId,
    required bool onDeviceOnly,
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!await init()) return false;
    try {
      await _stt.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        localeId: localeId,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          onDevice: onDeviceOnly,
          cancelOnError: true,
        ),
      );
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  Future<void> cancelListening() async {
    try {
      await _stt.cancel();
    } catch (_) {}
  }

  /// Returns true when the Android TTS engine has this language available.
  Future<bool> ttsSupports(String locale) async {
    try {
      final r = await _tts.isLanguageAvailable(locale);
      return r == true || r == 1;
    } catch (_) {
      return false;
    }
  }

  Future<void> speak(String text, String locale) async {
    try {
      await _tts.stop();
      if (await ttsSupports(locale)) {
        await _tts.setLanguage(locale);
      }
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
