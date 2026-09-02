import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gps_service.dart';
import 'localization_service.dart';
import 'speech_config.dart';

/// Calls a user-nominated emergency contact, with a spoken countdown that can
/// be cancelled.
///
/// Deliberately does NOT dial 112/108. An accidental shake or a misheard voice
/// command must never summon emergency services — the contact is someone the
/// user chose, and the countdown gives them time to stop it.
class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  static const _channel = MethodChannel('aiforall/phone');
  static const _prefsKey = 'emergency_contact';
  static const countdownSeconds = 5;

  final FlutterTts _tts = FlutterTts();
  final GPSService _gps = GPSService();
  final LocalizationService _localization = LocalizationService();

  Timer? _timer;
  bool get isCountingDown => _timer?.isActive ?? false;

  static Future<String?> getContact() async =>
      (await SharedPreferences.getInstance()).getString(_prefsKey);

  static Future<void> setContact(String number) async =>
      (await SharedPreferences.getInstance()).setString(_prefsKey, number);

  /// Speaks the user's location, then counts down and calls.
  /// [onTick] reports seconds remaining so the UI can show it.
  Future<void> trigger({void Function(int)? onTick}) async {
    final number = await getContact();
    await SpeechConfig.apply(_tts, tamil: _localization.isTamil);

    if (number == null || number.isEmpty) {
      await _speak(_localization.isTamil
          ? 'அவசர தொடர்பு எண் அமைக்கப்படவில்லை. அமைப்புகளில் சேர்க்கவும்.'
          : 'No emergency contact is set. Add one in settings.');
      return;
    }

    // Location first — it is the useful part even if the call never connects.
    await _speak(await _locationSentence());

    var remaining = countdownSeconds;
    onTick?.call(remaining);
    await _speak(_localization.isTamil
        ? 'அவசர அழைப்பு $remaining வினாடிகளில். நிறுத்த திரையைத் தட்டவும்.'
        : 'Calling your emergency contact in $remaining seconds. '
            'Tap the screen to stop.');

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      remaining--;
      onTick?.call(remaining);
      if (remaining <= 0) {
        t.cancel();
        await _placeCall(number);
      }
    });
  }

  /// Any tap / key press during the countdown stops it.
  Future<void> cancel() async {
    if (!isCountingDown) return;
    _timer?.cancel();
    _timer = null;
    await _speak(_localization.isTamil
        ? 'அவசர அழைப்பு ரத்து செய்யப்பட்டது.'
        : 'Emergency call cancelled.');
  }

  Future<void> _placeCall(String number) async {
    try {
      final placed =
          await _channel.invokeMethod<bool>('call', {'number': number});
      if (placed != true) {
        await _speak(_localization.isTamil
            ? 'டயலரைத் திறக்கிறது. அழைக்க பச்சை பொத்தானை அழுத்தவும்.'
            : 'Opening the dialler. Press the green button to call.');
      }
    } on PlatformException catch (_) {
      await _speak(_localization.isTamil
          ? 'அழைப்பு தோல்வியடைந்தது.'
          : 'The call could not be placed.');
    }
  }

  Future<String> _locationSentence() async {
    final pos = _gps.getLastKnownPosition();
    final address = _gps.getLastKnownAddress();
    if (pos == null) {
      return _localization.isTamil
          ? 'அவசரம். இருப்பிடம் தெரியவில்லை.'
          : 'Emergency. Location is not available.';
    }
    final lat = pos.latitude.toStringAsFixed(5);
    final lon = pos.longitude.toStringAsFixed(5);
    return _localization.isTamil
        ? 'அவசரம். நீங்கள் ${address ?? ''} இல் உள்ளீர்கள். அட்சரேகை $lat, தீர்க்கரேகை $lon.'
        : 'Emergency. You are at ${address ?? 'an unknown address'}. '
            'Latitude $lat, longitude $lon.';
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Ask for CALL_PHONE up front so the countdown does not stall on a dialog.
  static Future<void> ensurePermission() async {
    try {
      final has = await _channel.invokeMethod<bool>('hasCallPermission');
      if (has != true) await _channel.invokeMethod('requestCallPermission');
    } on PlatformException catch (_) {/* dialler fallback still works */}
  }

  void dispose() {
    _timer?.cancel();
    _tts.stop();
  }
}
