import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class CreditsService extends ChangeNotifier {
  static const String _creditsKey = 'user_credits';
  static const String _premiumKey = 'is_premium';
  static const String _premiumExpiryKey = 'premium_expiry';
  static const String _sessionIdKey = 'session_id';
  static const String _sessionWordsKey = 'session_opened_words';
  static const String _firstLaunchKey = 'first_launch';
  static const String _lastResetDateKey = 'last_reset_date';
  static const String _initialCreditsUsedKey = 'initial_credits_used';
  static const String _deviceIdKey = 'device_id';
  static const String _deviceFirstLaunchKey = 'device_first_launch_';
  
  static const int _initialCredits = 50; // İlk açılışta 50 hak
  static const int _dailyCredits = 5; // Günlük 5 hak
  
  int _credits = 0;
  bool _isPremium = false;
  DateTime? _premiumExpiry;
  String _currentSessionId = '';
  Set<String> _sessionOpenedWords = {};
  DateTime? _lastResetDate;
  bool _initialCreditsUsed = false;
  String? _deviceId;
  
  // Singleton instance
  static final CreditsService _instance = CreditsService._internal();
  factory CreditsService() => _instance;
  CreditsService._internal();
  
  // Getter'lar
  int get credits => _credits;
  bool get isPremium => _isPremium && (_premiumExpiry?.isAfter(DateTime.now()) ?? false);
  DateTime? get premiumExpiry => _premiumExpiry;
  bool get hasInitialCredits => !_initialCreditsUsed;
  
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Cihaz ID'sini al veya oluştur
    await _initializeDeviceId(prefs);
    
    // Premium durumunu yükle
    _isPremium = prefs.getBool(_premiumKey) ?? false;
    
    final expiryMillis = prefs.getInt(_premiumExpiryKey);
    if (expiryMillis != null) {
      _premiumExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    }
    
    // Son sıfırlama tarihini yükle - ÖNEMLİ: _checkDailyReset'ten önce!
    final lastResetStr = prefs.getString(_lastResetDateKey);
    if (lastResetStr != null) {
      _lastResetDate = DateTime.parse(lastResetStr);
    }
    
    // Bu cihaz için ilk açılış kontrolü
    final deviceFirstLaunchKey = '$_deviceFirstLaunchKey$_deviceId';
    final isDeviceFirstLaunch = prefs.getBool(deviceFirstLaunchKey) ?? true;
    
    if (isDeviceFirstLaunch) {
      // Bu cihazda ilk açılış - 50 kredi ver
      await prefs.setInt(_creditsKey, _initialCredits);
      await prefs.setBool(deviceFirstLaunchKey, false);
      await prefs.setBool(_firstLaunchKey, false);
      await prefs.setBool(_initialCreditsUsedKey, false);
      
      // İlk açılışta bugünün tarihini kaydet
      final now = DateTime.now();
      final turkeyTime = now.toUtc().add(const Duration(hours: 3));
      _lastResetDate = DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day);
      await prefs.setString(_lastResetDateKey, _lastResetDate!.toIso8601String());
      
      _credits = _initialCredits;
      _initialCreditsUsed = false;
    } else {
      // Bu cihazda daha önce açılmış
      _initialCreditsUsed = prefs.getBool(_initialCreditsUsedKey) ?? false;
      _credits = prefs.getInt(_creditsKey) ?? 0;
      
      // Eğer ilk krediler bitmiş ve günlük sistem aktifse günlük kontrolü yap
      if (_initialCreditsUsed) {
        await _checkDailyReset(prefs);
      }
    }
    
    // Session yönetimi
    await _initializeSession(prefs);
    
    notifyListeners();
  }
  
  // Cihaz ID'sini al veya oluştur
  Future<void> _initializeDeviceId(SharedPreferences prefs) async {
    _deviceId = prefs.getString(_deviceIdKey);
    
    if (_deviceId == null) {
      final deviceInfoPlugin = DeviceInfoPlugin();
      
      try {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          _deviceId = androidInfo.id;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          _deviceId = iosInfo.identifierForVendor ?? DateTime.now().millisecondsSinceEpoch.toString();
        } else {
          // Diğer platformlar için timestamp tabanlı ID
          _deviceId = DateTime.now().millisecondsSinceEpoch.toString();
        }
      } catch (e) {
        // Hata durumunda timestamp tabanlı ID
        _deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      }
      
      await prefs.setString(_deviceIdKey, _deviceId!);
    }
  }
  
  // Günlük sıfırlama kontrolü (Türkiye saatine göre)
  Future<void> _checkDailyReset(SharedPreferences prefs) async {
    if (!_initialCreditsUsed) return; // İlk krediler hala varsa günlük sistemi çalıştırma
    
    final now = DateTime.now();
    // Türkiye saati için UTC+3 ekleme
    final turkeyTime = now.toUtc().add(const Duration(hours: 3));
    final todayMidnight = DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day);
    
    // Eğer _lastResetDate null ise (beklenmedik durum), bugünün tarihini kaydet ama kredi verme
    if (_lastResetDate == null) {
      _lastResetDate = todayMidnight;
      await prefs.setString(_lastResetDateKey, todayMidnight.toIso8601String());
      // Kredi vermiyoruz, sadece tarihi kaydediyoruz
      return;
    }
    
    // Yeni gün kontrolü - sadece gerçekten yeni gün başlamışsa kredi ver
    if (_lastResetDate!.isBefore(todayMidnight)) {
      // Yeni gün başlamış, kredileri yenile
      _credits = _dailyCredits;
      _lastResetDate = todayMidnight;
      
      await prefs.setInt(_creditsKey, _credits);
      await prefs.setString(_lastResetDateKey, todayMidnight.toIso8601String());
      
      // Günlük kelime setini temizle
      _sessionOpenedWords.clear();
      await prefs.setStringList(_sessionWordsKey, []);
    }
    // Eğer aynı gündeyse, mevcut krediler korunur (birikme yok)
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
    
    // Günlük sıfırlama kontrolü yap
    final prefs = await SharedPreferences.getInstance();
    await _checkDailyReset(prefs);
    
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
    
    // Eğer ilk krediler bittiyse, günlük sisteme geç
    if (!_initialCreditsUsed && _credits == 0) {
      _initialCreditsUsed = true;
      await prefs.setBool(_initialCreditsUsedKey, true);
      
      // Türkiye saatine göre bugünün gece yarısını ayarla
      final now = DateTime.now();
      final turkeyTime = now.toUtc().add(const Duration(hours: 3));
      _lastResetDate = DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day);
      await prefs.setString(_lastResetDateKey, _lastResetDate!.toIso8601String());
    }
    
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
  
  // Premium üyelik aktifleştir (1 ay) - Aylık abonelik için
  Future<void> activatePremiumMonthly() async {
    _isPremium = true;
    _premiumExpiry = DateTime.now().add(const Duration(days: 30)); // 1 ay
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
    await prefs.setInt(_premiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
    
    notifyListeners();
  }
  
  // GIZLI KOD: Premium üyelik sonsuza kadar aktifleştir
  Future<void> activatePremiumForever() async {
    _isPremium = true;
    // 100 yıl sonraya ayarla (pratikte sonsuza kadar)
    _premiumExpiry = DateTime.now().add(const Duration(days: 365 * 100));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
    await prefs.setInt(_premiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
    
    notifyListeners();
  }
  
  // GIZLI KOD: Premium durumunu toggle et (premium ise free yap, free ise premium yap)
  Future<bool> togglePremiumStatus() async {
    if (isPremium) {
      // Premium'dan free'ye geç
      await cancelPremium();
      return false; // Artık free
    } else {
      // Free'den premium'a geç
      await activatePremiumForever();
      return true; // Artık premium
    }
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
  
  // Test için kredileri sıfırla
  Future<void> resetCreditsForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!_initialCreditsUsed) {
      // İlk krediler henüz bitmemişse, 50'ye sıfırla
      _credits = _initialCredits;
    } else {
      // Günlük sisteme geçilmişse, günlük kredileri ver
      _credits = _dailyCredits;
      final now = DateTime.now();
      final turkeyTime = now.toUtc().add(const Duration(hours: 3));
      _lastResetDate = DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day);
      await prefs.setString(_lastResetDateKey, _lastResetDate!.toIso8601String());
    }
    
    _sessionOpenedWords.clear();
    
    await prefs.setInt(_creditsKey, _credits);
    await prefs.setStringList(_sessionWordsKey, []);
    
    notifyListeners();
  }
  
  // Test için ilk kredileri bitir
  Future<void> useAllInitialCreditsForTesting() async {
    if (!_initialCreditsUsed) {
      _credits = 0;
      _initialCreditsUsed = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_creditsKey, _credits);
      await prefs.setBool(_initialCreditsUsedKey, true);
      
      // Günlük sisteme geç - yarın yeni krediler gelsin diye bugünün tarihini ayarla
      final now = DateTime.now();
      final turkeyTime = now.toUtc().add(const Duration(hours: 3));
      _lastResetDate = DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day).subtract(const Duration(days: 1));
      await prefs.setString(_lastResetDateKey, _lastResetDate!.toIso8601String());
      
      notifyListeners();
    }
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