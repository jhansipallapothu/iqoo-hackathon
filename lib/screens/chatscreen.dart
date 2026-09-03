import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../services/ai_service.dart';
import '../services/localization_service.dart';
import '../services/offline_cache_service.dart';
import '../services/config_service.dart';
import '../services/hardware_keys.dart';
import '../services/speech_config.dart';

class Chatscreen extends StatefulWidget {
  final String? imagePath;
  final String? prompt;
  final Map<String, dynamic>? locationData;

  const Chatscreen({
    super.key, 
    this.imagePath, 
    this.prompt, 
    this.locationData,
  });

  @override
  State<Chatscreen> createState() => _ChatscreenState();
}

class _ChatscreenState extends State<Chatscreen> {
  final AIService _aiService = AIService();
  final LocalizationService _localization = LocalizationService();
  final OfflineCacheService _cacheService = OfflineCacheService();
  final ConfigService _configService = ConfigService();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  StreamSubscription<String>? _keySub;

  List<ChatMessage> messages = [];
  bool _isLoading = false;
  String? _lastAIResponse;
  String? _imageHash;

  // ChatGPT-style voice chat: speak, it transcribes + sends, reads the answer
  // aloud, then re-opens the mic for the next turn until you toggle it off.
  bool _sttReady = false;
  bool _voiceMode = false;
  bool _listening = false;

  ChatUser currentUser = ChatUser(id: "0", firstName: "User");
  ChatUser geminiUser = ChatUser(
    id: "1",
    firstName: "AI for all",
    profileImage: "assets/images/import.jpg",
  );

  @override
  void initState() {
    super.initState();
    // Either volume key re-speaks the last answer while this screen is open.
    _keySub = HardwareKeys.stream.listen((_) {
      if (ModalRoute.of(context)?.isCurrent ?? true) _speakLastResponse();
    });
    _initializeServices();
    if (widget.imagePath != null) {
      _computeImageHash(widget.imagePath!);
      _sendMediaMessage(widget.imagePath!);
    }
  }

  Future<void> _initializeServices() async {
    await _configService.initialize();
    await _localization.initialize();
    await _aiService.initialize();
    await _cacheService.initialize();
    await _setupTTS();
    await _setupStt();
  }

  Future<void> _setupStt() async {
    await Permission.microphone.request();
    try {
      _sttReady = await _stt.initialize(
        onStatus: (s) {
          // When a listen turn ends on its own (silence), reflect it.
          if (s == 'done' || s == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    } catch (_) {
      _sttReady = false;
    }
    if (mounted) setState(() {});
  }

  void _toggleVoiceMode() {
    if (!_sttReady) {
      _speak(_localization.isTamil
          ? 'இந்த சாதனத்தில் குரல் உள்ளீடு கிடைக்கவில்லை.'
          : 'Voice input is not available on this device.');
      return;
    }
    setState(() => _voiceMode = !_voiceMode);
    HapticFeedback.mediumImpact();
    if (_voiceMode) {
      _speak(_localization.isTamil ? 'குரல் அரட்டை இயக்கத்தில்.' : 'Voice chat on.');
      _listenOnce();
    } else {
      _stt.stop();
      _speak(_localization.isTamil ? 'குரல் அரட்டை நிறுத்தப்பட்டது.' : 'Voice chat off.');
    }
  }

  Future<void> _listenOnce() async {
    if (!_sttReady || !_voiceMode || _listening || _isLoading) return;
    await _tts.stop();
    setState(() => _listening = true);
    HapticFeedback.lightImpact();
    await _stt.listen(
      onResult: (r) {
        if (!r.finalResult) return;
        final text = r.recognizedWords.trim();
        setState(() => _listening = false);
        if (text.isEmpty) {
          _speak(_localization.isTamil ? 'கேட்கவில்லை.' : "Didn't catch that.");
          Future.delayed(const Duration(milliseconds: 1200), _listenOnce);
          return;
        }
        _sendMessage(ChatMessage(
          user: currentUser,
          createdAt: DateTime.now(),
          text: text,
        ));
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: false,
      ),
    );
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _setupTTS() async {
    await _tts.awaitSpeakCompletion(true);
    await SpeechConfig.apply(_tts, tamil: _localization.isTamil);
  }

  void _computeImageHash(String path) {
    _imageHash = path.hashCode.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = _localization.isTamil;
    
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_localization.tr('app_title')),
        actions: [
          if (widget.locationData != null && widget.locationData!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.location_on),
              onPressed: _showLocationDetails,
              tooltip: _localization.tr('location_details'),
            ),
          if (_configService.appConfig.features.ttsEnabled && _lastAIResponse != null)
            IconButton(
              icon: const Icon(Icons.volume_up),
              onPressed: _speakLastResponse,
              tooltip: _localization.tr('speak'),
            ),
        ],
      ),
      body: _buildUI(),
    );
  }

