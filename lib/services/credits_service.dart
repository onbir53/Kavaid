import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'device_data_service.dart';
import 'analytics_service.dart';

class CreditsService extends ChangeNotifier {
  static const String _premiumKey = 'is_premium';
  static const String _premiumExpiryKey = 'premium_expiry';
  static const String _deviceIdKey = 'device_id';
  
  bool _isPremium = false;
  DateTime? _premiumExpiry;
  String? _deviceId;
  
  // Singleton instance
  static final CreditsService _instance = CreditsService._internal();
  factory CreditsService() => _instance;
  CreditsService._internal();
  
  // Getter'lar
  bool get isPremium => _isPremium && (_premiumExpiry?.isAfter(DateTime.now()) ?? false);
  DateTime? get premiumExpiry => _premiumExpiry;
  bool get isLifetimeAdsFree => _isPremium; // Premium kullanıcıları için reklamsız
  
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
      _isPremium = firebaseData['premiumDurumu'] ?? false;
      
      if (firebaseData['premiumBitisTarihi'] != null) {
        _premiumExpiry = DateTime.fromMillisecondsSinceEpoch(firebaseData['premiumBitisTarihi']);
      }
      
      // Firebase'den alınan verileri SharedPreferences'a da kaydet (cache için)
      final devicePremiumKey = '${_premiumKey}_$_deviceId';
      final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
      
      await prefs.setBool(devicePremiumKey, _isPremium);
      
      if (_premiumExpiry != null) {
        await prefs.setInt(devicePremiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
      }
      
      debugPrint('✅ [CreditsService] Firebase\'den veriler yüklendi: Premium: $_isPremium');
    } else {
      debugPrint('⚠️ [CreditsService] Firebase\'de veri yok, SharedPreferences kullanılıyor');
      // Firebase'de veri yoksa, SharedPreferences'tan yükle
      // Cihaz bazlı key'ler oluştur
      final devicePremiumKey = '${_premiumKey}_$_deviceId';
      final devicePremiumExpiryKey = '${_premiumExpiryKey}_$_deviceId';
      
      // Premium durumunu yükle
      _isPremium = prefs.getBool(devicePremiumKey) ?? false;
      
      final expiryMillis = prefs.getInt(devicePremiumExpiryKey);
      if (expiryMillis != null) {
        _premiumExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      }
    }
    
    debugPrint('🎯 [CreditsService] Initialize tamamlandı - Premium: $_isPremium');
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
  
  // Kelime açılımı kontrolü - artık sadece true döndürüyor
  Future<bool> canOpenWord(String wordId) async {
    return true; // Herkes sınırsız kelime açabilir
  }
  
  // Kelime açıldığında - artık hiçbir şey yapmıyor
  Future<bool> consumeCredit(String wordId) async {
    return true; // Her zaman başarılı
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
    
    // Analytics user properties'ini güncelle
    await AnalyticsService.setUserProperties(isPremium: _isPremium);
    
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
    
    // Analytics user properties'ini güncelle
    await AnalyticsService.setUserProperties(isPremium: _isPremium);
    
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
    
    // Analytics user properties'ini güncelle
    await AnalyticsService.setUserProperties(isPremium: _isPremium);
    
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
    
    // Analytics user properties'ini güncelle
    await AnalyticsService.setUserProperties(isPremium: _isPremium);
    
    notifyListeners();
  }
  
  // Firebase'e verileri kaydet
  Future<void> _saveToFirebase() async {
    try {
      debugPrint('💾 [CreditsService] Firebase\'e kaydetme başlıyor...');
      debugPrint('📊 [CreditsService] Kaydedilecek veriler: Premium: $_isPremium');
      
      final deviceDataService = DeviceDataService();
      // Basitleştirilmiş veri kaydı - sadece premium bilgisi
      final Map<String, dynamic> dataToSave = {
        'premiumDurumu': _isPremium,
      };
      
      if (_premiumExpiry != null) {
        dataToSave['premiumBitisTarihi'] = _premiumExpiry!.millisecondsSinceEpoch;
      }
      
      final success = await deviceDataService.saveDeviceData(dataToSave);
      
      if (success) {
        debugPrint('✅ [CreditsService] Firebase\'e veriler başarıyla kaydedildi');
      } else {
        debugPrint('❌ [CreditsService] Firebase\'e veri kaydetme başarısız');
      }
    } catch (e) {
      debugPrint('❌ [CreditsService] Firebase\'e veri kaydetme hatası: $e');
    }
  }
  
  // Eski metotlar için uyumluluk - artık hiçbir şey yapmıyorlar
  int get credits => 999; // Sınırsız gösterim için
  bool get hasInitialCredits => false;
  bool get initialCreditsUsed => true;
  DateTime? get lastResetDate => null;
  
  Future<void> resetCreditsForTesting() async {
    // Artık bir şey yapmıyor
  }
  
  Future<void> useAllInitialCreditsForTesting() async {
    // Artık bir şey yapmıyor
  }
  
  Future<void> resetToInitialCreditsForTesting() async {
    // Artık bir şey yapmıyor
  }
  
  Future<void> simulateMidnightResetForTesting() async {
    // Artık bir şey yapmıyor
  }
  
  Future<void> useAllDailyCreditsForTesting() async {
    // Artık bir şey yapmıyor
  }
  
  Future<void> checkDailyResetManually() async {
    // Artık bir şey yapmıyor
  }
  
  // Lifetime Ads Free durumunu ayarla (OneTimePurchase için)
  Future<void> setLifetimeAdsFree(bool value) async {
    if (value) {
      // Lifetime ads free = premium forever
      await activatePremiumForever();
    } else {
      // Lifetime ads free'yi kaldır
      await cancelPremium();
    }
  }
  
  // DEBUG: Reklamsız durumunu test için toggle et
  Future<void> toggleAdsFreeForTest() async {
    await togglePremiumStatus();
  }
} 