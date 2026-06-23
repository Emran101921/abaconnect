import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'web_speech_recognition.dart';

/// On-device speech recognition for dictating messages and clinical notes.
class SpeechToTextService extends ChangeNotifier {
  SpeechToText? _speech;
  WebSpeechController? _webSpeech;

  bool _initialized = false;
  bool _available = false;
  bool _listening = false;
  String? _activeFieldKey;
  String _baseText = '';
  void Function(String text)? _onUpdate;
  String? _lastError;
  String? _localeId;

  bool get isAvailable => _available;
  bool get isListening => _listening;
  String? get activeFieldKey => _activeFieldKey;
  String? get lastError => _lastError;

  bool isListeningFor(String fieldKey) =>
      _listening && _activeFieldKey == fieldKey;

  Future<bool> ensureInitialized() async {
    if (_initialized) return _available;

    _lastError = null;

    if (kIsWeb) {
      _webSpeech ??= WebSpeechController();
      _available = await _webSpeech!.initialize(
        onError: (message) {
          _lastError = message;
          _listening = false;
          _activeFieldKey = null;
          notifyListeners();
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _listening = false;
            _activeFieldKey = null;
            notifyListeners();
          } else if (status == 'listening') {
            _listening = true;
            notifyListeners();
          }
        },
      );
      if (!_available) {
        _lastError ??= _webSpeech!.lastError ?? _unavailableReason();
      }
    } else {
      _speech ??= SpeechToText();
      _available = await _speech!.initialize(
        debugLogging: kDebugMode,
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _listening = false;
            _activeFieldKey = null;
            notifyListeners();
          }
        },
        onError: (error) {
          _lastError = _friendlyError(error.errorMsg);
          _listening = false;
          _activeFieldKey = null;
          notifyListeners();
        },
      );
      if (!_available) {
        _lastError ??= _unavailableReason();
      } else {
        _localeId = await _resolveLocaleId();
      }
    }

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
    if (!ok) {
      _lastError ??= _unavailableReason();
      notifyListeners();
      return;
    }

    _baseText = currentText;
    _onUpdate = onUpdate;
    _activeFieldKey = fieldKey;
    _lastError = null;

    if (kIsWeb) {
      final started = await _webSpeech!.startListening(
        localeId: _localeId,
        onText: (text, {required bool isFinal}) {
          final combined = _appendWords(_baseText, text);
          _onUpdate?.call(combined);
          if (isFinal) {
            _baseText = combined;
          }
        },
      );
      _listening = started && _webSpeech!.isListening;
      if (!_listening) {
        _lastError ??= _webSpeech!.lastError ?? _unavailableReason();
        _activeFieldKey = null;
      }
      notifyListeners();
      return;
    }

    try {
      await _speech!.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          localeId: _localeId,
        ),
      );
    } catch (e) {
      _lastError = 'Could not start dictation: $e';
      _listening = false;
      _activeFieldKey = null;
      notifyListeners();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    _listening = _speech!.isListening;
    if (!_listening) {
      _lastError ??= _speech!.lastError?.errorMsg ?? _unavailableReason();
      _activeFieldKey = null;
    }
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

  Future<String?> _resolveLocaleId() async {
    if (_speech == null) return null;
    try {
      final locales = await _speech!.locales();
      if (locales.isEmpty) return null;

      final preferred = locales.where(
        (l) =>
            l.localeId == 'en_US' ||
            l.localeId.startsWith('en_US') ||
            l.localeId == 'en-US',
      );
      if (preferred.isNotEmpty) return preferred.first.localeId;

      final english = locales.where((l) => l.localeId.startsWith('en'));
      if (english.isNotEmpty) return english.first.localeId;

      return locales.first.localeId;
    } catch (_) {
      return null;
    }
  }

  String _unavailableReason() {
    if (kIsWeb) {
      return 'Dictation requires Safari 14.1+, Chrome, or Edge with microphone access enabled.';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Speech recognition needs microphone permission. On the iOS Simulator, '
          'use a physical device if dictation stays unavailable.';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Speech recognition needs microphone permission. Allow microphone access '
          'in system Settings for BloomOra.';
    }
    return 'Speech recognition is not available on this device.';
  }

  String _friendlyError(String code) {
    return switch (code) {
      'error_permission' ||
      'error_audio_error' =>
        'Microphone permission is required for dictation. Enable it in Settings.',
      'not supported' || 'not_available' || 'speech_not_supported' =>
        _unavailableReason(),
      _ => code,
    };
  }

  Future<void> stop() async {
    if (kIsWeb) {
      if (!_listening && !(_webSpeech?.isListening ?? false)) return;
      await _webSpeech?.stop();
      _listening = false;
      _activeFieldKey = null;
      notifyListeners();
      return;
    }

    if (!_listening && !(_speech?.isListening ?? false)) return;
    await _speech?.stop();
    _listening = false;
    _activeFieldKey = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (kIsWeb) {
      _webSpeech?.stop();
    } else {
      _speech?.stop();
    }
    super.dispose();
  }
}
