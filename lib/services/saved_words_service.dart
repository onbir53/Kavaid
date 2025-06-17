import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word_model.dart';

class SavedWordsService extends ChangeNotifier {
  // Singleton pattern
  static final SavedWordsService _instance = SavedWordsService._internal();
  factory SavedWordsService() => _instance;
  SavedWordsService._internal();

  // Database ve Cache için
  Database? _database;
  List<WordModel>? _cachedSavedWords;
  Set<String> _savedWordKeys = <String>{};
  bool _isInitialized = false;

  // Database'i aç veya oluştur
  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'kavaid_saved_words.db');
      
      print('DEBUG: Database path: $path');
      
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE saved_words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              kelime TEXT UNIQUE NOT NULL,
              word_data TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          print('DEBUG: Database tablosu oluşturuldu');
        },
      );
      
      print('DEBUG: Database başarıyla açıldı');
      return _database!;
    } catch (e) {
      print('DEBUG: Database açma hatası: $e');
      rethrow;
    }
  }

  // Kaydedilen kelimeleri getir
  Future<List<WordModel>> getSavedWords() async {
    try {
      // Cache varsa ve güncel ise onu döndür
      if (_cachedSavedWords != null && _isInitialized) {
        print('DEBUG: Cache\'den ${_cachedSavedWords!.length} kelime döndürülüyor');
        return _cachedSavedWords!;
      }

      final db = await _getDatabase();
      final List<Map<String, dynamic>> maps = await db.query(
        'saved_words',
        orderBy: 'created_at DESC', // En yeni en üstte
      );

      print('DEBUG: Database\'den ${maps.length} kayıt okundu');

      final savedWords = maps
          .map((map) {
            try {
              final wordData = jsonDecode(map['word_data'] as String);
              return WordModel.fromJson(wordData);
            } catch (e) {
              print('DEBUG: Kelime parse hatası: $e');
              return null;
            }
          })
          .where((word) => word != null)
          .cast<WordModel>()
          .toList();

      // Cache'i güncelle
      _cachedSavedWords = savedWords;
      _savedWordKeys = savedWords.map((word) => word.kelime).toSet();
      _isInitialized = true;

      print('DEBUG: ${savedWords.length} kelime başarıyla yüklendi (SQLite)');
      return savedWords;
    } catch (e) {
      print('DEBUG: getSavedWords hatası: $e');
      
      // Hata durumunda boş cache döndür
      _cachedSavedWords = [];
      _savedWordKeys.clear();
      _isInitialized = true;
      
      return [];
    }
  }

  // Kelime kaydet
  Future<bool> saveWord(WordModel word) async {
    try {
      print('DEBUG: Kelime kaydediliyor: ${word.kelime}');
      
      // Cache henüz yüklenmemişse yükle
      if (!_isInitialized) {
        await getSavedWords();
      }

      final db = await _getDatabase();
      
      // Eğer kelime zaten varsa, önce sil (en üste eklemek için)
      await db.delete(
        'saved_words',
        where: 'kelime = ?',
        whereArgs: [word.kelime],
      );

      // Yeni kelimeyi ekle
      await db.insert(
        'saved_words',
        {
          'kelime': word.kelime,
          'word_data': jsonEncode(word.toJson()),
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('DEBUG: Kelime database\'e kaydedildi');

      // Cache'i yenile
      final savedWords = _cachedSavedWords ?? [];
      savedWords.removeWhere((savedWord) => savedWord.kelime == word.kelime);
      savedWords.insert(0, word);
      
      _cachedSavedWords = savedWords;
      _savedWordKeys.add(word.kelime);

      // Tüm dinleyicileri bilgilendir
      notifyListeners();

      print('DEBUG: Kelime başarıyla kaydedildi (${savedWords.length} toplam)');
      return true;
    } catch (e) {
      print('DEBUG: Kelime kaydetme hatası: $e');
      return false;
    }
  }

  // Kelimeyi kayıtlılardan kaldır
  Future<bool> removeWord(WordModel word) async {
    try {
      print('DEBUG: Kelime kaldırılıyor: ${word.kelime}');
      
      // Cache henüz yüklenmemişse yükle
      if (!_isInitialized) {
        await getSavedWords();
      }

      final db = await _getDatabase();
      
      // Database'den sil
      final deletedCount = await db.delete(
        'saved_words',
        where: 'kelime = ?',
        whereArgs: [word.kelime],
      );

      print('DEBUG: Database\'den $deletedCount kayıt silindi');

      // Cache'den kaldır
      final savedWords = _cachedSavedWords ?? [];
      final initialLength = savedWords.length;
      savedWords.removeWhere((savedWord) => savedWord.kelime == word.kelime);
      
      _cachedSavedWords = savedWords;
      _savedWordKeys.remove(word.kelime);

      // Tüm dinleyicileri bilgilendir
      notifyListeners();

      print('DEBUG: Kelime başarıyla kaldırıldı (${savedWords.length} toplam)');
      return deletedCount > 0;
    } catch (e) {
      print('DEBUG: Kelime kaldırma hatası: $e');
      return false;
    }
  }

  // Kelime kayıtlı mı kontrol et (hızlı cache'den)
  bool isWordSavedSync(WordModel word) {
    return _savedWordKeys.contains(word.kelime);
  }

  // Kelime kayıtlı mı kontrol et (async - backward compatibility)
  Future<bool> isWordSaved(WordModel word) async {
    // Cache boşsa önce yükle
    if (!_isInitialized) {
      await getSavedWords();
    }
    
    return _savedWordKeys.contains(word.kelime);
  }

  // Tüm kayıtlı kelimeleri temizle
  Future<void> clearAllSavedWords() async {
    try {
      print('DEBUG: Tüm kayıtlı kelimeler temizleniyor');
      
      final db = await _getDatabase();
      
      // Database'i temizle
      await db.delete('saved_words');
      
      // Cache'i temizle
      _cachedSavedWords = [];
      _savedWordKeys.clear();
      
      // Tüm dinleyicileri bilgilendir
      notifyListeners();
      
      print('DEBUG: Tüm kayıtlı kelimeler başarıyla temizlendi');
    } catch (e) {
      print('DEBUG: Kayıtlı kelimeler temizleme hatası: $e');
    }
  }

  // İlk yükleme için
  Future<void> initialize() async {
    if (!_isInitialized) {
      print('DEBUG: SavedWordsService (SQLite) initialize ediliyor...');
      await getSavedWords();
      print('DEBUG: SavedWordsService (SQLite) initialize edildi');
    }
  }

  // Kaydedilen kelime sayısını al
  int get savedWordsCount => _cachedSavedWords?.length ?? 0;

  // Database durumunu kontrol et
  bool get isDatabaseReady => _database != null;
  
  // Initialization durumunu kontrol et
  bool get isInitialized => _isInitialized;
  
  // Test için cache'i sıfırla
  void resetForTesting() {
    _cachedSavedWords = null;
    _savedWordKeys.clear();
    _isInitialized = false;
  }

  // Database'i kapat (uygulamadan çıkarken)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('DEBUG: Database kapatıldı');
    }
  }
} 