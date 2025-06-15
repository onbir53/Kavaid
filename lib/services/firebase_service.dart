import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/word_model.dart';

class FirebaseService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final DatabaseReference _wordsRef = _database.ref().child('kelimeler');

  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Cache için
  static Map<String, List<WordModel>>? _cachedData;
  static DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  // Cache'i temizle
  static void clearCache() {
    _cachedData = null;
    _lastCacheTime = null;
    debugPrint('🗑️ Cache temizlendi');
  }

  // Helper fonksiyonlar - Type casting için
  static Map<String, dynamic>? _safeCastMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
    }
    return null;
  }

  static List<Map<String, dynamic>>? _safeCastList(dynamic value) {
    if (value == null) return null;
    if (value is List<Map<String, dynamic>>) return value;
    if (value is List) {
      return value.map((item) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) {
          return Map<String, dynamic>.from(item.map((k, v) => MapEntry(k.toString(), v)));
        }
        return <String, dynamic>{};
      }).toList();
    }
    return null;
  }

  // Kelime arama - HomeScreen için (hızlandırılmış)
  Future<List<WordModel>> searchWords(String query) async {
    return await searchWordsInDatabase(query);
  }

  // Hızlandırılmış kelime arama
  Future<List<WordModel>> searchWordsInDatabase(String query) async {
    if (query.isEmpty) return [];

    try {
      // Cache kontrolü - Yeni kelime eklendiğinde cache'i atla
      final now = DateTime.now();
      if (_cachedData != null && 
          _lastCacheTime != null && 
          now.difference(_lastCacheTime!).compareTo(_cacheTimeout) < 0) {
        debugPrint('📦 Cache\'den arama yapılıyor');
        return _searchInCache(query);
      }
      
      debugPrint('🔍 Firebase\'den fresh arama yapılıyor');

      final snapshot = await _wordsRef.get();
      
      if (!snapshot.exists) return [];

      final data = snapshot.value as Map<dynamic, dynamic>;
      final words = <WordModel>[];
      final results = <WordModel>[];

      // Yeni yapıya göre parsing ve arama
      for (final entry in data.entries) {
        try {
          final key = entry.key.toString(); // Harekeli kelime key olarak
          final value = entry.value;
          
          if (value != null && value is Map) {
            final wordData = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
            
            // Yeni yapıya uygun WordModel oluştur
            WordModel word;
            if (wordData.containsKey('kelimeBilgisi')) {
              // Eski format uyumluluğu
              word = WordModel.fromJson(wordData);
            } else {
              // Yeni format - direkt kelime bilgileri
              word = WordModel(
                kelime: wordData['kelime'] ?? key,
                harekeliKelime: wordData['harekeliKelime'] ?? key,
                anlam: wordData['anlam'],
                koku: wordData['koku'],
                dilbilgiselOzellikler: _safeCastMap(wordData['dilbilgiselOzellikler']),
                ornekCumleler: _safeCastList(wordData['ornekCumleler']),
                fiilCekimler: _safeCastMap(wordData['fiilCekimler']),
                eklenmeTarihi: wordData['eklenmeTarihi'],
                bulunduMu: true,
              );
            }
            
            words.add(word);
            
            // Hızlı arama - sadece başlangıç eşleşmelerini kontrol et
            final lowerQuery = query.toLowerCase();
            final lowerKelime = word.kelime.toLowerCase();
            final lowerHarekeli = word.harekeliKelime?.toLowerCase() ?? '';
            final lowerAnlam = word.anlam?.toLowerCase() ?? '';
            final lowerKey = key.toLowerCase(); // Key'i de kontrol et
            
            if (lowerKelime.startsWith(lowerQuery) || 
                lowerHarekeli.startsWith(lowerQuery) ||
                lowerKey.startsWith(lowerQuery) ||
                lowerAnlam.contains(lowerQuery)) {
              results.add(word);
              
              // Erken çıkış - 15 sonuç bulunca dur
              if (results.length >= 15) break;
            }
          }
        } catch (e) {
          debugPrint('Kelime parse hatası: $e');
          // Hata durumunda devam et
          continue;
        }
      }

      // Cache'i güncelle
      _cachedData = {'all': words};
      _lastCacheTime = now;

      // Hızlı sıralama - sadece score hesapla
      results.sort((a, b) => 
        b.searchScore(query).compareTo(a.searchScore(query)));

      return results;
    } catch (e) {
      print('Firebase arama hatası: $e');
      return [];
    }
  }

  // Cache'de arama
  List<WordModel> _searchInCache(String query) {
    if (_cachedData == null) return [];
    
    final allWords = _cachedData!['all'] ?? [];
    final results = <WordModel>[];
    final lowerQuery = query.toLowerCase();

    for (final word in allWords) {
      final lowerKelime = word.kelime.toLowerCase();
      final lowerHarekeli = word.harekeliKelime?.toLowerCase() ?? '';
      final lowerAnlam = word.anlam?.toLowerCase() ?? '';
      
      if (lowerKelime.startsWith(lowerQuery) || 
          lowerHarekeli.startsWith(lowerQuery) ||
          lowerAnlam.contains(lowerQuery)) {
        results.add(word);
        
        if (results.length >= 15) break;
      }
    }

    results.sort((a, b) => 
      b.searchScore(query).compareTo(a.searchScore(query)));

    return results;
  }

  // Öneriler için hızlı arama (debounce ile her harf girişinde)
  Stream<List<WordModel>> getSuggestions(String query) {
    if (query.isEmpty) {
      return Stream.value([]);
    }

    return _wordsRef
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <WordModel>[];

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final suggestions = <WordModel>[];

      data.forEach((key, value) {
        try {
          final keyStr = key.toString(); // Harekeli kelime key olarak
          
          if (value != null && value is Map) {
            final wordData = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
            
            // Yeni yapıya uygun WordModel oluştur
            WordModel word;
            if (wordData.containsKey('kelimeBilgisi')) {
              // Eski format uyumluluğu
              word = WordModel.fromJson(wordData);
            } else {
              // Yeni format - direkt kelime bilgileri
              word = WordModel(
                kelime: wordData['kelime'] ?? keyStr,
                harekeliKelime: wordData['harekeliKelime'] ?? keyStr,
                anlam: wordData['anlam'],
                koku: wordData['koku'],
                dilbilgiselOzellikler: _safeCastMap(wordData['dilbilgiselOzellikler']),
                ornekCumleler: _safeCastList(wordData['ornekCumleler']),
                fiilCekimler: _safeCastMap(wordData['fiilCekimler']),
                eklenmeTarihi: wordData['eklenmeTarihi'],
                bulunduMu: true,
              );
            }
            
            // Kelime veya harekeli kelime ile başlayanlara öncelik ver
            final kelimeMatch = word.kelime.toLowerCase().startsWith(query.toLowerCase());
            final harekeliMatch = word.harekeliKelime?.toLowerCase().startsWith(query.toLowerCase()) ?? false;
            final keyMatch = keyStr.toLowerCase().startsWith(query.toLowerCase());
            final anlamMatch = word.anlam?.toLowerCase().contains(query.toLowerCase()) ?? false;
            
            if (kelimeMatch || harekeliMatch || keyMatch || anlamMatch) {
              suggestions.add(word);
            }
          }
        } catch (e) {
          debugPrint('Öneri parse hatası: $e');
        }
      });

      // Arama skoruna göre sırala ve sınırla
      suggestions.sort((a, b) => 
        b.searchScore(query).compareTo(a.searchScore(query)));

      return suggestions.take(5).toList();
    });
  }

  // Yeni kelime kaydet
  Future<bool> saveWord(WordModel word) async {
    try {
      // Sadece bulunmuş kelimeleri kaydet
      if (!word.bulunduMu) return false;

      // Kelime zaten var mı kontrol et
      final existingWord = await getWordByName(word.kelime);
      if (existingWord != null) {
        print('Kelime zaten mevcut: ${word.kelime}');
        return true;
      }

      // Yeni kelime ID'si oluştur
      final newWordRef = _wordsRef.push();
      
      // Firebase'e kaydet
      await newWordRef.set(word.toFirebaseJson());
      
      // Cache'i temizle - yeni kelime eklendiği için
      clearCache();
      
      print('Kelime kaydedildi: ${word.kelime}');
      return true;
    } catch (e) {
      print('Kelime kaydetme hatası: $e');
      return false;
    }
  }

  // Kelimeyi isimle getir
  Future<WordModel?> getWordByName(String wordName) async {
    try {
      final snapshot = await _wordsRef.get();
      
      if (!snapshot.exists) return null;

      final data = snapshot.value as Map<dynamic, dynamic>;
      
      // Tüm kelimeleri kontrol et
      for (final entry in data.entries) {
        try {
          final key = entry.key.toString(); // Harekeli kelime key olarak
          final value = entry.value;
          
          if (value != null && value is Map) {
            final wordData = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
            
            // Yeni yapıya uygun WordModel oluştur
            WordModel word;
            if (wordData.containsKey('kelimeBilgisi')) {
              // Eski format uyumluluğu
              word = WordModel.fromJson(wordData);
            } else {
              // Yeni format - direkt kelime bilgileri
              word = WordModel(
                kelime: wordData['kelime'] ?? key,
                harekeliKelime: wordData['harekeliKelime'] ?? key,
                anlam: wordData['anlam'],
                koku: wordData['koku'],
                dilbilgiselOzellikler: _safeCastMap(wordData['dilbilgiselOzellikler']),
                ornekCumleler: _safeCastList(wordData['ornekCumleler']),
                fiilCekimler: _safeCastMap(wordData['fiilCekimler']),
                eklenmeTarihi: wordData['eklenmeTarihi'],
                bulunduMu: true,
              );
            }
            
            // Kelime, harekeli kelime veya key tam eşleşmesi
            if (word.kelime.toLowerCase() == wordName.toLowerCase() ||
                word.harekeliKelime?.toLowerCase() == wordName.toLowerCase() ||
                key.toLowerCase() == wordName.toLowerCase()) {
              return word;
            }
          }
        } catch (e) {
          debugPrint('Kelime kontrol hatası: $e');
        }
      }
      
      return null;
    } catch (e) {
      print('Kelime getirme hatası: $e');
      return null;
    }
  }

  // Son eklenen kelimeleri getir
  Future<List<WordModel>> getRecentWords({int limit = 10}) async {
    try {
      final snapshot = await _wordsRef.get();

      if (!snapshot.exists) return [];

      final data = snapshot.value as Map<dynamic, dynamic>;
      final words = <WordModel>[];

      data.forEach((key, value) {
        try {
          final keyStr = key.toString(); // Harekeli kelime key olarak
          
          if (value != null && value is Map) {
            final wordData = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
            
            // Yeni yapıya uygun WordModel oluştur
            WordModel word;
            if (wordData.containsKey('kelimeBilgisi')) {
              // Eski format uyumluluğu
              word = WordModel.fromJson(wordData);
            } else {
              // Yeni format - direkt kelime bilgileri
              word = WordModel(
                kelime: wordData['kelime'] ?? keyStr,
                harekeliKelime: wordData['harekeliKelime'] ?? keyStr,
                anlam: wordData['anlam'],
                koku: wordData['koku'],
                dilbilgiselOzellikler: _safeCastMap(wordData['dilbilgiselOzellikler']),
                ornekCumleler: _safeCastList(wordData['ornekCumleler']),
                fiilCekimler: _safeCastMap(wordData['fiilCekimler']),
                eklenmeTarihi: wordData['eklenmeTarihi'],
                bulunduMu: true,
              );
            }
            
            words.add(word);
          }
        } catch (e) {
          debugPrint('Son kelime parse hatası: $e');
        }
      });

      // Ekleme tarihine göre sırala (en yeni önce)
      words.sort((a, b) {
        final aTime = a.eklenmeTarihi ?? 0;
        final bTime = b.eklenmeTarihi ?? 0;
        return bTime.compareTo(aTime);
      });

      return words.take(limit).toList();
    } catch (e) {
      print('Son kelimeler getirme hatası: $e');
      return [];
    }
  }

  // Toplam kelime sayısını getir
  Future<int> getTotalWordCount() async {
    try {
      final snapshot = await _wordsRef.get();
      if (!snapshot.exists) return 0;
      
      final data = snapshot.value as Map<dynamic, dynamic>;
      return data.length;
    } catch (e) {
      print('Kelime sayısı getirme hatası: $e');
      return 0;
    }
  }

  // Database bağlantısını test et
  Future<bool> testConnection() async {
    try {
      await _wordsRef.limitToFirst(1).get();
      return true;
    } catch (e) {
      print('Firebase bağlantı testi hatası: $e');
      return false;
    }
  }

  // Database'den rastgele kelime getir
  Future<List<WordModel>> getRandomWords({int count = 5}) async {
    try {
      final snapshot = await _wordsRef.limitToFirst(20).get();

      if (!snapshot.exists) return [];

      final data = snapshot.value as Map<dynamic, dynamic>;
      final words = <WordModel>[];

      data.forEach((key, value) {
        try {
          final keyStr = key.toString(); // Harekeli kelime key olarak
          
          if (value != null && value is Map) {
            final wordData = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
            
            // Yeni yapıya uygun WordModel oluştur
            WordModel word;
            if (wordData.containsKey('kelimeBilgisi')) {
              // Eski format uyumluluğu
              word = WordModel.fromJson(wordData);
            } else {
              // Yeni format - direkt kelime bilgileri
              word = WordModel(
                kelime: wordData['kelime'] ?? keyStr,
                harekeliKelime: wordData['harekeliKelime'] ?? keyStr,
                anlam: wordData['anlam'],
                koku: wordData['koku'],
                dilbilgiselOzellikler: _safeCastMap(wordData['dilbilgiselOzellikler']),
                ornekCumleler: _safeCastList(wordData['ornekCumleler']),
                fiilCekimler: _safeCastMap(wordData['fiilCekimler']),
                eklenmeTarihi: wordData['eklenmeTarihi'],
                bulunduMu: true,
              );
            }
            
            words.add(word);
          }
        } catch (e) {
          debugPrint('Rastgele kelime parse hatası: $e');
        }
      });

      // Karıştır ve istenilen sayıda döndür
      words.shuffle();
      return words.take(count).toList();
    } catch (e) {
      print('Rastgele kelimeler getirme hatası: $e');
      return [];
    }
  }
} 