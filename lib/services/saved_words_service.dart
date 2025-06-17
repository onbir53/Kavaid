import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_model.dart';

class SavedWordsService extends ChangeNotifier {
  static const String _savedWordsKey = 'kavaid_saved_words';
  
  // Singleton pattern
  static final SavedWordsService _instance = SavedWordsService._internal();
  factory SavedWordsService() => _instance;
  SavedWordsService._internal();

  // Cache için
  List<WordModel>? _cachedSavedWords;
  Set<String> _savedWordKeys = <String>{};
  bool _isInitialized = false;
  bool _useCache = false; // SharedPreferences başarısız olursa cache kullan

  // Kaydedilen kelimeleri getir
  Future<List<WordModel>> getSavedWords() async {
    try {
      if (_useCache) {
        // SharedPreferences çalışmıyorsa cache'den dön
        print('DEBUG: Cache modunda çalışıyor');
        return _cachedSavedWords ?? [];
      }

      final prefs = await SharedPreferences.getInstance();
      final savedWordsJson = prefs.getStringList(_savedWordsKey) ?? [];
      
      final savedWords = savedWordsJson
          .map((json) {
            try {
              return WordModel.fromJson(jsonDecode(json));
            } catch (e) {
              print('Kelime parse hatası: $e');
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
      
      print('DEBUG: ${savedWords.length} kelime yüklendi');
      return savedWords;
    } catch (e) {
      print('SharedPreferences hatası: $e');
      print('DEBUG: Cache moduna geçiliyor');
      
      // SharedPreferences çalışmıyorsa cache moduna geç
      _useCache = true;
      _cachedSavedWords ??= [];
      _savedWordKeys.clear();
      _isInitialized = true;
      
      return _cachedSavedWords!;
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
      
      final savedWords = _cachedSavedWords ?? [];
      print('DEBUG: Mevcut kayıtlı kelime sayısı: ${savedWords.length}');
      
      // Eğer kelime zaten kayıtlıysa, önce kaldır (en üste eklemek için)
      savedWords.removeWhere((savedWord) => savedWord.kelime == word.kelime);
      
      // En başa ekle (en yeni en üstte)
      savedWords.insert(0, word);
      print('DEBUG: Yeni kayıtlı kelime sayısı: ${savedWords.length}');
      
      // SharedPreferences'a kaydet (sadece cache modunda değilse)
      if (!_useCache) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedWordsJson = savedWords
              .map((w) => jsonEncode(w.toJson()))
              .toList();
          
          await prefs.setStringList(_savedWordsKey, savedWordsJson);
          print('DEBUG: SharedPreferences\'a kaydedildi');
        } catch (e) {
          print('SharedPreferences kaydetme hatası: $e');
          print('DEBUG: Cache moduna geçiliyor');
          _useCache = true;
        }
      }
      
      // Cache'i güncelle
      _cachedSavedWords = savedWords;
      _savedWordKeys.add(word.kelime);
      
      // Tüm dinleyicileri bilgilendir
      notifyListeners();
      
      print('DEBUG: Kelime başarıyla kaydedildi');
      return true;
    } catch (e) {
      print('Kelime kaydedilirken hata: $e');
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
      
      final savedWords = _cachedSavedWords ?? [];
      print('DEBUG: Kaldırma öncesi kelime sayısı: ${savedWords.length}');
      
      // Kelimeyi listeden kaldır
      final initialLength = savedWords.length;
      savedWords.removeWhere((savedWord) => savedWord.kelime == word.kelime);
      
      print('DEBUG: Kaldırma sonrası kelime sayısı: ${savedWords.length}');
      print('DEBUG: Kelime kaldırıldı mı: ${initialLength != savedWords.length}');
      
      // SharedPreferences'ı güncelle (sadece cache modunda değilse)
      if (!_useCache) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedWordsJson = savedWords
              .map((w) => jsonEncode(w.toJson()))
              .toList();
          
          await prefs.setStringList(_savedWordsKey, savedWordsJson);
          print('DEBUG: SharedPreferences\'tan kaldırıldı');
        } catch (e) {
          print('SharedPreferences kaldırma hatası: $e');
          print('DEBUG: Cache moduna geçiliyor');
          _useCache = true;
        }
      }
      
      // Cache'i güncelle
      _cachedSavedWords = savedWords;
      _savedWordKeys.remove(word.kelime);
      
      // Tüm dinleyicileri bilgilendir
      notifyListeners();
      
      print('DEBUG: Kelime başarıyla kaldırıldı');
      return true;
    } catch (e) {
      print('Kelime kaldırılırken hata: $e');
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
    
    final isSaved = _savedWordKeys.contains(word.kelime);
    print('DEBUG: ${word.kelime} kayıtlı mı: $isSaved');
    return isSaved;
  }

  // Tüm kayıtlı kelimeleri temizle
  Future<void> clearAllSavedWords() async {
    try {
      print('DEBUG: Tüm kayıtlı kelimeler temizleniyor');
      
      // SharedPreferences'ı temizle (sadece cache modunda değilse)
      if (!_useCache) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_savedWordsKey);
          print('DEBUG: SharedPreferences temizlendi');
        } catch (e) {
          print('SharedPreferences temizleme hatası: $e');
          print('DEBUG: Cache moduna geçiliyor');
          _useCache = true;
        }
      }
      
      // Cache'i temizle
      _cachedSavedWords = [];
      _savedWordKeys.clear();
      
      // Tüm dinleyicileri bilgilendir
      notifyListeners();
      
      print('DEBUG: Tüm kayıtlı kelimeler başarıyla temizlendi');
    } catch (e) {
      print('Kayıtlı kelimeler temizlenirken hata: $e');
    }
  }

  // İlk yükleme için
  Future<void> initialize() async {
    if (!_isInitialized) {
      await getSavedWords();
    }
  }

  // Cache durumunu kontrol et
  bool get isUsingCache => _useCache;
  
  // Test için cache'i sıfırla
  void resetForTesting() {
    _cachedSavedWords = null;
    _savedWordKeys.clear();
    _isInitialized = false;
    _useCache = false;
  }
} 