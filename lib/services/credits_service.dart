import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreditsService extends ChangeNotifier {
  static const String _creditsKey = 'user_credits';
  static const String _premiumKey = 'is_premium';
  static const String _premiumExpiryKey = 'premium_expiry';
  static const String _sessionIdKey = 'session_id';
  static const String _sessionWordsKey = 'session_opened_words';
  static const String _firstLaunchKey = 'first_launch';
  
  static const int _initialCredits = 50;
  
  int _credits = 0;
  bool _isPremium = false;
  DateTime? _premiumExpiry;
  String _currentSessionId = '';
  Set<String> _sessionOpenedWords = {};
  
  // Singleton instance
  static final CreditsService _instance = CreditsService._internal();
  factory CreditsService() => _instance;
  CreditsService._internal();
  
  // Getter'lar
  int get credits => _credits;
  bool get isPremium => _isPremium && (_premiumExpiry?.isAfter(DateTime.now()) ?? false);
  DateTime? get premiumExpiry => _premiumExpiry;
  
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // İlk açılış kontrolü
    final isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;
    if (isFirstLaunch) {
      await prefs.setInt(_creditsKey, _initialCredits);
      await prefs.setBool(_firstLaunchKey, false);
    }
    
    // Kredi ve premium durumunu yükle
    _credits = prefs.getInt(_creditsKey) ?? _initialCredits;
    _isPremium = prefs.getBool(_premiumKey) ?? false;
    
    final expiryMillis = prefs.getInt(_premiumExpiryKey);
    if (expiryMillis != null) {
      _premiumExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    }
    
    // Session yönetimi
    await _initializeSession(prefs);
    
    notifyListeners();
  }
  
  Future<void> _initializeSession(SharedPreferences prefs) async {
    final savedSessionId = prefs.getString(_sessionIdKey) ?? '';
    final currentSessionId = DateTime.now().toIso8601String();
    
    // Yeni oturum oluştur
    if (savedSessionId != currentSessionId.substring(0, 10)) { // Gün bazlı oturum
      _currentSessionId = currentSessionId;
      _sessionOpenedWords.clear();
      await prefs.setString(_sessionIdKey, _currentSessionId);
      await prefs.setStringList(_sessionWordsKey, []);
    } else {
      _currentSessionId = savedSessionId;
      _sessionOpenedWords = (prefs.getStringList(_sessionWordsKey) ?? []).toSet();
    }
  }
  
  // Kelime açılımı kontrolü
  Future<bool> canOpenWord(String wordId) async {
    // Premium kullanıcılar sınırsız erişime sahip
    if (isPremium) return true;
    
    // Hak kontrolü
    if (_credits <= 0) return false;
    
    return true;
  }
  
  // Kelime açıldığında hak düşür
  Future<bool> consumeCredit(String wordId) async {
    // Premium kullanıcılar için hak düşürme
    if (isPremium) return true;
    
    // Bu oturumda daha önce açılmış mı?
    if (_sessionOpenedWords.contains(wordId)) {
      return true; // Hak düşürme, zaten açılmış
    }
    
    // Hak kontrolü
    if (_credits <= 0) return false;
    
    // Hak düşür ve kaydet
    _credits--;
    _sessionOpenedWords.add(wordId);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_creditsKey, _credits);
    await prefs.setStringList(_sessionWordsKey, _sessionOpenedWords.toList());
    
    notifyListeners();
    return true;
  }
  
  // Premium üyelik aktifleştir (60 ay)
  Future<void> activatePremium() async {
    _isPremium = true;
    _premiumExpiry = DateTime.now().add(const Duration(days: 60 * 30)); // 60 ay
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
    await prefs.setInt(_premiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
    
    notifyListeners();
  }
  
  // Premium durumu kontrol et
  Future<void> checkPremiumStatus() async {
    if (_premiumExpiry != null && _premiumExpiry!.isBefore(DateTime.now())) {
      _isPremium = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumKey, false);
      notifyListeners();
    }
  }
  
  // Kredileri sıfırla (test için)
  Future<void> resetCredits() async {
    _credits = _initialCredits;
    _sessionOpenedWords.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_creditsKey, _credits);
    await prefs.setStringList(_sessionWordsKey, []);
    
    notifyListeners();
  }
  
  // Premium'u iptal et (test için)
  Future<void> cancelPremium() async {
    _isPremium = false;
    _premiumExpiry = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, false);
    await prefs.remove(_premiumExpiryKey);
    
    notifyListeners();
  }
} 