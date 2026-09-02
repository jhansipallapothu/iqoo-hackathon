import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  static const String _localeKey = 'app_locale';
  
  Map<String, String> _strings = {};
  String _currentLocale = 'en';
  bool _initialized = false;

  String get currentLocale => _currentLocale;
  bool get isTamil => _currentLocale == 'ta';
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    _currentLocale = prefs.getString(_localeKey) ?? 'en';
    
    await _loadStrings(_currentLocale);
    _initialized = true;
  }

  Future<void> _loadStrings(String locale) async {
    try {
      final jsonString = await rootBundle.loadString('assets/l10n/$locale.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _strings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      // Fallback to English
      if (locale != 'en') {
        await _loadStrings('en');
      } else {
        _strings = {};
      }
    }
  }

  Future<void> setLocale(String locale) async {
    if (locale == _currentLocale) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale);
    _currentLocale = locale;
    await _loadStrings(locale);
  }

  String tr(String key, {Map<String, String>? params}) {
    String result = _strings[key] ?? key;
    
    if (params != null) {
      params.forEach((key, value) {
        result = result.replaceAll('{$key}', value);
      });
    }
    
    return result;
  }

  List<String> get supportedLocales => ['en', 'ta'];
}