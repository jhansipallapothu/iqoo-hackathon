import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

/// Runs Qwen3 0.6B locally via `flutter_gemma` (LiteRT-LM engine, preferring
/// the Snapdragon NPU — the plugin falls back to GPU then CPU if the NPU
/// backend isn't available on a given phone). No Hugging Face account/token
/// is needed — this model is public.
///
/// The model (~586 MB) downloads once over network and is cached on device by
/// the plugin; airplane-mode use is only true after that first successful
/// download. Any initialization or generation failure here is silent to the
/// caller ([AiService.explain]/[generateResponse] fall back to cloud) —
/// on-device is a fallible enhancement, never the only path.
class OnDeviceLLMService {
  static final OnDeviceLLMService _instance = OnDeviceLLMService._internal();
  factory OnDeviceLLMService() => _instance;
  OnDeviceLLMService._internal();

  static const _modelType = ModelType.qwen3;
  static const _hfRepo = 'litert-community/Qwen3-0.6B';
  static const _systemInstruction =
      'You are a plain-language reading assistant for a blind user. Explain '
      'the given text in short, clear sentences. Never invent a dose, '
      'expiry, amount, address, or other detail that is not in the text.';

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _initializing = false;
  bool _initialized = false;
  String? _error;

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  String? get error => _error;

  Future<bool> initialize({void Function(int percent)? onDownloadProgress}) async {
    if (_initialized) return true;
    if (_initializing) return false;
    _initializing = true;
    _error = null;
    try {
      await FlutterGemma.initialize(inferenceEngines: [const LiteRtLmEngine()]);

      if (!FlutterGemma.hasActiveModel()) {
        await FlutterGemma.installModel(
          modelType: _modelType,
          fileType: ModelFileType.litertlm,
        )
            .fromHuggingFace(_hfRepo)
            .withProgress((p) => onDownloadProgress?.call(p))
            .install();
      }

      _model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.npu,
      );
      _chat = await _model!.createChat(systemInstruction: _systemInstruction);
      _initialized = true;
      return true;
    } catch (e) {
      _error = 'On-device model unavailable: $e';
      _model = null;
      _chat = null;
      _initialized = false;
      return false;
    } finally {
      _initializing = false;
    }
  }

  /// Returns the full response text, or null on any failure (images are
  /// accepted for a future multimodal seam; unused by the text-only Read &
  /// Explain path today).
  Future<String?> generateResponse(String prompt,
      {List<Uint8List>? images}) async {
    final chat = _chat;
    if (!_initialized || chat == null) return null;
    try {
      await chat.addQueryChunk(
        images != null && images.isNotEmpty
            ? Message.withImages(text: prompt, imageBytes: images, isUser: true)
            : Message.text(text: prompt, isUser: true),
      );
      final response = await chat.generateChatResponse();
      if (response is! TextResponse) return null;
      final text = response.token.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _model?.close();
    _model = null;
    _chat = null;
    _initialized = false;
  }
}
