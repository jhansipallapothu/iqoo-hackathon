import 'package:flutter/services.dart';

/// Volume-rocker events forwarded from MainActivity while the app is foreground.
/// Emits 'volume_up' / 'volume_down'.
class HardwareKeys {
  static const _channel = EventChannel('aiforall/hardware_keys');
  static Stream<String>? _stream;

  static Stream<String> get stream =>
      _stream ??= _channel.receiveBroadcastStream().map((e) => e as String);
}

/// Last thing the app spoke — so Volume-Down can repeat it.
class SpokenText {
  static String? last;
}
