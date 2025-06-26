import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'device_data_service.dart';

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
  
  static const int _initialCredits = 100; // İlk açılışta 100 hak
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
    debugPrint('🚀 [CreditsService] Initialize başlıyor...');
    final prefs = await SharedPreferences.getInstance();
    
    // Cihaz ID'sini al veya oluştur
    await _initializeDeviceId(prefs);
    debugPrint('📱 [CreditsService] Cihaz ID: $_deviceId');
    
    // Önce Firebase'den verileri almayı dene
    debugPrint('🔥 [CreditsService] Firebase\'den veriler alınmaya çalışılıyor...');
    final deviceDataService = DeviceDataService();
    final firebaseData = await deviceDataService.getDeviceData();
    
    if (firebaseData != null) {
      debugPrint('✅ [CreditsService] Firebase\'de veri bulundu: $firebaseData');
      // Firebase'de veri varsa, onları kullan
      _credits = firebaseData['krediler'] ?? 0;
      _isPremium = firebaseData['premiumDurumu'] ?? false;
      _initialCreditsUsed = firebaseData['ilkKredilerKullanildi'] ?? false;
      
      if (firebaseData['premiumBitisTarihi'] != null) {
        _premiumExpiry = DateTime.fromMillisecondsSinceEpoch(firebaseData['premiumBitisTarihi']);
      }
      
      if (firebaseData['sonSifirlamaTarihi'] != null) {
        _lastResetDate = DateTime.parse(firebaseData['sonSifirlamaTarihi']);
      }
      
      if (firebaseData['oturumAcilanKelimeler'] != null) {
        _sessionOpenedWords = Set<String>.from(firebaseData['oturumAcilanKelimeler']);
      }
      
      // Firebase'den alınan verileri SharedPreferences'a da kaydet (cache için)
      final deviceCreditsKey = '${_creditsKey}_$_deviceId';
      final devicePremiumKey = '${_premiumKey}_$_deviceId';
      final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
      final deviceInitialCreditsUsedKey = '${_initialCreditsUsedKey}_$_deviceId';
      final deviceLastResetDateKey = '${_lastResetDateKey}_$_deviceId';
      final deviceSessionWordsKey = '${_sessionWordsKey}_$_deviceId';
      
      await prefs.setInt(deviceCreditsKey, _credits);
      await prefs.setBool(devicePremiumKey, _isPremium);
      await prefs.setBool(deviceInitialCreditsUsedKey, _initialCreditsUsed);
      
      if (_premiumExpiry != null) {
        await prefs.setInt(devicePremiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
      }
      
      if (_lastResetDate != null) {
        await prefs.setString(deviceLastResetDateKey, _lastResetDate!.toIso8601String());
      }
      
      await prefs.setStringList(deviceSessionWordsKey, _sessionOpenedWords.toList());
      
      debugPrint('✅ [CreditsService] Firebase\'den veriler yüklendi: Kredi: $_credits, Premium: $_isPremium');
    } else {
      debugPrint('⚠️ [CreditsService] Firebase\'de veri yok, SharedPreferences kullanılıyor');
      // Firebase'de veri yoksa, SharedPreferences'tan yükle (mevcut kod)
      // Cihaz bazlı key'ler oluştur
      final deviceCreditsKey = '${_creditsKey}_$_deviceId';
      final devicePremiumKey = '${_premiumKey}_$_deviceId';
      final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
      final deviceInitialCreditsUsedKey = '${_initialCreditsUsedKey}_$_deviceId';
      final deviceLastResetDateKey = '${_lastResetDateKey}_$_deviceId';
      final deviceSessionWordsKey = '${_sessionWordsKey}_$_deviceId';
      
      // Premium durumunu yükle
      _isPremium = prefs.getBool(devicePremiumKey) ?? false;
      
      final expiryMillis = prefs.getInt(devicePremiumExpiryKey);
      if (expiryMillis != null) {
        _premiumExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      }
      
      // Son sıfırlama tarihini yükle - ÖNEMLİ: _checkDailyReset'ten önce!
      final lastResetStr = prefs.getString(deviceLastResetDateKey);
      if (lastResetStr != null) {
        _lastResetDate = DateTime.parse(lastResetStr);
      }
      
      // Bu cihaz için ilk açılış kontrolü
      final deviceFirstLaunchKey = '$_deviceFirstLaunchKey$_deviceId';
      final isDeviceFirstLaunch = prefs.getBool(deviceFirstLaunchKey) ?? true;
      
      if (isDeviceFirstLaunch) {
        debugPrint('🆕 [CreditsService] İlk açılış - 100 kredi veriliyor');
        // Bu cihazda ilk açılış - 100 kredi ver
        await prefs.setInt(deviceCreditsKey, _initialCredits);
        await prefs.setBool(deviceFirstLaunchKey, false);
        await prefs.setBool(deviceInitialCreditsUsedKey, false);
        
        // İlk açılışta bugünün tarihini kaydet
        final now = DateTime.now();
        final turkeyTime = now.toUtc().add(const Duration(hours: 3));
        _lastResetDate = DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day);
        await prefs.setString(deviceLastResetDateKey, _lastResetDate!.toIso8601String());
        
        _credits = _initialCredits;
        _initialCreditsUsed = false;
        
        // İlk açılışta Firebase'e kaydet
        debugPrint('💾 [CreditsService] İlk açılış verileri Firebase\'e kaydediliyor...');
        await _saveToFirebase();
      } else {
        debugPrint('📱 [CreditsService] Daha önce açılmış cihaz, mevcut veriler yükleniyor');
        // Bu cihazda daha önce açılmış
        _initialCreditsUsed = prefs.getBool(deviceInitialCreditsUsedKey) ?? false;
        _credits = prefs.getInt(deviceCreditsKey) ?? 0;
        
        // Eğer ilk krediler bitmiş ve günlük sistem aktifse günlük kontrolü yap
        if (_initialCreditsUsed) {
          await _checkDailyReset(prefs);
        }
      }
    }
    
    // Session yönetimi
    await _initializeSession(prefs);
    
    debugPrint('🎯 [CreditsService] Initialize tamamlandı - Kredi: $_credits, Premium: $_isPremium');
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
    
    // Cihaz bazlı key'ler
    final deviceCreditsKey = '${_creditsKey}_$_deviceId';
    final deviceLastResetDateKey = '${_lastResetDateKey}_$_deviceId';
    final deviceSessionWordsKey = '${_sessionWordsKey}_$_deviceId';
    
    // Eğer _lastResetDate null ise (beklenmedik durum), bugünün tarihini kaydet ama kredi verme
    if (_lastResetDate == null) {
      _lastResetDate = todayMidnight;
      await prefs.setString(deviceLastResetDateKey, todayMidnight.toIso8601String());
      // Kredi vermiyoruz, sadece tarihi kaydediyoruz
      await _saveToFirebase(); // Firebase'e de kaydet
      return;
    }
    
    // Yeni gün kontrolü - sadece gerçekten yeni gün başlamışsa kredi ver
    if (_lastResetDate!.isBefore(todayMidnight)) {
      // Yeni gün başlamış, kredileri yenile
      _credits = _dailyCredits;
      _lastResetDate = todayMidnight;
      
      await prefs.setInt(deviceCreditsKey, _credits);
      await prefs.setString(deviceLastResetDateKey, todayMidnight.toIso8601String());
      
      // Günlük kelime setini temizle
      _sessionOpenedWords.clear();
      await prefs.setStringList(deviceSessionWordsKey, []);
      
      // Firebase'e de kaydet
      await _saveToFirebase();
    }
    // Eğer aynı gündeyse, mevcut krediler korunur (birikme yok)
  }
  
  Future<void> _initializeSession(SharedPreferences prefs) async {
    final savedSessionId = prefs.getString(_sessionIdKey) ?? '';
    final currentSessionId = DateTime.now().toIso8601String();
    
    // Cihaz bazlı key
    final deviceSessionWordsKey = '${_sessionWordsKey}_$_deviceId';
    
    // Yeni oturum oluştur
    if (savedSessionId != currentSessionId.substring(0, 10)) { // Gün bazlı oturum
      _currentSessionId = currentSessionId;
      _sessionOpenedWords.clear();
      await prefs.setString(_sessionIdKey, _currentSessionId);
      await prefs.setStringList(deviceSessionWordsKey, []);
    } else {
      _currentSessionId = savedSessionId;
      _sessionOpenedWords = (prefs.getStringList(deviceSessionWordsKey) ?? []).toSet();
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
    
    // Cihaz bazlı key'ler
    final deviceCreditsKey = '${_creditsKey}_$_deviceId';
    final deviceSessionWordsKey = '${_sessionWordsKey}_$_deviceId';
    final deviceInitialCreditsUsedKey = '${_initialCreditsUsedKey}_$_deviceId';
    final deviceLastResetDateKey = '${_lastResetDateKey}_$_deviceId';
    
    await prefs.setInt(deviceCreditsKey, _credits);
    await prefs.setStringList(deviceSessionWordsKey, _sessionOpenedWords.toList());
    
    // Eğer ilk krediler bittiyse, günlük sisteme geç
    if (!_initialCreditsUsed && _credits == 0) {
      _initialCreditsUsed = true;
      await prefs.setBool(deviceInitialCreditsUsedKey, true);
      
      // Türkiye saatine göre bugünün gece yarısını ayarla
      final now = DateTime.now();
      final turkeyTime = now.toUtc().add(const Duration(hours: 3));
      _lastResetDate = DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day);
      await prefs.setString(deviceLastResetDateKey, _lastResetDate!.toIso8601String());
    }
    
    // Firebase'e de kaydet
    await _saveToFirebase();
    
    notifyListeners();
    return true;
  }
  
  // Premium üyelik aktifleştir (60 ay)
  Future<void> activatePremium() async {
    _isPremium = true;
    _premiumExpiry = DateTime.now().add(const Duration(days: 60 * 30)); // 60 ay
    
    final prefs = await SharedPreferences.getInstance();
    final devicePremiumKey = '${_premiumKey}_$_deviceId';
    final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
    
    await prefs.setBool(devicePremiumKey, true);
    await prefs.setInt(devicePremiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
    
    // Firebase'e de kaydet
    await _saveToFirebase();
    
    notifyListeners();
  }
  
  // Premium üyelik aktifleştir (1 ay) - Aylık abonelik için
  Future<void> activatePremiumMonthly() async {
    _isPremium = true;
    _premiumExpiry = DateTime.now().add(const Duration(days: 30)); // 1 ay
    
    final prefs = await SharedPreferences.getInstance();
    final devicePremiumKey = '${_premiumKey}_$_deviceId';
    final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
    
    await prefs.setBool(devicePremiumKey, true);
    await prefs.setInt(devicePremiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
    
    // Firebase'e de kaydet
    await _saveToFirebase();
    
    notifyListeners();
  }
  
  // GIZLI KOD: Premium üyelik sonsuza kadar aktifleştir
  Future<void> activatePremiumForever() async {
    _isPremium = true;
    // 100 yıl sonraya ayarla (pratikte sonsuza kadar)
    _premiumExpiry = DateTime.now().add(const Duration(days: 365 * 100));
    
    final prefs = await SharedPreferences.getInstance();
    final devicePremiumKey = '${_premiumKey}_$_deviceId';
    final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
    
    await prefs.setBool(devicePremiumKey, true);
    await prefs.setInt(devicePremiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
    
    // Firebase'e de kaydet
    await _saveToFirebase();
    
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
      final devicePremiumKey = '${_premiumKey}_$_deviceId';
      await prefs.setBool(devicePremiumKey, false);
      notifyListeners();
    }
  }
  
  // Test için kredileri sıfırla
  Future<void> resetCreditsForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Cihaz bazlı key'ler
    final deviceCreditsKey = '${_creditsKey}_$_deviceId';
    final deviceLastResetDateKey = '${_lastResetDateKey}_$_deviceId';
    final deviceSessionWordsKey = '${_sessionWordsKey}_$_deviceId';
    
    if (!_initialCreditsUsed) {
      // İlk krediler henüz bitmemişse, 100'e sıfırla
      _credits = _initialCredits;
    } else {
      // Günlük sisteme geçilmişse, günlük kredileri ver
      _credits = _dailyCredits;
      final now = DateTime.now();
      final turkeyTime = now.toUtc().add(const Duration(hours: 3));
      _lastResetDate = DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day);
      await prefs.setString(deviceLastResetDateKey, _lastResetDate!.toIso8601String());
    }
    
    _sessionOpenedWords.clear();
    
    await prefs.setInt(deviceCreditsKey, _credits);
    await prefs.setStringList(deviceSessionWordsKey, []);
    
    notifyListeners();
  }
  
  // Test için ilk kredileri bitir
  Future<void> useAllInitialCreditsForTesting() async {
    if (!_initialCreditsUsed) {
      _credits = 0;
      _initialCreditsUsed = true;
      
      final prefs = await SharedPreferences.getInstance();
      
      // Cihaz bazlı key'ler
      final deviceCreditsKey = '${_creditsKey}_$_deviceId';
      final deviceInitialCreditsUsedKey = '${_initialCreditsUsedKey}_$_deviceId';
      final deviceLastResetDateKey = '${_lastResetDateKey}_$_deviceId';
      
      await prefs.setInt(deviceCreditsKey, _credits);
      await prefs.setBool(deviceInitialCreditsUsedKey, true);
      
      // Günlük sisteme geç - yarın yeni krediler gelsin diye bugünün tarihini ayarla
      final now = DateTime.now();
      final turkeyTime = now.toUtc().add(const Duration(hours: 3));
      _lastResetDate = DateTime(turkeyTime.year, turkeyTime.month, turkeyTime.day).subtract(const Duration(days: 1));
      await prefs.setString(deviceLastResetDateKey, _lastResetDate!.toIso8601String());
      
      notifyListeners();
    }
  }
  
  // Premium'u iptal et (test için)
  Future<void> cancelPremium() async {
    _isPremium = false;
    _premiumExpiry = null;
    
    final prefs = await SharedPreferences.getInstance();
    final devicePremiumKey = '${_premiumKey}_$_deviceId';
    final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
    
    await prefs.setBool(devicePremiumKey, false);
    await prefs.remove(devicePremiumExpiryKey);
    
    // Firebase'e de kaydet
    await _saveToFirebase();
    
    notifyListeners();
  }
  
  // Firebase'e verileri kaydet
  Future<void> _saveToFirebase() async {
    try {
      debugPrint('💾 [CreditsService] Firebase\'e kaydetme başlıyor...');
      debugPrint('📊 [CreditsService] Kaydedilecek veriler: Kredi: $_credits, Premium: $_isPremium, İlkKredilerBitti: $_initialCreditsUsed');
      
      final deviceDataService = DeviceDataService();
      final success = await deviceDataService.saveCreditsData(
        credits: _credits,
        isPremium: _isPremium,
        premiumExpiry: _premiumExpiry,
        initialCreditsUsed: _initialCreditsUsed,
        lastResetDate: _lastResetDate,
        sessionOpenedWords: _sessionOpenedWords.toList(),
      );
      
      if (success) {
        debugPrint('✅ [CreditsService] Firebase\'e veriler başarıyla kaydedildi');
      } else {
        debugPrint('❌ [CreditsService] Firebase\'e veri kaydetme başarısız');
      }
    } catch (e) {
      debugPrint('❌ [CreditsService] Firebase\'e veri kaydetme hatası: $e');
    }
  }
} 