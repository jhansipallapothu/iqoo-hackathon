import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/ocr_service.dart';
import '../services/ai_service.dart';
import '../services/localization_service.dart';
import '../services/config_service.dart';
import '../services/speech_config.dart';
import '../services/hardware_keys.dart';
import '../services/read_explain_logic.dart';

/// Two-stage read flow. Fast path (ML Kit OCR) speaks the raw text in a beat;
/// slow path (language model) speaks a plain-language explanation on top,
/// sentence by sentence. If the slow path stalls, the fast path has already
/// answered — the screen is never silent.
class ReadExplainScreen extends StatefulWidget {
  final String imagePath;
  /// A spoken question from the user (double-tap-to-ask). Null = default
  /// per-document-type explanation.
  final String? question;
  const ReadExplainScreen({super.key, required this.imagePath, this.question});

  @override
  State<ReadExplainScreen> createState() => _ReadExplainScreenState();
}

enum _Stage { reading, ocrDone, explaining, done, failed }

class _ReadExplainScreenState extends State<ReadExplainScreen> {
  final _ocr = OcrService();
  final _ai = AIService();
  final _localization = LocalizationService();
  final _config = ConfigService();
  final _tts = FlutterTts();

  StreamSubscription<String>? _keySub;
  static const _phone = MethodChannel('aiforall/phone');

  _Stage _stage = _Stage.reading;
  String _ocrText = '';
  final _explanation = StringBuffer();
  String _spokenFull = ''; // everything said, for Volume-Down repeat
  String? _payUri; // set when a bill prints a UPI payee; enables "pay this bill"

  @override
  void initState() {
    super.initState();
    _keySub = HardwareKeys.stream.listen((_) {
      if (ModalRoute.of(context)?.isCurrent ?? true) _repeat();
    });
    _run();
  }

