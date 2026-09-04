// Pure Dart — no Flutter imports, so `dart run` can execute the self-check.
// Everything here is the fallback path: what the app says when the language
// model is slow, absent, or offline. It must never produce nothing.

enum DocType { medicine, notice, bill, generic }

/// Cheap keyword classification of OCR output. Used to pick a spoken template
/// when the LLM does not answer in time.
DocType classifyDocument(String ocrText) {
  final t = ocrText.toLowerCase();

  const medicine = [
    'mg', 'tablet', 'tablets', 'capsule', 'syrup', 'dosage', 'dose',
    'paracetamol', 'ibuprofen', 'amoxicillin', 'antibiotic', 'ip ',
    'expiry', 'exp.', 'mfd', 'batch no', 'rx',
  ];
  const bill = [
    'amount due', 'total due', 'bill', 'invoice', 'due date', 'units',
    'meter', 'consumer no', 'account no', 'payable', 'rs.', '₹',
  ];
  const notice = [
    'notice', 'applications', 'apply', 'office', 'government', 'scheme',
    'eligible', 'documents required', 'last date', 'submit', 'aadhaar',
  ];

  int score(List<String> words) => words.where(t.contains).length;

  final m = score(medicine), b = score(bill), n = score(notice);
  if (m == 0 && b == 0 && n == 0) return DocType.generic;
  if (m >= b && m >= n) return DocType.medicine;
  if (b >= n) return DocType.bill;
  return DocType.notice;
}

/// Spoken fallback when no explanation arrives. Names the document type and
/// reads what was found, so the user always learns something.
String fallbackSentence(DocType type, String ocrText) {
  final trimmed = collapseWhitespace(ocrText);
  final snippet =
      trimmed.length > 200 ? '${trimmed.substring(0, 200)}…' : trimmed;
  switch (type) {
    case DocType.medicine:
      return 'This looks like medicine packaging. It reads: $snippet';
    case DocType.bill:
      return 'This looks like a bill. It reads: $snippet';
    case DocType.notice:
      return 'This looks like an official notice. It reads: $snippet';
    case DocType.generic:
      return trimmed.isEmpty
          ? 'No readable text found. Try moving closer, or hold the phone steadier.'
          : 'It reads: $snippet';
  }
}

/// The instruction sent to the language model. Deliberately asks for actions,
/// not a summary — explaining what to do is the whole product.
String explainPrompt(DocType type, String ocrText, {String? userQuestion}) {
  const base =
      'You are helping a blind person who cannot see this document. '
      'Answer in at most three short sentences, plain spoken English, no '
      'formatting or bullet points. Do not repeat the raw text back.';
  final q = userQuestion?.trim();
  final ask = (q != null && q.isNotEmpty)
      ? 'The person asks: "$q". Answer that using the document; '
          'if the document does not say, tell them so.'
      : switch (type) {
          DocType.medicine =>
            'Say what this medicine is for, the dose limit, and the expiry if present.',
          DocType.bill =>
            'Say who the bill is from, how much is owed, and the due date.',
          DocType.notice =>
            'Say what this notice is about, what the person must do, and by when.',
          DocType.generic => 'Say what this document is and what it means.',
        };
  return '$base $ask\n\nText from the document:\n$ocrText';
}

/// If this looks like a bill that prints a UPI payee, build a `upi://pay`
/// deep link. The user's own UPI app then shows payee + amount and demands the
/// UPI PIN — we never see or move the money. Returns null when there is no
/// payee to pay, so the caller only offers "pay" when it can actually work.
///
/// ponytail: reads a VPA printed as plain text. Bills that carry only a UPI
/// *QR* need ML Kit barcode scanning — add that if the Sept spike shows plain
/// VPAs are rare on real bills.
String? buildUpiUri(String ocrText) {
  // UPI handle: name@bank. The bank suffix is letters only and not followed by
  // a dot, so an e-mail (`billing@company.com`) is rejected.
  final vpa = RegExp(r'(?<![\w.@])[A-Za-z0-9.\-_]{2,}@[A-Za-z]{2,}(?![A-Za-z.])')
      .firstMatch(ocrText);
  if (vpa == null) return null;

  final params = <String, String>{
    'pa': vpa.group(0)!,
    'pn': 'Biller',
    'cu': 'INR',
  };

  final amt = RegExp(
    r'(?:₹|rs\.?|inr)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  ).firstMatch(ocrText);
  final n = amt == null ? null : double.tryParse(amt.group(1)!.replaceAll(',', ''));
  if (n != null && n > 0) params['am'] = n.toStringAsFixed(2);

  final q = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return 'upi://pay?$q';
}

/// First complete sentence, so speech can start before generation finishes.
/// Returns null until at least one sentence terminator has arrived.
String? firstSentence(String partial) {
  final match = RegExp(r'^.*?[.!?](\s|$)').firstMatch(partial);
  final s = match?.group(0)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}

String collapseWhitespace(String s) =>
    s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Run: `dart run lib/services/read_explain_logic.dart`
void main() {
  assert(classifyDocument('PARACETAMOL IP 650mg Tablets Exp. 01/2026') ==
      DocType.medicine);
  assert(classifyDocument('Electricity bill. Amount due Rs. 840. Due date 12/09') ==
      DocType.bill);
  assert(classifyDocument(
          'NOTICE: Ration card applications open. Submit Aadhaar at the office.') ==
      DocType.notice);
  assert(classifyDocument('hello world') == DocType.generic);

  // Empty OCR must still say something useful, never an empty utterance.
  assert(fallbackSentence(DocType.generic, '   ').contains('No readable text'));
  assert(fallbackSentence(DocType.medicine, 'Crocin 650').contains('medicine'));

  // Streaming: nothing to speak until a terminator arrives.
  assert(firstSentence('This is parac') == null);
  assert(firstSentence('This is paracetamol. It treats') ==
      'This is paracetamol.');

  assert(explainPrompt(DocType.medicine, 'x').contains('dose limit'));
  assert(collapseWhitespace(' a \n\n b  ') == 'a b');

  // UPI deep link: only when a real VPA is present; amount is optional.
  assert(buildUpiUri('EB bill. Pay to tneb@okhdfcbank. Amount due Rs. 1,240.50') ==
      'upi://pay?pa=tneb%40okhdfcbank&pn=Biller&cu=INR&am=1240.50');
  assert(buildUpiUri('UPI ID 9876543210@ybl total ₹840') ==
      'upi://pay?pa=9876543210%40ybl&pn=Biller&cu=INR&am=840.00');
  assert(buildUpiUri('Pay at counter to water.board@sbi') ==
      'upi://pay?pa=water.board%40sbi&pn=Biller&cu=INR');
  assert(buildUpiUri('Queries: billing@company.com, amount due Rs. 500') == null);
  assert(buildUpiUri('Electricity bill, amount due Rs. 840, no online payment') ==
      null);

  print('read_explain_logic: all checks passed');
}
