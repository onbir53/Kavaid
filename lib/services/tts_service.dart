import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();
  
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // TTS ayarları
      await _flutterTts.setLanguage("ar-SA"); // Arapça (Suudi Arabistan) 
      await _flutterTts.setSpeechRate(0.5); // Konuşma hızı (0.0 - 1.0)
      await _flutterTts.setVolume(1.0); // Ses seviyesi
      await _flutterTts.setPitch(1.0); // Ses tonu
      
      // iOS için özel ayarlar
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
            [IosTextToSpeechAudioCategoryOptions.allowBluetooth]);
      }
      
      // Event listener'lar
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        debugPrint('🎵 TTS: Konuşma başladı');
      });
      
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        debugPrint('✅ TTS: Konuşma tamamlandı');
      });
      
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('❌ TTS Hatası: $msg');
      });
      
      _isInitialized = true;
      debugPrint('✅ TTS servisi başlatıldı');
    } catch (e) {
      debugPrint('❌ TTS başlatma hatası: $e');
    }
  }
  
  Future<bool> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isSpeaking) {
      await stop();
    }
    
    try {
      final result = await _flutterTts.speak(text);
      return result == 1;
    } catch (e) {
      debugPrint('❌ TTS konuşma hatası: $e');
      return false;
    }
  }
  
  Future<void> stop() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
    }
  }
  
  bool get isSpeaking => _isSpeaking;
  
  void dispose() {
    _flutterTts.stop();
  }
} 