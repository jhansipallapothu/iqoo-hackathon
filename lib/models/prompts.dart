import 'package:json_annotation/json_annotation.dart';

part 'prompts.g.dart';

@JsonSerializable()
class PromptsConfig {
  final Map<String, ModePrompt> modes;
  final LocationContext location_context;
  final OfflineFallback offline_fallback;

  PromptsConfig({
    required this.modes,
    required this.location_context,
    required this.offline_fallback,
  });

  factory PromptsConfig.fromJson(Map<String, dynamic> json) => _$PromptsConfigFromJson(json);
  Map<String, dynamic> toJson() => _$PromptsConfigToJson(this);
}

@JsonSerializable()
class ModePrompt {
  final String en;
  final String ta;

  ModePrompt({required this.en, required this.ta});

  factory ModePrompt.fromJson(Map<String, dynamic> json) => _$ModePromptFromJson(json);
  Map<String, dynamic> toJson() => _$ModePromptToJson(this);
}

@JsonSerializable()
class LocationContext {
  final String en;
  final String ta;

  LocationContext({required this.en, required this.ta});

  factory LocationContext.fromJson(Map<String, dynamic> json) => _$LocationContextFromJson(json);
  Map<String, dynamic> toJson() => _$LocationContextToJson(this);
}

@JsonSerializable()
class OfflineFallback {
  final String en;
  final String ta;

  OfflineFallback({required this.en, required this.ta});

  factory OfflineFallback.fromJson(Map<String, dynamic> json) => _$OfflineFallbackFromJson(json);
  Map<String, dynamic> toJson() => _$OfflineFallbackToJson(this);
}