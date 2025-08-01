// kavaid/lib/services/database_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kavaid.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    final idType = 'TEXT PRIMARY KEY NOT NULL';
    final textType = 'TEXT';
    final intType = 'INTEGER';

    await db.execute('''
CREATE TABLE IF NOT EXISTS words ( 
  kelime ${idType}, harekeliKelime ${textType}, anlam ${textType}, koku ${textType}, dilbilgiselOzellikler ${textType}, ornekCumleler ${textType}, fiilCekimler ${textType}, eklenmeTarihi ${intType}
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS pending_ai_words ( 
  kelime ${idType}, harekeliKelime ${textType}, anlam ${textType}, koku ${textType}, dilbilgiselOzellikler ${textType}, ornekCumleler ${textType}, fiilCekimler ${textType}, eklenmeTarihi ${intType}
)''');
    
    // ANR önleme için performans indeksleri
    await db.execute('CREATE INDEX IF NOT EXISTS idx_words_kelime ON words(kelime COLLATE NOCASE)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_words_harekeli ON words(harekeliKelime COLLATE NOCASE)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_words_anlam ON words(anlam COLLATE NOCASE)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_kelime ON pending_ai_words(kelime COLLATE NOCASE)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_harekeli ON pending_ai_words(harekeliKelime COLLATE NOCASE)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_anlam ON pending_ai_words(anlam COLLATE NOCASE)');
  }

  Map<String, dynamic> _wordToDbMap(WordModel word) {
    return {
      'kelime': word.kelime, 'harekeliKelime': word.harekeliKelime, 'anlam': word.anlam, 'koku': word.koku,
      'dilbilgiselOzellikler': json.encode(word.dilbilgiselOzellikler),
      'ornekCumleler': json.encode(word.ornekCumleler?.map((e) => e).toList()),
      'fiilCekimler': json.encode(word.fiilCekimler), 'eklenmeTarihi': word.eklenmeTarihi,
    };
  }

  WordModel _dbMapToWord(Map<String, dynamic> map) {
    try {
      // Null safety: kelime alanı zorunlu
      final kelime = map['kelime']?.toString();
      if (kelime == null || kelime.isEmpty) {
        throw Exception('Kelime alanı boş veya null');
      }

      // ornekCumleler için güvenli dönüştürme
      List<Map<String, String>> ornekCumlelerList = <Map<String, String>>[];
      try {
        final ornekCumlelerStr = map['ornekCumleler']?.toString() ?? '[]';
        final decodedOrnekler = json.decode(ornekCumlelerStr);
        if (decodedOrnekler is List) {
          ornekCumlelerList = decodedOrnekler
              .where((e) => e != null && e is Map)
              .map((e) => Map<String, String>.from(e as Map))
              .toList();
        }
      } catch (e) {
        debugPrint('ornekCumleler JSON decode hatası: $e');
        ornekCumlelerList = <Map<String, String>>[];
      }

      // dilbilgiselOzellikler için güvenli dönüştürme
      Map<String, dynamic> ozelliklerMap = <String, dynamic>{};
      try {
        final ozelliklerStr = map['dilbilgiselOzellikler']?.toString() ?? '{}';
        final decodedOzellikler = json.decode(ozelliklerStr);
        if (decodedOzellikler is Map) {
          ozelliklerMap = Map<String, dynamic>.from(decodedOzellikler);
        }
      } catch (e) {
        debugPrint('dilbilgiselOzellikler JSON decode hatası: $e');
        ozelliklerMap = <String, dynamic>{};
      }

      // fiilCekimler için güvenli dönüştürme
      Map<String, dynamic> cekimlerMap = <String, dynamic>{};
      try {
        final cekimlerStr = map['fiilCekimler']?.toString() ?? '{}';
        final decodedCekimler = json.decode(cekimlerStr);
        if (decodedCekimler is Map) {
          cekimlerMap = Map<String, dynamic>.from(decodedCekimler);
        }
      } catch (e) {
        debugPrint('fiilCekimler JSON decode hatası: $e');
        cekimlerMap = <String, dynamic>{};
      }

      return WordModel(
        kelime: kelime,
        harekeliKelime: map['harekeliKelime']?.toString(),
        anlam: map['anlam']?.toString(),
        koku: map['koku']?.toString(),
        dilbilgiselOzellikler: ozelliklerMap,
        ornekCumleler: ornekCumlelerList,
        fiilCekimler: cekimlerMap,
        eklenmeTarihi: map['eklenmeTarihi'] as int?,
        bulunduMu: true,
      );
    } catch (e) {
      debugPrint('_dbMapToWord hatası: $e, map: $map');
      // Hata durumunda minimal bir WordModel döndür
      return WordModel(
        kelime: map['kelime']?.toString() ?? 'Hatalı Kelime',
        harekeliKelime: map['harekeliKelime']?.toString(),
        anlam: 'Veri yükleme hatası',
        bulunduMu: false,
      );
    }
  }

  Future<void> addPendingAiWord(WordModel word) async {
    final db = await instance.database;
    await db.insert('pending_ai_words', _wordToDbMap(word), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getPendingAiWordsCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM pending_ai_words');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<WordModel>> searchWords(String query) async {
    final db = await instance.database;
    if (query.isEmpty) return [];

    // Arama için terimleri hazırla
    final arabicStartsWith = '$query%';
    final lowerTurkishQuery = query.toLowerCase();
    final turkishStartsWith = '$lowerTurkishQuery%';
    final turkishContainsAfterComma = '%,$lowerTurkishQuery%';
    final turkishContainsAfterCommaSpace = '%, $lowerTurkishQuery%';

    final params = [
        arabicStartsWith,
        arabicStartsWith,
        turkishStartsWith,
        turkishContainsAfterComma,
        turkishContainsAfterCommaSpace
    ];

    // Optimize edilmiş SQL sorgusu - indexli arama (sınırsız)
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM (
          SELECT * FROM words
          UNION ALL
          SELECT * FROM pending_ai_words
      )
      WHERE
         kelime LIKE ? COLLATE NOCASE
         OR harekeliKelime LIKE ? COLLATE NOCASE
         OR LOWER(anlam) LIKE ?
         OR LOWER(anlam) LIKE ?
         OR LOWER(anlam) LIKE ?
      ORDER BY 
        CASE 
          WHEN kelime = ? THEN 1
          WHEN harekeliKelime = ? THEN 2
          WHEN kelime LIKE ? THEN 3
          WHEN harekeliKelime LIKE ? THEN 4
          ELSE 5
        END
    ''', [...params, query, query, arabicStartsWith, arabicStartsWith]);

    return maps.map((json) => _dbMapToWord(json)).toList();
  }

  Future<List<WordModel>> getPendingAiWords() async {
    final db = await instance.database;
    final maps = await db.query('pending_ai_words');
    return maps.map((json) => _dbMapToWord(json)).toList();
  }

  Future<void> clearPendingAiWords() async {
    final db = await instance.database;
    await db.delete('pending_ai_words');
  }

  Future<void> recreateWordsTable(List<WordModel> words) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('words');
      for (final word in words) {
        batch.insert('words', _wordToDbMap(word), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    print('${words.length} kelime ile lokal veritabanı güncellendi.');
  }

  Future<int> getWordsCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM words');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // YEREL ARAMA İÇİN TÜM KELİMELERİ GETİR
  Future<List<WordModel>> getAllWords() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM words
      UNION ALL
      SELECT * FROM pending_ai_words
    ''');
    
    if (maps.isEmpty) {
      return [];
    }
    
    return maps.map((json) => _dbMapToWord(json)).toList();
  }

  Future<void> addWord(WordModel word) async {
    final db = await instance.database;
    await db.insert('words', _wordToDbMap(word), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<WordModel?> getWordByExactMatch(String query) async {
    final db = await instance.database;
    final searchTerm = query.toLowerCase().trim();
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM words WHERE LOWER(kelime) = ? OR LOWER(harekeliKelime) = ?
      UNION
      SELECT * FROM pending_ai_words WHERE LOWER(kelime) = ? OR LOWER(harekeliKelime) = ?
      LIMIT 1
    ''', [searchTerm, searchTerm, searchTerm, searchTerm]);

    if (maps.isNotEmpty) {
      return _dbMapToWord(maps.first);
    }
    return null;
  }

  Future<WordModel?> getWordByHarekeliKelime(String harekeliKelime) async {
    final db = await instance.database;
    final maps = await db.query(
      'words',
      where: 'harekeliKelime = ?',
      whereArgs: [harekeliKelime],
    );
    
    if (maps.isNotEmpty) {
      return _dbMapToWord(maps.first);
    }
    return null;
  }

  // AI kelime arama öncesi tekrar kontrolü - harekeli Arapça ile
  Future<bool> isWordExistsByHarekeliArabic(String harekeliKelime) async {
    if (harekeliKelime.isEmpty) return false;
    
    final db = await instance.database;
    
    // Hem ana tabloda hem de pending AI words tablosunda kontrol et
    final mainTableResult = await db.query(
      'words',
      where: 'harekeliKelime = ? COLLATE NOCASE',
      whereArgs: [harekeliKelime],
      limit: 1,
    );
    
    if (mainTableResult.isNotEmpty) {
      debugPrint('✅ Kelime ana tabloda bulundu: $harekeliKelime');
      return true;
    }
    
    // Pending AI words tablosunda da kontrol et
    final pendingTableResult = await db.query(
      'pending_ai_words',
      where: 'harekeliKelime = ? COLLATE NOCASE',
      whereArgs: [harekeliKelime],
      limit: 1,
    );
    
    if (pendingTableResult.isNotEmpty) {
      debugPrint('✅ Kelime pending AI tablosunda bulundu: $harekeliKelime');
      return true;
    }
    
    debugPrint('❌ Kelime hiçbir tabloda bulunamadı: $harekeliKelime');
    return false;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}