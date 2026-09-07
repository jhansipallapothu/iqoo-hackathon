import 'package:json_annotation/json_annotation.dart';

part 'app_config.g.dart';

@JsonSerializable()
class AppConfig {
  final AppInfo app;
  final Features features;
  final VoiceAssistantConfig voice_assistant;
  final ModelConfig model;
  final CameraConfig camera;
  final GPSConfig gps;
  final CacheConfig cache;
  final DemoConfig demo;

  AppConfig({
    required this.app,
    required this.features,
    required this.voice_assistant,
    required this.model,
    required this.camera,
    required this.gps,
    required this.cache,
    required this.demo,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);
  Map<String, dynamic> toJson() => _$AppConfigToJson(this);
}

@JsonSerializable()
class AppInfo {
  final String name;
  final String version;
  final String build;

  AppInfo({required this.name, required this.version, required this.build});

  factory AppInfo.fromJson(Map<String, dynamic> json) => _$AppInfoFromJson(json);
  Map<String, dynamic> toJson() => _$AppInfoToJson(this);
}

@JsonSerializable()
class Features {
  @JsonKey(name: 'on_device_llm')
  final bool onDeviceLLM;
  
  @JsonKey(name: 'offline_mode')
  final bool offlineMode;

  @JsonKey(name: 'gps_enabled')
  final bool gpsEnabled;
  
  @JsonKey(name: 'tts_enabled')
  final bool ttsEnabled;
  
  @JsonKey(name: 'vibration_feedback')
  final bool vibrationFeedback;
  
  @JsonKey(name: 'web_browsing')
  final bool webBrowsing;
  
  @JsonKey(name: 'voice_assistant')
  final bool voiceAssistant;
  
  @JsonKey(name: 'shake_wake_word')
  final bool shakeWakeWord;
  
  @JsonKey(name: 'high_contrast')
  final bool highContrast;
  
  @JsonKey(name: 'large_text')
  final bool largeText;
  
  @JsonKey(name: 'accessibility_mode')
  final bool accessibilityMode;

  Features({
    required this.onDeviceLLM,
    required this.offlineMode,
    required this.gpsEnabled,
    required this.ttsEnabled,
    required this.vibrationFeedback,
    required this.webBrowsing,
    required this.voiceAssistant,
    required this.shakeWakeWord,
    required this.highContrast,
    required this.largeText,
    required this.accessibilityMode,
  });

  factory Features.fromJson(Map<String, dynamic> json) => _$FeaturesFromJson(json);
  Map<String, dynamic> toJson() => _$FeaturesToJson(this);
}

@JsonSerializable()
class VoiceAssistantConfig {
  @JsonKey(name: 'wake_word')
  final String wakeWord;

  @JsonKey(name: 'listen_timeout_seconds')
  final int listenTimeoutSeconds;
  
  @JsonKey(name: 'pause_timeout_seconds')
  final int pauseTimeoutSeconds;
  
  @JsonKey(name: 'confidence_threshold')
  final double confidenceThreshold;
  
  @JsonKey(name: 'continuous_listening')
  final bool continuousListening;
  
  @JsonKey(name: 'shake_threshold')
  final double shakeThreshold;

  VoiceAssistantConfig({
    required this.wakeWord,
    required this.listenTimeoutSeconds,
    required this.pauseTimeoutSeconds,
    required this.confidenceThreshold,
    required this.continuousListening,
    required this.shakeThreshold,
  });

  factory VoiceAssistantConfig.fromJson(Map<String, dynamic> json) => _$VoiceAssistantConfigFromJson(json);
  Map<String, dynamic> toJson() => _$VoiceAssistantConfigToJson(this);
}

@JsonSerializable()
class ModelConfig {
  final String name;
  final String path;
  final String vocab_path;
  final int max_tokens;
  final double temperature;
  final double top_p;

  ModelConfig({
    required this.name,
    required this.path,
    required this.vocab_path,
    required this.max_tokens,
    required this.temperature,
    required this.top_p,
  });

  factory ModelConfig.fromJson(Map<String, dynamic> json) => _$ModelConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ModelConfigToJson(this);
}

@JsonSerializable()
class CameraConfig {
  final String resolution;
  final List<String> formats;
  final int max_size_mb;

  CameraConfig({
    required this.resolution,
    required this.formats,
    required this.max_size_mb,
  });

  factory CameraConfig.fromJson(Map<String, dynamic> json) => _$CameraConfigFromJson(json);
  Map<String, dynamic> toJson() => _$CameraConfigToJson(this);
}

@JsonSerializable()
class GPSConfig {
  @JsonKey(name: 'accuracy_threshold_high')
  final int accuracyThresholdHigh;
  
  @JsonKey(name: 'accuracy_threshold_medium')
  final int accuracyThresholdMedium;
  
  @JsonKey(name: 'update_interval_ms')
  final int updateIntervalMs;
  
  @JsonKey(name: 'cache_duration_seconds')
  final int cacheDurationSeconds;

  GPSConfig({
    required this.accuracyThresholdHigh,
    required this.accuracyThresholdMedium,
    required this.updateIntervalMs,
    required this.cacheDurationSeconds,
  });

  factory GPSConfig.fromJson(Map<String, dynamic> json) => _$GPSConfigFromJson(json);
  Map<String, dynamic> toJson() => _$GPSConfigToJson(this);
}

@JsonSerializable()
class CacheConfig {
  @JsonKey(name: 'max_entries')
  final int maxEntries;
  
  @JsonKey(name: 'max_age_days')
  final int maxAgeDays;
  
  @JsonKey(name: 'preload_test_images')
  final bool preloadTestImages;

  CacheConfig({
    required this.maxEntries,
    required this.maxAgeDays,
    required this.preloadTestImages,
  });

  factory CacheConfig.fromJson(Map<String, dynamic> json) => _$CacheConfigFromJson(json);
  Map<String, dynamic> toJson() => _$CacheConfigToJson(this);
}

@JsonSerializable()
class DemoConfig {
  @JsonKey(name: 'preloaded_images')
  final List<String> preloadedImages;
  
  @JsonKey(name: 'cached_responses')
  final bool cachedResponses;

  DemoConfig({
    required this.preloadedImages,
    required this.cachedResponses,
  });

  factory DemoConfig.fromJson(Map<String, dynamic> json) => _$DemoConfigFromJson(json);
  Map<String, dynamic> toJson() => _$DemoConfigToJson(this);
}