  void _showLocationDetails() {
    final data = widget.locationData!;
    final isTamil = _localization.isTamil;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _localization.tr('image_location_data'),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildInfoRow(_localization.tr('address'), data['address'] ?? 'N/A'),
            _buildInfoRow(_localization.tr('coordinates'), '${data['latitude']?.toStringAsFixed(6)}, ${data['longitude']?.toStringAsFixed(6)}'),
            _buildInfoRow(_localization.tr('altitude'), '${data['altitude']?.toStringAsFixed(1)} m'),
            _buildInfoRow(_localization.tr('gps_accuracy'), '${data['accuracy']?.toStringAsFixed(1)} m'),
            _buildInfoRow(_localization.tr('timestamp'), data['timestamp'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUI() {
    return DashChat(
      inputOptions: InputOptions(
        trailing: [
          IconButton(
            onPressed: _toggleVoiceMode,
            icon: Icon(_listening
                ? Icons.mic
                : (_voiceMode ? Icons.graphic_eq : Icons.mic_none)),
            color: _voiceMode ? Colors.blueAccent : null,
            tooltip: _voiceMode ? 'Stop voice chat' : 'Start voice chat',
          ),
          IconButton(
            onPressed: _sendMediaMessageFromCamera,
            icon: const Icon(Icons.image),
            tooltip: 'Add image',
          ),
          if (_configService.appConfig.features.ttsEnabled)
            IconButton(
              onPressed: _speakLastResponse,
              icon: const Icon(Icons.volume_up),
              tooltip: 'Speak last response',
            ),
        ],
        sendButtonBuilder: (onSend) => _isLoading
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => onSend(),
              ),
      ),
      currentUser: currentUser,
      onSend: _sendMessage,
      messages: messages,
      messageOptions: MessageOptions(
        currentUserContainerColor: Colors.blueAccent,
        containerColor: Colors.grey[800]!,
        textColor: Colors.white,
      ),
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    if (_configService.initialized &&
        _configService.appConfig.features.vibrationFeedback) {
      HapticFeedback.lightImpact();
    }
    
    setState(() {
      messages = [chatMessage, ...messages];
      _isLoading = true;
    });
    
    _getAIResponse(chatMessage);
  }

  void _sendMediaMessage(String imagePath) {
    _computeImageHash(imagePath);
    
    final chatMessage = ChatMessage(
      user: currentUser,
      createdAt: DateTime.now(),
      text: widget.prompt ?? _localization.tr('describe_picture'),
      medias: [
        ChatMedia(
          url: imagePath,
          fileName: "",
          type: MediaType.image,
        )
      ],
    );
    _sendMessage(chatMessage);
  }

  void _sendMediaMessageFromCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      _sendMediaMessage(file.path);
    }
  }

  Future<void> _getAIResponse(ChatMessage chatMessage) async {
    try {
      // Check cache first if offline mode enabled
      String? cachedResponse;
      if (_configService.appConfig.features.offlineMode) {
        cachedResponse = await _cacheService.getCachedResponse(
          prompt: chatMessage.text,
          imageHash: _imageHash,
        );
      }

      if (cachedResponse != null) {
        _handleResponse(cachedResponse, fromCache: true);
        return;
      }

      String question = chatMessage.text;
      List<Uint8List>? images;
      
      if (chatMessage.medias?.isNotEmpty ?? false) {
        final file = File(chatMessage.medias!.first.url);
        if (file.existsSync()) {
          images = [file.readAsBytesSync()];
        }
      }

      final response = await _aiService.generateResponse(
        prompt: question,
        images: images,
        isTamil: _localization.isTamil,
        enableBrowsing: _configService.appConfig.features.onDeviceLLM == false || true, // Enable for both
      );

      if (response != null) {
        // Cache the response
        if (_configService.appConfig.features.offlineMode) {
          await _cacheService.cacheResponse(
            prompt: question,
            response: response,
            imageHash: _imageHash,
            locationData: widget.locationData,
          );
        }
        _handleResponse(response);
      } else {
        _handleResponse(_localization.tr('error_occurred') + ': No response');
      }
    } catch (e) {
      _handleResponse('${_localization.tr('error_occurred')}: $e');
    }
  }

  void _handleResponse(String response, {bool fromCache = false}) {
    if (!mounted) return;

    final displayResponse = fromCache 
        ? '${_localization.tr('offline_mode')}: $response' 
        : response;

    if (messages.isNotEmpty && messages.first.user == geminiUser) {
      final lastMessage = messages.removeAt(0);
      final updatedMessage = ChatMessage(
        user: geminiUser,
        createdAt: lastMessage.createdAt,
        text: lastMessage.text + displayResponse,
        medias: lastMessage.medias,
      );
      setState(() {
        messages = [updatedMessage, ...messages];
        _lastAIResponse = displayResponse;
        _isLoading = false;
      });
    } else {
      final message = ChatMessage(
        user: geminiUser,
        createdAt: DateTime.now(),
        text: displayResponse,
      );
      setState(() {
        messages = [message, ...messages];
        _lastAIResponse = displayResponse;
        _isLoading = false;
      });
    }

    // Accessibility: speak the answer aloud automatically, then in voice-chat
    // mode re-open the mic for the next turn (ChatGPT-style loop).
    if (_configService.initialized &&
        _configService.appConfig.features.ttsEnabled) {
      _speakLastResponse().then((_) {
        if (_voiceMode && mounted) _listenOnce();
      });
    } else if (_voiceMode && mounted) {
      _listenOnce();
    }
  }

  Future<void> _speakLastResponse() async {
    if (_lastAIResponse == null) return;
    SpokenText.last = _lastAIResponse; // so Home's Volume-Down repeats it too
    await _tts.stop();
    await _tts.speak(_lastAIResponse!);
  }

  @override
  void dispose() {
    _keySub?.cancel();
    _voiceMode = false;
    _stt.stop();
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }
}