import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';
import '../services/localization_service.dart';
import '../services/offline_cache_service.dart';
import '../services/config_service.dart';

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
  
  List<ChatMessage> messages = [];
  bool _isLoading = false;
  String? _lastAIResponse;
  String? _imageHash;

  ChatUser currentUser = ChatUser(id: "0", firstName: "User");
  ChatUser geminiUser = ChatUser(
    id: "1",
    firstName: "AI for all",
    profileImage: "assets/images/import.jpg",
  );

  @override
  void initState() {
    super.initState();
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
  }

  Future<void> _setupTTS() async {
    await _tts.awaitSpeakCompletion(true);
    // en-US voice data ships with Google TTS everywhere; en-IN is often a
    // network-only voice that silently produces no audio.
    final ok = await _tts.setLanguage(
        _localization.currentLocale == 'ta' ? 'ta-IN' : 'en-US');
    if (ok != 1) await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
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

    // Accessibility: speak the answer aloud automatically.
    if (_configService.initialized &&
        _configService.appConfig.features.ttsEnabled) {
      _speakLastResponse();
    }
  }

  Future<void> _speakLastResponse() async {
    if (_lastAIResponse == null) return;
    await _tts.stop();
    await _tts.speak(_lastAIResponse!);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}