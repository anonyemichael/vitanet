import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

final voiceServiceProvider = ChangeNotifierProvider<VoiceService>((ref) {
  return VoiceService();
});

class VoiceService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isSpeechInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  VoiceService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<bool> initializeSpeech() async {
    if (_isSpeechInitialized) return true;
    _isSpeechInitialized = await _speech.initialize(
      onError: (val) {
        debugPrint('Speech Error: $val');
        _isListening = false;
        notifyListeners();
      },
      onStatus: (val) {
        debugPrint('Speech Status: $val');
        if (val == 'done' || val == 'notListening') {
          _isListening = false;
          notifyListeners();
        }
      },
    );
    return _isSpeechInitialized;
  }

  Future<void> startListening(Function(String) onResult) async {
    final initialized = await initializeSpeech();
    if (initialized) {
      _isListening = true;
      notifyListeners();
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
      );
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
    notifyListeners();
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
