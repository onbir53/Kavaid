// kavaid/lib/services/database_service.dart

import 'dart:convert';
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
    const idType = 'TEXT PRIMARY KEY NOT NULL';
    const textType = 'TEXT';
    const intType = 'INTEGER';

    await db.execute('''
CREATE TABLE words ( 
  kelime ${idType}, harekeliKelime ${textType}, anlam ${textType}, koku ${textType}, dilbilgiselOzellikler ${textType}, ornekCumleler ${textType}, fiilCekimler ${textType}, eklenmeTarihi ${intType}
)''');
    await db.execute('''
CREATE TABLE pending_ai_words ( 
  kelime ${idType}, harekeliKelime ${textType}, anlam ${textType}, koku ${textType}, dilbilgiselOzellikler ${textType}, ornekCumleler ${textType}, fiilCekimler ${textType}, eklenmeTarihi ${intType}
)''');
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
    // ornekCumleler için güvenli dönüştürme
    final decodedOrnekler = json.decode(map['ornekCumleler'] ?? '[]');
    final ornekCumlelerList = (decodedOrnekler is List)
        ? decodedOrnekler.map((e) => Map<String, String>.from(e as Map)).toList()
        : <Map<String, String>>[];

    // dilbilgiselOzellikler için güvenli dönüştürme
    final decodedOzellikler = json.decode(map['dilbilgiselOzellikler'] ?? '{}');
    final ozelliklerMap = (decodedOzellikler is Map)
        ? Map<String, dynamic>.from(decodedOzellikler)
        : <String, dynamic>{};

    // fiilCekimler için güvenli dönüştürme
    final decodedCekimler = json.decode(map['fiilCekimler'] ?? '{}');
    final cekimlerMap = (decodedCekimler is Map)
        ? Map<String, dynamic>.from(decodedCekimler)
        : <String, dynamic>{};

    return WordModel(
      kelime: map['kelime'], harekeliKelime: map['harekeliKelime'], anlam: map['anlam'], koku: map['koku'],
      dilbilgiselOzellikler: ozelliklerMap,
      ornekCumleler: ornekCumlelerList,
      fiilCekimler: cekimlerMap, 
      eklenmeTarihi: map['eklenmeTarihi'], bulunduMu: true,
    );
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

  Future<List<WordModel>> searchWords(String query, {int limit = 50, int offset = 0}) async {
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

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM (
          SELECT * FROM words
          UNION ALL
          SELECT * FROM pending_ai_words
      )
      WHERE
         kelime LIKE ?
         OR harekeliKelime LIKE ?
         OR LOWER(anlam) LIKE ?
         OR LOWER(anlam) LIKE ?
         OR LOWER(anlam) LIKE ?
      LIMIT ? OFFSET ?
    ''', [...params, limit, offset]);

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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}