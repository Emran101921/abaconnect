import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// On-device speech recognition for dictating messages and clinical notes.
class SpeechToTextService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;
  bool _available = false;
  bool _listening = false;
  String? _activeFieldKey;
  String _baseText = '';
  void Function(String text)? _onUpdate;
  String? _lastError;

  bool get isAvailable => _available;
  bool get isListening => _listening;
  String? get activeFieldKey => _activeFieldKey;
  String? get lastError => _lastError;

  bool isListeningFor(String fieldKey) =>
      _listening && _activeFieldKey == fieldKey;

  Future<bool> ensureInitialized() async {
    if (_initialized) return _available;
    _available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _listening = false;
          _activeFieldKey = null;
          notifyListeners();
        }
      },
      onError: (error) {
        _lastError = error.errorMsg;
        _listening = false;
        _activeFieldKey = null;
        notifyListeners();
      },
    );
    _initialized = true;
    notifyListeners();
    return _available;
  }

  Future<void> toggle({
    required String fieldKey,
    required String currentText,
    required void Function(String text) onUpdate,
  }) async {
    if (_listening && _activeFieldKey == fieldKey) {
      await stop();
      return;
    }

    if (_listening) await stop();

    final ok = await ensureInitialized();
    if (!ok) return;

    _baseText = currentText;
    _onUpdate = onUpdate;
    _activeFieldKey = fieldKey;
    _lastError = null;

    await _speech.listen(
      onResult: _handleResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
      ),
    );
    _listening = true;
    notifyListeners();
  }

  void _handleResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;

    final combined = _appendWords(_baseText, words);
    _onUpdate?.call(combined);

    if (result.finalResult) {
      _baseText = combined;
    }
  }

  String _appendWords(String base, String words) {
    final trimmed = base.trimRight();
    if (trimmed.isEmpty) return words;
    final needsSpace = !trimmed.endsWith(' ') && !trimmed.endsWith('\n');
    return '$trimmed${needsSpace ? ' ' : ''}$words';
  }

  Future<void> stop() async {
    if (!_listening) return;
    await _speech.stop();
    _listening = false;
    _activeFieldKey = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