  @override
  void dispose() {
    _keySub?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _run() async {
    await _config.initialize();
    await _localization.initialize();
    await SpeechConfig.apply(_tts);
    // Queue utterances instead of the flutter_tts default (QUEUE_FLUSH), so the
    // "Reading" cue, the raw OCR readout, and each streamed explanation sentence
    // all play in full instead of cutting each other off.
    await _tts.setQueueMode(1);
    await _tts.awaitSpeakCompletion(false); // don't block _run on each utterance

    HapticFeedback.mediumImpact();
    await _speak(_localization.isTamil ? 'படிக்கிறது' : 'Reading');

    // No response cache here: the previous key (imagePath.hashCode) was unique
    // per capture so it never hit, and a content hash of the JPEG janks the UI
    // isolate. Each capture just re-runs — OCR is fast and the LLM has its own
    // timeout/fallback.

    // --- Fast path: OCR ---
    try {
      _ocrText = await _ocr.recognise(widget.imagePath);
    } catch (_) {
      _ocrText = '';
    }
    if (!mounted) return;
    setState(() => _stage = _Stage.ocrDone);

    final type = classifyDocument(_ocrText);
    if (type == DocType.bill) _payUri = buildUpiUri(_ocrText);

    if (_ocrText.isEmpty) {
      final msg = fallbackSentence(DocType.generic, '');
      setState(() => _stage = _Stage.failed);
      await _speak(msg);
      _spokenFull = msg;
      return;
    }

    // Speak the raw text right away — this is the guaranteed answer.
    final lead = _localization.isTamil ? 'உரை: ' : 'Text found. ';
    await _speak(lead + _preview(_ocrText));
    _spokenFull = lead + _preview(_ocrText);

    // Very little text usually means blur or a bad angle — a blind user can't
    // see that. Nudge a retry, but keep going with what we have.
    if (_ocrText.replaceAll(RegExp(r'\s+'), '').length < 12) {
      const hint =
          'That looked partial. Hold the item steady and capture again for more.';
      await _speak(hint);
      _spokenFull += ' $hint';
    }

    // --- Slow path: explanation, streamed ---
    setState(() => _stage = _Stage.explaining);
    final full = await _ai.explain(
      explainPrompt(type, _ocrText, userQuestion: widget.question),
      onSentence: (s) {
        if (!mounted) return;
        setState(() => _explanation.write('$s '));
        _speak(s);
        _spokenFull += ' $s';
      },
    );

    if (!mounted) return;
    if (full == null || full.trim().isEmpty) {
      // Model gave nothing usable — fall back to a template over the OCR text.
      final fb = fallbackSentence(type, _ocrText);
      setState(() => _stage = _Stage.failed);
      if (_explanation.isEmpty) {
        await _speak(fb);
        _spokenFull += ' $fb';
      }
    } else {
      setState(() => _stage = _Stage.done);
    }

    await _offerPayment();
  }

  /// Bill carried a UPI payee → tell the user, and arm long-press to pay.
  Future<void> _offerPayment() async {
    final uri = _payUri;
    if (uri == null || !mounted) return;
    final am = Uri.parse(uri).queryParameters['am'];
    final offer = am != null
        ? 'This bill can be paid by U P I. Press and hold anywhere to pay $am rupees.'
        : 'This bill lists a U P I ID. Press and hold anywhere to pay it.';
    setState(() {}); // reveal the on-screen Pay button for a sighted helper
    await _speak(offer);
    _spokenFull += ' $offer';
  }

  /// Hands the `upi://pay` link to the user's UPI app, which shows payee +
  /// amount and requires the UPI PIN. We never touch the payment itself.
  Future<void> _payBill() async {
    final uri = _payUri;
    if (uri == null) return;
    final q = Uri.parse(uri).queryParameters;
    final am = q['am'], pa = q['pa'] ?? '';
    HapticFeedback.mediumImpact();
    await _tts.stop();
    // Speak the amount + payee to completion before the UPI app takes focus.
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(am != null
        ? 'Opening your payment app to pay $am rupees to $pa. It will ask for your U P I PIN.'
        : 'Opening your payment app to pay $pa. It will ask for the amount and your PIN.');
    await _tts.awaitSpeakCompletion(false);
    try {
      final ok = await _phone.invokeMethod<bool>('payUpi', {'uri': uri}) ?? false;
      if (!ok && mounted) await _speak('No U P I app is installed on this phone.');
    } on PlatformException {
      if (mounted) await _speak('Could not open a payment app.');
    }
  }

  Future<void> _repeat() async {
    if (_spokenFull.trim().isEmpty) return;
    await _tts.stop();
    await _speak(_spokenFull.trim());
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.speak(text.trim());
  }

  String _preview(String s) =>
      s.length > 240 ? '${s.substring(0, 240)}…' : s;

  String get _statusLabel {
    final ta = _localization.isTamil;
    switch (_stage) {
      case _Stage.reading:
        return ta ? 'படிக்கிறது…' : 'Reading…';
      case _Stage.ocrDone:
      case _Stage.explaining:
        return ta ? 'விளக்குகிறது…' : 'Explaining…';
      case _Stage.done:
        return ta ? 'முடிந்தது' : 'Done';
      case _Stage.failed:
        return ta ? 'உரை மட்டும்' : 'Text only';
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _stage == _Stage.reading ||
        _stage == _Stage.ocrDone ||
        _stage == _Stage.explaining;
    return Scaffold(
      appBar: AppBar(
        title: Text(_localization.isTamil ? 'படித்து விளக்கு' : 'Read & Explain'),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay),
            tooltip: 'Repeat',
            onPressed: _repeat,
          ),
        ],
      ),
      // The whole body is a repeat button for a blind user; back arrow exits.
      body: Semantics(
        button: true,
        liveRegion: true,
        label: _statusLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _repeat,
          onLongPress: _payUri != null ? _payBill : null,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(widget.imagePath),
                  key: ValueKey(widget.imagePath),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // ponytail: bound decode so a full-res capture can't blow the
                  // image cache and render nothing.
                  cacheWidth: 1080,
                  frameBuilder: (context, child, frame, wasSync) {
                    if (wasSync || frame != null) return child;
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stack) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    alignment: Alignment.center,
                    child: Icon(Icons.image_not_supported,
                        size: 40, color: Colors.grey[600]),
                  ),
                ),
              ),
              if (_payUri != null) ...[
                const SizedBox(height: 12),
                Builder(builder: (_) {
                  final am = Uri.parse(_payUri!).queryParameters['am'];
                  final label = am != null ? 'Pay ₹$am' : 'Pay this bill';
                  return Semantics(
                    button: true,
                    label: '$label. Also: press and hold anywhere on the screen.',
                    child: FilledButton.icon(
                      onPressed: _payBill,
                      icon: const Icon(Icons.payments),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                        textStyle: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      label: Text(label),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (busy)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Icon(_stage == _Stage.done ? Icons.check_circle : Icons.info,
                        size: 18),
                  const SizedBox(width: 8),
                  Text(_statusLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (_explanation.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_explanation.toString().trim(),
                    style: const TextStyle(fontSize: 18)),
              ],
              if (_stage != _Stage.reading) ...[
                const Divider(height: 32),
                Text(_localization.isTamil ? 'கண்டறியப்பட்ட உரை' : 'Detected text',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  _ocrText.isNotEmpty
                      ? _ocrText
                      : (_localization.isTamil
                          ? 'உரை எதுவும் கண்டறியப்படவில்லை'
                          : 'No readable text found'),
                  style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: _ocrText.isNotEmpty
                          ? Colors.black87
                          : Colors.grey[600],
                      fontStyle: _ocrText.isNotEmpty
                          ? FontStyle.normal
                          : FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
