import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR (ML Kit, Latin script). Fast path of the two-stage read flow:
/// speaks the raw text in ~100-300ms while the language model works.
class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Full recognised text, whitespace collapsed. Empty string if nothing found.
  Future<String> recognise(String imagePath) async {
    final result =
        await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    return result.text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  void dispose() => _recognizer.close();
}
