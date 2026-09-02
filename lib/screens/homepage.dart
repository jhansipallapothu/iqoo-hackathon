import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/gps_service.dart';
import '../services/config_service.dart';
import '../services/localization_service.dart';
import '../services/ai_service.dart';
import '../services/offline_cache_service.dart';
import '../services/voice_assistant_service.dart';
import '../services/sms_service.dart';
import '../services/hardware_keys.dart';
import '../services/speech_config.dart';
import '../widgets/debug_overlay.dart';
import 'chatscreen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final CameraDescription? camera;

  const HomeScreen({super.key, required this.camera});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  int _selectedIndex = 0;
  bool _showCameraError = false;
  
  final GPSService _gpsService = GPSService();
  final ConfigService _configService = ConfigService();
  final LocalizationService _localization = LocalizationService();
  final AIService _aiService = AIService();
  final OfflineCacheService _cacheService = OfflineCacheService();
  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();
  final Connectivity _connectivity = Connectivity();
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<String>? _keySub;

  Position? _currentPosition;
  String? _currentAddress;
  bool _isGPSEnabled = false;
  StreamSubscription<Position>? _positionSubscription;
  ConnectivityResult _connectivityResult = ConnectivityResult.none;
  bool _initialized = false;
  bool _isProcessing = false;
  bool _voiceAssistantActive = false;
  String _voiceStatus = '';
  String _lastTranscription = '';

  // Accessibility
  bool _highContrast = false;
  bool _largeText = false;
  double _textScaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keySub = HardwareKeys.stream.listen((k) {
      // Only the visible screen reacts (chat screen sits on top of this one).
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      if (k == 'volume_up') {
        if (!_isProcessing) _takePicture();
      } else if (k == 'volume_down') {
        _repeatSpoken();
      }
    });
    _initializeAll();
  }

  void _repeatSpoken() {
    final text = SpokenText.last;
    if (text == null || text.isEmpty) {
      _announceReady();
    } else {
      _tts.stop();
      _tts.speak(text);
    }
  }

  Future<void> _initializeAll() async {
    // Camera is the only thing the user is actually waiting to see, so start it
    // first and don't await it — the rest runs alongside instead of behind it.
    if (widget.camera != null) {
      _initializeCamera();
    } else if (mounted) {
      setState(() {
        _showCameraError = true;
        _initialized = true;
      });
    }

    // Config + localization gate the first frame. Run them together.
    await Future.wait([
      _configService.initialize(),
      _localization.initialize(),
    ]);
    if (mounted) setState(() {});

    // Everything below is off the critical path — kick it all off concurrently
    // and let each finish whenever. None of it blocks a frame.
    _listenConnectivity();
    _initializeGPS();
    _setupVoiceAssistantCallbacks(); // wire onError BEFORE init so failures surface

    unawaited(_cacheService
        .initialize()
        .then((_) => _loadAccessibilitySettings())
        .catchError((e) => debugPrint('Cache init failed: $e')));
    unawaited(_aiService
        .initialize()
        .catchError((e) => debugPrint('AI init failed: $e')));
    unawaited(SmsService()
        .initialize()
        .catchError((e) => debugPrint('SMS init failed: $e')));
    unawaited(_voiceAssistant
        .initialize()
        .catchError((e) => debugPrint('Voice assistant init failed: $e')));
  }

  void _setupVoiceAssistantCallbacks() {
    _voiceAssistant.onCommandRecognized = _onVoiceCommand;
    _voiceAssistant.onTranscriptionUpdate = (text) {
      if (mounted) setState(() => _lastTranscription = text);
    };
    _voiceAssistant.onListeningStateChange = (listening) {
      if (mounted) setState(() => _voiceStatus = listening ? 'Listening...' : 'Wake word active');
    };
    _voiceAssistant.onStatusUpdate = (status) {
      _handleVoiceStatus(status);
    };
    _voiceAssistant.onError = (error) {
      _showSnackBar('Voice Error: $error');
    };
  }

  void _handleVoiceStatus(String status) {
    if (status.startsWith('capture_image:')) {
      final mode = int.tryParse(status.split(':')[1]) ?? 0;
      _captureImageByVoice(mode);
    } else if (status.startsWith('switch_mode:')) {
      final mode = int.tryParse(status.split(':')[1]) ?? 0;
      setState(() => _selectedIndex = mode);
      _announceModeChange(mode);
    } else if (status.startsWith('directions:')) {
      final dest = status.split(':')[1];
      _showSnackBar('Navigation to $dest not yet implemented');
    } else if (status.startsWith('web_search:')) {
      final query = status.split(':')[1];
      _showSnackBar('Web search: $query');
    } else if (status == 'repeat_response') {
      _showSnackBar('Repeating last response');
    } else if (status == 'open_settings') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    } else if (status == 'emergency') {
      _triggerEmergencySOS();
    } else if (status.startsWith('ai_query:')) {
      final query = status.split(':')[1];
      _sendAIQuery(query);
    }
  }

  Future<void> _captureImageByVoice(int mode) async {
    if (!(_isCameraInitialized && _cameraController != null && _cameraController!.value.isInitialized)) {
      _voiceAssistant.announce('Camera not ready');
      return;
    }
    
    setState(() => _selectedIndex = mode);
    await _takePicture();
  }

  void _announceModeChange(int mode) {
    const modeNames = ['Explore', 'Food Labels', 'Text', 'Documents'];
    const modeNamesTa = ['ஆராய்வு', 'உணவு லேபிள்கள்', 'உரை', 'ஆவணங்கள்'];
    final name = _localization.isTamil ? modeNamesTa[mode] : modeNames[mode];
    _voiceAssistant.announce('Switched to $name mode');
  }

  Future<void> _sendAIQuery(String query) async {
    // Navigate to chat screen with text query
    _showSnackBar('AI Query: $query');
  }

  Future<void> _triggerEmergencySOS() async {
    _voiceAssistant.announce('Emergency SOS activated. Vibrating and announcing location.');
    HapticFeedback.heavyImpact();
    await _announceLocationByVoice();
    _showSnackBar('EMERGENCY SOS TRIGGERED');
  }

  Future<void> _announceLocationByVoice() async {
    final position = _gpsService.getLastKnownPosition();
    final address = _gpsService.getLastKnownAddress();
    
    if (position == null) {
      _voiceAssistant.announce('Location not available');
      return;
    }

    final message = _localization.isTamil
        ? 'அவசரம்! நீங்கள் $address இல் உள்ளீர்கள். அகசதுவரம்: ${position.latitude.toStringAsFixed(6)}, நெடுசதுவரம்: ${position.longitude.toStringAsFixed(6)}.'
        : 'Emergency! You are at $address. Latitude: ${position.latitude.toStringAsFixed(6)}, Longitude: ${position.longitude.toStringAsFixed(6)}.';
    
    _voiceAssistant.announce(message, interrupt: true);
  }

  void _loadAccessibilitySettings() async {
    final highContrast = await _cacheService.getBool('high_contrast');
    final largeText = await _cacheService.getBool('large_text');
    if (mounted) {
      setState(() {
        _highContrast = highContrast;
        _largeText = largeText;
        _textScaleFactor = largeText ? 1.5 : 1.0;
      });
    }
  }

  void _saveAccessibilitySetting(String key, bool value) async {
    await _cacheService.setBool(key, value);
  }

  Future<void> _announceReady() async {
    if (!_configService.appConfig.features.ttsEnabled) return;
    try {
      await SpeechConfig.apply(_tts, tamil: _localization.isTamil);
      final msg = _localization.isTamil
          ? 'AI அனைவருக்கும் தயார். படம் எடுக்க எங்கும் தட்டவும்.'
          : 'A I For All ready. Tap anywhere to take a photo. '
              'Swipe left or right to change mode.';
      SpokenText.last = msg;
      await _tts.speak(msg);
    } catch (_) {}
  }

  void _listenConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      if (mounted) setState(() => _connectivityResult = result);
    });
    _connectivity.checkConnectivity().then((r) {
      if (mounted) setState(() => _connectivityResult = r);
    });
  }

  Future<void> _initializeGPS() async {
    if (!_configService.appConfig.features.gpsEnabled) return;
    
    final enabled = await Geolocator.isLocationServiceEnabled();
    setState(() => _isGPSEnabled = enabled);
    
    if (!enabled) return;

    final hasPermission = await _gpsService.requestPermission();
    if (!hasPermission) return;

    try {
      final position = await _gpsService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
          _currentAddress = _gpsService.getLastKnownAddress();
        });
      }

      _positionSubscription?.cancel();
      _positionSubscription = _gpsService.getPositionStream().listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _currentAddress = _gpsService.getLastKnownAddress();
          });
        }
      });
    } catch (e) {
      print('GPS init error: $e');
    }
  }

  Future<void> _initializeCamera() async {
    if (widget.camera == null) return;

    // medium is plenty for a VLM prompt and initialises noticeably faster than
    // high; audio off since we never record video.
    _cameraController = CameraController(
      widget.camera!,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _showCameraError = false;
          _initialized = true;
        });
        _announceReady();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showCameraError = true;
          _initialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _positionSubscription?.cancel();
    _gpsService.dispose();
    _voiceAssistant.dispose();
    _keySub?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _suspendPreview();
      if (_voiceAssistantActive) _voiceAssistant.stopListening();
    } else if (state == AppLifecycleState.resumed) {
      // Only resume if we're the visible route — otherwise the chat screen is
      // still on top and the preview should stay suspended.
      if (ModalRoute.of(context)?.isCurrent ?? true) _resumePreview();
      if (_voiceAssistantActive) _voiceAssistant.startListening();
    }
  }

  void _onItemTapped(int index) {
    if (_configService.appConfig.features.vibrationFeedback) HapticFeedback.lightImpact();
    _voiceAssistant.announce(_getModeName(index));
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getModeName(int index) {
    return _localization.isTamil 
        ? ['ஆராய்வு', 'உணவு லேபிள்கள்', 'உரை', 'ஆவணங்கள்'][index]
        : ['Explore', 'Food Labels', 'Text', 'Documents'][index];
  }

  Future<void> _takePicture() async {
    if (_isProcessing) return;
    
    if (!(_isCameraInitialized && _cameraController != null && _cameraController!.value.isInitialized)) {
      _showSnackBar(_localization.tr('camera_not_initialized'));
      return;
    }

    setState(() => _isProcessing = true);
    
    try {
      final XFile file = await _cameraController!.takePicture();
      final String prompt = _buildPrompt();
      Map<String, dynamic>? locationData;
      
      if (_currentPosition != null && _configService.appConfig.features.gpsEnabled) {
        locationData = await _gpsService.getLocationData();
      }

      if (mounted) {
        // Always-alive camera: suspend the preview stream while the chat screen
        // is on top (frees CPU during inference) but never close the session —
        // reopening costs 1-2s, resuming is instant.
        _suspendPreview();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Chatscreen(
              imagePath: file.path,
              prompt: prompt,
              locationData: locationData,
            ),
          ),
        ).then((_) {
          _resumePreview();
          _voiceAssistant.announce('Analysis complete');
        });
      }
    } catch (e) {
      _showSnackBar('${_localization.tr('error_occurred')}: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  bool _previewSuspended = false;

  void _suspendPreview() {
    final c = _cameraController;
    if (c == null || !c.value.isInitialized || _previewSuspended) return;
    _previewSuspended = true;
    c.pausePreview();
  }

  void _resumePreview() {
    final c = _cameraController;
    if (c == null || !c.value.isInitialized || !_previewSuspended) return;
    _previewSuspended = false;
    c.resumePreview();
  }

  String _buildPrompt() {
    final isTamil = _localization.isTamil;
    final modeKeys = ['explore', 'food', 'text', 'document'];
    final mode = modeKeys[_selectedIndex.clamp(0, 3)];
    
    String prompt = _configService.getPrompt(mode, isTamil: isTamil);
    
    if (_currentPosition != null) {
      final locationContext = _configService.getLocationContext(
        isTamil: isTamil,
        address: _currentAddress ?? 'Unknown',
        lat: _currentPosition!.latitude,
        lon: _currentPosition!.longitude,
        accuracy: _currentPosition!.accuracy,
      );
      prompt = '$prompt. $locationContext';
    }
    
    return prompt;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey[900],
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Voice Assistant Controls
  Future<void> _toggleVoiceAssistant() async {
    setState(() {
      _voiceAssistantActive = !_voiceAssistantActive;
    });
    
    if (_voiceAssistantActive) {
      await _voiceAssistant.startListening();
      _voiceAssistant.announce('Voice assistant activated. Say "Hey Assistant" to begin.');
    } else {
      await _voiceAssistant.stopListening();
      _voiceAssistant.announce('Voice assistant deactivated');
    }
  }

  void _onVoiceCommand(VoiceCommand command) {
    _showSnackBar('Command: ${command.type.name} (${(command.confidence * 100).toInt()}%)');
  }

  @override
  Widget build(BuildContext context) {
    // _initializeAll() is async; the AppBar/body read _configService.appConfig,
    // which throws until configs are loaded. Hold a loader until then.
    if (!_configService.initialized || !_localization.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isTamil = _localization.isTamil;
    final isOnline = _connectivityResult != ConnectivityResult.none;
    final textScale = _textScaleFactor;

    return DebugOverlay(
      enabled: true,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          boldText: _highContrast,
          highContrast: _highContrast,
        ),
        child: Semantics(
          label: isTamil ? 'AI அனைவர்க்கும் मुख் ஸ்க்ரீன்' : 'AI For ALL Main Screen',
          child: Scaffold(
            appBar: _buildAppBar(isTamil, isOnline),
            body: _buildBody(isTamil, isOnline),
            bottomNavigationBar: _buildBottomNavBar(isTamil),
            floatingActionButton: _buildFAB(isTamil),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isTamil, bool isOnline) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _localization.tr('welcome'),
              style: TextStyle(
                color: Colors.blueAccent, 
                fontSize: 18 * _textScaleFactor,
                fontWeight: _highContrast ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (_currentAddress != null)
              Text(
                _currentAddress!,
                style: TextStyle(
                  color: Colors.white70, 
                  fontSize: 11 * _textScaleFactor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (_voiceAssistantActive)
              Text(
                _voiceStatus.isNotEmpty ? _voiceStatus : (_lastTranscription.isNotEmpty ? '"$_lastTranscription"' : 'Voice Active'),
                style: TextStyle(
                  color: Colors.greenAccent, 
                  fontSize: 10 * _textScaleFactor,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      backgroundColor: _highContrast ? Colors.black : Colors.black,
      actions: [
        _buildVoiceAssistantButton(isTamil),
        _buildGPSIndicator(),
        _buildNetworkIndicator(isOnline),
        _buildAccessibilityButton(isTamil),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.blue),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          tooltip: _localization.tr('settings'),
        ),
      ],
    );
  }

  Widget _buildVoiceAssistantButton(bool isTamil) {
    return Semantics(
      button: true,
      label: _voiceAssistantActive ? (isTamil ? 'தொல்காப்பியний நிறுத்து' : 'Stop Voice Assistant') : (isTamil ? 'தொல்காப்பியன் துவக்கு' : 'Start Voice Assistant'),
      hint: isTamil ? 'அனைத்து காட்சிகளுக்கும் குரல் கட்டளைகளை இயக்கவும்' : 'Enable voice commands for all screens',
      child: IconButton(
        icon: Icon(
          _voiceAssistantActive ? Icons.mic : Icons.mic_none,
          color: _voiceAssistantActive ? Colors.greenAccent : Colors.blue,
          size: 28,
        ),
        onPressed: _toggleVoiceAssistant,
        tooltip: _voiceAssistantActive ? 'Stop Voice Assistant' : 'Start Voice Assistant',
      ),
    );
  }

  Widget _buildAccessibilityButton(bool isTamil) {
    return Semantics(
      button: true,
      label: isTamil ? 'அணுகல் அமைப்புகள்' : 'Accessibility Settings',
      child: PopupMenuButton<String>(
        icon: Icon(Icons.accessibility_new, color: _highContrast || _largeText ? Colors.amber : Colors.grey),
        tooltip: 'Accessibility Options',
        onSelected: (value) {
          setState(() {
            switch (value) {
              case 'high_contrast':
                _highContrast = !_highContrast;
                _saveAccessibilitySetting('high_contrast', _highContrast);
                break;
              case 'large_text':
                _largeText = !_largeText;
                _textScaleFactor = _largeText ? 1.5 : 1.0;
                _saveAccessibilitySetting('large_text', _largeText);
                break;
              case 'voice_assistant':
                _toggleVoiceAssistant();
                break;
            }
          });
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'high_contrast',
            child: Row(
              children: [
                Icon(_highContrast ? Icons.check_box : Icons.check_box_outline_blank, color: _highContrast ? Colors.green : null),
                const SizedBox(width: 8),
                Text(isTamil ? 'உயர் துவிர்ச்சி' : 'High Contrast'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'large_text',
            child: Row(
              children: [
                Icon(_largeText ? Icons.check_box : Icons.check_box_outline_blank, color: _largeText ? Colors.green : null),
                const SizedBox(width: 8),
                Text(isTamil ? 'மேல் வலியான உரை' : 'Large Text'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'voice_assistant',
            child: Row(
              children: [
                Icon(_voiceAssistantActive ? Icons.mic : Icons.mic_none, color: _voiceAssistantActive ? Colors.green : null),
                const SizedBox(width: 8),
                Text(isTamil ? 'குரல் உதவியாளர்' : 'Voice Assistant'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkIndicator(bool isOnline) {
    return Semantics(
      label: isOnline ? 'Online' : 'Offline',
      child: IconButton(
        icon: Icon(
          isOnline ? Icons.wifi : Icons.wifi_off,
          color: isOnline ? Colors.green : Colors.red,
        ),
        onPressed: null,
        tooltip: isOnline ? _localization.tr('online_mode') : _localization.tr('offline_mode'),
      ),
    );
  }

  Widget _buildGPSIndicator() {
    if (!_configService.appConfig.features.gpsEnabled) {
      return Semantics(
        label: 'GPS Disabled',
        child: IconButton(
          icon: const Icon(Icons.gps_off, color: Colors.grey),
          onPressed: null,
          tooltip: _localization.tr('gps_disabled'),
        ),
      );
    }

    Color indicatorColor;
    IconData icon;
    String tooltip;

    if (!_isGPSEnabled) {
      indicatorColor = Colors.red;
      icon = Icons.gps_off;
      tooltip = _localization.tr('gps_disabled');
    } else if (_currentPosition == null) {
      indicatorColor = Colors.orange;
      icon = Icons.gps_fixed;
      tooltip = _localization.tr('gps_acquiring');
    } else {
      final accuracy = _currentPosition!.accuracy;
      if (accuracy <= _configService.appConfig.gps.accuracyThresholdHigh) {
        indicatorColor = Colors.green;
        icon = Icons.gps_fixed;
        tooltip = '${_localization.tr('high_accuracy')}: ${accuracy.toStringAsFixed(1)}m';
      } else if (accuracy <= _configService.appConfig.gps.accuracyThresholdMedium) {
        indicatorColor = Colors.yellow;
        icon = Icons.gps_fixed;
        tooltip = '${_localization.tr('medium_accuracy')}: ${accuracy.toStringAsFixed(1)}m';
      } else {
        indicatorColor = Colors.orange;
        icon = Icons.gps_fixed;
        tooltip = '${_localization.tr('low_accuracy')}: ${accuracy.toStringAsFixed(1)}m';
      }
    }

    return Semantics(
      label: tooltip,
      button: true,
      hint: 'Double tap for GPS details',
      child: IconButton(
        icon: Icon(icon, color: indicatorColor),
        onPressed: _showGPSDetails,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildBody(bool isTamil, bool isOnline) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_showCameraError) {
      return _buildCameraErrorView(isTamil);
    }
    
    if (!_isCameraInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _localization.tr('initializing_camera'),
              style: TextStyle(fontSize: 16 * _textScaleFactor),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Blind users can't find the shutter button — the whole preview is it.
        // Double-tap is reserved for the debug overlay, so use single tap.
        Semantics(
          button: true,
          label: isTamil
              ? 'படம் எடுக்க எங்கும் தட்டவும்'
              : 'Tap anywhere to take a photo',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isProcessing ? null : _takePicture,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 200) return;
              final next = (_selectedIndex + (v < 0 ? 1 : -1)).clamp(0, 3);
              if (next != _selectedIndex) _onItemTapped(next);
            },
            child: SizedBox.expand(child: CameraPreview(_cameraController!)),
          ),
        ),
        _buildGPSOverlay(),
        if (!isOnline) _buildOfflineBanner(isTamil),
        if (_isProcessing) _buildProcessingOverlay(isTamil),
        _buildVoiceAssistantOverlay(isTamil),
      ],
    );
  }

  Widget _buildVoiceAssistantOverlay(bool isTamil) {
    if (!_voiceAssistantActive) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Semantics(
        liveRegion: true,
        label: isTamil ? 'குரல் உதவியாளர் செயலாகிறது' : 'Voice Assistant Active',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.greenAccent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.mic, color: Colors.greenAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _voiceStatus.isNotEmpty ? _voiceStatus : (isTamil ? 'குரல் உதவியாளர் செயலாகிறது...' : 'Voice Assistant Active...'),
                      style: TextStyle(
                        color: Colors.greenAccent, 
                        fontSize: 14 * _textScaleFactor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_lastTranscription.isNotEmpty)
                    Flexible(
                      child: Text(
                        '"$_lastTranscription"',
                        style: TextStyle(
                          color: Colors.white70, 
                          fontSize: 12 * _textScaleFactor,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildVoiceCommandHint('Take Photo', Icons.camera_alt),
                  _buildVoiceCommandHint('Read Text', Icons.text_fields),
                  _buildVoiceCommandHint('Identify Food', Icons.restaurant),
                  _buildVoiceCommandHint('Where Am I', Icons.location_on),
                  _buildVoiceCommandHint('Search Web', Icons.search),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceCommandHint(String label, IconData icon) {
    final isTamil = _localization.isTamil;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: isTamil 
            ? 'குரல் கட்டளை: "$label"'
            : 'Voice command: "$label"',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            Text(
              label,
              style: TextStyle(
                color: Colors.white54, 
                fontSize: 9 * _textScaleFactor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(bool isTamil) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Semantics(
        liveRegion: true,
        label: isTamil ? 'ஆஃப்லைன் பதிவு செயல்படுகிறது' : 'Offline Mode Active',
        child: Container(
          color: Colors.orange[800],
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                isTamil ? 'ஆஃப்லைன் பதிவு - சேமிக்கப்பட்ட பதில்கள் காட்டுகிறது' : 'Offline Mode - Showing cached responses',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay(bool isTamil) {
    return Semantics(
      liveRegion: true,
      label: isTamil ? 'செயலாக்குகிறது...' : 'Processing...',
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _localization.tr('processing'),
                style: TextStyle(color: Colors.white, fontSize: 16 * _textScaleFactor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGPSOverlay() {
    if (!_configService.appConfig.features.gpsEnabled || _currentPosition == null) {
      return const SizedBox.shrink();
    }
    
    final accuracy = _currentPosition!.accuracy;
    final color = accuracy <= 10 ? Colors.green : (accuracy <= 50 ? Colors.yellow : Colors.orange);
    
    return Positioned(
      top: 10,
      right: 10,
      child: Semantics(
        label: 'GPS Accuracy: ${accuracy.toStringAsFixed(1)} meters',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                '${accuracy.toStringAsFixed(1)}m',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGPSDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildGPSBottomSheet(),
    );
  }

  Widget _buildGPSBottomSheet() {
    final isTamil = _localization.isTamil;
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _localization.tr('gps_status'),
                style: TextStyle(color: Colors.white, fontSize: 20 * _textScaleFactor, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildGPSInfoRow(_localization.tr('status'), _isGPSEnabled ? _localization.tr('gps_enabled') : _localization.tr('gps_disabled')),
          _buildGPSInfoRow(_localization.tr('permission'), _currentPosition != null ? _localization.tr('granted') : _localization.tr('pending')),
          if (_currentPosition != null) ...[
            _buildGPSInfoRow(_localization.tr('latitude'), _currentPosition!.latitude.toStringAsFixed(6)),
            _buildGPSInfoRow(_localization.tr('longitude'), _currentPosition!.longitude.toStringAsFixed(6)),
            _buildGPSInfoRow(_localization.tr('altitude'), '${_currentPosition!.altitude.toStringAsFixed(1)} m'),
            _buildGPSInfoRow(_localization.tr('accuracy'), '${_currentPosition!.accuracy.toStringAsFixed(1)} m'),
            _buildGPSInfoRow(_localization.tr('speed'), '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h'),
            _buildGPSInfoRow(_localization.tr('heading'), '${_currentPosition!.heading.toStringAsFixed(0)}°'),
            _buildGPSInfoRow(_localization.tr('address'), _currentAddress ?? _localization.tr('resolving')),
            _buildGPSInfoRow(_localization.tr('last_update'), _currentPosition!.timestamp.toLocal().toString().split('.')[0]),
          ],
          const SizedBox(height: 20),
          if (!_isGPSEnabled)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: Text(_localization.tr('enable_gps')),
                onPressed: () async {
                  Navigator.pop(context);
                  await _gpsService.openLocationSettings();
                },
              ),
            ),
          if (_isGPSEnabled && _currentPosition == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(_localization.tr('retry_gps')),
                onPressed: () async {
                  Navigator.pop(context);
                  _initializeGPS();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGPSInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.white70, fontSize: 14 * _textScaleFactor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.white, fontSize: 14 * _textScaleFactor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraErrorView(bool isTamil) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _localization.tr('camera_not_available'),
            style: TextStyle(fontSize: 18 * _textScaleFactor, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (widget.camera != null) {
                _initializeCamera();
              }
            },
            child: Text(_localization.tr('retry_camera')),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(bool isTamil) {
    return Container(
      color: _highContrast ? Colors.black : Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _buildNavItem(Icons.explore, _localization.tr('explore'), 0),
            _buildNavItem(Icons.qr_code, _localization.tr('food_labels'), 1),
            _buildNavItem(Icons.text_fields, _localization.tr('text_mode'), 2),
            _buildNavItem(Icons.document_scanner, _localization.tr('documents'), 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      hint: _localization.isTamil ? '$label மோடு தேர்வு செய்ய டேப் செய்யவும்' : 'Tap to select $label mode',
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: isSelected ? 28 : 24,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 11 * _textScaleFactor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  height: 3,
                  width: 30,
                  color: Colors.blueAccent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(bool isTamil) {
    if (!_isCameraInitialized) return const SizedBox.shrink();
    
    final accuracy = _currentPosition?.accuracy ?? 999;
    final isHighAccuracy = accuracy <= 10;
    
    return Semantics(
      button: true,
      label: isTamil ? 'புகைப்படம் எடுக்க' : 'Take Picture',
      hint: isTamil ? 'கேமரா புகைப்படம் எடுக்க மைய பட்டனை டேப் செய்யவும்' : 'Tap center button to capture photo',
      child: FloatingActionButton(
        onPressed: _isProcessing ? null : _takePicture,
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Icon(Icons.camera, size: 28),
        backgroundColor: isHighAccuracy ? Colors.green : Colors.white,
        foregroundColor: Colors.black,
        elevation: 8,
        tooltip: isTamil ? 'புகைப்படம் எடுக்க' : 'Take Picture',
      ),
    );
  }
}