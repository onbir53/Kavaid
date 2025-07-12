import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import '../models/word_model.dart';
import 'firebase_service.dart';
import 'dart:math' as math;

class GeminiService {
  static const String _defaultApiKey = 'AIzaSyCbAR_1yQ2QVKbpyWRFj0VpOxAQZ2JBfas';
  static const String _defaultModel = 'gemini-1.5-flash-latest';
  static const String _defaultPrompt = '''YAPAY ZEKA İÇİN GÜNCEL VE KESİN TALİMATLAR

Sen bir Arapça sözlük uygulamasısın. Kullanıcıdan Arapça veya Türkçe bir kelime al ve gramer özelliklerini dikkate alarak detaylı bir tarama yap.
Sadece kesin olarak bildiğin ve doğrulayabildiğin bilgileri sun. 
Bilmediğin veya emin olmadığın hiçbir bilgiyi uydurma ya da tahmin etme. Çıktıyı aşağıdaki JSON formatında üret.

Genel Kurallar
JSON Formatı: Çıktı, belirtilen JSON yapısına tam uymalıdır.

eğer kullanıcı türkçe bir kelime girerse bu kelimenin gramer yapısına çok dikkat et arapça gramerinde ve  çevir ve öyle devam et.
anlam kısmında girilen türkçe kelimeyide ver.
aranan türkçe kelimenin mazi müzari mastar olarak arapça korşlığını en doğru oalrak ver
Harekeler: kelime ve koku alanları harekesiz, diğer tüm Arapça kelimeler tam harekeli (vokalize edilmiş) olmalıdır.
Boş Bırakma: Bilgi yoksa veya alan uygulanamıyorsa, ilgili alanlar "" (boş string) veya [] (boş dizi) olmalıdır. Asla uydurma bilgi ekleme.
Hata Durumu: Kelime bulunamazsa veya dilbilgisel olarak anlaşılamazsa, bulunduMu alanını false yap, kelimeBilgisi alanını null bırak.
Örnek Cümleler: ornekCumleler dizisi, iki adet orta uzunlukta ve orta zorlukta cümle içermelidir.
genel yapı: veriler kısa, öz, resmi ve net olmalıdır. Parantezli ek açıklamalar veya gayri resmi ifadeler kullanılmamalıdır.
dikkat: parantez kullanılmamalı.

Kelime: "{KELIME}"

{
  "bulunduMu": true,
  "kelimeBilgisi": {
    "kelime": "تهنئة",
    "harekeliKelime": "تَهْنِئَةٌ",
    "anlam": "Tebrik, kutlama",
    "koku": "هنا",
    "dilbilgiselOzellikler": {
      "tur": "Mastar",
      "cogulForm": "تَهَانِئُ"
    },
    "ornekCumleler": [
      {
        "arapcaCümle": "أَرْسَلْتُ تَهْنِئَةً بِالنَّجَاحِ.",
        "turkceAnlam": "Başarı için tebrik mesajı gönderdim."
      },
      {
        "arapcaCümle": "تَلَقَّيْتُ تَهْنِئَةً بِالْعِيدِ.",
        "turkceAnlam": "Bayram tebriği aldım."
      }
    ],
    "fiilCekimler": {
      "maziForm": "هَنَّأَ",
      "muzariForm": "يُهَنِّئُ",
      "mastarForm": "تَهْنِئَةٌ",
      "emirForm": "هَنِّئْ"
    }
  }
}
JSON Alanlarının Tanımı
bulunduMu (boolean): Kelimenin sözlükte bulunup bulunmadığını gösterir.
true: Kelime bulundu, kelimeBilgisi dolu.
false: Kelime bulunamadı veya girilen bir kelime değil, kelimeBilgisi null.
kelimeBilgisi (object | null): Kelimeye ait tüm bilgiler.
bulunduMu false ise null.
Aksi takdirde aşağıdaki alanları içerir:
kelime (string): Kullanıcının girdiği kelime, eğer türkçe girdiyse arapça olarak ele al(harekeli veya harekesiz).
harekeliKelime (string): Kelimenin tam harekeli hali.
anlam (string): Türkçe anlam(lar), virgülle ayrılmış, net ve öz gramere uygun şekilde olmalıi fiillerin zamanına dikkat edilmeli, 
eğer aranan türkçe bir kelimeyse ve arapçaya çevrildiyse anlamda  girilien türkeç kelimeyide ver anlamlar arasında, parantez falan kullanma.
koku (string): Kelimenin kökü, bitişik ve harekesiz (ör. كتب).
dilbilgiselOzellikler (object):
tur (string): Kelimenin türü (ör. İsim, Mazî Fiil, Mastar). Bilinmiyorsa "".
cogulForm (string): İsimse tam harekeli çoğul hali, değilse "" veya zaten kelime çoğulsa "".
ornekCumleler (array of object): İki örnek cümle.
arapcaCümle (string): Tam harekeli Arapça cümle.
turkceAnlam (string): Cümlenin Türkçe çevirisi.
fiilCekimler (object): Fiilse çekimler, değilse tüm alanlar "".
maziForm (string): Mazi, 3. tekil eril, harekeli.
muzariForm (string): Muzari, 3. tekil eril, harekeli.
mastarForm (string): Mastar, harekeli.
emirForm (string): Emir, 2. tekil eril, harekeli.
''';

