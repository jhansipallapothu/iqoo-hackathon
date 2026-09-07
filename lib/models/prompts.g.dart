// GENERATED CODE - hand-written to match json_serializable output.
// Regenerate with: flutter pub run build_runner build --delete-conflicting-outputs

part of 'prompts.dart';

PromptsConfig _$PromptsConfigFromJson(Map<String, dynamic> json) =>
    PromptsConfig(
      modes: (json['modes'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, ModePrompt.fromJson(e as Map<String, dynamic>)),
      ),
      location_context: LocationContext.fromJson(
          json['location_context'] as Map<String, dynamic>),
      offline_fallback: OfflineFallback.fromJson(
          json['offline_fallback'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PromptsConfigToJson(PromptsConfig instance) =>
    <String, dynamic>{
      'modes': instance.modes.map((k, e) => MapEntry(k, e.toJson())),
      'location_context': instance.location_context.toJson(),
      'offline_fallback': instance.offline_fallback.toJson(),
    };

ModePrompt _$ModePromptFromJson(Map<String, dynamic> json) => ModePrompt(
      en: json['en'] as String,
    );

Map<String, dynamic> _$ModePromptToJson(ModePrompt instance) =>
    <String, dynamic>{
      'en': instance.en,
    };

LocationContext _$LocationContextFromJson(Map<String, dynamic> json) =>
    LocationContext(
      en: json['en'] as String,
    );

Map<String, dynamic> _$LocationContextToJson(LocationContext instance) =>
    <String, dynamic>{
      'en': instance.en,
    };

OfflineFallback _$OfflineFallbackFromJson(Map<String, dynamic> json) =>
    OfflineFallback(
      en: json['en'] as String,
    );

Map<String, dynamic> _$OfflineFallbackToJson(OfflineFallback instance) =>
    <String, dynamic>{
      'en': instance.en,
    };
