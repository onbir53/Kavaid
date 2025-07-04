import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import '../models/word_model.dart';
import 'firebase_service.dart';

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

  // Firebase Realtime Database'den API anahtarını al (her seferinde fresh)
  Future<String> _getApiKey() async {
    try {
      debugPrint('🔑 Firebase\'den API anahtarı alınıyor...');
      
      final database = FirebaseDatabase.instance;
      final configRef = database.ref('config/gemini_api');
      
      final snapshot = await configRef.get();
      
      String apiKey = _defaultApiKey;
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value.toString().trim();
        if (value.isNotEmpty && value != 'null' && value != _defaultApiKey) {
          apiKey = value;
          debugPrint('✅ FIREBASE API KEY: ${value.substring(0, 15)}...${value.substring(value.length - 5)}');
        } else {
          debugPrint('⚠️ Firebase API key boş veya default, varsayılan kullanılıyor');
          apiKey = _defaultApiKey;
        }
      } else {
        debugPrint('⚠️ Firebase\'de config/gemini_api bulunamadı, varsayılan kullanılıyor');
        apiKey = _defaultApiKey;
      }
      
      debugPrint('🔧 KULLANILAN API KEY: ${apiKey.substring(0, 15)}...${apiKey.substring(apiKey.length - 5)}');
      return apiKey;
      
    } catch (e) {
      debugPrint('❌ Firebase API key hatası, varsayılan kullanılıyor: $e');
      return _defaultApiKey;
    }
  }

  // Firebase'den Gemini model bilgisini al
  Future<String> _getModel() async {
    try {
      final database = FirebaseDatabase.instance;
      final configRef = database.ref('config/gemini_model');
      
      final snapshot = await configRef.get();
      
      String model = _defaultModel;
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value.toString().trim();
        if (value.isNotEmpty && value != 'null') {
          model = value;
          debugPrint('✅ FIREBASE MODEL: $value');
        } else {
          debugPrint('⚠️ Firebase model boş, varsayılan kullanılıyor');
          model = _defaultModel;
        }
      } else {
        debugPrint('⚠️ Firebase\'de model bulunamadı, varsayılan kullanılıyor');
        model = _defaultModel;
      }
      
      debugPrint('🔧 KULLANILAN MODEL: $model');
      return model;
      
    } catch (e) {
      debugPrint('❌ Firebase model hatası, varsayılan kullanılıyor: $e');
      return _defaultModel;
    }
  }

  // Firebase'den Gemini prompt'unu al
  Future<String> _getPrompt() async {
    try {
      final database = FirebaseDatabase.instance;
      final configRef = database.ref('config/gemini_prompt');
      
      final snapshot = await configRef.get();
      
      String prompt = _defaultPrompt;
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value.toString();
        if (value.isNotEmpty && value.length > 100) {
          prompt = value;
          debugPrint('✅ FIREBASE PROMPT: ${value.length} karakter');
        } else {
          debugPrint('⚠️ Firebase prompt çok kısa veya boş, varsayılan kullanılıyor');
          prompt = _defaultPrompt;
        }
      } else {
        debugPrint('⚠️ Firebase\'de prompt bulunamadı, varsayılan kullanılıyor');
        prompt = _defaultPrompt;
      }
      
      debugPrint('🔧 KULLANILAN PROMPT: ${prompt.length} karakter');
      return prompt;
      
    } catch (e) {
      debugPrint('❌ Firebase prompt hatası, varsayılan kullanılıyor: $e');
      return _defaultPrompt;
    }
  }

  // Config alanını database'de oluştur
  Future<void> _createConfigInDatabase() async {
    try {
      debugPrint('🔧 Database\'de config alanı kontrol ediliyor...');
      
      final database = FirebaseDatabase.instance;
      final configRef = database.ref('config');
      
      // Önce var mı kontrol et
      final snapshot = await configRef.get();
      if (snapshot.exists) {
        debugPrint('✅ Config alanı zaten mevcut, değiştirilmeyecek');
        return;
      }
      
      // Yoksa oluştur
      await configRef.set({
        'gemini_api': _defaultApiKey,
        'gemini_model': _defaultModel,
        'gemini_prompt': _defaultPrompt,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'note': 'Bu alanları Firebase Console\'dan düzenleyebilirsiniz'
      });
      
      debugPrint('✅ Config alanı başarıyla oluşturuldu');
    } catch (e) {
      debugPrint('❌ Config alanı oluşturulamadı: $e');
    }
  }

  // API anahtarını manuel refresh et (artık her seferinde fresh alındığı için sadece log)
  void clearApiKeyCache() {
    debugPrint('🔄 API anahtarı bir sonraki istekte Firebase\'den fresh alınacak');
  }

  // Kelime analizi - HomeScreen için
  Future<WordModel?> analyzeWord(String word) async {
    try {
      debugPrint('🔍 Kelime analiz ediliyor: $word');
      
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
      
      // Önce Firebase'de kelime var mı kontrol et
      final firebaseService = FirebaseService();
      final existingWord = await firebaseService.getWordByName(word);
      
      if (existingWord != null) {
        debugPrint('📦 Kelime zaten veritabanında mevcut: ${existingWord.kelime}');
        return existingWord;
      }
      
      debugPrint('🤖 Kelime veritabanında bulunamadı, Gemini API\'ye istek atılıyor: $word');
      
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
      
      final database = FirebaseDatabase.instance;
      final configRef = database.ref('config');
      
      // Önce var mı kontrol et
      final snapshot = await configRef.get();
      if (snapshot.exists) {
        debugPrint('✅ Config alanı zaten mevcut, üzerine yazılmayacak');
        return;
      }
      
      // Yoksa oluştur
      await configRef.set({
        'gemini_api': _defaultApiKey,
        'gemini_model': _defaultModel,
        'gemini_prompt': _defaultPrompt,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'note': 'Bu alanları Firebase Console\'dan düzenleyebilirsiniz - Manuel oluşturuldu'
      });
      
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
} 