  // Singleton pattern
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  // Public initializer, main.dart'tan çağrılacak
  Future<void> initialize() async {
    await _initializeFirebaseConfig();
  }

  // Firebase config durumu
  bool _isConfigInitialized = false;
  int _adCooldownSeconds = 60; // Varsayılan değer
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Dışarıdan erişim için public getter
  int get adCooldownSeconds => _adCooldownSeconds;

  // Firebase config'i initialize et ve validate et
  Future<void> _initializeFirebaseConfig() async {
    if (_isConfigInitialized) return;
    
    debugPrint('🔧 Firebase config initialization başlatılıyor...');
    
    try {
      await _createConfigInDatabase();
      await _validateConfig();
      _isConfigInitialized = true;
      debugPrint('✅ Firebase config başarıyla initialize edildi');
    } catch (e) {
      debugPrint('❌ Firebase config initialization hatası: $e');
      // Hata durumunda da devam et ama flag'i false bırak
    }
  }

  // Config'in valid olup olmadığını kontrol et
  Future<void> _validateConfig() async {
    debugPrint('🔍 Firebase config validation başlatılıyor...');
    
    try {
      // API key kontrolü
      final apiKey = await _getApiKey();
      if (apiKey.isEmpty || apiKey == 'null') {
        throw Exception('API key boş veya geçersiz');
      }
      
      // Model kontrolü  
      final model = await _getModel();
      if (model.isEmpty || model == 'null') {
        throw Exception('Model boş veya geçersiz');
      }
      
      // Prompt kontrolü
      final prompt = await _getPrompt();
      if (prompt.isEmpty || prompt.length < 100) {
        throw Exception('Prompt boş veya çok kısa');
      }

      // Reklam süresi kontrolü
      _adCooldownSeconds = await _getAdCooldown();
      
      debugPrint('✅ Firebase config validation başarılı');
      debugPrint('   API Key: ${apiKey.length} karakter');
      debugPrint('   Model: $model');
      debugPrint('   Prompt: ${prompt.length} karakter');
      debugPrint('   Ad Cooldown: $_adCooldownSeconds saniye');
      
    } catch (e) {
      debugPrint('❌ Firebase config validation hatası: $e');
      throw e;
    }
  }

  // Retry mekanizması ile API key al
  Future<String> _getApiKey() async {
    return await _getConfigWithRetry('gemini_api');
  }

  // Retry mekanizması ile model al
  Future<String> _getModel() async {
    return await _getConfigWithRetry('gemini_model');
  }

  // Retry mekanizması ile prompt al
  Future<String> _getPrompt() async {
    return await _getConfigWithRetry('gemini_prompt');
  }

  // Retry mekanizması ile reklam süresini al
  Future<int> _getAdCooldown() async {
    final valueStr = await _getConfigWithRetry('ad_cooldown_seconds');
    debugPrint('ℹ️ [GeminiService] Firebase\'den okunan "ad_cooldown_seconds" ham değeri: "$valueStr"');
    final intValue = int.tryParse(valueStr);
    if (intValue == null) {
      debugPrint('⚠️ [GeminiService] "ad_cooldown_seconds" değeri sayıya çevrilemedi. Güvenlik için 60sn kullanılıyor.');
      return 60;
    }
    debugPrint('✅ [GeminiService] "ad_cooldown_seconds" başarıyla parse edildi: $intValue saniye.');
    return intValue;
  }

