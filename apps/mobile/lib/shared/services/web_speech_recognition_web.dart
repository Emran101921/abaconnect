import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS('webkitSpeechRecognition')
extension type _SpeechRecognition._(web.SpeechRecognition _)
    implements web.SpeechRecognition {
  external factory _SpeechRecognition();
}

/// Safari-tuned Web Speech API wrapper (Chrome/Edge/Safari).
class WebSpeechController {
  _SpeechRecognition? _recognition;
  bool _listening = false;
  void Function(String text, {required bool isFinal})? _onText;
  void Function(String message)? _onError;
  void Function(String status)? _onStatus;
  String? _lastError;
  bool _micWarmed = false;

  bool get isSupported =>
      web.window.hasProperty('SpeechRecognition'.toJS).toDart ||
      web.window.hasProperty('webkitSpeechRecognition'.toJS).toDart;

  bool get isSafari {
    final ua = web.window.navigator.userAgent.toLowerCase();
    return ua.contains('safari') &&
        !ua.contains('chrome') &&
        !ua.contains('chromium') &&
        !ua.contains('edg');
  }

  bool get isListening => _listening;
  String? get lastError => _lastError;

  Future<bool> initialize({
    void Function(String message)? onError,
    void Function(String status)? onStatus,
  }) async {
    _onError = onError;
    _onStatus = onStatus;
    _lastError = null;

    if (!isSupported) {
      _lastError = _unsupportedMessage();
      return false;
    }

    _recognition ??= _SpeechRecognition();
    final rec = _recognition!;
    rec.onerror = _handleError.toJS;
    rec.onstart = _handleStart.toJS;
    rec.onspeechstart = _handleStart.toJS;
    rec.onend = _handleEnd.toJS;
    rec.onnomatch = _handleNoMatch.toJS;
    rec.onresult = _handleResult.toJS;

    await _warmUpMicrophone();
    return true;
  }

  Future<bool> startListening({
    required void Function(String text, {required bool isFinal}) onText,
    String? localeId,
  }) async {
    if (!isSupported || _recognition == null) {
      _lastError = _unsupportedMessage();
      return false;
    }

    if (_listening) {
      await stop();
    }

    _onText = onText;
    _lastError = null;
    await _warmUpMicrophone();

    final rec = _recognition!;
    // Safari is far more reliable with push-to-talk (continuous: false).
    rec.continuous = false;
    rec.interimResults = true;
    rec.lang = _normalizeLocale(localeId);

    try {
      rec.start();
      return true;
    } catch (e) {
      _lastError = 'Could not start dictation. Allow microphone access and try again.';
      _onError?.call(_lastError!);
      return false;
    }
  }

  Future<void> stop() async {
    if (_recognition == null || !_listening) return;
    try {
      _recognition!.stop();
    } catch (_) {}
    _listening = false;
    _onStatus?.call('notListening');
  }

  Future<void> _warmUpMicrophone() async {
    if (_micWarmed) return;
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
      _micWarmed = true;
      if (isSafari) {
        // Safari often misses the first utterance without a brief delay.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      _lastError =
          'Microphone access is required for dictation. Allow access in Safari settings.';
      _onError?.call(_lastError!);
    }
  }

  void _handleStart(web.Event _) {
    _listening = true;
    _onStatus?.call('listening');
  }

  void _handleEnd(web.Event _) {
    _listening = false;
    _onStatus?.call('done');
  }

  void _handleNoMatch(web.Event _) {
    _listening = false;
    _onStatus?.call('notListening');
  }

  void _handleError(web.SpeechRecognitionErrorEvent event) {
    _listening = false;
    _lastError = _friendlyWebError(event.error);
    _onError?.call(_lastError!);
    _onStatus?.call('notListening');
  }

  void _handleResult(web.SpeechRecognitionEvent event) {
    final results = event.results;
    if (results.length == 0) return;

    final lastIndex = results.length - 1;
    final result = results.item(lastIndex);
    if (result.length == 0) return;

    final alt = result.item(0);
    final transcript = alt.transcript.trim();
    if (transcript.isEmpty) return;

    final isFinal = result.isFinal;
    _onText?.call(transcript, isFinal: isFinal);
  }

  String _normalizeLocale(String? localeId) {
    if (localeId == null || localeId.isEmpty) {
      return web.window.navigator.language.isNotEmpty
          ? web.window.navigator.language
          : 'en-US';
    }
    return localeId.replaceAll('_', '-');
  }

  String _unsupportedMessage() {
    if (isSafari) {
      return 'Safari dictation needs macOS 14.1+ or iOS 14.5+ with microphone access enabled.';
    }
    return 'Dictation requires a browser with speech recognition (Chrome, Edge, or Safari).';
  }

  String _friendlyWebError(String code) {
    return switch (code) {
      'not-allowed' || 'service-not-allowed' =>
        'Microphone access denied. In Safari: Settings → Websites → Microphone → Allow for this site.',
      'audio-capture' => 'No microphone detected.',
      'network' => 'Speech recognition needs a network connection in this browser.',
      'aborted' => 'Dictation stopped.',
      'no-speech' => 'No speech detected. Tap the mic and try again.',
      _ => 'Dictation error: $code',
    };
  }
}
