class WebSpeechController {
  bool get isSupported => false;
  bool get isListening => false;
  String? get lastError => 'Speech recognition is not available.';

  Future<bool> initialize({
    void Function(String message)? onError,
    void Function(String status)? onStatus,
  }) async =>
      false;

  Future<bool> startListening({
    required void Function(String text, {required bool isFinal}) onText,
    String? localeId,
  }) async =>
      false;

  Future<void> stop() async {}
}
