import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/word_model.dart';

class GeminiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview';
  static const String _apiKey = 'YOUR_GEMINI_API_KEY'; // Buraya API Key'inizi ekleyin

  // Singleton pattern
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  // Kelime analizi - HomeScreen için
  Future<WordModel?> analyzeWord(String word) async {
    try {
      final result = await searchWord(word);
      return result.bulunduMu ? result : null;
    } catch (e) {
      print('Analiz hatası: $e');
      return null;
    }
  }

  Future<WordModel> searchWord(String word) async {
    try {
      final prompt = _buildPrompt(word);
      final response = await _makeRequest(prompt);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];
        
        // JSON'u temizle ve parse et
        final cleanedJson = _cleanJsonResponse(content);
        final wordData = json.decode(cleanedJson);
        
        return WordModel.fromJson(wordData);
      } else {
        throw Exception('API Hatası: ${response.statusCode}');
      }
    } catch (e) {
      // Hata durumunda boş kelime modeli döndür
      return WordModel(
        kelime: word,
        bulunduMu: false,
        anlam: 'Kelime bulunamadı veya API hatası: ${e.toString()}',
      );
    }
  }

  String _buildPrompt(String word) {
    return '''
Aşağıdaki kelimeyi Arapça sözlük formatında analiz et ve JSON formatında döndür:

Kelime: "$word"

Lütfen aşağıdaki JSON formatında yanıt ver:

{
  "kelime": "aranan kelime",
  "harekeliYazi": "Arapça harekeli yazılış (varsa)",
  "anlam": "Türkçe anlamı (detaylı)",
  "kok": "Kelime kökü (Arapça)",
  "kelimeTuru": "isim/fiil/sıfat/zarf/edat/zamir/ünlem vb.",
  "cogulFormu": "çoğul formu (varsa)",
  "bulunduMu": true/false (kelime bulundu mu?),
  "ornekler": [
    {
      "arapcaCumle": "Arapça örnek cümle",
      "turkceCeviri": "Türkçe çevirisi"
    }
  ],
  "fiilCekimi": {
    "mazi": "geçmiş zaman (varsa)",
    "muzari": "şimdiki/gelecek zaman (varsa)", 
    "mastar": "mastar formu (varsa)",
    "emir": "emir kipi (varsa)"
  },
  "ek": "Ek bilgiler, etimoloji, özel kullanımlar vb."
}

ÖNEMLI KURALLAR:
1. Sadece JSON formatında yanıt ver, başka metin ekleme
2. Eğer kelime Arapça değilse veya bulunamadıysa "bulunduMu": false yap
3. Türkçe kelime ise Arapça karşılığını bul
4. Fiiller için mutlaka çekim bilgilerini ekle
5. En az 1-2 örnek cümle ver
6. Harekeliyi doğru şekilde yaz
7. Anlamı detaylı ve açıklayıcı yap
''';
  }

  Future<http.Response> _makeRequest(String prompt) async {
    final url = Uri.parse('$_baseUrl:generateContent?key=$_apiKey');
    
    final headers = {
      'Content-Type': 'application/json',
    };

    final body = json.encode({
      'contents': [
        {
          'parts': [
            {
              'text': prompt,
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0, // Tutarlı sonuçlar için
        'maxOutputTokens': 1024,
        'topP': 1,
        'topK': 1,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        }
      ]
    });

    return await http.post(url, headers: headers, body: body);
  }

  String _cleanJsonResponse(String response) {
    // Markdown formatını temizle
    String cleaned = response.replaceAll('```json', '').replaceAll('```', '');
    
    // Başlangıç ve bitiş boşluklarını temizle
    cleaned = cleaned.trim();
    
    // Eğer JSON başlangıcı yoksa, ilk { işaretini bul
    final startIndex = cleaned.indexOf('{');
    final endIndex = cleaned.lastIndexOf('}');
    
    if (startIndex != -1 && endIndex != -1) {
      cleaned = cleaned.substring(startIndex, endIndex + 1);
    }
    
    return cleaned;
  }

  // API Key kontrolü
  bool get isConfigured => _apiKey != 'YOUR_GEMINI_API_KEY';
} 