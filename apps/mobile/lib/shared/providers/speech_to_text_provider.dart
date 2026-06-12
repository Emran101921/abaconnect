import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/speech_to_text_service.dart';

final speechToTextServiceProvider =
    ChangeNotifierProvider<SpeechToTextService>((ref) {
  final service = SpeechToTextService();
  ref.onDispose(service.dispose);
  return service;
});
