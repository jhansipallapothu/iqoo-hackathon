import 'dart:async';
import 'dart:math';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/gps_service.dart';
import '../services/localization_service.dart';
import '../services/config_service.dart';
import '../services/browsing_service.dart';
import '../services/speech_config.dart';

enum VoiceCommandType {
  captureImage,
  describeScene,
  readText,
  identifyFood,
  analyzeDocument,
  getLocation,
  getDirections,
  searchWeb,
  readLastResponse,
  repeatLastResponse,
  switchMode,
  toggleFeature,
  openSettings,
  help,
  emergency,
  unknown,
}

class VoiceCommand {
  final VoiceCommandType type;
  final Map<String, dynamic> parameters;
  final String originalText;
  final double confidence;

  VoiceCommand({
    required this.type,
    required this.parameters,
    required this.originalText,
    required this.confidence,
  });
}

class VoiceAssistantService {
  static final VoiceAssistantService _instance = VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AIService _aiService = AIService();
  final GPSService _gpsService = GPSService();
  final LocalizationService _localization = LocalizationService();
  final ConfigService _configService = ConfigService();
  final BrowsingService _browsingService = BrowsingService();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSubscription;
  
  bool _isListening = false;
  bool _isWakeWordActive = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _accessibilityMode = false;
  String _wakeWord = 'hey assistant';
  double _shakeThreshold = 15.0;
  DateTime? _lastShakeTime;

  // Callbacks for UI updates
  Function(VoiceCommand)? onCommandRecognized;
  Function(String)? onTranscriptionUpdate;
  Function(bool)? onListeningStateChange;
  Function(String)? onStatusUpdate;
  Function(String)? onError;

