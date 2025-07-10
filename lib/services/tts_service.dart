import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

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
      await _flutterTts.setSpeechRate(0.4); // Hız yavaşlatıldı.
      await _flutterTts.setVolume(1.0); // Ses seviyesi
      await _flutterTts.setPitch(1.0); // Ses tonu

      // Erkek sesi bul ve ayarla
      await _setMaleVoice();
      
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

  Future<void> _setMaleVoice() async {
    try {
      final voices = await _flutterTts.getVoices;
      final voiceList = (voices as List<dynamic>).cast<Map<dynamic, dynamic>>();

      // Cihazdaki tüm Arapça sesleri logla
      debugPrint('ℹ️ [TTS] Cihazda bulunan Arapça sesler:');
      for (var voice in voiceList) {
        if (voice['locale']?.toString().toLowerCase().startsWith('ar') ?? false) {
          debugPrint('   - İsim: ${voice['name']}, Dil: ${voice['locale']}, Cinsiyet: ${voice['gender']}');
        }
      }

      // Erkek Arapça sesi bulmaya çalış
      final arabicMaleVoice = voiceList.firstWhereOrNull(
        (voice) {
          final lang = voice['locale']?.toString().toLowerCase() ?? '';
          final name = voice['name']?.toString().toLowerCase() ?? '';
          final gender = voice['gender']?.toString().toLowerCase() ?? '';
          return lang.startsWith('ar') && (gender == 'male' || name.contains('male'));
        },
      );

      if (arabicMaleVoice != null) {
        final voiceToSet = Map<String, String>.from(arabicMaleVoice.map((key, value) => MapEntry(key.toString(), value.toString())));
        await _flutterTts.setVoice(voiceToSet);
        debugPrint('✅ [TTS] Erkek Arapça ses ayarlandı: ${voiceToSet['name']}');
      } else {
        debugPrint('⚠️ [TTS] Cihazda erkek Arapça ses bulunamadı. Varsayılan ses kullanılacak.');
      }
    } catch (e) {
      debugPrint('❌ [TTS] Ses ayarlanırken bir hata oluştu: $e');
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