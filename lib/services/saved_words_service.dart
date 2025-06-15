import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  // Kaydedilen kelimeleri getir
  Future<List<WordModel>> getSavedWords() async {
    try {
      // Şimdilik boş liste döndür (storage implementasyonu sonra)
      print('DEBUG: Storage boş - implementasyon sonra eklenecek');
      _cachedSavedWords = [];
      _savedWordKeys.clear();
      return [];
    } catch (e) {
      print('Kaydedilen kelimeler yüklenirken hata: $e');
      _cachedSavedWords = [];
      _savedWordKeys.clear();
      return [];
    }
  }

  // Kelime kaydet
  Future<bool> saveWord(WordModel word) async {
    try {
      print('DEBUG: Kelime kaydediliyor: ${word.kelime}');
      
      final savedWords = await getSavedWords();
      print('DEBUG: Mevcut kayıtlı kelime sayısı: ${savedWords.length}');
      
      // Eğer kelime zaten kayıtlıysa, önce kaldır (en üste eklemek için)
      savedWords.removeWhere((savedWord) => savedWord.kelime == word.kelime);
      
      // En başa ekle (en yeni en üstte)
      savedWords.insert(0, word);
      print('DEBUG: Yeni kayıtlı kelime sayısı: ${savedWords.length}');
      
      // Cache'i güncelle
      _cachedSavedWords = savedWords;
      _savedWordKeys.add(word.kelime);
      
      // Tüm dinleyicileri bilgilendir
      notifyListeners();
      
      print('DEBUG: Kelime cache\'e eklendi');
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
      
      final savedWords = await getSavedWords();
      print('DEBUG: Kaldırma öncesi kelime sayısı: ${savedWords.length}');
      
      // Kelimeyi listeden kaldır
      final initialLength = savedWords.length;
      savedWords.removeWhere((savedWord) => savedWord.kelime == word.kelime);
      
      print('DEBUG: Kaldırma sonrası kelime sayısı: ${savedWords.length}');
      print('DEBUG: Kelime kaldırıldı mı: ${initialLength != savedWords.length}');
      
      // Cache'i güncelle
      _cachedSavedWords = savedWords;
      _savedWordKeys.remove(word.kelime);
      
      // Tüm dinleyicileri bilgilendir
      notifyListeners();
      
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
    if (_cachedSavedWords == null) {
      await getSavedWords();
    }
    
    final isSaved = _savedWordKeys.contains(word.kelime);
    print('DEBUG: ${word.kelime} kayıtlı mı: $isSaved');
    return isSaved;
  }

  // Tüm kayıtlı kelimeleri temizle
  Future<void> clearAllSavedWords() async {
    try {
      print('DEBUG: Tüm kayıtlı kelimeler temizlendi');
      
      // Cache'i temizle
      _cachedSavedWords = [];
      _savedWordKeys.clear();
      
      // Tüm dinleyicileri bilgilendir
      notifyListeners();
    } catch (e) {
      print('Kayıtlı kelimeler temizlenirken hata: $e');
    }
  }

  // İlk yükleme için
  Future<void> initialize() async {
    await getSavedWords();
  }
} 