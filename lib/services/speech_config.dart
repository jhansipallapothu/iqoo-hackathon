import 'dart:io' show Platform;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// One place to tune how the app sounds.
///
/// Daily screen-reader users run speech considerably faster than the default,
/// and a slightly lowered pitch keeps the app distinct from nearby human
/// voices. Values are deliberately in one file: four screens/services used to
/// each hardcode their own, which drifted.
class SpeechConfig {
  /// One shared engine each. Android allows a single active SpeechRecognizer,
  /// and multiple FlutterTts instances speak over each other — every screen and
  /// service used to `new` its own. Use these instead.
  static final FlutterTts tts = FlutterTts();
  static final stt.SpeechToText speech = stt.SpeechToText();

  /// flutter_tts on Android does NOT map 1.0 to the engine's natural pace — its
  /// scale runs hot, so 1.0 already sounds rushed and ~0.5 is a normal talking
  /// speed. iOS uses 0.0–1.0 with ~0.5 as normal.
  /// ponytail: this is the calibration knob — comfortable speed is personal and
  /// it's the one number a blind tester will comment on. Nudge, rebuild, listen.
  static double get rate => Platform.isIOS ? 0.5 : 0.4;

  /// Slightly below neutral so it does not blend with people talking nearby.
  static const double pitch = 0.9;

  static const double volume = 1.0;

  /// Applies rate/pitch/volume. Always en-US: en-IN is frequently a network-only
  /// voice on Indian devices — speak() reports success and produces no audio.
  static Future<void> apply(FlutterTts tts) async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(rate);
    await tts.setPitch(pitch);
    await tts.setVolume(volume);
  }
}
