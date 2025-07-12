// kavaid/lib/services/sync_service.dart

import 'package:flutter/foundation.dart';
import 'package:kavaid/models/word_model.dart';
import 'package:kavaid/services/database_service.dart';
import 'package:kavaid/services/firebase_service.dart';
import 'package:kavaid/services/global_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseService _dbService = DatabaseService.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final GlobalConfigService _configService = GlobalConfigService();

  bool _isSyncing = false;
  bool _isDbInitializing = false;
  static const String _syncCompletedKey = 'firebase_sync_completed_v2';

  Future<void> initializeLocalDatabase({bool force = false}) async {
    if (_isDbInitializing && !force) return;
    
    final prefs = await SharedPreferences.getInstance();
    final bool isSyncCompleted = prefs.getBool(_syncCompletedKey) ?? false;

    if (isSyncCompleted && !force) {
      debugPrint('Yerel veritabanı zaten senkronize. İlk kurulum atlanıyor.');
      return;
    }

    _isDbInitializing = true;

    try {
      final db = await _dbService.database;
      final tableInfo = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='words'");
      bool exists = tableInfo.isNotEmpty;
      int count = 0;
      if (exists) {
        final countResult = await db.rawQuery('SELECT COUNT(*) FROM words');
        count = Sqflite.firstIntValue(countResult) ?? 0;
      }

      if (force || !exists || count == 0) {
        debugPrint('Lokal veritabanı boş veya zorunlu senkronizasyon. Firebase\'den veriler çekiliyor...');
        try {
          final allWords = await _firebaseService.getAllWordsFromFirebase();
          if (allWords.isNotEmpty) {
            await _dbService.recreateWordsTable(allWords);
            await prefs.setBool(_syncCompletedKey, true);
            debugPrint('Lokal veritabanı başarıyla ${allWords.length} kelime ile kuruldu/güncellendi.');
          } else {
            debugPrint('Firebase\'den hiç kelime gelmedi. Lokal veritabanı boş bırakıldı.');
          }
        } catch (e) {
          debugPrint('initializeLocalDatabase sırasında hata: $e');
        }
      } else {
        debugPrint('Lokal veritabanı zaten dolu ($count kelime). İlk kurulum atlanıyor.');
        await prefs.setBool(_syncCompletedKey, true);
      }
    } finally {
      _isDbInitializing = false;
    }
  }

  Future<void> handleAiFoundWord(WordModel word) async {
    debugPrint('Yeni AI kelimesi işleniyor: ${word.kelime}');
    await _dbService.addPendingAiWord(word);
    
    final pendingCount = await _dbService.getPendingAiWordsCount();
    const threshold = GlobalConfigService.aiBatchSyncThreshold;

    debugPrint('Bekleyen AI kelime sayısı: $pendingCount, Eşik: $threshold');

    if (pendingCount >= threshold) {
      debugPrint('AI kelime eşiği aşıldı. Firebase ile senkronizasyon tetikleniyor...');
      synchronizeWithFirebase(); // no await, let it run in the background
    }
  }

  Future<void> synchronizeWithFirebase() async {
    if (_isSyncing) {
      debugPrint('Senkronizasyon zaten devam ediyor. Yeni istek atlanıyor.');
      return;
    }
    _isSyncing = true;
    debugPrint('🔥 Firebase senkronizasyonu başladı.');
    
    try {
      final pendingWords = await _dbService.getPendingAiWords();
      if (pendingWords.isEmpty) {
        debugPrint('Senkronize edilecek bekleyen kelime yok.');
        _isSyncing = false;
        return;
      }

      debugPrint('${pendingWords.length} adet bekleyen kelime bulundu. Mevcut anahtarlar çekiliyor...');
      final firebaseKeys = await _firebaseService.getExistingWordKeys();
      
      final newWordsToUpload = <WordModel>[];
      for (final pWord in pendingWords) {
        if (pWord.harekeliKelime != null && !firebaseKeys.contains(pWord.harekeliKelime)) {
          newWordsToUpload.add(pWord);
        }
      }

      if (newWordsToUpload.isNotEmpty) {
        debugPrint('${newWordsToUpload.length} adet YENİ kelime Firebase\'e eklenecek.');
        await _firebaseService.batchAddWords(newWordsToUpload);
      } else {
        debugPrint('Bekleyen tüm kelimeler zaten Firebase\'de mevcut.');
      }

      await _dbService.clearPendingAiWords();
      debugPrint('Bekleyen AI kelimeleri yerel tablodan temizlendi.');

      debugPrint('Tam senkronizasyon için lokal veritabanı güncelleniyor...');
      await initializeLocalDatabase(force: true);

      debugPrint('Firebase kelime sayacı güncelleniyor...');
      await _firebaseService.recalculateAndSetTotalWordsCount();

      debugPrint('✅ Firebase senkronizasyonu başarıyla tamamlandı.');
    } catch (e) {
      debugPrint('❌ synchronizeWithFirebase sırasında bir hata oluştu: $e');
    } finally {
      _isSyncing = false;
    }
  }
}