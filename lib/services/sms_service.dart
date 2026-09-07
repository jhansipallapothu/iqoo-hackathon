import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:another_telephony/telephony.dart' hide SmsType;
import 'config_service.dart';
import 'sms_classifier.dart';
import 'speech_config.dart';

/// Reads incoming SMS aloud for blind users, tagged by type.
///
/// Classification is local + instant (see [classifySms]) so it works fully
/// offline. RECEIVE_SMS / READ_SMS are restricted permissions — fine for a
/// sideloaded demo, not shippable to Play unless this is the SMS app.
class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Telephony _telephony = Telephony.instance;
  final FlutterTts _tts = SpeechConfig.tts;
  final ConfigService _config = ConfigService();
  bool _started = false;

  Future<void> initialize() async {
    if (_started) return;
    await _config.initialize();
    if (!_config.appConfig.features.ttsEnabled) return;

    final granted = await Permission.sms.request();
    if (!granted.isGranted) return;

    await SpeechConfig.apply(_tts);

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage msg) =>
          _announce(msg.address ?? 'unknown', msg.body ?? ''),
      listenInBackground: false,
    );
    _started = true;
  }

  void _announce(String sender, String body) {
    final r = classifySms(body);
    final who = _shortSender(sender);
    String line;
    switch (r.type) {
      case SmsType.otp:
        final spaced = r.code!.split('').join(' '); // digits, one by one
        line = 'O T P from $who: $spaced';
        break;
      case SmsType.spam:
        line = 'Likely spam message from $who.';
        break;
      case SmsType.transaction:
        line = 'Transaction alert from $who: $body';
        break;
      case SmsType.normal:
        line = 'Message from $who: $body';
        break;
    }
    _tts.speak(line);
  }

  String _shortSender(String s) {
    final alpha = RegExp(r'[A-Za-z]{3,}').firstMatch(s)?.group(0);
    if (alpha != null) return alpha;
    final digits = s.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : s;
  }

  void dispose() => _tts.stop();
}
