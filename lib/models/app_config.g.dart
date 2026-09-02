// GENERATED CODE - hand-written to match json_serializable output.
// Regenerate with: flutter pub run build_runner build --delete-conflicting-outputs

part of 'app_config.dart';

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => AppConfig(
      app: AppInfo.fromJson(json['app'] as Map<String, dynamic>),
      features: Features.fromJson(json['features'] as Map<String, dynamic>),
      voice_assistant: VoiceAssistantConfig.fromJson(
          json['voice_assistant'] as Map<String, dynamic>),
      model: ModelConfig.fromJson(json['model'] as Map<String, dynamic>),
      camera: CameraConfig.fromJson(json['camera'] as Map<String, dynamic>),
      gps: GPSConfig.fromJson(json['gps'] as Map<String, dynamic>),
      cache: CacheConfig.fromJson(json['cache'] as Map<String, dynamic>),
      demo: DemoConfig.fromJson(json['demo'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
      'app': instance.app.toJson(),
      'features': instance.features.toJson(),
      'voice_assistant': instance.voice_assistant.toJson(),
      'model': instance.model.toJson(),
      'camera': instance.camera.toJson(),
      'gps': instance.gps.toJson(),
      'cache': instance.cache.toJson(),
      'demo': instance.demo.toJson(),
    };

AppInfo _$AppInfoFromJson(Map<String, dynamic> json) => AppInfo(
      name: json['name'] as String,
      version: json['version'] as String,
      build: json['build'] as String,
    );

Map<String, dynamic> _$AppInfoToJson(AppInfo instance) => <String, dynamic>{
      'name': instance.name,
      'version': instance.version,
      'build': instance.build,
    };

Features _$FeaturesFromJson(Map<String, dynamic> json) => Features(
      onDeviceLLM: json['on_device_llm'] as bool,
      offlineMode: json['offline_mode'] as bool,
      tamilSupport: json['tamil_support'] as bool,
      gpsEnabled: json['gps_enabled'] as bool,
      ttsEnabled: json['tts_enabled'] as bool,
      vibrationFeedback: json['vibration_feedback'] as bool,
      webBrowsing: json['web_browsing'] as bool,
      voiceAssistant: json['voice_assistant'] as bool,
      shakeWakeWord: json['shake_wake_word'] as bool,
      highContrast: json['high_contrast'] as bool,
      largeText: json['large_text'] as bool,
      accessibilityMode: json['accessibility_mode'] as bool,
    );

Map<String, dynamic> _$FeaturesToJson(Features instance) => <String, dynamic>{
      'on_device_llm': instance.onDeviceLLM,
      'offline_mode': instance.offlineMode,
      'tamil_support': instance.tamilSupport,
      'gps_enabled': instance.gpsEnabled,
      'tts_enabled': instance.ttsEnabled,
      'vibration_feedback': instance.vibrationFeedback,
      'web_browsing': instance.webBrowsing,
      'voice_assistant': instance.voiceAssistant,
      'shake_wake_word': instance.shakeWakeWord,
      'high_contrast': instance.highContrast,
      'large_text': instance.largeText,
      'accessibility_mode': instance.accessibilityMode,
    };

VoiceAssistantConfig _$VoiceAssistantConfigFromJson(
        Map<String, dynamic> json) =>
    VoiceAssistantConfig(
      wakeWord: json['wake_word'] as String,
      wakeWordTa: json['wake_word_ta'] as String,
      listenTimeoutSeconds: (json['listen_timeout_seconds'] as num).toInt(),
      pauseTimeoutSeconds: (json['pause_timeout_seconds'] as num).toInt(),
      confidenceThreshold:
          (json['confidence_threshold'] as num).toDouble(),
      continuousListening: json['continuous_listening'] as bool,
      shakeThreshold: (json['shake_threshold'] as num).toDouble(),
    );

Map<String, dynamic> _$VoiceAssistantConfigToJson(
        VoiceAssistantConfig instance) =>
    <String, dynamic>{
      'wake_word': instance.wakeWord,
      'wake_word_ta': instance.wakeWordTa,
      'listen_timeout_seconds': instance.listenTimeoutSeconds,
      'pause_timeout_seconds': instance.pauseTimeoutSeconds,
      'confidence_threshold': instance.confidenceThreshold,
      'continuous_listening': instance.continuousListening,
      'shake_threshold': instance.shakeThreshold,
    };

ModelConfig _$ModelConfigFromJson(Map<String, dynamic> json) => ModelConfig(
      name: json['name'] as String,
      path: json['path'] as String,
      vocab_path: json['vocab_path'] as String,
      max_tokens: (json['max_tokens'] as num).toInt(),
      temperature: (json['temperature'] as num).toDouble(),
      top_p: (json['top_p'] as num).toDouble(),
    );

Map<String, dynamic> _$ModelConfigToJson(ModelConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'vocab_path': instance.vocab_path,
      'max_tokens': instance.max_tokens,
      'temperature': instance.temperature,
      'top_p': instance.top_p,
    };

CameraConfig _$CameraConfigFromJson(Map<String, dynamic> json) => CameraConfig(
      resolution: json['resolution'] as String,
      formats: (json['formats'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      max_size_mb: (json['max_size_mb'] as num).toInt(),
    );

Map<String, dynamic> _$CameraConfigToJson(CameraConfig instance) =>
    <String, dynamic>{
      'resolution': instance.resolution,
      'formats': instance.formats,
      'max_size_mb': instance.max_size_mb,
    };

GPSConfig _$GPSConfigFromJson(Map<String, dynamic> json) => GPSConfig(
      accuracyThresholdHigh: (json['accuracy_threshold_high'] as num).toInt(),
      accuracyThresholdMedium:
          (json['accuracy_threshold_medium'] as num).toInt(),
      updateIntervalMs: (json['update_interval_ms'] as num).toInt(),
      cacheDurationSeconds: (json['cache_duration_seconds'] as num).toInt(),
    );

Map<String, dynamic> _$GPSConfigToJson(GPSConfig instance) => <String, dynamic>{
      'accuracy_threshold_high': instance.accuracyThresholdHigh,
      'accuracy_threshold_medium': instance.accuracyThresholdMedium,
      'update_interval_ms': instance.updateIntervalMs,
      'cache_duration_seconds': instance.cacheDurationSeconds,
    };

CacheConfig _$CacheConfigFromJson(Map<String, dynamic> json) => CacheConfig(
      maxEntries: (json['max_entries'] as num).toInt(),
      maxAgeDays: (json['max_age_days'] as num).toInt(),
      preloadTestImages: json['preload_test_images'] as bool,
    );

Map<String, dynamic> _$CacheConfigToJson(CacheConfig instance) =>
    <String, dynamic>{
      'max_entries': instance.maxEntries,
      'max_age_days': instance.maxAgeDays,
      'preload_test_images': instance.preloadTestImages,
    };

DemoConfig _$DemoConfigFromJson(Map<String, dynamic> json) => DemoConfig(
      preloadedImages: (json['preloaded_images'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      cachedResponses: json['cached_responses'] as bool,
    );

Map<String, dynamic> _$DemoConfigToJson(DemoConfig instance) =>
    <String, dynamic>{
      'preloaded_images': instance.preloadedImages,
      'cached_responses': instance.cachedResponses,
    };