  // Command patterns for different languages
  final Map<String, List<(RegExp, VoiceCommandType)>> _commandPatterns = {
    'en': [
      // Capture image
      (RegExp(r'(take|snap|capture|photo|picture|shoot).*(photo|picture|image)', caseSensitive: false), VoiceCommandType.captureImage),
      (RegExp(r'(what|describe).*(see|here|around|scene)', caseSensitive: false), VoiceCommandType.describeScene),
      
      // Text reading
      (RegExp(r'(read|scan|extract).*(text|words|writing)', caseSensitive: false), VoiceCommandType.readText),
      
      // Food
      (RegExp(r'(identify|what|recognize).*(food|meal|dish|eat)', caseSensitive: false), VoiceCommandType.identifyFood),
      (RegExp(r'(nutrition|calories|ingredients|allergens).*(food|meal)', caseSensitive: false), VoiceCommandType.identifyFood),
      
      // Document
      (RegExp(r'(analyze|read|scan|summarize).*(document|paper|letter|receipt|bill)', caseSensitive: false), VoiceCommandType.analyzeDocument),
      
      // Location
      (RegExp(r'(where|location|address|place).*(am i|here)', caseSensitive: false), VoiceCommandType.getLocation),
      (RegExp(r'(navigate|direction|route|go to).*(.*?)', caseSensitive: false), VoiceCommandType.getDirections),
      
      // Web search
      (RegExp(r'(search|look up|find|google).*(.*?)', caseSensitive: false), VoiceCommandType.searchWeb),
      (RegExp(r'(latest|current|news|weather|price).*(.*?)', caseSensitive: false), VoiceCommandType.searchWeb),
      
      // Response control
      (RegExp(r'(read|speak|say).*(last|previous|response|answer)', caseSensitive: false), VoiceCommandType.readLastResponse),
      (RegExp(r'(repeat|again).*(last|previous|response|answer)', caseSensitive: false), VoiceCommandType.repeatLastResponse),
      
      // Mode switching
      (RegExp(r'(switch|change|mode).*(explore|food|text|document)', caseSensitive: false), VoiceCommandType.switchMode),
      
      // Features
      (RegExp(r'(turn|toggle|enable|disable).*(gps|location|tts|speech|vibration|browsing|offline)', caseSensitive: false), VoiceCommandType.toggleFeature),
      
      // Settings
      (RegExp(r'(open|go to|show).*(setting|config|menu)', caseSensitive: false), VoiceCommandType.openSettings),
      
      // Help
      (RegExp(r'(help|what can you do|commands|how to use)', caseSensitive: false), VoiceCommandType.help),
      
      // Emergency
      (RegExp(r'(emergency|help me|sos|danger|urgent)', caseSensitive: false), VoiceCommandType.emergency),
    ],
    'ta': [
      // Capture image - Tamil
      (RegExp(r'(எடுத்து|பிடி|புகைப்படம்|திரைப்படம்)', caseSensitive: false), VoiceCommandType.captureImage),
      (RegExp(r'(என்ன|விவரி).*(இங்கு|சுற்று|தொடர்)', caseSensitive: false), VoiceCommandType.describeScene),
      
      // Text reading
      (RegExp(r'(வாசி|ச캔|எடுத்து).*(எழுத்து|சொற்கள்|எழுதிய)', caseSensitive: false), VoiceCommandType.readText),
      
      // Food
      (RegExp(r'(அடையாளம்|என்ன|அறிதல்).*(உணவு|சாப்பாடு|பளவு)', caseSensitive: false), VoiceCommandType.identifyFood),
      (RegExp(r'(நீர்ப்பு|கலாரி|கறைகள்|ஆலர்ஜி).*(உணவு|சாப்பாடு)', caseSensitive: false), VoiceCommandType.identifyFood),
      
      // Document
      (RegExp(r'(விவரி|வாசி|சக்கன்|சுருக்கம்).*(ஆவணம்|காகிதம்|கத்து|பில்)', caseSensitive: false), VoiceCommandType.analyzeDocument),
      
      // Location
      (RegExp(r'(எங்கே|இடம்|முகவர்|இடம்).*(நான்|இங்கு)', caseSensitive: false), VoiceCommandType.getLocation),
      (RegExp(r'(நாவிகேட்|திசை|मार்க்|செல்).*(.*?)', caseSensitive: false), VoiceCommandType.getDirections),
      
      // Web search
      (RegExp(r'(தேடு|பாரு|காண்|கூகிள்).*(.*?)', caseSensitive: false), VoiceCommandType.searchWeb),
      (RegExp(r'(அத்யதன்|தற்போதை|செய்தி|வானிலை|விலை).*(.*?)', caseSensitive: false), VoiceCommandType.searchWeb),
      
      // Response control
      (RegExp(r'(வாசி|பேசு|சொல்).*(கடைசி|முன்னடி|பதில்|உத்தரவு)', caseSensitive: false), VoiceCommandType.readLastResponse),
      (RegExp(r'(மறுபடியும்|அதே).*(கடைசி|முன்னடி|பதில்|உத்தரவு)', caseSensitive: false), VoiceCommandType.repeatLastResponse),
      
      // Mode switching
      (RegExp(r'(மாற்று|மேன்|மோடு).*(ஆராய்வு|உணவு|உரை|ஆவணம்)', caseSensitive: false), VoiceCommandType.switchMode),
      
      // Features
      (RegExp(r'(செய்|மேன்|இயக்கு|நிறுத்து).*(GPS|இடம்|TTS|பேச்சு|நடை|உலாவல்|ஆஃப்லைன்)', caseSensitive: false), VoiceCommandType.toggleFeature),
      
      // Settings
      (RegExp(r'(திற|செல்|காண்).*(அமைப்பு|நிலைமை|மெனு)', caseSensitive: false), VoiceCommandType.openSettings),
      
      // Help
      (RegExp(r'(உதவி|நீங்கள் என்ன செய்யலாம்|குறிப்புகள்|எப்படி பயன்படுத்த)', caseSensitive: false), VoiceCommandType.help),
      
      // Emergency
      (RegExp(r'(அவசர|உதவி|SOS|ஆபத்து|அவசரம்)', caseSensitive: false), VoiceCommandType.emergency),
    ],
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _configService.initialize();
    await _localization.initialize();
    await _aiService.initialize();

    await _setupTTS();
    await _requestPermissions();

    // Speech recognition. debugLogging surfaces why it fails on odd OEM builds.
    bool available = false;
    try {
      available = await _speech.initialize(
        onError: (error) => _handleError('Speech recognition error: $error'),
        onStatus: (status) => _handleStatus(status),
        debugLogging: true,
      );
    } catch (e) {
      _handleError('Speech init threw: $e');
    }

    if (!available) {
      _handleError('Speech recognition not available on this device');
      // TTS + shake still work — mark initialised so those aren't blocked.
      _setupShakeDetection();
      _isInitialized = true;
      return;
    }

    _setupShakeDetection();
    _isInitialized = true;
    _announce('Voice assistant ready. Say "$_wakeWord" to activate.');
  }

