// Pure Dart — no Flutter imports, so `dart run` can execute the self-check.

enum SmsType { otp, spam, transaction, normal }

class SmsResult {
  final SmsType type;
  final String? code;
  const SmsResult(this.type, {this.code});
}

/// Offline, instant classification of an SMS body.
SmsResult classifySms(String body) {
  final t = body.toLowerCase();

  final otpWord = RegExp(
      r'otp|one[- ]?time|verification code|\bcode\b|passcode|secure code');
  final code = RegExp(r'(?<!\d)(\d{4,8})(?!\d)').firstMatch(body)?.group(1);
  if (otpWord.hasMatch(t) && code != null) {
    return SmsResult(SmsType.otp, code: code);
  }

  const spamHints = [
    'won', 'winner', 'lottery', 'prize', 'congratulations', 'click here',
    'claim now', 'limited offer', 'loan approved', 'free recharge', 'bit.ly',
    'earn money', 'work from home', 'get rich',
  ];
  if (spamHints.any(t.contains)) return const SmsResult(SmsType.spam);

  const txnHints = [
    'debited', 'credited', 'a/c', 'account', 'balance', 'txn', 'upi',
    'payment', 'received rs', 'spent', 'withdrawn', 'transferred',
  ];
  if (txnHints.any(t.contains)) return const SmsResult(SmsType.transaction);

  return const SmsResult(SmsType.normal);
}

/// Run: `dart run lib/services/sms_classifier.dart`
void main() {
  assert(classifySms('Your OTP is 449281. Do not share.').type == SmsType.otp);
  assert(classifySms('Use code 5567 to verify').code == '5567');
  assert(classifySms('Congratulations! You won a lottery prize').type ==
      SmsType.spam);
  assert(classifySms('Rs 500 debited from a/c XX1234').type ==
      SmsType.transaction);
  assert(classifySms('Are we meeting at 5?').type == SmsType.normal);
  assert(classifySms('Call me on 91234').type == SmsType.normal);
  print('sms_classifier: all checks passed');
}
