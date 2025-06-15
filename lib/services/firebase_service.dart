import 'package:firebase_database/firebase_database.dart';
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

  // Kelime arama - HomeScreen için (hızlandırılmış)
  Future<List<WordModel>> searchWords(String query) async {
    return await searchWordsInDatabase(query);
  }

  // Hızlandırılmış kelime arama
  Future<List<WordModel>> searchWordsInDatabase(String query) async {
    if (query.isEmpty) return [];

    try {
      // Cache kontrolü
      final now = DateTime.now();
      if (_cachedData != null && 
          _lastCacheTime != null && 
          now.difference(_lastCacheTime!).compareTo(_cacheTimeout) < 0) {
        return _searchInCache(query);
      }

      final snapshot = await _wordsRef.get();
      
      if (!snapshot.exists) return [];

      final data = snapshot.value as Map<dynamic, dynamic>;
      final words = <WordModel>[];
      final results = <WordModel>[];

      // Hızlı parsing ve arama
      for (final entry in data.entries) {
        try {
          if (entry.value != null && entry.value is Map) {
            final wordData = Map<String, dynamic>.from(entry.value.map((k, v) => MapEntry(k.toString(), v)));
            final word = WordModel.fromJson(wordData);
            words.add(word);
            
            // Hızlı arama - sadece başlangıç eşleşmelerini kontrol et
            final lowerQuery = query.toLowerCase();
            final lowerKelime = word.kelime.toLowerCase();
            final lowerHarekeli = word.harekeliKelime?.toLowerCase() ?? '';
            final lowerAnlam = word.anlam?.toLowerCase() ?? '';
            
            if (lowerKelime.startsWith(lowerQuery) || 
                lowerHarekeli.startsWith(lowerQuery) ||
                lowerAnlam.contains(lowerQuery)) {
              results.add(word);
              
              // Erken çıkış - 15 sonuç bulunca dur
              if (results.length >= 15) break;
            }
          }
        } catch (e) {
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
          if (value != null && value is Map) {
            final wordData = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
            final word = WordModel.fromJson(wordData);
            
            // Kelime veya harekeli kelime ile başlayanlara öncelik ver
            final kelimeMatch = word.kelime.toLowerCase().startsWith(query.toLowerCase());
            final harekeliMatch = word.harekeliKelime?.toLowerCase().startsWith(query.toLowerCase()) ?? false;
            final anlamMatch = word.anlam?.toLowerCase().contains(query.toLowerCase()) ?? false;
            
            if (kelimeMatch || harekeliMatch || anlamMatch) {
              suggestions.add(word);
            }
          }
        } catch (e) {
          print('Öneri parse hatası: $e');
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
          if (entry.value != null && entry.value is Map) {
            final wordData = Map<String, dynamic>.from(entry.value.map((k, v) => MapEntry(k.toString(), v)));
            final word = WordModel.fromJson(wordData);
            
            // Kelime veya harekeli kelime tam eşleşmesi
            if (word.kelime.toLowerCase() == wordName.toLowerCase() ||
                word.harekeliKelime?.toLowerCase() == wordName.toLowerCase()) {
              return word;
            }
          }
        } catch (e) {
          print('Kelime kontrol hatası: $e');
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
          if (value != null && value is Map) {
            final wordData = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
            final word = WordModel.fromJson(wordData);
            words.add(word);
          }
        } catch (e) {
          print('Son kelime parse hatası: $e');
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
          if (value != null && value is Map) {
            final wordData = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
            final word = WordModel.fromJson(wordData);
            words.add(word);
          }
        } catch (e) {
          print('Rastgele kelime parse hatası: $e');
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