  Future<void> _setupTTS() async {
    await SpeechConfig.apply(_tts);
    // Small pause before speaking (milliseconds)
    await _tts.setSilence(50);
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  void _setupShakeDetection() {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude > _shakeThreshold) {
        final now = DateTime.now();
        if (_lastShakeTime == null || now.difference(_lastShakeTime!).inSeconds > 2) {
          _lastShakeTime = now;
          _onShakeDetected();
        }
      }
    });
  }

  void _toggleWakeWordListening() {
    if (_isWakeWordActive) {
      stopWakeWordListening();
    } else {
      startWakeWordListening();
    }
  }

  void _onShakeDetected() {
    if (_accessibilityMode) {
      _toggleWakeWordListening();
      _announce('Wake word listening ' + (_isWakeWordActive ? 'activated' : 'deactivated'));
    }
  }

  void _handleError(String error) {
    onError?.call(error);
    _announce('Error: $error');
  }

  void _handleStatus(String status) {
    if (status == 'listening') {
      _isListening = true;
      onListeningStateChange?.call(true);
      _announce('Listening...', interrupt: false);
    } else if (status == 'notListening') {
      _isListening = false;
      onListeningStateChange?.call(false);
    }
  }

  Future<void> startWakeWordListening() async {
    if (!_isInitialized || _isWakeWordActive) return;
    
    _isWakeWordActive = true;
    _listenForWakeWord();
  }

  Future<void> stopWakeWordListening() async {
    _isWakeWordActive = false;
    await _speech.stop();
  }

  Future<void> _listenForWakeWord() async {
    if (!_isWakeWordActive) return;

    // No localeId => use the device's default recogniser locale. A missing
    // locale (e.g. en-IN not installed) makes listen() fail silently.
    await _speech.listen(
      onResult: (result) {
        onTranscriptionUpdate?.call(result.recognizedWords);
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _processWakeWordResult(result.recognizedWords);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
      ),
    );
  }

  void _processWakeWordResult(String text) {
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains(_wakeWord.toLowerCase())) {
      _onWakeWordDetected(text);
    } else if (_isListening) {
      // Already in command mode, process as command
      _processCommand(text);
    }
  }

  void _onWakeWordDetected(String text) {
    _announce('Yes? How can I help?', interrupt: true);
    _startCommandListening();
  }

  Future<void> _startCommandListening() async {
    await _speech.listen(
      onResult: (result) {
        onTranscriptionUpdate?.call(result.recognizedWords);
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _processCommand(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
    );
  }

  void _processCommand(String text) {
    if (_isProcessing) return;
    _isProcessing = true;

    final command = _parseCommand(text);
    onCommandRecognized?.call(command);
    
    _executeCommand(command).then((_) {
      _isProcessing = false;
      if (_isWakeWordActive) {
        _listenForWakeWord(); // Return to wake word listening
      }
    }).catchError((e) {
      _isProcessing = false;
      _handleError('Command execution failed: $e');
      if (_isWakeWordActive) {
        _listenForWakeWord();
      }
    });
  }

  VoiceCommand _parseCommand(String text) {
    final patterns = _commandPatterns[_localization.currentLocale] ?? _commandPatterns['en']!;
    
    for (final entry in patterns) {
      final match = entry.$1.firstMatch(text);
      if (match != null) {
        final params = _extractParameters(text, entry.$2);
        return VoiceCommand(
          type: entry.$2,
          parameters: params,
          originalText: text,
          confidence: 0.9,
        );
      }
    }

    // Fallback: send to AI for interpretation
    return VoiceCommand(
      type: VoiceCommandType.unknown,
      parameters: {'raw_text': text},
      originalText: text,
      confidence: 0.3,
    );
  }

  Map<String, dynamic> _extractParameters(String text, VoiceCommandType type) {
    final params = <String, dynamic>{};
    final lowerText = text.toLowerCase();

    switch (type) {
      case VoiceCommandType.switchMode:
        if (lowerText.contains('explore') || lowerText.contains('ஆராய்வு')) params['mode'] = 0;
        else if (lowerText.contains('food') || lowerText.contains('உணவு')) params['mode'] = 1;
        else if (lowerText.contains('text') || lowerText.contains('உரை')) params['mode'] = 2;
        else if (lowerText.contains('document') || lowerText.contains('ஆவணம்')) params['mode'] = 3;
        break;
      case VoiceCommandType.toggleFeature:
        if (lowerText.contains('gps') || lowerText.contains('location') || lowerText.contains('இடம்')) params['feature'] = 'gps_enabled';
        else if (lowerText.contains('tts') || lowerText.contains('speech') || lowerText.contains('பேச்சு')) params['feature'] = 'tts_enabled';
        else if (lowerText.contains('vibration') || lowerText.contains('நடை')) params['feature'] = 'vibration_feedback';
        else if (lowerText.contains('browsing') || lowerText.contains('web') || lowerText.contains('உலாவல்')) params['feature'] = 'web_browsing';
        else if (lowerText.contains('offline') || lowerText.contains('ஆஃப்லைன்')) params['feature'] = 'offline_mode';
        params['enable'] = lowerText.contains('enable') || lowerText.contains('turn on') || lowerText.contains('இயக்கு') || lowerText.contains('on');
        break;
      case VoiceCommandType.searchWeb:
        params['query'] = text.replaceAll(RegExp(r'(search|look up|find|google|தேடு|பாரு|காண்|கூகிள்)\s*', caseSensitive: false), '');
        break;
      case VoiceCommandType.getDirections:
        params['destination'] = text.replaceAll(RegExp(r'(navigate|direction|route|go to|நாவிகேட்|திசை|செல்)\s*', caseSensitive: false), '');
        break;
      default:
        break;
    }

    return params;
  }

  Future<void> _executeCommand(VoiceCommand command) async {
    try {
      switch (command.type) {
        case VoiceCommandType.captureImage:
        case VoiceCommandType.describeScene:
          await _executeCaptureCommand(command.type == VoiceCommandType.describeScene);
          break;
        case VoiceCommandType.readText:
          await _executeCaptureCommand(false, mode: 2); // Text mode
          break;
        case VoiceCommandType.identifyFood:
          await _executeCaptureCommand(false, mode: 1); // Food mode
          break;
        case VoiceCommandType.analyzeDocument:
          await _executeCaptureCommand(false, mode: 3); // Document mode
          break;
        case VoiceCommandType.getLocation:
          await _announceLocation();
          break;
        case VoiceCommandType.getDirections:
          await _announceDirections(command.parameters['destination'] as String?);
          break;
        case VoiceCommandType.searchWeb:
          await _executeWebSearch(command.parameters['query'] as String? ?? command.originalText);
          break;
        case VoiceCommandType.readLastResponse:
        case VoiceCommandType.repeatLastResponse:
          await _repeatLastResponse();
          break;
        case VoiceCommandType.switchMode:
          _switchMode(command.parameters['mode'] as int?);
          break;
        case VoiceCommandType.toggleFeature:
          _toggleFeature(command.parameters['feature'] as String?, command.parameters['enable'] as bool?);
          break;
        case VoiceCommandType.openSettings:
          onStatusUpdate?.call('open_settings');
          _announce('Opening settings');
          break;
        case VoiceCommandType.help:
          _announceHelp();
          break;
        case VoiceCommandType.emergency:
          await _triggerEmergency();
          break;
        case VoiceCommandType.unknown:
          await _handleUnknownCommand(command.originalText);
          break;
      }
    } catch (e) {
      _handleError('Command failed: $e');
    }
  }

  Future<void> _executeCaptureCommand(bool describeScene, {int mode = 0}) async {
    _announce(describeScene ? 'Describing scene...' : 'Capturing image...');
    onStatusUpdate?.call('capture_image:$mode');
  }

  Future<void> _announceLocation() async {
    final position = _gpsService.getLastKnownPosition();
    final address = _gpsService.getLastKnownAddress();
    
    if (position == null) {
      _announce('Location not available. Please enable GPS.');
      return;
    }

    final accuracy = position.accuracy;
    String accuracyDesc;
    if (accuracy <= 10) accuracyDesc = 'high accuracy';
    else if (accuracy <= 50) accuracyDesc = 'medium accuracy';
    else accuracyDesc = 'low accuracy';

    final message = _localization.isTamil
        ? 'நீங்கள் $address இல் உள்ளீர்கள். GPS துல்லியம்: ${accuracy.toStringAsFixed(1)} மீட்டர் ($accuracyDesc).'
        : 'You are at $address. GPS accuracy: ${accuracy.toStringAsFixed(1)} meters ($accuracyDesc).';
    
    _announce(message);
  }

  Future<void> _announceDirections(String? destination) async {
    if (destination == null || destination.isEmpty) {
      _announce('Where would you like to go? Please specify a destination.');
      return;
    }
    
    _announce('Getting directions to $destination...');
    onStatusUpdate?.call('directions:$destination');
  }

  Future<void> _executeWebSearch(String query) async {
    _announce('Searching the web for $query...');
    onStatusUpdate?.call('web_search:$query');
  }

  Future<void> _repeatLastResponse() async {
    onStatusUpdate?.call('repeat_response');
    _announce('Repeating last response');
  }

  void _switchMode(int? mode) {
    if (mode != null && mode >= 0 && mode <= 3) {
      const modeNames = ['Explore', 'Food Labels', 'Text', 'Documents'];
      const modeNamesTa = ['ஆராய்வு', 'உணவு லேபிள்கள்', 'உரை', 'ஆவணங்கள்'];
      final name = _localization.isTamil ? modeNamesTa[mode] : modeNames[mode];
      _announce('Switching to $name mode');
      onStatusUpdate?.call('switch_mode:$mode');
    }
  }

  void _toggleFeature(String? feature, bool? enable) {
    if (feature == null) return;
    final shouldEnable = enable ?? true;
    
    const featureNames = {
      'gps_enabled': 'GPS',
      'tts_enabled': 'Text to Speech',
      'vibration_feedback': 'Vibration',
      'web_browsing': 'Web Browsing',
      'offline_mode': 'Offline Mode',
    };
    
    const featureNamesTa = {
      'gps_enabled': 'GPS',
      'tts_enabled': 'எழுத்து-பேச்சு',
      'vibration_feedback': 'நடை',
      'web_browsing': 'வலை உலாவல்',
      'offline_mode': 'ஆஃப்லைன் பதிவு',
    };
    
    final name = _localization.isTamil ? (featureNamesTa[feature] ?? feature) : (featureNames[feature] ?? feature);
    final action = shouldEnable ? (_localization.isTamil ? 'இயக்கப்பட்டது' : 'enabled') : (_localization.isTamil ? 'நிறுத்தப்பட்டது' : 'disabled');
    
    _configService.updateFeature(feature, shouldEnable);
    _announce('$name $action');
  }

  void _announceHelp() {
    final helpText = _localization.isTamil
        ? '''உதவி: "ஹேי 어시스턴트" என்று சொல்லுங்கள், பின்னர்:
        - "புகைப்படம் எடு" அல்லது "சூழலை விவரி"
        - "எழுத்து வாசி" அல்லது "உணவு அடையாளம்" 
        - "ஆவணம் பகுப்பாய்வு" அல்லது "எங்கே இருக்கிறேன்"
        - "தேடு [விஷயம்]" அல்லது "திசை [இடம்]"
        - "கடைசி பதில் வாசி" அல்லது "மோடு மாற்று"
        - "GPS இயக்கு" அல்லது "ஆஃப்லைன் চালு"
        - "அவசரம்".Threading'''
        : '''Help: Say "Hey Assistant" then:
        - "Take photo" or "Describe scene"
        - "Read text" or "Identify food"
        - "Analyze document" or "Where am I"
        - "Search [topic]" or "Navigate to [place]"
        - "Read last response" or "Switch mode"
        - "Enable GPS" or "Turn on offline mode"
        - "Emergency" for SOS''';
    
    _announce(helpText);
  }

  Future<void> _triggerEmergency() async {
    _announce('Emergency mode activated. Contacting emergency services...', interrupt: true);
    HapticFeedback.heavyImpact();
    onStatusUpdate?.call('emergency');
  }

  Future<void> _handleUnknownCommand(String text) async {
    // Send to AI for general response
    _announce('Let me help with that...');
    onStatusUpdate?.call('ai_query:$text');
  }

  // ponytail: public wrapper so other screens can trigger TTS announcements
  void announce(String text, {bool interrupt = true}) =>
      _announce(text, interrupt: interrupt);

  void _announce(String text, {bool interrupt = true}) {
    if (interrupt) {
      _tts.stop();
    }
    _tts.speak(text);
    if (_configService.appConfig.features.vibrationFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  // Public API for UI
  Future<void> startListening() async {
    if (!_isInitialized) await initialize();
    await startWakeWordListening();
  }

  Future<void> stopListening() async {
    await stopWakeWordListening();
  }

  void setAccessibilityMode(bool enabled) {
    _accessibilityMode = enabled;
    _configService.updateFeature('accessibility_mode', enabled);
  }

  void setWakeWord(String word) {
    _wakeWord = word.toLowerCase();
  }

  void setShakeThreshold(double threshold) {
    _shakeThreshold = threshold;
  }

  bool get isListening => _isListening;
  bool get isWakeWordActive => _isWakeWordActive;
  bool get isProcessing => _isProcessing;
  bool get accessibilityMode => _accessibilityMode;

  void dispose() {
    _speech.stop();
    _speech.cancel();
    _tts.stop();
    _accelerometerSubscription?.cancel();
    _userAccelerometerSubscription?.cancel();
    _browsingService.dispose();
    _isInitialized = false;
  }
}