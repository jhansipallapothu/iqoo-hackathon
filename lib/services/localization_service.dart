import 'dart:convert';
import 'package:flutter/services.dart';

class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  // English-only build. The Tamil string branches scattered through the app are
  // dead code until a proper l10n pass — isTamil is hard-wired false so they
  // never execute. Do not re-enable without finishing the Tamil translations.
  Map<String, String> _strings = {};
  final String _currentLocale = 'en';
  bool _initialized = false;

  String get currentLocale => _currentLocale;
  bool get isTamil => false;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await _loadStrings('en');
    _initialized = true;
  }

  Future<void> _loadStrings(String locale) async {
    try {
      final jsonString = await rootBundle.loadString('assets/l10n/$locale.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _strings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      _strings = {};
    }
  }

  // No-op: this build ships English only.
  Future<void> setLocale(String locale) async {}

  String tr(String key, {Map<String, String>? params}) {
    String result = _strings[key] ?? key;
    
    if (params != null) {
      params.forEach((key, value) {
        result = result.replaceAll('{$key}', value);
      });
    }
    
    return result;
  }

  List<String> get supportedLocales => ['en'];
}