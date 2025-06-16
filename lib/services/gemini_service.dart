import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import '../models/word_model.dart';
import 'firebase_service.dart';

class GeminiService {
  static const String _defaultApiKey = 'AIzaSyCbAR_1yQ2QVKbpyWRFj0VpOxAQZ2JBfas';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent';

  // Singleton pattern
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  // Firebase Realtime Database'den API anahtarını al (her seferinde fresh)
  Future<String> _getApiKey() async {
    try {
      debugPrint('🔑 Firebase Realtime Database\'den API anahtarı alınıyor...');
      
      final database = FirebaseDatabase.instance;
      final configRef = database.ref('config/gemini_api');
      
      final snapshot = await configRef.get();
      
      String apiKey = _defaultApiKey;
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value.toString().trim();
        if (value.isNotEmpty) {
          apiKey = value;
          debugPrint('✅ API anahtarı Realtime Database\'den alındı: ${value.substring(0, 10)}...');
        } else {
          debugPrint('⚠️ Database\'deki API anahtarı boş, varsayılan kullanılıyor');
        }
      } else {
        debugPrint('⚠️ Database\'de config/gemini_api bulunamadı, oluşturuluyor...');
        
        // Config alanını otomatik oluştur
        await _createConfigInDatabase();
        apiKey = _defaultApiKey;
      }
      
      return apiKey;
      
    } catch (e) {
      debugPrint('⚠️ Realtime Database hatası, varsayılan API anahtarı kullanılıyor: $e');
      return _defaultApiKey;
    }
  }

  // Config alanını database'de oluştur
  Future<void> _createConfigInDatabase() async {
    try {
      debugPrint('🔧 Database\'de config alanı oluşturuluyor...');
      
      final database = FirebaseDatabase.instance;
      final configRef = database.ref('config');
      
      await configRef.set({
        'gemini_api': _defaultApiKey,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'note': 'Bu alanı Firebase Console\'dan düzenleyebilirsiniz'
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
      
      // Firebase'de bulunamadıysa null döndür - AI çağrısı yapmayız
      debugPrint('❌ Kelime veritabanında bulunamadı, analiz yapılamıyor: $word');
      return null;
    } catch (e) {
      debugPrint('Analiz hatası: $e');
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
      
      // API anahtarını dinamik olarak al
      final apiKey = await _getApiKey();
      final url = Uri.parse('$_baseUrl?key=$apiKey');
      
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': _buildPrompt(word),
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.0,
          'maxOutputTokens': 2048,
          'thinkingConfig': {
            'thinkingBudget': 0
          },
        }
      };

      debugPrint('📤 İstek gönderiliyor...');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      debugPrint('📥 Yanıt alındı - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('🔍 API Yanıt Yapısı: ${data.keys.toList()}');
        
        // Candidates kontrolü
        if (data['candidates'] == null) {
          debugPrint('❌ Candidates null - Tam yanıt: ${response.body}');
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
        debugPrint('🔍 Candidate yapısı: ${candidate.keys.toList()}');
        debugPrint('🔍 Candidate içeriği: $candidate');
        
        // finishReason kontrolü
        final finishReason = candidate['finishReason'];
        if (finishReason == 'MAX_TOKENS') {
          debugPrint('⚠️ Token limiti aşıldı, yanıt kesildi');
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'Yanıt çok uzun, token limiti aşıldı',
          );
        }
        
        if (finishReason == 'SAFETY') {
          debugPrint('⚠️ Güvenlik filtreleri devreye girdi');
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'İçerik güvenlik filtreleri tarafından bloklandı',
          );
        }
        
        if (candidate['content'] == null) {
          debugPrint('❌ Content null');
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'API yanıtında content bulunamadı',
          );
        }
        
        debugPrint('🔍 Content yapısı: ${candidate['content'].keys.toList()}');
        debugPrint('🔍 Content içeriği: ${candidate['content']}');
        
        if (candidate['content']['parts'] == null || candidate['content']['parts'].isEmpty) {
          debugPrint('❌ Parts null veya boş');
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'API yanıtında metin içeriği bulunamadı',
          );
        }
        
        debugPrint('🔍 Parts uzunluğu: ${candidate['content']['parts'].length}');
        debugPrint('🔍 İlk part: ${candidate['content']['parts'][0]}');
        
        final content = candidate['content']['parts'][0]['text'];
        if (content == null || content.toString().trim().isEmpty) {
          debugPrint('❌ Text içeriği boş');
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'API yanıtında metin içeriği bulunamadı',
          );
        }
        
        debugPrint('✅ İçerik alındı: ${content.length > 500 ? content.substring(0, 500) + "..." : content}');
        
        // JSON'u temizle ve parse et
        final cleanedJson = _cleanJsonResponse(content);
        debugPrint('🧹 Temizlenmiş JSON uzunluğu: ${cleanedJson.length}');
        
        try {
          final wordData = json.decode(cleanedJson);
          final wordModel = WordModel.fromJson(wordData);
          
          // Eğer kelime bulunduysa Firebase'e kaydet
          if (wordData['bulunduMu'] == true && wordData['kelimeBilgisi'] != null) {
            await _saveToFirebase(wordData['kelimeBilgisi']);
          }
          
          return wordModel;
        } catch (jsonError) {
          debugPrint('❌ JSON parse hatası: $jsonError');
          debugPrint('🔍 Problematik JSON: $cleanedJson');
          
          // JSON parse hatası durumunda fallback
          return WordModel(
            kelime: word,
            bulunduMu: false,
            anlam: 'JSON parse hatası oluştu',
          );
        }
      } else {
        debugPrint('❌ API Hatası - Status: ${response.statusCode}');
        debugPrint('❌ API Hatası - Body: ${response.body}');
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

  String _buildPrompt(String word) {
    return '''YAPAY ZEKA İÇİN GÜNCEL VE KESİN TALİMATLAR

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

Kelime: "$word"

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
        "arapcaCümle": "أَرْسَلْتُ تَهْنِئَةً بِالنَّجَاحِ.",
        "turkceAnlam": "Başarı için tebrik mesajı gönderdim."
      },
      {
        "arapcaCümle": "تَلَقَّيْتُ تَهْنِئَةً بِالْعِيدِ.",
        "turkceAnlam": "Bayram tebriği aldım."
      }
    ],
    "fiilCekimler": {
      "maziForm": "هَنَّأَ",
      "muzariForm": "يُهَنِّئُ",
      "mastarForm": "تَهْنِئَةٌ",
      "emirForm": "هَنِّئْ"
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
      
      debugPrint('🔧 Final cleaned JSON: $cleaned');
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
} 