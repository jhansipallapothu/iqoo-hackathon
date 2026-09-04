import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import '../models/prompts.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  AppConfig? _appConfig;
  PromptsConfig? _promptsConfig;
  bool _initialized = false;

  AppConfig get appConfig => _appConfig!;
  PromptsConfig get promptsConfig => _promptsConfig!;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _loadConfigs();
    _initialized = true;
  }

  static const _featureKeys = [
    'on_device_llm', 'offline_mode', 'tamil_support', 'gps_enabled',
    'tts_enabled', 'vibration_feedback', 'web_browsing', 'voice_assistant',
    'shake_wake_word', 'high_contrast', 'large_text', 'accessibility_mode',
  ];

  Future<void> _loadConfigs() async {
    try {
      final appConfigJson = await rootBundle.loadString('assets/config/app_config.json');
      final appConfigMap = json.decode(appConfigJson);
      _appConfig = AppConfig.fromJson(appConfigMap);

      final promptsJson = await rootBundle.loadString('assets/config/prompts.json');
      final promptsMap = json.decode(promptsJson);
      _promptsConfig = PromptsConfig.fromJson(promptsMap);

      // Re-apply any toggles the user changed in Settings — without this the
      // asset defaults win on every restart and the switches don't stick.
      final prefs = await SharedPreferences.getInstance();
      for (final f in _featureKeys) {
        final saved = prefs.getBool('feature_$f');
        if (saved != null) await updateFeature(f, saved);
      }
    } catch (e) {
      throw Exception('Failed to load configs: $e');
    }
  }

  String getPrompt(String mode, {required bool isTamil}) {
    final modePrompt = _promptsConfig!.modes[mode];
    if (modePrompt == null) return _promptsConfig!.modes['explore']!.en;
    return isTamil ? modePrompt.ta : modePrompt.en;
  }

  String getLocationContext({required bool isTamil, required String address, required double lat, required double lon, required double accuracy}) {
    final context = _promptsConfig!.location_context;
    final template = isTamil ? context.ta : context.en;
    return template
        .replaceAll('{address}', address)
        .replaceAll('{lat}', lat.toStringAsFixed(6))
        .replaceAll('{lon}', lon.toStringAsFixed(6))
        .replaceAll('{accuracy}', accuracy.toStringAsFixed(1));
  }

  String getOfflineFallback({required bool isTamil}) {
    return isTamil ? _promptsConfig!.offline_fallback.ta : _promptsConfig!.offline_fallback.en;
  }

  VoiceAssistantConfig get voiceAssistantConfig => _appConfig!.voice_assistant;

  Future<void> updateFeature(String feature, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feature_$feature', enabled);
    
    // Update in-memory config
    final features = _appConfig!.features;
    _appConfig = AppConfig(
      app: _appConfig!.app,
      features: Features(
        onDeviceLLM: feature == 'on_device_llm' ? enabled : features.onDeviceLLM,
        offlineMode: feature == 'offline_mode' ? enabled : features.offlineMode,
        tamilSupport: feature == 'tamil_support' ? enabled : features.tamilSupport,
        gpsEnabled: feature == 'gps_enabled' ? enabled : features.gpsEnabled,
        ttsEnabled: feature == 'tts_enabled' ? enabled : features.ttsEnabled,
        vibrationFeedback: feature == 'vibration_feedback' ? enabled : features.vibrationFeedback,
        webBrowsing: feature == 'web_browsing' ? enabled : features.webBrowsing,
        voiceAssistant: feature == 'voice_assistant' ? enabled : features.voiceAssistant,
        shakeWakeWord: feature == 'shake_wake_word' ? enabled : features.shakeWakeWord,
        highContrast: feature == 'high_contrast' ? enabled : features.highContrast,
        largeText: feature == 'large_text' ? enabled : features.largeText,
        accessibilityMode: feature == 'accessibility_mode' ? enabled : features.accessibilityMode,
      ),
      voice_assistant: _appConfig!.voice_assistant,
      model: _appConfig!.model,
      camera: _appConfig!.camera,
      gps: _appConfig!.gps,
      cache: _appConfig!.cache,
      demo: _appConfig!.demo,
    );
  }

  bool isFeatureEnabled(String feature) {
    final features = _appConfig!.features;
    switch (feature) {
      case 'on_device_llm':
        return features.onDeviceLLM;
      case 'offline_mode':
        return features.offlineMode;
      case 'tamil_support':
        return features.tamilSupport;
      case 'gps_enabled':
        return features.gpsEnabled;
      case 'tts_enabled':
        return features.ttsEnabled;
      case 'vibration_feedback':
        return features.vibrationFeedback;
      case 'web_browsing':
        return features.webBrowsing;
      case 'voice_assistant':
        return features.voiceAssistant;
      case 'shake_wake_word':
        return features.shakeWakeWord;
      case 'high_contrast':
        return features.highContrast;
      case 'large_text':
        return features.largeText;
      case 'accessibility_mode':
        return features.accessibilityMode;
      default:
        return false;
    }
  }
}