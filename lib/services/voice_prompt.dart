import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'speech_config.dart';

/// One-shot spoken question, using the single shared recogniser.
///
/// Returns:
///  - the transcript when something was heard,
///  - `''` when the mic opened but caught nothing,
///  - `null` when speech recognition is not available on this device
///    (e.g. this MIUI Redmi has no RecognitionService — voice input only
///    works on the iQOO 15).
class VoicePrompt {
  static bool _triedInit = false;
  static bool _available = false;

  static Future<String?> ask({
    void Function(String message)? announce,
    Duration listenFor = const Duration(seconds: 12),
  }) async {
    final speech = SpeechConfig.speech;

    if (!_triedInit) {
      _triedInit = true;
      try {
        _available = await speech.initialize();
      } catch (_) {
        _available = false;
      }
    }
    if (!_available) return null;

    announce?.call('Ask your question.');

    final result = Completer<String>();
    try {
      await speech.listen(
        onResult: (r) {
          if (r.finalResult && !result.isCompleted) {
            result.complete(r.recognizedWords.trim());
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: false,
          onDevice: true, // prefer offline recognition
          listenFor: listenFor,
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      return '';
    }

    // The engine can end a turn with only a status callback and no final
    // result — fall back to "nothing heard" rather than hanging.
    return result.future.timeout(
      listenFor + const Duration(seconds: 2),
      onTimeout: () => '',
    );
  }
}