  // Retry mekanizması ile config değeri al
  Future<String> _getConfigWithRetry(String configKey) async {
    for (int i = 0; i < _maxRetries; i++) {
      DataSnapshot snapshot;
      try {
        debugPrint('🔄 Firebase config okunuyor (${i + 1}/$_maxRetries): $configKey');
        
        final database = FirebaseDatabase.instance;
        final configRef = database.ref('config/$configKey');
        snapshot = await configRef.get();
        
      } catch (e) {
        debugPrint('❌ Firebase ağ hatası (${i + 1}/$_maxRetries): $configKey - $e');
        if (i < _maxRetries - 1) {
          debugPrint('🔄 ${_retryDelay.inSeconds} saniye beklenip tekrar denenecek...');
          await Future.delayed(_retryDelay);
          continue; // Sonraki denemeye geç
        } else {
          // Bu son deneme, ağ hatasıyla ilgili kesin bir hata fırlat.
          throw Exception('Firebase config okunamadı ($configKey) ve tüm ağ denemeleri başarısız oldu: $e');
        }
      }

      // Ağ isteği başarılı, şimdi veriyi kontrol et.
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value.toString().trim();
        if (value.isNotEmpty && value != 'null') {
          debugPrint('✅ Firebase config başarıyla okundu: $configKey');
          return value; // Başarılı, değeri döndür.
        } else {
           // Değer boş, bu bir konfigürasyon hatası. Yeniden deneme yok.
           throw Exception('Firebase config değeri boş veya geçersiz: $configKey');
        }
      } else {
          // Anahtar bulunamadı, bu bir konfigürasyon hatası. Yeniden deneme yok.
          throw Exception('Firebase config anahtarı bulunamadı: $configKey');
      }
    }
    // Bu kod normalde ulaşılamaz olmalı.
    throw Exception('Beklenmedik durum: _getConfigWithRetry döngüsü tamamlandı.');
  }

  // Config alanını database'de oluştur (geliştirilmiş)
  Future<void> _createConfigInDatabase() async {
    try {
      debugPrint('🔧 Firebase config kontrolü yapılıyor...');
      
      final database = FirebaseDatabase.instance;
      final configRef = database.ref('config');
      
      // Config alanının var olup olmadığını kontrol et
      final snapshot = await configRef.get();
      
      if (snapshot.exists && snapshot.value != null) {
        final configData = snapshot.value as Map<dynamic, dynamic>;
        
        // Eksik alanları kontrol et ve ekle
        final updates = <String, dynamic>{};
        
        if (!configData.containsKey('gemini_api') || configData['gemini_api'] == null) {
          updates['gemini_api'] = _defaultApiKey;
          debugPrint('📝 gemini_api alanı eklenecek');
        }
        
        if (!configData.containsKey('gemini_model') || configData['gemini_model'] == null) {
          updates['gemini_model'] = _defaultModel;
          debugPrint('📝 gemini_model alanı eklenecek');
        }
        
        if (!configData.containsKey('gemini_prompt') || configData['gemini_prompt'] == null) {
          updates['gemini_prompt'] = _defaultPrompt;
          debugPrint('📝 gemini_prompt alanı eklenecek');
        }
        
        if (updates.isNotEmpty) {
          await configRef.update(updates);
          debugPrint('✅ Eksik config alanları güncellendi: ${updates.keys.join(', ')}');
        } else {
          debugPrint('✅ Tüm config alanları mevcut');
        }
      } else {
        // Config alanı hiç yoksa tamamen oluştur
        await configRef.set({
          'gemini_api': _defaultApiKey,
          'gemini_model': _defaultModel,
          'gemini_prompt': _defaultPrompt,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'note': 'Firebase Console\'dan bu değerleri düzenleyebilirsiniz'
        });
        
        debugPrint('✅ Firebase config tamamen oluşturuldu');
      }
      
    } catch (e) {
      debugPrint('❌ Firebase config oluşturma hatası: $e');
      throw e;
    }
  }

  // API anahtarını manuel refresh et (artık her seferinde fresh alındığı için sadece log)
  void clearApiKeyCache() {
    debugPrint('🔄 API anahtarı bir sonraki istekte Firebase\'den fresh alınacak');
  }

  // Firebase config'i manuel olarak yeniden initialize et
  Future<void> forceConfigRefresh() async {
    debugPrint('🔄 Firebase config manuel refresh başlatılıyor...');
    _isConfigInitialized = false;
    await _initializeFirebaseConfig();
  }

  // Manual olarak config değerlerini set et (test için)
  Future<bool> setConfigValues({
    String? apiKey,
    String? model,
    String? prompt,
  }) async {
    try {
      debugPrint('🔧 Firebase config değerleri manuel olarak set ediliyor...');
      
      final database = FirebaseDatabase.instance;
      final configRef = database.ref('config');
      
      final updates = <String, dynamic>{};
      
      if (apiKey != null && apiKey.isNotEmpty) {
        updates['gemini_api'] = apiKey;
        debugPrint('🔑 API Key güncelleniyor: ${apiKey.substring(0, 15)}...${apiKey.substring(apiKey.length - 5)}');
      }
      
      if (model != null && model.isNotEmpty) {
        updates['gemini_model'] = model;
        debugPrint('🤖 Model güncelleniyor: $model');
      }
      
      if (prompt != null && prompt.isNotEmpty) {
        updates['gemini_prompt'] = prompt;
        debugPrint('📝 Prompt güncelleniyor: ${prompt.length} karakter');
      }
      
      if (updates.isNotEmpty) {
        updates['updated_at'] = DateTime.now().millisecondsSinceEpoch;
        await configRef.update(updates);
        
        // Config'i yeniden initialize et
        await forceConfigRefresh();
        
        debugPrint('✅ Firebase config manuel güncelleme başarılı');
        return true;
      } else {
        debugPrint('⚠️ Güncellenecek config değeri bulunamadı');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Firebase config manuel güncelleme hatası: $e');
      return false;
    }
  }

  // Config durumunu debug et
  Future<void> debugConfigStatus() async {
    try {
      debugPrint('🔍 GeminiService Config Debug Başlıyor...');
      debugPrint('────────────────────────────────────');
      
      // Initialization durumu
      debugPrint('🔧 Config Initialize Durumu: $_isConfigInitialized');
      
      // Firebase bağlantısı test et
      debugPrint('🔥 Firebase bağlantısı test ediliyor...');
      final database = FirebaseDatabase.instance;
      final configRef = database.ref('config');
      
      try {
        final snapshot = await configRef.get();
        if (snapshot.exists) {
          debugPrint('✅ Firebase config alanı mevcut');
          final configData = snapshot.value as Map<dynamic, dynamic>;
          debugPrint('📊 Config alanları: ${configData.keys.toList()}');
        } else {
          debugPrint('❌ Firebase config alanı bulunamadı');
        }
      } catch (e) {
        debugPrint('❌ Firebase bağlantı hatası: $e');
      }
      
      // Tüm config değerlerini test et
      debugPrint('🔍 Config değerleri test ediliyor...');
      
      try {
        final apiKey = await _getApiKey();
        debugPrint('🔑 API Key: ${apiKey.substring(0, 15)}...${apiKey.substring(apiKey.length - 5)} (${apiKey.length} karakter)');
        debugPrint('🔑 API Key Default?: ${apiKey == _defaultApiKey}');
      } catch (e) {
        debugPrint('❌ API Key hatası: $e');
      }
      
      try {
        final model = await _getModel();
        debugPrint('🤖 Model: $model');
        debugPrint('🤖 Model Default?: ${model == _defaultModel}');
      } catch (e) {
        debugPrint('❌ Model hatası: $e');
      }
      
      try {
        final prompt = await _getPrompt();
        debugPrint('📝 Prompt: ${prompt.length} karakter');
        debugPrint('📝 Prompt Default?: ${prompt == _defaultPrompt}');
        debugPrint('📝 Prompt Preview: ${prompt.substring(0, math.min(100, prompt.length))}...');
        
        // Reklam süresi debug
        try {
          final cooldown = await _getAdCooldown();
          debugPrint('⏱️ Ad Cooldown: $cooldown saniye');
        } catch (e) {
          debugPrint('❌ Ad Cooldown hatası: $e');
        }
      } catch (e) {
        debugPrint('❌ Prompt hatası: $e');
      }
      
      debugPrint('────────────────────────────────────');
      debugPrint('✅ GeminiService Config Debug Tamamlandı');
      
    } catch (e) {
      debugPrint('❌ Config debug kritik hatası: $e');
    }
  }

  // Kelime analizi - HomeScreen için
  Future<WordModel?> analyzeWord(String word) async {
    try {
      debugPrint('🔍 Kelime analiz ediliyor: $word');
      
      // Firebase config'i initialize et
      await _initializeFirebaseConfig();
      
      // Önce Firebase'de kelime var mı kontrol et
      final firebaseService = FirebaseService();
      final existingWord = await firebaseService.getWordByName(word);
      
      if (existingWord != null) {
        debugPrint('📦 Kelime zaten veritabanında mevcut: ${existingWord.kelime}');
        return existingWord.bulunduMu ? existingWord : null;
      }
      
      // Firebase'de bulunamadıysa AI çağrısı yap
      debugPrint('🤖 Kelime veritabanında bulunamadı, AI çağrısı yapılıyor: $word');
      final result = await searchWord(word);
      
      // AI'dan gelen sonucu döndür
      return result.bulunduMu ? result : null;
    } catch (e) {
      debugPrint('❌ Analiz hatası: $e');
      return null;
    }
  }

  Future<WordModel> searchWord(String word) async {
    try {
      debugPrint('🔍 Kelime aranıyor: $word');
      
      // OPTIMIZASYON: Firebase kontrolü burada gereksiz.
      // Bu kontrol zaten bu fonksiyonu çağıran HomeScreen._performActualAISearch
      // içinde yapılıyor. Bu bloğun kaldırılması, her AI aramasında
      // gereksiz bir veritabanı sorgusunu önler.
      /*
      final firebaseService = FirebaseService();
      final existingWord = await firebaseService.getWordByName(word);
      
      if (existingWord != null) {
        debugPrint('📦 Kelime zaten veritabanında mevcut: ${existingWord.kelime}');
        return existingWord;
      }
      */
      
      debugPrint('🤖 Kelime veritabanında bulunamadı, Gemini API\'ye istek atılıyor: $word');
      
      // Firebase config'i initialize et
      await _initializeFirebaseConfig();
      
      // API anahtarını, modeli ve prompt'u dinamik olarak al
      debugPrint('📥 Firebase config değerleri alınıyor...');
      final apiKey = await _getApiKey();
      final model = await _getModel();
      final promptTemplate = await _getPrompt();
      debugPrint('📥 Firebase config değerleri alındı');
      
      // URL'yi model bilgisine göre oluştur
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
      debugPrint('🌐 API URL: $url');
      
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': _buildPromptWithWord(promptTemplate, word),
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.0,
          'topK': 1,
          'topP': 0.1,
          'maxOutputTokens': 1000,
          'thinkingConfig': {
            'thinkingBudget': 0, // Thinking'i kapatmak için budget'ı 0 yap
          },
        },
        'systemInstruction': {
          'parts': [
            {
              'text': 'Sen deterministik bir sözlük asistanısın. Hiç düşünme, sadece kesin bilgileri ver.'
            }
          ]
        }
      };

      debugPrint('📤 HTTP isteği gönderiliyor...');
      debugPrint('📤 Request Body Size: ${json.encode(requestBody).length} bytes');
      debugPrint('🔧 Temperature: ${(requestBody['generationConfig'] as Map)['temperature']}');
      final thinkingConfig = (requestBody['generationConfig'] as Map)['thinkingConfig'] as Map?;
      debugPrint('🔧 Thinking Budget: ${thinkingConfig?['thinkingBudget']}');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      debugPrint('📥 HTTP yanıt alındı - Status: ${response.statusCode}');
      debugPrint('📥 Response Size: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Candidates kontrolü
        if (data['candidates'] == null) {
          debugPrint('❌ Candidates null');
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'API yanıtında candidates bulunamadı',
          );
        }
        
        if (data['candidates'].isEmpty) {
          debugPrint('❌ Candidates boş');
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'API yanıtında içerik bulunamadı',
          );
        }
        
        final candidate = data['candidates'][0];
        
        // finishReason kontrolü - kesilmiş yanıtları da parse etmeye çalış
        final finishReason = candidate['finishReason'];
        
        if (candidate['content'] == null) {
          debugPrint('❌ Content null');
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'API yanıtında content bulunamadı',
          );
        }
        
        if (candidate['content']['parts'] == null || candidate['content']['parts'].isEmpty) {
          debugPrint('❌ Parts null veya boş');
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'API yanıtında metin içeriği bulunamadı',
          );
        }
        
        final content = candidate['content']['parts'][0]['text'];
        if (content == null || content.toString().trim().isEmpty) {
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'API yanıtında metin içeriği bulunamadı',
          );
        }
        
        // JSON'u temizle ve parse et
        final cleanedJson = _cleanJsonResponse(content);
        
        try {
          final wordData = json.decode(cleanedJson);
          final wordModel = WordModel.fromJson(wordData);
          
          // Eğer kelime bulunduysa Firebase'e kaydet
          if (wordData['bulunduMu'] == true && wordData['kelimeBilgisi'] != null) {
            await _saveToFirebase(wordData['kelimeBilgisi']);
          }
          
          return wordModel;
        } catch (jsonError) {
          // JSON parse hatası durumunda fallback
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'JSON formatı hatalı veya kelime bulunamadı',
          );
        }
      } else {
        debugPrint('❌ API Hatası - Status: ${response.statusCode}');
        debugPrint('❌ API Hatası - Body: ${response.body}');
        debugPrint('❌ Kullanılan URL: $url');
        debugPrint('❌ API Key son 10 karakter: ${apiKey.substring(apiKey.length - 10)}');
        debugPrint('❌ Model: $model');
        throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Hata oluştu: $e');
      // Hata durumunda boş kelime modeli döndür
      return WordModel(
        kelime: word,
        bulunduMu: false,
        anlam: 'Kelime bulunamadı veya API hatası: ${e.toString()}',
      );
    }
  }

  Future<void> _saveToFirebase(Map<String, dynamic> kelimeBilgisi) async {
    try {
      final harekeliKelime = kelimeBilgisi['harekeliKelime'] ?? kelimeBilgisi['kelime'];
      debugPrint('💾 Realtime Database\'e kaydediliyor: $harekeliKelime');
      
      final database = FirebaseDatabase.instance;
      final kelimelerRef = database.ref('kelimeler');
      
      // Kelime zaten var mı kontrol et (harekeli hali ile)
      final existingSnapshot = await kelimelerRef.child(harekeliKelime).once();
      
      if (existingSnapshot.snapshot.exists) {
        debugPrint('📝 Kelime zaten mevcut: $harekeliKelime');
        return;
      }
      
      // Gemini'den gelen kelimeBilgisi objesini direkt kaydet
      final docData = {
        ...kelimeBilgisi, // Tüm kelimeBilgisi objesini kopyala
        'eklenmeTarihi': DateTime.now().millisecondsSinceEpoch,
        'kaynak': 'AI', // AI'dan geldiğini belirtmek için
      };
      
      // Harekeli kelimeyi key olarak kullanarak kaydet
      await kelimelerRef.child(harekeliKelime).set(docData);
      debugPrint('✅ Realtime Database\'e başarıyla kaydedildi: $harekeliKelime');
      
      // Firebase cache'ini temizle - yeni kelime eklendiği için
      FirebaseService.clearCache();
      
    } catch (e) {
      debugPrint('❌ Realtime Database kaydetme hatası: $e');
      // Hata durumunda sessizce devam et, ana işlevi etkilemesin
    }
  }

  // Prompt'a kelimeyi ekle
  String _buildPromptWithWord(String promptTemplate, String word) {
    // Prompt içindeki {KELIME} placeholder'ını gerçek kelime ile değiştir
    return promptTemplate.replaceAll('{KELIME}', word);
  }

  String _buildPrompt(String word) {
    return _defaultPrompt.replaceAll('{KELIME}', word);
  }

  String _cleanJsonResponse(String response) {
    try {
      // Markdown kod bloklarını temizle
      String cleaned = response.replaceAll(RegExp(r'```json\s*'), '');
      cleaned = cleaned.replaceAll(RegExp(r'```\s*$'), '');
      cleaned = cleaned.replaceAll('```', '');
      
      // Başındaki ve sonundaki boşlukları temizle
      cleaned = cleaned.trim();
      
      // Eğer JSON ile başlamıyorsa, JSON'u bul
      int jsonStart = cleaned.indexOf('{');
      if (jsonStart > 0) {
        cleaned = cleaned.substring(jsonStart);
      }
      
      // JSON'un tam olup olmadığını kontrol et
      int braceCount = 0;
      int lastValidIndex = -1;
      
      for (int i = 0; i < cleaned.length; i++) {
        if (cleaned[i] == '{') {
          braceCount++;
        } else if (cleaned[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            lastValidIndex = i;
            break;
          }
        }
      }
      
      if (lastValidIndex > 0) {
        cleaned = cleaned.substring(0, lastValidIndex + 1);
      }
      
      // Eğer hala geçersizse, son } karakterinden sonrasını temizle
      int jsonEnd = cleaned.lastIndexOf('}');
      if (jsonEnd > 0 && jsonEnd < cleaned.length - 1) {
        cleaned = cleaned.substring(0, jsonEnd + 1);
      }
      
      return cleaned;
    } catch (e) {
      debugPrint('❌ JSON temizleme hatası: $e');
      // Hata durumunda basit temizlik yap
      String fallback = response.trim();
      int start = fallback.indexOf('{');
      int end = fallback.lastIndexOf('}');
      if (start >= 0 && end > start) {
        return fallback.substring(start, end + 1);
      }
      return response;
    }
  }

  // API Key kontrolü
  Future<bool> get isConfigured async {
    try {
      final apiKey = await _getApiKey();
      return apiKey.isNotEmpty;
    } catch (e) {
      debugPrint('❌ API anahtarı kontrol hatası: $e');
      return false;
    }
  }

  // TEST: Firebase'e config alanlarını manuel oluştur
  static Future<void> createFirebaseConfig() async {
    try {
      debugPrint('🔧 Firebase\'e config alanları kontrol ediliyor...');
      
      final service = GeminiService();
      await service._createConfigInDatabase();
      
      debugPrint('📝 Firebase\'e yazılan config:');
      debugPrint('   API Key: ${_defaultApiKey.substring(0, 15)}...${_defaultApiKey.substring(_defaultApiKey.length - 5)}');
      debugPrint('   Model: $_defaultModel');
      debugPrint('   Prompt: ${_defaultPrompt.length} karakter');
      
      debugPrint('✅ Firebase config alanları başarıyla oluşturuldu');
    } catch (e) {
      debugPrint('❌ Firebase config oluşturma hatası: $e');
    }
  }

  // TEST: API bağlantısını test et
  static Future<void> testApiConnection() async {
    try {
      debugPrint('🧪 Gemini API bağlantısı test ediliyor...');
      
      final service = GeminiService();
      
      // Önce config'i initialize et
      await service._initializeFirebaseConfig();
      
      final testWord = 'مرحبا'; // "Merhaba" Arapça
      
      // Test kelimesi ile API çağrısı yap
      debugPrint('🔍 Test kelimesi: $testWord');
      final result = await service.searchWord(testWord);
      
      // Detaylı sonuç log'la
      if (result.bulunduMu) {
        debugPrint('✅ Gemini API bağlantısı BAŞARILI');
        debugPrint('📖 Test sonucu: ${result.kelime} - ${result.anlam}');
      } else {
        debugPrint('❌ Gemini API bağlantı hatası: ${result.anlam}');
      }
      
    } catch (e) {
      debugPrint('❌ API test kritik hatası: $e');
    }
  }

  // TEST: Firebase config değerlerini test et
  static Future<void> testFirebaseConfig() async {
    try {
      debugPrint('🧪🔥 Firebase Config Test Başlıyor...');
      
      final service = GeminiService();
      
      // Önce config'i initialize et
      await service._initializeFirebaseConfig();
      
      // API Key test
      debugPrint('🔑 API Key test ediliyor...');
      final apiKey = await service._getApiKey();
      debugPrint('🔑 Alınan API Key: ${apiKey.substring(0, 15)}...${apiKey.substring(apiKey.length - 5)}');
      
      // Model test
      debugPrint('🤖 Model test ediliyor...');
      final model = await service._getModel();
      debugPrint('🤖 Alınan Model: $model');
      
      // Prompt test
      debugPrint('📝 Prompt test ediliyor...');
      final prompt = await service._getPrompt();
      debugPrint('📝 Alınan Prompt: ${prompt.length} karakter');
      debugPrint('📝 Prompt başı: ${prompt.substring(0, math.min(200, prompt.length))}...');
      
      // Reklam süresi debug
      try {
        final cooldown = await service._getAdCooldown();
        debugPrint('⏱️ Ad Cooldown: $cooldown saniye');
      } catch (e) {
        debugPrint('❌ Ad Cooldown hatası: $e');
      }
      
      debugPrint('✅ Firebase Config Test Tamamlandı');
      
    } catch (e) {
      debugPrint('❌ Firebase Config test hatası: $e');
    }
  }

  // COMPREHENSIVE TEST: Tüm sistemi test et
  static Future<Map<String, dynamic>> runComprehensiveTest() async {
    final results = <String, dynamic>{
      'configSetup': false,
      'configValidation': false,
      'firebaseConnection': false,
      'geminiApiConnection': false,
      'testWordSearch': false,
      'errors': <String>[],
      'details': <String, dynamic>{},
    };
    
    try {
      debugPrint('🔬 COMPREHENSIVE TEST BAŞLATIYOR...');
      debugPrint('═══════════════════════════════════════════════════════════════');
      
      final service = GeminiService();
      
      // 1. Config Setup Test
      debugPrint('1️⃣ Config Setup Test...');
      try {
        await service._createConfigInDatabase();
        results['configSetup'] = true;
        debugPrint('✅ Config setup başarılı');
      } catch (e) {
        results['errors'].add('Config setup hatası: $e');
        debugPrint('❌ Config setup hatası: $e');
      }
      
      // 2. Config Validation Test
      debugPrint('2️⃣ Config Validation Test...');
      try {
        await service._validateConfig();
        results['configValidation'] = true;
        debugPrint('✅ Config validation başarılı');
      } catch (e) {
        results['errors'].add('Config validation hatası: $e');
        debugPrint('❌ Config validation hatası: $e');
      }
      
      // 3. Firebase Connection Test
      debugPrint('3️⃣ Firebase Connection Test...');
      try {
        final database = FirebaseDatabase.instance;
        final configRef = database.ref('config');
        final snapshot = await configRef.get();
        
        if (snapshot.exists) {
          results['firebaseConnection'] = true;
          final configData = snapshot.value as Map<dynamic, dynamic>;
          results['details']['firebaseConfigKeys'] = configData.keys.toList();
          debugPrint('✅ Firebase connection başarılı');
          debugPrint('📊 Config keys: ${configData.keys.toList()}');
        } else {
          results['errors'].add('Firebase config bulunamadı');
          debugPrint('❌ Firebase config bulunamadı');
        }
      } catch (e) {
        results['errors'].add('Firebase connection hatası: $e');
        debugPrint('❌ Firebase connection hatası: $e');
      }
      
      // 4. Gemini API Connection Test
      debugPrint('4️⃣ Gemini API Connection Test...');
      try {
        final apiKey = await service._getApiKey();
        final model = await service._getModel();
        
        results['details']['apiKey'] = '${apiKey.substring(0, 15)}...${apiKey.substring(apiKey.length - 5)}';
        results['details']['model'] = model;
        results['details']['apiKeyIsDefault'] = apiKey == _defaultApiKey;
        
        // Basit HTTP test
        final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          results['geminiApiConnection'] = true;
          debugPrint('✅ Gemini API connection başarılı');
        } else {
          results['errors'].add('Gemini API HTTP hatası: ${response.statusCode}');
          debugPrint('❌ Gemini API HTTP hatası: ${response.statusCode}');
        }
      } catch (e) {
        results['errors'].add('Gemini API connection hatası: $e');
        debugPrint('❌ Gemini API connection hatası: $e');
      }
      
      // 5. Test Word Search
      debugPrint('5️⃣ Test Word Search...');
      try {
        final testWord = 'مرحبا'; // "Merhaba" Arapça
        final result = await service.searchWord(testWord);
        
        if (result.bulunduMu) {
          results['testWordSearch'] = true;
          results['details']['testWordResult'] = {
            'word': result.kelime,
            'meaning': result.anlam,
            'harakeli': result.harekeliKelime,
          };
          debugPrint('✅ Test word search başarılı');
          debugPrint('📖 Test sonucu: ${result.kelime} - ${result.anlam}');
        } else {
          results['errors'].add('Test word search başarısız: ${result.anlam}');
          debugPrint('❌ Test word search başarısız: ${result.anlam}');
        }
      } catch (e) {
        results['errors'].add('Test word search hatası: $e');
        debugPrint('❌ Test word search hatası: $e');
      }
      
      // Sonuçları özetle
      debugPrint('═══════════════════════════════════════════════════════════════');
      debugPrint('📊 TEST SONUÇLARI:');
      debugPrint('   Config Setup: ${results['configSetup'] ? '✅' : '❌'}');
      debugPrint('   Config Validation: ${results['configValidation'] ? '✅' : '❌'}');
      debugPrint('   Firebase Connection: ${results['firebaseConnection'] ? '✅' : '❌'}');
      debugPrint('   Gemini API Connection: ${results['geminiApiConnection'] ? '✅' : '❌'}');
      debugPrint('   Test Word Search: ${results['testWordSearch'] ? '✅' : '❌'}');
      debugPrint('   Hata Sayısı: ${results['errors'].length}');
      
      if (results['errors'].isNotEmpty) {
        debugPrint('🔍 HATALAR:');
        for (int i = 0; i < results['errors'].length; i++) {
          debugPrint('   ${i + 1}. ${results['errors'][i]}');
        }
      }
      
      final allPassed = results['configSetup'] && 
                       results['configValidation'] && 
                       results['firebaseConnection'] && 
                       results['geminiApiConnection'] && 
                       results['testWordSearch'];
      
      debugPrint('═══════════════════════════════════════════════════════════════');
      debugPrint(allPassed ? '🎉 TÜM TESTLER BAŞARILI!' : '⚠️ BAZI TESTLER BAŞARISIZ!');
      debugPrint('═══════════════════════════════════════════════════════════════');
      
    } catch (e) {
      results['errors'].add('Critical test hatası: $e');
      debugPrint('❌ Critical test hatası: $e');
    }
    
    return results;
  }

  // UI'dan çağrılabilir test metodu
  static Future<String> runQuickTest() async {
    try {
      debugPrint('⚡ Quick Test Başlatılıyor...');
      
      final service = GeminiService();
      
      // Config debug
      await service.debugConfigStatus();
      
      // Basit test
      final testWord = 'سلام'; // "Selam" Arapça
      final result = await service.searchWord(testWord);
      
      if (result.bulunduMu) {
        return 'TEST BAŞARILI ✅\n\nTest Kelimesi: ${result.kelime}\nAnlam: ${result.anlam}\nHarekeli: ${result.harekeliKelime}';
      } else {
        return 'TEST BAŞARISIZ ❌\n\nHata: ${result.anlam}';
      }
      
    } catch (e) {
      return 'TEST HATASI ❌\n\nHata: $e';
    }
  }
} 