import 'dart:typed_data';

/// On-device LLM stub.
///
/// ponytail: the real on-device path is `flutter_gemma` (Gemma 3n on the NPU),
/// wired in during the hackathon. Until then this always reports "unavailable"
/// so [AIService] falls back to cloud Gemini. Keeps the public surface stable.
class OnDeviceLLMService {
  static final OnDeviceLLMService _instance = OnDeviceLLMService._internal();
  factory OnDeviceLLMService() => _instance;
  OnDeviceLLMService._internal();

  bool get initialized => false;
  bool get initializing => false;
  String? get error => 'On-device LLM not wired yet (using cloud fallback).';

  Future<bool> initialize() async => false;

  Future<String?> generateResponse(String prompt,
          {List<Uint8List>? images}) async =>
      null; // null => AIService uses cloud

  void dispose() {}
}
