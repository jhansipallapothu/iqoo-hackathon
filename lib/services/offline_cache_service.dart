import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/config_service.dart';

class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  final ConfigService _configService = ConfigService();
  SharedPreferences? _prefs;
  Directory? _cacheDir;
  bool _initialized = false;

  bool get initialized => _initialized;

  // ponytail: thin passthrough so screens don't reach into private _prefs
  Future<bool> getBool(String key, {bool defaultValue = false}) async =>
      _prefs?.getBool(key) ?? defaultValue;

  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _configService.initialize();
    _prefs = await SharedPreferences.getInstance();
    _cacheDir = await getApplicationDocumentsDirectory();
    _initialized = true;
  }

  // Cache AI responses
  Future<void> cacheResponse({
    required String prompt,
    required String response,
    String? imageHash,
    Map<String, dynamic>? locationData,
  }) async {
    final key = _generateKey(prompt, imageHash);
    final data = {
      'prompt': prompt,
      'response': response,
      'imageHash': imageHash,
      'locationData': locationData,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await _prefs!.setString('cache_$key', json.encode(data));
    await _cleanupOldEntries();
  }

  Future<String?> getCachedResponse({
    required String prompt,
    String? imageHash,
  }) async {
    final key = _generateKey(prompt, imageHash);
    final jsonString = _prefs!.getString('cache_$key');
    
    if (jsonString == null) return null;
    
    final data = json.decode(jsonString);
    final timestamp = DateTime.parse(data['timestamp']);
    final maxAge = Duration(days: _configService.appConfig.cache.maxAgeDays);
    
    if (DateTime.now().difference(timestamp) > maxAge) {
      await _prefs!.remove('cache_$key');
      return null;
    }
    
    return data['response'] as String?;
  }

  String _generateKey(String prompt, String? imageHash) {
    final combined = prompt + (imageHash ?? '');
    return combined.hashCode.toString();
  }

  Future<void> _cleanupOldEntries() async {
    final keys = _prefs!.getKeys().where((k) => k.startsWith('cache_')).toList();
    
    if (keys.length > _configService.appConfig.cache.maxEntries) {
      // Remove oldest entries
      final entries = <MapEntry<String, String>>[];
      for (final key in keys) {
        final value = _prefs!.getString(key)!;
        final data = json.decode(value);
        final timestamp = DateTime.parse(data['timestamp']);
        entries.add(MapEntry(key, timestamp.toIso8601String()));
      }
      
      entries.sort((a, b) => a.value.compareTo(b.value));
      final toRemove = entries.take(keys.length - _configService.appConfig.cache.maxEntries);
      
      for (final entry in toRemove) {
        await _prefs!.remove(entry.key);
      }
    }
  }

  // Preload test images for demo
  Future<void> preloadTestImages() async {
    if (!_configService.appConfig.cache.preloadTestImages) return;
    // ponytail: asset-to-cache copy not needed yet; preloadedImages list is
    // read straight from config where used.
  }

  // Get cache stats for debug overlay
  Future<Map<String, dynamic>> getCacheStats() async {
    // The debug overlay calls this from initState, before homepage's un-awaited
    // initialize() has finished — _prefs! would throw and crash the first frame.
    if (!_initialized) await initialize();
    final keys = _prefs!.getKeys().where((k) => k.startsWith('cache_')).toList();
    int totalSize = 0;
    
    for (final key in keys) {
      final value = _prefs!.getString(key) ?? '';
      totalSize += value.length;
    }
    
    return {
      'entries': keys.length,
      'maxEntries': _configService.appConfig.cache.maxEntries,
      'sizeKB': (totalSize / 1024).toStringAsFixed(1),
    };
  }

  Future<void> clearCache() async {
    if (!_initialized) await initialize();
    final keys = _prefs!.getKeys().where((k) => k.startsWith('cache_')).toList();
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }
}